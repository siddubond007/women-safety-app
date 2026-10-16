import {
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  Length,
} from "class-validator";

export class StartEligibilityVerificationDto {
  // Optional at DTO level for backward compatibility with the old no-body
  // client contract. The service requires explicit consent before any enabled
  // provider can start.
  @IsOptional()
  @IsBoolean()
  consentAccepted?: boolean;

  @IsOptional()
  @IsString()
  @Length(1, 64)
  consentVersion?: string;

  @IsOptional()
  @IsBoolean()
  biometricProcessingConsented?: boolean;
}

export const ELIGIBILITY_SUPPORT_REQUEST_CATEGORIES = [
  "verificationHelp",
  "manualReviewRequest",
  "accessibilityAlternative",
  "appealGuidance",
] as const;

export type EligibilitySupportRequestCategoryApi =
  (typeof ELIGIBILITY_SUPPORT_REQUEST_CATEGORIES)[number];

export class CreateEligibilitySupportRequestDto {
  @IsIn(ELIGIBILITY_SUPPORT_REQUEST_CATEGORIES)
  category!: EligibilitySupportRequestCategoryApi;
}
