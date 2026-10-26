import { Injectable, ServiceUnavailableException } from "@nestjs/common";
import { randomBytes } from "node:crypto";
import { spawn } from "node:child_process";
import { resolve } from "node:path";

const DRIVE_SCOPE = "https://www.googleapis.com/auth/drive.file";
const DRIVE_API = "https://www.googleapis.com/drive/v3";
const DRIVE_UPLOAD_API = "https://www.googleapis.com/upload/drive/v3/files";
const DRIVE_FOLDER_MIME = "application/vnd.google-apps.folder";

type GoogleTokenResponse = {
  access_token?: string;
  expires_in?: number;
  refresh_token?: string;
  scope?: string;
  token_type?: string;
  error?: string;
  error_description?: string;
};

type GoogleDriveFile = {
  id?: string;
  name?: string;
  mimeType?: string;
  size?: string;
  parents?: string[];
};

export type GoogleDriveAuthorizationCompletion =
  | { persistence: "local_dpapi" }
  | { persistence: "render_environment"; refreshToken: string };

@Injectable()
export class GoogleDriveStorageService {
  private readonly pendingStates = new Map<string, number>();
  private rootFolderId: string | null = null;
  private readonly folderCache = new Map<string, string>();

  status() {
    const rootName = this.rootFolderName();
    return {
      provider: "google_drive",
      configured: Boolean(
        process.env.SAKHI_GOOGLE_DRIVE_CLIENT_ID?.trim() &&
          process.env.SAKHI_GOOGLE_DRIVE_CLIENT_SECRET?.trim(),
      ),
      connected: Boolean(process.env.SAKHI_GOOGLE_DRIVE_REFRESH_TOKEN?.trim()),
      scope: DRIVE_SCOPE,
      storageFolder: rootName,
      rootFolderName: rootName,
      hierarchy: {
        profilePattern: `${rootName}/users/{opaqueUserId}/profile`,
        feedPattern: `${rootName}/feeds/{categorySlug}/{opaqueUserId}/{postId}`,
      },
    };
  }

  async verifyConnectionStatus(performRemoteCheck = false) {
    const base = this.status();
    if (!performRemoteCheck || !base.configured || !base.connected) {
      return { ...base, rootFolderId: this.rootFolderId, verifiedAt: null };
    }
    try {
      const accessToken = await this.getAccessToken();
      const rootFolderId = await this.ensureRootFolder(accessToken);
      return {
        ...base,
        rootFolderId,
        verifiedAt: new Date().toISOString(),
      };
    } catch (error) {
      return {
        ...base,
        connected: false,
        rootFolderId: null,
        verifiedAt: new Date().toISOString(),
        errorMessage:
          error instanceof Error ? error.message : "Google Drive verification failed.",
      };
    }
  }

  buildMediaHierarchySegments(options: {
    purpose: "avatar" | "post" | "PROFILE_PHOTO" | "COMMUNITY_POST_IMAGE" | "COMMUNITY_POST_VIDEO";
    accountId: string;
    categorySlug?: string | null;
    postId?: string | null;
  }): { segments: string[]; displayPath: string } {
    const rootName = this.rootFolderName();
    const safeUserId = this.sanitizeSegment(options.accountId, "unknown-user");
    if (options.purpose === "avatar" || options.purpose === "PROFILE_PHOTO") {
      const segments = ["users", safeUserId, "profile"];
      return {
        segments,
        displayPath: [rootName, ...segments].join("/"),
      };
    }
    const safeCategory = this.sanitizeSegment(options.categorySlug || "community", "community");
    const safePostSegment = this.sanitizeSegment(options.postId || "staging", "staging");
    const segments = ["feeds", safeCategory, safeUserId, safePostSegment];
    return {
      segments,
      displayPath: [rootName, ...segments].join("/"),
    };
  }

