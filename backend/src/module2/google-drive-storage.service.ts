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
};

@Injectable()
export class GoogleDriveStorageService {
  private readonly pendingStates = new Map<string, number>();
  private rootFolderId: string | null = null;

  status() {
    return {
      provider: "google_drive",
      configured: Boolean(
        process.env.SAKHI_GOOGLE_DRIVE_CLIENT_ID?.trim() &&
          process.env.SAKHI_GOOGLE_DRIVE_CLIENT_SECRET?.trim(),
      ),
      connected: Boolean(process.env.SAKHI_GOOGLE_DRIVE_REFRESH_TOKEN?.trim()),
      scope: DRIVE_SCOPE,
      storageFolder: "Sakhi Media",
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

  async completeAuthorization(code: string, state: string): Promise<void> {
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
      // Never include the token endpoint response in the exception or logs.
      throw new ServiceUnavailableException(
        "Google did not return an offline refresh token. Reconnect and approve the requested Drive access.",
      );
    }

    await this.persistRefreshToken(token.refresh_token);
    process.env.SAKHI_GOOGLE_DRIVE_REFRESH_TOKEN = token.refresh_token;
    this.rootFolderId = null;
  }

  async uploadImage(input: {
    uploadId: string;
    accountId: string;
    purpose: "avatar" | "post";
    fileName: string;
    contentType: "image/jpeg" | "image/png" | "image/webp";
    buffer: Buffer;
  }): Promise<{ driveFileId: string; storedName: string; size: number }> {
    if (input.buffer.length === 0) {
      throw new ServiceUnavailableException("The selected image is empty.");
    }
    const accessToken = await this.getAccessToken();
    const parentId = await this.ensureRootFolder(accessToken);
    const safeFileName = this.safeFileName(input.fileName);
    const storedName = `${input.purpose}_${input.accountId.slice(0, 8)}_${input.uploadId}_${safeFileName}`;
    const metadata = {
      name: storedName,
      mimeType: input.contentType,
      parents: [parentId],
      appProperties: {
        sakhiUploadId: input.uploadId,
        sakhiPurpose: input.purpose,
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
        "Google Drive could not store the image. Check the Drive API and authorized account, then retry.",
      );
    }
    return {
      driveFileId: file.id,
      storedName: file.name ?? storedName,
      size: Number(file.size ?? input.buffer.length),
    };
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
    const query = "name = 'Sakhi Media' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
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
        name: "Sakhi Media",
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
    if (!process.env.SAKHI_GOOGLE_DRIVE_CLIENT_ID?.trim() ||
        !process.env.SAKHI_GOOGLE_DRIVE_CLIENT_SECRET?.trim()) {
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

  private redirectUri(): string {
    return (
      process.env.SAKHI_GOOGLE_DRIVE_REDIRECT_URI?.trim() ||
      `http://127.0.0.1:${process.env.PORT?.trim() || "3001"}/api/v1/integrations/google-drive/callback`
    );
  }

  private safeFileName(fileName: string): string {
    const normalized = fileName.replace(/[\\/]/g, "_").replace(/[^a-zA-Z0-9._-]/g, "_");
    const trimmed = normalized.slice(-100);
    return trimmed && trimmed !== "." ? trimmed : "image";
  }
}
