import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
  ServiceUnavailableException,
  UnauthorizedException,
} from "@nestjs/common";
import {
  createHash,
  createHmac,
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
  | "BUSINESS_ADMIN";

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

export const ADMIN_ROLE_DEFINITIONS: Record<SakhiAdminRole, AdminRoleDefinition> =
  {
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
  };

export interface AdminStaffRecord {
  id: string;
  staffCode: string;
  fullName: string;
  email: string;
  role: SakhiAdminRole;
  status: "ACTIVE" | "SUSPENDED" | "REVOKED";
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
    | "NONE"
    | "PENDING_BADGE"
    | "VERIFIED_WOMAN_OWNED"
    | "REVOKED";
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
  private static readonly businessMap = new Map<string, BusinessListingRecord>();
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
        privacyPolicyVersion: "v2.4 (Zero Raw Aadhaar/OTP & Encrypted Health Data)",
        communityGuidelines: "Zero tolerance for harassment, doxxing, hate speech, or non-consensual media.",
        medicalLegalDisclaimer: "In-app wellness content is non-diagnostic educational guidance; in-app complaints do not replace a Police FIR or 112 call.",
      },
      notificationTemplates: {
        wellnessDiscreetDefault: "Sakhi Daily Mindfulness: Your personal calendar reminder is ready.",
        complaintStatusUpdate: "Sakhi Personal Note: You have a new update in your private vault.",
        sosEmergencySms: "URGENT SAKHI SOS: {memberName} needs emergency assistance. Live location: {trackingUrl} | Dial 112.",
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

  static getSuperAdminPrincipal(customLabel?: string): AuthenticatedAdminPrincipal {
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

  static principalFromStaff(staff: AdminStaffRecord): AuthenticatedAdminPrincipal {
    const def =
      ADMIN_ROLE_DEFINITIONS[staff.role] ??
      ADMIN_ROLE_DEFINITIONS.COMPLAINT_REVIEWER;
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
  ): { value: string; expiresAt: Date } {
    const expiresAtSec = Math.floor(Date.now() / 1000) + 8 * 3600;
    const payload = `staff-admin.${staff.id}.${expiresAtSec}`;
    const sig = createHmac("sha256", secretKey || "sakhi-rbac-default-secret")
      .update(`sakhi-staff-session:${payload}`)
      .digest("base64url");
    return {
      value: `${payload}.${sig}`,
      expiresAt: new Date(expiresAtSec * 1000),
    };
  }

  static verifySignedStaffSessionToken(
    token: string,
    secretKey: string,
  ): AdminStaffRecord | null {
    if (!token.startsWith("staff-admin.")) return null;
    const parts = token.split(".");
    if (parts.length !== 4) return null;
    const staffId = parts[1] ?? "";
    const expiresAtSec = Number(parts[2] ?? "0");
    const sig = parts[3] ?? "";
    if (!staffId || !Number.isSafeInteger(expiresAtSec)) return null;
    if (expiresAtSec <= Math.floor(Date.now() / 1000)) return null;

    const payload = `staff-admin.${staffId}.${expiresAtSec}`;
    const expected = createHmac(
      "sha256",
      secretKey || "sakhi-rbac-default-secret",
    )
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

      // Fallback to AuditEvent snapshots if table not yet migrated or empty
      if (prisma.auditEvent?.findMany) {
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
            } else if (!loadedStaffFromTable || !this.staffMap.has(meta.id)) {
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
    } catch {
      // Safe fallback in unit tests
    }
  }

  private static mapDbRowToStaff(r: Record<string, any>): AdminStaffRecord {
    const role = (
      r.role && r.role in ADMIN_ROLE_DEFINITIONS
        ? r.role
        : "COMPLAINT_REVIEWER"
    ) as SakhiAdminRole;
    const def = ADMIN_ROLE_DEFINITIONS[role];
    const rawPerms =
      typeof r.permissions === "object" && r.permissions !== null
        ? r.permissions
        : {};
    const allowedRoutes = Array.isArray(rawPerms.allowedRoutes)
      ? rawPerms.allowedRoutes
      : Array.isArray(r.allowedRoutes)
        ? r.allowedRoutes
        : [...def.allowedRoutes];

    return {
      id: String(r.id),
      staffCode: String(r.staffCode ?? "#ADM-101"),
      fullName: String(r.fullName ?? "Sakhi Admin"),
      email: String(r.email ?? "admin@sakhi.org.in"),
      role,
      status:
        r.status === "SUSPENDED" || r.status === "REVOKED"
          ? r.status
          : "ACTIVE",
      accessTokenDigest: String(r.accessTokenDigest ?? ""),
      accessTokenPreview: String(r.accessTokenPreview ?? "SAKHI-STAFF-••••"),
      isAuthorisedComplaintReviewer:
        role === "SUPER_ADMIN" ||
        role === "COMPLAINT_REVIEWER" ||
        Boolean(r.isAuthorisedComplaintReviewer),
      clearanceLevel: String(r.clearanceLevel ?? def.defaultClearanceLevel),
      permissions: {
        view: Boolean(rawPerms.view ?? def.defaultPermissions.view),
        create: Boolean(rawPerms.create ?? def.defaultPermissions.create),
        edit: Boolean(rawPerms.edit ?? def.defaultPermissions.edit),
        approve: Boolean(rawPerms.approve ?? def.defaultPermissions.approve),
        suspend: Boolean(rawPerms.suspend ?? def.defaultPermissions.suspend),
        export: Boolean(rawPerms.export ?? def.defaultPermissions.export),
        delete: Boolean(rawPerms.delete ?? def.defaultPermissions.delete),
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
      serviceArea: b.serviceArea ? String(b.serviceArea) : String(b.city ?? "Bengaluru"),
      priceRange: b.priceRange ? String(b.priceRange) : "₹500 – ₹2,500",
      description: String(b.description ?? ""),
      logoAsset: b.logoAsset ? String(b.logoAsset) : null,
      coverImage: b.coverImage ? String(b.coverImage) : null,
      contactPhone: b.contactPhone ? String(b.contactPhone) : null,
      hidePhoneNumber: Boolean(b.hidePhoneNumber),
      whatsappNumber: b.whatsappNumber ? String(b.whatsappNumber) : null,
      instagramHandle: b.instagramHandle ? String(b.instagramHandle) : null,
      websiteOrInstagram: b.websiteOrInstagram
        ? String(b.websiteOrInstagram)
        : null,
      productsServices: Array.isArray(b.productsServices) ? b.productsServices : [],
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

  static findStaffByToken(
    rawToken: string,
    signingSecret = "sakhi-rbac-default-secret",
  ): AdminStaffRecord | null {
    const clean = rawToken.trim();
    if (!clean) return null;
    if (clean.startsWith("staff-admin.")) {
      return this.verifySignedStaffSessionToken(clean, signingSecret);
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

    // Always include the real Master Super Admin governance seat so a solo Super Admin can assign cases to themselves immediately
    results.unshift({
      id: "SA-01",
      staffCode: "#SA-01",
      name: "Sakhi Super Admin (#SA-01 • Master Governance)",
      role: "SUPER_ADMIN",
      clearance: "LEVEL_4_MASTER_GOVERNANCE",
      email: "superadmin@sakhi.org.in",
    });

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
    },
    createdByLabel: string,
  ): Promise<{ staff: AdminStaffRecord; issuedAccessToken: string }> {
    await this.ensureHydrated(prisma);

    const fullName = (dto.fullName ?? "").trim();
    if (fullName.length < 3 || fullName.length > 120 || /^\d+$/.test(fullName)) {
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

    const rolePrefixMap: Record<SakhiAdminRole, string> = {
      SUPER_ADMIN: "SA",
      VERIFICATION_ADMIN: "VA",
      CONTENT_MODERATOR: "CM",
      COMPLAINT_REVIEWER: "CR",
      SOS_SAFETY_ADMIN: "SOS",
      BUSINESS_ADMIN: "BA",
    };
    const prefix = rolePrefixMap[rawRole];
    const num = randomInt(100, 999);
    const staffCode = `#${prefix}-${num}`;

    const customToken = dto.customAccessToken?.trim();
    if (customToken && customToken.length < 8) {
      throw new BadRequestException(
        "Custom admin access token must be at least 8 characters.",
      );
    }
    const randomPart = randomUUID().replace(/-/g, "").slice(0, 10).toUpperCase();
    const issuedAccessToken =
      customToken || `SAKHI-${prefix}-${num}-${randomPart}`;
    const accessTokenDigest = sha256Hex(issuedAccessToken);
    const accessTokenPreview = `${issuedAccessToken.slice(0, 12)}••••${issuedAccessToken.slice(-4)}`;

    const nowIso = new Date().toISOString();
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
      id: randomUUID(),
      staffCode,
      fullName,
      email,
      role: rawRole,
      status: "ACTIVE",
      accessTokenDigest,
      accessTokenPreview,
      isAuthorisedComplaintReviewer:
        rawRole === "SUPER_ADMIN" ||
        rawRole === "COMPLAINT_REVIEWER" ||
        Boolean(dto.isAuthorisedComplaintReviewer),
      clearanceLevel:
        dto.clearanceLevel?.trim() || def.defaultClearanceLevel,
      permissions,
      allowedRoutes: [...def.allowedRoutes],
      createdBy: createdByLabel,
      lastLoginAt: null,
      createdAt: nowIso,
      updatedAt: nowIso,
    };

    await this.persistStaffRecord(prisma, staff, "created", createdByLabel);
    return { staff, issuedAccessToken };
  }

  static async updateStaffAccount(
    prisma: PrismaService,
    staffId: string,
    dto: {
      fullName?: string;
      role?: string;
      status?: string;
      isAuthorisedComplaintReviewer?: boolean;
      clearanceLevel?: string;
      permissions?: Partial<GranularRolePermissions>;
      regenerateToken?: boolean;
      customAccessToken?: string;
    },
    updatedByLabel: string,
  ): Promise<{ staff: AdminStaffRecord; issuedAccessToken?: string }> {
    await this.ensureHydrated(prisma);
    const existing =
      this.staffMap.get(staffId) ??
      Array.from(this.staffMap.values()).find((s) => s.staffCode === staffId);
    if (!existing) {
      throw new NotFoundException(`Admin staff account ${staffId} not found.`);
    }

    if (dto.fullName !== undefined) {
      const cleanName = dto.fullName.trim();
      if (cleanName.length < 3 || /^\d+$/.test(cleanName)) {
        throw new BadRequestException(
          "Admin full name must be at least 3 characters and not numbers only.",
        );
      }
      existing.fullName = cleanName;
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
      if (nextRole === "SUPER_ADMIN" || nextRole === "COMPLAINT_REVIEWER") {
        existing.isAuthorisedComplaintReviewer = true;
      }
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
      existing.status = nextStatus;
    }

    if (dto.isAuthorisedComplaintReviewer !== undefined) {
      existing.isAuthorisedComplaintReviewer = Boolean(
        dto.isAuthorisedComplaintReviewer,
      );
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
    if (dto.regenerateToken || dto.customAccessToken?.trim()) {
      const cleanCustom = dto.customAccessToken?.trim();
      if (cleanCustom && cleanCustom.length < 8) {
        throw new BadRequestException(
          "Custom access token must be at least 8 characters.",
        );
      }
      const rand = randomUUID().replace(/-/g, "").slice(0, 10).toUpperCase();
      issuedAccessToken =
        cleanCustom ||
        `SAKHI-${existing.staffCode.replace("#", "")}-${rand}`;
      existing.accessTokenDigest = sha256Hex(issuedAccessToken);
      existing.accessTokenPreview = `${issuedAccessToken.slice(0, 12)}••••${issuedAccessToken.slice(-4)}`;
    }

    existing.updatedAt = new Date().toISOString();
    await this.persistStaffRecord(prisma, existing, "updated", updatedByLabel);
    return { staff: existing, issuedAccessToken };
  }

  static async deleteStaffAccount(
    prisma: PrismaService,
    staffId: string,
    deletedByLabel: string,
  ): Promise<{ deleted: true; staffCode: string }> {
    await this.ensureHydrated(prisma);
    const existing =
      this.staffMap.get(staffId) ??
      Array.from(this.staffMap.values()).find((s) => s.staffCode === staffId);
    if (!existing) {
      throw new NotFoundException(`Admin staff account ${staffId} not found.`);
    }
    this.staffMap.delete(existing.id);
    const anyPrisma = prisma as unknown as Record<string, any>;
    if (anyPrisma.adminStaffAccount?.delete) {
      await anyPrisma.adminStaffAccount
        .delete({ where: { id: existing.id } })
        .catch(() => null);
    }
    if (prisma.auditEvent?.create) {
      await prisma.auditEvent
        .create({
          data: {
            actorType: "ADMIN",
            action: "module10.admin_staff.snapshot",
            targetType: "admin_staff_account",
            targetId: existing.id,
            outcome: "deleted",
            requestId: randomUUID(),
            redactedMetadata: {
              id: existing.id,
              staffCode: existing.staffCode,
              deleted: true,
              deletedBy: deletedByLabel,
            },
          },
        })
        .catch(() => null);
    }
    return { deleted: true, staffCode: existing.staffCode };
  }

  private static async persistStaffRecord(
    prisma: PrismaService,
    staff: AdminStaffRecord,
    outcome: string,
    actorLabel: string,
  ): Promise<void> {
this.staffMap.set(staff.id, staff);
    const anyPrisma = prisma as unknown as Record<string, any>;
    let persisted = false;

    if (anyPrisma.adminStaffAccount?.upsert) {
      try {
        await anyPrisma.adminStaffAccount.upsert({
          where: { id: staff.id },
          update: {
            fullName: staff.fullName,
            email: staff.email,
            role: staff.role,
            status: staff.status,
            accessTokenDigest: staff.accessTokenDigest,
            accessTokenPreview: staff.accessTokenPreview,
            isAuthorisedComplaintReviewer: staff.isAuthorisedComplaintReviewer,
            clearanceLevel: staff.clearanceLevel,
            permissions: { ...staff.permissions, allowedRoutes: staff.allowedRoutes },
            lastLoginAt: staff.lastLoginAt ? new Date(staff.lastLoginAt) : null,
            updatedAt: new Date(staff.updatedAt),
          },
          create: {
            id: staff.id,
            staffCode: staff.staffCode,
            fullName: staff.fullName,
            email: staff.email,
            role: staff.role,
            status: staff.status,
            accessTokenDigest: staff.accessTokenDigest,
            accessTokenPreview: staff.accessTokenPreview,
            isAuthorisedComplaintReviewer: staff.isAuthorisedComplaintReviewer,
            clearanceLevel: staff.clearanceLevel,
            permissions: { ...staff.permissions, allowedRoutes: staff.allowedRoutes },
            createdBy: staff.createdBy,
            createdAt: new Date(staff.createdAt),
            updatedAt: new Date(staff.updatedAt),
          },
        });
        persisted = true;
      } catch (error) {
        if (
          typeof error === "object" &&
          error !== null &&
          "code" in error &&
          (error as { code?: unknown }).code === "P2002"
        ) {
          this.staffMap.delete(staff.id);
          this.hydrated = false;
          this.hydrationPromise = null;
          throw new ConflictException(
            "An admin account with this email or staff code already exists.",
          );
        }
      }
    }

    if (prisma.auditEvent?.create) {
      try {
        await prisma.auditEvent.create({
          data: {
            actorType: "ADMIN",
            action: "module10.admin_staff.snapshot",
            targetType: "admin_staff_account",
            targetId: staff.id,
            outcome,
            requestId: randomUUID(),
            redactedMetadata: JSON.parse(
              JSON.stringify({ ...staff, updatedBy: actorLabel }),
            ),
          },
        });
        persisted = true;
      } catch {
        // Only report success when at least one durable store accepts the record.
      }
    }

    if (!persisted) {
      this.staffMap.delete(staff.id);
      this.hydrated = false;
      this.hydrationPromise = null;
      throw new ServiceUnavailableException(
        "Admin staff changes could not be durably saved. Check database connectivity and migration state, then retry.",
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
    };
  }

  static async upsertBusinessListing(
    prisma: PrismaService,
    body: Record<string, unknown>,
    actorLabel: string,
  ): Promise<BusinessListingRecord> {
    await this.ensureHydrated(prisma);
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
      businessCode,
      businessName,
      ownerAccountId: existing?.ownerAccountId ?? null,
      ownerDisplayName,
      category,
      city,
      description,
      contactPhone:
        typeof body.contactPhone === "string"
          ? body.contactPhone.trim()
          : (existing?.contactPhone ?? null),
      websiteOrInstagram:
        typeof body.websiteOrInstagram === "string"
          ? body.websiteOrInstagram.trim()
          : (existing?.websiteOrInstagram ?? null),
      approvalStatus:
        (body.approvalStatus as BusinessListingRecord["approvalStatus"]) ??
        existing?.approvalStatus ??
        "PENDING_APPROVAL",
      verificationBadgeStatus:
        (body.verificationBadgeStatus as BusinessListingRecord["verificationBadgeStatus"]) ??
        existing?.verificationBadgeStatus ??
        "PENDING_BADGE",
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

    await this.persistBusinessRecord(prisma, record, actorLabel);
    return record;
  }

  static async reviewBusinessListing(
    prisma: PrismaService,
    businessId: string,
    body: {
      approvalStatus?: "PENDING_APPROVAL" | "APPROVED" | "SUSPENDED" | "REJECTED";
      verificationBadgeStatus?:
        | "NONE"
        | "PENDING_BADGE"
        | "VERIFIED_WOMAN_OWNED"
        | "REVOKED";
      isFeatured?: boolean;
      isReportedFraudulent?: boolean;
      reviewNotes?: string;
    },
    actorLabel: string,
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
    if (body.approvalStatus) updated.approvalStatus = body.approvalStatus;
    if (body.verificationBadgeStatus) {
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

    await this.persistBusinessRecord(prisma, updated, actorLabel);
    return updated;
  }

  private static async persistBusinessRecord(
    prisma: PrismaService,
    record: BusinessListingRecord,
    actorLabel: string,
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
        ownerDisplayName: record.ownerDisplayName,
        category: record.category,
        city: record.city,
        description: record.description,
        contactPhone: record.contactPhone,
        websiteOrInstagram: record.websiteOrInstagram,
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
        description: record.description,
        contactPhone: record.contactPhone,
        websiteOrInstagram: record.websiteOrInstagram,
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
      action: "module10.business_listing.snapshot",
      targetType: "business_directory_listing",
      targetId: record.id,
      outcome: record.approvalStatus,
      requestId: randomUUID(),
      redactedMetadata: JSON.parse(
        JSON.stringify({ ...record, actorLabel }),
      ),
    };

    try {
      if (
        typeof anyPrisma.$transaction === "function" &&
        anyPrisma.auditEvent?.create
      ) {
        await anyPrisma.$transaction(
          async (transaction: Record<string, any>) => {
            await transaction.businessDirectoryListing.upsert(upsertArgs);
            await transaction.auditEvent.create({ data: auditData });
          },
        );
      } else {
        // The primary business table is mandatory; audit snapshots are secondary.
        await anyPrisma.businessDirectoryListing.upsert(upsertArgs);
        if (anyPrisma.auditEvent?.create) {
          await anyPrisma.auditEvent.create({ data: auditData });
        }
      }
    } catch (error) {
      if (
        typeof error === "object" &&
        error !== null &&
        "code" in error &&
        (error as { code?: unknown }).code === "P2002"
      ) {
        throw new ConflictException(
          "A business listing with this business code already exists.",
        );
      }
      throw new ServiceUnavailableException(
        "Business listing changes could not be durably committed to PostgreSQL. No success was recorded; verify database connectivity and retry.",
      );
    }

    // Update the process cache only after the durable database write succeeds.
    this.businessMap.set(record.id, record);
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
  ): Promise<PlatformConfigRecord> {
    await this.ensureHydrated(prisma);
    if (typeof body.featureFlags === "object" && body.featureFlags !== null) {
      this.platformConfig.featureFlags = {
        ...this.platformConfig.featureFlags,
        ...(body.featureFlags as Record<string, boolean>),
      };
    }
    if (
      typeof body.mediaUploadLimits === "object" &&
      body.mediaUploadLimits !== null
    ) {
      this.platformConfig.mediaUploadLimits = {
        ...this.platformConfig.mediaUploadLimits,
        ...(body.mediaUploadLimits as Record<string, any>),
      };
    }
    if (Array.isArray(body.businessCategories)) {
      this.platformConfig.businessCategories = body.businessCategories
        .map((c) => String(c).trim())
        .filter(Boolean);
    }
    if (typeof body.announcementBanner === "string") {
      this.platformConfig.announcementBanner = body.announcementBanner.trim();
    }
    this.platformConfig.updatedBy = actorLabel;
    this.platformConfig.updatedAt = new Date().toISOString();

    const anyPrisma = prisma as unknown as Record<string, any>;
    if (anyPrisma.platformConfigSetting?.upsert) {
      await anyPrisma.platformConfigSetting
        .upsert({
          where: { configKey: "default" },
          update: {
            featureFlags: this.platformConfig.featureFlags,
            mediaUploadLimits: this.platformConfig.mediaUploadLimits,
            businessCategories: this.platformConfig.businessCategories,
            announcementBanner: this.platformConfig.announcementBanner,
            updatedBy: actorLabel,
            updatedAt: new Date(this.platformConfig.updatedAt),
          },
          create: {
            configKey: "default",
            featureFlags: this.platformConfig.featureFlags,
            mediaUploadLimits: this.platformConfig.mediaUploadLimits,
            businessCategories: this.platformConfig.businessCategories,
            announcementBanner: this.platformConfig.announcementBanner,
            updatedBy: actorLabel,
            updatedAt: new Date(this.platformConfig.updatedAt),
          },
        })
        .catch(() => null);
    }

    if (prisma.auditEvent?.create) {
      await prisma.auditEvent
        .create({
          data: {
            actorType: "ADMIN",
            action: "module10.platform_config.snapshot",
            targetType: "platform_config_setting",
            targetId: "default",
            outcome: "updated",
            requestId: randomUUID(),
            redactedMetadata: JSON.parse(JSON.stringify(this.platformConfig)),
          },
        })
        .catch(() => null);
    }

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
