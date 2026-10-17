import { IsIn, IsOptional, IsString, MaxLength, MinLength } from "class-validator";

export class DevelopmentMemberStateDto {
  @IsOptional()
  @IsIn(["PENDING_VERIFICATION", "ACTIVE", "RESTRICTED", "SUSPENDED", "DELETED"])
  accountStatus?: "PENDING_VERIFICATION" | "ACTIVE" | "RESTRICTED" | "SUSPENDED" | "DELETED";

  @IsOptional()
  @IsIn(["UNVERIFIED", "VERIFIED", "REJECTED"])
  verificationStatus?: "UNVERIFIED" | "VERIFIED" | "REJECTED";

  @IsString()
  @MinLength(10)
  @MaxLength(500)
  reason!: string;
}
