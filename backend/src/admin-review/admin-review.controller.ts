import { Body, Controller, Get, Headers, Param, ParseUUIDPipe, Post, Query } from "@nestjs/common";
import { ApiHeader, ApiOkResponse, ApiTags } from "@nestjs/swagger";
import { AdminReviewService } from "./admin-review.service.js";
import { ManualEligibilityDecisionDto } from "./admin-review.dto.js";
import { DevelopmentMemberStateDto } from "./admin-member-state.dto.js";

@ApiTags("admin-review")
@ApiHeader({ name: "X-Sakhi-Admin-Token", required: true, description: "Shared reviewer token for local dev/test only. Never use this mechanism in production." })
@Controller("admin-review")
export class AdminReviewController {
  constructor(private readonly review: AdminReviewService) {}

  @Get("session")
  @ApiOkResponse({ description: "Validates local dev/test reviewer access." })
  session(@Headers("x-sakhi-admin-token") token?: string) {
    return this.review.session(token);
  }

  @Get("members")
  @ApiOkResponse({ description: "Lists persisted member accounts from the development database." })
  members(
    @Headers("x-sakhi-admin-token") token?: string,
    @Query("page") page?: string,
    @Query("pageSize") pageSize?: string,
    @Query("search") search?: string,
    @Query("accountStatus") accountStatus?: string,
    @Query("verificationStatus") verificationStatus?: string,
  ) {
    return this.review.members(token, page, pageSize, search, accountStatus, verificationStatus);
  }

  @Post("members/create")
  @ApiOkResponse({ description: "Creates a new database member account and community profile from Super Admin." })
  createMember(
    @Headers("x-sakhi-admin-token") token: string | undefined,
    @Body() body: Record<string, unknown>,
  ) {
    return this.review.createMember(body, token);
  }

  @Post("members/:accountId/state")
  @ApiOkResponse({ description: "Updates a member's persisted development account/verification state." })
  updateMemberState(
    @Headers("x-sakhi-admin-token") token: string | undefined,
    @Param("accountId", new ParseUUIDPipe({ version: "4" })) accountId: string,
    @Body() dto: DevelopmentMemberStateDto,
  ) {
    return this.review.updateMemberState(accountId, dto, token);
  }

  @Get("queue")
  @ApiOkResponse({ description: "Lists explicit pending manual-review submissions." })
  queue(@Headers("x-sakhi-admin-token") token?: string) {
    return this.review.queue(token);
  }

  @Get("history")
  @ApiOkResponse({ description: "Returns persisted manual-review decision history." })
  history(@Headers("x-sakhi-admin-token") token?: string) {
    return this.review.history(token);
  }

  @Post("submissions/:submissionId/decision")
  @ApiOkResponse({ description: "Records a decision for a pending manual-review submission." })
  decide(
    @Headers("x-sakhi-admin-token") token: string | undefined,
    @Param("submissionId", new ParseUUIDPipe({ version: "4" })) submissionId: string,
    @Body() dto: ManualEligibilityDecisionDto,
  ) {
    return this.review.decide(submissionId, dto, token);
  }

  @Post("seed-live-data")
  @ApiOkResponse({ description: "Populates/upserts rich live PostgreSQL users, posts, groups, and wellness items." })
  seedLiveData(@Headers("x-sakhi-admin-token") token?: string) {
    return this.review.seedLiveData(token);
  }

  @Get("community")
  @ApiOkResponse({ description: "Returns live PostgreSQL community posts, explore posts, and groups." })
  community(@Headers("x-sakhi-admin-token") token?: string) {
    return this.review.communityOverview(token);
  }

  @Post("community/posts")
  @ApiOkResponse({ description: "Creates a new live community/explore post in PostgreSQL." })
  createCommunityPost(
    @Headers("x-sakhi-admin-token") token: string | undefined,
    @Body() body: Record<string, unknown>,
  ) {
    return this.review.createAdminPost(body, token);
  }

  @Post("community/posts/:postId/delete")
  @ApiOkResponse({ description: "Deletes a community post from PostgreSQL." })
  deleteCommunityPost(
    @Headers("x-sakhi-admin-token") token: string | undefined,
    @Param("postId", new ParseUUIDPipe({ version: "4" })) postId: string,
  ) {
    return this.review.deleteAdminPost(postId, token);
  }

  @Get("operations")
  @ApiOkResponse({
    description:
      "Returns live PostgreSQL data for moderation reports, SOS events, wellness items, cloud media uploads, and audit logs.",
  })
  operations(@Headers("x-sakhi-admin-token") token?: string) {
    return this.review.operationsOverview(token);
  }
}
