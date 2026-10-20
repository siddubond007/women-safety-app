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

function pickAdminToken(primary?: string, fallback?: string): string | undefined {
  return primary?.trim() || fallback?.trim() || undefined;
}

@Controller("admin-review")
export class AdminReviewController {
  constructor(private readonly adminReview: AdminReviewService) {}

  @Get("session")
  session(
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
  ) {
    return this.adminReview.session(pickAdminToken(token, altToken));
  }

  @Get("queue")
  queue(
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
  ) {
    return this.adminReview.queue(pickAdminToken(token, altToken));
  }

  @Get("members")
  members(
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Query("page") page?: string,
    @Query("pageSize") pageSize?: string,
    @Query("search") search?: string,
    @Query("accountStatus") accountStatus?: string,
    @Query("verificationStatus") verificationStatus?: string,
  ) {
    return this.adminReview.members(
      pickAdminToken(token, altToken),
      page,
      pageSize,
      search,
      accountStatus,
      verificationStatus,
    );
  }

  @Post("members/create")
  @HttpCode(201)
  createMember(
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
  ) {
    return this.adminReview.createMember(body, pickAdminToken(token, altToken));
  }

  @Patch("members/:accountId/state")
  updateMemberState(
    @Param("accountId", new ParseUUIDPipe()) accountId: string,
    @Body() dto: DevelopmentMemberStateDto,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
  ) {
    return this.adminReview.updateMemberState(
      accountId,
      dto,
      pickAdminToken(token, altToken),
    );
  }

  @Post("submissions/:submissionId/decision")
  @HttpCode(200)
  decide(
    @Param("submissionId", new ParseUUIDPipe()) submissionId: string,
    @Body() dto: ManualEligibilityDecisionDto,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
  ) {
    return this.adminReview.decide(
      submissionId,
      dto,
      pickAdminToken(token, altToken),
    );
  }

  @Post("seed-live-data")
  @HttpCode(200)
  seedLiveData(
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
  ) {
    return this.adminReview.seedLiveData(pickAdminToken(token, altToken));
  }

  @Get("community")
  communityOverview(
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
  ) {
    return this.adminReview.communityOverview(pickAdminToken(token, altToken));
  }

  @Post("community/posts")
  @HttpCode(201)
  createAdminPost(
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
  ) {
    return this.adminReview.createAdminPost(body, pickAdminToken(token, altToken));
  }

  @Delete("community/posts/:postId")
  deleteAdminPost(
    @Param("postId") postId: string,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
  ) {
    return this.adminReview.deleteAdminPost(postId, pickAdminToken(token, altToken));
  }

  @Put("categories/:slug")
  updateCategoryConfig(
    @Param("slug") slug: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
  ) {
    return this.adminReview.updateCategoryConfig(
      slug,
      body,
      pickAdminToken(token, altToken),
    );
  }

  @Post("reports/:reportId/resolve")
  @HttpCode(200)
  resolveReport(
    @Param("reportId") reportId: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
  ) {
    return this.adminReview.resolveReport(
      reportId,
      body,
      pickAdminToken(token, altToken),
    );
  }

  @Post("posts/:postId/moderate")
  @HttpCode(200)
  moderatePost(
    @Param("postId") postId: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
  ) {
    return this.adminReview.moderatePost(
      postId,
      body,
      pickAdminToken(token, altToken),
    );
  }

  @Post("comments/:commentId/moderate")
  @HttpCode(200)
  moderateComment(
    @Param("commentId") commentId: string,
    @Body() body: Record<string, unknown>,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
  ) {
    return this.adminReview.moderateComment(
      commentId,
      body,
      pickAdminToken(token, altToken),
    );
  }

  @Get("operations")
  operationsOverview(
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
  ) {
    return this.adminReview.operationsOverview(pickAdminToken(token, altToken));
  }
}
