import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  Res,
  UploadedFile,
  UseInterceptors,
} from "@nestjs/common";
import { ApiBearerAuth, ApiOkResponse, ApiTags } from "@nestjs/swagger";
import { FileInterceptor } from "@nestjs/platform-express";
import {
  CreateCommunityPostDto,
  CreateEmergencyContactDto,
  CreatePostCommentDto,
  RecordSafetyEventDto,
  ReportUserOrPostDto,
  RequestMediaUploadDto,
  ToggleBlockedUserDto,
  ToggleTwoFactorDto,
  UpdateAvatarDto,
  UpdateModule2ProfileDto,
  UpdateNotificationPreferenceDto,
  UpdatePrivacyPreferenceDto,
  UpdateSecurityPinDto,
  UploadMediaObjectDto,
  UploadBinaryMediaDto,
} from "./module2.dto.js";
import { Module2Service } from "./module2.service.js";

@ApiTags("module2")
@ApiBearerAuth()
@Controller("module2")
export class Module2Controller {
  constructor(private readonly module2: Module2Service) {}

  @Get("bootstrap")
  @ApiOkResponse({
    description:
      "Returns the full database-backed state for all 12 Sakhi Module 2 screens.",
  })
  bootstrap(@Headers("authorization") authorization: string | undefined) {
    return this.module2.bootstrap(authorization);
  }

  @Get("public-feed")
  @ApiOkResponse({
    description:
      "Returns live PostgreSQL community posts, explore posts, groups, followers directory, and wellness catalog.",
  })
  publicFeed() {
    return this.module2.publicFeed();
  }

  @Put("profile")
  @HttpCode(200)
  @ApiOkResponse({ description: "Updates member profile, bio, location, and interests." })
  updateProfile(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: UpdateModule2ProfileDto,
  ) {
    return this.module2.updateProfile(authorization, dto);
  }

  @Put("profile/avatar")
  @HttpCode(200)
  @ApiOkResponse({ description: "Updates the member profile avatar asset or Cloud URL." })
  updateAvatar(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: UpdateAvatarDto,
  ) {
    return this.module2.updateAvatar(authorization, dto);
  }

  @Post("media/presign")
  @HttpCode(200)
  @ApiOkResponse({
    description: "Legacy metadata-only presign route disabled; use the authenticated multipart binary upload endpoint after connecting Google Drive.",
  })
  requestMediaUpload(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: RequestMediaUploadDto,
  ) {
    return this.module2.requestMediaUpload(authorization, dto);
  }

