import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
} from "@nestjs/common";
import {
  StagingTestAccessDecisionDto,
  StagingTestAdminLoginDto,
} from "./staging-test-admin.dto.js";
import { StagingTestAdminService } from "./staging-test-admin.service.js";

const SESSION_HEADER = "x-sakhi-staging-admin-session";

@Controller("staging-test-admin")
export class StagingTestAdminController {
  constructor(private readonly stagingAdmin: StagingTestAdminService) {}

  @Post("session")
  @HttpCode(200)
  login(
    @Body() dto: StagingTestAdminLoginDto,
    @Headers("origin") origin: string | undefined,
  ) {
    this.stagingAdmin.assertAdminOrigin(origin);
    const session = this.stagingAdmin.session(dto.token);
    const sessionToken = this.stagingAdmin.createSessionToken(dto.token);
    return {
      ...session,
      sessionToken: sessionToken.value,
      sessionExpiresAt: sessionToken.expiresAt.toISOString(),
    };
  }

  @Get("session")
  session(
    @Headers(SESSION_HEADER) sessionToken?: string,
    @Headers("origin") origin?: string,
  ) {
    this.stagingAdmin.assertAdminOrigin(origin);
    return this.stagingAdmin.sessionFromToken(sessionToken);
  }

  @Post("logout")
  @HttpCode(200)
  logout(@Headers("origin") origin: string | undefined) {
    this.stagingAdmin.assertAdminOrigin(origin);
    return { signedOut: true };
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
