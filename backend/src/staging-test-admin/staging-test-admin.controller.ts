import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Req,
  Res,
  UseGuards,
} from "@nestjs/common";
import { randomBytes } from "node:crypto";
import type { Request, Response } from "express";
import {
  StagingTestAccessDecisionDto,
  StagingSyntheticFixtureDto,
  StagingTestAdminBootstrapDto,
  StagingTestAdminLoginDto,
} from "./staging-test-admin.dto.js";
import { StagingTestAdminService } from "./staging-test-admin.service.js";
import { AdminStaffSessionGuard } from "../admin-security/admin-staff-session.guard.js";

const SESSION_HEADER = "x-sakhi-staging-admin-session";
const SESSION_COOKIE = "sakhi_admin_session";
const CSRF_COOKIE = "sakhi_admin_csrf";
const COOKIE_PATH = "/api/v1";

function cookieValue(request: Request, name: string): string | undefined {
  const header = request.headers.cookie;
  if (!header) return undefined;
  for (const part of header.split(";")) {
    const separator = part.indexOf("=");
    if (separator >= 0 && part.slice(0, separator).trim() === name) {
      return decodeURIComponent(part.slice(separator + 1).trim());
    }
  }
  return undefined;
}

function cookieOptions(maxAgeSeconds: number): string {
  // The Admin UI and API are separate Render origins. Production fetches use
  // credentials: "include", so both cookies must be explicitly cross-site
  // capable; SameSite=Lax silently withholds them on these browser requests.
  if (process.env.NODE_ENV === "production") {
    return `Path=${COOKIE_PATH}; Max-Age=${Math.max(0, maxAgeSeconds)}; SameSite=None; Secure; Partitioned;`;
  }
  return `Path=${COOKIE_PATH}; Max-Age=${Math.max(0, maxAgeSeconds)}; SameSite=Lax;`;
}

function setStaffSessionCookies(
  response: Response,
  token: string,
  expiresAt: string,
  csrfToken: string,
): void {
  const maxAge = Math.floor(
    (new Date(expiresAt).getTime() - Date.now()) / 1000,
  );
  response.setHeader("Set-Cookie", [
    `${SESSION_COOKIE}=${encodeURIComponent(token)}; HttpOnly; ${cookieOptions(maxAge)}`,
    `${CSRF_COOKIE}=${encodeURIComponent(csrfToken)}; ${cookieOptions(maxAge)}`,
  ]);
}

function clearStaffSessionCookies(response: Response): void {
  response.setHeader("Set-Cookie", [
    `${SESSION_COOKIE}=; HttpOnly; ${cookieOptions(0)}`,
    `${CSRF_COOKIE}=; ${cookieOptions(0)}`,
  ]);
}

@UseGuards(AdminStaffSessionGuard)
@Controller("staging-test-admin")
export class StagingTestAdminController {
  constructor(private readonly stagingAdmin: StagingTestAdminService) {}

  @Post("session")
  @HttpCode(200)
  async login(
    @Body() dto: StagingTestAdminLoginDto,
    @Headers("origin") origin: string | undefined,
    @Res({ passthrough: true }) response: Response,
  ) {
    this.stagingAdmin.assertAdminOrigin(origin);
    const result = await this.stagingAdmin.loginWithToken(
      dto.token,
      dto.mfaCode,
    );
    if (
      result.authenticated &&
      result.sessionToken?.startsWith("staff-admin.")
    ) {
      const csrfToken = randomBytes(32).toString("base64url");
      setStaffSessionCookies(
        response,
        result.sessionToken,
        result.sessionExpiresAt,
        csrfToken,
      );
      const { sessionToken: _sessionToken, ...safeResult } = result;
      return { ...safeResult, csrfToken };
    }
    return result;
  }

  @Get("session")
  async session(
    @Headers(SESSION_HEADER) sessionToken: string | undefined,
    @Headers("origin") origin: string | undefined,
    @Req() request: Request,
  ) {
    this.stagingAdmin.assertAdminOrigin(origin);
    const result = await this.stagingAdmin.sessionFromToken(sessionToken);
    const csrfToken = cookieValue(request, CSRF_COOKIE);
    return { ...result, ...(csrfToken ? { csrfToken } : {}) };
  }

  @Post("logout")
  @HttpCode(200)
  async logout(
    @Headers(SESSION_HEADER) sessionToken: string | undefined,
    @Headers("origin") origin: string | undefined,
    @Res({ passthrough: true }) response: Response,
  ) {
    this.stagingAdmin.assertAdminOrigin(origin);
    const result = await this.stagingAdmin.logout(sessionToken);
    clearStaffSessionCookies(response);
    return result;
  }

  @Post("session/rotate")
  @HttpCode(200)
  async rotateSession(
    @Headers(SESSION_HEADER) sessionToken: string | undefined,
    @Headers("origin") origin: string | undefined,
    @Res({ passthrough: true }) response: Response,
  ) {
    this.stagingAdmin.assertAdminOrigin(origin);
    const rotated = await this.stagingAdmin.rotateStaffSession(sessionToken);
    const csrfToken = randomBytes(32).toString("base64url");
    setStaffSessionCookies(
      response,
      rotated.sessionToken,
      rotated.sessionExpiresAt,
      csrfToken,
    );
    return {
      rotated: true,
      sessionExpiresAt: rotated.sessionExpiresAt,
      csrfToken,
    };
  }

