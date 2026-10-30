import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  Param,
  Patch,
  Post,
  Put,
  Query,
  Res,
  UploadedFile,
  UseInterceptors,
} from "@nestjs/common";
import { FileInterceptor } from "@nestjs/platform-express";
import type { Response } from "express";
import {
  CreateCommunityPostDto,
  CreateEmergencyContactDto,
  CreatePostCommentDto,
  EditCommunityPostDto,
  EditPostCommentDto,
  ReactToPostDto,
  RecordSafetyEventDto,
  StartLocationShareDto,
  UpdateEmergencyContactDto,
  ReportUserOrPostDto,
  RequestAccountDeletionDto,
  RequestMediaUploadDto,
  CreateBusinessEnquiryDto,
  ReplyBusinessEnquiryDto,
  ReportBusinessDto,
  ToggleBlockedUserDto,
  ToggleTwoFactorDto,
  UpdateAvatarDto,
  UpsertMemberBusinessDto,
  UpdateModule2ProfileDto,
  UpdateNotificationPreferenceDto,
  UpdatePrivacyPreferenceDto,
  UpdateSecurityPinDto,
  UploadBinaryMediaDto,
  UploadMediaObjectDto,
} from "./module2.dto.js";
import { Module2Service } from "./module2.service.js";

@Controller("module2")
export class Module2Controller {
  constructor(private readonly service: Module2Service) {}

  @Get("public-feed")
  publicFeed(@Headers("authorization") authorization?: string) {
    return this.service.publicFeed(authorization);
  }

  @Get("bootstrap")
  bootstrap(@Headers("authorization") authorization?: string) {
    return this.service.bootstrap(authorization);
  }

  @Get("categories")
  listCategories() {
    return this.service.listCategories();
  }

  @Get("nearby-circles")
  listNearbyCircles(
    @Headers("authorization") authorization?: string,
    @Query("lat") lat?: string,
    @Query("lng") lng?: string,
    @Query("radiusKm") radiusKm?: string,
    @Query("city") city?: string,
  ) {
    return this.service.listNearbyCircles(
      authorization,
      lat === undefined ? undefined : Number(lat),
      lng === undefined ? undefined : Number(lng),
      radiusKm === undefined ? 15 : Number(radiusKm),
      city,
    );
  }

  @Get("posts")
  listPosts(
    @Headers("authorization") authorization?: string,
    @Query("categorySlug") categorySlug?: string,
    @Query("topic") topic?: string,
    @Query("search") search?: string,
    @Query("savedOnly") savedOnly?: string,
    @Query("limit") limit?: string,
  ) {
    return this.service.listPosts(authorization, {
      categorySlug,
      topic,
      search,
      savedOnly: savedOnly === "true" || savedOnly === "1",
      limit: limit ? Number(limit) : undefined,
    });
  }

  @Get("username-availability")
  checkUsernameAvailability(
    @Headers("authorization") authorization: string | undefined,
    @Query("username") username: string,
  ) {
    return this.service.checkUsernameAvailability(authorization, username);
  }

  @Get("members/search")
  searchVisibleMembers(
    @Headers("authorization") authorization: string | undefined,
    @Query("q") query?: string,
  ) {
    return this.service.searchMembers(authorization, query);
  }

  @Get("members/followers")
  listFollowers(@Headers("authorization") authorization: string | undefined) {
    return this.service.listFollowers(authorization, "followers");
  }

  @Get("members/following")
  listFollowing(@Headers("authorization") authorization: string | undefined) {
    return this.service.listFollowers(authorization, "following");
  }

  @Get("members/:targetId/connections")
  listMemberConnections(
    @Headers("authorization") authorization: string | undefined,
    @Param("targetId") targetId: string,
    @Query("mode") mode?: string,
    @Query("type") type?: string,
  ) {
    const resolvedMode = (mode ?? type ?? "followers").toLowerCase();
    return this.service.listMemberConnections(
      authorization,
      targetId,
      resolvedMode === "following" ? "following" : "followers",
    );
  }

  @Get("members/:targetId/profile-overview")
  getMemberProfileOverview(
    @Headers("authorization") authorization: string | undefined,
    @Param("targetId") targetId: string,
  ) {
    return this.service.getMemberProfileOverview(authorization, targetId);
  }

  @Put("profile")
  updateProfile(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: UpdateModule2ProfileDto,
  ) {
    return this.service.updateProfile(authorization, dto);
  }

  @Patch("profile")
  patchProfile(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: UpdateModule2ProfileDto,
  ) {
    return this.service.updateProfile(authorization, dto);
  }

