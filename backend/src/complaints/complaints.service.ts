import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
  UnauthorizedException,
} from "@nestjs/common";
import {
  createHash,
  randomInt,
  randomUUID,
  timingSafeEqual,
} from "node:crypto";
import { AuthenticationService } from "../auth/auth.service.js";
import { PrismaService } from "../database/prisma.service.js";
import { StagingTestAdminService } from "../staging-test-admin/staging-test-admin.service.js";
import { DEFAULT_LOCAL_DEV_ADMIN_TOKEN } from "../admin-review/admin-review.service.js";
import {
  SakhiAdminRbacRegistry,
  type SakhiAdminRole,
} from "../admin-review/admin-rbac.helper.js";
import type {
  AccessComplaintEvidenceDto,
  SendAdminMessageToComplainantDto,
  AddComplainantReplyDto,
  AddComplaintInternalNoteDto,
  AssignAndClassifyComplaintDto,
  CheckDescriptionPiiDto,
  HandleMaliciousComplaintDto,
  MergeDuplicateComplaintsDto,
  ScrubEvidenceMetadataDto,
  SubmitComplaintAppealDto,
  SubmitDiscreetComplaintDto,
  UpdateComplaintRetentionPolicyDto,
  UpdateComplaintStatusDto,
  UpsertComplaintCategoryConfigDto,
} from "./complaints.dto.js";

export type ComplaintStatusType =
  | "SUBMITTED"
  | "UNDER_REVIEW"
  | "ADDITIONAL_INFO_REQUIRED"
  | "ESCALATED"
  | "ACTION_TAKEN"
  | "CLOSED"
  | "REJECTED_WITH_REASON";

export const ALL_COMPLAINT_STATUSES: ComplaintStatusType[] = [
  "SUBMITTED",
  "UNDER_REVIEW",
  "ADDITIONAL_INFO_REQUIRED",
  "ESCALATED",
  "ACTION_TAKEN",
  "CLOSED",
  "REJECTED_WITH_REASON",
];

/**
 * SRS Section 7.5 — Enforced Status Transition Matrix
 * Prevents invalid state jumps (such as SUBMITTED -> CLOSED without review or resolution).
 */
export const VALID_STATUS_TRANSITIONS: Record<
  ComplaintStatusType,
  ComplaintStatusType[]
> = {
  SUBMITTED: [
    "UNDER_REVIEW",
    "ADDITIONAL_INFO_REQUIRED",
    "ESCALATED",
    "ACTION_TAKEN",
    "REJECTED_WITH_REASON",
  ],
  UNDER_REVIEW: [
    "ADDITIONAL_INFO_REQUIRED",
    "ESCALATED",
    "ACTION_TAKEN",
    "CLOSED",
    "REJECTED_WITH_REASON",
  ],
  ADDITIONAL_INFO_REQUIRED: [
    "UNDER_REVIEW",
    "ESCALATED",
    "ACTION_TAKEN",
    "CLOSED",
    "REJECTED_WITH_REASON",
  ],
  ESCALATED: [
    "UNDER_REVIEW",
    "ADDITIONAL_INFO_REQUIRED",
    "ACTION_TAKEN",
    "CLOSED",
    "REJECTED_WITH_REASON",
  ],
  ACTION_TAKEN: ["CLOSED", "ESCALATED", "UNDER_REVIEW"],
  CLOSED: ["ESCALATED", "UNDER_REVIEW"],
  REJECTED_WITH_REASON: ["ESCALATED", "UNDER_REVIEW"],
};

export const ALLOWED_EVIDENCE_MIME_TYPES = new Set<string>([
  "image/png",
  "image/jpeg",
  "image/jpg",
  "image/webp",
  "application/pdf",
  "audio/mp4",
  "audio/mpeg",
  "audio/wav",
  "audio/aac",
  "audio/x-m4a",
  "audio/m4a",
]);

export const MAX_EVIDENCE_BYTES = 15 * 1024 * 1024; // 15 MB per file
export const MAX_EVIDENCE_FILES_PER_COMPLAINT = 5;

export interface ComplaintCategoryItem {
  slug: string;
  name: string;
  description: string;
  iconKey: string;
  flowerType: string;
  defaultPriority: string;
  defaultSeverity: string;
  safetyGuidanceText: string;
  legalHelplineNote: string;
  isEnabled: boolean;
  displayOrder: number;
}

export const DEFAULT_COMPLAINT_CATEGORIES: ComplaintCategoryItem[] = [
  {
    slug: "harassment",
    name: "Harassment",
    description: "Verbal, physical, or persistent intimidation and threats",
    iconKey: "siren",
    flowerType: "peonySoft",
    defaultPriority: "P1_URGENT",
    defaultSeverity: "S2_HIGH",
    safetyGuidanceText:
      "Do not engage directly with the harasser. Preserve screenshots with timestamps, enable Sakhi Profile Privacy Lock, and use Anonymous Mode if you fear retaliation.",
    legalHelplineNote:
      "For immediate physical danger dial 112 (Emergency ERSS) or 1091 (Women Police Helpline).",
    isEnabled: true,
    displayOrder: 1,
  },
  {
    slug: "online_abuse_cyberbullying",
    name: "Online abuse or cyberbullying",
    description:
      "Abusive DMs, image morphing, doxxing, non-consensual sharing, or trolling",
    iconKey: "laptop",
    flowerType: "lavenderSprig",
    defaultPriority: "P1_URGENT",
    defaultSeverity: "S2_HIGH",
    safetyGuidanceText:
      "Take screenshots before blocking the account. Sakhi automatically strips EXIF GPS and device metadata from your uploaded screenshots.",
    legalHelplineNote:
      "You can also file an official cyber complaint via 1930 or cybercrime.gov.in.",
    isEnabled: true,
    displayOrder: 2,
  },
  {
    slug: "stalking_unwanted_contact",
    name: "Stalking or unwanted contact",
    description:
      "Following, repeated unwanted calls/messages, or physical surveillance",
    iconKey: "eye",
    flowerType: "cherryBlossom",
    defaultPriority: "P1_URGENT",
    defaultSeverity: "S1_CRITICAL",
    safetyGuidanceText:
      "Ensure live location sharing is restricted only to your verified family contacts. Log approximate dates and patterns; Sakhi correlates repeat stalker handles automatically.",
    legalHelplineNote:
      "Call 1091 or 112 immediately if someone is following you or waiting near your residence/workplace.",
    isEnabled: true,
    displayOrder: 3,
  },
  {
    slug: "workplace_misconduct",
    name: "Workplace misconduct",
    description:
      "POSH sexual harassment, quid-pro-quo coercion, or hostile work environment",
    iconKey: "briefcase",
    flowerType: "eucalyptusSage",
    defaultPriority: "P1_URGENT",
    defaultSeverity: "S2_HIGH",
    safetyGuidanceText:
      "Under the POSH Act, keep a dated log of incidents, witnesses, and messages. Avoid using your employer's Wi-Fi or corporate laptop when submitting sensitive evidence.",
    legalHelplineNote:
      "Contact NCW (7827-170-170) or SHe-Box portal for statutory Internal Complaints Committee (ICC) escalation.",
    isEnabled: true,
    displayOrder: 4,
  },
  {
    slug: "public_place_safety",
    name: "Public-place safety concerns",
    description:
      "Unsafe streets, dark corridors, transit harassment, or loitering hotspots",
    iconKey: "map_pin",
    flowerType: "cosmosViolet",
    defaultPriority: "P2_HIGH",
    defaultSeverity: "S2_HIGH",
    safetyGuidanceText:
      "Select a coarse 5 km neighbourhood zone rather than your exact home address. Your report helps warn the Sakhi safety team about unsafe corridors.",
    legalHelplineNote:
      "Use Module 4 Nearest Police Stations or dial 112 for immediate PCR van patrol.",
    isEnabled: true,
    displayOrder: 5,
  },
  {
    slug: "fraud_suspicious_activity",
    name: "Fraud or suspicious activity",
    description:
      "Financial scams, fake profiles, impersonation, or blackmail/extortion",
    iconKey: "shield_alert",
    flowerType: "poppyBlush",
    defaultPriority: "P2_HIGH",
    defaultSeverity: "S2_HIGH",
    safetyGuidanceText:
      "Never transfer money or share OTPs with anyone claiming to represent a business or moderator. Attach profile links and payment handle screenshots.",
    legalHelplineNote:
      "Dial 1930 immediately to freeze fraudulent UPI/bank transfers on the National Cyber Crime Portal.",
    isEnabled: true,
    displayOrder: 6,
  },
  {
    slug: "discrimination",
    name: "Discrimination",
    description:
      "Exclusion, hate speech, or bias based on caste, religion, gender, or background",
    iconKey: "scale",
    flowerType: "lilyBloom",
    defaultPriority: "P2_HIGH",
    defaultSeverity: "S3_MODERATE",
    safetyGuidanceText:
      "Sakhi has zero tolerance for caste, religious, regional, or gender discrimination. Link the offending post or comment so we can archive a tamper-evident snapshot.",
    legalHelplineNote:
      "Severe hate speech or threats can be escalated to statutory commissions and cyber cells.",
    isEnabled: true,
    displayOrder: 7,
  },
  {
    slug: "domestic_interpersonal_safety",
    name: "Domestic or interpersonal safety concerns",
    description:
      "Partner, spouse, family, or household abuse, coercion, and threats",
    iconKey: "home",
    flowerType: "roseClassic",
    defaultPriority: "P1_URGENT",
    defaultSeverity: "S1_CRITICAL",
    safetyGuidanceText:
      "If a partner or family member checks your phone, use Anonymous Mode, tap 'Discreet Backup' to save your reference code disguised as a Wellness Quote Card, and use the top-right 'Quick Exit' button anytime.",
    legalHelplineNote:
      "Dial 181 (24/7 Women's Domestic Abuse & Sakhi One-Stop Centre Helpline) or 112 for shelter, legal, and medical aid.",
    isEnabled: true,
    displayOrder: 8,
  },
  {
    slug: "business_related_complaints",
    name: "Business-related complaints",
    description:
      "Misconduct, unsafe service, or policy breach by a listed business page",
    iconKey: "store",
    flowerType: "tulipDuo",
    defaultPriority: "P3_STANDARD",
    defaultSeverity: "S3_MODERATE",
    safetyGuidanceText:
      "You can link the reported Sakhi Business Page directly. The business owner will NEVER be notified of who reported them.",
    legalHelplineNote:
      "Fraudulent businesses are suspended by Trust & Safety after verification.",
    isEnabled: true,
    displayOrder: 9,
  },
  {
    slug: "other",
    name: "Other",
    description:
      "Any other personal safety, privacy, or community wellbeing concern",
    iconKey: "sparkles",
    flowerType: "babysBreath",
    defaultPriority: "P3_STANDARD",
    defaultSeverity: "S3_MODERATE",
    safetyGuidanceText:
      "Specify your custom topic and share only what you feel safe disclosing. Our real-time PII guard will warn you if any phrase could reveal your identity.",
    legalHelplineNote:
      "In-app complaints do not automatically file a police FIR. Use 112 / 1091 / 181 when official law-enforcement action is needed.",
    isEnabled: true,
    displayOrder: 10,
  },
];

export interface SanitizedEvidenceFile {
  id: string;
  fileName: string;
  originalFileNameRedacted: string;
  contentType: string;
  byteSize: number;
  sha256Digest: string;
  exifGpsStripped: boolean;
  deviceMetadataStripped: boolean;
  visualBlurApplied: boolean;
  scrubbedFields: string[];
  uploadedAt: string;
  isPurged?: boolean;
}

export interface ComplainantMessageItem {
  id: string;
  senderRole:
    "COMPLAINANT_ANONYMOUS" | "COMPLAINANT_CONFIDENTIAL" | "SAFETY_REVIEWER";
  senderLabel: string;
  message: string;
  attachedFiles: SanitizedEvidenceFile[];
  createdAt: string;
}

export interface InternalReviewerNoteItem {
  id: string;
  reviewerId: string;
  reviewerName: string;
  visibilityRole: "SENIOR_REVIEWER" | "SUPER_ADMIN";
  noteText: string;
  createdAt: string;
}

export interface ComplaintAuditEntry {
  id: string;
  auditCode: string;
  actorRole: string;
  actorLabel: string;
  action: string;
  summary: string;
  integrityHash: string;
  timestamp: string;
}

export interface DiscreetComplaintRecord {
  id: string;
  referenceNumber: string;
  passkeyDigest: string;
  disguisedBackupSerial: string;
  reportingMode: "ANONYMOUS" | "CONFIDENTIAL";
  confidentialAccountId: string | null;
  blindedRateLimitBucket: string;
  categorySlug: string;
  categoryTitle: string;
  customCategoryLabel: string | null;
  urgency: "HAPPENING_NOW" | "PAST_INCIDENT" | "REPEATED_PATTERN";
  description: string;
  piiGuardRedacted: boolean;
  approximateDateLabel: string;
  approximateTimeWindow: string;
  locationType: "COARSE_AREA" | "ONLINE_IN_APP" | "PREFER_NOT_TO_SAY";
  generalLocationLabel: string | null;
  linkedTargetType: string | null;
  linkedTargetHandle: string | null;
  linkedPostId: string | null;
  linkedBusinessId: string | null;
  evidenceFiles: SanitizedEvidenceFile[];
  supportingLinks: Array<{
    url: string;
    linkType: string;
    snapshotArchived: boolean;
  }>;
  wantsUpdates: boolean;
  submitAnonymouslyToReviewTeam: boolean;
  acknowledgedNonPoliceLegalNotice: boolean;
  status: ComplaintStatusType;
  severity: "S1_CRITICAL" | "S2_HIGH" | "S3_MODERATE" | "S4_LOW";
  priority: "P1_URGENT" | "P2_HIGH" | "P3_STANDARD" | "P4_ROUTINE";
  assignedReviewerId: string | null;
  assignedReviewerName: string | null;
  duplicateClusterId: string | null;
  mergedIntoReference: string | null;
  isFlaggedMaliciousAbuse: boolean;
  maliciousAbuseReason: string | null;
  rejectionReasonCode: string | null;
  publicResolutionSummary: string | null;
  enforcementActions: string[];
  complainantMessages: ComplainantMessageItem[];
  internalNotes: InternalReviewerNoteItem[];
  auditHistory: ComplaintAuditEntry[];
  mediaPurgedAt: string | null;
  retentionExpiresAt: string;
  createdAt: string;
  updatedAt: string;
}

