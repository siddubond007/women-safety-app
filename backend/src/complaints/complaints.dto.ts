import {
  IsArray,
  IsBoolean,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from "class-validator";

export class CheckDescriptionPiiDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(4000)
  description!: string;
}

export class ScrubEvidenceMetadataDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  originalFileName!: string;

  @IsString()
  @IsOptional()
  @MaxLength(80)
  contentType?: string;

  @IsInt()
  @IsOptional()
  @Min(0)
  byteSize?: number;

  @IsString()
  @IsOptional()
  @MaxLength(120)
  deviceModel?: string;

  @IsBoolean()
  @IsOptional()
  visualBlurApplied?: boolean;
}

export class SubmitDiscreetComplaintDto {
  @IsString()
  @IsOptional()
  @MaxLength(24)
  reportingMode?: string; // 'ANONYMOUS' | 'CONFIDENTIAL'

  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  categorySlug!: string;

  @IsString()
  @IsOptional()
  @MaxLength(120)
  customCategoryLabel?: string;

  @IsString()
  @IsOptional()
  @MaxLength(32)
  urgency?: string; // 'HAPPENING_NOW' | 'PAST_INCIDENT' | 'REPEATED_PATTERN'

  @IsString()
  @IsNotEmpty()
  @MaxLength(4000)
  description!: string;

  @IsBoolean()
  @IsOptional()
  piiGuardRedacted?: boolean;

  @IsString()
  @IsOptional()
  @MaxLength(80)
  approximateDateLabel?: string;

  @IsString()
  @IsOptional()
  @MaxLength(80)
  approximateTimeWindow?: string;

  @IsString()
  @IsOptional()
  @MaxLength(32)
  locationType?: string; // 'COARSE_AREA' | 'ONLINE_IN_APP' | 'PREFER_NOT_TO_SAY'

  @IsString()
  @IsOptional()
  @MaxLength(180)
  generalLocationLabel?: string;

  @IsString()
  @IsOptional()
  @MaxLength(32)
  linkedTargetType?: string;

  @IsString()
  @IsOptional()
  @MaxLength(120)
  linkedTargetHandle?: string;

  @IsString()
  @IsOptional()
  @MaxLength(80)
  linkedPostId?: string;

  @IsString()
  @IsOptional()
  @MaxLength(80)
  linkedBusinessId?: string;

  @IsArray()
  @IsOptional()
  evidenceFiles?: Array<Record<string, unknown>>;

  @IsArray()
  @IsOptional()
  supportingLinks?: Array<Record<string, unknown> | string>;

  @IsBoolean()
  @IsOptional()
  wantsUpdates?: boolean;

  @IsBoolean()
  @IsOptional()
  submitAnonymouslyToReviewTeam?: boolean;

  @IsBoolean()
  @IsOptional()
  acknowledgedNonPoliceLegalNotice?: boolean;

  @IsString()
  @IsOptional()
  @MaxLength(128)
  clientRateLimitHint?: string;
}

export class AddComplainantReplyDto {
  @IsString()
  @IsOptional()
  @MaxLength(64)
  passkey?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(2000)
  message!: string;

  @IsArray()
  @IsOptional()
  additionalEvidenceFiles?: Array<Record<string, unknown>>;
}

export class SubmitComplaintAppealDto {
  @IsString()
  @IsOptional()
  @MaxLength(64)
  passkey?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  appealReasonCategory!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(2000)
  appealDescription!: string;

  @IsArray()
  @IsOptional()
  additionalEvidenceFiles?: Array<Record<string, unknown>>;
}

export class AssignAndClassifyComplaintDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  assignedReviewerId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  assignedReviewerName!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(24)
  severity!: string; // 'S1_CRITICAL' | 'S2_HIGH' | 'S3_MODERATE' | 'S4_LOW'

  @IsString()
  @IsNotEmpty()
  @MaxLength(24)
  priority!: string; // 'P1_URGENT' | 'P2_HIGH' | 'P3_STANDARD' | 'P4_ROUTINE'

  @IsString()
  @IsOptional()
  @MaxLength(500)
  reason?: string;
}

export class UpdateComplaintStatusDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  status!: string;

  @IsString()
  @IsOptional()
  @MaxLength(2000)
  publicMessageToComplainant?: string;

  @IsString()
  @IsOptional()
  @MaxLength(80)
  rejectionReasonCode?: string;

  @IsArray()
  @IsOptional()
  enforcementActions?: string[];

  @IsBoolean()
  @IsOptional()
  escalateToSpecialist?: boolean;
}

export class AddComplaintInternalNoteDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(2000)
  noteText!: string;

  @IsString()
  @IsOptional()
  @MaxLength(40)
  visibilityRole?: string; // 'SENIOR_REVIEWER' | 'SUPER_ADMIN'
}

export class AccessComplaintEvidenceDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  evidenceId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  action!: string; // 'REVEAL_VIEWER' | 'WATERMARKED_DOWNLOAD'

  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  justificationReason!: string;
}

export class MergeDuplicateComplaintsDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  primaryReferenceNumber!: string;

  @IsArray()
  duplicateReferenceNumbers!: string[];

  @IsString()
  @IsOptional()
  @MaxLength(64)
  clusterId?: string;

  @IsString()
  @IsOptional()
  @MaxLength(500)
  notes?: string;
}

export class HandleMaliciousComplaintDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  action!: string; // 'REJECT_MALICIOUS' | 'THROTTLE_BLINDED_BUCKET' | 'ESCALATE_SECURITY_AUDIT'

  @IsInt()
  @IsOptional()
  @Min(1)
  @Max(720)
  cooldownHours?: number;

  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  reason!: string;
}

export class UpsertComplaintCategoryConfigDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  slug!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  name!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(300)
  description!: string;

  @IsString()
  @IsOptional()
  @MaxLength(40)
  iconKey?: string;

  @IsString()
  @IsOptional()
  @MaxLength(40)
  flowerType?: string;

  @IsString()
  @IsOptional()
  @MaxLength(24)
  defaultPriority?: string;

  @IsString()
  @IsOptional()
  @MaxLength(24)
  defaultSeverity?: string;

  @IsString()
  @IsOptional()
  @MaxLength(2000)
  safetyGuidanceText?: string;

  @IsString()
  @IsOptional()
  @MaxLength(500)
  legalHelplineNote?: string;

  @IsBoolean()
  @IsOptional()
  isEnabled?: boolean;

  @IsInt()
  @IsOptional()
  @Min(1)
  @Max(100)
  displayOrder?: number;
}

export class UpdateComplaintRetentionPolicyDto {
  @IsInt()
  @Min(7)
  @Max(365)
  closedEvidenceRetentionDays!: number;

  @IsInt()
  @Min(7)
  @Max(365)
  rejectedReportRetentionDays!: number;

  @IsInt()
  @Min(1)
  @Max(90)
  technicalRateLimitLogDays!: number;
}