  createAuthorizationUrl(): string {
    this.assertClientConfigured();
    const state = randomBytes(32).toString("base64url");
    this.pendingStates.set(state, Date.now() + 10 * 60 * 1000);
    for (const [key, expiry] of this.pendingStates) {
      if (expiry < Date.now()) this.pendingStates.delete(key);
    }

    const url = new URL("https://accounts.google.com/o/oauth2/v2/auth");
    url.searchParams.set("client_id", this.clientId());
    url.searchParams.set("redirect_uri", this.redirectUri());
    url.searchParams.set("response_type", "code");
    url.searchParams.set("scope", DRIVE_SCOPE);
    url.searchParams.set("access_type", "offline");
    url.searchParams.set("prompt", "consent");
    url.searchParams.set("include_granted_scopes", "true");
    url.searchParams.set("state", state);
    return url.toString();
  }

  async completeAuthorization(
    code: string,
    state: string,
  ): Promise<GoogleDriveAuthorizationCompletion> {
    this.assertClientConfigured();
    const expiry = this.pendingStates.get(state);
    this.pendingStates.delete(state);
    if (!expiry || expiry < Date.now()) {
      throw new ServiceUnavailableException(
        "Google Drive authorization state is invalid or expired. Start the connection again.",
      );
    }

    const form = new URLSearchParams({
      code,
      client_id: this.clientId(),
      client_secret: this.clientSecret(),
      redirect_uri: this.redirectUri(),
      grant_type: "authorization_code",
    });
    const response = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: form,
    });
    const token = (await response.json().catch(() => ({}))) as GoogleTokenResponse;
    if (!response.ok || !token.refresh_token) {
      throw new ServiceUnavailableException(
        "Google did not return an offline refresh token. Reconnect and approve the requested Drive access.",
      );
    }

    // Render containers cannot use the local Windows DPAPI credential store.
    // In an explicitly enabled staging deployment, return the refresh token to
    // the administrator's no-store callback page so it can be saved directly
    // as a Render environment variable. Never log or persist it in the app DB.
    if (this.isRenderStagingEnvironmentSetupEnabled()) {
      this.rootFolderId = null;
      this.folderCache.clear();
      return {
        persistence: "render_environment",
        refreshToken: token.refresh_token,
      };
    }

    await this.persistRefreshToken(token.refresh_token);
    process.env.SAKHI_GOOGLE_DRIVE_REFRESH_TOKEN = token.refresh_token;
    this.rootFolderId = null;
    this.folderCache.clear();
    return { persistence: "local_dpapi" };
  }

  private isRenderStagingEnvironmentSetupEnabled(): boolean {
    let callback: URL;
    try {
      callback = new URL(this.redirectUri());
    } catch {
      return false;
    }
    return (
      process.env.SAKHI_GOOGLE_DRIVE_CLOUD_SETUP_ENABLED?.trim().toLowerCase() ===
        "true" &&
      process.env.NODE_ENV === "production" &&
      process.env.SAKHI_ENV === "staging" &&
      Boolean(process.env.RENDER_SERVICE_ID?.trim()) &&
      callback.protocol === "https:" &&
      callback.hostname.endsWith(".onrender.com") &&
      callback.pathname === "/api/v1/integrations/google-drive/callback"
    );
  }

  async uploadImage(input: {
    uploadId: string;
    accountId: string;
    purpose: "avatar" | "post";
    categorySlug?: string | null;
    postId?: string | null;
    fileName: string;
    contentType: "image/jpeg" | "image/png" | "image/webp" | "video/mp4";
    buffer: Buffer;
  }): Promise<{
    driveFileId: string;
    driveFolderId: string;
    driveFolderPath: string;
    storedName: string;
    size: number;
  }> {
    if (input.buffer.length === 0) {
      throw new ServiceUnavailableException("The selected media file is empty.");
    }
    const accessToken = await this.getAccessToken();
    const hierarchy = this.buildMediaHierarchySegments({
      purpose: input.purpose,
      accountId: input.accountId,
      categorySlug: input.categorySlug,
      postId: input.postId,
    });
    const parentId = await this.ensureFolderHierarchy(accessToken, hierarchy.segments);
    const safeFileName = this.safeFileName(input.fileName);
    const storedName = `${input.purpose}_${input.accountId.slice(0, 8)}_${input.uploadId}_${safeFileName}`;
    const metadata = {
      name: storedName,
      mimeType: input.contentType,
      parents: [parentId],
      appProperties: {
        sakhiUploadId: input.uploadId,
        sakhiPurpose: input.purpose,
        sakhiAccountId: input.accountId,
        sakhiCategorySlug: input.categorySlug || "community",
      },
    };
    const boundary = `sakhi_${randomBytes(18).toString("hex")}`;
    const body = Buffer.concat([
      Buffer.from(
        `--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${JSON.stringify(metadata)}\r\n--${boundary}\r\nContent-Type: ${input.contentType}\r\n\r\n`,
        "utf8",
      ),
      input.buffer,
      Buffer.from(`\r\n--${boundary}--`, "utf8"),
    ]);
    const response = await fetch(
      `${DRIVE_UPLOAD_API}?uploadType=multipart&fields=id,name,mimeType,size`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": `multipart/related; boundary=${boundary}`,
        },
        body,
      },
    );
    const file = (await response.json().catch(() => ({}))) as GoogleDriveFile;
    if (!response.ok || !file.id) {
      throw new ServiceUnavailableException(
        "Google Drive could not store the media. Check the Drive API and authorized account, then retry.",
      );
    }
    return {
      driveFileId: file.id,
      driveFolderId: parentId,
      driveFolderPath: hierarchy.displayPath,
      storedName: file.name ?? storedName,
      size: Number(file.size ?? input.buffer.length),
    };
  }

  async moveFileToPostFolder(options: {
    driveFileId: string;
    accountId: string;
    categorySlug: string;
    postId: string;
  }): Promise<{ driveFolderId: string; driveFolderPath: string }> {
    const hierarchy = this.buildMediaHierarchySegments({
      purpose: "post",
      accountId: options.accountId,
      categorySlug: options.categorySlug,
      postId: options.postId,
    });
    const status = this.status();
    if (!status.configured || !status.connected) {
      return { driveFolderId: "local-folder", driveFolderPath: hierarchy.displayPath };
    }
    try {
      const accessToken = await this.getAccessToken();
      const targetFolderId = await this.ensureFolderHierarchy(accessToken, hierarchy.segments);
      const getRes = await fetch(
        `${DRIVE_API}/files/${encodeURIComponent(options.driveFileId)}?fields=id,parents`,
        { headers: { Authorization: `Bearer ${accessToken}` } },
      );
      if (getRes.ok) {
        const meta = (await getRes.json().catch(() => ({}))) as GoogleDriveFile;
        const removeParents = (meta.parents ?? []).join(",");
        const patchUrl = new URL(`${DRIVE_API}/files/${encodeURIComponent(options.driveFileId)}`);
        patchUrl.searchParams.set("addParents", targetFolderId);
        if (removeParents) patchUrl.searchParams.set("removeParents", removeParents);
        await fetch(patchUrl, {
          method: "PATCH",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            appProperties: {
              sakhiCategorySlug: options.categorySlug,
              sakhiPostId: options.postId,
            },
          }),
        });
      }
      return {
        driveFolderId: targetFolderId,
        driveFolderPath: hierarchy.displayPath,
      };
    } catch {
      return {
        driveFolderId: "unchanged",
        driveFolderPath: hierarchy.displayPath,
      };
    }
  }

  async downloadFile(driveFileId: string): Promise<{ buffer: Buffer; contentType: string }> {
    if (!/^[A-Za-z0-9_-]{10,200}$/.test(driveFileId)) {
      throw new ServiceUnavailableException("The stored Google Drive file reference is invalid.");
    }
    const accessToken = await this.getAccessToken();
    const response = await fetch(
      `${DRIVE_API}/files/${encodeURIComponent(driveFileId)}?alt=media`,
      { headers: { Authorization: `Bearer ${accessToken}` } },
    );
    if (!response.ok) {
      throw new ServiceUnavailableException(
        "The stored image could not be retrieved from Google Drive.",
      );
    }
    return {
      buffer: Buffer.from(await response.arrayBuffer()),
      contentType: response.headers.get("content-type")?.split(";")[0] ?? "application/octet-stream",
    };
  }

  private async getAccessToken(): Promise<string> {
    this.assertClientConfigured();
    const refreshToken = process.env.SAKHI_GOOGLE_DRIVE_REFRESH_TOKEN?.trim();
    if (!refreshToken) {
      throw new ServiceUnavailableException(
        "Google Drive is not connected. Open the local Google Drive connect URL and authorize the Sakhi media app.",
      );
    }

    const form = new URLSearchParams({
      client_id: this.clientId(),
      client_secret: this.clientSecret(),
      refresh_token: refreshToken,
      grant_type: "refresh_token",
    });
    const response = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: form,
    });
    const token = (await response.json().catch(() => ({}))) as GoogleTokenResponse;
    if (!response.ok || !token.access_token) {
      throw new ServiceUnavailableException(
        "Google Drive authorization is unavailable. Reconnect the Google account from this local development backend.",
      );
    }
    return token.access_token;
  }

  private async ensureRootFolder(accessToken: string): Promise<string> {
    if (this.rootFolderId) return this.rootFolderId;
    const rootName = this.rootFolderName();
    const escaped = rootName.replace(/\x27/g, "\\\x27");
    const query = `name = \x27${escaped}\x27 and mimeType = \x27application/vnd.google-apps.folder\x27 and trashed = false`;
    const listUrl = new URL(`${DRIVE_API}/files`);
    listUrl.searchParams.set("q", query);
    listUrl.searchParams.set("pageSize", "20");
    listUrl.searchParams.set("fields", "files(id,name,mimeType)");
    const listResponse = await fetch(listUrl, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    const listed = (await listResponse.json().catch(() => ({}))) as {
      files?: GoogleDriveFile[];
    };
    if (listResponse.ok && listed.files?.[0]?.id) {
      this.rootFolderId = listed.files[0].id;
      return this.rootFolderId;
    }

    const createResponse = await fetch(`${DRIVE_API}/files?fields=id,name,mimeType`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        name: rootName,
        mimeType: DRIVE_FOLDER_MIME,
      }),
    });
    const created = (await createResponse.json().catch(() => ({}))) as GoogleDriveFile;
    if (!createResponse.ok || !created.id) {
      throw new ServiceUnavailableException(
        "Sakhi could not create its private media folder in Google Drive.",
      );
    }
    this.rootFolderId = created.id;
    return created.id;
  }

  private async ensureFolderHierarchy(
    accessToken: string,
    segments: string[],
  ): Promise<string> {
    let currentParentId = await this.ensureRootFolder(accessToken);
    let cumulativeKey = this.rootFolderName();
    for (const rawSegment of segments) {
      const segment = this.sanitizeSegment(rawSegment, "general");
      cumulativeKey = `${cumulativeKey}/${segment}`;
      const cached = this.folderCache.get(cumulativeKey);
      if (cached) {
        currentParentId = cached;
        continue;
      }
      const childId = await this.findOrCreateChildFolder(
        accessToken,
        currentParentId,
        segment,
      );
      this.folderCache.set(cumulativeKey, childId);
      currentParentId = childId;
    }
    return currentParentId;
  }

  private async findOrCreateChildFolder(
    accessToken: string,
    parentId: string,
    folderName: string,
  ): Promise<string> {
    const escapedName = folderName.replace(/\x27/g, "\\\x27");
    const escapedParent = parentId.replace(/\x27/g, "\\\x27");
    const query = `name = \x27${escapedName}\x27 and \x27${escapedParent}\x27 in parents and mimeType = \x27${DRIVE_FOLDER_MIME}\x27 and trashed = false`;
    const listUrl = new URL(`${DRIVE_API}/files`);
    listUrl.searchParams.set("q", query);
    listUrl.searchParams.set("pageSize", "5");
    listUrl.searchParams.set("fields", "files(id,name)");
    const listRes = await fetch(listUrl, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    const listed = (await listRes.json().catch(() => ({}))) as {
      files?: GoogleDriveFile[];
    };
    if (listRes.ok && listed.files?.[0]?.id) {
      return listed.files[0].id;
    }

    const createRes = await fetch(`${DRIVE_API}/files?fields=id,name`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        name: folderName,
        mimeType: DRIVE_FOLDER_MIME,
        parents: [parentId],
      }),
    });
    const created = (await createRes.json().catch(() => ({}))) as GoogleDriveFile;
    if (!createRes.ok || !created.id) {
      return parentId;
    }
    return created.id;
  }

  private persistRefreshToken(refreshToken: string): Promise<void> {
    if (process.platform !== "win32") {
      throw new ServiceUnavailableException(
        "The local credential writer currently requires Windows DPAPI. Use the supported Windows dev startup script.",
      );
    }
    const scriptPath = resolve(
      process.cwd(),
      "scripts",
      "Store-GoogleDriveRefreshToken.ps1",
    );
    return new Promise((resolvePromise, rejectPromise) => {
      const child = spawn(
        "powershell.exe",
        [
          "-NoLogo",
          "-NoProfile",
          "-NonInteractive",
          "-ExecutionPolicy",
          "Bypass",
          "-File",
          scriptPath,
        ],
        { windowsHide: true, stdio: ["pipe", "ignore", "pipe"] },
      );
      let stderr = "";
      child.stderr.setEncoding("utf8");
      child.stderr.on("data", (chunk: string) => {
        stderr += chunk;
      });
      child.on("error", () => {
        rejectPromise(
          new ServiceUnavailableException(
            "Unable to save Google Drive credentials with Windows DPAPI.",
          ),
        );
      });
      child.on("close", (code) => {
        if (code !== 0) {
          rejectPromise(
            new ServiceUnavailableException(
              stderr.includes("credential store")
                ? "The local Google Drive credential store was not found. Configure the OAuth client and restart the backend."
                : "The Google Drive refresh token could not be stored securely.",
            ),
          );
          return;
        }
        resolvePromise();
      });
      child.stdin.end(JSON.stringify({ refreshToken }), "utf8");
    });
  }

  private assertClientConfigured(): void {
    if (
      !process.env.SAKHI_GOOGLE_DRIVE_CLIENT_ID?.trim() ||
      !process.env.SAKHI_GOOGLE_DRIVE_CLIENT_SECRET?.trim()
    ) {
      throw new ServiceUnavailableException(
        "Google Drive OAuth is not configured. Run backend/scripts/Set-GoogleDriveCredentials.ps1 and restart the dev backend.",
      );
    }
  }

  private clientId(): string {
    return process.env.SAKHI_GOOGLE_DRIVE_CLIENT_ID?.trim() ?? "";
  }

  private clientSecret(): string {
    return process.env.SAKHI_GOOGLE_DRIVE_CLIENT_SECRET?.trim() ?? "";
  }

  private rootFolderName(): string {
    return process.env.SAKHI_GOOGLE_DRIVE_ROOT_FOLDER?.trim() || "Sakhi Media";
  }

  private redirectUri(): string {
    return (
      process.env.SAKHI_GOOGLE_DRIVE_REDIRECT_URI?.trim() ||
      `http://127.0.0.1:${process.env.PORT?.trim() || "3001"}/api/v1/integrations/google-drive/callback`
    );
  }

  private sanitizeSegment(raw: string, fallback: string): string {
    const cleaned = (raw ?? "")
      .trim()
      .replace(/[^a-zA-Z0-9_-]/g, "_")
      .slice(0, 80);
    return cleaned.length > 0 ? cleaned : fallback;
  }

  private safeFileName(fileName: string): string {
    const normalized = fileName
      .replace(/[\\/]/g, "_")
      .replace(/[^a-zA-Z0-9._-]/g, "_");
    const trimmed = normalized.slice(-100);
    return trimmed && trimmed !== "." ? trimmed : "image";
  }
}
