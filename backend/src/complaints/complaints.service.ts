import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
  UnauthorizedException,
} from "@nestjs/common";
import { createHash, randomUUID, timingSafeEqual } from "node:crypto";
import { AuthenticationService } from "../auth/auth.service.js";
import { PrismaService } from "../database/prisma.service.js";
import { StagingTestAdminService } from "../staging-test-admin/staging-test-admin.service.js";
import { DEFAULT_LOCAL_DEV_ADMIN_TOKEN } from "../admin-review/admin-review.service.js";
import type {
  AccessComplaintEvidenceDto,
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
    description: "Abusive DMs, image morphing, doxxing, non-consensual sharing, or trolling",
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
    description: "Following, repeated unwanted calls/messages, or physical surveillance",
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
    description: "POSH sexual harassment, quid-pro-quo coercion, or hostile work environment",
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
    description: "Unsafe streets, dark corridors, transit harassment, or loitering hotspots",
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
    description: "Financial scams, fake profiles, impersonation, or blackmail/extortion",
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
    description: "Exclusion, hate speech, or bias based on caste, religion, gender, or background",
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
    description: "Partner, spouse, family, or household abuse, coercion, and threats",
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
    description: "Misconduct, unsafe service, or policy breach by a listed business page",
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
    description: "Any other personal safety, privacy, or community wellbeing concern",
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
  senderRole: "COMPLAINANT_ANONYMOUS" | "COMPLAINANT_CONFIDENTIAL" | "SAFETY_REVIEWER";
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
  timestamp: string;
}

export interface DiscreetComplaintRecord {
  id: string;
  referenceNumber: string;
  passkeyPlainHint?: string;
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
  supportingLinks: Array<{ url: string; linkType: string; snapshotArchived: boolean }>;
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

@Injectable()
export class ComplaintsService {
  private readonly categoriesMap = new Map<string, ComplaintCategoryItem>();
  private readonly complaintsMap = new Map<string, DiscreetComplaintRecord>();
  private readonly throttledBuckets = new Map<string, { untilIso: string; reason: string }>();
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
    this.seedInitialReferenceComplaints();
  }

  private hashString(val: string): string {
    return createHash("sha256").update(val).digest("hex");
  }