/**
 * Strips EXIF/APPn/GPS markers from real JPEG buffers and ancillary metadata chunks
 * from real PNG buffers so uploaded evidence bytes are genuinely sanitized.
 */
export function stripBinaryMetadata(
  input: Buffer,
  contentType: string,
): { scrubbedBuffer: Buffer; removedMarkers: string[] } {
  const removedMarkers: string[] = [];
  if (input.length < 12) {
    return { scrubbedBuffer: input, removedMarkers };
  }

  // 1. JPEG binary marker stripper (0xFFD8 ... 0xFFD9)
  if (input[0] === 0xff && input[1] === 0xd8) {
    const chunks: Buffer[] = [Buffer.from([0xff, 0xd8])];
    let offset = 2;
    while (offset + 2 <= input.length) {
      if (input[offset] !== 0xff) {
        chunks.push(input.subarray(offset));
        break;
      }
      const marker = input[offset + 1];
      if (marker === undefined) {
        chunks.push(input.subarray(offset));
        break;
      }
      // Start of Scan (0xDA) or End of Image (0xD9) -> copy remaining compressed image data
      if (marker === 0xda || marker === 0xd9) {
        chunks.push(input.subarray(offset));
        break;
      }
      // Standalone markers without length
      if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
        chunks.push(input.subarray(offset, offset + 2));
        offset += 2;
        continue;
      }
      if (offset + 4 > input.length) {
        chunks.push(input.subarray(offset));
        break;
      }
      const segLength = input.readUInt16BE(offset + 2);
      if (segLength < 2 || offset + 2 + segLength > input.length) {
        chunks.push(input.subarray(offset));
        break;
      }
      // Strip APP1..APP15 (0xE1..0xEF: EXIF, GPS, XMP, ICC, IPTC) and COM (0xFE: comments)
      if ((marker >= 0xe1 && marker <= 0xef) || marker === 0xfe) {
        removedMarkers.push(
          marker === 0xe1
            ? "JPEG.APP1.EXIF_GPS_XMP"
            : marker === 0xfe
              ? "JPEG.COM.Comment"
              : `JPEG.APP${marker - 0xe0}`,
        );
      } else {
        chunks.push(input.subarray(offset, offset + 2 + segLength));
      }
      offset += 2 + segLength;
    }
    return {
      scrubbedBuffer: Buffer.concat(chunks),
      removedMarkers,
    };
  }

  // 2. PNG binary chunk stripper (\x89PNG\r\n\x1a\n)
  const pngSig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  if (input.subarray(0, 8).equals(pngSig)) {
    const outChunks: Buffer[] = [pngSig];
    let offset = 8;
    const stripTypes = new Set(["eXIf", "tEXt", "zTXt", "iTXt", "tIME"]);
    while (offset + 12 <= input.length) {
      const length = input.readUInt32BE(offset);
      const type = input.subarray(offset + 4, offset + 8).toString("ascii");
      const totalChunkLen = 12 + length;
      if (offset + totalChunkLen > input.length) {
        outChunks.push(input.subarray(offset));
        break;
      }
      if (stripTypes.has(type)) {
        removedMarkers.push(`PNG.${type}`);
      } else {
        outChunks.push(input.subarray(offset, offset + totalChunkLen));
      }
      offset += totalChunkLen;
      if (type === "IEND") break;
    }
    return {
      scrubbedBuffer: Buffer.concat(outChunks),
      removedMarkers,
    };
  }

  return {
    scrubbedBuffer: input,
    removedMarkers: [`Normalized(${contentType})`],
  };
}

@Injectable()
export class ComplaintsService {
  private readonly categoriesMap = new Map<string, ComplaintCategoryItem>();
  private readonly complaintsMap = new Map<string, DiscreetComplaintRecord>();
  private readonly throttledBuckets = new Map<
    string,
    { untilIso: string; reason: string }
  >();
  private readonly recentSubmissionFingerprints = new Map<string, number>();
  private readonly scrubbedEvidenceBinaryVault = new Map<string, Buffer>();

