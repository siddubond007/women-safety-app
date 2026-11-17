import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  HttpException,
  NotFoundException,
  ServiceUnavailableException,
  UnauthorizedException,
} from "@nestjs/common";
import {
  createHash,
  createHmac,
  randomBytes,
  randomInt,
  randomUUID,
  timingSafeEqual,
} from "node:crypto";
import type { PrismaService } from "../database/prisma.service.js";

export type SakhiAdminRole =
  | "SUPER_ADMIN"
  | "VERIFICATION_ADMIN"
  | "CONTENT_MODERATOR"
  | "COMPLAINT_REVIEWER"
  | "SOS_SAFETY_ADMIN"
  | "BUSINESS_ADMIN"
  | "READ_ONLY_AUDITOR";

export interface GranularRolePermissions {
  view: boolean;
  create: boolean;
  edit: boolean;
  approve: boolean;
  suspend: boolean;
  export: boolean;
  delete: boolean;
}

export interface AdminRoleDefinition {
  role: SakhiAdminRole;
  title: string;
  badgeLabel: string;
  description: string;
  allowedRoutes: string[];
  defaultPermissions: GranularRolePermissions;
  defaultClearanceLevel: string;
  canAccessDiscreetComplaints: boolean;
  canManageCategoriesAndRetention: boolean;
  privacyBoundaries: string[];
}

export const ADMIN_ROLE_DEFINITIONS: Record<
  SakhiAdminRole,
  AdminRoleDefinition
> = {
  SUPER_ADMIN: {
    role: "SUPER_ADMIN",
    title: "Super Admin (Master Governance)",
    badgeLabel: "Super Admin",
    description:
      "Full governance across all platform modules, RBAC staff creation, global feature flags, DPDP retention policies, system health, and global audit logs.",
    allowedRoutes: [
      "/dashboard",
      "/action-center",
      "/members",
      "/verification",
      "/verifications",
      "/moderation",
      "/complaints",
      "/emergency",
      "/community",
      "/businesses",
      "/wellness",
      "/admin-users",
      "/audit-security",
      "/integrations",
      "/settings",
    ],
    defaultPermissions: {
      view: true,
      create: true,
      edit: true,
      approve: true,
      suspend: true,
      export: true,
      delete: true,
    },
    defaultClearanceLevel: "LEVEL_4_MASTER_GOVERNANCE",
    canAccessDiscreetComplaints: true,
    canManageCategoriesAndRetention: true,
    privacyBoundaries: [
      "Blocked from raw 12-digit Aadhaar numbers & OTPs (SRS 12.2)",
      "Blocked from individual menstrual cycle & private wellness logs (SRS 8.2 & 12.2)",
    ],
  },
  VERIFICATION_ADMIN: {
    role: "VERIFICATION_ADMIN",
    title: "Verification & User Support Admin",
    badgeLabel: "Role 1 • Verification Admin",
    description:
      "Reviews pending female eligibility submissions, manages member account states (Active, Restricted, Suspended), and resolves onboarding support requests.",
    allowedRoutes: [
      "/dashboard",
      "/verification",
      "/verifications",
      "/members",
      "/test-access",
    ],
    defaultPermissions: {
      view: true,
      create: false,
      edit: true,
      approve: true,
      suspend: true,
      export: false,
      delete: false,
    },
    defaultClearanceLevel: "LEVEL_2_ELIGIBILITY_SUPPORT",
    canAccessDiscreetComplaints: false,
    canManageCategoriesAndRetention: false,
    privacyBoundaries: [
      "Blocked from Discreet & Anonymous Complaints (SRS 7.4)",
      "Blocked from SOS live location logs & Community post moderation",
      "Blocked from raw Aadhaar numbers & private menstrual health data",
    ],
  },
  CONTENT_MODERATOR: {
    role: "CONTENT_MODERATOR",
    title: "Community, Content & Wellness Moderator",
    badgeLabel: "Role 2 • Content Moderator",
    description:
      "Moderates reported community posts, comments, groups, and manages non-diagnostic wellness educational articles and FAQs.",
    allowedRoutes: ["/dashboard", "/moderation", "/community", "/wellness"],
    defaultPermissions: {
      view: true,
      create: true,
      edit: true,
      approve: true,
      suspend: true,
      export: false,
      delete: true,
    },
    defaultClearanceLevel: "LEVEL_1_COMMUNITY_MODERATION",
    canAccessDiscreetComplaints: false,
    canManageCategoriesAndRetention: false,
    privacyBoundaries: [
      "Strictly blocked from Discreet & Anonymous Complaints (SRS 7.4)",
      "Blocked from Member Eligibility Verification Queue & SOS Console",
      "Blocked from individual user menstrual/wellness logs",
    ],
  },
  COMPLAINT_REVIEWER: {
    role: "COMPLAINT_REVIEWER",
    title: "Authorised Complaint Reviewer (Case Officer)",
    badgeLabel: "Role 3 • Complaint Reviewer",
    description:
      "Authorised safety officer for Anonymous (#SKH-ANON) and Confidential (#SKH-CONF) complaints, two-way encrypted replies, controlled evidence vault, and duplicate cluster merges.",
    allowedRoutes: ["/dashboard", "/complaints"],
    defaultPermissions: {
      view: true,
      create: true,
      edit: true,
      approve: true,
      suspend: true,
      export: true,
      delete: false,
    },
    defaultClearanceLevel: "LEVEL_3_POSH_CYBER_SAFETY",
    canAccessDiscreetComplaints: true,
    canManageCategoriesAndRetention: false,
    privacyBoundaries: [
      "Cannot unmask Anonymous (#SKH-ANON) reporters (zero account ID stored)",
      "Every evidence reveal or watermarked export requires a logged justification",
      "Cannot alter global DPDP retention policies or create admin accounts",
    ],
  },
  SOS_SAFETY_ADMIN: {
    role: "SOS_SAFETY_ADMIN",
    title: "SOS & Emergency Safety Admin",
    badgeLabel: "Role 4 • SOS Safety Admin",
    description:
      "Manages the Verified Police Station Directory, 112/Emergency helpline rules, SOS delivery diagnostics, and false-trigger/abuse reports.",
    allowedRoutes: ["/dashboard", "/emergency"],
    defaultPermissions: {
      view: true,
      create: true,
      edit: true,
      approve: true,
      suspend: false,
      export: true,
      delete: false,
    },
    defaultClearanceLevel: "LEVEL_3_EMERGENCY_OPERATIONS",
    canAccessDiscreetComplaints: false,
    canManageCategoriesAndRetention: false,
    privacyBoundaries: [
      "Blocked from Discreet & Anonymous Complaints",
      "Blocked from Community DMs, Eligibility Verification docs & Wellness logs",
    ],
  },
  BUSINESS_ADMIN: {
    role: "BUSINESS_ADMIN",
    title: "Business & Marketplace Admin",
    badgeLabel: "Role 5 • Business Admin",
    description:
      "Reviews women-owned business directory listings, optional business verification badges, reported fraudulent business pages, and featured placements.",
    allowedRoutes: ["/dashboard", "/businesses"],
    defaultPermissions: {
      view: true,
      create: true,
      edit: true,
      approve: true,
      suspend: true,
      export: false,
      delete: false,
    },
    defaultClearanceLevel: "LEVEL_2_MARKETPLACE_TRUST",
    canAccessDiscreetComplaints: false,
    canManageCategoriesAndRetention: false,
    privacyBoundaries: [
      "Blocked from Eligibility Verification docs, SOS logs & Wellness data",
      "Blocked from Discreet Complaints unless explicitly granted Complaint Reviewer clearance",
    ],
  },
  READ_ONLY_AUDITOR: {
    role: "READ_ONLY_AUDITOR",
    title: "Read-only Security Auditor",
    badgeLabel: "Role 6 • Read-only Auditor",
    description:
      "Reviews redacted administrative audit records and security events. Cannot mutate platform data, manage staff, export evidence, or access raw complaint evidence and member health records.",
    allowedRoutes: ["/dashboard", "/audit-security"],
    defaultPermissions: {
      view: true,
      create: false,
      edit: false,
      approve: false,
      suspend: false,
      export: false,
      delete: false,
    },
    defaultClearanceLevel: "LEVEL_1_AUDIT_ONLY",
    canAccessDiscreetComplaints: false,
    canManageCategoriesAndRetention: false,
    privacyBoundaries: [
      "Read-only access to redacted administrative audit metadata only",
      "No raw complaint evidence, evidence export, member health records, secrets, or session credentials",
      "All mutation and staff-governance operations are denied",
    ],
  },
};

