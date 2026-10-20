import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsEmail,
  IsIn,
  IsISO8601,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from "class-validator";

export class UpdateModule2ProfileDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  displayName!: string;

  @IsString()
  @MaxLength(300)
  bio!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  location!: string;

  @IsArray()
  @ArrayMaxSize(16)
  @IsString({ each: true })
  @MaxLength(40, { each: true })
  interests!: string[];

  @IsOptional()
  @IsEmail()
  @MaxLength(160)
  email?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  businessProfileUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  avatarAsset?: string;
}

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  displayName?: string;

  @IsOptional()
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
  @ArrayMaxSize(16)
  @IsString({ each: true })
  @MaxLength(40, { each: true })
  interests?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(255)
  @Matches(/^(?!.*\.\.)(profile\/[0-9a-fA-F-]{36}\/[a-zA-Z0-9._-]+|assets\/images\/[a-zA-Z0-9/_.-]+|https?:\/\/127\.0\.0\.1:\d+\/api\/v1\/module2\/media\/object\/[0-9a-fA-F-]{36})$/, {
    message: "profilePhotoRef must be a valid scoped profile photo reference.",
  })
  profilePhotoRef?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  avatarAsset?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  businessProfileUrl?: string;
}

export class CreateCommunityPostDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(2000)
  content?: string;

  @IsOptional()
  @IsString()
  @MinLength(2)
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
  @IsIn(["VERIFIED_MEMBERS", "FOLLOWERS_ONLY", "PRIVATE_SELF", "Verified members", "Followers only", "Only me"])
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
  @IsString({ each: true })
  mediaUploadIds?: string[];
}

export class CreatePostDto {
  @IsString()
  @MinLength(1)
  @MaxLength(5000)
  body!: string;

  @IsOptional()
  @IsString()
  @IsIn(["VERIFIED_MEMBERS", "FOLLOWERS", "SELECTED_MEMBERS", "ONLY_ME", "FOLLOWERS_ONLY", "PRIVATE_SELF"])
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
  @IsIn(["LIKE", "LOVE", "SUPPORT", "INSPIRED", "HAPPY", "GRATEFUL", "STRONG", "CARE"])
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

  @IsString()
  @IsIn(["VERIFIED_MEMBERS", "PRIVATE"])
  visibility!: "VERIFIED_MEMBERS" | "PRIVATE";
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
  @IsString()
  @IsIn(["SOS_ACTIVATED", "LOCATION_SHARED", "FAKE_CALL_TRIGGERED", "AUDIO_RECORDING_STARTED"])
  eventType!:
    | "SOS_ACTIVATED"
    | "LOCATION_SHARED"
    | "FAKE_CALL_TRIGGERED"
    | "AUDIO_RECORDING_STARTED";

  @IsOptional()
  @IsString()
  @MaxLength(120)
  locationLabel?: string;
}

export class CreateEmergencyContactDto {
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  name!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(50)
  relationship!: string;

  @IsString()
  @MinLength(8)
  @MaxLength(20)
  phoneE164!: string;
}

export class ToggleTwoFactorDto {
  @IsBoolean()
  enabled!: boolean;
}

export class UpdateSecurityPinDto {
  @IsString()
  @MinLength(4)
  @MaxLength(6)
  currentPin!: string;

  @IsString()
  @MinLength(4)
  @MaxLength(6)
  newPin!: string;
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
  @IsIn(["avatar", "post", "wellness"])
  purpose!: "avatar" | "post" | "wellness";

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
  @IsIn(["avatar", "post", "wellness"])
  purpose!: "avatar" | "post" | "wellness";

  @IsOptional()
  @IsString()
  @MaxLength(80)
  checksumSha256?: string;
}

export class UploadBinaryMediaDto {
  @IsOptional()
  @IsString()
  @IsIn(["avatar", "post", "PROFILE_PHOTO", "COMMUNITY_POST_IMAGE", "COMMUNITY_POST_VIDEO"])
  purpose?: "avatar" | "post" | "PROFILE_PHOTO" | "COMMUNITY_POST_IMAGE" | "COMMUNITY_POST_VIDEO";

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