  @Put("profile/avatar")
  updateAvatar(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: UpdateAvatarDto,
  ) {
    return this.service.updateAvatar(authorization, dto);
  }

  @Post("media/upload-request")
  @HttpCode(200)
  requestMediaUpload(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: RequestMediaUploadDto,
  ) {
    return this.service.requestMediaUpload(authorization, dto);
  }

  @Post("media/upload-object")
  @HttpCode(201)
  uploadMediaObject(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: UploadMediaObjectDto,
  ) {
    return this.service.uploadMediaObject(authorization, dto);
  }

  @Post("media/binary-upload")
  @HttpCode(201)
  @UseInterceptors(
    FileInterceptor("file", {
      limits: { fileSize: 50 * 1024 * 1024, files: 1 },
    }),
  )
  uploadMediaFile(
    @Headers("authorization") authorization: string | undefined,
    @UploadedFile()
    file:
      | {
          originalname: string;
          mimetype: string;
          buffer: Buffer;
          size: number;
        }
      | undefined,
    @Body() dto: UploadBinaryMediaDto,
  ) {
    if (!file) {
      throw new BadRequestException("Select an image file before uploading.");
    }
    return this.service.uploadMediaFile(authorization, file, dto);
  }

  @Post("media/upload")
  @HttpCode(201)
  @UseInterceptors(
    FileInterceptor("file", {
      limits: { fileSize: 50 * 1024 * 1024, files: 1 },
    }),
  )
  uploadMediaFileAlias(
    @Headers("authorization") authorization: string | undefined,
    @UploadedFile()
    file:
      | {
          originalname: string;
          mimetype: string;
          buffer: Buffer;
          size: number;
        }
      | undefined,
    @Body() dto: UploadBinaryMediaDto,
  ) {
    if (!file) {
      throw new BadRequestException("Select an image file before uploading.");
    }
    return this.service.uploadMediaFile(authorization, file, dto);
  }

  @Get("media/objects")
  listMediaObjects(@Headers("authorization") authorization?: string) {
    return this.service.listMediaObjects(authorization);
  }

  @Get("media/object/:uploadId")
  async getMediaObject(
    @Headers("authorization") authorization: string | undefined,
    @Param("uploadId") uploadId: string,
    @Res() response: Response,
  ) {
    const media = await this.service.resolveMediaObject(
      authorization,
      uploadId,
    );
    if (media.redirectUrl) {
      return response.redirect(302, media.redirectUrl);
    }
    response.setHeader("Content-Type", media.contentType);
    response.setHeader("Cache-Control", "private, max-age=300");
    response.setHeader("X-Content-Type-Options", "nosniff");
    return response.status(200).send(media.buffer);
  }

  @Post("posts")
  @HttpCode(201)
  createPost(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: CreateCommunityPostDto,
  ) {
    return this.service.createPost(authorization, {
      ...dto,
      content: (dto.content ?? dto.body ?? "").trim(),
      imageAsset: dto.imageAsset ?? dto.mediaAsset,
    });
  }

  @Patch("posts/:postId")
  editPost(
    @Headers("authorization") authorization: string | undefined,
    @Param("postId") postId: string,
    @Body() dto: EditCommunityPostDto,
  ) {
    return this.service.editPost(authorization, postId, dto);
  }

  @Delete("posts/:postId")
  deletePost(
    @Headers("authorization") authorization: string | undefined,
    @Param("postId") postId: string,
  ) {
    return this.service.deletePost(authorization, postId);
  }

  @Post("posts/:postId/react")
  @HttpCode(200)
  reactToPost(
    @Headers("authorization") authorization: string | undefined,
    @Param("postId") postId: string,
    @Body() dto: ReactToPostDto,
  ) {
    return this.service.reactToPost(authorization, postId, dto.reactionType);
  }

  @Post("posts/:postId/like")
  @HttpCode(200)
  togglePostLike(
    @Headers("authorization") authorization: string | undefined,
    @Param("postId") postId: string,
  ) {
    return this.service.togglePostLike(authorization, postId);
  }

  @Post("posts/:postId/save")
  @HttpCode(200)
  togglePostSave(
    @Headers("authorization") authorization: string | undefined,
    @Param("postId") postId: string,
  ) {
    return this.service.togglePostSave(authorization, postId);
  }

  @Get("posts/:postId/comments")
  listPostComments(
    @Headers("authorization") authorization: string | undefined,
    @Param("postId") postId: string,
  ) {
    return this.service.listPostComments(authorization, postId);
  }