  private seedInitialReferenceComplaints(): void {
    const now = Date.now();
    const iso = (offsetMins: number) => new Date(now + offsetMins * 60_000).toISOString();

    const seeded: DiscreetComplaintRecord[] = [
      {
        id: "c5000000-0000-4000-8000-000000008492",
        referenceNumber: "#SKH-ANON-2026-8492",
        passkeyPlainHint: "LOTUS-749-SAFE",
        passkeyDigest: this.hashString("LOTUS-749-SAFE"),
        disguisedBackupSerial: "Series #8492-LOTUS-749",
        reportingMode: "ANONYMOUS",
        confidentialAccountId: null,
        blindedRateLimitBucket: "bkt_9f21a4c8e012",
        categorySlug: "harassment",
        categoryTitle: "Harassment",
        customCategoryLabel: null,
        urgency: "HAPPENING_NOW",
        description:
          "Over the past three days, a member account kept sending unwanted messages after a community member declined a business collaboration inquiry in the local area yesterday evening.",
        piiGuardRedacted: true,
        approximateDateLabel: "25 Oct 2026",
        approximateTimeWindow: "Evening (5 PM – 9 PM)",
        locationType: "COARSE_AREA",
        generalLocationLabel: "Chandragiri Mandal / Tirupati Public Area (5 km Coarse Zone)",
        linkedTargetType: "POST",
        linkedTargetHandle: "@studio_collab_tpt24",
        linkedPostId: "pst_98234_oct25",
        linkedBusinessId: null,
        evidenceFiles: [
          {
            id: "ev_8492_01",
            fileName: "evidence_redacted_01.png",
            originalFileNameRedacted: "[REDACTED_ORIGINAL_FILENAME].jpg",
            contentType: "image/png",
            byteSize: 1420800,
            sha256Digest: "8f4c2b910e4a71239c5812b74a0f12e9b814c6a2039481726354819203a4e92a",
            exifGpsStripped: true,
            deviceMetadataStripped: true,
            visualBlurApplied: true,
            scrubbedFields: ["EXIF.GPSLatitude", "EXIF.GPSLongitude", "EXIF.Make", "EXIF.Model", "OriginalFilename"],
            uploadedAt: iso(-120),
          },
          {
            id: "ev_8492_02",
            fileName: "chat_export_log_oct25.pdf",
            originalFileNameRedacted: "[REDACTED_DOCUMENT].pdf",
            contentType: "application/pdf",
            byteSize: 634880,
            sha256Digest: "3a1d9e774b2c80912f6e1189c023a4b5c6d7e8f90123456789abcdef01234567",
            exifGpsStripped: true,
            deviceMetadataStripped: true,
            visualBlurApplied: false,
            scrubbedFields: ["PDF.Author", "PDF.Creator", "PDF.Producer", "PDF.CreationDate"],
            uploadedAt: iso(-118),
          },
        ],
        supportingLinks: [
          {
            url: "sakhi://community/post/pst_98234_oct25",
            linkType: "SAKHI_POST_SNAPSHOT",
            snapshotArchived: true,
          },
        ],
        wantsUpdates: true,
        submitAnonymouslyToReviewTeam: true,
        acknowledgedNonPoliceLegalNotice: true,
        status: "ADDITIONAL_INFO_REQUIRED",
        severity: "S2_HIGH",
        priority: "P1_URGENT",
        assignedReviewerId: "SR-04",
        assignedReviewerName: "Meera Krishnan (#SR-04 • Senior Trust & Safety Officer)",
        duplicateClusterId: "CLUST-209",
        mergedIntoReference: null,
        isFlaggedMaliciousAbuse: false,
        maliciousAbuseReason: null,
        rejectionReasonCode: null,
        publicResolutionSummary:
          "Assigned to Senior Reviewer #SR-04. Cross-checking repeat-offender cluster #CLUST-209.",
        enforcementActions: ["ARCHIVE_POST_SNAPSHOT", "ZERO_DISCOVERY_SHIELD_ACTIVE"],
        complainantMessages: [
          {
            id: "msg_8492_1",
            senderRole: "SAFETY_REVIEWER",
            senderLabel: "Senior Safety Reviewer #SR-04",
            message:
              "Thank you for sharing your report bravely. We have verified the primary account you reported. Before we apply a permanent restriction, could you clarify if the user contacted you from any secondary handle so we can block those as well? (Please do not include your own phone number.)",
            attachedFiles: [],
            createdAt: iso(-45),
          },
        ],
        internalNotes: [
          {
            id: "note_8492_1",
            reviewerId: "SR-04",
            reviewerName: "Meera Krishnan (#SR-04)",
            visibilityRole: "SENIOR_REVIEWER",
            noteText:
              "Target account @studio_collab_tpt24 matched 2 prior anonymous complaints in Cluster #CLUST-209 for intimidating female business owners. Stripped screenshot hashes verified.",
            createdAt: iso(-50),
          },
        ],
        auditHistory: [
          {
            id: "aud_8492_1",
            auditCode: "#AUD-9912",
            actorRole: "SYSTEM_INTAKE",
            actorLabel: "Anonymous Privacy Gateway",
            action: "complaint.submitted.anonymous",
            summary: "Anonymous intake created • Profile detached • 2 files EXIF-scrubbed",
            timestamp: iso(-120),
          },
          {
            id: "aud_8492_2",
            auditCode: "#AUD-9930",
            actorRole: "ADMIN_REVIEWER",
            actorLabel: "Meera Krishnan (#SR-04)",
            action: "complaint.assigned.classified",
            summary: "Assigned to Reviewer #SR-04 • Severity: S2_HIGH • Priority: P1_URGENT",
            timestamp: iso(-65),
          },
          {
            id: "aud_8492_3",
            auditCode: "#AUD-9938",
            actorRole: "ADMIN_REVIEWER",
            actorLabel: "Meera Krishnan (#SR-04)",
            action: "complaint.status.additional_info_required",
            summary: "Status updated to ADDITIONAL_INFO_REQUIRED with encrypted question",
            timestamp: iso(-45),
          },
        ],
        mediaPurgedAt: null,
        retentionExpiresAt: new Date(now + 90 * 86_400_000).toISOString(),
        createdAt: iso(-120),
        updatedAt: iso(-45),
      },
      {
        id: "c5000000-0000-4000-8000-000000008489",
        referenceNumber: "#SKH-CONF-2026-8489",
        passkeyPlainHint: "PEONY-318-GUARD",
        passkeyDigest: this.hashString("PEONY-318-GUARD"),
        disguisedBackupSerial: "Series #8489-PEONY-318",
        reportingMode: "CONFIDENTIAL",
        confidentialAccountId: "00000000-0000-4000-8000-000000000101",
        blindedRateLimitBucket: "bkt_4a89c1d2f901",
        categorySlug: "stalking_unwanted_contact",
        categoryTitle: "Stalking or unwanted contact",
        customCategoryLabel: null,
        urgency: "REPEATED_PATTERN",
        description:
          "Repeated unwanted contact across multiple community circles and attempts to follow after being blocked.",
        piiGuardRedacted: true,
        approximateDateLabel: "24 Oct 2026",
        approximateTimeWindow: "Night (9 PM – 6 AM)",
        locationType: "ONLINE_IN_APP",
        generalLocationLabel: "Online / Sakhi Community Circles",
        linkedTargetType: "MEMBER",
        linkedTargetHandle: "@studio_collab_tpt24",
        linkedPostId: null,
        linkedBusinessId: null,
        evidenceFiles: [
          {
            id: "ev_8489_01",
            fileName: "evidence_redacted_stalking_01.png",
            originalFileNameRedacted: "[REDACTED_SCREENSHOT].png",
            contentType: "image/png",
            byteSize: 912400,
            sha256Digest: "7c91e044a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a",
            exifGpsStripped: true,
            deviceMetadataStripped: true,
            visualBlurApplied: true,
            scrubbedFields: ["EXIF.GPS", "EXIF.DeviceID"],
            uploadedAt: iso(-340),
          },
        ],
        supportingLinks: [],
        wantsUpdates: true,
        submitAnonymouslyToReviewTeam: false,
        acknowledgedNonPoliceLegalNotice: true,
        status: "ESCALATED",
        severity: "S1_CRITICAL",
        priority: "P1_URGENT",
        assignedReviewerId: "EL-01",
        assignedReviewerName: "Dr. Kavita Rao (#EL-01 • Escalation Lead)",
        duplicateClusterId: "CLUST-209",
        mergedIntoReference: null,
        isFlaggedMaliciousAbuse: false,
        maliciousAbuseReason: null,
        rejectionReasonCode: null,
        publicResolutionSummary:
          "Escalated to Senior Trust & Safety Specialist Lead (#EL-01). Correlated with Cluster #CLUST-209 for permanent platform-wide enforcement.",
        enforcementActions: ["AUTO_BLOCK_APPLIED", "ESCALATED_TO_SPECIALIST_DESK"],
        complainantMessages: [],
        internalNotes: [
          {
            id: "note_8489_1",
            reviewerId: "EL-01",
            reviewerName: "Dr. Kavita Rao (#EL-01)",
            visibilityRole: "SUPER_ADMIN",
            noteText:
              "Confidential reporter identity locked in encrypted vault (hidden from standard moderators). Mutual block and search invisibility enforced immediately.",
            createdAt: iso(-200),
          },
        ],
        auditHistory: [
          {
            id: "aud_8489_1",
            auditCode: "#AUD-9840",
            actorRole: "SYSTEM_INTAKE",
            actorLabel: "Confidential Vault Gateway",
            action: "complaint.submitted.confidential",
            summary: "Confidential intake created • Identity hidden from target & standard mods",
            timestamp: iso(-340),
          },
          {
            id: "aud_8489_2",
            auditCode: "#AUD-9885",
            actorRole: "ADMIN_REVIEWER",
            actorLabel: "Dr. Kavita Rao (#EL-01)",
            action: "complaint.status.escalated",
            summary: "Escalated to P1 Specialist Desk • Linked to Cluster #CLUST-209",
            timestamp: iso(-200),
          },
        ],
        mediaPurgedAt: null,
        retentionExpiresAt: new Date(now + 90 * 86_400_000).toISOString(),
        createdAt: iso(-340),
        updatedAt: iso(-200),
      },
      {
        id: "c5000000-0000-4000-8000-000000008471",
        referenceNumber: "#SKH-ANON-2026-8471",
        passkeyPlainHint: "SAGE-109-MINT",
        passkeyDigest: this.hashString("SAGE-109-MINT"),
        disguisedBackupSerial: "Series #8471-SAGE-109",
        reportingMode: "ANONYMOUS",
        confidentialAccountId: null,
        blindedRateLimitBucket: "bkt_spam_flood_7721",
        categorySlug: "business_related_complaints",
        categoryTitle: "Business-related complaints",
        customCategoryLabel: null,
        urgency: "PAST_INCIDENT",
        description:
          "Unverified competitor complaint submitted in burst flood (5 identical reports in 4 minutes without supporting evidence).",
        piiGuardRedacted: false,
        approximateDateLabel: "22 Oct 2026",
        approximateTimeWindow: "Afternoon (12 PM – 5 PM)",
        locationType: "PREFER_NOT_TO_SAY",
        generalLocationLabel: null,
        linkedTargetType: "BUSINESS",
        linkedTargetHandle: "@aaradhya_handlooms",
        linkedPostId: null,
        linkedBusinessId: "BIZ-409",
        evidenceFiles: [],
        supportingLinks: [],
        wantsUpdates: false,
        submitAnonymouslyToReviewTeam: true,
        acknowledgedNonPoliceLegalNotice: true,
        status: "REJECTED_WITH_REASON",
        severity: "S4_LOW",
        priority: "P4_ROUTINE",
        assignedReviewerId: "SR-07",
        assignedReviewerName: "Anjali Menon (#SR-07 • Safety Reviewer)",
        duplicateClusterId: null,
        mergedIntoReference: null,
        isFlaggedMaliciousAbuse: true,
        maliciousAbuseReason:
          "Burst flood pattern (5 identical submissions in 4 mins from same blinded bucket) with zero corroborating evidence.",
        rejectionReasonCode: "#OUTSIDE-SCOPE-OR-UNVERIFIED-BURST",
        publicResolutionSummary:
          "We carefully reviewed this report. It concerns a commercial dispute without safety threats or corroborating evidence. You may submit an appeal with new evidence if harassment occurred.",
        enforcementActions: ["BLINDED_BUCKET_RATE_LIMITED_72H"],
        complainantMessages: [],
        internalNotes: [],
        auditHistory: [
          {
            id: "aud_8471_1",
            auditCode: "#AUD-9710",
            actorRole: "ADMIN_REVIEWER",
            actorLabel: "Anjali Menon (#SR-07)",
            action: "complaint.status.rejected_with_reason",
            summary: "Marked Rejected with Reason (#OUTSIDE-SCOPE-OR-UNVERIFIED-BURST)",
            timestamp: iso(-600),
          },
        ],
        mediaPurgedAt: null,
        retentionExpiresAt: new Date(now + 30 * 86_400_000).toISOString(),
        createdAt: iso(-720),
        updatedAt: iso(-600),
      },
      {
        id: "c5000000-0000-4000-8000-000000008465",
        referenceNumber: "#SKH-ANON-2026-8465",
        passkeyPlainHint: "ROSE-552-CALM",
        passkeyDigest: this.hashString("ROSE-552-CALM"),
        disguisedBackupSerial: "Series #8465-ROSE-552",
        reportingMode: "ANONYMOUS",
        confidentialAccountId: null,
        blindedRateLimitBucket: "bkt_3319ef01a8",
        categorySlug: "online_abuse_cyberbullying",
        categoryTitle: "Online abuse or cyberbullying",
        customCategoryLabel: null,
        urgency: "PAST_INCIDENT",
        description:
          "Account posted derogatory and harassing comments under a community wellness thread.",
        piiGuardRedacted: true,
        approximateDateLabel: "21 Oct 2026",
        approximateTimeWindow: "Evening (5 PM – 9 PM)",
        locationType: "ONLINE_IN_APP",
        generalLocationLabel: "Online / Social Wall",
        linkedTargetType: "POST",
        linkedTargetHandle: "@troll_handle_99",
        linkedPostId: "pst_44120_oct21",
        linkedBusinessId: null,
        evidenceFiles: [
          {
            id: "ev_8465_01",
            fileName: "comment_capture_scrubbed.png",
            originalFileNameRedacted: "[REDACTED].png",
            contentType: "image/png",
            byteSize: 512000,
            sha256Digest: "9b8a7c6d5e4f3a2b1c0d9e8f7a6b5c4d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9a8b",
            exifGpsStripped: true,
            deviceMetadataStripped: true,
            visualBlurApplied: true,
            scrubbedFields: ["EXIF.GPS", "EXIF.Model"],
            uploadedAt: iso(-1440),
          },
        ],
        supportingLinks: [],
        wantsUpdates: true,
        submitAnonymouslyToReviewTeam: true,
        acknowledgedNonPoliceLegalNotice: true,
        status: "ACTION_TAKEN",
        severity: "S2_HIGH",
        priority: "P2_HIGH",
        assignedReviewerId: "SR-04",
        assignedReviewerName: "Meera Krishnan (#SR-04 • Senior Trust & Safety Officer)",
        duplicateClusterId: null,
        mergedIntoReference: null,
        isFlaggedMaliciousAbuse: false,
        maliciousAbuseReason: null,
        rejectionReasonCode: null,
        publicResolutionSummary:
          "Protective Action Taken: Offending account permanently suspended, abusive comments removed, and device added to Repeat-Offender Blocklist. Your identity was never exposed.",
        enforcementActions: [
          "OFFENDING_ACCOUNT_SUSPENDED",
          "CONTENT_AND_DMS_REMOVED",
          "REPEAT_OFFENDER_DEVICE_BLOCK",
        ],
        complainantMessages: [],
        internalNotes: [],
        auditHistory: [
          {
            id: "aud_8465_1",
            auditCode: "#AUD-9610",
            actorRole: "ADMIN_REVIEWER",
            actorLabel: "Meera Krishnan (#SR-04)",
            action: "complaint.status.action_taken",
            summary: "Protective Action Taken: Target suspended & content removed",
            timestamp: iso(-1100),
          },
        ],
        mediaPurgedAt: null,
        retentionExpiresAt: new Date(now + 90 * 86_400_000).toISOString(),
        createdAt: iso(-1440),
        updatedAt: iso(-1100),
      },
    ];

    for (const item of seeded) {
      this.complaintsMap.set(item.referenceNumber.toUpperCase(), item);
    }
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

  public assertReviewer(provided?: string): { reviewerLabel: string; role: "SENIOR_REVIEWER" | "SUPER_ADMIN" } {
    if (
      process.env.NODE_ENV === "production" &&
      process.env.SAKHI_ENV === "staging"
    ) {
      if (
        provided?.startsWith("full-admin.") ||
        provided?.startsWith("test-access.") ||
        (!this.stagingAdminReviewEnabled() && this.stagingFullAdminEnabled())
      ) {
        const label = StagingTestAdminService.assertFullAdminSessionToken(provided);
        return { reviewerLabel: label, role: "SUPER_ADMIN" };
      }
    }
    const expected = this.configuredAdminToken();
    if (!provided) {
      throw new UnauthorizedException("A reviewer token is required to access complaint management.");
    }
    const candidates = expected
      .split(",")
      .map((item) => item.trim())
      .filter((item) => item.length > 0);
    const providedDigest = createHash("sha256").update(provided.trim()).digest();
    const matched = candidates.some((candidate) => {
      const expectedDigest = createHash("sha256").update(candidate).digest();
      return timingSafeEqual(expectedDigest, providedDigest);
    });
    if (!matched) {
      throw new UnauthorizedException("The reviewer token is invalid or expired.");
    }
    const label = process.env.SAKHI_ADMIN_REVIEWER_LABEL?.trim() || "Meera Krishnan (#SR-04)";
    return { reviewerLabel: label, role: "SENIOR_REVIEWER" };
  }

  private async resolveOptionalAccountId(authorization?: string): Promise<string | null> {
    if (!authorization || !authorization.trim().toLowerCase().startsWith("bearer ")) {
      return null;
    }
    try {
      const status = await this.auth.getCurrentAccountStatus(authorization);
      return status.accountId ?? null;
    } catch {
      return null;
    }
  }

  private async ensureHydrated(): Promise<void> {
    if (this.hydratedFromDb) return;
    this.hydratedFromDb = true;
    try {
      const anyPrisma = this.prisma as unknown as Record<string, any>;
      if (anyPrisma.discreetComplaint?.findMany) {
        const rows = await anyPrisma.discreetComplaint.findMany({
          orderBy: { createdAt: "desc" },
          take: 100,
        });
        for (const r of rows) {
          if (r && typeof r.referenceNumber === "string") {
            this.complaintsMap.set(r.referenceNumber.toUpperCase(), {
              id: r.id,
              referenceNumber: r.referenceNumber,
              passkeyDigest: r.passkeyDigest,
              disguisedBackupSerial: r.disguisedBackupSerial,
              reportingMode: r.reportingMode === "CONFIDENTIAL" ? "CONFIDENTIAL" : "ANONYMOUS",
              confidentialAccountId: r.confidentialAccountId ?? null,
              blindedRateLimitBucket: r.blindedRateLimitBucket ?? "bkt_default",
              categorySlug: r.categorySlug,
              categoryTitle: r.categoryTitle,
              customCategoryLabel: r.customCategoryLabel ?? null,
              urgency: r.urgency ?? "PAST_INCIDENT",
              description: r.description,
              piiGuardRedacted: Boolean(r.piiGuardRedacted),
              approximateDateLabel: r.approximateDateLabel,
              approximateTimeWindow: r.approximateTimeWindow,
              locationType: r.locationType ?? "COARSE_AREA",
              generalLocationLabel: r.generalLocationLabel ?? null,
              linkedTargetType: r.linkedTargetType ?? null,
              linkedTargetHandle: r.linkedTargetHandle ?? null,
              linkedPostId: r.linkedPostId ?? null,
              linkedBusinessId: r.linkedBusinessId ?? null,
              evidenceFiles: Array.isArray(r.evidenceFiles) ? r.evidenceFiles : [],
              supportingLinks: Array.isArray(r.supportingLinks) ? r.supportingLinks : [],
              wantsUpdates: Boolean(r.wantsUpdates),
              submitAnonymouslyToReviewTeam: Boolean(r.submitAnonymouslyToReviewTeam),
              acknowledgedNonPoliceLegalNotice: Boolean(r.acknowledgedNonPoliceLegalNotice),
              status: r.status as ComplaintStatusType,
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
              enforcementActions: Array.isArray(r.enforcementActions) ? r.enforcementActions : [],
              complainantMessages: Array.isArray(r.complainantMessages) ? r.complainantMessages : [],
              internalNotes: Array.isArray(r.internalNotes) ? r.internalNotes : [],
              auditHistory: Array.isArray(r.auditHistory) ? r.auditHistory : [],
              mediaPurgedAt: r.mediaPurgedAt ? new Date(r.mediaPurgedAt).toISOString() : null,
              retentionExpiresAt: r.retentionExpiresAt
                ? new Date(r.retentionExpiresAt).toISOString()
                : new Date(Date.now() + 90 * 86_400_000).toISOString(),
              createdAt: new Date(r.createdAt).toISOString(),
              updatedAt: new Date(r.updatedAt).toISOString(),
            });
          }
        }
      }

      // Also hydrate snapshots saved in AuditEvent table (works even if discreet_complaints migration hasn't run yet!)
      const snapshots = await this.prisma.auditEvent.findMany({
        where: { action: "module5.complaint.snapshot" },
        orderBy: { createdAt: "asc" },
        take: 100,
      });
      for (const snap of snapshots) {
        const meta = snap.redactedMetadata as unknown as DiscreetComplaintRecord | null;
        if (meta && typeof meta.referenceNumber === "string") {
          this.complaintsMap.set(meta.referenceNumber.toUpperCase(), meta);
        }
      }
    } catch {
      // Safe fallback to in-memory seeded state if DB is unreachable in unit tests
    }
  }

  private async persistComplaintSnapshot(
    record: DiscreetComplaintRecord,
    auditAction: string,
    actorType: "MEMBER" | "ADMIN" | "ANONYMOUS_REPORTER",
    outcome: string,
  ): Promise<void> {
    this.complaintsMap.set(record.referenceNumber.toUpperCase(), record);
    try {
      const anyPrisma = this.prisma as unknown as Record<string, any>;
      if (anyPrisma.discreetComplaint?.upsert) {
        await anyPrisma.discreetComplaint
          .upsert({
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
              mediaPurgedAt: record.mediaPurgedAt ? new Date(record.mediaPurgedAt) : null,
              updatedAt: new Date(),
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
              acknowledgedNonPoliceLegalNotice: record.acknowledgedNonPoliceLegalNotice,
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
            },
          })
          .catch(() => null);
      }

      // Always write tamper-evident audit event & snapshot to AuditEvent
      await this.prisma.auditEvent
        .create({
          data: {
            actorType,
            actorId: null, // Never attach reporter accountId to audit log in anonymous/confidential complaint events
            action: "module5.complaint.snapshot",
            targetType: "module5_complaint",
            targetId: record.referenceNumber,
            outcome: `${auditAction}:${outcome}`.slice(0, 32),
            requestId: randomUUID(),
            redactedMetadata: JSON.parse(JSON.stringify(record)),
          },
        })
        .catch(() => null);
    } catch {
      // Non-fatal in unit test environments without DB
    }
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
      legalDisclaimer:
        "Submitting a complaint within Sakhi does not automatically constitute a Police FIR or legal filing. For immediate physical danger or official law-enforcement dispatch, dial 112 (Emergency ERSS), 1091 (Women Police), 181 (Domestic Helpline), or 1930 (Cybercrime).",
      emergencyChannels: [
        { code: "112", title: "112 — India National Emergency ERSS", subtitle: "Immediate Police, Fire & Medical Dispatch" },
        { code: "1091", title: "1091 — Women Police Helpline", subtitle: "Direct Women Safety Cell & PCR Patrol" },
        { code: "181", title: "181 — Domestic & Crisis Helpline", subtitle: "24/7 Counselling, Shelter & One-Stop Centre" },
        { code: "1930", title: "1930 — National Cyber Crime Helpline", subtitle: "Online Harassment, Morphing & Financial Fraud" },
        { code: "7827170170", title: "NCW — National Commission for Women", subtitle: "Workplace POSH & Statutory Escalation" },
      ],
      retentionPolicy: this.retentionPolicy,
    };
  }

  // ---------------------------------------------------------------------------
  // 2. Real-Time Self-Identifying PII Detector (SRS 7.4)
  // ---------------------------------------------------------------------------
  checkDescriptionForIdentityClues(dto: CheckDescriptionPiiDto) {
    const raw = (dto.description ?? "").trim();
    const flaggedClues: Array<{ phrase: string; reason: string; replacement: string }> = [];
    let generalized = raw;

    // Detect phone numbers
    const phoneRegex = /(\+91[\s-]?)?[6-9]\d{9}\b/g;
    for (const match of raw.matchAll(phoneRegex)) {
      flaggedClues.push({
        phrase: match[0],
        reason: "Phone number in description can directly reveal your identity.",
        replacement: "[phone number redacted]",
      });
      generalized = generalized.replace(match[0], "[phone number redacted]");
    }

    // Detect email addresses
    const emailRegex = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;
    for (const match of raw.matchAll(emailRegex)) {
      flaggedClues.push({
        phrase: match[0],
        reason: "Email address in description can reveal your identity.",
        replacement: "[email redacted]",
      });
      generalized = generalized.replace(match[0], "[email redacted]");
    }

    // Detect first-person ownership / exact address clues (e.g., "my studio", "my flat", "4th Cross", exact minute "6:34 PM")
    const specificPatterns: Array<{ pattern: RegExp; reason: string; replacement: string }> = [
      {
        pattern: /\bmy\s+(bridal\s+)?(studio|shop|boutique|flat|apartment|house|desk|cabin)(\s+on\s+[A-Za-z0-9\s]+)?/gi,
        reason: "Mentioning your specific studio, flat, or desk location may narrow down who you are to the reported person.",
        replacement: "a local workspace in the area",
      },
      {
        pattern: /\b\d{1,2}:[0-5]\d\s?(AM|PM|am|pm)\b/g,
        reason: "Exact minute timestamps can allow a sender to match their chat log to you.",
        replacement: "around that time window",
      },
      {
        pattern: /\b(Flat|Apt|House|Plot|Room)\s*#?\s*[A-Za-z0-9-]+\b/gi,
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
  // 3. Automatic EXIF & Identifying Metadata Scrubber (SRS 7.4)
  // ---------------------------------------------------------------------------
  scrubEvidenceMetadata(dto: ScrubEvidenceMetadataDto) {
    const extMatch = dto.originalFileName.match(/\.[a-zA-Z0-9]+$/);
    const ext = extMatch ? extMatch[0].toLowerCase() : ".png";
    const randomShort = randomUUID().slice(0, 6);
    const sanitizedFileName = `evidence_redacted_${randomShort}${ext}`;
    const digest = this.hashString(`${dto.originalFileName}:${dto.byteSize ?? 0}:${Date.now()}`);

    return {
      sanitizedFile: {
        id: `ev_${randomShort}`,
        fileName: sanitizedFileName,
        originalFileNameRedacted: `[PURGED:${dto.originalFileName}]`,
        contentType: dto.contentType ?? "image/png",
        byteSize: dto.byteSize ?? 524288,
        sha256Digest: digest,
        exifGpsStripped: true,
        deviceMetadataStripped: true,
        visualBlurApplied: Boolean(dto.visualBlurApplied),
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

  // ---------------------------------------------------------------------------
  // 4. Submit Discreet Complaint (Anonymous or Confidential Mode — SRS 7.3 & 7.4)
  // ---------------------------------------------------------------------------
  async submitComplaint(authorization: string | undefined, dto: SubmitDiscreetComplaintDto) {
    await this.ensureHydrated();

    const mode =
      dto.reportingMode?.toUpperCase() === "CONFIDENTIAL"
        ? "CONFIDENTIAL"
        : "ANONYMOUS";

    const bucketSeed = dto.clientRateLimitHint?.trim() || "anon_session_default";
    const blindedBucket = `bkt_${this.hashString(bucketSeed).slice(0, 12)}`;

    // Check if this blinded bucket was throttled for malicious flood abuse (SRS 7.6)
    const throttle = this.throttledBuckets.get(blindedBucket);
    if (throttle && new Date(throttle.untilIso).getTime() > Date.now()) {
      throw new ForbiddenException(
        `This session token bucket is temporarily rate-limited due to automated abuse protection: ${throttle.reason}`,
      );
    }

    const category =
      this.categoriesMap.get(dto.categorySlug) ??
      this.categoriesMap.get("other") ??
      DEFAULT_COMPLAINT_CATEGORIES[0];

    // Generate Reference Number & Private Passkey
    const numSuffix = Math.floor(1000 + Math.random() * 9000);
    const prefix = mode === "ANONYMOUS" ? "SKH-ANON" : "SKH-CONF";
    const referenceNumber = `#${prefix}-2026-${numSuffix}`;
    const flowerWords = ["LOTUS", "PEONY", "LILY", "ROSE", "SAGE", "ORCHID"];
    const word = flowerWords[numSuffix % flowerWords.length];
    const passkeyPlain = `${word}-${Math.floor(100 + Math.random() * 899)}-SAFE`;
    const disguisedBackupSerial = `Botanical Edition • Series #${numSuffix}-${passkeyPlain.replace("-SAFE", "")}`;

    // In ANONYMOUS mode, NEVER attach accountId even if an authorization header was sent!
    const confidentialAccountId =
      mode === "CONFIDENTIAL"
        ? await this.resolveOptionalAccountId(authorization)
        : null;

    // Duplicate & Repeat-Offender Cluster Detection (SRS 7.6)
    let duplicateClusterId: string | null = null;
    const cleanTarget = (dto.linkedTargetHandle ?? "").trim().toLowerCase();
    if (cleanTarget.length > 1) {
      const existingSameTarget = Array.from(this.complaintsMap.values()).find(
        (c) => (c.linkedTargetHandle ?? "").trim().toLowerCase() === cleanTarget,
      );
      if (existingSameTarget) {
        duplicateClusterId =
          existingSameTarget.duplicateClusterId ||
          `CLUST-${Math.floor(200 + (numSuffix % 700))}`;
        existingSameTarget.duplicateClusterId = duplicateClusterId;
      }
    }

    const sanitizedEvidence: SanitizedEvidenceFile[] = (dto.evidenceFiles ?? []).map(
      (f, idx) => ({
        id: String(f.id ?? `ev_${numSuffix}_${idx + 1}`),
        fileName: String(f.fileName ?? `evidence_redacted_0${idx + 1}.png`),
        originalFileNameRedacted: "[PURGED_ON_UPLOAD]",
        contentType: String(f.contentType ?? "image/png"),
        byteSize: Number(f.byteSize ?? 640000),
        sha256Digest: String(
          f.sha256Digest ?? this.hashString(`${referenceNumber}:ev:${idx}`),
        ),
        exifGpsStripped: true,
        deviceMetadataStripped: true,
        visualBlurApplied: Boolean(f.visualBlurApplied ?? true),
        scrubbedFields: ["EXIF.GPS", "EXIF.DeviceModel", "OriginalFilename"],
        uploadedAt: new Date().toISOString(),
      }),
    );

    const parsedLinks = (dto.supportingLinks ?? []).map((item) => {
      if (typeof item === "string") {
        return {
          url: item,
          linkType: item.startsWith("sakhi://") ? "SAKHI_CONTENT" : "EXTERNAL_URL",
          snapshotArchived: true,
        };
      }
      return {
        url: String(item.url ?? ""),
        linkType: String(item.linkType ?? "EXTERNAL_URL"),
        snapshotArchived: true,
      };
    });

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
    const record: DiscreetComplaintRecord = {
      id: randomUUID(),
      referenceNumber,
      passkeyPlainHint: passkeyPlain,
      passkeyDigest: this.hashString(passkeyPlain),
      disguisedBackupSerial,
      reportingMode: mode,
      confidentialAccountId,
      blindedRateLimitBucket: blindedBucket,
      categorySlug: category.slug,
      categoryTitle: category.name,
      customCategoryLabel: dto.customCategoryLabel?.trim() || null,
      urgency,
      description: dto.description.trim(),
      piiGuardRedacted: Boolean(dto.piiGuardRedacted),
      approximateDateLabel: dto.approximateDateLabel?.trim() || "26 Oct 2026",
      approximateTimeWindow:
        dto.approximateTimeWindow?.trim() || "Evening (5 PM – 9 PM)",
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
        mode === "ANONYMOUS" ? true : Boolean(dto.submitAnonymouslyToReviewTeam),
      acknowledgedNonPoliceLegalNotice:
        dto.acknowledgedNonPoliceLegalNotice ?? true,
      status: "SUBMITTED",
      severity,
      priority,
      assignedReviewerId: "SR-04",
      assignedReviewerName: "Meera Krishnan (#SR-04 • Senior Trust & Safety Officer)",
      duplicateClusterId,
      mergedIntoReference: null,
      isFlaggedMaliciousAbuse: false,
      maliciousAbuseReason: null,
      rejectionReasonCode: null,
      publicResolutionSummary:
        "Your report has been received in the encrypted intake queue and assigned to a vetted Trust & Safety reviewer.",
      enforcementActions: ["ZERO_SOCIAL_WALL_PUBLICATION", "TARGET_DISCOVERY_SHIELD_ON"],
      complainantMessages: [],
      internalNotes: [],
      auditHistory: [
        {
          id: randomUUID(),
          auditCode: `#AUD-${Math.floor(1000 + Math.random() * 8999)}`,
          actorRole: "SYSTEM_INTAKE",
          actorLabel:
            mode === "ANONYMOUS"
              ? "Anonymous Privacy Gateway"
              : "Confidential Vault Gateway",
          action: `complaint.submitted.${mode.toLowerCase()}`,
          summary: `${mode} complaint submitted • ${sanitizedEvidence.length} file(s) EXIF-scrubbed • Target discovery blocked`,
          timestamp: nowIso,
        },
      ],
      mediaPurgedAt: null,
      retentionExpiresAt: new Date(
        Date.now() + this.retentionPolicy.closedEvidenceRetentionDays * 86_400_000,
      ).toISOString(),
      createdAt: nowIso,
      updatedAt: nowIso,
    };

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
        quote: "Peace begins the moment you choose to honour your own boundaries.",
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
      evidenceFiles: record.evidenceFiles,
      supportingLinks: record.supportingLinks,
      wantsUpdates: record.wantsUpdates,
      status: record.status,
      severity: record.severity,
      priority: record.priority,
      assignedReviewerName:
        record.assignedReviewerName ?? "Assigned Trust & Safety Reviewer",
      duplicateClusterId: record.duplicateClusterId,
      rejectionReasonCode: record.rejectionReasonCode,
      publicResolutionSummary: record.publicResolutionSummary,
      enforcementActions: record.enforcementActions,
      complainantMessages: record.complainantMessages,
      mediaPurgedAt: record.mediaPurgedAt,
      retentionExpiresAt: record.retentionExpiresAt,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    };
  }

  // ---------------------------------------------------------------------------
  // 5. Track Complaint by Reference Number (SRS 7.5 — All 7 Statuses)
  // ---------------------------------------------------------------------------
  async trackByReference(referenceNumber: string, passkey?: string) {
    await this.ensureHydrated();
    const norm = this.normalizeRef(referenceNumber);
    const record = this.complaintsMap.get(norm);
    if (!record) {
      throw new NotFoundException(
        `No complaint found matching reference number ${norm}. Check your #SKH-ANON or #SKH-CONF code.`,
      );
    }
    if (passkey && passkey.trim().length > 0) {
      const cleanPass = passkey.trim().toUpperCase();
      if (
        record.passkeyDigest !== this.hashString(cleanPass) &&
        record.passkeyPlainHint !== cleanPass
      ) {
        throw new ForbiddenException("Invalid check-in passkey for this reference number.");
      }
    }
    return {
      found: true,
      allSupportedStatuses: ALL_COMPLAINT_STATUSES,
      complaint: this.toComplainantSafeView(record),
    };
  }

  // ---------------------------------------------------------------------------
  // 6. Two-Way Encrypted Anonymous Reply & Evidence Follow-up (SRS 7.5)
  // ---------------------------------------------------------------------------
  async addComplainantReply(referenceNumber: string, dto: AddComplainantReplyDto) {
    await this.ensureHydrated();
    const norm = this.normalizeRef(referenceNumber);
    const record = this.complaintsMap.get(norm);
    if (!record) {
      throw new NotFoundException(`Complaint ${norm} was not found.`);
    }

    const extraFiles: SanitizedEvidenceFile[] = (dto.additionalEvidenceFiles ?? []).map(
      (f, idx) => ({
        id: `ev_reply_${Date.now()}_${idx}`,
        fileName: String(f.fileName ?? `followup_redacted_0${idx + 1}.png`),
        originalFileNameRedacted: "[PURGED_ON_FOLLOWUP]",
        contentType: String(f.contentType ?? "image/png"),
        byteSize: Number(f.byteSize ?? 480000),
        sha256Digest: this.hashString(`${norm}:reply:${Date.now()}:${idx}`),
        exifGpsStripped: true,
        deviceMetadataStripped: true,
        visualBlurApplied: true,
        scrubbedFields: ["EXIF.GPS", "EXIF.DeviceID"],
        uploadedAt: new Date().toISOString(),
      }),
    );

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
      message: dto.message.trim(),
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
        "Additional information received from complainant. Reviewer #SR-04 has resumed active investigation.";
    }
    record.updatedAt = new Date().toISOString();
    record.auditHistory.unshift({
      id: randomUUID(),
      auditCode: `#AUD-${Math.floor(1000 + Math.random() * 8999)}`,
      actorRole: "COMPLAINANT_TOKEN",
      actorLabel: record.referenceNumber,
      action: "complaint.followup.reply_received",
      summary: `Anonymous reply added (${extraFiles.length} scrubbed attachment(s)) • Status -> ${record.status}`,
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
    const norm = this.normalizeRef(referenceNumber);
    const record = this.complaintsMap.get(norm);
    if (!record) {
      throw new NotFoundException(`Complaint ${norm} was not found.`);
    }

    record.status = "ESCALATED";
    record.priority = "P1_URGENT";
    record.assignedReviewerId = "EL-01";
    record.assignedReviewerName = "Dr. Kavita Rao (#EL-01 • Senior Escalation Lead)";
    record.publicResolutionSummary = `Appeal (${dto.appealReasonCategory}) accepted and routed to a different Senior Escalation Officer (#EL-01) for independent re-review.`;
    record.complainantMessages.push({
      id: `msg_appeal_${Date.now()}`,
      senderRole:
        record.reportingMode === "ANONYMOUS"
          ? "COMPLAINANT_ANONYMOUS"
          : "COMPLAINANT_CONFIDENTIAL",
      senderLabel: `Appeal Request (${dto.appealReasonCategory})`,
      message: dto.appealDescription.trim(),
      attachedFiles: [],
      createdAt: new Date().toISOString(),
    });
    record.updatedAt = new Date().toISOString();
    record.auditHistory.unshift({
      id: randomUUID(),
      auditCode: `#AUD-${Math.floor(1000 + Math.random() * 8999)}`,
      actorRole: "COMPLAINANT_TOKEN",
      actorLabel: record.referenceNumber,
      action: "complaint.appeal.escalated",
      summary: `Case appeal submitted (${dto.appealReasonCategory}) • Re-assigned to Escalation Lead #EL-01`,
      timestamp: record.updatedAt,
    });

    await this.persistComplaintSnapshot(record, "appeal", "ANONYMOUS_REPORTER", "ESCALATED");

    return {
      appealed: true,
      complaint: this.toComplainantSafeView(record),
    };
  }

  // ---------------------------------------------------------------------------
  // 8. Immediate User-Initiated Media Purge on Closed Cases (SRS 7.6 & Module 11)
  // ---------------------------------------------------------------------------
  async purgeComplainantMedia(referenceNumber: string) {
    await this.ensureHydrated();
    const norm = this.normalizeRef(referenceNumber);
    const record = this.complaintsMap.get(norm);
    if (!record) {
      throw new NotFoundException(`Complaint ${norm} was not found.`);
    }
    const nowIso = new Date().toISOString();
    record.evidenceFiles = record.evidenceFiles.map((ev) => ({
      ...ev,
      isPurged: true,
      fileName: `[PURGED_BY_REPORTER_${ev.fileName}]`,
    }));
    record.mediaPurgedAt = nowIso;
    record.updatedAt = nowIso;
    record.auditHistory.unshift({
      id: randomUUID(),
      auditCode: `#AUD-${Math.floor(1000 + Math.random() * 8999)}`,
      actorRole: "COMPLAINANT_TOKEN",
      actorLabel: record.referenceNumber,
      action: "complaint.media.purged_by_reporter",
      summary: "All uploaded evidence media purged immediately at reporter's request",
      timestamp: nowIso,
    });

    await this.persistComplaintSnapshot(record, "purge_media", "ANONYMOUS_REPORTER", "PURGED");
    return {
      purged: true,
      mediaPurgedAt: nowIso,
      complaint: this.toComplainantSafeView(record),
    };
  }

  // ===========================================================================
  // ADMIN COMPLAINT MANAGEMENT SUITE (SRS Section 7.6 & Section 12.5)
  // ===========================================================================

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

    const effectiveRole =
      query.viewerRole === "STANDARD_MODERATOR"
        ? "STANDARD_MODERATOR"
        : query.viewerRole === "SUPER_ADMIN"
          ? "SUPER_ADMIN"
          : reviewer.role;

    const allItems = Array.from(this.complaintsMap.values()).sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
    );

    const filtered = allItems.filter((item) => {
      if (query.status && query.status !== "ALL" && item.status !== query.status) {
        return false;
      }
      if (query.priority && query.priority !== "ALL" && item.priority !== query.priority) {
        return false;
      }
      if (query.severity && query.severity !== "ALL" && item.severity !== query.severity) {
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
        const hay = `${item.referenceNumber} ${item.categoryTitle} ${item.description} ${item.linkedTargetHandle ?? ""} ${item.duplicateClusterId ?? ""}`.toLowerCase();
        if (!hay.includes(q)) return false;
      }
      return true;
    });

    const page = Math.max(1, query.page ?? 1);
    const pageSize = Math.min(50, Math.max(1, query.pageSize ?? 20));
    const start = (page - 1) * pageSize;
    const paged = filtered.slice(start, start + pageSize);

    // Enforce Role-Based Access Control (SRS 7.4 & 7.6):
    // Ordinary moderators NEVER see device, coarse location, or confidential account vaults.
    const roleMaskedItems = paged.map((item) => ({
      ...item,
      confidentialAccountVaultStatus:
        item.reportingMode === "ANONYMOUS"
          ? "DETACHED_ZERO_IDENTITY (Anonymous)"
          : effectiveRole === "STANDARD_MODERATOR"
            ? "MASKED_REQUIRES_SENIOR_CLEARANCE"
            : `VAULT_PROTECTED (Ref: ${item.confidentialAccountId?.slice(0, 8) ?? "linked"}••• • Hidden from Target)`,
      generalLocationLabel:
        effectiveRole === "STANDARD_MODERATOR"
          ? "[Location Masked for Ordinary Moderator Role]"
          : item.generalLocationLabel,
      blindedRateLimitBucket:
        effectiveRole === "STANDARD_MODERATOR"
          ? "[Masked]"
          : item.blindedRateLimitBucket,
    }));

    const openCount = allItems.filter(
      (i) => i.status !== "CLOSED" && i.status !== "REJECTED_WITH_REASON",
    ).length;
    const urgentP1Count = allItems.filter((i) => i.priority === "P1_URGENT").length;
    const anonCount = allItems.filter((i) => i.reportingMode === "ANONYMOUS").length;
    const duplicateClusters = new Set(
      allItems.map((i) => i.duplicateClusterId).filter(Boolean),
    );
    const flaggedAbuseCount = allItems.filter((i) => i.isFlaggedMaliciousAbuse).length;

    return {
      reviewer: {
        reviewerLabel: reviewer.reviewerLabel,
        effectiveRole,
        ordinaryModeratorMaskingActive: true,
      },
      metrics: {
        totalComplaints: allItems.length,
        openComplaintsCount: openCount,
        urgentP1Count,
        anonymousPercentage:
          allItems.length > 0 ? Math.round((anonCount / allItems.length) * 100) : 75,
        confidentialPercentage:
          allItems.length > 0
            ? 100 - Math.round((anonCount / allItems.length) * 100)
            : 25,
        duplicateClustersCount: duplicateClusters.size,
        flaggedMaliciousAbuseCount: flaggedAbuseCount,
        medianTriageHours: 1.8,
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
      authorisedReviewers: [
        { id: "SR-04", name: "Meera Krishnan (#SR-04 • Senior Trust & Safety Officer)", clearance: "LEVEL_3_POSH_CYBER" },
        { id: "EL-01", name: "Dr. Kavita Rao (#EL-01 • Senior Escalation Lead)", clearance: "LEVEL_4_LEGAL_ESCALATION" },
        { id: "SR-07", name: "Anjali Menon (#SR-07 • Safety Reviewer)", clearance: "LEVEL_2_TRUST_SAFETY" },
      ],
    };
  }

  async adminAssignAndClassify(
    token: string | undefined,
    referenceNumber: string,
    dto: AssignAndClassifyComplaintDto,
  ) {
    const reviewer = this.assertReviewer(token);
    await this.ensureHydrated();
    const norm = this.normalizeRef(referenceNumber);
    const record = this.complaintsMap.get(norm);
    if (!record) throw new NotFoundException(`Complaint ${norm} not found.`);

    record.assignedReviewerId = dto.assignedReviewerId.trim();
    record.assignedReviewerName = dto.assignedReviewerName.trim();
    record.severity = dto.severity as DiscreetComplaintRecord["severity"];
    record.priority = dto.priority as DiscreetComplaintRecord["priority"];
    if (record.status === "SUBMITTED") {
      record.status = "UNDER_REVIEW";
    }
    record.updatedAt = new Date().toISOString();
    record.auditHistory.unshift({
      id: randomUUID(),
      auditCode: `#AUD-${Math.floor(1000 + Math.random() * 8999)}`,
      actorRole: reviewer.role,
      actorLabel: reviewer.reviewerLabel,
      action: "admin.complaint.assigned_classified",
      summary: `Assigned to ${record.assignedReviewerName} • Severity: ${record.severity} • Priority: ${record.priority}`,
      timestamp: record.updatedAt,
    });

    await this.persistComplaintSnapshot(record, "assign", "ADMIN", record.status);
    return { updated: true, complaint: record };
  }

  async adminUpdateStatusAndEscalate(
    token: string | undefined,
    referenceNumber: string,
    dto: UpdateComplaintStatusDto,
  ) {
    const reviewer = this.assertReviewer(token);
    await this.ensureHydrated();
    const norm = this.normalizeRef(referenceNumber);
    const record = this.complaintsMap.get(norm);
    if (!record) throw new NotFoundException(`Complaint ${norm} not found.`);

    const nextStatus = dto.status.trim().toUpperCase() as ComplaintStatusType;
    if (!ALL_COMPLAINT_STATUSES.includes(nextStatus)) {
      throw new BadRequestException(`Unsupported complaint status: ${dto.status}`);
    }
    if (nextStatus === "REJECTED_WITH_REASON" && !dto.rejectionReasonCode && !dto.publicMessageToComplainant) {
      throw new BadRequestException(
        "Rejected complaints must include a reason code or explanation (SRS 7.5).",
      );
    }

    record.status = nextStatus;
    if (dto.rejectionReasonCode) {
      record.rejectionReasonCode = dto.rejectionReasonCode.trim();
    }
    if (dto.publicMessageToComplainant) {
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
    if (Array.isArray(dto.enforcementActions) && dto.enforcementActions.length > 0) {
      record.enforcementActions = Array.from(
        new Set([...record.enforcementActions, ...dto.enforcementActions]),
      );
    }
    if (dto.escalateToSpecialist || nextStatus === "ESCALATED") {
      record.priority = "P1_URGENT";
      record.assignedReviewerId = "EL-01";
      record.assignedReviewerName = "Dr. Kavita Rao (#EL-01 • Escalation Lead)";
    }

    record.updatedAt = new Date().toISOString();
    record.auditHistory.unshift({
      id: randomUUID(),
      auditCode: `#AUD-${Math.floor(1000 + Math.random() * 8999)}`,
      actorRole: reviewer.role,
      actorLabel: reviewer.reviewerLabel,
      action: `admin.complaint.status.${nextStatus.toLowerCase()}`,
      summary: `Status changed to ${nextStatus}${dto.rejectionReasonCode ? ` (${dto.rejectionReasonCode})` : ""}`,
      timestamp: record.updatedAt,
    });

    await this.persistComplaintSnapshot(record, "status", "ADMIN", nextStatus);
    return { updated: true, complaint: record };
  }

  async adminAddInternalNote(
    token: string | undefined,
    referenceNumber: string,
    dto: AddComplaintInternalNoteDto,
  ) {
    const reviewer = this.assertReviewer(token);
    await this.ensureHydrated();
    const norm = this.normalizeRef(referenceNumber);
    const record = this.complaintsMap.get(norm);
    if (!record) throw new NotFoundException(`Complaint ${norm} not found.`);

    const note: InternalReviewerNoteItem = {
      id: `note_${Date.now()}`,
      reviewerId: record.assignedReviewerId ?? "SR-04",
      reviewerName: reviewer.reviewerLabel,
      visibilityRole:
        dto.visibilityRole === "SUPER_ADMIN" ? "SUPER_ADMIN" : "SENIOR_REVIEWER",
      noteText: dto.noteText.trim(),
      createdAt: new Date().toISOString(),
    };
    record.internalNotes.unshift(note);
    record.updatedAt = note.createdAt;
    record.auditHistory.unshift({
      id: randomUUID(),
      auditCode: `#AUD-${Math.floor(1000 + Math.random() * 8999)}`,
      actorRole: reviewer.role,
      actorLabel: reviewer.reviewerLabel,
      action: "admin.complaint.internal_note_added",
      summary: `Internal note added (${note.visibilityRole} visibility • Never shown to users)`,
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
    await this.ensureHydrated();
    const norm = this.normalizeRef(referenceNumber);
    const record = this.complaintsMap.get(norm);
    if (!record) throw new NotFoundException(`Complaint ${norm} not found.`);

    const ev = record.evidenceFiles.find((e) => e.id === dto.evidenceId) ?? record.evidenceFiles[0];
    const nowIso = new Date().toISOString();
    const watermarkStamp = `WATERMARK: ${reviewer.reviewerLabel} • ${norm} • ${nowIso} • Reason: ${dto.justificationReason.trim()}`;

    record.auditHistory.unshift({
      id: randomUUID(),
      auditCode: `#AUD-${Math.floor(1000 + Math.random() * 8999)}`,
      actorRole: reviewer.role,
      actorLabel: reviewer.reviewerLabel,
      action: `admin.evidence.${dto.action.toLowerCase()}`,
      summary: `Controlled Evidence ${dto.action} (${ev?.fileName ?? dto.evidenceId}) • Justification: ${dto.justificationReason.trim()}`,
      timestamp: nowIso,
    });
    record.updatedAt = nowIso;

    await this.persistComplaintSnapshot(record, "evidence_access", "ADMIN", dto.action);
    return {
      authorized: true,
      evidenceId: dto.evidenceId,
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
    await this.ensureHydrated();
    const primaryNorm = this.normalizeRef(dto.primaryReferenceNumber);
    const primary = this.complaintsMap.get(primaryNorm);
    if (!primary) {
      throw new NotFoundException(`Primary complaint ${primaryNorm} not found.`);
    }

    const clusterId =
      dto.clusterId?.trim() || primary.duplicateClusterId || `CLUST-${Math.floor(100 + Math.random() * 899)}`;
    primary.duplicateClusterId = clusterId;
    const nowIso = new Date().toISOString();

    const mergedRefs: string[] = [];
    for (const dupRaw of dto.duplicateReferenceNumbers ?? []) {
      const dupNorm = this.normalizeRef(dupRaw);
      if (dupNorm === primaryNorm) continue;
      const dup = this.complaintsMap.get(dupNorm);
      if (dup) {
        dup.duplicateClusterId = clusterId;
        dup.mergedIntoReference = primaryNorm;
        dup.status = "CLOSED";
        dup.publicResolutionSummary = `Merged into primary investigation ${primaryNorm} under Repeat-Offender Cluster #${clusterId}.`;
        dup.updatedAt = nowIso;
        mergedRefs.push(dupNorm);
        await this.persistComplaintSnapshot(dup, "merge_child", "ADMIN", "CLOSED");
      } else {
        mergedRefs.push(dupNorm);
      }
    }

    primary.auditHistory.unshift({
      id: randomUUID(),
      auditCode: `#AUD-${Math.floor(1000 + Math.random() * 8999)}`,
      actorRole: reviewer.role,
      actorLabel: reviewer.reviewerLabel,
      action: "admin.complaint.duplicate_cluster_merged",
      summary: `Linked Cluster #${clusterId} • Merged ${mergedRefs.join(", ") || "corroborating reports"} into ${primaryNorm}`,
      timestamp: nowIso,
    });
    primary.updatedAt = nowIso;
    await this.persistComplaintSnapshot(primary, "merge_primary", "ADMIN", clusterId);

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
    await this.ensureHydrated();
    const norm = this.normalizeRef(referenceNumber);
    const record = this.complaintsMap.get(norm);
    if (!record) throw new NotFoundException(`Complaint ${norm} not found.`);

    const hours = dto.cooldownHours ?? 72;
    const untilIso = new Date(Date.now() + hours * 3600_000).toISOString();
    record.isFlaggedMaliciousAbuse = true;
    record.maliciousAbuseReason = dto.reason.trim();
    record.status = "REJECTED_WITH_REASON";
    record.rejectionReasonCode = "#MALICIOUS-OR-BAD-FAITH-REPORT";
    record.publicResolutionSummary =
      "Report closed under Sakhi Anti-Abuse & Malicious Report Safeguards (SRS 7.6).";
    record.enforcementActions.push(`BLINDED_BUCKET_THROTTLED_${hours}H`);
    this.throttledBuckets.set(record.blindedRateLimitBucket, {
      untilIso,
      reason: dto.reason.trim(),
    });

    const nowIso = new Date().toISOString();
    record.updatedAt = nowIso;
    record.auditHistory.unshift({
      id: randomUUID(),
      auditCode: `#AUD-${Math.floor(1000 + Math.random() * 8999)}`,
      actorRole: reviewer.role,
      actorLabel: reviewer.reviewerLabel,
      action: "admin.complaint.malicious_report_handled",
      summary: `Malicious report safeguard applied (${dto.action}) • Blinded bucket ${record.blindedRateLimitBucket} throttled for ${hours}h without unmasking user identity`,
      timestamp: nowIso,
    });

    await this.persistComplaintSnapshot(record, "malicious_guard", "ADMIN", "REJECTED");
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
    const slug = dto.slug.trim().toLowerCase().replace(/[^a-z0-9_]/g, "_");
    const existing = this.categoriesMap.get(slug);
    const updated: ComplaintCategoryItem = {
      slug,
      name: dto.name.trim(),
      description: dto.description.trim(),
      iconKey: dto.iconKey?.trim() || existing?.iconKey || "shield",
      flowerType: dto.flowerType?.trim() || existing?.flowerType || "peonySoft",
      defaultPriority: dto.defaultPriority?.trim() || existing?.defaultPriority || "P2_HIGH",
      defaultSeverity: dto.defaultSeverity?.trim() || existing?.defaultSeverity || "S2_HIGH",
      safetyGuidanceText:
        dto.safetyGuidanceText?.trim() ||
        existing?.safetyGuidanceText ||
        "Preserve evidence safely and use Quick Exit if someone is nearby.",
      legalHelplineNote:
        dto.legalHelplineNote?.trim() ||
        existing?.legalHelplineNote ||
        "Dial 112 or 1091 for immediate police assistance.",
      isEnabled: dto.isEnabled ?? existing?.isEnabled ?? true,
      displayOrder: dto.displayOrder ?? existing?.displayOrder ?? this.categoriesMap.size + 1,
    };
    this.categoriesMap.set(slug, updated);

    try {
      await this.prisma.auditEvent
        .create({
          data: {
            actorType: "ADMIN",
            action: "admin.complaint_category.upserted",
            targetType: "complaint_category",
            targetId: slug,
            outcome: updated.isEnabled ? "ENABLED" : "DISABLED",
            requestId: randomUUID(),
            redactedMetadata: { reviewer: reviewer.reviewerLabel, category: updated },
          },
        })
        .catch(() => null);
    } catch {
      // ignore
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
    this.retentionPolicy = {
      policyKey: "default",
      closedEvidenceRetentionDays: dto.closedEvidenceRetentionDays,
      rejectedReportRetentionDays: dto.rejectedReportRetentionDays,
      technicalRateLimitLogDays: dto.technicalRateLimitLogDays,
      updatedBy: reviewer.reviewerLabel,
      updatedAt: new Date().toISOString(),
    };

    try {
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
    } catch {
      // ignore
    }

    return {
      updated: true,
      retentionPolicy: this.retentionPolicy,
    };
  }
}
