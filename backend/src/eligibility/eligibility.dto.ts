import {
  IsBoolean,
  IsDateString,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from "class-validator";

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

export class InitiateDecentroVerificationDto {
  @IsOptional()
  @IsBoolean()
  consent?: boolean;

  @IsOptional()
  @IsBoolean()
  consentAccepted?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  consentPurpose?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  consentVersion?: string;

  @IsOptional()
  @IsBoolean()
  biometricProcessingConsented?: boolean;

  // Redirects are intentionally controlled by the server; client URLs are ignored.
  @IsOptional()
  @IsString()
  @MaxLength(80)
  referenceId?: string;
}

export class LocalEligibilitySimulationDto {
  @IsString()
  @MinLength(1)
  @MaxLength(20)
  gender!: string;

  @IsDateString()
  dob!: string;
}
