import {
  IsBoolean,
  IsEmail,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from "class-validator";

export class StagingTestAdminLoginDto {
  @IsString()
  @MinLength(8)
  @MaxLength(500)
  token!: string;

  @IsOptional()
  @IsString()
  @MinLength(6)
  @MaxLength(128)
  mfaCode?: string;
}

export class StagingTestAdminBootstrapDto {
  @IsString()
  @MinLength(8)
  @MaxLength(500)
  token!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(120)
  fullName!: string;

  @IsEmail()
  @MaxLength(254)
  email!: string;

  @IsString()
  @MinLength(12)
  @MaxLength(128)
  password!: string;
}

export class StagingTestAccessDecisionDto {
  @IsBoolean()
  acknowledgedTestOnly!: boolean;

  @IsString()
  @MinLength(10)
  @MaxLength(500)
  reason!: string;
}


export class StagingSyntheticFixtureDto {
  @IsBoolean()
  acknowledgedTestOnly!: boolean;

  @IsString()
  @MinLength(10)
  @MaxLength(500)
  reason!: string;
}
