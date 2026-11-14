import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
  Query,
  Res,
  UseGuards,
  UnauthorizedException,
} from "@nestjs/common";
import type { Response } from "express";
import { DevelopmentMemberStateDto } from "./admin-member-state.dto.js";
import { ManualEligibilityDecisionDto } from "./admin-review.dto.js";
import { AdminReviewService } from "./admin-review.service.js";
import { AdminStaffSessionGuard } from "../admin-security/admin-staff-session.guard.js";

function pickAdminToken(stagingSession?: string): string | undefined {
  return stagingSession?.trim() || undefined;
}

@UseGuards(AdminStaffSessionGuard)
@Controller("admin-review")
export class AdminReviewController {
  constructor(private readonly adminReview: AdminReviewService) {}

  @Post("auth/login")
  @HttpCode(200)
  async loginWithCredentials(
    @Body() body: Record<string, unknown>,
    @Headers("origin") origin: string | undefined,
    @Res({ passthrough: true }) response: Response,
  ) {
    if (
      process.env.SAKHI_ENV === "staging" &&
      process.env.NODE_ENV === "production"
    ) {
      const allowedOrigins = String(process.env.SAKHI_ADMIN_CORS_ORIGIN ?? "")
        .split(",")
        .map((value) => value.trim())
        .filter(Boolean);
      if (!origin || !allowedOrigins.includes(origin)) {
        throw new UnauthorizedException(
          "The admin login origin is not allowed.",
        );
      }
    }
    const result = await this.adminReview.loginWithCredentials(body as any);
    const secure = process.env.NODE_ENV === "production";
    const sameSite = secure ? "None; Secure" : "Lax";
    const maxAge = Math.max(
      0,
      Math.floor(
        (new Date(result.sessionExpiresAt).getTime() - Date.now()) / 1000,
      ),
    );
    response.setHeader("Set-Cookie", [
      `sakhi_admin_session=${encodeURIComponent(result.sessionToken)}; HttpOnly; Path=/api/v1; Max-Age=${maxAge}; SameSite=${sameSite}`,
      `sakhi_admin_csrf=${encodeURIComponent(result.csrfToken)}; Path=/api/v1; Max-Age=${maxAge}; SameSite=${sameSite}`,
    ]);
    const { sessionToken: _sessionToken, ...safeResult } = result;
    return safeResult;
  }

  @Post("auth/logout")
  @HttpCode(200)
  async logoutAdminSession(
    @Headers("x-sakhi-staging-admin-session") sessionToken: string | undefined,
    @Res({ passthrough: true }) response: Response,
  ) {
    const result = await this.adminReview.logoutAdminSession(sessionToken);
    const secure =
      process.env.NODE_ENV === "production"
        ? "; SameSite=None; Secure"
        : "; SameSite=Lax";
    response.setHeader("Set-Cookie", [
      `sakhi_admin_session=; HttpOnly; Path=/api/v1; Max-Age=0${secure}`,
      `sakhi_admin_csrf=; Path=/api/v1; Max-Age=0${secure}`,
    ]);
    return result;
  }

  @Post("auth/password/change")
  @HttpCode(200)
  async changeOwnPassword(
    @Body() body: { newPassword?: string },
    @Headers("x-sakhi-staging-admin-session") sessionToken: string | undefined,
    @Res({ passthrough: true }) response: Response,
  ) {
    const result = await this.adminReview.changeOwnAdminPassword(
      body,
      pickAdminToken(sessionToken),
    );
    const secure =
      process.env.NODE_ENV === "production"
        ? "; SameSite=None; Secure"
        : "; SameSite=Lax";
    response.setHeader("Set-Cookie", [
      `sakhi_admin_session=; HttpOnly; Path=/api/v1; Max-Age=0${secure}`,
      `sakhi_admin_csrf=; Path=/api/v1; Max-Age=0${secure}`,
    ]);
    return result;
  }

  @Get("session")
  session(
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.session(pickAdminToken(stagingSessionToken));
  }

