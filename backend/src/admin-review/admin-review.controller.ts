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
} from "@nestjs/common";
import { DevelopmentMemberStateDto } from "./admin-member-state.dto.js";
import { ManualEligibilityDecisionDto } from "./admin-review.dto.js";
import { AdminReviewService } from "./admin-review.service.js";

function pickAdminToken(
  primary?: string,
  fallback?: string,
  stagingSession?: string,
): string | undefined {
  return (
    primary?.trim() ||
    fallback?.trim() ||
    stagingSession?.trim() ||
    undefined
  );
}

@Controller("admin-review")
export class AdminReviewController {
  constructor(private readonly adminReview: AdminReviewService) {}

  @Get("session")
  session(
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.session(
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Get("registration-policy")
  getRegistrationPolicy(
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.getRegistrationPolicy(
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Put("registration-policy")
  updateRegistrationPolicy(
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.updateRegistrationPolicy(
      body,
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Get("queue")
  queue(
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.queue(
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Get("history")
  history(
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.history(
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Get("members")
  members(
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
    @Query("page") page?: string,
    @Query("pageSize") pageSize?: string,
    @Query("search") search?: string,
    @Query("accountStatus") accountStatus?: string,
    @Query("verificationStatus") verificationStatus?: string,
  ) {
    return this.adminReview.members(
      pickAdminToken(token, altToken, stagingSessionToken),
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
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.createMember(
      body,
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Get("members/:accountId")
  memberDetail(
    @Param("accountId", new ParseUUIDPipe()) accountId: string,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.getMember360Detail(
      accountId,
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Patch("members/:accountId/state")
  updateMemberState(
    @Param("accountId", new ParseUUIDPipe()) accountId: string,
    @Body() dto: DevelopmentMemberStateDto,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.updateMemberState(
      accountId,
      dto,
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Post("members/:accountId/state")
  @HttpCode(201)
  updateMemberStatePost(
    @Param("accountId", new ParseUUIDPipe()) accountId: string,
    @Body() dto: DevelopmentMemberStateDto,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.updateMemberState(
      accountId,
      dto,
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Patch("members/:accountId/eligibility-override")
  overrideMemberEligibility(
    @Param("accountId", new ParseUUIDPipe()) accountId: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.overrideMemberEligibilityAndState(
      accountId,
      body,
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Post("members/:accountId/eligibility-override")
  @HttpCode(200)
  overrideMemberEligibilityPost(
    @Param("accountId", new ParseUUIDPipe()) accountId: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.overrideMemberEligibilityAndState(
      accountId,
      body,
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Post("submissions/:submissionId/decision")
  @HttpCode(200)
  decide(
    @Param("submissionId", new ParseUUIDPipe()) submissionId: string,
    @Body() dto: ManualEligibilityDecisionDto,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.decide(
      submissionId,
      dto,
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Post("seed-live")
  @HttpCode(200)
  seedLiveData(
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.seedLiveData(
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Get("community")
  communityOverview(
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.communityOverview(
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Post("community/posts")
  @HttpCode(201)
  createAdminPost(
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.createAdminPost(
      body,
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Delete("community/posts/:postId")
  deleteAdminPost(
    @Param("postId") postId: string,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.deleteAdminPost(
      postId,
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Put("categories/:slug")
  updateCategoryConfig(
    @Param("slug") slug: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.updateCategoryConfig(
      slug,
      body,
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Post("moderation/reports/:reportId/decision")
  @HttpCode(200)
  resolveReport(
    @Param("reportId") reportId: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.resolveReport(
      reportId,
      body,
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Post("moderation/posts/:postId/action")
  @HttpCode(200)
  moderatePost(
    @Param("postId") postId: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.moderatePost(
      postId,
      body,
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Post("moderation/comments/:commentId/action")
  @HttpCode(200)
  moderateComment(
    @Param("commentId") commentId: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.moderateComment(
      commentId,
      body,
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Get("operations")
  operationsOverview(
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.operationsOverview(
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Get("safety-console")
  safetyConsoleOverview(
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.safetyConsoleOverview(
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Post("police-stations")
  @HttpCode(201)
  upsertPoliceStation(
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.upsertPoliceStation(
      body,
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }

  @Post("sos-events/:eventId/review")
  @HttpCode(200)
  reviewSosEvent(
    @Param("eventId") eventId: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.adminReview.reviewSosEvent(
      eventId,
      body,
      pickAdminToken(token, altToken, stagingSessionToken),
    );
  }
}
