import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsEmail,
  IsISO8601,
  IsIn,
  IsOptional,
  IsString,
  IsUrl,
  IsUUID,
  Matches,
  MaxLength,
  MinLength,
} from "class-validator";

const PROFILE_VISIBILITY = ["VERIFIED_MEMBERS", "FOLLOWERS_ONLY", "ONLY_ME"] as const;
const MESSAGE_PERMISSION = ["VERIFIED_MEMBERS", "FOLLOWING_ONLY", "NO_ONE"] as const;
const POST_AUDIENCE = ["VERIFIED_MEMBERS", "FOLLOWERS", "SELECTED_MEMBERS", "ONLY_ME"] as const;
const LOCATION_SHARING = ["HIDDEN", "CITY_ONLY"] as const;
const BUSINESS_ENQUIRY_PERMISSION = ["ALL_VERIFIED", "VERIFIED_BUSINESSES", "NONE"] as const;
const REPORT_REASONS = ["HARASSMENT", "IMPERSONATION", "SPAM", "UNSAFE_CONTENT", "OTHER"] as const;

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  @Matches(/^[\p{L}\p{M}\p{N}\s.'’_-]+$/u)
  displayName?: string;

  @IsOptional()
  @IsEmail()
  @MaxLength(254)
  email?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  bio?: string | null;

  /// City/general location only. Precise GPS coordinates are never accepted here.
  @IsOptional()
  @IsString()
  @MaxLength(100)
  @Matches(/^[\p{L}\p{M}\p{N}\s,.'’_-]+$/u)
  locationCity?: string | null;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @MaxLength(40, { each: true })
  interests?: string[];

  /// A trusted object-storage reference, not an arbitrary filesystem path or data URI.
  @IsOptional()
  @IsString()
  @MaxLength(512)
  @Matches(/^profile\/[A-Za-z0-9][A-Za-z0-9_./-]*$/)
  profilePhotoRef?: string | null;
}

export class UpdatePrivacySettingsDto {
  @IsOptional()
  @IsString()
  @IsIn(PROFILE_VISIBILITY)
  profileVisibility?: (typeof PROFILE_VISIBILITY)[number];

  @IsOptional()
  @IsString()
  @IsIn(MESSAGE_PERMISSION)
  messagePermission?: (typeof MESSAGE_PERMISSION)[number];

  @IsOptional()
  @IsString()
  @IsIn(["VERIFIED_MEMBERS", "FOLLOWERS", "ONLY_ME"])
  defaultPostAudience?: "VERIFIED_MEMBERS" | "FOLLOWERS" | "ONLY_ME";

  @IsOptional()
  @IsString()
  @IsIn(LOCATION_SHARING)
  locationSharing?: (typeof LOCATION_SHARING)[number];

  @IsOptional()
  @IsBoolean()
  appearInSearch?: boolean;

  @IsOptional()
  @IsString()
  @IsIn(BUSINESS_ENQUIRY_PERMISSION)
  businessEnquiryPermission?: (typeof BUSINESS_ENQUIRY_PERMISSION)[number];
}

export class UpdateNotificationPreferencesDto {
  @IsOptional() @IsBoolean() communityUpdates?: boolean;
  @IsOptional() @IsBoolean() groupActivity?: boolean;
  @IsOptional() @IsBoolean() wellnessReminders?: boolean;
  @IsOptional() @IsBoolean() safetyAlerts?: boolean;
  @IsOptional() @IsBoolean() messages?: boolean;
  @IsOptional() @IsBoolean() businessEnquiries?: boolean;
  @IsOptional() @IsBoolean() marketingUpdates?: boolean;
}

export class CreatePostDto {
  @IsString()
  @MinLength(1)
  @MaxLength(5000)
  body!: string;

  @IsOptional()
  @IsString()
  @IsIn(POST_AUDIENCE)
  audience?: (typeof POST_AUDIENCE)[number];

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(100)
  @IsUUID("4", { each: true })
  selectedAudienceAccountIds?: string[];
}

export class CreatePostCommentDto {
  @IsString()
  @MinLength(1)
  @MaxLength(2000)
  body!: string;
}

export class ReportMemberDto {
  @IsUUID("4")
  reportedAccountId!: string;

  @IsOptional()
  @IsUUID("4")
  postId?: string;

  @IsString()
  @IsIn(REPORT_REASONS)
  reason!: (typeof REPORT_REASONS)[number];

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  details?: string;
}

export class CreateBusinessProfileDto {
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  displayName!: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;

  @IsOptional()
  @IsUrl({ protocols: ["https"], require_protocol: true })
  @MaxLength(2048)
  websiteUrl?: string;
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

export class DeactivateAccountDto {
  @IsString()
  @IsIn(["DEACTIVATE"])
  confirmation!: "DEACTIVATE";
}

export class UpdateMarketingConsentDto {
  @IsBoolean()
  consentAccepted!: boolean;
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
  @IsIn(["VERIFIED_MEMBERS", "PRIVATE"])
  visibility?: "VERIFIED_MEMBERS" | "PRIVATE";
}

export class CreateCommunityEventDto {
  @IsUUID("4")
  groupId!: string;

  @IsString()
  @MinLength(3)
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

  @IsISO8601({ strict: true })
  startsAt!: string;

  @IsISO8601({ strict: true })
  endsAt!: string;
}

