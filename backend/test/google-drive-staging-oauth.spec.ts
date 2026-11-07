import { afterEach, describe, expect, it, vi } from "vitest";
import type { Response } from "express";
import { GoogleDriveIntegrationController } from "../src/module2/google-drive-integration.controller.js";
import { GoogleDriveStorageService } from "../src/module2/google-drive-storage.service.js";

const envKeys = [
  "SAKHI_GOOGLE_DRIVE_CLIENT_ID",
  "SAKHI_GOOGLE_DRIVE_CLIENT_SECRET",
  "SAKHI_GOOGLE_DRIVE_REFRESH_TOKEN",
  "SAKHI_GOOGLE_DRIVE_REDIRECT_URI",
  "SAKHI_GOOGLE_DRIVE_CLOUD_SETUP_ENABLED",
  "SAKHI_ENV",
  "NODE_ENV",
  "RENDER_SERVICE_ID",
] as const;

const originalEnv = new Map<string, string | undefined>();

function snapshotEnvironment() {
  originalEnv.clear();
  for (const key of envKeys) originalEnv.set(key, process.env[key]);
}

function restoreEnvironment() {
  for (const key of envKeys) {
    const original = originalEnv.get(key);
    if (original === undefined) delete process.env[key];
    else process.env[key] = original;
  }
}

afterEach(() => {
  restoreEnvironment();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe("Google Drive OAuth for Render staging", () => {
  it("returns a refresh-token handoff instead of attempting Windows DPAPI in staging", async () => {
    snapshotEnvironment();
    process.env.SAKHI_GOOGLE_DRIVE_CLIENT_ID =
      "sakhi-staging-test.apps.googleusercontent.com";
    process.env.SAKHI_GOOGLE_DRIVE_CLIENT_SECRET =
      "test-client-secret-not-real";
    delete process.env.SAKHI_GOOGLE_DRIVE_REFRESH_TOKEN;
    process.env.SAKHI_GOOGLE_DRIVE_REDIRECT_URI =
      "https://sakhi-staging-api.onrender.com/api/v1/integrations/google-drive/callback";
    process.env.SAKHI_GOOGLE_DRIVE_CLOUD_SETUP_ENABLED = "true";
    process.env.SAKHI_ENV = "staging";
    process.env.NODE_ENV = "production";
    process.env.RENDER_SERVICE_ID = "srv-dbc5s4dg1s2s7395oed0";

    const refreshToken = "1//synthetic-test-token-not-a-real-credential";
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        refresh_token: refreshToken,
        access_token: "synthetic-access-token",
        expires_in: 3600,
        token_type: "Bearer",
      }),
    });
    vi.stubGlobal("fetch", fetchMock);

    const drive = new GoogleDriveStorageService();
    const authUrl = new URL(drive.createAuthorizationUrl());
    const state = authUrl.searchParams.get("state");
    expect(state).toBeTruthy();

    const completion = await drive.completeAuthorization(
      "synthetic-authorization-code",
      state!,
    );

    expect(completion).toEqual({
      persistence: "render_environment",
      refreshToken,
    });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(process.env.SAKHI_GOOGLE_DRIVE_REFRESH_TOKEN).toBeUndefined();
  });

  it("returns the token only in a non-cacheable, escaped cloud setup page", async () => {
    const refreshToken = "token<&synthetic>";
    const drive = {
      completeAuthorization: vi.fn().mockResolvedValue({
        persistence: "render_environment",
        refreshToken,
      }),
    } as unknown as GoogleDriveStorageService;
    const controller = new GoogleDriveIntegrationController(drive);
    const response = {
      setHeader: vi.fn(),
      status: vi.fn().mockReturnThis(),
      type: vi.fn().mockReturnThis(),
      send: vi.fn().mockReturnThis(),
      redirect: vi.fn().mockReturnThis(),
    } as unknown as Response;

    await controller.callback(
      "synthetic-authorization-code",
      "synthetic-state",
      undefined,
      response,
    );

    expect(response.setHeader).toHaveBeenCalledWith(
      "Cache-Control",
      "no-store, no-cache, must-revalidate, private",
    );
    expect(response.setHeader).toHaveBeenCalledWith(
      "Referrer-Policy",
      "no-referrer",
    );
    const html = vi.mocked(response.send).mock.calls[0]?.[0] as string;
    expect(html).toContain("SAKHI_GOOGLE_DRIVE_REFRESH_TOKEN");
    expect(html).toContain("token&lt;&amp;synthetic&gt;");
    expect(html).not.toContain("token<&synthetic>");
    expect(html).toContain(
      "https://dashboard.render.com/web/srv-dbc5s4dg1s2s7395oed0",
    );
  });
});