  @Get("rbac-profile")
  rbacProfile(
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.rbacProfile(pickAdminToken(stagingSessionToken));
  }

  @Get("staff")
  listAdminStaff(
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.listAdminStaff(pickAdminToken(stagingSessionToken));
  }

  @Post("staff")
  @HttpCode(201)
  createAdminStaff(
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.createAdminStaff(
      body as any,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Patch("staff/:staffId")
  updateAdminStaff(
    @Param("staffId") staffId: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.updateAdminStaff(
      staffId,
      body as any,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Delete("staff/:staffId")
  deleteAdminStaff(
    @Param("staffId") staffId: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.deleteAdminStaff(
      staffId,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Get("platform-config")
  getPlatformConfig(
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.getPlatformConfig(
      pickAdminToken(stagingSessionToken),
    );
  }

  @Put("platform-config")
  updatePlatformConfig(
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.updatePlatformConfig(
      body,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Get("businesses")
  listBusinesses(
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.listBusinesses(pickAdminToken(stagingSessionToken));
  }

  @Post("businesses")
  @HttpCode(201)
  upsertBusiness(
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.upsertBusiness(
      body,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Patch("businesses/:businessId/review")
  reviewBusiness(
    @Param("businessId") businessId: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.reviewBusiness(
      businessId,
      body,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Delete("businesses/:businessId")
  deleteBusiness(
    @Param("businessId") businessId: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.deleteBusiness(
      businessId,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Get("registration-policy")
  getRegistrationPolicy(
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.getRegistrationPolicy(
      pickAdminToken(stagingSessionToken),
    );
  }

  @Put("registration-policy")
  updateRegistrationPolicy(
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.updateRegistrationPolicy(
      body,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Get("queue")
  queue(
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.queue(pickAdminToken(stagingSessionToken));
  }

  @Get("history")
  history(
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.history(pickAdminToken(stagingSessionToken));
  }

  @Get("audit-events")
  auditEvents(
    @Headers("x-sakhi-staging-admin-session") sessionToken?: string,
    @Query("limit") limit?: string,
  ) {
    return this.adminReview.listAuditEvents(sessionToken, limit);
  }

  @Get("members")
  members(
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
    @Query("page") page?: string,
    @Query("pageSize") pageSize?: string,
    @Query("search") search?: string,
    @Query("accountStatus") accountStatus?: string,
    @Query("verificationStatus") verificationStatus?: string,
  ) {
    return this.adminReview.members(
      pickAdminToken(stagingSessionToken),
      page,
      pageSize,
      search,
      accountStatus,
      verificationStatus,
    );
  }

  @Post("members")
  @HttpCode(201)
  createMember(
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.createMember(
      body,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Get("members/:accountId")
  memberDetail(
    @Param("accountId", new ParseUUIDPipe()) accountId: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.getMember360Detail(
      accountId,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Patch("members/:accountId/state")
  updateMemberState(
    @Param("accountId", new ParseUUIDPipe()) accountId: string,
    @Body() dto: DevelopmentMemberStateDto,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.updateMemberState(
      accountId,
      dto,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Post("members/:accountId/state")
  @HttpCode(201)
  updateMemberStatePost(
    @Param("accountId", new ParseUUIDPipe()) accountId: string,
    @Body() dto: DevelopmentMemberStateDto,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.updateMemberState(
      accountId,
      dto,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Patch("members/:accountId/eligibility-override")
  overrideMemberEligibility(
    @Param("accountId", new ParseUUIDPipe()) accountId: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.overrideMemberEligibilityAndState(
      accountId,
      body,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Post("members/:accountId/eligibility-override")
  @HttpCode(200)
  overrideMemberEligibilityPost(
    @Param("accountId", new ParseUUIDPipe()) accountId: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.overrideMemberEligibilityAndState(
      accountId,
      body,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Post("submissions/:submissionId/decision")
  @HttpCode(200)
  decide(
    @Param("submissionId", new ParseUUIDPipe()) submissionId: string,
    @Body() dto: ManualEligibilityDecisionDto,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.decide(
      submissionId,
      dto,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Post("seed-live")
  @HttpCode(200)
  seedLiveData(
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.seedLiveData(pickAdminToken(stagingSessionToken));
  }

  @Get("community")
  communityOverview(
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.communityOverview(
      pickAdminToken(stagingSessionToken),
    );
  }

  @Post("community/posts")
  @HttpCode(201)
  createAdminPost(
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.createAdminPost(
      body,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Delete("community/posts/:postId")
  deleteAdminPost(
    @Param("postId") postId: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.deleteAdminPost(
      postId,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Put("categories/:slug")
  updateCategoryConfig(
    @Param("slug") slug: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.updateCategoryConfig(
      slug,
      body,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Post("moderation/reports/:reportId/decision")
  @HttpCode(200)
  resolveReport(
    @Param("reportId") reportId: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.resolveReport(
      reportId,
      body,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Post("reports/:reportId/resolve")
  @HttpCode(200)
  resolveReportAlias(
    @Param("reportId") reportId: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.resolveReport(
      reportId,
      body,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Patch("moderation/reports/:reportId/triage")
  triageReport(
    @Param("reportId") reportId: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.triageReport(
      reportId,
      body,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Patch("reports/:reportId/triage")
  triageReportAlias(
    @Param("reportId") reportId: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.triageReport(
      reportId,
      body,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Get("moderation/reports/:reportId")
  getReportDetail(
    @Param("reportId") reportId: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.getReportDetail(
      reportId,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Get("media/:uploadId/preview")
  async previewMediaForModeration(
    @Param("uploadId") uploadId: string,
    @Res() response: Response,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    const resolvedToken = pickAdminToken(stagingSessionToken);
    const media = await this.adminReview.previewReportedMedia(
      uploadId,
      resolvedToken,
    );
    response.setHeader("Content-Type", media.contentType);
    response.setHeader("Cache-Control", "private, no-store, max-age=0");
    response.setHeader("X-Content-Type-Options", "nosniff");
    return response.status(200).send(media.buffer);
  }

  @Get("wellness-resources")
  listWellnessResources(
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.listWellnessResources(
      pickAdminToken(stagingSessionToken),
    );
  }

  @Post("wellness-resources")
  @HttpCode(201)
  upsertWellnessResource(
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.upsertWellnessResource(
      body,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Delete("wellness-resources/:resourceId")
  deleteWellnessResource(
    @Param("resourceId") resourceId: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.deleteWellnessResource(
      resourceId,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Post("moderation/posts/:postId/action")
  @HttpCode(200)
  moderatePost(
    @Param("postId") postId: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.moderatePost(
      postId,
      body,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Post("moderation/comments/:commentId/action")
  @HttpCode(200)
  moderateComment(
    @Param("commentId") commentId: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.moderateComment(
      commentId,
      body,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Get("operations")
  operationsOverview(
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.operationsOverview(
      pickAdminToken(stagingSessionToken),
    );
  }

  @Get("safety-console")
  safetyConsoleOverview(
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.safetyConsoleOverview(
      pickAdminToken(stagingSessionToken),
    );
  }

  @Post("police-stations")
  @HttpCode(201)
  upsertPoliceStation(
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.upsertPoliceStation(
      body,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Post("police-stations/sync-osm")
  @HttpCode(200)
  syncPoliceStationsFromOsm(
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.syncPoliceStationsFromOsm(
      body,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Delete("police-stations/:stationCode")
  deletePoliceStation(
    @Param("stationCode") stationCode: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.deletePoliceStation(
      stationCode,
      pickAdminToken(stagingSessionToken),
    );
  }

  @Post("sos-events/:eventId/review")
  @HttpCode(200)
  reviewSosEvent(
    @Param("eventId") eventId: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.reviewSosEvent(
      eventId,
      body,
      pickAdminToken(stagingSessionToken),
    );
  }
}