  @Post("bootstrap/super-admin")
  @HttpCode(200)
  bootstrapSuperAdmin(
    @Body() dto: StagingTestAdminBootstrapDto,
    @Headers("origin") origin: string | undefined,
  ) {
    this.stagingAdmin.assertAdminOrigin(origin);
    return this.stagingAdmin.bootstrapSuperAdmin(
      dto.token,
      dto.fullName,
      dto.email,
    );
  }

  @Post("staff-mfa/enroll")
  @HttpCode(200)
  startMfaEnrollment(
    @Body() body: { token: string },
    @Headers("origin") origin: string | undefined,
  ) {
    this.stagingAdmin.assertAdminOrigin(origin);
    return this.stagingAdmin.startStaffMfaEnrollment(body?.token);
  }

  @Post("staff-mfa/verify-enrollment")
  @HttpCode(200)
  verifyMfaEnrollment(
    @Body() body: { token: string; code: string },
    @Headers("origin") origin: string | undefined,
  ) {
    this.stagingAdmin.assertAdminOrigin(origin);
    return this.stagingAdmin.verifyStaffMfaEnrollment(body?.token, body?.code);
  }

  @Post("staff-mfa/recovery/request")
  @HttpCode(200)
  requestMfaRecovery(
    @Body() body: { token: string },
    @Headers("origin") origin: string | undefined,
  ) {
    this.stagingAdmin.assertAdminOrigin(origin);
    return this.stagingAdmin.requestStaffMfaRecovery(body?.token);
  }

  @Get("staff-mfa/recovery/pending")
  async listStaffMfaRecoveryRequests(
    @Headers(SESSION_HEADER) sessionToken: string | undefined,
    @Headers("origin") origin: string | undefined,
  ) {
    this.stagingAdmin.assertAdminOrigin(origin);
    return this.stagingAdmin.listStaffMfaRecoveryRequests(sessionToken);
  }

  @Post("staff-mfa/encryption-keys/rotate")
  @HttpCode(200)
  async rotateStaffMfaEncryptionKeys(
    @Headers(SESSION_HEADER) sessionToken: string | undefined,
    @Headers("origin") origin: string | undefined,
  ) {
    this.stagingAdmin.assertAdminOrigin(origin);
    return this.stagingAdmin.rotateStaffMfaEncryptionKeys(sessionToken);
  }

  @Post("staff-mfa/recovery/approve")
  @HttpCode(200)
  approveMfaRecovery(
    @Body() body: { requestId: string },
    @Headers(SESSION_HEADER) sessionToken: string | undefined,
    @Headers("origin") origin: string | undefined,
  ) {
    this.stagingAdmin.assertAdminOrigin(origin);
    return this.stagingAdmin.approveStaffMfaRecovery(
      body?.requestId,
      sessionToken,
    );
  }

  @Post("staff-mfa/recovery/complete")
  @HttpCode(200)
  completeMfaRecovery(
    @Body() body: { token: string; recoveryToken: string },
    @Headers("origin") origin: string | undefined,
  ) {
    this.stagingAdmin.assertAdminOrigin(origin);
    return this.stagingAdmin.completeStaffMfaRecovery(
      body?.token,
      body?.recoveryToken,
    );
  }

  @Post("synthetic-fixtures/member")
  @HttpCode(201)
  createSyntheticMemberFixture(
    @Body() dto: StagingSyntheticFixtureDto,
    @Headers(SESSION_HEADER) sessionToken?: string,
    @Headers("origin") origin?: string,
  ) {
    this.stagingAdmin.assertAdminOrigin(origin);
    return this.stagingAdmin.createSyntheticMemberFixture(dto, sessionToken);
  }

  @Get("accounts")
  accounts(
    @Headers(SESSION_HEADER) sessionToken?: string,
    @Headers("origin") origin?: string,
  ) {
    this.stagingAdmin.assertAdminOrigin(origin);
    return this.stagingAdmin.accounts(sessionToken);
  }

  @Post("accounts/:accountId/approve")
  approve(
    @Param("accountId", new ParseUUIDPipe()) accountId: string,
    @Body() dto: StagingTestAccessDecisionDto,
    @Headers(SESSION_HEADER) sessionToken?: string,
    @Headers("origin") origin?: string,
  ) {
    this.stagingAdmin.assertAdminOrigin(origin);
    return this.stagingAdmin.approve(accountId, dto, sessionToken);
  }

  @Post("accounts/:accountId/revoke")
  revoke(
    @Param("accountId", new ParseUUIDPipe()) accountId: string,
    @Body() dto: StagingTestAccessDecisionDto,
    @Headers(SESSION_HEADER) sessionToken?: string,
    @Headers("origin") origin?: string,
  ) {
    this.stagingAdmin.assertAdminOrigin(origin);
    return this.stagingAdmin.revoke(accountId, dto, sessionToken);
  }
}
