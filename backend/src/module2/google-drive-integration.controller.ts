import { Controller, Get, Query, Res } from "@nestjs/common";
import type { Response } from "express";
import { GoogleDriveStorageService } from "./google-drive-storage.service.js";

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
      await this.googleDrive.completeAuthorization(code, state);
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