export interface AdminStaffRecord {
  id: string;
  staffCode: string;
  username?: string | null;
  fullName: string;
  email: string;
  role: SakhiAdminRole;
  status: "ACTIVE" | "SUSPENDED" | "REVOKED";
  mustResetPassword?: boolean;
  accessTokenDigest: string;
  accessTokenPreview: string;
  isAuthorisedComplaintReviewer: boolean;
  clearanceLevel: string;
  permissions: GranularRolePermissions;
  allowedRoutes: string[];
  createdBy: string;
  lastLoginAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface AuthenticatedAdminPrincipal {
  staffId: string;
  staffCode: string;
  reviewerLabel: string;
  fullName: string;
  email: string;
  role: SakhiAdminRole;
  roleTitle: string;
  badgeLabel: string;
  clearanceLevel: string;
  isAuthorisedComplaintReviewer: boolean;
  permissions: GranularRolePermissions;
  allowedRoutes: string[];
}

export interface BusinessListingRecord {
  id: string;
  businessCode: string;
  businessName: string;
  ownerAccountId: string | null;
  ownerDisplayName: string;
  category: string;
  city: string;
  serviceArea?: string | null;
  priceRange?: string | null;
  description: string;
  logoAsset?: string | null;
  coverImage?: string | null;
  mediaGallery?: string[];
  businessHours?: Record<string, any> | null;
  contactPhone: string | null;
  hidePhoneNumber?: boolean;
  whatsappNumber?: string | null;
  instagramHandle?: string | null;
  websiteOrInstagram: string | null;
  productsServices?: Array<Record<string, any>>;
  offersAndPosts?: Array<Record<string, any>>;
  enquiriesCount?: number;
  viewsCount?: number;
  approvalStatus: "PENDING_APPROVAL" | "APPROVED" | "SUSPENDED" | "REJECTED";
  verificationBadgeStatus:
    "NONE" | "PENDING_BADGE" | "VERIFIED_WOMAN_OWNED" | "REVOKED";
  isFeatured: boolean;
  isReportedFraudulent: boolean;
  reportReason: string | null;
  reviewedBy: string | null;
  reviewNotes: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface PlatformConfigRecord {
  configKey: string;
  featureFlags: {
    communityFeedEnabled: boolean;
    businessDirectoryEnabled: boolean;
    wellnessTrackerEnabled: boolean;
    anonymousComplaintsEnabled: boolean;
    sosLiveShareEnabled: boolean;
    decentroDigilockerEnabled: boolean;
    directMessagingEnabled?: boolean;
    manualVerificationFallbackEnabled?: boolean;
  };
  mediaUploadLimits: {
    maxPostImageMb: number;
    maxVideoUploadMb?: number;
    maxVideoDurationSeconds?: number;
    maxComplaintEvidenceMb: number;
    maxFilesPerComplaint: number;
    allowedFormats: string[];
    feedCategories?: string[];
    policyDocuments?: {
      termsVersion: string;
      privacyPolicyVersion: string;
      communityGuidelines: string;
      medicalLegalDisclaimer: string;
    };
    notificationTemplates?: {
      wellnessDiscreetDefault: string;
      complaintStatusUpdate: string;
      sosEmergencySms: string;
    };
    retentionPolicies?: {
      verificationRetentionDays: number;
      closedComplaintRetentionDays: number;
      messagesRetentionDays: number;
      deletedAccountPurgeDays: number;
    };
  };
  businessCategories: string[];
  announcementBanner: string;
  updatedBy: string;
  updatedAt: string;
}

function sha256Hex(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

/**
 * Shared singleton registry backed by PostgreSQL. Staff accounts and platform
 * config retain AuditEvent snapshot fallback; Module 6 business listings require
 * a successful write to the primary business directory table.
 */
export class SakhiAdminRbacRegistry {
  private static readonly staffMap = new Map<string, AdminStaffRecord>();
  private static readonly businessMap = new Map<
    string,
    BusinessListingRecord
  >();
  private static platformConfig: PlatformConfigRecord = {
    configKey: "default",
    featureFlags: {
      communityFeedEnabled: true,
      businessDirectoryEnabled: true,
      wellnessTrackerEnabled: true,
      anonymousComplaintsEnabled: true,
      sosLiveShareEnabled: true,
      decentroDigilockerEnabled: true,
      directMessagingEnabled: true,
      manualVerificationFallbackEnabled: true,
    },
    mediaUploadLimits: {
      maxPostImageMb: 10,
      maxVideoUploadMb: 50,
      maxVideoDurationSeconds: 120,
      maxComplaintEvidenceMb: 15,
      maxFilesPerComplaint: 5,
      allowedFormats: ["PNG", "JPEG", "WEBP", "PDF", "M4A", "MP3", "WAV"],
      feedCategories: [
        "Following",
        "Community",
        "Trending",
        "Business Updates",
        "Safety Awareness",
        "Wellness and Lifestyle",
      ],
      policyDocuments: {
        termsVersion: "v2.4 (DPDP Act 2023 & IT Rules Compliant)",
        privacyPolicyVersion:
          "v2.4 (Zero Raw Aadhaar/OTP & Encrypted Health Data)",
        communityGuidelines:
          "Zero tolerance for harassment, doxxing, hate speech, or non-consensual media.",
        medicalLegalDisclaimer:
          "In-app wellness content is non-diagnostic educational guidance; in-app complaints do not replace a Police FIR or 112 call.",
      },
      notificationTemplates: {
        wellnessDiscreetDefault:
          "Sakhi Daily Mindfulness: Your personal calendar reminder is ready.",
        complaintStatusUpdate:
          "Sakhi Personal Note: You have a new update in your private vault.",
        sosEmergencySms:
          "URGENT SAKHI SOS: {memberName} needs emergency assistance. Live location: {trackingUrl} | Dial 112.",
      },
      retentionPolicies: {
        verificationRetentionDays: 30,
        closedComplaintRetentionDays: 90,
        messagesRetentionDays: 180,
        deletedAccountPurgeDays: 30,
      },
    },
    businessCategories: [
      "Fashion and clothing",
      "Beauty and personal care",
      "Food and catering",
      "Health and fitness",
      "Education and training",
      "Home services",
      "Professional consulting",
      "Art and handicrafts",
      "Retail and ecommerce",
      "Events and photography",
      "Freelancers and independent professionals",
      "Other",
    ],
    announcementBanner:
      "Sakhi Women Safety & Community Sanctuary — Verified, Encrypted & DPDP Act 2023 Compliant.",
    updatedBy: "Sakhi Super Admin",
    updatedAt: new Date().toISOString(),
  };
  private static hydrated = false;
  private static hydrationPromise: Promise<void> | null = null;

  static resetForTesting(): void {
    this.staffMap.clear();
    this.businessMap.clear();
    this.hydrated = false;
    this.hydrationPromise = null;
  }

  static getSuperAdminPrincipal(
    customLabel?: string,
  ): AuthenticatedAdminPrincipal {
    const def = ADMIN_ROLE_DEFINITIONS.SUPER_ADMIN;
    const label = customLabel?.trim() || "Sakhi Super Admin";
    return {
      staffId: "SUPER-ADMIN-MASTER",
      staffCode: "#SA-01",
      reviewerLabel: `${label} (#SA-01)`,
      fullName: label,
      email: "superadmin@sakhi.org.in",
      role: "SUPER_ADMIN",
      roleTitle: def.title,
      badgeLabel: def.badgeLabel,
      clearanceLevel: def.defaultClearanceLevel,
      isAuthorisedComplaintReviewer: true,
      permissions: { ...def.defaultPermissions },
      allowedRoutes: [...def.allowedRoutes],
    };
  }

  static principalFromStaff(
    staff: AdminStaffRecord,
  ): AuthenticatedAdminPrincipal {
    const def = ADMIN_ROLE_DEFINITIONS[staff.role];
    if (!def) {
      throw new UnauthorizedException("The stored staff role is not recognized; access is denied.");
    }
    return {
      staffId: staff.id,
      staffCode: staff.staffCode,
      reviewerLabel: `${staff.fullName} (${staff.staffCode} • ${def.badgeLabel})`,
      fullName: staff.fullName,
      email: staff.email,
      role: staff.role,
      roleTitle: def.title,
      badgeLabel: def.badgeLabel,
      clearanceLevel: staff.clearanceLevel || def.defaultClearanceLevel,
      isAuthorisedComplaintReviewer:
        staff.role === "SUPER_ADMIN" ||
        staff.role === "COMPLAINT_REVIEWER" ||
        staff.isAuthorisedComplaintReviewer,
      permissions: { ...def.defaultPermissions, ...staff.permissions },
      allowedRoutes:
        Array.isArray(staff.allowedRoutes) && staff.allowedRoutes.length > 0
          ? staff.allowedRoutes
          : [...def.allowedRoutes],
    };
  }

  static createSignedStaffSessionToken(
    staff: AdminStaffRecord,
    secretKey: string,
    sessionId = randomUUID(),
    expiresAtSec = Math.floor(Date.now() / 1000) + 8 * 3600,
  ): { value: string; expiresAt: Date; sessionId: string } {
    const decodedKey = Buffer.from(secretKey, "base64");
    if (decodedKey.length !== 32 || decodedKey.toString("base64") !== secretKey) {
      throw new ServiceUnavailableException(
        "A dedicated base64-encoded 32-byte staff-session signing key is required.",
      );
    }
    const payload = `staff-admin.${staff.id}.${sessionId}.${expiresAtSec}`;
    const sig = createHmac("sha256", decodedKey)
      .update(`sakhi-staff-session:${payload}`)
      .digest("base64url");
    return {
      value: `${payload}.${sig}`,
      expiresAt: new Date(expiresAtSec * 1000),
      sessionId,
    };
  }

  static verifySignedStaffSessionToken(
    token: string,
    secretKey: string,
  ): AdminStaffRecord | null {
    const decodedKey = Buffer.from(secretKey, "base64");
    if (decodedKey.length !== 32 || decodedKey.toString("base64") !== secretKey) return null;
    if (!token.startsWith("staff-admin.")) return null;
    const parts = token.split(".");
    if (parts.length !== 5) return null;
    const staffId = parts[1] ?? "";
    const sessionId = parts[2] ?? "";
    const expiresAtSec = Number(parts[3] ?? "0");
    const sig = parts[4] ?? "";
    if (
      !staffId ||
      !/^[0-9a-f-]{36}$/i.test(sessionId) ||
      !Number.isSafeInteger(expiresAtSec)
    )
      return null;
    if (expiresAtSec <= Math.floor(Date.now() / 1000)) return null;

    const payload = `staff-admin.${staffId}.${sessionId}.${expiresAtSec}`;
    const expected = createHmac("sha256", decodedKey)
      .update(`sakhi-staff-session:${payload}`)
      .digest();
    const supplied = Buffer.from(sig, "base64url");
    if (
      supplied.length !== expected.length ||
      !timingSafeEqual(supplied, expected)
    ) {
      return null;
    }
    const staff = this.staffMap.get(staffId);
    if (!staff || staff.status !== "ACTIVE") return null;
    return staff;
  }

  /**
   * Rebuild the staff cache from the authoritative database table. Unlike the
   * legacy hydration fallback, this never resurrects deleted accounts from
   * audit snapshots. Used at bootstrap boundaries after out-of-band staging
   * account resets and before the initial account is created.
   */
  static async reloadStaffRegistryFromDatabase(
    prisma: PrismaService,
  ): Promise<void> {
    const anyPrisma = prisma as unknown as Record<string, any>;
    if (!anyPrisma.adminStaffAccount?.findMany) {
      throw new ServiceUnavailableException(
        "The authoritative admin staff account table is required for bootstrap.",
      );
    }
    this.staffMap.clear();
    this.hydrated = false;
    this.hydrationPromise = null;
    await this.ensureHydrated(prisma);
  }

  static async ensureHydrated(prisma: PrismaService): Promise<void> {
    if (this.hydrated) return;
    if (this.hydrationPromise) return this.hydrationPromise;
    const pending = this.hydrateRegistry(prisma);
    this.hydrationPromise = pending;
    try {
      await pending;
      this.hydrated = true;
    } finally {
      if (this.hydrationPromise === pending) this.hydrationPromise = null;
    }
  }

  private static async hydrateRegistry(prisma: PrismaService): Promise<void> {
    const anyPrisma = prisma as unknown as Record<string, any>;

    try {
      // 1. Load AdminStaffAccount rows from primary table if migrated
      let loadedStaffFromTable = false;
      if (anyPrisma.adminStaffAccount?.findMany) {
        const rows = await anyPrisma.adminStaffAccount
          .findMany({ orderBy: { createdAt: "asc" } })
          .catch(() => null);
        if (Array.isArray(rows)) {
          loadedStaffFromTable = true;
          for (const r of rows) {
            const mapped = this.mapDbRowToStaff(r);
            this.staffMap.set(mapped.id, mapped);
          }
        }
      }

      // Audit snapshots are a legacy fallback only when the staff table is
      // unavailable. An existing but empty staff table is authoritative: in
      // particular, never resurrect accounts intentionally removed during a
      // staging reset from historical audit metadata.
      if (!loadedStaffFromTable && prisma.auditEvent?.findMany) {
        const snaps = await prisma.auditEvent
          .findMany({
            where: { action: "module10.admin_staff.snapshot" },
            orderBy: { createdAt: "asc" },
            take: 200,
          })
          .catch(() => []);
        for (const s of snaps) {
          const meta = s.redactedMetadata as Record<string, any> | null;
          if (meta && typeof meta.id === "string") {
            if (meta.deleted === true) {
              this.staffMap.delete(meta.id);
            } else {
              const mapped = this.mapDbRowToStaff(meta);
              this.staffMap.set(mapped.id, mapped);
            }
          }
        }
      }

      // 2. Load BusinessDirectoryListing rows
      let loadedBizFromTable = false;
      if (anyPrisma.businessDirectoryListing?.findMany) {
        const bizRows = await anyPrisma.businessDirectoryListing
          .findMany({ orderBy: { createdAt: "desc" } })
          .catch(() => null);
        if (Array.isArray(bizRows)) {
          loadedBizFromTable = true;
          for (const b of bizRows) {
            const mapped = this.mapDbRowToBusiness(b);
            this.businessMap.set(mapped.id, mapped);
          }
        }
      }
      if (!loadedBizFromTable && prisma.auditEvent?.findMany) {
        const snaps = await prisma.auditEvent
          .findMany({
            where: { action: "module10.business_listing.snapshot" },
            orderBy: { createdAt: "asc" },
            take: 200,
          })
          .catch(() => []);
        for (const s of snaps) {
          const meta = s.redactedMetadata as Record<string, any> | null;
          if (meta && typeof meta.id === "string") {
            const mapped = this.mapDbRowToBusiness(meta);
            this.businessMap.set(mapped.id, mapped);
          }
        }
      }

      // 3. Load PlatformConfigSetting
      if (anyPrisma.platformConfigSetting?.findUnique) {
        const cfg = await anyPrisma.platformConfigSetting
          .findUnique({ where: { configKey: "default" } })
          .catch(() => null);
        if (cfg) {
          this.platformConfig = {
            configKey: "default",
            featureFlags: {
              ...this.platformConfig.featureFlags,
              ...(typeof cfg.featureFlags === "object" && cfg.featureFlags
                ? cfg.featureFlags
                : {}),
            },
            mediaUploadLimits: {
              ...this.platformConfig.mediaUploadLimits,
              ...(typeof cfg.mediaUploadLimits === "object" &&
              cfg.mediaUploadLimits
                ? cfg.mediaUploadLimits
                : {}),
            },
            businessCategories: Array.isArray(cfg.businessCategories)
              ? cfg.businessCategories
              : this.platformConfig.businessCategories,
            announcementBanner:
              cfg.announcementBanner ?? this.platformConfig.announcementBanner,
            updatedBy: cfg.updatedBy ?? "Sakhi Super Admin",
            updatedAt: cfg.updatedAt
              ? new Date(cfg.updatedAt).toISOString()
              : new Date().toISOString(),
          };
        }
      }
    } catch (error) {
      this.staffMap.clear();
      if (process.env.NODE_ENV !== "test") {
        throw new ServiceUnavailableException(
          "Admin staff records could not be loaded and validated. Privileged access is denied.",
        );
      }
    }
  }

  private static mapDbRowToStaff(r: Record<string, any>): AdminStaffRecord {
    if (typeof r.role !== "string" || !Object.prototype.hasOwnProperty.call(ADMIN_ROLE_DEFINITIONS, r.role)) {
      throw new UnauthorizedException("The stored staff role is not recognized; access is denied.");
    }
    const role = r.role as SakhiAdminRole;
    const def = ADMIN_ROLE_DEFINITIONS[role];
    if (r.status !== "ACTIVE" && r.status !== "SUSPENDED" && r.status !== "REVOKED") {
      throw new UnauthorizedException("The stored staff account status is invalid; access is denied.");
    }
    if (!r.permissions || typeof r.permissions !== "object" || Array.isArray(r.permissions)) {
      throw new UnauthorizedException("Stored staff permissions are malformed; access is denied.");
    }
    const rawPerms = r.permissions as Record<string, unknown>;
    const permissionKeys = ["view", "create", "edit", "approve", "suspend", "export", "delete"] as const;
    for (const key of permissionKeys) {
      if (rawPerms[key] !== undefined && typeof rawPerms[key] !== "boolean") {
        throw new UnauthorizedException(`Stored staff permission ${key} is not a boolean; access is denied.`);
      }
    }
    if (r.isAuthorisedComplaintReviewer !== undefined && typeof r.isAuthorisedComplaintReviewer !== "boolean") {
      throw new UnauthorizedException("Stored complaint-reviewer authorization is invalid; access is denied.");
    }
    const allowedRoutes = Array.isArray(rawPerms.allowedRoutes)
      ? rawPerms.allowedRoutes
      : Array.isArray(r.allowedRoutes)
        ? r.allowedRoutes
        : [...def.allowedRoutes];

    return {
      id: String(r.id),
      staffCode: String(r.staffCode ?? "#ADM-101"),
      username: r.username == null ? null : String(r.username),
      fullName: String(r.fullName ?? "Sakhi Admin"),
      email: String(r.email ?? "admin@sakhi.org.in"),
      role,
      status: r.status,
      // Every staff account must establish a password before ordinary
      // credential sign-in. This also repairs legacy passwordless staff rows.
      mustResetPassword: Boolean(r.mustResetPassword) || r.passwordHash === null,
      accessTokenDigest: String(r.accessTokenDigest ?? ""),
      accessTokenPreview: String(r.accessTokenPreview ?? "SAKHI-STAFF-••••"),
      isAuthorisedComplaintReviewer:
        role === "SUPER_ADMIN" ||
        role === "COMPLAINT_REVIEWER" ||
        Boolean(r.isAuthorisedComplaintReviewer),
      clearanceLevel: String(r.clearanceLevel ?? def.defaultClearanceLevel),
      permissions: {
        view: rawPerms.view === undefined ? def.defaultPermissions.view : rawPerms.view as boolean,
        create: rawPerms.create === undefined ? def.defaultPermissions.create : rawPerms.create as boolean,
        edit: rawPerms.edit === undefined ? def.defaultPermissions.edit : rawPerms.edit as boolean,
        approve: rawPerms.approve === undefined ? def.defaultPermissions.approve : rawPerms.approve as boolean,
        suspend: rawPerms.suspend === undefined ? def.defaultPermissions.suspend : rawPerms.suspend as boolean,
        export: rawPerms.export === undefined ? def.defaultPermissions.export : rawPerms.export as boolean,
        delete: rawPerms.delete === undefined ? def.defaultPermissions.delete : rawPerms.delete as boolean,
      },
      allowedRoutes,
      createdBy: String(r.createdBy ?? "Sakhi Super Admin"),
      lastLoginAt: r.lastLoginAt ? new Date(r.lastLoginAt).toISOString() : null,
      createdAt: r.createdAt
        ? new Date(r.createdAt).toISOString()
        : new Date().toISOString(),
      updatedAt: r.updatedAt
        ? new Date(r.updatedAt).toISOString()
        : new Date().toISOString(),
    };
  }

  private static mapDbRowToBusiness(
    b: Record<string, any>,
  ): BusinessListingRecord {
    return {
      id: String(b.id),
      businessCode: String(b.businessCode ?? "#BIZ-101"),
      businessName: String(b.businessName ?? "Women-Owned Business"),
      ownerAccountId: b.ownerAccountId ? String(b.ownerAccountId) : null,
      ownerDisplayName: String(b.ownerDisplayName ?? "Verified Sakhi Member"),
      category: String(b.category ?? "Fashion and clothing"),
      city: String(b.city ?? "Bengaluru"),
      serviceArea: b.serviceArea
        ? String(b.serviceArea)
        : String(b.city ?? "Bengaluru"),
      priceRange: b.priceRange ? String(b.priceRange) : "₹500 – ₹2,500",
      description: String(b.description ?? ""),
      logoAsset: b.logoAsset ? String(b.logoAsset) : null,
      coverImage: b.coverImage ? String(b.coverImage) : null,
      mediaGallery: Array.isArray(b.mediaGallery)
        ? b.mediaGallery.map((x: unknown) => String(x))
        : [],
      businessHours:
        b.businessHours && typeof b.businessHours === "object"
          ? b.businessHours
          : null,
      contactPhone: b.contactPhone ? String(b.contactPhone) : null,
      hidePhoneNumber: Boolean(b.hidePhoneNumber),
      whatsappNumber: b.whatsappNumber ? String(b.whatsappNumber) : null,
      instagramHandle: b.instagramHandle ? String(b.instagramHandle) : null,
      websiteOrInstagram: b.websiteOrInstagram
        ? String(b.websiteOrInstagram)
        : null,
      productsServices: Array.isArray(b.productsServices)
        ? b.productsServices
        : [],
      offersAndPosts: Array.isArray(b.offersAndPosts) ? b.offersAndPosts : [],
      enquiriesCount: Number(b.enquiriesCount ?? 0),
      viewsCount: Number(b.viewsCount ?? 0),
      approvalStatus:
        b.approvalStatus === "APPROVED" ||
        b.approvalStatus === "SUSPENDED" ||
        b.approvalStatus === "REJECTED"
          ? b.approvalStatus
          : "PENDING_APPROVAL",
      verificationBadgeStatus:
        b.verificationBadgeStatus === "PENDING_BADGE" ||
        b.verificationBadgeStatus === "VERIFIED_WOMAN_OWNED" ||
        b.verificationBadgeStatus === "REVOKED"
          ? b.verificationBadgeStatus
          : "NONE",
      isFeatured: Boolean(b.isFeatured),
      isReportedFraudulent: Boolean(b.isReportedFraudulent),
      reportReason: b.reportReason ? String(b.reportReason) : null,
      reviewedBy: b.reviewedBy ? String(b.reviewedBy) : null,
      reviewNotes: b.reviewNotes ? String(b.reviewNotes) : null,
      createdAt: b.createdAt
        ? new Date(b.createdAt).toISOString()
        : new Date().toISOString(),
      updatedAt: b.updatedAt
        ? new Date(b.updatedAt).toISOString()
        : new Date().toISOString(),
    };
  }

  static refreshStaffRecordFromDatabase(
    row: Record<string, unknown>,
  ): AdminStaffRecord {
    const mapped = this.mapDbRowToStaff(row);
    this.staffMap.set(mapped.id, mapped);
    return mapped;
  }

  static findStaffByToken(
    rawToken: string,
    signingSecret?: string,
  ): AdminStaffRecord | null {
    const clean = rawToken.trim();
    if (!clean) return null;
    if (clean.startsWith("staff-admin.")) {
      return signingSecret
        ? this.verifySignedStaffSessionToken(clean, signingSecret)
        : null;
    }
    const digest = sha256Hex(clean);
    const digestBuf = Buffer.from(digest, "hex");
    for (const staff of this.staffMap.values()) {
      if (staff.status !== "ACTIVE" || !staff.accessTokenDigest) continue;
      const expectedBuf = Buffer.from(staff.accessTokenDigest, "hex");
      if (
        expectedBuf.length === digestBuf.length &&
        timingSafeEqual(expectedBuf, digestBuf)
      ) {
        return staff;
      }
    }
    return null;
  }

  static listStaff(): AdminStaffRecord[] {
    return Array.from(this.staffMap.values()).sort(
      (a, b) =>
        new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
    );
  }

  /**
   * Returns ONLY real database-backed Authorised Complaint Reviewers plus the
   * Master Super Admin account. Never returns hardcoded fake reviewers.
   */
  static listAuthorisedComplaintReviewers(): Array<{
    id: string;
    staffCode: string;
    name: string;
    role: SakhiAdminRole;
    clearance: string;
    email: string;
  }> {
    const activeReviewerStaff = Array.from(this.staffMap.values()).filter(
      (s) =>
        s.status === "ACTIVE" &&
        (s.role === "COMPLAINT_REVIEWER" ||
          s.role === "SUPER_ADMIN" ||
          s.isAuthorisedComplaintReviewer),
    );

    const results = activeReviewerStaff.map((s) => ({
      id: s.staffCode,
      staffCode: s.staffCode,
      name: `${s.fullName} (${s.staffCode} • ${ADMIN_ROLE_DEFINITIONS[s.role].badgeLabel})`,
      role: s.role,
      clearance: s.clearanceLevel,
      email: s.email,
    }));

    return results;
  }

  static async createStaffAccount(
    prisma: PrismaService,
    dto: {
      fullName: string;
      email: string;
      role: string;
      customAccessToken?: string;
      isAuthorisedComplaintReviewer?: boolean;
      clearanceLevel?: string;
      permissions?: Partial<GranularRolePermissions>;
      mustResetPassword?: boolean;
      username?: string;
      initialPasswordHash?: string;
    },
    createdByLabel: string,
    actorStaffId?: string,
    staffId?: string,
    transactionClient?: unknown,
  ): Promise<{ staff: AdminStaffRecord; issuedAccessToken: string }> {
    await this.ensureHydrated(prisma);

    const fullName = (dto.fullName ?? "").trim();
    if (
      fullName.length < 3 ||
      fullName.length > 120 ||
      /^\d+$/.test(fullName)
    ) {
      throw new BadRequestException(
        "Admin full name must be between 3 and 120 characters and cannot be numbers only.",
      );
    }
    const email = (dto.email ?? "").trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      throw new BadRequestException("Provide a valid admin email address.");
    }
    const duplicateEmail = Array.from(this.staffMap.values()).find(
      (s) => s.email.toLowerCase() === email && s.status !== "REVOKED",
    );
    if (duplicateEmail) {
      throw new BadRequestException(
        `An active admin staff account with email "${email}" already exists (${duplicateEmail.staffCode}).`,
      );
    }

    const rawRole = (dto.role ?? "").trim().toUpperCase() as SakhiAdminRole;
    if (!(rawRole in ADMIN_ROLE_DEFINITIONS)) {
      throw new BadRequestException(
        `Invalid admin role "${dto.role}". Valid roles: ${Object.keys(ADMIN_ROLE_DEFINITIONS).join(", ")}`,
      );
    }
    const def = ADMIN_ROLE_DEFINITIONS[rawRole];
    if (dto.isAuthorisedComplaintReviewer !== undefined && typeof dto.isAuthorisedComplaintReviewer !== "boolean") {
      throw new BadRequestException("isAuthorisedComplaintReviewer must be a boolean.");
    }
    if (
      dto.isAuthorisedComplaintReviewer === true &&
      rawRole !== "SUPER_ADMIN" &&
      rawRole !== "COMPLAINT_REVIEWER"
    ) {
      throw new BadRequestException(
        "Only Super Admin or Complaint Reviewer roles may hold complaint-reviewer clearance.",
      );
    }

    const rolePrefixMap: Record<SakhiAdminRole, string> = {
      SUPER_ADMIN: "SA",
      VERIFICATION_ADMIN: "VA",
      CONTENT_MODERATOR: "CM",
      COMPLAINT_REVIEWER: "CR",
      SOS_SAFETY_ADMIN: "SOS",
      BUSINESS_ADMIN: "BA",
      READ_ONLY_AUDITOR: "RO",
    };
    const prefix = rolePrefixMap[rawRole];
    const num = randomInt(100, 999);
    const staffCode = `#${prefix}-${num}`;

    if (dto.customAccessToken !== undefined) {
      throw new BadRequestException("Caller-supplied staff credentials are not accepted; the server generates credentials.");
    }
    const randomPart = randomBytes(32).toString("base64url");
    const issuedAccessToken = `SAKHI-${prefix}-${num}-${randomPart}`;
    const accessTokenDigest = sha256Hex(issuedAccessToken);
    const accessTokenPreview = `${issuedAccessToken.slice(0, 12)}••••${issuedAccessToken.slice(-4)}`;

    const nowIso = new Date().toISOString();
    for (const [key, value] of Object.entries(dto.permissions ?? {})) {
      if (!["view", "create", "edit", "approve", "suspend", "export", "delete"].includes(key) || typeof value !== "boolean") {
        throw new BadRequestException("Staff permissions must contain only recognized boolean permission values.");
      }
    }
    const permissions: GranularRolePermissions = {
      view: dto.permissions?.view ?? def.defaultPermissions.view,
      create: dto.permissions?.create ?? def.defaultPermissions.create,
      edit: dto.permissions?.edit ?? def.defaultPermissions.edit,
      approve: dto.permissions?.approve ?? def.defaultPermissions.approve,
      suspend: dto.permissions?.suspend ?? def.defaultPermissions.suspend,
      export: dto.permissions?.export ?? def.defaultPermissions.export,
      delete: dto.permissions?.delete ?? def.defaultPermissions.delete,
    };

    const staff: AdminStaffRecord = {
      id: staffId ?? randomUUID(),
      staffCode,
      fullName,
      email,
      role: rawRole,
      status: "ACTIVE",
      mustResetPassword: dto.mustResetPassword === true,
      username: dto.username?.trim().toLowerCase() || null,
      accessTokenDigest,
      accessTokenPreview,
      isAuthorisedComplaintReviewer:
        rawRole === "SUPER_ADMIN" ||
        rawRole === "COMPLAINT_REVIEWER" ||
        Boolean(dto.isAuthorisedComplaintReviewer),
      clearanceLevel: dto.clearanceLevel?.trim() || def.defaultClearanceLevel,
      permissions,
      allowedRoutes: [...def.allowedRoutes],
      createdBy: createdByLabel,
      lastLoginAt: null,
      createdAt: nowIso,
      updatedAt: nowIso,
    };

    await this.persistStaffRecord(
      prisma,
      staff,
      "created",
      createdByLabel,
      actorStaffId,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      dto.initialPasswordHash,
      transactionClient,
    );
    return { staff, issuedAccessToken };
  }

  static async updateStaffAccount(
    prisma: PrismaService,
    staffId: string,
    dto: {
      fullName?: string;
      email?: string;
      emailChangeReason?: string;
      role?: string;
      status?: string;
      isAuthorisedComplaintReviewer?: boolean;
      clearanceLevel?: string;
      permissions?: Partial<GranularRolePermissions>;
      regenerateToken?: boolean;
      customAccessToken?: string;
    },
    updatedByLabel: string,
    updatedByStaffId?: string,
  ): Promise<{ staff: AdminStaffRecord; issuedAccessToken?: string }> {
    await this.ensureHydrated(prisma);
    const anyPrisma = prisma as unknown as Record<string, any>;
    const dbRow = anyPrisma.adminStaffAccount?.findUnique
      ? await anyPrisma.adminStaffAccount.findUnique({ where: { id: staffId } })
      : null;
    if (!dbRow && process.env.NODE_ENV !== "test") {
      throw new ServiceUnavailableException("Staff updates require an authoritative database record.");
    }
    const cached = dbRow ? this.mapDbRowToStaff(dbRow) :
      (this.staffMap.get(staffId) ?? Array.from(this.staffMap.values()).find((s) => s.staffCode === staffId));
    if (!cached) {
      throw new NotFoundException(`Admin staff account ${staffId} not found.`);
    }
    const existing = { ...cached, permissions: { ...cached.permissions }, allowedRoutes: [...cached.allowedRoutes] };
    const original: AdminStaffRecord = {
      ...existing,
      permissions: { ...existing.permissions },
      allowedRoutes: [...existing.allowedRoutes],
    };

    if (dto.fullName !== undefined) {
      const cleanName = dto.fullName.trim();
      if (cleanName.length < 3 || /^\d+$/.test(cleanName)) {
        throw new BadRequestException(
          "Admin full name must be at least 3 characters and not numbers only.",
        );
      }
      existing.fullName = cleanName;
    }

    if (dto.email !== undefined) {
      const cleanEmail = dto.email.trim().toLowerCase();
      if (cleanEmail.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(cleanEmail)) {
        throw new BadRequestException("Provide a valid staff email address (maximum 254 characters).");
      }
      if (cleanEmail !== original.email.toLowerCase()) {
        const reason = dto.emailChangeReason?.trim() ?? "";
        if (reason.length < 10 || reason.length > 500) {
          throw new BadRequestException("Provide an email-change reason of 10 to 500 characters.");
        }
        const duplicate = Array.from(this.staffMap.values()).find(
          (staff) => staff.id !== staffId && staff.status !== "REVOKED" && staff.email.toLowerCase() === cleanEmail,
        );
        if (duplicate) {
          throw new ConflictException("That email address is already assigned to another active staff account.");
        }
        existing.email = cleanEmail;
      }
    }

    if (dto.role !== undefined) {
      const nextRole = dto.role.trim().toUpperCase() as SakhiAdminRole;
      if (!(nextRole in ADMIN_ROLE_DEFINITIONS)) {
        throw new BadRequestException(`Invalid admin role "${dto.role}".`);
      }
      existing.role = nextRole;
      const def = ADMIN_ROLE_DEFINITIONS[nextRole];
      existing.allowedRoutes = [...def.allowedRoutes];
      if (!dto.permissions) {
        existing.permissions = { ...def.defaultPermissions };
      }
      existing.isAuthorisedComplaintReviewer =
        nextRole === "SUPER_ADMIN" || nextRole === "COMPLAINT_REVIEWER";
    }

    if (dto.status !== undefined) {
      const nextStatus = dto.status.trim().toUpperCase();
      if (
        nextStatus !== "ACTIVE" &&
        nextStatus !== "SUSPENDED" &&
        nextStatus !== "REVOKED"
      ) {
        throw new BadRequestException(
          'Status must be "ACTIVE", "SUSPENDED", or "REVOKED".',
        );
      }
      if (
        nextStatus === "ACTIVE" &&
        original.status !== "ACTIVE" &&
        dto.regenerateToken !== true
      ) {
        throw new BadRequestException(
          "Reactivating a staff account requires issuing a new access credential.",
        );
      }
      existing.status = nextStatus;
      if (nextStatus !== "ACTIVE" && original.status === "ACTIVE") {
        existing.accessTokenDigest = sha256Hex(randomUUID());
        existing.accessTokenPreview = "REVOKED";
      }
    }

    if (dto.isAuthorisedComplaintReviewer !== undefined) {
      if (typeof dto.isAuthorisedComplaintReviewer !== "boolean") {
        throw new BadRequestException("isAuthorisedComplaintReviewer must be a boolean.");
      }
      const effectiveRole = (dto.role ?? existing.role) as SakhiAdminRole;
      if (
        dto.isAuthorisedComplaintReviewer &&
        effectiveRole !== "SUPER_ADMIN" &&
        effectiveRole !== "COMPLAINT_REVIEWER"
      ) {
        throw new BadRequestException(
          "Only Super Admin or Complaint Reviewer roles may hold complaint-reviewer clearance.",
        );
      }
      existing.isAuthorisedComplaintReviewer = dto.isAuthorisedComplaintReviewer;
    }
    if (dto.clearanceLevel !== undefined && dto.clearanceLevel.trim()) {
      existing.clearanceLevel = dto.clearanceLevel.trim();
    }
    if (dto.permissions) {
      existing.permissions = {
        ...existing.permissions,
        ...dto.permissions,
      };
    }

    let issuedAccessToken: string | undefined;
    if (dto.customAccessToken !== undefined) {
      throw new BadRequestException("Caller-supplied staff credentials are not accepted.");
    }
    if (dto.regenerateToken !== undefined && typeof dto.regenerateToken !== "boolean") {
      throw new BadRequestException("regenerateToken must be a boolean.");
    }
    for (const [key, value] of Object.entries(dto.permissions ?? {})) {
      if (!["view", "create", "edit", "approve", "suspend", "export", "delete"].includes(key) || typeof value !== "boolean") {
        throw new BadRequestException("Staff permissions must contain only recognized boolean permission values.");
      }
    }
    if (dto.regenerateToken === true) {
      const rand = randomBytes(32).toString("base64url");
      issuedAccessToken = `SAKHI-${existing.staffCode.replace("#", "")}-${rand}`;
      existing.accessTokenDigest = sha256Hex(issuedAccessToken);
      existing.accessTokenPreview = `${issuedAccessToken.slice(0, 12)}••••${issuedAccessToken.slice(-4)}`;
    }

    existing.updatedAt = new Date().toISOString();
    try {
      await this.persistStaffRecord(
        prisma,
        existing,
        "updated",
        updatedByLabel,
        updatedByStaffId,
        original.updatedAt,
        original.role,
        original.status,
        original.email,
        dto.emailChangeReason?.trim(),
      );
    } catch (error) {
      this.staffMap.set(existing.id, original);
      throw error;
    }
    return { staff: existing, issuedAccessToken };
  }

  static async deleteStaffAccount(
    prisma: PrismaService,
    staffId: string,
    deletedByLabel: string,
    deletedByStaffId?: string,
  ): Promise<{ deleted: true; staffCode: string }> {
    await this.ensureHydrated(prisma);
    const anyPrisma = prisma as unknown as Record<string, any>;
    const dbRow = anyPrisma.adminStaffAccount?.findUnique
      ? await anyPrisma.adminStaffAccount.findUnique({ where: { id: staffId } })
      : null;
    if (!dbRow && process.env.NODE_ENV !== "test") {
      throw new ServiceUnavailableException("Staff deletion requires an authoritative database record.");
    }
    const existing = dbRow ? this.mapDbRowToStaff(dbRow) :
      (this.staffMap.get(staffId) ?? Array.from(this.staffMap.values()).find((s) => s.staffCode === staffId));
    if (!existing) {
      throw new NotFoundException(`Admin staff account ${staffId} not found.`);
    }

    const now = new Date();
    if (typeof anyPrisma.$transaction !== "function") {
      throw new ServiceUnavailableException(
        "Staff deletion requires transactional database and audit support.",
      );
    }

    try {
      const persist = async (tx: any) => {
        if (existing.role === "SUPER_ADMIN" && existing.status === "ACTIVE") {
          const activeSuperAdmins = await tx.adminStaffAccount.count({
            where: { role: "SUPER_ADMIN", status: "ACTIVE" },
          });
          if (activeSuperAdmins <= 1) {
            throw new ConflictException("The last active Super Admin cannot be deleted or revoked.");
          }
        }
        const updated = await tx.adminStaffAccount.updateMany({
        where: {
          id: existing.id,
          updatedAt: new Date(existing.updatedAt),
          role: existing.role,
          status: existing.status,
        },
        data: {
          status: "REVOKED",
          deletedAt: now,
          deletedBy: deletedByStaffId,
          accessTokenDigest: sha256Hex(randomUUID()),
          accessTokenPreview: "REVOKED",
          updatedAt: now,
        },
      });
      if (updated.count !== 1) {
        throw new ConflictException(
          "The staff account was already revoked or changed.",
        );
      }
      await tx.adminStaffSession.updateMany({
        where: { staffId: existing.id, revokedAt: null },
        data: { revokedAt: now, revokeReason: "STAFF_DELETED" },
      });
      await tx.adminStaffBackupCode.updateMany({
        where: { staffId: existing.id, usedAt: null },
        data: { usedAt: now },
      });
      await tx.adminStaffRecoveryRequest.updateMany({
        where: {
          staffId: existing.id,
          status: { in: ["PENDING", "APPROVED"] },
        },
        data: { status: "CANCELLED" },
      });
      await tx.auditEvent.create({
        data: {
          actorType: "ADMIN",
          actorId: deletedByStaffId,
          action: "admin.staff_account.deleted",
          targetType: "admin_staff_account",
          targetId: existing.id,
          outcome: "success",
          requestId: randomUUID(),
          redactedMetadata: {
            staffCode: existing.staffCode,
            deletedBy: deletedByLabel,
            sessionsRevoked: true,
            backupCodesInvalidated: true,
          },
        },
        });
      }, { isolationLevel: "Serializable" });
    } catch (error) {
      if (error instanceof HttpException) throw error;
      throw new ServiceUnavailableException(
        "Staff deletion, session revocation, backup-code invalidation, and audit logging must commit together. No deletion was accepted.",
      );
    }

    this.staffMap.delete(existing.id);
    return { deleted: true, staffCode: existing.staffCode };
  }