  @Post("posts/:postId/comments")
  @HttpCode(201)
  addPostComment(
    @Headers("authorization") authorization: string | undefined,
    @Param("postId") postId: string,
    @Body() dto: CreatePostCommentDto,
  ) {
    return this.service.addPostComment(authorization, postId, {
      content: (dto.content ?? dto.body ?? "").trim(),
      body: dto.body,
      parentCommentId: dto.parentCommentId,
      replyToHandle: dto.replyToHandle,
    });
  }

  @Patch("posts/:postId/comments/:commentId")
  editPostComment(
    @Headers("authorization") authorization: string | undefined,
    @Param("postId") postId: string,
    @Param("commentId") commentId: string,
    @Body() dto: EditPostCommentDto,
  ) {
    return this.service.editPostComment(authorization, postId, commentId, dto);
  }

  @Delete("posts/:postId/comments/:commentId")
  deletePostComment(
    @Headers("authorization") authorization: string | undefined,
    @Param("postId") postId: string,
    @Param("commentId") commentId: string,
  ) {
    return this.service.deletePostComment(authorization, postId, commentId);
  }

  @Post("followers/:profileId/toggle")
  @HttpCode(200)
  toggleFollow(
    @Headers("authorization") authorization: string | undefined,
    @Param("profileId") profileId: string,
  ) {
    return this.service.toggleFollow(authorization, profileId);
  }

  @Post("members/:profileId/follow")
  @HttpCode(200)
  toggleMemberFollowAlias(
    @Headers("authorization") authorization: string | undefined,
    @Param("profileId") profileId: string,
  ) {
    return this.service.toggleFollow(authorization, profileId);
  }

  @Put("privacy")
  updatePrivacy(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: UpdatePrivacyPreferenceDto,
  ) {
    return this.service.updatePrivacyPreference(authorization, dto);
  }

  @Put("notifications")
  updateNotification(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: UpdateNotificationPreferenceDto,
  ) {
    return this.service.updateNotificationPreference(authorization, dto);
  }

  @Get("quotes")
  listWomenQuotes(@Query("category") category?: string) {
    return this.service.listWomenQuotes(category);
  }

  @Get("safety/overview")
  getSafetyOverview(@Headers("authorization") authorization?: string) {
    return this.service.getSafetyOverview(authorization);
  }

  @Get("safety/police-stations")
  listNearbyPoliceStations(
    @Query("lat") lat?: string,
    @Query("lng") lng?: string,
    @Query("radiusMeters") radiusMeters?: string,
  ) {
    return this.service.listNearbyPoliceStations(
      lat === undefined ? undefined : Number(lat),
      lng === undefined ? undefined : Number(lng),
      radiusMeters ? Number(radiusMeters) : 5000,
    );
  }

  @Post("safety/events")
  @HttpCode(201)
  recordSafetyEvent(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: RecordSafetyEventDto,
  ) {
    return this.service.recordSafetyEvent(authorization, dto);
  }

  @Post("safety/check-ins")
  @HttpCode(201)
  recordSafetyCheckInAlias(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: RecordSafetyEventDto,
  ) {
    return this.service.recordSafetyEvent(authorization, dto);
  }

  @Post("safety/sos/activate")
  @HttpCode(201)
  activateSos(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: RecordSafetyEventDto,
  ) {
    return this.service.activateSos(authorization, dto);
  }

  @Post("safety/sos/:eventId/cancel")
  @HttpCode(200)
  cancelSos(
    @Headers("authorization") authorization: string | undefined,
    @Param("eventId") eventId: string,
  ) {
    return this.service.updateSosStatus(authorization, eventId, "CANCELLED");
  }

  @Post("safety/sos/:eventId/resolve")
  @HttpCode(200)
  resolveSos(
    @Headers("authorization") authorization: string | undefined,
    @Param("eventId") eventId: string,
  ) {
    return this.service.updateSosStatus(authorization, eventId, "RESOLVED");
  }

  @Post("safety/contacts")
  @HttpCode(201)
  addEmergencyContact(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: CreateEmergencyContactDto,
  ) {
    return this.service.addEmergencyContact(authorization, dto);
  }

  @Patch("safety/contacts/:contactId")
  updateEmergencyContact(
    @Headers("authorization") authorization: string | undefined,
    @Param("contactId") contactId: string,
    @Body() dto: UpdateEmergencyContactDto,
  ) {
    return this.service.updateEmergencyContact(authorization, contactId, dto);
  }

