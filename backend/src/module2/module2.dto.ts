import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsEmail,
  IsIn,
  IsISO8601,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
} from "class-validator";

export class UpdateModule2ProfileDto {
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  @Matches(/^[^\d]+$/, {
    message: "Full name cannot contain numbers.",
  })
  displayName?: string;

  @ValidateIf(
    (o) =>
      o.username !== undefined &&
      o.username !== null &&
      String(o.username).trim() !== "" &&
      String(o.username).trim() !== "@",
  )
  @IsString()
  @Matches(/^@?[a-zA-Z0-9_.-]{2,32}$/, {
    message:
      "Username must contain 2–32 letters, numbers, dots, hyphens, or underscores.",
  })
  username?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  bio?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  location?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  locationCity?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(24)
  @IsString({ each: true })
  @MaxLength(60, { each: true })
  interests?: string[];

  @ValidateIf(
    (o) =>
      o.email !== undefined &&
      o.email !== null &&
      String(o.email).trim() !== "",
  )
  @IsEmail()
  @MaxLength(160)
  email?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  businessProfileUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(512)
  avatarAsset?: string;

  @ValidateIf(
    (o) =>
      o.profilePhotoRef !== undefined &&
      o.profilePhotoRef !== null &&
      String(o.profilePhotoRef).trim() !== "",
  )
  @IsString()
  @MaxLength(512)
  @Matches(/^profile\/[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\/[A-Za-z0-9][A-Za-z0-9._-]{0,127}\.(?:avif|gif|jpe?g|png|webp)$/i, {
    message: "Profile photo reference must be a trusted profile media key.",
  })
  profilePhotoRef?: string;
}

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  @Matches(/^[^\d]+$/, {
    message: "Full name cannot contain numbers.",
  })
  displayName?: string;

  @ValidateIf(
    (o) =>
      o.username !== undefined &&
      o.username !== null &&
      String(o.username).trim() !== "" &&
      String(o.username).trim() !== "@",
  )
  @IsString()
  @Matches(/^@?[a-zA-Z0-9_.-]{2,32}$/, {
    message:
      "Username must contain 2–32 letters, numbers, dots, hyphens, or underscores.",
  })
  username?: string;

  @ValidateIf(
    (o) =>
      o.email !== undefined &&
      o.email !== null &&
      String(o.email).trim() !== "",
  )
  @IsEmail()
  @MaxLength(160)
  email?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  bio?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  location?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  locationCity?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(24)
  @IsString({ each: true })
  @MaxLength(60, { each: true })
  interests?: string[];

  @ValidateIf(
    (o) =>
      o.profilePhotoRef !== undefined &&
      o.profilePhotoRef !== null &&
      String(o.profilePhotoRef).trim() !== "",
  )
  @IsString()
  @MaxLength(512)
  @Matches(/^profile\/[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\/[A-Za-z0-9][A-Za-z0-9._-]{0,127}\.(?:avif|gif|jpe?g|png|webp)$/i, {
    message: "Profile photo reference must be a trusted profile media key.",
  })
  profilePhotoRef?: string;

  @IsOptional()
  @IsString()
  @MaxLength(512)
  avatarAsset?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  businessProfileUrl?: string;
}

export class CreateCommunityPostDto {
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  content?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  body?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  categoryBadge?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  categorySlug?: string;

  @IsOptional()
  @IsString()
  @IsIn([
    "VERIFIED_MEMBERS",
    "FOLLOWERS_ONLY",
    "PRIVATE_SELF",
    "Verified members",
    "Followers only",
    "Only me",
  ])
  visibility?: string;

  @IsOptional()
  @IsString()
  @IsIn(["1:1", "4:5", "16:9"])
  cropPreset?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  hashtags?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(120)
  locationTag?: string;

  @IsOptional()
  @IsBoolean()
  allowComments?: boolean;

  @IsOptional()
  @IsBoolean()
  shareToBusinessProfile?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(512)
  imageAsset?: string;

  @IsOptional()
  @IsString()
  @MaxLength(512)
  mediaAsset?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(4)
  @IsUUID("4", { each: true })
  mediaUploadIds?: string[];
}

export class CreatePostDto {
  @IsString()
  @MinLength(1)
  @MaxLength(5000)
  body!: string;

  @IsOptional()
  @IsString()
  @IsIn([
    "VERIFIED_MEMBERS",
    "FOLLOWERS",
    "SELECTED_MEMBERS",
    "ONLY_ME",
    "FOLLOWERS_ONLY",
    "PRIVATE_SELF",
  ])
  audience?: string;