  private static async persistStaffRecord(
    prisma: PrismaService,
    staff: AdminStaffRecord,
    outcome: string,
    actorLabel: string,
    actorStaffId?: string,
    expectedUpdatedAt?: string,
    originalRole?: SakhiAdminRole,
    originalStatus?: AdminStaffRecord["status"],
    originalEmail?: string,
    emailChangeReason?: string,
    initialPasswordHash?: string,
    transactionClient?: unknown,
  ): Promise<void> {
    const anyPrisma = prisma as unknown as Record<string, any>;
    if (typeof anyPrisma.$transaction !== "function") {
      throw new ServiceUnavailableException(
        "Admin staff changes require transactional database and audit support.",
      );
    }

    const safeMetadata = {
      id: staff.id,
      staffCode: staff.staffCode,
      username: staff.username ?? null,
      fullName: staff.fullName,
      email: staff.email,
      role: staff.role,
      status: staff.status,
      mustResetPassword: Boolean(staff.mustResetPassword),
      isAuthorisedComplaintReviewer: staff.isAuthorisedComplaintReviewer,
      clearanceLevel: staff.clearanceLevel,
      permissions: staff.permissions,
      allowedRoutes: staff.allowedRoutes,
      createdBy: staff.createdBy,
      updatedBy: actorLabel,
      lastLoginAt: staff.lastLoginAt,
    };

    try {
      await anyPrisma.$transaction(async (tx: any) => {
        if (
          outcome !== "created" &&
          originalRole === "SUPER_ADMIN" &&
          originalStatus === "ACTIVE" &&
          (staff.role !== "SUPER_ADMIN" || staff.status !== "ACTIVE")
        ) {
          const activeSuperAdmins = await tx.adminStaffAccount.count({
            where: { role: "SUPER_ADMIN", status: "ACTIVE" },
          });
          if (activeSuperAdmins <= 1) {
            throw new ConflictException("The last active Super Admin cannot be demoted, suspended, or revoked.");
          }
        }

        const staffData = {
          username: staff.username ?? null,
          ...(outcome === "created" ? {
            passwordHash: initialPasswordHash ?? null,
            passwordUpdatedAt: initialPasswordHash ? new Date(staff.createdAt) : null,
          } : {}),
          fullName: staff.fullName,
          email: staff.email,
          role: staff.role,
          status: staff.status,
          mustResetPassword: Boolean(staff.mustResetPassword),
          accessTokenDigest: staff.accessTokenDigest,
          accessTokenPreview: staff.accessTokenPreview,
          isAuthorisedComplaintReviewer: staff.isAuthorisedComplaintReviewer,
          clearanceLevel: staff.clearanceLevel,
          permissions: { ...staff.permissions, allowedRoutes: staff.allowedRoutes },
          suspendedAt: staff.status === "SUSPENDED" ? new Date(staff.updatedAt) : null,
          suspendedBy: staff.status === "SUSPENDED" ? actorStaffId : null,
          deletedAt: staff.status === "REVOKED" ? new Date(staff.updatedAt) : null,
          deletedBy: staff.status === "REVOKED" ? actorStaffId : null,
          lastLoginAt: staff.lastLoginAt ? new Date(staff.lastLoginAt) : null,
          updatedAt: new Date(staff.updatedAt),
        };
        if (outcome === "created") {
          await tx.adminStaffAccount.create({
            data: {
              id: staff.id,
              staffCode: staff.staffCode,
              ...staffData,
              createdBy: staff.createdBy,
              createdAt: new Date(staff.createdAt),
            },
          });
        } else {
          if (!expectedUpdatedAt) {
            throw new ServiceUnavailableException("Staff updates require an optimistic concurrency version.");
          }
          const updated = await tx.adminStaffAccount.updateMany({
            where: {
              id: staff.id,
              updatedAt: new Date(expectedUpdatedAt),
              role: originalRole,
              status: originalStatus,
            },
            data: staffData,
          });
          if (updated.count !== 1) {
            throw new ConflictException("The staff account changed concurrently; reload it and retry.");
          }
        }

        if (outcome !== "created") {
          const now = new Date();
          await tx.adminStaffSession.updateMany({
            where: { staffId: staff.id, revokedAt: null },
            data: { revokedAt: now, revokeReason: "STAFF_ACCOUNT_CHANGED" },
          });
          if (staff.status !== "ACTIVE") {
            await tx.adminStaffBackupCode.updateMany({
              where: { staffId: staff.id, usedAt: null },
              data: { usedAt: now },
            });
            await tx.adminStaffRecoveryRequest.updateMany({
              where: {
                staffId: staff.id,
                status: { in: ["PENDING", "APPROVED"] },
              },
              data: { status: "CANCELLED" },
            });
          }
        }

        await tx.auditEvent.create({
          data: {
            actorType: "ADMIN",
            actorId: actorStaffId,
            action:
              outcome === "created"
                ? "admin.staff_account.created"
                : originalEmail !== undefined && originalEmail.toLowerCase() !== staff.email.toLowerCase()
                  ? "admin.staff_account.email_changed"
                  : "admin.staff_account.updated",
            targetType: "admin_staff_account",
            targetId: staff.id,
            outcome: "success",
            requestId: randomUUID(),
            redactedMetadata: {
              ...safeMetadata,
              ...(originalEmail !== undefined && originalEmail.toLowerCase() !== staff.email.toLowerCase()
                ? {
                    emailChanged: true,
                    reason: emailChangeReason,
                    previousEmailSha256: sha256Hex(originalEmail.toLowerCase()),
                    newEmailSha256: sha256Hex(staff.email.toLowerCase()),
                  }
                : {}),
            },
          },
        });
      };
      if (transactionClient) {
        await persist(transactionClient);
      } else {
        await anyPrisma.$transaction(persist, { isolationLevel: "Serializable" });
        this.staffMap.set(staff.id, staff);
      }
    } catch (error) {
      this.hydrated = false;
      this.hydrationPromise = null;
      if (error instanceof HttpException) throw error;
      if (
        typeof error === "object" &&
        error !== null &&
        "code" in error &&
        (error as { code?: unknown }).code === "P2002"
      ) {
        throw new ConflictException(
          "An admin account with this email or staff code already exists.",
        );
      }
      throw new ServiceUnavailableException(
        "Admin staff changes, session revocation, and audit logging must commit together. No change was accepted.",
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Business Directory & Marketplace Governance (Role 5 & Super Admin)
  // ---------------------------------------------------------------------------
  static async listBusinesses(prisma: PrismaService) {
    await this.ensureHydrated(prisma);
    const anyPrisma = prisma as unknown as Record<string, any>;
    if (!anyPrisma.businessDirectoryListing?.findMany) {
      throw new ServiceUnavailableException(
        "Business directory storage is unavailable. Verify the Module 6 database migration and Prisma client.",
      );
    }
    const freshRows = await anyPrisma.businessDirectoryListing.findMany({
      orderBy: { createdAt: "desc" },
    });
    if (!Array.isArray(freshRows)) {
      throw new ServiceUnavailableException(
        "Business directory storage returned an invalid response.",
      );
    }
    this.businessMap.clear();
    for (const row of freshRows) {
      const mapped = this.mapDbRowToBusiness(row);
      this.businessMap.set(mapped.id, mapped);
    }
    const items = Array.from(this.businessMap.values()).sort(
      (a, b) =>
        new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
    );

    const [enquiries, reports] = await Promise.all([
      typeof anyPrisma.businessEnquiry?.findMany === "function"
        ? anyPrisma.businessEnquiry
            .findMany({ orderBy: { updatedAt: "desc" }, take: 100 })
            .catch(() => [])
        : Promise.resolve([]),
      typeof anyPrisma.businessReport?.findMany === "function"
        ? anyPrisma.businessReport
            .findMany({ orderBy: { createdAt: "desc" }, take: 100 })
            .catch(() => [])
        : Promise.resolve([]),
    ]);

    return {
      metrics: {
        totalBusinesses: items.length,
        pendingApprovalCount: items.filter(
          (i) => i.approvalStatus === "PENDING_APPROVAL",
        ).length,
        approvedCount: items.filter((i) => i.approvalStatus === "APPROVED")
          .length,
        verifiedBadgeCount: items.filter(
          (i) => i.verificationBadgeStatus === "VERIFIED_WOMAN_OWNED",
        ).length,
        pendingBadgeCount: items.filter(
          (i) => i.verificationBadgeStatus === "PENDING_BADGE",
        ).length,
        reportedFraudulentCount: items.filter((i) => i.isReportedFraudulent)
          .length,
        featuredCount: items.filter((i) => i.isFeatured).length,
      },
      categories: this.platformConfig.businessCategories,
      businesses: items,
      enquiries: Array.isArray(enquiries) ? enquiries : [],
      reports: Array.isArray(reports) ? reports : [],
    };
  }

  static async upsertBusinessListing(
    prisma: PrismaService,
    body: Record<string, unknown>,
    actorLabel: string,
    actorStaffId?: string,
  ): Promise<BusinessListingRecord> {
    await this.ensureHydrated(prisma);
    if (body.approvalStatus !== undefined || body.verificationBadgeStatus !== undefined) {
      throw new BadRequestException("Business approval and verification badge changes must use the dedicated review operation.");
    }
    const businessName = String(body.businessName ?? "").trim();
    if (businessName.length < 3 || /^\d+$/.test(businessName)) {
      throw new BadRequestException(
        "Business name must be at least 3 characters and cannot be numbers only.",
      );
    }
    const ownerDisplayName = String(
      body.ownerDisplayName ?? "Verified Sakhi Entrepreneur",
    ).trim();
    const category = String(
      body.category ??
        this.platformConfig.businessCategories[0] ??
        "Women-Owned Boutique & Apparel",
    ).trim();
    const city = String(body.city ?? "Bengaluru").trim();
    const description = String(
      body.description ?? "Verified women-owned business listing.",
    ).trim();

    const nowIso = new Date().toISOString();
    const id =
      typeof body.id === "string" && body.id.trim()
        ? body.id.trim()
        : randomUUID();
    const existing = this.businessMap.get(id);
    const businessCode =
      existing?.businessCode ?? `#BIZ-${randomInt(1000, 9999)}`;

    const record: BusinessListingRecord = {
      id,
      businessCode:
        typeof body.businessCode === "string" && body.businessCode.trim()
          ? body.businessCode.trim()
          : businessCode,
      businessName,
      ownerAccountId:
        typeof body.ownerAccountId === "string" && body.ownerAccountId.trim()
          ? body.ownerAccountId.trim()
          : (existing?.ownerAccountId ?? null),
      ownerDisplayName,
      category,
      city,
      serviceArea:
        typeof body.serviceArea === "string" && body.serviceArea.trim()
          ? body.serviceArea.trim()
          : (existing?.serviceArea ?? city),
      priceRange:
        typeof body.priceRange === "string" && body.priceRange.trim()
          ? body.priceRange.trim()
          : (existing?.priceRange ?? "₹500 – ₹2,500"),
      description,
      logoAsset:
        typeof body.logoAsset === "string" && body.logoAsset.trim()
          ? body.logoAsset.trim()
          : (existing?.logoAsset ?? null),
      coverImage:
        typeof body.coverImage === "string" && body.coverImage.trim()
          ? body.coverImage.trim()
          : (existing?.coverImage ?? null),
      mediaGallery: Array.isArray(body.mediaGallery)
        ? body.mediaGallery.map((x) => String(x))
        : (existing?.mediaGallery ?? []),
      businessHours:
        body.businessHours && typeof body.businessHours === "object"
          ? (body.businessHours as Record<string, any>)
          : (existing?.businessHours ?? null),
      productsServices: Array.isArray(body.productsServices)
        ? (body.productsServices as Array<Record<string, any>>)
        : (existing?.productsServices ?? []),
      offersAndPosts: Array.isArray(body.offersAndPosts)
        ? (body.offersAndPosts as Array<Record<string, any>>)
        : (existing?.offersAndPosts ?? []),
      hidePhoneNumber:
        typeof body.hidePhoneNumber === "boolean"
          ? body.hidePhoneNumber
          : (existing?.hidePhoneNumber ?? false),
      whatsappNumber:
        typeof body.whatsappNumber === "string"
          ? body.whatsappNumber.trim()
          : (existing?.whatsappNumber ?? null),
      instagramHandle:
        typeof body.instagramHandle === "string"
          ? body.instagramHandle.trim()
          : (existing?.instagramHandle ?? null),
      contactPhone:
        typeof body.contactPhone === "string"
          ? body.contactPhone.trim()
          : (existing?.contactPhone ?? null),
      websiteOrInstagram:
        typeof body.websiteOrInstagram === "string"
          ? body.websiteOrInstagram.trim()
          : (existing?.websiteOrInstagram ?? null),
      approvalStatus: existing?.approvalStatus ?? "PENDING_APPROVAL",
      verificationBadgeStatus: existing?.verificationBadgeStatus ?? "PENDING_BADGE",
      isFeatured:
        typeof body.isFeatured === "boolean"
          ? body.isFeatured
          : (existing?.isFeatured ?? false),
      isReportedFraudulent:
        typeof body.isReportedFraudulent === "boolean"
          ? body.isReportedFraudulent
          : (existing?.isReportedFraudulent ?? false),
      reportReason:
        typeof body.reportReason === "string"
          ? body.reportReason.trim()
          : (existing?.reportReason ?? null),
      reviewedBy: actorLabel,
      reviewNotes:
        typeof body.reviewNotes === "string"
          ? body.reviewNotes.trim()
          : (existing?.reviewNotes ?? null),
      createdAt: existing?.createdAt ?? nowIso,
      updatedAt: nowIso,
    };

    await this.persistBusinessRecord(prisma, record, actorLabel, actorStaffId);
    return record;
  }

  static async reviewBusinessListing(
    prisma: PrismaService,
    businessId: string,
    body: {
      approvalStatus?:
        "PENDING_APPROVAL" | "APPROVED" | "SUSPENDED" | "REJECTED";
      verificationBadgeStatus?:
        "NONE" | "PENDING_BADGE" | "VERIFIED_WOMAN_OWNED" | "REVOKED";
      isFeatured?: boolean;
      isReportedFraudulent?: boolean;
      reviewNotes?: string;
    },
    actorLabel: string,
    actorStaffId?: string,
  ): Promise<BusinessListingRecord> {
    await this.ensureHydrated(prisma);
    const existing =
      this.businessMap.get(businessId) ??
      Array.from(this.businessMap.values()).find(
        (b) => b.businessCode === businessId,
      );
    if (!existing) {
      throw new NotFoundException(`Business listing ${businessId} not found.`);
    }

    // Work on a copy so failed persistence cannot mutate the in-memory record.
    const updated: BusinessListingRecord = { ...existing };
    if (body.approvalStatus) {
      if (!["PENDING_APPROVAL", "APPROVED", "SUSPENDED", "REJECTED"].includes(body.approvalStatus)) {
        throw new BadRequestException("Unsupported business approval status.");
      }
      updated.approvalStatus = body.approvalStatus;
    }
    if (body.verificationBadgeStatus) {
      if (!["NONE", "PENDING_BADGE", "VERIFIED_WOMAN_OWNED", "REVOKED"].includes(body.verificationBadgeStatus)) {
        throw new BadRequestException("Unsupported business verification badge status.");
      }
      updated.verificationBadgeStatus = body.verificationBadgeStatus;
    }
    if (typeof body.isFeatured === "boolean") {
      updated.isFeatured = body.isFeatured;
    }
    if (typeof body.isReportedFraudulent === "boolean") {
      updated.isReportedFraudulent = body.isReportedFraudulent;
    }
    if (body.reviewNotes !== undefined) {
      updated.reviewNotes = body.reviewNotes.trim();
    }
    updated.reviewedBy = actorLabel;
    updated.updatedAt = new Date().toISOString();

    const anyPrisma = prisma as unknown as Record<string, any>;
    if (typeof anyPrisma.$transaction !== "function" || !anyPrisma.auditEvent?.create) {
      throw new ServiceUnavailableException("Business review and audit require one database transaction.");
    }
    await anyPrisma.$transaction(async (tx: Record<string, any>) => {
      await this.persistBusinessRecord(prisma, updated, actorLabel, actorStaffId, tx);
      if (updated.ownerAccountId && tx.memberProfile?.update) {
        const otherApproved = Array.from(this.businessMap.values()).find(
          (business) =>
            business.ownerAccountId === updated.ownerAccountId &&
            business.id !== updated.id &&
            business.approvalStatus === "APPROVED",
        );
        if (updated.approvalStatus === "APPROVED") {
          await tx.memberProfile.update({
            where: { accountId: updated.ownerAccountId },
            data: {
              businessProfileName: updated.businessName.slice(0, 120),
              businessCategory: updated.category.slice(0, 80),
              businessProfileUrl: `sakhi://business/${updated.id}`,
            },
          });
        } else if (updated.approvalStatus === "REJECTED" || updated.approvalStatus === "SUSPENDED") {
          await tx.memberProfile.update({
            where: { accountId: updated.ownerAccountId },
            data: {
              businessProfileName: otherApproved ? otherApproved.businessName.slice(0, 120) : null,
              businessCategory: otherApproved ? otherApproved.category.slice(0, 80) : null,
              businessProfileUrl: otherApproved ? `sakhi://business/${otherApproved.id}` : null,
            },
          });
        }
      }
    }, { isolationLevel: "Serializable" });
    this.businessMap.set(updated.id, updated);
    return updated;
  }

  static async deleteBusinessListing(
    prisma: PrismaService,
    businessId: string,
    actorLabel: string,
    actorStaffId?: string,
  ): Promise<{ deleted: true; businessId: string }> {
    await this.ensureHydrated(prisma);
    const existing =
      this.businessMap.get(businessId) ??
      Array.from(this.businessMap.values()).find(
        (b) => b.businessCode === businessId,
      );
    if (!existing) throw new NotFoundException(`Business listing ${businessId} not found.`);
    const targetId = existing.id;
    const anyPrisma = prisma as unknown as Record<string, any>;
    if (!anyPrisma.businessDirectoryListing?.delete || !anyPrisma.auditEvent?.create ||
        typeof anyPrisma.$transaction !== "function") {
      throw new ServiceUnavailableException("Business deletion and audit require one database transaction.");
    }
    await anyPrisma.$transaction(async (tx: Record<string, any>) => {
      await tx.businessDirectoryListing.delete({ where: { id: targetId } });
      await tx.auditEvent.create({
        data: {
          actorType: "ADMIN",
          actorId: actorStaffId ?? null,
          action: "module10.business_listing.deleted",
          targetType: "business_directory_listing",
          targetId,
          outcome: "deleted",
          requestId: randomUUID(),
          redactedMetadata: { businessCode: existing.businessCode, businessName: existing.businessName },
        },
      });
    }, { isolationLevel: "Serializable" });
    this.businessMap.delete(targetId);
    return { deleted: true, businessId: targetId };
  }

  private static async persistBusinessRecord(
    prisma: PrismaService,
    record: BusinessListingRecord,
    actorLabel: string,
    actorStaffId?: string,
    transactionClient?: Record<string, any>,
  ): Promise<void> {
    const anyPrisma = prisma as unknown as Record<string, any>;
    if (!anyPrisma.businessDirectoryListing?.upsert) {
      throw new ServiceUnavailableException(
        "Business directory storage is unavailable. Apply the Module 6 database migration before saving listings.",
      );
    }

    const upsertArgs = {
      where: { id: record.id },
      update: {
        businessName: record.businessName,
        ownerAccountId: record.ownerAccountId,
        ownerDisplayName: record.ownerDisplayName,
        category: record.category,
        city: record.city,
        serviceArea: record.serviceArea ?? null,
        priceRange: record.priceRange ?? "₹500 – ₹2,500",
        description: record.description,
        logoAsset: record.logoAsset ?? null,
        coverImage: record.coverImage ?? null,
        mediaGallery: record.mediaGallery ?? [],
        businessHours: record.businessHours ?? {},
        contactPhone: record.contactPhone,
        hidePhoneNumber: record.hidePhoneNumber ?? false,
        whatsappNumber: record.whatsappNumber ?? null,
        instagramHandle: record.instagramHandle ?? null,
        websiteOrInstagram: record.websiteOrInstagram,
        productsServices: record.productsServices ?? [],
        offersAndPosts: record.offersAndPosts ?? [],
        approvalStatus: record.approvalStatus,
        verificationBadgeStatus: record.verificationBadgeStatus,
        isFeatured: record.isFeatured,
        isReportedFraudulent: record.isReportedFraudulent,
        reportReason: record.reportReason,
        reviewedBy: record.reviewedBy,
        reviewNotes: record.reviewNotes,
        updatedAt: new Date(record.updatedAt),
      },
      create: {
        id: record.id,
        businessCode: record.businessCode,
        businessName: record.businessName,
        ownerAccountId: record.ownerAccountId,
        ownerDisplayName: record.ownerDisplayName,
        category: record.category,
        city: record.city,
        serviceArea: record.serviceArea ?? null,
        priceRange: record.priceRange ?? "₹500 – ₹2,500",
        description: record.description,
        logoAsset: record.logoAsset ?? null,
        coverImage: record.coverImage ?? null,
        mediaGallery: record.mediaGallery ?? [],
        businessHours: record.businessHours ?? {},
        contactPhone: record.contactPhone,
        hidePhoneNumber: record.hidePhoneNumber ?? false,
        whatsappNumber: record.whatsappNumber ?? null,
        instagramHandle: record.instagramHandle ?? null,
        websiteOrInstagram: record.websiteOrInstagram,
        productsServices: record.productsServices ?? [],
        offersAndPosts: record.offersAndPosts ?? [],
        approvalStatus: record.approvalStatus,
        verificationBadgeStatus: record.verificationBadgeStatus,
        isFeatured: record.isFeatured,
        isReportedFraudulent: record.isReportedFraudulent,
        reportReason: record.reportReason,
        reviewedBy: record.reviewedBy,
        reviewNotes: record.reviewNotes,
        createdAt: new Date(record.createdAt),
        updatedAt: new Date(record.updatedAt),
      },
    };
    const auditData = {
      actorType: "ADMIN",
      actorId: actorStaffId ?? null,
      action: "module10.business_listing.snapshot",
      targetType: "business_directory_listing",
      targetId: record.id,
      outcome: record.approvalStatus,
      requestId: randomUUID(),
      redactedMetadata: {
        businessCode: record.businessCode,
        approvalStatus: record.approvalStatus,
        verificationBadgeStatus: record.verificationBadgeStatus,
        isFeatured: record.isFeatured,
        isReportedFraudulent: record.isReportedFraudulent,
      },
    };

    try {
      if (transactionClient) {
        await transactionClient.businessDirectoryListing.upsert(upsertArgs);
        await transactionClient.auditEvent.create({ data: auditData });
      } else {
        if (typeof anyPrisma.$transaction !== "function" || !anyPrisma.auditEvent?.create) {
          throw new ServiceUnavailableException("Business listing and audit require one database transaction.");
        }
        await anyPrisma.$transaction(async (transaction: Record<string, any>) => {
          await transaction.businessDirectoryListing.upsert(upsertArgs);
          await transaction.auditEvent.create({ data: auditData });
        }, { isolationLevel: "Serializable" });
      }
    } catch (error) {
      if (error instanceof HttpException) throw error;
      if (
        typeof error === "object" && error !== null && "code" in error &&
        (error as { code?: unknown }).code === "P2002"
      ) {
        throw new ConflictException("A business listing with this business code already exists.");
      }
      throw new ServiceUnavailableException("Business listing changes and audit could not be durably committed. No success was recorded.");
    }

    // Update the process cache only after the durable database write succeeds.
    if (!transactionClient) this.businessMap.set(record.id, record);
  }

  // ---------------------------------------------------------------------------
  // Global Platform Config & Feature Flags (Super Admin Exclusive)
  // ---------------------------------------------------------------------------
  static async getPlatformConfig(
    prisma: PrismaService,
  ): Promise<PlatformConfigRecord> {
    await this.ensureHydrated(prisma);
    return this.platformConfig;
  }

  static async updatePlatformConfig(
    prisma: PrismaService,
    body: Record<string, unknown>,
    actorLabel: string,
    actorStaffId?: string,
  ): Promise<PlatformConfigRecord> {
    await this.ensureHydrated(prisma);
    const next = JSON.parse(JSON.stringify(this.platformConfig)) as PlatformConfigRecord;
    if (typeof body.featureFlags === "object" && body.featureFlags !== null && !Array.isArray(body.featureFlags)) {
      const allowedFlags = Object.keys(next.featureFlags);
      for (const [key, value] of Object.entries(body.featureFlags as Record<string, unknown>)) {
        if (!allowedFlags.includes(key) || typeof value !== "boolean") {
          throw new BadRequestException("Platform feature flags must contain only recognized boolean values.");
        }
      }
      next.featureFlags = { ...next.featureFlags, ...(body.featureFlags as Record<string, boolean>) };
    }
    if (typeof body.mediaUploadLimits === "object" && body.mediaUploadLimits !== null && !Array.isArray(body.mediaUploadLimits)) {
      next.mediaUploadLimits = {
        ...next.mediaUploadLimits,
        ...(body.mediaUploadLimits as Record<string, any>),
      };
    }
    if (Array.isArray(body.businessCategories)) {
      next.businessCategories = body.businessCategories
        .map((category) => String(category).trim())
        .filter(Boolean);
    }
    if (typeof body.announcementBanner === "string") {
      next.announcementBanner = body.announcementBanner.trim();
    }
    next.updatedBy = actorLabel;
    next.updatedAt = new Date().toISOString();

    const anyPrisma = prisma as unknown as Record<string, any>;
    if (!anyPrisma.platformConfigSetting?.upsert || !anyPrisma.auditEvent?.create ||
        typeof anyPrisma.$transaction !== "function") {
      throw new ServiceUnavailableException("Platform configuration and audit must be persisted in one database transaction.");
    }
    await anyPrisma.$transaction(async (tx: Record<string, any>) => {
      await tx.platformConfigSetting.upsert({
        where: { configKey: "default" },
        update: {
          featureFlags: next.featureFlags,
          mediaUploadLimits: next.mediaUploadLimits,
          businessCategories: next.businessCategories,
          announcementBanner: next.announcementBanner,
          updatedBy: actorLabel,
          updatedAt: new Date(next.updatedAt),
        },
        create: {
          configKey: "default",
          featureFlags: next.featureFlags,
          mediaUploadLimits: next.mediaUploadLimits,
          businessCategories: next.businessCategories,
          announcementBanner: next.announcementBanner,
          updatedBy: actorLabel,
          updatedAt: new Date(next.updatedAt),
        },
      });
      await tx.auditEvent.create({
        data: {
          actorType: "ADMIN",
          actorId: actorStaffId ?? null,
          action: "module10.platform_config.snapshot",
          targetType: "platform_config_setting",
          targetId: "default",
          outcome: "updated",
          requestId: randomUUID(),
          redactedMetadata: {
            featureFlagKeys: Object.keys(next.featureFlags),
            businessCategoryCount: next.businessCategories.length,
            mediaUploadLimitKeys: Object.keys(next.mediaUploadLimits),
            announcementBannerUpdated: typeof body.announcementBanner === "string",
          },
        },
      });
    }, { isolationLevel: "Serializable" });
    this.platformConfig = next;
    return this.platformConfig;
  }

  static assertRouteAccess(
    principal: AuthenticatedAdminPrincipal,
    requiredRoles: SakhiAdminRole[],
    featureLabel: string,
  ): void {
    if (principal.role === "SUPER_ADMIN") return;
    if (!requiredRoles.includes(principal.role)) {
      throw new ForbiddenException(
        `Access denied: your assigned role (${principal.badgeLabel}) is not authorised to access ${featureLabel}. Required role: ${requiredRoles.join(" or ")}.`,
      );
    }
  }
}
