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
  ReportUserOrPostDto,
  RequestAccountDeletionDto,
  RequestMediaUploadDto,
  ToggleBlockedUserDto,
  ToggleTwoFactorDto,
  UpdateAvatarDto,
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
      limits: { fileSize: 10 * 1024 * 1024, files: 1 },
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
      limits: { fileSize: 10 * 1024 * 1024, files: 1 },
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

  @Post("safety/events")
  @HttpCode(201)
  recordSafetyEvent(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: RecordSafetyEventDto,
  ) {
    return this.service.recordSafetyEvent(authorization, dto);
  }

  @Post("safety/contacts")
  @HttpCode(201)
  addEmergencyContact(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: CreateEmergencyContactDto,
  ) {
    return this.service.addEmergencyContact(authorization, dto);
  }

  @Put("security/two-factor")
  toggleTwoFactor(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: ToggleTwoFactorDto,
  ) {
    return this.service.toggleTwoFactor(authorization, dto);
  }

  @Put("security/pin")
  updateSecurityPin(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: UpdateSecurityPinDto,
  ) {
    return this.service.updateSecurityPin(authorization, dto);
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
}