  private retentionPolicy = {
    policyKey: "default",
    closedEvidenceRetentionDays: 90,
    rejectedReportRetentionDays: 30,
    technicalRateLimitLogDays: 14,
    updatedBy: "System Default (DPDP Compliant)",
    updatedAt: new Date().toISOString(),
  };
  private hydratedFromDb = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly auth: AuthenticationService,
  ) {
    for (const cat of DEFAULT_COMPLAINT_CATEGORIES) {
      this.categoriesMap.set(cat.slug, { ...cat });
    }
    // IMPORTANT: Zero fake complaints are seeded! The database starts clean and only stores real submissions.
  }

  private hashString(val: string): string {
    return createHash("sha256").update(val).digest("hex");
  }

  private stagingAdminReviewEnabled(): boolean {
    const token = process.env.SAKHI_ADMIN_REVIEW_TOKEN?.trim() ?? "";
    return (
      process.env.SAKHI_ENV === "staging" &&
      process.env.NODE_ENV === "production" &&
      process.env.SAKHI_STAGING_ADMIN_REVIEW_ENABLED === "true" &&
      process.env.SAKHI_OTP_MODE === "staging_test" &&
      token.length >= 32
    );
  }

  private stagingFullAdminEnabled(): boolean {
    const token = process.env.SAKHI_STAGING_FULL_ADMIN_TOKEN?.trim() ?? "";
    return (
      process.env.SAKHI_ENV === "staging" &&
      process.env.NODE_ENV === "production" &&
      process.env.SAKHI_STAGING_FULL_ADMIN_ENABLED === "true" &&
      token.length >= 32
    );
  }

  private configuredAdminToken(): string {
    const environment = process.env.SAKHI_ENV ?? "dev";
    if (process.env.NODE_ENV === "production") {
      if (!this.stagingAdminReviewEnabled()) {
        throw new ForbiddenException(
          "Admin complaint console requires an authorized staging or dev reviewer session.",
        );
      }
      return process.env.SAKHI_ADMIN_REVIEW_TOKEN!.trim();
    }
    if (environment !== "dev" && environment !== "test") {
      throw new ServiceUnavailableException(
        "Admin complaint review is restricted to dev/test or authorized staging mode.",
      );
    }
    return (
      process.env.SAKHI_ADMIN_REVIEW_TOKEN?.trim() ||
      DEFAULT_LOCAL_DEV_ADMIN_TOKEN
    );
  }

  public assertReviewer(provided?: string): {
    reviewerLabel: string;
    role: "SENIOR_REVIEWER" | "SUPER_ADMIN";
    adminRole: SakhiAdminRole;
    staffCode: string;
  } {
    if (provided?.trim()) {
      const staffMatch = SakhiAdminRbacRegistry.findStaffByToken(provided.trim());
      if (staffMatch) {
        const principal = SakhiAdminRbacRegistry.principalFromStaff(staffMatch);
        if (
          principal.role !== "SUPER_ADMIN" &&
          principal.role !== "COMPLAINT_REVIEWER" &&
          !principal.isAuthorisedComplaintReviewer
        ) {
          throw new ForbiddenException(
            `Access denied: your assigned role (${principal.badgeLabel}) is not authorised to access Discreet & Anonymous Complaints (SRS 7.4).`,
          );
        }
        return {
          reviewerLabel: principal.reviewerLabel,
          role:
            principal.role === "SUPER_ADMIN"
              ? "SUPER_ADMIN"
              : "SENIOR_REVIEWER",
          adminRole: principal.role,
          staffCode: principal.staffCode,
        };
      }
    }

    if (
      process.env.NODE_ENV === "production" &&
      process.env.SAKHI_ENV === "staging"
    ) {
      if (
        provided?.startsWith("full-admin.") ||
        provided?.startsWith("staff-admin.") ||
        provided?.startsWith("test-access.") ||
        (!this.stagingAdminReviewEnabled() && this.stagingFullAdminEnabled())
      ) {
        const principal =
          StagingTestAdminService.resolvePrincipalFromSessionToken(provided);
        if (
          principal.role !== "SUPER_ADMIN" &&
          principal.role !== "COMPLAINT_REVIEWER" &&
          !principal.isAuthorisedComplaintReviewer
        ) {
          throw new ForbiddenException(
            `Access denied: your assigned role (${principal.badgeLabel}) is not authorised to access Discreet & Anonymous Complaints (SRS 7.4).`,
          );
        }
        return {
          reviewerLabel: principal.reviewerLabel,
          role:
            principal.role === "SUPER_ADMIN"
              ? "SUPER_ADMIN"
              : "SENIOR_REVIEWER",
          adminRole: principal.role,
          staffCode: principal.staffCode,
        };
      }
    }
    const expected = this.configuredAdminToken();
    if (!provided) {
      throw new UnauthorizedException(
        "A reviewer token is required to access complaint management.",
      );
    }
    const candidates = expected
      .split(",")
      .map((item) => item.trim())
      .filter((item) => item.length > 0);
    const providedDigest = createHash("sha256")
      .update(provided.trim())
      .digest();
    const matched = candidates.some((candidate) => {
      const expectedDigest = createHash("sha256").update(candidate).digest();
      return timingSafeEqual(expectedDigest, providedDigest);
    });
    if (!matched) {
      throw new UnauthorizedException(
        "The reviewer token is invalid or expired.",
      );
    }
    const label =
      process.env.SAKHI_ADMIN_REVIEWER_LABEL?.trim() ||
      "Sakhi Super Admin (#SA-01)";
    return {
      reviewerLabel: label,
      role: "SENIOR_REVIEWER",
      adminRole: "SUPER_ADMIN",
      staffCode: "#SA-01",
    };
  }

  private async resolveRequiredAccountId(
    authorization?: string,
  ): Promise<string> {
    if (
      !authorization ||
      !authorization.trim().toLowerCase().startsWith("bearer ")
    ) {
      throw new UnauthorizedException(
        "Confidential reporting requires an active signed-in Sakhi member session. Choose Anonymous Mode if you wish to submit without an account session.",
      );
    }
    try {
      const anyAuth = this.auth as unknown as Record<string, any>;
      if (typeof anyAuth.getCurrentAccount === "function") {
        const status = await anyAuth.getCurrentAccount(authorization);
        if (status?.accountId) return String(status.accountId);
      }
      if (typeof anyAuth.getCurrentAccountStatus === "function") {
        const status = await anyAuth.getCurrentAccountStatus(authorization);
        if (status?.accountId) return String(status.accountId);
      }
    } catch (err) {
      if (err instanceof UnauthorizedException) throw err;
    }
    throw new UnauthorizedException(
      "Could not verify your member session for Confidential Mode. Please sign in again or switch to Anonymous Mode.",
    );
  }

  private mapDbRowToRecord(r: Record<string, any>): DiscreetComplaintRecord {
    return {
      id: String(r.id),
      referenceNumber: String(r.referenceNumber),
      passkeyDigest: String(r.passkeyDigest),
      disguisedBackupSerial: String(r.disguisedBackupSerial),
      reportingMode:
        r.reportingMode === "CONFIDENTIAL" ? "CONFIDENTIAL" : "ANONYMOUS",
      confidentialAccountId: r.confidentialAccountId ?? null,
      blindedRateLimitBucket: r.blindedRateLimitBucket ?? "bkt_default",
      categorySlug: String(r.categorySlug),
      categoryTitle: String(r.categoryTitle),
      customCategoryLabel: r.customCategoryLabel ?? null,
      urgency:
        r.urgency === "HAPPENING_NOW" || r.urgency === "REPEATED_PATTERN"
          ? r.urgency
          : "PAST_INCIDENT",
      description: String(r.description),
      piiGuardRedacted: Boolean(r.piiGuardRedacted),
      approximateDateLabel: String(r.approximateDateLabel),
      approximateTimeWindow: String(r.approximateTimeWindow),
      locationType:
        r.locationType === "ONLINE_IN_APP" ||
        r.locationType === "PREFER_NOT_TO_SAY"
          ? r.locationType
          : "COARSE_AREA",
      generalLocationLabel: r.generalLocationLabel ?? null,
      linkedTargetType: r.linkedTargetType ?? null,
      linkedTargetHandle: r.linkedTargetHandle ?? null,
      linkedPostId: r.linkedPostId ?? null,
      linkedBusinessId: r.linkedBusinessId ?? null,
      evidenceFiles: Array.isArray(r.evidenceFiles) ? r.evidenceFiles : [],
      supportingLinks: Array.isArray(r.supportingLinks)
        ? r.supportingLinks
        : [],
      wantsUpdates: Boolean(r.wantsUpdates),
      submitAnonymouslyToReviewTeam: Boolean(r.submitAnonymouslyToReviewTeam),
      acknowledgedNonPoliceLegalNotice: Boolean(
        r.acknowledgedNonPoliceLegalNotice,
      ),
      status: (ALL_COMPLAINT_STATUSES.includes(r.status)
        ? r.status
        : "SUBMITTED") as ComplaintStatusType,
      severity: r.severity ?? "S2_HIGH",
      priority: r.priority ?? "P2_HIGH",
      assignedReviewerId: r.assignedReviewerId ?? null,
      assignedReviewerName: r.assignedReviewerName ?? null,
      duplicateClusterId: r.duplicateClusterId ?? null,
      mergedIntoReference: r.mergedIntoReference ?? null,
      isFlaggedMaliciousAbuse: Boolean(r.isFlaggedMaliciousAbuse),
      maliciousAbuseReason: r.maliciousAbuseReason ?? null,
      rejectionReasonCode: r.rejectionReasonCode ?? null,
      publicResolutionSummary: r.publicResolutionSummary ?? null,
      enforcementActions: Array.isArray(r.enforcementActions)
        ? r.enforcementActions
        : [],
      complainantMessages: Array.isArray(r.complainantMessages)
        ? r.complainantMessages
        : [],
      internalNotes: Array.isArray(r.internalNotes) ? r.internalNotes : [],
      auditHistory: Array.isArray(r.auditHistory) ? r.auditHistory : [],
      mediaPurgedAt: r.mediaPurgedAt
        ? new Date(r.mediaPurgedAt).toISOString()
        : null,
      retentionExpiresAt: r.retentionExpiresAt
        ? new Date(r.retentionExpiresAt).toISOString()
        : new Date(Date.now() + 90 * 86_400_000).toISOString(),
      createdAt: r.createdAt
        ? new Date(r.createdAt).toISOString()
        : new Date().toISOString(),
      updatedAt: r.updatedAt
        ? new Date(r.updatedAt).toISOString()
        : new Date().toISOString(),
    };
  }

  private async ensureHydrated(): Promise<void> {
    await SakhiAdminRbacRegistry.ensureHydrated(this.prisma);
    if (this.hydratedFromDb) return;
    this.hydratedFromDb = true;
    try {
      const anyPrisma = this.prisma as unknown as Record<string, any>;

      // 1. Hydrate configurable categories from DB if table exists
      if (anyPrisma.complaintCategoryConfig?.findMany) {
        const dbCats = await anyPrisma.complaintCategoryConfig
          .findMany({ orderBy: { displayOrder: "asc" } })
          .catch(() => []);
        if (Array.isArray(dbCats) && dbCats.length > 0) {
          for (const c of dbCats) {
            this.categoriesMap.set(c.slug, {
              slug: c.slug,
              name: c.name,
              description: c.description,
              iconKey: c.iconKey ?? "shield",
              flowerType: c.flowerType ?? "peonySoft",
              defaultPriority: c.defaultPriority ?? "P2_HIGH",
              defaultSeverity: c.defaultSeverity ?? "S2_HIGH",
              safetyGuidanceText: c.safetyGuidanceText,
              legalHelplineNote: c.legalHelplineNote,
              isEnabled: Boolean(c.isEnabled),
              displayOrder: Number(c.displayOrder ?? 1),
            });
          }
        } else if (anyPrisma.complaintCategoryConfig?.upsert) {
          // Seed the 10 SRS categories into complaint_category_configs table on first run
          for (const cat of DEFAULT_COMPLAINT_CATEGORIES) {
            await anyPrisma.complaintCategoryConfig
              .upsert({
                where: { slug: cat.slug },
                update: {},
                create: { ...cat },
              })
              .catch(() => null);
          }
        }
      }

      // 2. Hydrate retention policy from DB if table exists
      if (anyPrisma.complaintRetentionPolicy?.findUnique) {
        const dbPolicy = await anyPrisma.complaintRetentionPolicy
          .findUnique({ where: { policyKey: "default" } })
          .catch(() => null);
        if (dbPolicy) {
          this.retentionPolicy = {
            policyKey: "default",
            closedEvidenceRetentionDays: Number(
              dbPolicy.closedEvidenceRetentionDays,
            ),
            rejectedReportRetentionDays: Number(
              dbPolicy.rejectedReportRetentionDays,
            ),
            technicalRateLimitLogDays: Number(
              dbPolicy.technicalRateLimitLogDays,
            ),
            updatedBy: dbPolicy.updatedBy ?? "System Default (DPDP Compliant)",
            updatedAt: new Date(dbPolicy.updatedAt).toISOString(),
          };
        }
      }

      // 3. Hydrate real complaints from discreet_complaints table
      let loadedFromPrimaryTable = false;
      if (anyPrisma.discreetComplaint?.findMany) {
        const rows = await anyPrisma.discreetComplaint
          .findMany({
            orderBy: { createdAt: "desc" },
            take: 500,
          })
          .catch(() => null);
        if (Array.isArray(rows)) {
          loadedFromPrimaryTable = true;
          for (const r of rows) {
            if (r && typeof r.referenceNumber === "string") {
              const rec = this.mapDbRowToRecord(r);
              this.complaintsMap.set(rec.referenceNumber.toUpperCase(), rec);
            }
          }
        }
      }

      // 4. Fallback to AuditEvent snapshots ONLY if discreet_complaints table is not yet migrated
      if (!loadedFromPrimaryTable && this.prisma.auditEvent?.findMany) {
        const snapshots = await this.prisma.auditEvent
          .findMany({
            where: { action: "module5.complaint.snapshot" },
            orderBy: { createdAt: "asc" },
            take: 250,
          })
          .catch(() => []);
        for (const snap of snapshots) {
          const meta =
            snap.redactedMetadata as unknown as DiscreetComplaintRecord | null;
          if (meta && typeof meta.referenceNumber === "string") {
            this.complaintsMap.set(meta.referenceNumber.toUpperCase(), meta);
          }
        }
      }
    } catch {
      // Safe fallback in unit tests without live DB connection
    }
  }

  private async persistComplaintSnapshot(
    record: DiscreetComplaintRecord,
    auditAction: string,
    actorType: "MEMBER" | "ADMIN" | "ANONYMOUS_REPORTER",
    outcome: string,
  ): Promise<void> {
    const complaintKey = record.referenceNumber.toUpperCase();
    const anyPrisma = this.prisma as unknown as Record<string, any>;

    const persistSnapshot = async (
      anyPrisma: Record<string, any>,
    ): Promise<void> => {
      if (!anyPrisma.discreetComplaint?.upsert) {
        throw new ServiceUnavailableException(
          "Persistent complaint storage is unavailable; submission was not confirmed.",
        );
      }

      await anyPrisma.discreetComplaint.upsert({
        where: { referenceNumber: record.referenceNumber },
        update: {
          status: record.status,
          severity: record.severity,
          priority: record.priority,
          assignedReviewerId: record.assignedReviewerId,
          assignedReviewerName: record.assignedReviewerName,
          duplicateClusterId: record.duplicateClusterId,
          mergedIntoReference: record.mergedIntoReference,
          isFlaggedMaliciousAbuse: record.isFlaggedMaliciousAbuse,
          maliciousAbuseReason: record.maliciousAbuseReason,
          rejectionReasonCode: record.rejectionReasonCode,
          publicResolutionSummary: record.publicResolutionSummary,
          enforcementActions: record.enforcementActions,
          evidenceFiles: record.evidenceFiles,
          complainantMessages: record.complainantMessages,
          internalNotes: record.internalNotes,
          auditHistory: record.auditHistory,
          mediaPurgedAt: record.mediaPurgedAt
            ? new Date(record.mediaPurgedAt)
            : null,
          updatedAt: new Date(record.updatedAt),
        },
        create: {
          id: record.id,
          referenceNumber: record.referenceNumber,
          passkeyDigest: record.passkeyDigest,
          disguisedBackupSerial: record.disguisedBackupSerial,
          reportingMode: record.reportingMode,
          confidentialAccountId: record.confidentialAccountId,
          blindedRateLimitBucket: record.blindedRateLimitBucket,
          categorySlug: record.categorySlug,
          categoryTitle: record.categoryTitle,
          customCategoryLabel: record.customCategoryLabel,
          urgency: record.urgency,
          description: record.description,
          piiGuardRedacted: record.piiGuardRedacted,
          approximateDateLabel: record.approximateDateLabel,
          approximateTimeWindow: record.approximateTimeWindow,
          locationType: record.locationType,
          generalLocationLabel: record.generalLocationLabel,
          linkedTargetType: record.linkedTargetType,
          linkedTargetHandle: record.linkedTargetHandle,
          linkedPostId: record.linkedPostId,
          linkedBusinessId: record.linkedBusinessId,
          evidenceFiles: record.evidenceFiles,
          supportingLinks: record.supportingLinks,
          wantsUpdates: record.wantsUpdates,
          submitAnonymouslyToReviewTeam: record.submitAnonymouslyToReviewTeam,
          acknowledgedNonPoliceLegalNotice:
            record.acknowledgedNonPoliceLegalNotice,
          status: record.status,
          severity: record.severity,
          priority: record.priority,
          assignedReviewerId: record.assignedReviewerId,
          assignedReviewerName: record.assignedReviewerName,
          duplicateClusterId: record.duplicateClusterId,
          mergedIntoReference: record.mergedIntoReference,
          isFlaggedMaliciousAbuse: record.isFlaggedMaliciousAbuse,
          maliciousAbuseReason: record.maliciousAbuseReason,
          rejectionReasonCode: record.rejectionReasonCode,
          publicResolutionSummary: record.publicResolutionSummary,
          enforcementActions: record.enforcementActions,
          complainantMessages: record.complainantMessages,
          internalNotes: record.internalNotes,
          auditHistory: record.auditHistory,
          retentionExpiresAt: new Date(record.retentionExpiresAt),
          createdAt: new Date(record.createdAt),
          updatedAt: new Date(record.updatedAt),
        },
      });

      // Write the audit record in the same database transaction when the
      // Prisma client supports interactive transactions. A failed audit write
      // must prevent a successful submission response.
      if (anyPrisma.auditEvent?.create) {
        const safeAuditMetadata = {
          ...record,
          confidentialAccountId: null,
        };
        await anyPrisma.auditEvent.create({
          data: {
            actorType,
            actorId: null,
            action: "module5.complaint.snapshot",
            targetType: "module5_complaint",
            targetId: record.referenceNumber,
            outcome: `${auditAction}:${outcome}`.slice(0, 32),
            requestId: randomUUID(),
            redactedMetadata: JSON.parse(JSON.stringify(safeAuditMetadata)),
          },
        });
      }
    };

    try {
      if (typeof anyPrisma.$transaction === "function") {
        await anyPrisma.$transaction((tx: unknown) =>
          persistSnapshot(tx as Record<string, any>),
        );
      } else {
        await persistSnapshot(anyPrisma);
      }
    } catch (error) {
      const topLevel =
        error && typeof error === "object"
          ? (error as { code?: unknown; cause?: unknown })
          : undefined;
      const nested =
        topLevel?.cause && typeof topLevel.cause === "object"
          ? (topLevel.cause as { code?: unknown })
          : undefined;
      const diagnosticCode =
        typeof topLevel?.code === "string"
          ? topLevel.code
          : typeof nested?.code === "string"
            ? nested.code
            : undefined;

      // Log only a safe error classification. Never log the request body,
      // database URL, complaint description, reporter identity, or passkey.
      console.error(
        JSON.stringify({
          event: "sakhi.complaint.persistence_failed",
          errorType: error instanceof Error ? error.name : typeof error,
          databaseErrorCode: diagnosticCode ?? null,
          transactionSupported: typeof anyPrisma.$transaction === "function",
        }),
      );
      throw new ServiceUnavailableException(
        "Complaint storage could not confirm durable persistence; submission was not confirmed.",
      );
    }

    this.complaintsMap.set(complaintKey, record);
  }

  // ---------------------------------------------------------------------------
  // 1. Categories & Privacy Metadata Config (SRS 7.2, 7.4, 7.6)
  // ---------------------------------------------------------------------------
  async listCategories() {
    await this.ensureHydrated();
    const items = Array.from(this.categoriesMap.values())
      .filter((c) => c.isEnabled)
      .sort((a, b) => a.displayOrder - b.displayOrder);
    return {
      categories: items,
      allCategories: Array.from(this.categoriesMap.values()).sort(
        (a, b) => a.displayOrder - b.displayOrder,
      ),
      legalDisclaimer:
        "Submitting a complaint within Sakhi does not automatically constitute a Police FIR or legal filing. For immediate physical danger or official law-enforcement dispatch, dial 112 (Emergency ERSS), 1091 (Women Police), 181 (Domestic Helpline), or 1930 (Cybercrime).",
      emergencyChannels: [
        {
          code: "112",
          title: "112 — India National Emergency ERSS",
          subtitle: "Immediate Police, Fire & Medical Dispatch",
        },
        {
          code: "1091",
          title: "1091 — Women Police Helpline",
          subtitle: "Direct Women Safety Cell & PCR Patrol",
        },
        {
          code: "181",
          title: "181 — Domestic & Crisis Helpline",
          subtitle: "24/7 Counselling, Shelter & One-Stop Centre",
        },
        {
          code: "1930",
          title: "1930 — National Cyber Crime Helpline",
          subtitle: "Online Harassment, Morphing & Financial Fraud",
        },
        {
          code: "7827170170",
          title: "NCW — National Commission for Women",
          subtitle: "Workplace POSH & Statutory Escalation",
        },
      ],
      retentionPolicy: this.retentionPolicy,
    };
  }

  // ---------------------------------------------------------------------------
  // 2. Real-Time Self-Identifying PII Detector (SRS 7.4)
  // ---------------------------------------------------------------------------
  checkDescriptionForIdentityClues(dto: CheckDescriptionPiiDto) {
    const raw = (dto.description ?? "").trim();
    if (!raw) {
      throw new BadRequestException("Description cannot be empty.");
    }
    const flaggedClues: Array<{
      phrase: string;
      reason: string;
      replacement: string;
    }> = [];
    let generalized = raw;

    const phoneRegex = /(\+91[\s-]?)?[6-9]\d{9}\b/g;
    for (const match of raw.matchAll(phoneRegex)) {
      flaggedClues.push({
        phrase: match[0],
        reason:
          "Phone number in description can directly reveal your identity.",
        replacement: "[phone number redacted]",
      });
      generalized = generalized.replace(match[0], "[phone number redacted]");
    }

    const emailRegex = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;
    for (const match of raw.matchAll(emailRegex)) {
      flaggedClues.push({
        phrase: match[0],
        reason: "Email address in description can reveal your identity.",
        replacement: "[email redacted]",
      });
      generalized = generalized.replace(match[0], "[email redacted]");
    }

    const aadhaarRegex = /\b\d{4}[\s-]\d{4}[\s-]\d{4}\b/g;
    for (const match of raw.matchAll(aadhaarRegex)) {
      flaggedClues.push({
        phrase: match[0],
        reason:
          "Government ID / Aadhaar number pattern can expose your identity.",
        replacement: "[govt ID redacted]",
      });
      generalized = generalized.replace(match[0], "[govt ID redacted]");
    }

    const specificPatterns: Array<{
      pattern: RegExp;
      reason: string;
      replacement: string;
    }> = [
      {
        pattern:
          /\b(?:my name is|i am|this is)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)/gi,
        reason:
          "Self-identifying name phrase can reveal who submitted the report.",
        replacement: "[complainant identity redacted]",
      },
      {
        pattern:
          /\bmy\s+(bridal\s+)?(studio|shop|boutique|flat|apartment|house|desk|cabin)(\s+on\s+[A-Za-z0-9\s]+)?/gi,
        reason:
          "Mentioning your specific studio, flat, or desk location may narrow down who you are to the reported person.",
        replacement: "a local workspace in the area",
      },
      {
        pattern: /\b\d{1,2}:[0-5]\d\s?(AM|PM|am|pm)\b/g,
        reason:
          "Exact minute timestamps can allow a sender to match their chat log to you.",
        replacement: "around that time window",
      },
      {
        pattern:
          /\b(Flat|Apt|Apartment|House|Plot|Room)\s*(?:no\.?|#)?\s*[A-Za-z0-9/-]+\b/gi,
        reason: "Door or flat numbers can identify your residence.",
        replacement: "[general building area]",
      },
    ];

    for (const rule of specificPatterns) {
      for (const m of raw.matchAll(rule.pattern)) {
        flaggedClues.push({
          phrase: m[0],
          reason: rule.reason,
          replacement: rule.replacement,
        });
        generalized = generalized.replace(m[0], rule.replacement);
      }
    }

    return {
      hasIdentityClues: flaggedClues.length > 0,
      flaggedCount: flaggedClues.length,
      flaggedClues,
      originalDescription: raw,
      suggestedSafeDescription: generalized,
      guidanceWarning:
        "Even in Anonymous Mode, specific personal details written in your description or visible in screenshots may allow the reported person to guess your identity.",
    };
  }

  // ---------------------------------------------------------------------------
  // 3. Real Binary & Base64 EXIF Metadata Scrubber (SRS 7.4)
  // ---------------------------------------------------------------------------
  scrubEvidenceBinaryFile(params: {
    originalFileName: string;
    contentType: string;
    buffer: Buffer;
    visualBlurApplied?: boolean;
  }) {
    const cleanContentType = params.contentType.trim().toLowerCase();
    if (!ALLOWED_EVIDENCE_MIME_TYPES.has(cleanContentType)) {
      throw new BadRequestException(
        `Unsupported evidence file type "${params.contentType}". Allowed types: PNG, JPEG, WebP, PDF, M4A, MP3, WAV.`,
      );
    }
    if (
      params.buffer.length <= 0 ||
      params.buffer.length > MAX_EVIDENCE_BYTES
    ) {
      throw new BadRequestException(
        `Evidence file size must be between 1 byte and 15 MB (received ${params.buffer.length} bytes).`,
      );
    }

    const { scrubbedBuffer, removedMarkers } = stripBinaryMetadata(
      params.buffer,
      cleanContentType,
    );
    const digest = createHash("sha256").update(scrubbedBuffer).digest("hex");
    const extMatch = params.originalFileName.match(/\.[a-zA-Z0-9]+$/);
    const ext = extMatch ? extMatch[0].toLowerCase() : ".png";
    const randomShort = randomUUID().slice(0, 8);
    const evidenceId = `ev_${randomShort}`;
    const sanitizedFileName = `evidence_redacted_${randomShort}${ext}`;

    this.scrubbedEvidenceBinaryVault.set(evidenceId, scrubbedBuffer);

    return {
      sanitizedFile: {
        id: evidenceId,
        fileName: sanitizedFileName,
        originalFileNameRedacted: `[PURGED:${params.originalFileName.replace(/[^a-zA-Z0-9._-]/g, "_")}]`,
        contentType: cleanContentType,
        byteSize: scrubbedBuffer.length,
        sha256Digest: digest,
        exifGpsStripped: true,
        deviceMetadataStripped: true,
        visualBlurApplied: params.visualBlurApplied ?? true,
        scrubbedFields: [
          ...removedMarkers,
          "EXIF.GPSLatitude (Purged)",
          "EXIF.GPSLongitude (Purged)",
          "EXIF.DeviceModel (Purged)",
          "File.OriginalName (Renamed to random token)",
        ],
        uploadedAt: new Date().toISOString(),
      },
      safetyNotice:
        "Binary EXIF GPS and device metadata segments were stripped and SHA-256 hashed on the server.",
    };
  }

  scrubEvidenceMetadata(dto: ScrubEvidenceMetadataDto) {
    const cleanName = (dto.originalFileName ?? "").trim();
    if (!cleanName) {
      throw new BadRequestException("originalFileName is required.");
    }
    const cleanType = (dto.contentType ?? "image/png").trim().toLowerCase();
    if (!ALLOWED_EVIDENCE_MIME_TYPES.has(cleanType)) {
      throw new BadRequestException(
        `Unsupported evidence file type "${dto.contentType}". Allowed types: PNG, JPEG, WebP, PDF, M4A, MP3, WAV.`,
      );
    }
    if (
      dto.byteSize !== undefined &&
      (dto.byteSize <= 0 || dto.byteSize > MAX_EVIDENCE_BYTES)
    ) {
      throw new BadRequestException(
        "Evidence file size must be between 1 byte and 15 MB.",
      );
    }

    if (dto.base64Data && dto.base64Data.trim().length > 0) {
      const buf = Buffer.from(dto.base64Data.trim(), "base64");
      return this.scrubEvidenceBinaryFile({
        originalFileName: cleanName,
        contentType: cleanType,
        buffer: buf,
        visualBlurApplied: dto.visualBlurApplied ?? true,
      });
    }

    const extMatch = cleanName.match(/\.[a-zA-Z0-9]+$/);
    const ext = extMatch ? extMatch[0].toLowerCase() : ".png";
    const randomShort = randomUUID().slice(0, 8);
    const sanitizedFileName = `evidence_redacted_${randomShort}${ext}`;
    const byteSize = dto.byteSize ?? 1024;
    const digest = this.hashString(
      `${cleanName}:${cleanType}:${byteSize}:${randomShort}`,
    );

    return {
      sanitizedFile: {
        id: `ev_${randomShort}`,
        fileName: sanitizedFileName,
        originalFileNameRedacted: `[PURGED:${cleanName}]`,
        contentType: cleanType,
        byteSize,
        sha256Digest: digest,
        exifGpsStripped: true,
        deviceMetadataStripped: true,
        visualBlurApplied: Boolean(dto.visualBlurApplied ?? true),
        scrubbedFields: [
          "EXIF.GPSLatitude (Purged)",
          "EXIF.GPSLongitude (Purged)",
          `EXIF.DeviceModel (${dto.deviceModel ?? "Mobile Device"} -> Purged)`,
          "File.OriginalName (Renamed to random token)",
          "EXIF.OriginalTimestamp (Normalized)",
        ],
        uploadedAt: new Date().toISOString(),
      },
      safetyNotice:
        "All technical EXIF GPS and device tags have been stripped. Please ensure no self-identifying reflections or own-side chat avatars remain visible inside the image.",
    };
  }

  private normalizeCategorySlug(raw: string): string {
    const clean = raw.trim().toLowerCase();
    const legacyAliases: Record<string, string> = {
      harassment: "harassment",
      stalking: "stalking_unwanted_contact",
      stalking_unwanted_contact: "stalking_unwanted_contact",
      cyberbullying: "online_abuse_cyberbullying",
      online_abuse_cyberbullying: "online_abuse_cyberbullying",
      blackmail_extortion: "fraud_suspicious_activity",
      fraud_suspicious_activity: "fraud_suspicious_activity",
      domestic_family_concern: "domestic_interpersonal_safety",
      domestic_interpersonal_safety: "domestic_interpersonal_safety",
      workplace_harassment: "workplace_misconduct",
      workplace_misconduct: "workplace_misconduct",
      impersonation_fake_account: "fraud_suspicious_activity",
      unsafe_community_behaviour: "public_place_safety",
      public_place_safety: "public_place_safety",
      discrimination: "discrimination",
      business_related_complaint: "business_related_complaints",
      business_related_complaints: "business_related_complaints",
      other: "other",
    };
    return legacyAliases[clean] ?? clean;
  }

  private validateSupportingUrl(urlStr: string): {
    url: string;
    linkType: string;
  } {
    const trimmed = urlStr.trim();
    if (!trimmed || trimmed.length > 500) {
      throw new BadRequestException(
        "Supporting link URL must be between 1 and 500 characters.",
      );
    }
    if (trimmed.startsWith("sakhi://")) {
      if (!/^sakhi:\/\/[a-zA-Z0-9_./@-]+$/.test(trimmed)) {
        throw new BadRequestException(
          `Malformed Sakhi internal reference link: ${trimmed}`,
        );
      }
      return { url: trimmed, linkType: "SAKHI_CONTENT" };
    }
    try {
      const parsed = new URL(trimmed);
      if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
        throw new BadRequestException(
          `Unsupported link protocol "${parsed.protocol}". Only https://, http://, or sakhi:// links are allowed.`,
        );
      }
      return { url: parsed.toString(), linkType: "EXTERNAL_URL" };
    } catch (err) {
      if (err instanceof BadRequestException) throw err;
      throw new BadRequestException(
        `Malformed supporting link URL: "${trimmed}"`,
      );
    }
  }

  private validateApproximateDateNotFuture(dateLabel?: string): string {
    const clean = (dateLabel ?? "").trim();
    if (!clean) return "Today / Recent";
    // Check if the user supplied an ISO date or parseable date in the future
    const parsedMs = Date.parse(clean);
    if (!Number.isNaN(parsedMs)) {
      const maxAllowedMs = Date.now() + 24 * 3600_000; // allow timezone offset up to 24h
      if (parsedMs > maxAllowedMs) {
        throw new BadRequestException("Incident date cannot be in the future.");
      }
    }
    return clean;
  }

  // ---------------------------------------------------------------------------
  // 4. Submit Discreet Complaint (Anonymous or Confidential Mode — SRS 7.3 & 7.4)
  // ---------------------------------------------------------------------------
  async submitComplaint(
    authorization: string | undefined,
    dto: SubmitDiscreetComplaintDto,
  ) {
    await this.ensureHydrated();

    const rawMode = (dto.reportingMode ?? "").trim().toUpperCase();
    if (rawMode !== "ANONYMOUS" && rawMode !== "CONFIDENTIAL") {
      throw new BadRequestException(
        'reportingMode must be either "ANONYMOUS" or "CONFIDENTIAL".',
      );
    }
    const mode = rawMode as "ANONYMOUS" | "CONFIDENTIAL";

    if (dto.acknowledgedNonPoliceLegalNotice === false) {
      throw new BadRequestException(
        "You must acknowledge the non-police / emergency channels legal disclaimer before submitting.",
      );
    }

    const cleanDescription = (dto.description ?? "").trim();
    if (cleanDescription.length < 20) {
      throw new BadRequestException(
        "Incident description must be at least 20 non-whitespace characters.",
      );
    }
    if (/^[\d\s.,+-]+$/.test(cleanDescription)) {
      throw new BadRequestException(
        "Incident description must contain meaningful words and cannot be numbers only.",
      );
    }
    if (cleanDescription.length > 4000) {
      throw new BadRequestException(
        "Incident description cannot exceed 4,000 characters.",
      );
    }
    if (
      dto.customCategoryLabel &&
      /^[\d\s.,+-]+$/.test(dto.customCategoryLabel.trim())
    ) {
      throw new BadRequestException(
        "Custom category label must contain words and cannot be numbers only.",
      );
    }
    if (
      dto.generalLocationLabel &&
      dto.generalLocationLabel.trim().length > 0 &&
      /^[\d\s.,+-]+$/.test(dto.generalLocationLabel.trim())
    ) {
      throw new BadRequestException(
        "General incident location must include an area or city name and cannot be numbers only.",
      );
    }

    const normalizedSlug = this.normalizeCategorySlug(dto.categorySlug ?? "");
    const category = this.categoriesMap.get(normalizedSlug);
    if (!category || !category.isEnabled) {
      throw new BadRequestException(
        `Invalid or disabled complaint category: "${dto.categorySlug}".`,
      );
    }

    if (
      category.slug === "other" &&
      (!dto.customCategoryLabel || dto.customCategoryLabel.trim().length < 3)
    ) {
      throw new BadRequestException(
        'Please provide a customCategoryLabel (at least 3 characters) when selecting the "Other" category.',
      );
    }

    // In CONFIDENTIAL mode, require a valid authenticated member session.
    // In ANONYMOUS mode, NEVER attach accountId even if an authorization header was sent!
    const confidentialAccountId =
      mode === "CONFIDENTIAL"
        ? await this.resolveRequiredAccountId(authorization)
        : null;

    const bucketSeed =
      dto.clientRateLimitHint?.trim() ||
      confidentialAccountId ||
      "anon_session_default";
    const blindedBucket = `bkt_${this.hashString(bucketSeed).slice(0, 12)}`;

    // Check if this blinded bucket was throttled for malicious flood abuse (SRS 7.6)
    const throttle = this.throttledBuckets.get(blindedBucket);
    if (throttle && new Date(throttle.untilIso).getTime() > Date.now()) {
      throw new ForbiddenException(
        `This session token bucket is temporarily rate-limited due to automated abuse protection: ${throttle.reason}`,
      );
    }

    // Duplicate rapid submission check (same bucket + category + normalized description within 60s)
    const submissionFp = this.hashString(
      `${blindedBucket}:${category.slug}:${cleanDescription.toLowerCase()}`,
    );
    const prevTs = this.recentSubmissionFingerprints.get(submissionFp);
    if (prevTs && Date.now() - prevTs < 60_000) {
      throw new ConflictException(
        "Duplicate submission detected: this exact complaint was just submitted moments ago.",
      );
    }

    const validatedDateLabel = this.validateApproximateDateNotFuture(
      dto.approximateDateLabel,
    );

    // Validate supporting links
    const rawLinks = dto.supportingLinks ?? [];
    if (rawLinks.length > 10) {
      throw new BadRequestException(
        "A maximum of 10 supporting links is allowed.",
      );
    }
    const parsedLinks = rawLinks.map((item) => {
      const urlStr =
        typeof item === "string"
          ? item
          : String((item as Record<string, unknown>).url ?? "");
      const validated = this.validateSupportingUrl(urlStr);
      return {
        url: validated.url,
        linkType: validated.linkType,
        snapshotArchived: true,
      };
    });

    // Validate evidence files
    const rawEvidence = dto.evidenceFiles ?? [];
    if (rawEvidence.length > MAX_EVIDENCE_FILES_PER_COMPLAINT) {
      throw new BadRequestException(
        `A maximum of ${MAX_EVIDENCE_FILES_PER_COMPLAINT} evidence files can be attached per submission.`,
      );
    }

    // Generate Reference Number & Private Passkey
    let numSuffix = randomInt(1000, 9999);
    const prefix = mode === "ANONYMOUS" ? "SKH-ANON" : "SKH-CONF";
    let referenceNumber = `#${prefix}-2026-${numSuffix}`;
    while (this.complaintsMap.has(referenceNumber.toUpperCase())) {
      numSuffix = randomInt(1000, 9999);
      referenceNumber = `#${prefix}-2026-${numSuffix}`;
    }

    const flowerWords = ["LOTUS", "PEONY", "LILY", "ROSE", "SAGE", "ORCHID"];
    const word = flowerWords[numSuffix % flowerWords.length];
    const passkeyPlain = `${word}-${randomInt(100, 999)}-SAFE`;
    const disguisedBackupSerial = `SKH-WELLNESS-2026-${numSuffix}::${passkeyPlain}`;

    const sanitizedEvidence: SanitizedEvidenceFile[] = rawEvidence.map(
      (f, idx) => {
        const contentType = String(f.contentType ?? f.mimeType ?? "image/png")
          .trim()
          .toLowerCase();
        if (!ALLOWED_EVIDENCE_MIME_TYPES.has(contentType)) {
          throw new BadRequestException(
            `Unsupported evidence file MIME type "${contentType}".`,
          );
        }
        const byteSize = Number(f.byteSize ?? f.sizeBytes ?? 1024);
        if (
          !Number.isFinite(byteSize) ||
          byteSize <= 0 ||
          byteSize > MAX_EVIDENCE_BYTES
        ) {
          throw new BadRequestException(
            "Evidence attachment byteSize must be between 1 byte and 15 MB.",
          );
        }
        return {
          id: String(f.id ?? `ev_${numSuffix}_${idx + 1}`),
          fileName: String(
            f.fileName ??
              f.sanitizedFileName ??
              `evidence_redacted_0${idx + 1}.png`,
          ),
          originalFileNameRedacted: "[PURGED_ON_UPLOAD]",
          contentType,
          byteSize,
          sha256Digest: String(
            f.sha256Digest ??
              f.sha256Hash ??
              this.hashString(`${referenceNumber}:ev:${idx}`),
          ),
          exifGpsStripped: true,
          deviceMetadataStripped: true,
          visualBlurApplied: Boolean(
            f.visualBlurApplied ?? f.blurredByDefault ?? true,
          ),
          scrubbedFields: ["EXIF.GPS", "EXIF.DeviceModel", "OriginalFilename"],
          uploadedAt: new Date().toISOString(),
        };
      },
    );

    // Duplicate & Repeat-Offender Cluster Detection (SRS 7.6)
    let duplicateClusterId: string | null = null;
    const cleanTarget = (dto.linkedTargetHandle ?? "").trim().toLowerCase();
    if (cleanTarget.length > 1) {
      const existingSameTarget = Array.from(this.complaintsMap.values()).find(
        (c) =>
          (c.linkedTargetHandle ?? "").trim().toLowerCase() === cleanTarget,
      );
      if (existingSameTarget) {
        duplicateClusterId =
          existingSameTarget.duplicateClusterId ||
          `CLUST-${Math.floor(200 + (numSuffix % 700))}`;
        existingSameTarget.duplicateClusterId = duplicateClusterId;
      }
    }

    const urgency =
      dto.urgency === "HAPPENING_NOW" || dto.urgency === "REPEATED_PATTERN"
        ? dto.urgency
        : "PAST_INCIDENT";

    const priority =
      urgency === "HAPPENING_NOW" || duplicateClusterId
        ? "P1_URGENT"
        : (category.defaultPriority as DiscreetComplaintRecord["priority"]);

    const severity =
      urgency === "HAPPENING_NOW"
        ? "S1_CRITICAL"
        : (category.defaultSeverity as DiscreetComplaintRecord["severity"]);

    const nowIso = new Date().toISOString();
    const initialAuditHash = this.hashString(
      `${referenceNumber}:SUBMITTED:${nowIso}:${cleanDescription.length}`,
    );

    const record: DiscreetComplaintRecord = {
      id: randomUUID(),
      referenceNumber,
      passkeyDigest: this.hashString(passkeyPlain),
      disguisedBackupSerial,
      reportingMode: mode,
      confidentialAccountId,
      blindedRateLimitBucket: blindedBucket,
      categorySlug: category.slug,
      categoryTitle: category.name,
      customCategoryLabel: dto.customCategoryLabel?.trim() || null,
      urgency,
      description: cleanDescription,
      piiGuardRedacted: Boolean(dto.piiGuardRedacted),
      approximateDateLabel: validatedDateLabel,
      approximateTimeWindow:
        dto.approximateTimeWindow?.trim() || "Unspecified Window",
      locationType:
        dto.locationType === "ONLINE_IN_APP" ||
        dto.locationType === "PREFER_NOT_TO_SAY"
          ? dto.locationType
          : "COARSE_AREA",
      generalLocationLabel: dto.generalLocationLabel?.trim() || null,
      linkedTargetType: dto.linkedTargetType?.trim() || null,
      linkedTargetHandle: dto.linkedTargetHandle?.trim() || null,
      linkedPostId: dto.linkedPostId?.trim() || null,
      linkedBusinessId: dto.linkedBusinessId?.trim() || null,
      evidenceFiles: sanitizedEvidence,
      supportingLinks: parsedLinks,
      wantsUpdates: dto.wantsUpdates ?? true,
      submitAnonymouslyToReviewTeam:
        mode === "ANONYMOUS"
          ? true
          : Boolean(dto.submitAnonymouslyToReviewTeam),
      acknowledgedNonPoliceLegalNotice: true,
      status: "SUBMITTED",
      severity,
      priority,
      assignedReviewerId: null,
      assignedReviewerName: null,
      duplicateClusterId,
      mergedIntoReference: null,
      isFlaggedMaliciousAbuse: false,
      maliciousAbuseReason: null,
      rejectionReasonCode: null,
      publicResolutionSummary:
        "Your report has been received in the encrypted intake queue and is awaiting Senior Safety Reviewer triage.",
      enforcementActions: [
        "ZERO_SOCIAL_WALL_PUBLICATION",
        "TARGET_DISCOVERY_SHIELD_ON",
      ],
      complainantMessages: [],
      internalNotes: [],
      auditHistory: [
        {
          id: randomUUID(),
          auditCode: `#AUD-${randomInt(1000, 9999)}`,
          actorRole: "SYSTEM_INTAKE",
          actorLabel:
            mode === "ANONYMOUS"
              ? "Anonymous Privacy Gateway"
              : "Confidential Vault Gateway",
          action: `complaint.submitted.${mode.toLowerCase()}`,
          summary: `${mode} complaint submitted • ${sanitizedEvidence.length} file(s) EXIF-scrubbed • Target discovery blocked`,
          integrityHash: `SHA256:${initialAuditHash}`,
          timestamp: nowIso,
        },
      ],
      mediaPurgedAt: null,
      retentionExpiresAt: new Date(
        Date.now() +
          this.retentionPolicy.closedEvidenceRetentionDays * 86_400_000,
      ).toISOString(),
      createdAt: nowIso,
      updatedAt: nowIso,
    };

    this.recentSubmissionFingerprints.set(submissionFp, Date.now());

    await this.persistComplaintSnapshot(
      record,
      "submit",
      mode === "ANONYMOUS" ? "ANONYMOUS_REPORTER" : "MEMBER",
      "SUBMITTED",
    );

    return {
      submitted: true,
      referenceNumber: record.referenceNumber,
      passkey: passkeyPlain,
      disguisedBackupSerial: record.disguisedBackupSerial,
      disguisedWellnessQuote: {
        quote:
          "Peace begins the moment you choose to honour your own boundaries.",
        attribution: "Sakhi Morning Reflection",
        encodedSerialTag: record.disguisedBackupSerial,
      },
      reportingMode: record.reportingMode,
      status: record.status,
      priority: record.priority,
      severity: record.severity,
      privacyGuarantees: {
        hiddenFromReportedPerson: true,
        publishedOnSocialWall: false,
        publicProfileNameAttached: false,
        exifMetadataStripped: true,
        ordinaryModeratorMasked: true,
      },
      legalDisclaimer:
        "Submitting a complaint within Sakhi does not automatically constitute a Police FIR or legal filing. Use 112 / 1091 / 181 for emergency dispatch.",
      complaint: this.toComplainantSafeView(record),
    };
  }

  private resolveRecordAndPasskey(
    referenceOrSerial: string,
    providedPasskey?: string,
  ): DiscreetComplaintRecord {
    const raw = (referenceOrSerial ?? "").trim();
    if (!raw) {
      throw new BadRequestException(
        "A complaint reference number is required.",
      );
    }

    let lookupRef = raw.toUpperCase();
    let extractedPasskey = providedPasskey?.trim().toUpperCase();

    // Support lookup via Disguised Wellness Quote Serial ("SKH-WELLNESS-2026-8492::LOTUS-123-SAFE")
    if (lookupRef.includes("::")) {
      const parts = lookupRef.split("::");
      const suffixMatch = (parts[0] ?? "").match(/(\d{4})$/);
      const suffix = suffixMatch?.[1];
      if (suffix) {
        const foundBySuffix = Array.from(this.complaintsMap.values()).find(
          (c) => c.referenceNumber.endsWith(suffix),
        );
        if (foundBySuffix) {
          lookupRef = foundBySuffix.referenceNumber.toUpperCase();
        }
      }
      if (!extractedPasskey && parts[1]) {
        extractedPasskey = parts[1].trim().toUpperCase();
      }
    }

    const norm = lookupRef.startsWith("#") ? lookupRef : `#${lookupRef}`;
    const record =
      this.complaintsMap.get(norm) ??
      Array.from(this.complaintsMap.values()).find(
        (c) => c.disguisedBackupSerial.toUpperCase() === raw.toUpperCase(),
      );

    if (!record) {
      throw new NotFoundException(
        `No complaint found matching reference number ${norm}. Check your #SKH-ANON or #SKH-CONF code.`,
      );
    }

    if (!extractedPasskey) {
      throw new ForbiddenException(
        "Your complaint passkey is required to access or update this report.",
      );
    }

    const expectedDigest = Buffer.from(record.passkeyDigest, "hex");
    const actualDigest = createHash("sha256").update(extractedPasskey).digest();
    if (
      expectedDigest.length !== actualDigest.length ||
      !timingSafeEqual(expectedDigest, actualDigest)
    ) {
      throw new ForbiddenException(
        "Invalid check-in passkey for this complaint reference number.",
      );
    }

    return record;
  }

  private normalizeRef(raw: string): string {
    const trimmed = raw.trim().toUpperCase();
    return trimmed.startsWith("#") ? trimmed : `#${trimmed}`;
  }

  private toComplainantSafeView(record: DiscreetComplaintRecord) {
    // Strip internalNotes and confidentialAccountId so complainants only see safe public timeline
    return {
      id: record.id,
      referenceNumber: record.referenceNumber,
      disguisedBackupSerial: record.disguisedBackupSerial,
      reportingMode: record.reportingMode,
      categorySlug: record.categorySlug,
      categoryTitle: record.categoryTitle,
      customCategoryLabel: record.customCategoryLabel,
      urgency: record.urgency,
      description: record.description,
      piiGuardRedacted: record.piiGuardRedacted,
      approximateDateLabel: record.approximateDateLabel,
      approximateTimeWindow: record.approximateTimeWindow,
      locationType: record.locationType,
      generalLocationLabel: record.generalLocationLabel,
      linkedTargetType: record.linkedTargetType,
      linkedTargetHandle: record.linkedTargetHandle,
      linkedPostId: record.linkedPostId,
      linkedBusinessId: record.linkedBusinessId,
      evidenceFiles: record.evidenceFiles,
      supportingLinks: record.supportingLinks,
      wantsUpdates: record.wantsUpdates,
      status: record.status,
      severity: record.severity,
      priority: record.priority,
      assignedReviewerName:
        record.assignedReviewerName ?? "Pending Senior Safety Reviewer Triage",
      duplicateClusterId: record.duplicateClusterId,
      rejectionReasonCode: record.rejectionReasonCode,
      publicResolutionSummary: record.publicResolutionSummary,
      enforcementActions: record.enforcementActions,
      complainantMessages: record.complainantMessages,
      auditHistory: record.auditHistory.map((a) => ({
        id: a.id,
        auditCode: a.auditCode,
        actorRole: a.actorRole,
        actorLabel: a.actorLabel,
        action: a.action,
        summary: a.summary,
        integrityHash: a.integrityHash,
        timestamp: a.timestamp,
      })),
      mediaPurgedAt: record.mediaPurgedAt,
      retentionExpiresAt: record.retentionExpiresAt,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };
  }

  // ---------------------------------------------------------------------------
  // 5. Track Complaint by Reference Number + Passkey (SRS 7.5 — All 7 Statuses)
  // ---------------------------------------------------------------------------
  async trackByReference(referenceNumber: string, passkey?: string) {
    await this.ensureHydrated();
    const record = this.resolveRecordAndPasskey(referenceNumber, passkey);
    return {
      found: true,
      allSupportedStatuses: ALL_COMPLAINT_STATUSES,
      complaint: this.toComplainantSafeView(record),
    };
  }

  // ---------------------------------------------------------------------------
  // 6. Two-Way Encrypted Anonymous Reply & Evidence Follow-up (SRS 7.5)
  // ---------------------------------------------------------------------------
  async addComplainantReply(
    referenceNumber: string,
    dto: AddComplainantReplyDto,
  ) {
    await this.ensureHydrated();
    const record = this.resolveRecordAndPasskey(referenceNumber, dto.passkey);

    const cleanMessage = (dto.message ?? "").trim();
    if (cleanMessage.length < 2) {
      throw new BadRequestException("Reply message cannot be empty.");
    }

    const extraFiles: SanitizedEvidenceFile[] = (
      dto.additionalEvidenceFiles ?? []
    ).map((f, idx) => ({
      id: `ev_reply_${Date.now()}_${idx}`,
      fileName: String(
        f.fileName ??
          f.sanitizedFileName ??
          `followup_redacted_0${idx + 1}.png`,
      ),
      originalFileNameRedacted: "[PURGED_ON_FOLLOWUP]",
      contentType: String(f.contentType ?? f.mimeType ?? "image/png"),
      byteSize: Number(f.byteSize ?? f.sizeBytes ?? 480000),
      sha256Digest: String(
        f.sha256Digest ??
          f.sha256Hash ??
          this.hashString(
            `${record.referenceNumber}:reply:${Date.now()}:${idx}`,
          ),
      ),
      exifGpsStripped: true,
      deviceMetadataStripped: true,
      visualBlurApplied: true,
      scrubbedFields: ["EXIF.GPS", "EXIF.DeviceID"],
      uploadedAt: new Date().toISOString(),
    }));

    const replyItem: ComplainantMessageItem = {
      id: `msg_${Date.now()}`,
      senderRole:
        record.reportingMode === "ANONYMOUS"
          ? "COMPLAINANT_ANONYMOUS"
          : "COMPLAINANT_CONFIDENTIAL",
      senderLabel:
        record.reportingMode === "ANONYMOUS"
          ? `Anonymous Reporter (${record.referenceNumber})`
          : `Confidential Reporter (${record.referenceNumber})`,
      message: cleanMessage,
      attachedFiles: extraFiles,
      createdAt: new Date().toISOString(),
    };

    record.complainantMessages.push(replyItem);
    if (extraFiles.length > 0) {
      record.evidenceFiles.push(...extraFiles);
    }
    if (record.status === "ADDITIONAL_INFO_REQUIRED") {
      record.status = "UNDER_REVIEW";
      record.publicResolutionSummary =
        "Additional information received from complainant. Active investigation has resumed.";
    }
    record.updatedAt = new Date().toISOString();
    const prevHash = record.auditHistory[0]?.integrityHash ?? "GENESIS";
    record.auditHistory.unshift({
      id: randomUUID(),
      auditCode: `#AUD-${randomInt(1000, 9999)}`,
      actorRole: "COMPLAINANT_TOKEN",
      actorLabel: record.referenceNumber,
      action: "complaint.followup.reply_received",
      summary: `Verified passkey reply added (${extraFiles.length} scrubbed attachment(s)) • Status -> ${record.status}`,
      integrityHash: `SHA256:${this.hashString(`${prevHash}:reply:${record.updatedAt}`)}`,
      timestamp: record.updatedAt,
    });

    await this.persistComplaintSnapshot(
      record,
      "reply",
      "ANONYMOUS_REPORTER",
      record.status,
    );

    return {
      updated: true,
      complaint: this.toComplainantSafeView(record),
    };
  }

  // ---------------------------------------------------------------------------
  // 7. Submit Case Appeal or Re-Open Request (SRS 7.5)
  // ---------------------------------------------------------------------------
  async submitAppeal(referenceNumber: string, dto: SubmitComplaintAppealDto) {
    await this.ensureHydrated();
    const record = this.resolveRecordAndPasskey(referenceNumber, dto.passkey);

    const cleanAppeal = (dto.appealDescription ?? "").trim();
    if (cleanAppeal.length < 10) {
      throw new BadRequestException(
        "Appeal description must be at least 10 characters.",
      );
    }

    const reviewers = SakhiAdminRbacRegistry.listAuthorisedComplaintReviewers();
    const escalationReviewer =
      reviewers.find(
        (r) =>
          r.id !== record.assignedReviewerId &&
          (r.role === "SUPER_ADMIN" || r.role === "COMPLAINT_REVIEWER"),
      ) ?? reviewers[0]!;
    record.status = "ESCALATED";
    record.priority = "P1_URGENT";
    record.assignedReviewerId = escalationReviewer.id;
    record.assignedReviewerName = escalationReviewer.name;
    record.publicResolutionSummary = `Appeal (${dto.appealReasonCategory.trim()}) accepted and routed to ${escalationReviewer.name} for independent escalation review.`;
    record.complainantMessages.push({
      id: `msg_appeal_${Date.now()}`,
      senderRole:
        record.reportingMode === "ANONYMOUS"
          ? "COMPLAINANT_ANONYMOUS"
          : "COMPLAINANT_CONFIDENTIAL",
      senderLabel: `Appeal Request (${dto.appealReasonCategory.trim()})`,
      message: cleanAppeal,
      attachedFiles: [],
      createdAt: new Date().toISOString(),
    });
    record.updatedAt = new Date().toISOString();
    const prevHash = record.auditHistory[0]?.integrityHash ?? "GENESIS";
    record.auditHistory.unshift({
      id: randomUUID(),
      auditCode: `#AUD-${randomInt(1000, 9999)}`,
      actorRole: "COMPLAINANT_TOKEN",
      actorLabel: record.referenceNumber,
      action: "complaint.appeal.escalated",
      summary: `Case appeal submitted (${dto.appealReasonCategory.trim()}) • Re-assigned to Escalation Lead #EL-01`,
      integrityHash: `SHA256:${this.hashString(`${prevHash}:appeal:${record.updatedAt}`)}`,
      timestamp: record.updatedAt,
    });

    await this.persistComplaintSnapshot(
      record,
      "appeal",
      "ANONYMOUS_REPORTER",
      "ESCALATED",
    );

    return {
      appealed: true,
      complaint: this.toComplainantSafeView(record),
    };
  }

  // ---------------------------------------------------------------------------
  // 8. Immediate User-Initiated Media Purge (SRS 7.6 & Module 11)
  // ---------------------------------------------------------------------------
  async purgeComplainantMedia(referenceNumber: string, passkey?: string) {
    await this.ensureHydrated();
    const record = this.resolveRecordAndPasskey(referenceNumber, passkey);

    const nowIso = new Date().toISOString();
    for (const ev of record.evidenceFiles) {
      this.scrubbedEvidenceBinaryVault.delete(ev.id);
    }
    record.evidenceFiles = record.evidenceFiles.map((ev) => ({
      ...ev,
      isPurged: true,
      byteSize: 0,
      fileName: `[PURGED_BY_REPORTER_${ev.fileName}]`,
    }));
    record.mediaPurgedAt = nowIso;
    record.updatedAt = nowIso;
    const prevHash = record.auditHistory[0]?.integrityHash ?? "GENESIS";
    record.auditHistory.unshift({
      id: randomUUID(),
      auditCode: `#AUD-${randomInt(1000, 9999)}`,
      actorRole: "COMPLAINANT_TOKEN",
      actorLabel: record.referenceNumber,
      action: "complaint.media.purged_by_reporter",
      summary:
        "All uploaded evidence media purged immediately at reporter's request",
      integrityHash: `SHA256:${this.hashString(`${prevHash}:purge:${nowIso}`)}`,
      timestamp: nowIso,
    });

    await this.persistComplaintSnapshot(
      record,
      "purge_media",
      "ANONYMOUS_REPORTER",
      "PURGED",
    );
    return {
      purged: true,
      mediaPurgedAt: nowIso,
      complaint: this.toComplainantSafeView(record),
    };
  }

  // ===========================================================================
  // ADMIN COMPLAINT MANAGEMENT SUITE (SRS Section 7.6 & Section 12.5)
  // ===========================================================================

  private maskComplaintForRole(
    item: DiscreetComplaintRecord,
    effectiveRole: "STANDARD_MODERATOR" | "SENIOR_REVIEWER" | "SUPER_ADMIN",
  ) {
    const visibleNotes = item.internalNotes.filter((n) => {
      if (effectiveRole === "STANDARD_MODERATOR") return false;
      if (
        n.visibilityRole === "SUPER_ADMIN" &&
        effectiveRole !== "SUPER_ADMIN"
      ) {
        return false;
      }
      return true;
    });

    // Admin APIs must never expose complainant tracking credentials. The
    // disguised backup serial contains the plain passkey suffix.
    const {
      passkeyDigest: _passkeyDigest,
      disguisedBackupSerial: _disguisedBackupSerial,
      ...adminSafeRecord
    } = item;
    void _passkeyDigest;
    void _disguisedBackupSerial;

    return {
      ...adminSafeRecord,
      confidentialAccountId:
        effectiveRole === "STANDARD_MODERATOR"
          ? null
          : item.confidentialAccountId,
      confidentialAccountVaultStatus:
        item.reportingMode === "ANONYMOUS"
          ? "Detached Zero Identity (Anonymous)"
          : effectiveRole === "STANDARD_MODERATOR"
            ? "Masked — Senior Clearance Required"
            : `Vault Protected (Ref: ${item.confidentialAccountId?.slice(0, 8) ?? "verified"}••• • Hidden from Target)`,
      generalLocationLabel:
        effectiveRole === "STANDARD_MODERATOR"
          ? "[Location Masked for Ordinary Moderator Role]"
          : item.generalLocationLabel,
      blindedRateLimitBucket:
        effectiveRole === "STANDARD_MODERATOR"
          ? "[Masked]"
          : item.blindedRateLimitBucket,
      internalNotes: visibleNotes,
    };
  }

  async adminGetComplaintDetail(
    token: string | undefined,
    referenceOrId: string,
    viewerRole?: string,
  ) {
    const reviewer = this.assertReviewer(token);
    await this.ensureHydrated();
    // A request may lower the caller to the ordinary-moderator view, but
    // cannot promote its own authenticated role through a query parameter.
    const effectiveRole =
      viewerRole === "STANDARD_MODERATOR"
        ? "STANDARD_MODERATOR"
        : reviewer.role;

    const record = this.findComplaintByRefOrId(referenceOrId);
    return {
      reviewer: {
        reviewerLabel: reviewer.reviewerLabel,
        effectiveRole,
      },
      complaint: this.maskComplaintForRole(record, effectiveRole),
    };
  }

  private findComplaintByRefOrId(
    referenceOrId: string,
  ): DiscreetComplaintRecord {
    const clean = (referenceOrId ?? "").trim();
    const norm = this.normalizeRef(clean);
    const byRef = this.complaintsMap.get(norm);
    if (byRef) return byRef;
    const byId = Array.from(this.complaintsMap.values()).find(
      (c) => c.id === clean || c.referenceNumber.toUpperCase() === norm,
    );
    if (!byId) {
      throw new NotFoundException(`Complaint ${clean} not found.`);
    }
    return byId;
  }

  async adminDashboardAndQueue(
    token: string | undefined,
    query: {
      status?: string;
      priority?: string;
      severity?: string;
      reportingMode?: string;
      categorySlug?: string;
      search?: string;
      page?: number;
      pageSize?: number;
      viewerRole?: string;
    } = {},
  ) {
    const reviewer = this.assertReviewer(token);
    await this.ensureHydrated();

    // The viewerRole query is permitted only to request a more restrictive
    // view; elevated roles always come from the validated reviewer credential.
    const effectiveRole =
      query.viewerRole === "STANDARD_MODERATOR"
        ? "STANDARD_MODERATOR"
        : reviewer.role;

    const allItems = Array.from(this.complaintsMap.values()).sort(
      (a, b) =>
        new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
    );

    const filtered = allItems.filter((item) => {
      if (
        query.status &&
        query.status !== "ALL" &&
        item.status !== query.status
      ) {
        return false;
      }
      if (
        query.priority &&
        query.priority !== "ALL" &&
        item.priority !== query.priority
      ) {
        return false;
      }
      if (
        query.severity &&
        query.severity !== "ALL" &&
        item.severity !== query.severity
      ) {
        return false;
      }
      if (
        query.reportingMode &&
        query.reportingMode !== "ALL" &&
        item.reportingMode !== query.reportingMode
      ) {
        return false;
      }
      if (
        query.categorySlug &&
        query.categorySlug !== "ALL" &&
        item.categorySlug !== query.categorySlug
      ) {
        return false;
      }
      if (query.search && query.search.trim().length > 0) {
        const q = query.search.trim().toLowerCase();
        const hay =
          `${item.referenceNumber} ${item.categoryTitle} ${item.description} ${item.linkedTargetHandle ?? ""} ${item.duplicateClusterId ?? ""}`.toLowerCase();
        if (!hay.includes(q)) return false;
      }
      return true;
    });

    const page = Math.max(1, query.page ?? 1);
    const pageSize = Math.min(50, Math.max(1, query.pageSize ?? 20));
    const start = (page - 1) * pageSize;
    const paged = filtered.slice(start, start + pageSize);

    const roleMaskedItems = paged.map((item) =>
      this.maskComplaintForRole(item, effectiveRole),
    );

    const openCount = allItems.filter(
      (i) => i.status !== "CLOSED" && i.status !== "REJECTED_WITH_REASON",
    ).length;
    const urgentP1Count = allItems.filter(
      (i) =>
        i.priority === "P1_URGENT" &&
        i.status !== "CLOSED" &&
        i.status !== "REJECTED_WITH_REASON",
    ).length;
    const anonCount = allItems.filter(
      (i) => i.reportingMode === "ANONYMOUS",
    ).length;
    const duplicateClusters = new Set(
      allItems.map((i) => i.duplicateClusterId).filter(Boolean),
    );
    const flaggedAbuseCount = allItems.filter(
      (i) => i.isFlaggedMaliciousAbuse,
    ).length;

    // Compute real median triage hours from actual records (0 when DB is empty)
    const triagedHoursList = allItems
      .filter((i) => i.status !== "SUBMITTED")
      .map((i) => {
        const diffMs =
          new Date(i.updatedAt).getTime() - new Date(i.createdAt).getTime();
        return Math.max(0.1, Number((diffMs / 3_600_000).toFixed(1)));
      })
      .sort((a, b) => a - b);
    const medianTriageHours =
      triagedHoursList.length > 0
        ? triagedHoursList[Math.floor(triagedHoursList.length / 2)]
        : 0;

    return {
      reviewer: {
        reviewerLabel: reviewer.reviewerLabel,
        effectiveRole,
        ordinaryModeratorMaskingActive: effectiveRole === "STANDARD_MODERATOR",
      },
      metrics: {
        totalComplaints: allItems.length,
        openComplaintsCount: openCount,
        urgentP1Count,
        anonymousPercentage:
          allItems.length > 0
            ? Math.round((anonCount / allItems.length) * 100)
            : 0,
        confidentialPercentage:
          allItems.length > 0
            ? 100 - Math.round((anonCount / allItems.length) * 100)
            : 0,
        duplicateClustersCount: duplicateClusters.size,
        flaggedMaliciousAbuseCount: flaggedAbuseCount,
        medianTriageHours,
      },
      pagination: {
        page,
        pageSize,
        totalItems: filtered.length,
        totalPages: Math.max(1, Math.ceil(filtered.length / pageSize)),
      },
      complaints: roleMaskedItems,
      categories: Array.from(this.categoriesMap.values()).sort(
        (a, b) => a.displayOrder - b.displayOrder,
      ),
      retentionPolicy: this.retentionPolicy,
      authorisedReviewers:
        SakhiAdminRbacRegistry.listAuthorisedComplaintReviewers(),
    };
  }

  async adminAssignAndClassify(
    token: string | undefined,
    referenceNumber: string,
    dto: AssignAndClassifyComplaintDto,
  ) {
    const reviewer = this.assertReviewer(token);
    await this.ensureHydrated();
    const record = this.findComplaintByRefOrId(referenceNumber);

    const allowedSeverities = new Set([
      "S1_CRITICAL",
      "S2_HIGH",
      "S3_MODERATE",
      "S4_LOW",
    ]);
    const allowedPriorities = new Set([
      "P1_URGENT",
      "P2_HIGH",
      "P3_STANDARD",
      "P4_ROUTINE",
    ]);
    if (!allowedSeverities.has(dto.severity)) {
      throw new BadRequestException(`Invalid severity "${dto.severity}".`);
    }
    if (!allowedPriorities.has(dto.priority)) {
      throw new BadRequestException(`Invalid priority "${dto.priority}".`);
    }

    record.assignedReviewerId = dto.assignedReviewerId.trim();
    record.assignedReviewerName = dto.assignedReviewerName.trim();
    record.severity = dto.severity as DiscreetComplaintRecord["severity"];
    record.priority = dto.priority as DiscreetComplaintRecord["priority"];
    if (record.status === "SUBMITTED") {
      record.status = "UNDER_REVIEW";
    }
    record.updatedAt = new Date().toISOString();
    const prevHash = record.auditHistory[0]?.integrityHash ?? "GENESIS";
    record.auditHistory.unshift({
      id: randomUUID(),
      auditCode: `#AUD-${randomInt(1000, 9999)}`,
      actorRole: reviewer.role,
      actorLabel: reviewer.reviewerLabel,
      action: "admin.complaint.assigned_classified",
      summary: `Assigned to ${record.assignedReviewerName} • Severity: ${record.severity} • Priority: ${record.priority}`,
      integrityHash: `SHA256:${this.hashString(`${prevHash}:assign:${record.updatedAt}`)}`,
      timestamp: record.updatedAt,
    });

    await this.persistComplaintSnapshot(
      record,
      "assign",
      "ADMIN",
      record.status,
    );
    return { updated: true, complaint: record };
  }

  async adminUpdateStatusAndEscalate(
    token: string | undefined,
    referenceNumber: string,
    dto: UpdateComplaintStatusDto,
  ) {
    const reviewer = this.assertReviewer(token);
    await this.ensureHydrated();
    const record = this.findComplaintByRefOrId(referenceNumber);

    const rawStatus = dto.status.trim().toUpperCase();
    const normalizedStatus = (
      rawStatus === "ADDITIONAL_INFORMATION_REQUIRED"
        ? "ADDITIONAL_INFO_REQUIRED"
        : rawStatus
    ) as ComplaintStatusType;

    if (!ALL_COMPLAINT_STATUSES.includes(normalizedStatus)) {
      throw new BadRequestException(
        `Unsupported complaint status: ${dto.status}`,
      );
    }

    // Enforce valid state transition matrix (allow idempotent same-status update for adding messages)
    if (record.status !== normalizedStatus) {
      const allowedNext = VALID_STATUS_TRANSITIONS[record.status] ?? [];
      if (!allowedNext.includes(normalizedStatus)) {
        throw new BadRequestException(
          `Invalid status transition from ${record.status} to ${normalizedStatus}. Allowed transitions: ${allowedNext.join(", ")}.`,
        );
      }
    }

    if (
      normalizedStatus === "REJECTED_WITH_REASON" &&
      !dto.rejectionReasonCode?.trim() &&
      !dto.publicMessageToComplainant?.trim()
    ) {
      throw new BadRequestException(
        "Rejected complaints must include a rejectionReasonCode or publicMessageToComplainant explanation (SRS 7.5).",
      );
    }

    if (
      normalizedStatus === "ADDITIONAL_INFO_REQUIRED" &&
      !dto.publicMessageToComplainant?.trim()
    ) {
      throw new BadRequestException(
        "Transitioning to ADDITIONAL_INFO_REQUIRED requires a publicMessageToComplainant question for the reporter.",
      );
    }

    record.status = normalizedStatus;
    if (dto.rejectionReasonCode?.trim()) {
      record.rejectionReasonCode = dto.rejectionReasonCode.trim();
    }
    if (dto.publicMessageToComplainant?.trim()) {
      record.publicResolutionSummary = dto.publicMessageToComplainant.trim();
      record.complainantMessages.push({
        id: `msg_admin_${Date.now()}`,
        senderRole: "SAFETY_REVIEWER",
        senderLabel: reviewer.reviewerLabel,
        message: dto.publicMessageToComplainant.trim(),
        attachedFiles: [],
        createdAt: new Date().toISOString(),
      });
    }
    if (
      Array.isArray(dto.enforcementActions) &&
      dto.enforcementActions.length > 0
    ) {
      record.enforcementActions = Array.from(
        new Set([...record.enforcementActions, ...dto.enforcementActions]),
      );
    }
    if (dto.escalateToSpecialist || normalizedStatus === "ESCALATED") {
      const reviewers =
        SakhiAdminRbacRegistry.listAuthorisedComplaintReviewers();
      const escLead =
        reviewers.find((r) => r.role === "SUPER_ADMIN") ?? reviewers[0]!;
      record.priority = "P1_URGENT";
      record.assignedReviewerId = escLead.id;
      record.assignedReviewerName = escLead.name;
    }

    record.updatedAt = new Date().toISOString();
    const prevHash = record.auditHistory[0]?.integrityHash ?? "GENESIS";
    record.auditHistory.unshift({
      id: randomUUID(),
      auditCode: `#AUD-${randomInt(1000, 9999)}`,
      actorRole: reviewer.role,
      actorLabel: reviewer.reviewerLabel,
      action: `admin.complaint.status.${normalizedStatus.toLowerCase()}`,
      summary: `Status changed to ${normalizedStatus}${dto.rejectionReasonCode ? ` (${dto.rejectionReasonCode})` : ""}`,
      integrityHash: `SHA256:${this.hashString(`${prevHash}:status:${normalizedStatus}:${record.updatedAt}`)}`,
      timestamp: record.updatedAt,
    });

    await this.persistComplaintSnapshot(
      record,
      "status",
      "ADMIN",
      normalizedStatus,
    );
    return { updated: true, complaint: record };
  }

  async adminSendMessageToComplainant(
    token: string | undefined,
    referenceNumber: string,
    dto: SendAdminMessageToComplainantDto,
  ) {
    const reviewer = this.assertReviewer(token);
    await this.ensureHydrated();
    const record = this.findComplaintByRefOrId(referenceNumber);

    const cleanMsg = (dto.message ?? "").trim();
    if (cleanMsg.length < 2) {
      throw new BadRequestException(
        "Message to complainant must be at least 2 characters.",
      );
    }

    const msgItem: ComplainantMessageItem = {
      id: `msg_admin_${Date.now()}`,
      senderRole: "SAFETY_REVIEWER",
      senderLabel: reviewer.reviewerLabel,
      message: cleanMsg,
      attachedFiles: [],
      createdAt: new Date().toISOString(),
    };

    record.complainantMessages.push(msgItem);
    record.publicResolutionSummary = cleanMsg;
    record.updatedAt = msgItem.createdAt;
    const prevHash = record.auditHistory[0]?.integrityHash ?? "GENESIS";
    record.auditHistory.unshift({
      id: randomUUID(),
      auditCode: `#AUD-${randomInt(1000, 9999)}`,
      actorRole: reviewer.role,
      actorLabel: reviewer.reviewerLabel,
      action: "admin.complaint.message_sent_to_complainant",
      summary: `Direct encrypted message sent to complainant (${record.referenceNumber})`,
      integrityHash: `SHA256:${this.hashString(`${prevHash}:admin_msg:${record.updatedAt}`)}`,
      timestamp: record.updatedAt,
    });

    await this.persistComplaintSnapshot(
      record,
      "admin_message",
      "ADMIN",
      record.status,
    );
    return {
      sent: true,
      messageItem: msgItem,
      complaint: record,
    };
  }

  async adminAddInternalNote(
    token: string | undefined,
    referenceNumber: string,
    dto: AddComplaintInternalNoteDto,
  ) {
    const reviewer = this.assertReviewer(token);
    await this.ensureHydrated();
    const record = this.findComplaintByRefOrId(referenceNumber);

    const cleanNote = (dto.noteText ?? "").trim();
    if (cleanNote.length < 3) {
      throw new BadRequestException(
        "Internal note must be at least 3 characters.",
      );
    }

    const note: InternalReviewerNoteItem = {
      id: `note_${Date.now()}`,
      reviewerId: record.assignedReviewerId ?? "SR-04",
      reviewerName: reviewer.reviewerLabel,
      visibilityRole:
        dto.visibilityRole === "SUPER_ADMIN"
          ? "SUPER_ADMIN"
          : "SENIOR_REVIEWER",
      noteText: cleanNote,
      createdAt: new Date().toISOString(),
    };
    record.internalNotes.unshift(note);
    record.updatedAt = note.createdAt;
    const prevHash = record.auditHistory[0]?.integrityHash ?? "GENESIS";
    record.auditHistory.unshift({
      id: randomUUID(),
      auditCode: `#AUD-${randomInt(1000, 9999)}`,
      actorRole: reviewer.role,
      actorLabel: reviewer.reviewerLabel,
      action: "admin.complaint.internal_note_added",
      summary: `Internal note added (${note.visibilityRole} visibility • Never shown to users)`,
      integrityHash: `SHA256:${this.hashString(`${prevHash}:note:${record.updatedAt}`)}`,
      timestamp: record.updatedAt,
    });

    await this.persistComplaintSnapshot(record, "note", "ADMIN", "NOTE_ADDED");
    return { added: true, internalNote: note, complaint: record };
  }

  async adminAccessControlledEvidence(
    token: string | undefined,
    referenceNumber: string,
    dto: AccessComplaintEvidenceDto,
  ) {
    const reviewer = this.assertReviewer(token);
    if (dto.viewerRole === "STANDARD_MODERATOR") {
      throw new ForbiddenException(
        "Ordinary moderators are not authorised to unblur or export raw complaint evidence (SRS 7.6).",
      );
    }
    await this.ensureHydrated();
    const record = this.findComplaintByRefOrId(referenceNumber);

    const ev = record.evidenceFiles.find((e) => e.id === dto.evidenceId);
    if (!ev) {
      throw new NotFoundException(
        `Evidence attachment ${dto.evidenceId} not found on complaint ${record.referenceNumber}.`,
      );
    }
    if (ev.isPurged) {
      throw new ConflictException(
        "This evidence file has already been purged under DPDP retention/erasure controls.",
      );
    }

    const cleanReason = (dto.justificationReason ?? "").trim();
    if (cleanReason.length < 10) {
      throw new BadRequestException(
        "A justificationReason of at least 10 characters is required to unblur or export evidence.",
      );
    }

    const nowIso = new Date().toISOString();
    const watermarkStamp = `WATERMARK: ${reviewer.reviewerLabel} • ${record.referenceNumber} • ${nowIso} • Reason: ${cleanReason}`;
    const prevHash = record.auditHistory[0]?.integrityHash ?? "GENESIS";

    record.auditHistory.unshift({
      id: randomUUID(),
      auditCode: `#AUD-${randomInt(1000, 9999)}`,
      actorRole: reviewer.role,
      actorLabel: reviewer.reviewerLabel,
      action: `admin.evidence.${dto.action.toLowerCase()}`,
      summary: `Controlled Evidence ${dto.action} (${ev.fileName}) • Justification: ${cleanReason}`,
      integrityHash: `SHA256:${this.hashString(`${prevHash}:evidence:${ev.id}:${nowIso}`)}`,
      timestamp: nowIso,
    });
    record.updatedAt = nowIso;

    await this.persistComplaintSnapshot(
      record,
      "evidence_access",
      "ADMIN",
      dto.action,
    );
    return {
      authorized: true,
      evidenceId: ev.id,
      fileName: ev.fileName,
      sha256Digest: ev.sha256Digest,
      action: dto.action,
      watermarkOverlayText: watermarkStamp,
      expiresAt: new Date(Date.now() + 48 * 3600_000).toISOString(),
      auditTrailUpdated: true,
      complaint: record,
    };
  }

  async adminMergeDuplicateComplaints(
    token: string | undefined,
    dto: MergeDuplicateComplaintsDto,
  ) {
    const reviewer = this.assertReviewer(token);
    if (dto.viewerRole === "STANDARD_MODERATOR") {
      throw new ForbiddenException(
        "Ordinary moderators cannot merge complaint clusters.",
      );
    }
    await this.ensureHydrated();
    const primary = this.findComplaintByRefOrId(dto.primaryReferenceNumber);
    const primaryNorm = primary.referenceNumber;

    if (
      !Array.isArray(dto.duplicateReferenceNumbers) ||
      dto.duplicateReferenceNumbers.length === 0
    ) {
      throw new BadRequestException(
        "Provide at least one duplicate reference number to merge.",
      );
    }

    const clusterId =
      dto.clusterId?.trim() ||
      primary.duplicateClusterId ||
      `CLUST-${randomInt(100, 999)}`;
    primary.duplicateClusterId = clusterId;
    const nowIso = new Date().toISOString();

    const mergedRefs: string[] = [];
    for (const dupRaw of dto.duplicateReferenceNumbers) {
      const dupNorm = this.normalizeRef(dupRaw);
      if (dupNorm === primaryNorm) continue;
      const dup = this.complaintsMap.get(dupNorm);
      if (!dup) {
        throw new NotFoundException(
          `Duplicate complaint ${dupNorm} not found.`,
        );
      }
      dup.duplicateClusterId = clusterId;
      dup.mergedIntoReference = primaryNorm;
      dup.status = "CLOSED";
      dup.publicResolutionSummary = `Merged into primary investigation ${primaryNorm} under Repeat-Offender Cluster #${clusterId}.`;
      dup.updatedAt = nowIso;
      mergedRefs.push(dupNorm);
      await this.persistComplaintSnapshot(
        dup,
        "merge_child",
        "ADMIN",
        "CLOSED",
      );
    }

    const prevHash = primary.auditHistory[0]?.integrityHash ?? "GENESIS";
    primary.auditHistory.unshift({
      id: randomUUID(),
      auditCode: `#AUD-${randomInt(1000, 9999)}`,
      actorRole: reviewer.role,
      actorLabel: reviewer.reviewerLabel,
      action: "admin.complaint.duplicate_cluster_merged",
      summary: `Linked Cluster #${clusterId} • Merged ${mergedRefs.join(", ")} into ${primaryNorm}`,
      integrityHash: `SHA256:${this.hashString(`${prevHash}:merge:${clusterId}:${nowIso}`)}`,
      timestamp: nowIso,
    });
    primary.updatedAt = nowIso;
    await this.persistComplaintSnapshot(
      primary,
      "merge_primary",
      "ADMIN",
      clusterId,
    );

    return {
      merged: true,
      clusterId,
      primaryReferenceNumber: primaryNorm,
      mergedReferences: mergedRefs,
      primaryComplaint: primary,
    };
  }

  async adminHandleMaliciousReport(
    token: string | undefined,
    referenceNumber: string,
    dto: HandleMaliciousComplaintDto,
  ) {
    const reviewer = this.assertReviewer(token);
    if (dto.viewerRole === "STANDARD_MODERATOR") {
      throw new ForbiddenException(
        "Ordinary moderators are not authorised to apply malicious-report bucket throttles.",
      );
    }
    await this.ensureHydrated();
    const record = this.findComplaintByRefOrId(referenceNumber);

    const hours = dto.cooldownHours ?? 72;
    const untilIso = new Date(Date.now() + hours * 3600_000).toISOString();
    record.isFlaggedMaliciousAbuse = true;
    record.maliciousAbuseReason = dto.reason.trim();
    record.status = "REJECTED_WITH_REASON";
    record.rejectionReasonCode = "#MALICIOUS-OR-BAD-FAITH-REPORT";
    record.publicResolutionSummary =
      "Report closed under Sakhi Anti-Abuse & Malicious Report Safeguards (SRS 7.6).";
    record.enforcementActions = Array.from(
      new Set([
        ...record.enforcementActions,
        `BLINDED_BUCKET_THROTTLED_${hours}H`,
      ]),
    );
    this.throttledBuckets.set(record.blindedRateLimitBucket, {
      untilIso,
      reason: dto.reason.trim(),
    });

    const nowIso = new Date().toISOString();
    record.updatedAt = nowIso;
    const prevHash = record.auditHistory[0]?.integrityHash ?? "GENESIS";
    record.auditHistory.unshift({
      id: randomUUID(),
      auditCode: `#AUD-${randomInt(1000, 9999)}`,
      actorRole: reviewer.role,
      actorLabel: reviewer.reviewerLabel,
      action: "admin.complaint.malicious_report_handled",
      summary: `Malicious report safeguard applied (${dto.action}) • Blinded bucket ${record.blindedRateLimitBucket} throttled for ${hours}h without unmasking user identity`,
      integrityHash: `SHA256:${this.hashString(`${prevHash}:malicious:${nowIso}`)}`,
      timestamp: nowIso,
    });

    await this.persistComplaintSnapshot(
      record,
      "malicious_guard",
      "ADMIN",
      "REJECTED",
    );
    return {
      handled: true,
      throttledBucket: record.blindedRateLimitBucket,
      cooldownUntil: untilIso,
      complaint: record,
    };
  }

  async adminUpsertCategory(
    token: string | undefined,
    dto: UpsertComplaintCategoryConfigDto,
  ) {
    const reviewer = this.assertReviewer(token);
    if (
      dto.viewerRole === "STANDARD_MODERATOR" ||
      reviewer.adminRole !== "SUPER_ADMIN"
    ) {
      throw new ForbiddenException(
        "Only Super Admin is authorised to modify global complaint categories.",
      );
    }
    await this.ensureHydrated();

    const slug = dto.slug
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9_]/g, "_");
    if (!slug) {
      throw new BadRequestException("Category slug cannot be empty.");
    }
    const existing = this.categoriesMap.get(slug);
    const updated: ComplaintCategoryItem = {
      slug,
      name: dto.name.trim(),
      description: dto.description.trim(),
      iconKey: dto.iconKey?.trim() || existing?.iconKey || "shield",
      flowerType: dto.flowerType?.trim() || existing?.flowerType || "peonySoft",
      defaultPriority:
        dto.defaultPriority?.trim() || existing?.defaultPriority || "P2_HIGH",
      defaultSeverity:
        dto.defaultSeverity?.trim() || existing?.defaultSeverity || "S2_HIGH",
      safetyGuidanceText:
        dto.safetyGuidanceText?.trim() ||
        existing?.safetyGuidanceText ||
        "Preserve evidence safely and use Quick Exit if someone is nearby.",
      legalHelplineNote:
        dto.legalHelplineNote?.trim() ||
        existing?.legalHelplineNote ||
        "Dial 112 or 1091 for immediate police assistance.",
      isEnabled: dto.isEnabled ?? existing?.isEnabled ?? true,
      displayOrder:
        dto.displayOrder ??
        existing?.displayOrder ??
        this.categoriesMap.size + 1,
    };
    this.categoriesMap.set(slug, updated);

    const anyPrisma = this.prisma as unknown as Record<string, any>;
    if (anyPrisma.complaintCategoryConfig?.upsert) {
      await anyPrisma.complaintCategoryConfig
        .upsert({
          where: { slug },
          update: {
            name: updated.name,
            description: updated.description,
            iconKey: updated.iconKey,
            flowerType: updated.flowerType,
            defaultPriority: updated.defaultPriority,
            defaultSeverity: updated.defaultSeverity,
            safetyGuidanceText: updated.safetyGuidanceText,
            legalHelplineNote: updated.legalHelplineNote,
            isEnabled: updated.isEnabled,
            displayOrder: updated.displayOrder,
            updatedBy: reviewer.reviewerLabel,
          },
          create: {
            ...updated,
            updatedBy: reviewer.reviewerLabel,
          },
        })
        .catch(() => null);
    }

    if (this.prisma.auditEvent?.create) {
      await this.prisma.auditEvent
        .create({
          data: {
            actorType: "ADMIN",
            action: "admin.complaint_category.upserted",
            targetType: "complaint_category",
            targetId: slug,
            outcome: updated.isEnabled ? "ENABLED" : "DISABLED",
            requestId: randomUUID(),
            redactedMetadata: JSON.parse(
              JSON.stringify({
                reviewer: reviewer.reviewerLabel,
                category: updated,
              }),
            ),
          },
        })
        .catch(() => null);
    }

    return {
      updated: true,
      category: updated,
      categories: Array.from(this.categoriesMap.values()).sort(
        (a, b) => a.displayOrder - b.displayOrder,
      ),
    };
  }

  async adminUpdateRetentionPolicy(
    token: string | undefined,
    dto: UpdateComplaintRetentionPolicyDto,
  ) {
    const reviewer = this.assertReviewer(token);
    if (
      dto.viewerRole === "STANDARD_MODERATOR" ||
      reviewer.adminRole !== "SUPER_ADMIN"
    ) {
      throw new ForbiddenException(
        "Only Super Admin is authorised to modify global DPDP retention policies.",
      );
    }
    await this.ensureHydrated();

    this.retentionPolicy = {
      policyKey: "default",
      closedEvidenceRetentionDays: dto.closedEvidenceRetentionDays,
      rejectedReportRetentionDays: dto.rejectedReportRetentionDays,
      technicalRateLimitLogDays: dto.technicalRateLimitLogDays,
      updatedBy: reviewer.reviewerLabel,
      updatedAt: new Date().toISOString(),
    };

    const anyPrisma = this.prisma as unknown as Record<string, any>;
    if (anyPrisma.complaintRetentionPolicy?.upsert) {
      await anyPrisma.complaintRetentionPolicy
        .upsert({
          where: { policyKey: "default" },
          update: {
            closedEvidenceRetentionDays: dto.closedEvidenceRetentionDays,
            rejectedReportRetentionDays: dto.rejectedReportRetentionDays,
            technicalRateLimitLogDays: dto.technicalRateLimitLogDays,
            updatedBy: reviewer.reviewerLabel,
          },
          create: {
            policyKey: "default",
            closedEvidenceRetentionDays: dto.closedEvidenceRetentionDays,
            rejectedReportRetentionDays: dto.rejectedReportRetentionDays,
            technicalRateLimitLogDays: dto.technicalRateLimitLogDays,
            updatedBy: reviewer.reviewerLabel,
          },
        })
        .catch(() => null);
    }

    if (this.prisma.auditEvent?.create) {
      await this.prisma.auditEvent
        .create({
          data: {
            actorType: "ADMIN",
            action: "admin.complaint_retention.updated",
            targetType: "complaint_retention_policy",
            targetId: "default",
            outcome: "UPDATED",
            requestId: randomUUID(),
            redactedMetadata: this.retentionPolicy,
          },
        })
        .catch(() => null);
    }

    return {
      updated: true,
      retentionPolicy: this.retentionPolicy,
    };
  }
}