  @IsOptional()
  @IsString()
  @MaxLength(512)
  mediaRef?: string;
}

export class EditCommunityPostDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(2000)
  content?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(2000)
  body?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  categorySlug?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  categoryBadge?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  visibility?: string;

  @IsOptional()
  @IsString()
  @IsIn(["1:1", "4:5", "16:9"])
  cropPreset?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  hashtags?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(120)
  locationTag?: string;

  @IsOptional()
  @IsBoolean()
  allowComments?: boolean;
}

export class ReactToPostDto {
  @IsString()
  @IsIn([
    "LIKE",
    "LOVE",
    "SUPPORT",
    "SOLIDARITY",
    "INSPIRED",
    "HAPPY",
    "HAHA",
    "CRYING",
    "SAD",
    "FIERCE",
    "GRATEFUL",
    "STRONG",
    "APPLAUD",
    "CARE",
  ])
  reactionType!: string;
}

export class CreatePostCommentDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  content?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  body?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  parentCommentId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  replyToHandle?: string;
}

export class EditPostCommentDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  content?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  body?: string;
}

export class CreateCommunityGroupDto {
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  category?: string;

  @IsOptional()
  @IsString()
  @IsIn(["VERIFIED_MEMBERS", "PRIVATE"])
  visibility?: "VERIFIED_MEMBERS" | "PRIVATE";
}

export class CreateCommunityEventDto {
  @IsString()
  @IsNotEmpty()
  groupId!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(160)
  title!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(3000)
  description!: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  locationCity?: string;

  @IsISO8601()
  startsAt!: string;

  @IsISO8601()
  endsAt!: string;
}

export class UpdatePrivacyPreferenceDto {
  @IsString()
  @IsIn([
    "view_profile",
    "message_me",
    "see_posts",
    "show_location",
    "search_results",
    "business_enquiries",
  ])
  settingId!:
    | "view_profile"
    | "message_me"
    | "see_posts"
    | "show_location"
    | "search_results"
    | "business_enquiries";

  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  selectedValue!: string;
}

export class UpdateNotificationPreferenceDto {
  @IsString()
  @IsIn([
    "community_updates",
    "group_activity",
    "wellness_reminders",
    "safety_alerts",
    "messages",
    "business_enquiries",
    "marketing_updates",
  ])
  prefId!:
    | "community_updates"
    | "group_activity"
    | "wellness_reminders"
    | "safety_alerts"
    | "messages"
    | "business_enquiries"
    | "marketing_updates";

  @IsBoolean()
  isEnabled!: boolean;
}

export class RecordSafetyEventDto {
  @IsOptional()
  @IsString()
  @MaxLength(40)
  eventType?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  status?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  locationLabel?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  locationArea?: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  note?: string;

  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;

  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100000)
  accuracyMeters?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  batteryPercent?: number;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  triggerSource?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(4)
  simSlotIndex?: number;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  simCarrierName?: string;

  @IsOptional()
  @IsBoolean()
  isTestMode?: boolean;

  @IsOptional()
  @IsInt()
  contactsAlertedCount?: number;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  shareToken?: string;
}

export class CreateEmergencyContactDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  contactName?: string;

  @IsString()
  @MinLength(2)
  @MaxLength(50)
  relationship!: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  phoneE164?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  phoneNumber?: string;

  @IsOptional()
  @IsBoolean()
  isPrimary?: boolean;

  @IsOptional()
  @IsBoolean()
  alertEnabled?: boolean;
}

export class UpdateEmergencyContactDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  relationship?: string;

  @IsOptional()
  @IsBoolean()
  isPrimary?: boolean;

  @IsOptional()
  @IsBoolean()
  alertEnabled?: boolean;
}

export class StartLocationShareDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  shareToken?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  durationLabel?: string;

  @IsOptional()
  @IsBoolean()
  includeProfile?: boolean;

  @IsOptional()
  @IsBoolean()
  includeTimestamp?: boolean;

  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;

  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100000)
  accuracyMeters?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  batteryPercent?: number;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  locationLabel?: string;
}

export class ToggleTwoFactorDto {
  @IsOptional()
  @IsBoolean()
  enabled?: boolean;

  @IsOptional()
  @IsBoolean()
  twoFactorEnabled?: boolean;
}

export class UpdateSecurityPinDto {
  @IsOptional()
  @IsString()
  @MinLength(4)
  @MaxLength(6)
  currentPin?: string;

  @IsOptional()
  @IsString()
  @MinLength(4)
  @MaxLength(6)
  newPin?: string;

  @IsOptional()
  @IsString()
  @MinLength(4)
  @MaxLength(6)
  pin?: string;
}

