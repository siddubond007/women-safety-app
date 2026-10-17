import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
  Query,
} from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { Module2Service } from "./module2.service.js";
import {
  CreateBusinessProfileDto,
  CreatePostCommentDto,
  CreatePostDto,
  DeactivateAccountDto,
  ReportMemberDto,
  RequestAccountDeletionDto,
  UpdateNotificationPreferencesDto,
  UpdatePrivacySettingsDto,
  UpdateProfileDto,
} from "./module2.dto.js";

@ApiTags("module-2-profile-community")
@ApiBearerAuth()
@Controller("module2")
export class Module2Controller {
  constructor(private readonly module2: Module2Service) {}

  @Get("profile")
  getProfile(@Headers("authorization") authorization?: string) {
    return this.module2.getProfile(authorization);
  }

  @Patch("profile")
  updateProfile(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: UpdateProfileDto,
  ) {
    return this.module2.updateProfile(authorization, dto);
  }

  @Get("discover")
  discover(
    @Headers("authorization") authorization: string | undefined,
    @Query("q") query?: string,
    @Query("limit") limit?: string,
  ) {
    return this.module2.getDiscover(authorization, query ?? "", limit);
  }

  @Get("members/:accountId")
  getMemberProfile(
    @Headers("authorization") authorization: string | undefined,
    @Param("accountId", new ParseUUIDPipe({ version: "4" })) accountId: string,
  ) {
    return this.module2.getMemberProfile(authorization, accountId);
  }

  @Get("feed")
  getFeed(
    @Headers("authorization") authorization: string | undefined,
    @Query("q") query?: string,
    @Query("cursor") cursor?: string,
    @Query("limit") limit?: string,
  ) {
    return this.module2.listPosts(authorization, { query, cursor, limit });
  }

  @Get("posts")
  getPosts(
    @Headers("authorization") authorization: string | undefined,
    @Query("accountId") accountId?: string,
    @Query("q") query?: string,
    @Query("cursor") cursor?: string,
    @Query("limit") limit?: string,
  ) {
    return this.module2.listPosts(authorization, { accountId, query, cursor, limit });
  }

  @Post("posts")
  createPost(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: CreatePostDto,
  ) {
    return this.module2.createPost(authorization, dto);
  }

  @Get("posts/saved")
  getSavedPosts(@Headers("authorization") authorization?: string) {
    return this.module2.listSavedPosts(authorization);
  }

  @Post("posts/:postId/like")
  likePost(
    @Headers("authorization") authorization: string | undefined,
    @Param("postId", new ParseUUIDPipe({ version: "4" })) postId: string,
  ) {
    return this.module2.setPostLike(authorization, postId, true);
  }

  @Delete("posts/:postId/like")
  unlikePost(
    @Headers("authorization") authorization: string | undefined,
    @Param("postId", new ParseUUIDPipe({ version: "4" })) postId: string,
  ) {
    return this.module2.setPostLike(authorization, postId, false);
  }

  @Post("posts/:postId/bookmark")
  bookmarkPost(
    @Headers("authorization") authorization: string | undefined,
    @Param("postId", new ParseUUIDPipe({ version: "4" })) postId: string,
  ) {
    return this.module2.setPostBookmark(authorization, postId, true);
  }

  @Delete("posts/:postId/bookmark")
  removeBookmark(
    @Headers("authorization") authorization: string | undefined,
    @Param("postId", new ParseUUIDPipe({ version: "4" })) postId: string,
  ) {
    return this.module2.setPostBookmark(authorization, postId, false);
  }

  @Get("posts/:postId/comments")
  listComments(
    @Headers("authorization") authorization: string | undefined,
    @Param("postId", new ParseUUIDPipe({ version: "4" })) postId: string,
  ) {
    return this.module2.listComments(authorization, postId);
  }

  @Post("posts/:postId/comments")
  createComment(
    @Headers("authorization") authorization: string | undefined,
    @Param("postId", new ParseUUIDPipe({ version: "4" })) postId: string,
    @Body() dto: CreatePostCommentDto,
  ) {
    return this.module2.createComment(authorization, postId, dto);
  }

