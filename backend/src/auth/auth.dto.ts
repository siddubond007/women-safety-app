import {
  IsBoolean,
  IsEmail,
  IsIn,
  IsISO8601,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  MinLength,
} from "class-validator";

export class RequestOtpDto {
  @IsString()
  @Matches(/^\+[1-9]\d{0,2}$/)
  countryCode!: string;

  @IsString()
  @Matches(/^\d{6,15}$/)
  phoneNumber!: string;

  @IsString()
  @IsIn(["login", "registration"])
  purpose!: "login" | "registration";
}

export class ResendOtpDto {
  @IsUUID()
  challengeId!: string;
}

export class VerifyOtpDto {
  @IsUUID()
  challengeId!: string;

  @IsString()
  @Matches(/^\d{6}$/)
  code!: string;
}

export class CreateProfileDto {
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  @Matches(/^[\p{L}\p{M}\p{N}\s.'’_-]+$/u)
  displayName!: string;

  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  dateOfBirth!: string;

  @IsOptional()
  @IsEmail()
  @MaxLength(254)
  email?: string | null;

  @IsString()
  @IsIn(["draft"])
  termsVersion!: "draft";

  @IsString()
  @IsIn(["draft"])
  privacyVersion!: "draft";

  @IsISO8601({ strict: true })
  acceptedAt!: string;

  @IsBoolean()
  optionalUpdatesAccepted!: boolean;
}