export class ReportUserOrPostDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  targetHandle?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  targetType?: string;

  @IsOptional()
  @IsString()
  postId?: string;

  @IsOptional()
  @IsString()
  commentId?: string;

  @IsOptional()
  @IsString()
  reportedAccountId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  category?: string;

  @IsString()
  @MinLength(3)
  @MaxLength(300)
  reason!: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  details?: string;
}

export class UpdateAvatarDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  avatarAsset!: string;
}

export class RequestMediaUploadDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(140)
  fileName!: string;

  @IsString()
  @IsIn(["image/jpeg", "image/png", "image/webp", "video/mp4"])
  contentType!: "image/jpeg" | "image/png" | "image/webp" | "video/mp4";

  @IsString()
  @IsIn(["avatar", "post", "wellness", "business"])
  purpose!: "avatar" | "post" | "wellness" | "business";

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(25_000_000)
  byteSize?: number;
}

export class UploadMediaObjectDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  uploadId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(140)
  fileName!: string;

  @IsString()
  @IsIn(["image/jpeg", "image/png", "image/webp", "video/mp4"])
  contentType!: "image/jpeg" | "image/png" | "image/webp" | "video/mp4";

  @IsString()
  @IsIn(["avatar", "post", "wellness", "business"])
  purpose!: "avatar" | "post" | "wellness" | "business";

  @IsOptional()
  @IsString()
  @MaxLength(80)
  checksumSha256?: string;
}

export class UploadBinaryMediaDto {
  @IsOptional()
  @IsString()
  @IsIn([
    "avatar",
    "post",
    "profile_photo",
    "community_post",
    "business_media",
    "PROFILE_PHOTO",
    "COMMUNITY_POST_IMAGE",
  ])
  purpose?:
    | "avatar"
    | "post"
    | "profile_photo"
    | "community_post"
    | "business_media"
    | "PROFILE_PHOTO"
    | "COMMUNITY_POST_IMAGE";

  @IsOptional()
  @IsString()
  @MaxLength(40)
  categorySlug?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  postId?: string;

  @IsOptional()
  @IsString()
  @IsIn(["1:1", "4:5", "16:9"])
  cropAspectRatio?: string;
}

export class ToggleBlockedUserDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  blockedUsername!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  blockedDisplayName!: string;
}

export class RequestAccountDeletionDto {
  @IsString()
  @IsIn(["DELETE"])
  confirmation!: "DELETE";

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

// =============================================================================
// MODULE 6: WOMEN-OWNED BUSINESS PAGES DTOs (SRS Section 8.1 - 8.5)
// =============================================================================
export class UpsertMemberBusinessDto {
  @IsString()
  @MinLength(2)
  @MaxLength(160)
  businessName!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(80)
  category!: string;

  @IsString()
  @MinLength(5)
  @MaxLength(2000)
  description!: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  city?: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  serviceArea?: string;

  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;

  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  priceRange?: string;

  @IsOptional()
  @IsString()
  @MaxLength(512)
  logoAsset?: string;

  @IsOptional()
  @IsString()
  @MaxLength(512)
  coverImage?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  contactPhone?: string;

  @IsOptional()
  @IsBoolean()
  hidePhoneNumber?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  whatsappNumber?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  instagramHandle?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  websiteOrInstagram?: string;

  @IsOptional()
  @IsObject()
  businessHours?: Record<string, any>;

  @IsOptional()
  @IsArray()
  productsServices?: Array<Record<string, any>>;

  @IsOptional()
  @IsArray()
  mediaGallery?: Array<Record<string, any>>;

  @IsOptional()
  @IsArray()
  offersAndPosts?: Array<Record<string, any>>;

  @IsOptional()
  @IsBoolean()
  requestVerificationBadge?: boolean;
}

export class CreateBusinessEnquiryDto {
  @IsOptional()
  @IsString()
  @MaxLength(160)
  subjectOrProduct?: string;

  @IsString()
  @MinLength(2)
  @MaxLength(1500)
  message!: string;

  @IsOptional()
  @IsString()
  @MaxLength(512)
  attachmentUrl?: string;
}

export class ReplyBusinessEnquiryDto {
  @IsString()
  @MinLength(1)
  @MaxLength(1500)
  message!: string;

  @IsOptional()
  @IsString()
  @IsIn(["OPEN", "REPLIED", "RESOLVED", "ARCHIVED"])
  status?: string;
}

export class ReportBusinessDto {
  @IsString()
  @MinLength(3)
  @MaxLength(160)
  reason!: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  details?: string;
}