  @Delete("safety/contacts/:contactId")
  deleteEmergencyContact(
    @Headers("authorization") authorization: string | undefined,
    @Param("contactId") contactId: string,
  ) {
    return this.service.deleteEmergencyContact(authorization, contactId);
  }

  @Post("safety/location-shares")
  @HttpCode(201)
  startLocationShare(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: StartLocationShareDto,
  ) {
    return this.service.startLocationShare(authorization, dto);
  }

  @Patch("safety/location-shares/:token/ping")
  pingLocationShare(
    @Headers("authorization") authorization: string | undefined,
    @Param("token") token: string,
    @Body() dto: StartLocationShareDto,
  ) {
    return this.service.pingLocationShare(authorization, token, dto);
  }

  @Post("safety/location-shares/:token/stop")
  @HttpCode(200)
  stopLocationShare(
    @Headers("authorization") authorization: string | undefined,
    @Param("token") token: string,
  ) {
    return this.service.stopLocationShare(authorization, token);
  }

  @Get("safety/track/:token/json")
  getPublicLocationTrackJson(@Param("token") token: string) {
    return this.service.getLiveLocationTrackState(token);
  }

  @Get("safety/track/:token")
  async getPublicLocationTrackPage(
    @Param("token") token: string,
    @Res() response: Response,
  ) {
    const html = await this.service.renderLiveLocationTrackHtml(token);
    response.setHeader("Content-Type", "text/html; charset=utf-8");
    return response.status(200).send(html);
  }

  @Put("security")
  updateSecurityCombined(
    @Headers("authorization") authorization: string | undefined,
    @Body()
    dto: {
      enabled?: boolean;
      twoFactorEnabled?: boolean;
      currentPin?: string;
      newPin?: string;
      pin?: string;
    },
  ) {
    if (
      typeof dto.enabled === "boolean" ||
      typeof dto.twoFactorEnabled === "boolean"
    ) {
      return this.service.toggleTwoFactor(authorization, {
        enabled: dto.enabled ?? dto.twoFactorEnabled ?? false,
      });
    }
    const resolvedPin = (dto.newPin ?? dto.pin ?? "").trim();
    return this.service.updateSecurityPin(authorization, {
      currentPin: dto.currentPin ?? "0000",
      newPin: resolvedPin,
    });
  }

  @Put("security/two-factor")
  toggleTwoFactor(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: ToggleTwoFactorDto,
  ) {
    return this.service.toggleTwoFactor(authorization, {
      enabled: dto.enabled ?? dto.twoFactorEnabled ?? false,
    });
  }

  @Put("security/pin")
  updateSecurityPin(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: UpdateSecurityPinDto,
  ) {
    return this.service.updateSecurityPin(authorization, {
      currentPin: dto.currentPin ?? "0000",
      newPin: (dto.newPin ?? dto.pin ?? "").trim(),
    });
  }

  @Post("moderation/report")
  @HttpCode(201)
  reportUserOrPost(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: ReportUserOrPostDto,
  ) {
    return this.service.reportUserOrPost(authorization, {
      ...dto,
      targetHandle:
        dto.targetHandle ?? dto.reportedAccountId ?? dto.postId ?? "@community",
    });
  }

  @Post("reports")
  @HttpCode(201)
  reportAlias(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: ReportUserOrPostDto,
  ) {
    return this.service.reportUserOrPost(authorization, {
      ...dto,
      targetHandle:
        dto.targetHandle ?? dto.reportedAccountId ?? dto.postId ?? "@community",
    });
  }

  @Post("moderation/block")
  @HttpCode(200)
  toggleBlockedUser(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: ToggleBlockedUserDto,
  ) {
    return this.service.toggleBlockedUser(authorization, dto);
  }

  @Post("account/delete")
  @HttpCode(200)
  requestAccountDeletion(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: RequestAccountDeletionDto,
  ) {
    return this.service.requestAccountDeletion(authorization, dto);
  }

  @Patch("safety/sos/:eventId/resolve")
  patchResolveSos(
    @Headers("authorization") authorization: string | undefined,
    @Param("eventId") eventId: string,
  ) {
    return this.service.updateSosStatus(authorization, eventId, "RESOLVED");
  }

  @Delete("safety/sos/:eventId")
  deleteSosEvent(
    @Headers("authorization") authorization: string | undefined,
    @Param("eventId") eventId: string,
  ) {
    return this.service.deleteSosEvent(authorization, eventId);
  }