  @Delete("comments/:commentId")
  deleteComment(
    @Headers("authorization") authorization: string | undefined,
    @Param("commentId", new ParseUUIDPipe({ version: "4" })) commentId: string,
  ) {
    return this.module2.deleteComment(authorization, commentId);
  }

  @Get("followers")
  getFollowers(
    @Headers("authorization") authorization: string | undefined,
    @Query("direction") direction?: string,
    @Query("q") query?: string,
    @Query("limit") limit?: string,
  ) {
    if (direction !== undefined && direction !== "followers" && direction !== "following") {
      throw new TypeError('direction must be "followers" or "following".');
    }
    return this.module2.listFollowers(
      authorization,
      direction === "following" ? "following" : "followers",
      query ?? "",
      limit,
    );
  }

  @Post("members/:accountId/follow")
  followMember(
    @Headers("authorization") authorization: string | undefined,
    @Param("accountId", new ParseUUIDPipe({ version: "4" })) accountId: string,
  ) {
    return this.module2.followMember(authorization, accountId);
  }

  @Delete("members/:accountId/follow")
  unfollowMember(
    @Headers("authorization") authorization: string | undefined,
    @Param("accountId", new ParseUUIDPipe({ version: "4" })) accountId: string,
  ) {
    return this.module2.unfollowMember(authorization, accountId);
  }

  @Get("privacy-settings")
  getPrivacySettings(@Headers("authorization") authorization?: string) {
    return this.module2.getPrivacySettings(authorization);
  }

  @Patch("privacy-settings")
  updatePrivacySettings(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: UpdatePrivacySettingsDto,
  ) {
    return this.module2.updatePrivacySettings(authorization, dto);
  }

  @Get("notification-preferences")
  getNotificationPreferences(@Headers("authorization") authorization?: string) {
    return this.module2.getNotificationPreferences(authorization);
  }

  @Patch("notification-preferences")
  updateNotificationPreferences(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: UpdateNotificationPreferencesDto,
  ) {
    return this.module2.updateNotificationPreferences(authorization, dto);
  }

  @Get("blocks")
  listBlockedMembers(@Headers("authorization") authorization?: string) {
    return this.module2.listBlockedMembers(authorization);
  }

  @Post("blocks/:accountId")
  blockMember(
    @Headers("authorization") authorization: string | undefined,
    @Param("accountId", new ParseUUIDPipe({ version: "4" })) accountId: string,
  ) {
    return this.module2.blockMember(authorization, accountId);
  }

  @Delete("blocks/:accountId")
  unblockMember(
    @Headers("authorization") authorization: string | undefined,
    @Param("accountId", new ParseUUIDPipe({ version: "4" })) accountId: string,
  ) {
    return this.module2.unblockMember(authorization, accountId);
  }

  @Post("reports")
  reportMember(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: ReportMemberDto,
  ) {
    return this.module2.reportMember(authorization, dto);
  }

  @Get("business-profile")
  getBusinessProfile(@Headers("authorization") authorization?: string) {
    return this.module2.getBusinessProfile(authorization);
  }

  @Put("business-profile")
  upsertBusinessProfile(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: CreateBusinessProfileDto,
  ) {
    return this.module2.upsertBusinessProfile(authorization, dto);
  }

  @Get("sessions")
  listSessions(@Headers("authorization") authorization?: string) {
    return this.module2.listSessions(authorization);
  }

  @Delete("sessions/:sessionId")
  revokeSession(
    @Headers("authorization") authorization: string | undefined,
    @Param("sessionId", new ParseUUIDPipe({ version: "4" })) sessionId: string,
  ) {
    return this.module2.revokeSession(authorization, sessionId);
  }

  @Post("account/deactivate")
  deactivateAccount(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: DeactivateAccountDto,
  ) {
    if (dto.confirmation !== "DEACTIVATE") {
      throw new TypeError('confirmation must be "DEACTIVATE".');
    }
    return this.module2.deactivateAccount(authorization);
  }

  @Post("account/deletion-request")
  requestDeletion(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: RequestAccountDeletionDto,
  ) {
    return this.module2.requestAccountDeletion(authorization, dto);
  }
}
