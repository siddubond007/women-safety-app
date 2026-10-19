import { ApiProperty, ApiPropertyOptional } from "@nestjs/swagger";
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsEmail,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from "class-validator";

export class UpdateModule2ProfileDto {
  @ApiProperty({ example: "Siddhu" })
  @IsString()
  @IsNotEmpty()
  @MinLength(2)
  @MaxLength(100)
  displayName!: string;

  @ApiProperty({
    example:
      "A passionate learner, exploring wellness, technology and meaningful connections. 💜",
  })
  @IsString()
  @MaxLength(300)
  bio!: string;

  @ApiProperty({ example: "Bangalore, India" })
  @IsString()
  @MaxLength(120)
  location!: string;

  @ApiProperty({
    example: ["Mental Wellness", "Travel", "Reading", "WomenInTech", "Art", "Fitness"],
  })
  @IsArray()
  @ArrayMaxSize(15)
  @IsString({ each: true })
  interests!: string[];

  @ApiPropertyOptional({ example: "siddhu@example.com" })
  @IsOptional()
  @IsEmail()
  @MaxLength(254)
  email?: string;

  @ApiPropertyOptional({ example: "https://sakhi.example.com/studio" })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  businessProfileUrl?: string;

  @ApiPropertyOptional({ example: "assets/images/profile/avatar_siddhu.webp" })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  avatarAsset?: string;
}

export class UpdateAvatarDto {
  @ApiProperty({
    example: "assets/images/profile/avatar_ananya.webp",
    description: "Local asset path or remote Cloud Storage HTTPS URL",
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  avatarAsset!: string;
}

export class RequestMediaUploadDto {
  @ApiProperty({ example: "profile_avatar.png" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  fileName!: string;

  @ApiProperty({ example: "image/png" })
  @IsString()
  @IsIn(["image/png", "image/jpeg", "image/webp", "image/svg+xml"])
  contentType!: "image/png" | "image/jpeg" | "image/webp" | "image/svg+xml";

  @ApiProperty({ enum: ["avatar", "post", "verification"] })
  @IsString()
  @IsIn(["avatar", "post", "verification"])
  purpose!: "avatar" | "post" | "verification";
}

export class UploadBinaryMediaDto {
  @ApiProperty({ enum: ["avatar", "post"] })
  @IsString()
  @IsIn(["avatar", "post"])
  purpose!: "avatar" | "post";
}

export class UploadMediaObjectDto {
  @ApiProperty({ example: "cloud_upload.png" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  fileName!: string;

  @ApiProperty({ example: "image/png" })
  @IsString()
  @IsIn(["image/png", "image/jpeg", "image/webp", "image/svg+xml"])
  contentType!: "image/png" | "image/jpeg" | "image/webp" | "image/svg+xml";

  @ApiProperty({ enum: ["avatar", "post", "verification"] })
  @IsString()
  @IsIn(["avatar", "post", "verification"])
  purpose!: "avatar" | "post" | "verification";

  @ApiPropertyOptional({
    description: "Optional base64 data URI (data:image/png;base64,...) to store in backend cloud bridge",
  })
  @IsOptional()
  @IsString()
  @MaxLength(1500000)
  dataUrl?: string;

  @ApiPropertyOptional({
    description: "Optional external HTTPS URL or cloud bucket object URL",
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  externalUrl?: string;

  @ApiPropertyOptional({
    description: "Optional visual theme preset when generating a studio cloud asset",
  })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  presetTheme?: string;
}

export class CreateCommunityPostDto {
  @ApiProperty({
    example: "Taking time for a mindful evening walk today 🌸💜",
  })
  @IsString()
  @IsNotEmpty()
  @MinLength(1)
  @MaxLength(1000)
  content!: string;

  @ApiPropertyOptional({ example: "Wellness" })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  categoryBadge?: string;

  @ApiPropertyOptional({ example: "assets/images/community/evening_walk_sunset.webp" })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  imageAsset?: string;
}

export class CreatePostCommentDto {
  @ApiProperty({ example: "So inspiring! Thank you for sharing 💜" })
  @IsString()
  @IsNotEmpty()
  @MinLength(1)
  @MaxLength(500)
  content!: string;
}

export class UpdatePrivacyPreferenceDto {
  @ApiProperty({
    enum: [
      "view_profile",
      "message_me",
      "see_posts",
      "show_location",
      "search_results",
      "business_enquiries",
    ],
  })
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

  @ApiProperty({ example: "Verified members only" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  selectedValue!: string;
}

export class UpdateNotificationPreferenceDto {
  @ApiProperty({
    enum: [
      "community_updates",
      "group_activity",
      "wellness_reminders",
      "safety_alerts",
      "messages",
      "business_enquiries",
      "marketing_updates",
    ],
  })
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

  @ApiProperty({ example: true })
  @IsBoolean()
  isEnabled!: boolean;
}

export class RecordSafetyEventDto {
  @ApiProperty({
    enum: ["SOS_TRIGGERED", "LOCATION_SHARED", "HELPLINE_OPENED"],
  })
  @IsString()
  @IsIn(["SOS_TRIGGERED", "LOCATION_SHARED", "HELPLINE_OPENED"])
  eventType!: "SOS_TRIGGERED" | "LOCATION_SHARED" | "HELPLINE_OPENED";

  @ApiPropertyOptional({ example: "Bangalore, India" })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  locationLabel?: string;
}

export class CreateEmergencyContactDto {
  @ApiProperty({ example: "Lakshmi Devi" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  name!: string;

  @ApiProperty({ example: "Mother" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  relationship!: string;

  @ApiProperty({ example: "+919845011223" })
  @IsString()
  @Matches(/^\+[1-9]\d{7,14}$/, {
    message: "Enter a valid international phone number (e.g. +919845011223).",
  })
  phoneE164!: string;
}

export class ToggleTwoFactorDto {
  @ApiProperty({ example: true })
  @IsBoolean()
  enabled!: boolean;
}

export class UpdateSecurityPinDto {
  @ApiProperty({ example: "4829" })
  @IsString()
  @Matches(/^\d{4,6}$/, { message: "PIN must be 4 to 6 digits." })
  newPin!: string;
}

export class ReportUserOrPostDto {
  @ApiProperty({ example: "@kavya" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  targetHandle!: string;

  @ApiProperty({ example: "Harassment or unkind behavior" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  reason!: string;
}

export class ToggleBlockedUserDto {
  @ApiProperty({ example: "@spam_account" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  blockedUsername!: string;

  @ApiProperty({ example: "Spam Account" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  blockedDisplayName!: string;
}
