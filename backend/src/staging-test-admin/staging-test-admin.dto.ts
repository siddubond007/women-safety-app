import { IsBoolean, IsString, MaxLength, MinLength } from "class-validator";

export class StagingTestAdminLoginDto {
  @IsString()
  @MinLength(8)
  @MaxLength(500)
  token!: string;
}

export class StagingTestAccessDecisionDto {
  @IsBoolean()
  acknowledgedTestOnly!: boolean;

  @IsString()
  @MinLength(10)
  @MaxLength(500)
  reason!: string;
}
