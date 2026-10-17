import { IsBoolean, IsOptional, IsString, MaxLength, MinLength } from "class-validator";

export class StartManualReviewDto {
  @IsBoolean()
  consentAccepted!: boolean;

  @IsString()
  @MinLength(1)
  @MaxLength(64)
  consentVersion!: string;

  // Accepted for compatibility with the existing mobile request shape.
  @IsOptional()
  @IsBoolean()
  biometricProcessingConsented?: boolean;
}