  @Post("media/binary-upload")
  @HttpCode(200)
  @UseInterceptors(
    FileInterceptor("file", {
      limits: { fileSize: 10 * 1024 * 1024, files: 1, fields: 1 },
    }),
  )
  @ApiOkResponse({
    description: "Uploads an actual validated image file to the connected private Google Drive and stores its metadata.",
  })
  uploadBinaryMedia(
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
      throw new BadRequestException("Choose an image file to upload.");
    }
    return this.module2.uploadMediaFile(authorization, file, dto);
  }

  @Post("media/upload")
  @HttpCode(200)
  @ApiOkResponse({
    description: "Legacy JSON/placeholder upload route disabled; use the authenticated multipart binary upload endpoint for real file bytes.",
  })
  uploadMediaObject(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: UploadMediaObjectDto,
  ) {
    return this.module2.uploadMediaObject(authorization, dto);
  }

  @Get("media")
  @ApiOkResponse({
    description: "Lists recent user media uploads stored in the backend cloud storage pipeline.",
  })
  listMediaObjects() {
    return this.module2.listMediaObjects();
  }

  @Get("media/object/:uploadId")
  @ApiOkResponse({
    description: "Streams a stored user upload image from the backend/cloud storage bridge.",
  })
  async serveMediaObject(
    @Param("uploadId", new ParseUUIDPipe({ version: "4" })) uploadId: string,
    @Res() res: {
      setHeader: (name: string, value: string) => void;
      status: (code: number) => { send: (body: Buffer | string) => void };
      redirect: (url: string) => void;
    },
  ) {
    const media = await this.module2.resolveMediaObject(uploadId);
    if (media.redirectUrl) {
      res.redirect(media.redirectUrl);
      return;
    }
    res.setHeader("Content-Type", media.contentType);
    res.setHeader("Cache-Control", "private, max-age=300");
    res.setHeader("X-Content-Type-Options", "nosniff");
    res.status(200).send(media.buffer);
  }

  @Post("posts")
  @HttpCode(200)
  @ApiOkResponse({ description: "Creates a new community feed post." })
  createPost(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: CreateCommunityPostDto,
  ) {
    return this.module2.createPost(authorization, dto);
  }

  @Post("posts/:postId/like")
  @HttpCode(200)
  @ApiOkResponse({ description: "Toggles like status on a community post." })
  toggleLike(
    @Headers("authorization") authorization: string | undefined,
    @Param("postId", new ParseUUIDPipe({ version: "4" })) postId: string,
  ) {
    return this.module2.togglePostLike(authorization, postId);
  }

  @Post("posts/:postId/save")
  @HttpCode(200)
  @ApiOkResponse({ description: "Toggles bookmark/save status on a community post." })
  toggleSave(
    @Headers("authorization") authorization: string | undefined,
    @Param("postId", new ParseUUIDPipe({ version: "4" })) postId: string,
  ) {
    return this.module2.togglePostSave(authorization, postId);
  }

  @Post("posts/:postId/comments")
  @HttpCode(200)
  @ApiOkResponse({ description: "Adds a comment to a community post." })
  addComment(
    @Headers("authorization") authorization: string | undefined,
    @Param("postId", new ParseUUIDPipe({ version: "4" })) postId: string,
    @Body() dto: CreatePostCommentDto,
  ) {
    return this.module2.addPostComment(authorization, postId, dto);
  }

  @Post("followers/:profileId/toggle")
  @HttpCode(200)
  @ApiOkResponse({ description: "Toggles follow status for a community profile." })
  toggleFollow(
    @Headers("authorization") authorization: string | undefined,
    @Param("profileId", new ParseUUIDPipe({ version: "4" })) profileId: string,
  ) {
    return this.module2.toggleFollow(authorization, profileId);
  }

  @Put("privacy")
  @HttpCode(200)
  @ApiOkResponse({ description: "Updates a member privacy setting." })
  updatePrivacy(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: UpdatePrivacyPreferenceDto,
  ) {
    return this.module2.updatePrivacyPreference(authorization, dto);
  }

  @Put("notifications")
  @HttpCode(200)
  @ApiOkResponse({ description: "Updates a member notification preference." })
  updateNotification(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: UpdateNotificationPreferenceDto,
  ) {
    return this.module2.updateNotificationPreference(authorization, dto);
  }

  @Post("safety/events")
  @HttpCode(200)
  @ApiOkResponse({ description: "Records a safety SOS or location share event." })
  recordSafetyEvent(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: RecordSafetyEventDto,
  ) {
    return this.module2.recordSafetyEvent(authorization, dto);
  }

  @Post("safety/contacts")
  @HttpCode(200)
  @ApiOkResponse({ description: "Adds a trusted emergency contact." })
  addEmergencyContact(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: CreateEmergencyContactDto,
  ) {
    return this.module2.addEmergencyContact(authorization, dto);
  }

  @Post("security/two-factor")
  @HttpCode(200)
  @ApiOkResponse({ description: "Updates two-factor authentication state." })
  toggleTwoFactor(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: ToggleTwoFactorDto,
  ) {
    return this.module2.toggleTwoFactor(authorization, dto);
  }

  @Post("security/pin")
  @HttpCode(200)
  @ApiOkResponse({ description: "Updates the member security PIN." })
  updatePin(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: UpdateSecurityPinDto,
  ) {
    return this.module2.updateSecurityPin(authorization, dto);
  }

  @Post("moderation/report")
  @HttpCode(200)
  @ApiOkResponse({ description: "Submits a user or post moderation report." })
  report(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: ReportUserOrPostDto,
  ) {
    return this.module2.reportUserOrPost(authorization, dto);
  }

  @Post("moderation/block")
  @HttpCode(200)
  @ApiOkResponse({ description: "Toggles a blocked user record." })
  toggleBlock(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: ToggleBlockedUserDto,
  ) {
    return this.module2.toggleBlockedUser(authorization, dto);
  }
}