  @Post("safety/sos/clear")
  @HttpCode(200)
  clearSosEventsPost(
    @Headers("authorization") authorization: string | undefined,
    @Body() body?: { mode?: "resolved" | "all" | "tests" },
  ) {
    return this.service.clearSosEvents(authorization, body?.mode ?? "all");
  }

  @Delete("safety/sos")
  clearSosEventsDelete(
    @Headers("authorization") authorization: string | undefined,
    @Query("mode") mode?: "resolved" | "all" | "tests",
  ) {
    return this.service.clearSosEvents(authorization, mode ?? "all");
  }

  @Post("groups/:groupId/join")
  @HttpCode(200)
  toggleJoinGroup(
    @Headers("authorization") authorization: string | undefined,
    @Param("groupId") groupId: string,
  ) {
    return this.service.toggleJoinCommunityGroup(authorization, groupId);
  }

  // ===========================================================================
  // MODULE 6: WOMEN-OWNED BUSINESS PAGES ROUTES (SRS Section 8.1 - 8.5)
  // ===========================================================================
  @Get("businesses/categories")
  listBusinessCategories() {
    return this.service.listBusinessCategories();
  }

  @Get("businesses/enquiries/list")
  listBusinessEnquiries(
    @Headers("authorization") authorization: string | undefined,
  ) {
    return this.service.listBusinessEnquiries(authorization);
  }

  @Post("businesses/enquiries/:enquiryId/messages")
  @HttpCode(200)
  replyBusinessEnquiry(
    @Headers("authorization") authorization: string | undefined,
    @Param("enquiryId") enquiryId: string,
    @Body() dto: ReplyBusinessEnquiryDto,
  ) {
    return this.service.replyBusinessEnquiry(authorization, enquiryId, dto);
  }

  @Get("businesses")
  listBusinesses(
    @Headers("authorization") authorization?: string,
    @Query("search") search?: string,
    @Query("category") category?: string,
    @Query("city") city?: string,
    @Query("lat") lat?: string,
    @Query("lng") lng?: string,
    @Query("radiusKm") radiusKm?: string,
    @Query("savedOnly") savedOnly?: string,
    @Query("ownerOnly") ownerOnly?: string,
  ) {
    return this.service.listMemberBusinesses(authorization, {
      search,
      category,
      city,
      lat: lat !== undefined ? Number(lat) : undefined,
      lng: lng !== undefined ? Number(lng) : undefined,
      radiusKm: radiusKm !== undefined ? Number(radiusKm) : undefined,
      savedOnly: savedOnly === "true" || savedOnly === "1",
      ownerOnly: ownerOnly === "true" || ownerOnly === "1",
    });
  }

  @Get("businesses/:businessId")
  getBusinessDetail(
    @Headers("authorization") authorization: string | undefined,
    @Param("businessId") businessId: string,
  ) {
    return this.service.getMemberBusinessDetail(authorization, businessId);
  }

  @Post("businesses")
  @HttpCode(201)
  createBusiness(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: UpsertMemberBusinessDto,
  ) {
    return this.service.createMemberBusiness(authorization, dto);
  }

  @Put("businesses/:businessId")
  updateBusinessPut(
    @Headers("authorization") authorization: string | undefined,
    @Param("businessId") businessId: string,
    @Body() dto: UpsertMemberBusinessDto,
  ) {
    return this.service.updateMemberBusiness(authorization, businessId, dto);
  }

  @Patch("businesses/:businessId")
  updateBusinessPatch(
    @Headers("authorization") authorization: string | undefined,
    @Param("businessId") businessId: string,
    @Body() dto: Partial<UpsertMemberBusinessDto>,
  ) {
    return this.service.updateMemberBusiness(authorization, businessId, dto);
  }

  @Post("businesses/:businessId/save")
  @HttpCode(200)
  toggleSaveBusiness(
    @Headers("authorization") authorization: string | undefined,
    @Param("businessId") businessId: string,
  ) {
    return this.service.toggleSaveBusiness(authorization, businessId);
  }

  @Post("businesses/:businessId/report")
  @HttpCode(201)
  reportBusiness(
    @Headers("authorization") authorization: string | undefined,
    @Param("businessId") businessId: string,
    @Body() dto: ReportBusinessDto,
  ) {
    return this.service.reportBusiness(authorization, businessId, dto);
  }

  @Post("businesses/:businessId/enquiries")
  @HttpCode(201)
  createBusinessEnquiry(
    @Headers("authorization") authorization: string | undefined,
    @Param("businessId") businessId: string,
    @Body() dto: CreateBusinessEnquiryDto,
  ) {
    return this.service.createBusinessEnquiry(authorization, businessId, dto);
  }
}
