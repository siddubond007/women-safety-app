import { Controller, Get, Query, Res } from "@nestjs/common";
import type { Response } from "express";
import { GoogleDriveStorageService } from "./google-drive-storage.service.js";

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function renderEnvironmentSetupPage(refreshToken: string): string {
  const safeToken = escapeHtml(refreshToken);
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Sakhi Google Drive — Save staging credential</title>
  <style>
    body { font: 16px/1.55 system-ui, sans-serif; max-width: 760px; margin: 48px auto; padding: 0 20px; color: #28152e; }
    h1 { color: #572064; }
    .token { box-sizing: border-box; width: 100%; min-height: 110px; padding: 12px; }
    li { margin: 10px 0; }
    .warning { padding: 12px; background: #fff4e5; border-radius: 8px; }
  </style>
</head>
<body>
  <h1>Google Drive authorization completed</h1>
  <p>Google authorized the Sakhi staging API. Render cannot store credentials in the local Windows DPAPI vault, so one final manual step is required.</p>
  <ol>
    <li>Copy the entire refresh token below.</li>
    <li>Open the <a href="https://dashboard.render.com/web/srv-dbc5s4dg1s2s7395oed0">Sakhi staging API on Render</a> and open <strong>Environment</strong>.</li>
    <li>Set <code>SAKHI_GOOGLE_DRIVE_REFRESH_TOKEN</code> to the copied value and save the changes. Render will restart the API.</li>
    <li>After the restart, open <code>/api/v1/integrations/google-drive/status?verify=true</code> on the staging API. It should report <code>connected: true</code>.</li>
  </ol>
  <label for="refresh-token"><strong>Refresh token — handle as a password</strong></label>
  <textarea id="refresh-token" class="token" readonly spellcheck="false">${safeToken}</textarea>
  <p class="warning">Do not share this token, put it in source control, or send it in chat. This page is marked non-cacheable. Close it after copying the token into Render.</p>
</body>
</html>`;
}

@Controller("integrations/google-drive")
export class GoogleDriveIntegrationController {
  constructor(private readonly googleDrive: GoogleDriveStorageService) {}

  @Get("status")
  async status(@Query("verify") verify?: string) {
    if (verify === "true") {
      return this.googleDrive.verifyConnectionStatus(true);
    }
    return this.googleDrive.status();
  }

  @Get("connect")
  connect(@Res() response: Response) {
    return response.redirect(this.googleDrive.createAuthorizationUrl());
  }

  @Get("callback")
  async callback(
    @Query("code") code: string | undefined,
    @Query("state") state: string | undefined,
    @Query("error") oauthError: string | undefined,
    @Res() response: Response,
  ) {
    if (oauthError) {
      return response
        .status(400)
        .type("html")
        .send(
          "<!doctype html><html><head><title>Sakhi Drive</title></head><body><h1>Google Drive connection cancelled</h1><p>Return to the local Sakhi backend and start the connection again if needed.</p></body></html>",
        );
    }
    if (!code || !state) {
      return response
        .status(400)
        .type("html")
        .send(
          "<!doctype html><html><head><title>Sakhi Drive</title></head><body><h1>Google Drive connection failed</h1><p>The OAuth callback did not contain the required authorization response.</p></body></html>",
        );
    }
    try {
      const completion = await this.googleDrive.completeAuthorization(
        code,
        state,
      );
      if (completion.persistence === "render_environment") {
        response.setHeader(
          "Cache-Control",
          "no-store, no-cache, must-revalidate, private",
        );
        response.setHeader("Pragma", "no-cache");
        response.setHeader("Expires", "0");
        response.setHeader("Referrer-Policy", "no-referrer");
        response.setHeader("X-Content-Type-Options", "nosniff");
        response.setHeader("X-Frame-Options", "DENY");
        response.setHeader(
          "Content-Security-Policy",
          "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
        );
        return response
          .status(200)
          .type("html")
          .send(renderEnvironmentSetupPage(completion.refreshToken));
      }
      return response
        .status(200)
        .type("html")
        .send(
          "<!doctype html><html><head><title>Sakhi Drive connected</title></head><body style='font:16px system-ui;max-width:640px;margin:64px auto;padding:0 20px'><h1>Sakhi is connected to Google Drive</h1><p>Your Google Drive refresh token has been stored in the Windows DPAPI credential store for this Windows user. You may close this page and return to Sakhi.</p></body></html>",
        );
    } catch {
      return response
        .status(500)
        .type("html")
        .send(
          "<!doctype html><html><head><title>Sakhi Drive</title></head><body><h1>Google Drive connection could not be saved</h1><p>No credential details are shown here. Check the local backend terminal and reconnect after correcting the local configuration.</p></body></html>",
        );
    }
  }
}
