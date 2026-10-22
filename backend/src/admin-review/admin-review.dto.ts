import {
  IsBoolean,
  IsIn,
  IsInt,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from "class-validator";

export class ManualEligibilityDecisionDto {
  @IsIn(["approve", "reject"])
  decision!: "approve" | "reject";

  @IsString()
  @MinLength(10)
  @MaxLength(500)
  reason!: string;

  @IsBoolean()
  reviewedEvidence!: boolean;
}

export class UpdateRegistrationPolicyDto {
  @IsInt()
  @Min(13)
  @Max(100)
  minimumAgeYears!: number;

  @IsString()
  @MinLength(10)
  @MaxLength(500)
  reason!: string;
}