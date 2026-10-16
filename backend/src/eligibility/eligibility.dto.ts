import { IsBoolean, IsIn, IsString, Length } from "class-validator";

export class StartEligibilityVerificationDto {
  @IsBoolean()
  consentAccepted!: boolean;

  @IsString()
  @Length(1, 64)
  consentVersion!: string;

  @IsBoolean()
  biometricProcessingConsented!: boolean;
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
