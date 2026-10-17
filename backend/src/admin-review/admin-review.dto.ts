import { IsBoolean, IsIn, IsString, MaxLength, MinLength } from "class-validator";

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