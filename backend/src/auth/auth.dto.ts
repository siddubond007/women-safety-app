import { ApiProperty, ApiPropertyOptional } from "@nestjs/swagger";
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsEmail,
  IsIn,
  IsISO8601,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  MinLength,
} from "class-validator";

export class RequestOtpDto {
  @ApiProperty({ example: "+91" })
  @IsString()
  @Matches(/^\+[1-9]\d{0,3}$/, {
    message: "Select a valid international country code.",
  })
  countryCode!: string;

  @ApiProperty({ example: "9876543210" })
  @IsString()
  @Matches(/^\d{6,14}$/, {
    message: "Enter a valid mobile number with digits only.",
  })
  phoneNumber!: string;

  @ApiProperty({ enum: ["login", "registration"] })
  @IsString()
  @IsIn(["login", "registration"])
  purpose!: "login" | "registration";
}

export class ResendOtpDto {
  @ApiProperty()
  @IsUUID("4", { message: "Enter a valid OTP request identifier." })
  challengeId!: string;
}

export class VerifyOtpDto {
  @ApiProperty()
  @IsUUID("4", { message: "Enter a valid OTP request identifier." })
  challengeId!: string;

  @ApiProperty({ example: "123456" })
  @IsString()
  @Matches(/^\d{6}$/, { message: "Enter the six-digit verification code." })
  code!: string;
}

export class CreateProfileDto {
  @ApiProperty({ example: "Aarohi Sharma" })
  @IsString()
  @IsNotEmpty()
  @MinLength(2)
  @MaxLength(100)
  @Matches(/^[^\d]+$/, {
    message: "Full name cannot contain numbers.",
  })
  displayName!: string;

  @ApiPropertyOptional({ example: "@aarohi_sharma" })
  @IsOptional()
  @IsString()
  @Matches(/^@?[a-zA-Z0-9_]{3,24}$/, {
    message:
      "Username must be 3 to 24 characters using letters, numbers, or underscores.",
  })
  username?: string | null;

  @ApiProperty({ example: "1999-04-12" })
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, {
    message: "Enter date of birth in YYYY-MM-DD format.",
  })
  dateOfBirth!: string;

  @ApiPropertyOptional({ example: "aarohi@example.com" })
  @IsOptional()
  @IsEmail({}, { message: "Enter a valid email address." })
  @MaxLength(254)
  email?: string | null;

  @ApiPropertyOptional({ example: "assets/images/profile/avatar_ananya.webp" })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  avatarAsset?: string | null;

  @ApiPropertyOptional({
    type: [String],
    example: ["Mental Wellness", "WomenInTech"],
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(16)
  @IsString({ each: true })
  @MaxLength(40, { each: true })
  interests?: string[];

  @ApiProperty({ example: "seed-draft-v1" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  termsVersion!: string;

  @ApiProperty({ example: "seed-draft-v1" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  privacyVersion!: string;

  @ApiProperty()
  @IsISO8601()
  acceptedAt!: string;

  @ApiProperty()
  @IsBoolean()
  optionalUpdatesAccepted!: boolean;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  eligibilityConfirmed?: boolean;
}
