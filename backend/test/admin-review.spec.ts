import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { createHash } from "node:crypto";
import { ForbiddenException, ConflictException, UnauthorizedException, ServiceUnavailableException } from "@nestjs/common";
import { AdminReviewService } from "../src/admin-review/admin-review.service.js";
import { SakhiAdminRbacRegistry } from "../src/admin-review/admin-rbac.helper.js";
import { StagingTestAdminService } from "../src/staging-test-admin/staging-test-admin.service.js";
import type { PrismaService } from "../src/database/prisma.service.js";

const originalToken = process.env.SAKHI_ADMIN_REVIEW_TOKEN;
const originalLabel = process.env.SAKHI_ADMIN_REVIEWER_LABEL;
const originalEnvironment = process.env.SAKHI_ENV;
const originalNodeEnvironment = process.env.NODE_ENV;
const originalHost = process.env.HOST;
const originalStagingAdminReviewEnabled = process.env.SAKHI_STAGING_ADMIN_REVIEW_ENABLED;
const originalOtpMode = process.env.SAKHI_OTP_MODE;
const originalStagingFullAdminEnabled = process.env.SAKHI_STAGING_FULL_ADMIN_ENABLED;
const originalStagingFullAdminToken = process.env.SAKHI_STAGING_FULL_ADMIN_TOKEN;
const originalStaffSigningKey = process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY;
const reviewerToken = "staff-admin.unit-test-super-admin-session";
const staffSigningKey = Buffer.alloc(32, 0x73).toString("base64");

function stagingStaffRow(role = "VERIFICATION_ADMIN") {
  const now = new Date("2026-11-09T12:00:00.000Z");
  return {
    id: "2d5fce37-6aab-4cb4-8a6c-6a2d07f87e91",
    staffCode: "#VA-123",
    fullName: "Staging Verification Reviewer",
    email: "staging.staff@example.test",
    role,
    status: "ACTIVE",
    accessTokenDigest: createHash("sha256").update("staff-first-factor-token-".padEnd(48, "x")).digest("hex"),
    accessTokenPreview: "SAKHI-STAFF-••••",
    isAuthorisedComplaintReviewer: false,
    clearanceLevel: "LEVEL_2_ELIGIBILITY_SUPPORT",
    permissions: {},
    createdBy: "Test fixture",
    lastLoginAt: null,
    createdAt: now,
    updatedAt: now,
  };
}

async function createStagingStaffSession(prisma: PrismaService): Promise<string> {
  configureStagingReviewer();
  process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY = staffSigningKey;
  SakhiAdminRbacRegistry.resetForTesting();
  await SakhiAdminRbacRegistry.ensureHydrated(prisma);
  const staff = SakhiAdminRbacRegistry.listStaff()[0];
  if (!staff) throw new Error("Staging staff fixture did not hydrate.");
  return SakhiAdminRbacRegistry.createSignedStaffSessionToken(staff, staffSigningKey).value;
}

function configureLocalReviewer() {
  process.env.SAKHI_ENV = "test";
  process.env.NODE_ENV = "test";
  process.env.SAKHI_ADMIN_REVIEW_TOKEN = reviewerToken;
  process.env.SAKHI_ADMIN_REVIEWER_LABEL = "QA Reviewer";
}

function configureStagingReviewer() {
  process.env.SAKHI_ENV = "staging";
  process.env.NODE_ENV = "production";
  process.env.HOST = "0.0.0.0";
  process.env.SAKHI_STAGING_ADMIN_REVIEW_ENABLED = "true";
  process.env.SAKHI_OTP_MODE = "staging_test";
  process.env.SAKHI_ADMIN_REVIEW_TOKEN = reviewerToken;
  process.env.SAKHI_ADMIN_REVIEWER_LABEL = "Staging QA Reviewer";
}

describe("AdminReviewService persistent staff-session boundary", () => {
  beforeEach(() => {
    const originalResolve = StagingTestAdminService.resolvePrincipalFromSessionToken;
    vi.spyOn(StagingTestAdminService, "resolvePrincipalFromSessionToken").mockImplementation(
      (token?: string) => {
        if (token === reviewerToken) {
          return {
            staffId: "2d5fce37-6aab-4cb4-8a6c-6a2d07f87e91",
            staffCode: "#SA-TEST",
            reviewerLabel: "QA Reviewer",
            fullName: "QA Reviewer",
            email: "qa.reviewer@example.test",
            role: "SUPER_ADMIN",
            roleTitle: "Super Admin",
            badgeLabel: "Super Admin",
            clearanceLevel: "LEVEL_4_MASTER_GOVERNANCE",
            isAuthorisedComplaintReviewer: true,
            permissions: { view: true, create: true, edit: true, approve: true, suspend: true, export: true, delete: true },
            allowedRoutes: [],
          };
        }
        return originalResolve(token);
      },
    );
  });

  afterEach(() => {
    if (originalToken === undefined) delete process.env.SAKHI_ADMIN_REVIEW_TOKEN;
    else process.env.SAKHI_ADMIN_REVIEW_TOKEN = originalToken;
    if (originalLabel === undefined) delete process.env.SAKHI_ADMIN_REVIEWER_LABEL;
    else process.env.SAKHI_ADMIN_REVIEWER_LABEL = originalLabel;
    if (originalEnvironment === undefined) delete process.env.SAKHI_ENV;
    else process.env.SAKHI_ENV = originalEnvironment;
    if (originalNodeEnvironment === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = originalNodeEnvironment;
    if (originalHost === undefined) delete process.env.HOST;
    else process.env.HOST = originalHost;
    if (originalStagingAdminReviewEnabled === undefined) delete process.env.SAKHI_STAGING_ADMIN_REVIEW_ENABLED;
    else process.env.SAKHI_STAGING_ADMIN_REVIEW_ENABLED = originalStagingAdminReviewEnabled;
    if (originalOtpMode === undefined) delete process.env.SAKHI_OTP_MODE;
    else process.env.SAKHI_OTP_MODE = originalOtpMode;
    if (originalStagingFullAdminEnabled === undefined) delete process.env.SAKHI_STAGING_FULL_ADMIN_ENABLED;
    else process.env.SAKHI_STAGING_FULL_ADMIN_ENABLED = originalStagingFullAdminEnabled;
    if (originalStagingFullAdminToken === undefined) delete process.env.SAKHI_STAGING_FULL_ADMIN_TOKEN;
    else process.env.SAKHI_STAGING_FULL_ADMIN_TOKEN = originalStagingFullAdminToken;
    if (originalStaffSigningKey === undefined) delete process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY;
    else process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY = originalStaffSigningKey;
    SakhiAdminRbacRegistry.resetForTesting();
    vi.restoreAllMocks();
  });

  it("rejects legacy shared reviewer credentials even if obsolete environment variables are set", async () => {
    configureLocalReviewer();
    const service = new AdminReviewService({} as PrismaService);
    await expect(service.session("a".repeat(64))).rejects.toThrow(UnauthorizedException);
  });

  it("rejects any credential that is not an individual staff session", async () => {
    configureLocalReviewer();
    const service = new AdminReviewService({} as PrismaService);
    await expect(service.session("b".repeat(64))).rejects.toThrow(UnauthorizedException);
  });

  it("accepts a test-issued individual session principal and returns its server-side label", async () => {
    configureLocalReviewer();
    const service = new AdminReviewService({} as PrismaService);
    await expect(service.session(reviewerToken)).resolves.toEqual({
      authenticated: true,
      reviewerLabel: "QA Reviewer",
      mode: "local_dev_test_only",
    });
  });

  it("rejects shared reviewer tokens in production staging even when legacy feature gates are enabled", async () => {
    configureStagingReviewer();
    const service = new AdminReviewService({} as PrismaService);
    await expect(service.session("a".repeat(64))).rejects.toThrow(
      /individual persistent MFA-verified staff session/i,
    );
  });

  it("fails closed when the explicit staging admin gate is not enabled", async () => {
    configureStagingReviewer();
    process.env.SAKHI_STAGING_ADMIN_REVIEW_ENABLED = "false";
    const service = new AdminReviewService({} as PrismaService);
    await expect(service.session("a".repeat(64))).rejects.toThrow(UnauthorizedException);
  });

  it("hydrates persisted staff accounts before resolving an individual signed session", async () => {
    configureStagingReviewer();
    SakhiAdminRbacRegistry.resetForTesting();
    const prisma = {
      adminStaffAccount: {
        findMany: vi.fn().mockResolvedValue([stagingStaffRow()]),
      },
      auditEvent: {
        findMany: vi.fn().mockResolvedValue([]),
      },
      businessDirectoryListing: {
        findMany: vi.fn().mockResolvedValue([]),
      },
      platformConfigSetting: {
        findUnique: vi.fn().mockResolvedValue(null),
      },
    } as unknown as PrismaService;

    try {
      const sessionToken = await createStagingStaffSession(prisma);
      const service = new AdminReviewService(prisma);
      await expect(service.session(sessionToken)).resolves.toMatchObject({
        authenticated: true,
        reviewerLabel: expect.stringContaining("Staging Verification Reviewer"),
        mode: "staging_test_only",
      });
      expect(prisma.adminStaffAccount.findMany).toHaveBeenCalled();
    } finally {
      SakhiAdminRbacRegistry.resetForTesting();
    }
  });
  it("does not issue a usable admin token when every durable persistence path fails", async () => {
    configureLocalReviewer();
    SakhiAdminRbacRegistry.resetForTesting();
    const customToken = "persist-failure-token-12345678901234567890";
    const prisma = {
      adminStaffAccount: {
        findMany: vi.fn().mockResolvedValue([]),
        upsert: vi.fn().mockRejectedValue(new Error("database unavailable")),
      },
      auditEvent: {
        findMany: vi.fn().mockResolvedValue([]),
        create: vi.fn().mockRejectedValue(new Error("audit store unavailable")),
      },
      businessDirectoryListing: {
        findMany: vi.fn().mockResolvedValue([]),
      },
      platformConfigSetting: {
        findUnique: vi.fn().mockResolvedValue(null),
      },
    } as unknown as PrismaService;

    try {
      await expect(
        SakhiAdminRbacRegistry.createStaffAccount(
          prisma,
          {
            fullName: "Persistence Failure Admin",
            email: "persistence.failure@example.test",
            role: "VERIFICATION_ADMIN",
          },
          "Sakhi Super Admin",
        ),
      ).rejects.toThrow(ServiceUnavailableException);
      expect(SakhiAdminRbacRegistry.findStaffByToken(customToken)).toBeNull();
    } finally {
      SakhiAdminRbacRegistry.resetForTesting();
    }
  });
  it("allows the staging reviewer to read the real member directory", async () => {
    configureStagingReviewer();
    const prisma = {
      adminStaffAccount: { findMany: vi.fn().mockResolvedValue([stagingStaffRow()]) },
      auditEvent: { findMany: vi.fn().mockResolvedValue([]) },
      memberAccount: {
        findMany: vi.fn().mockResolvedValue([]),
        count: vi.fn().mockResolvedValue(0),
      },
      eligibilitySubmission: {
        count: vi.fn().mockResolvedValue(0),
      },
    } as unknown as PrismaService;
    const staffSession = await createStagingStaffSession(prisma);
    const service = new AdminReviewService(prisma);

    await expect(service.members(staffSession, "1", "1")).resolves.toMatchObject({
      total: 0,
      page: 1,
      pageSize: 1,
      items: [],
      summary: {
        totalAccounts: 0,
        activeAccounts: 0,
        pendingAccounts: 0,
        verifiedAccounts: 0,
        rejectedAccounts: 0,
        pendingManualReviews: 0,
      },
    });
  });

  it("masks member DOB, email, and phone from ordinary staging reviewers even when full-admin mode is enabled", async () => {
    configureStagingReviewer();
    process.env.SAKHI_STAGING_FULL_ADMIN_ENABLED = "true";
    process.env.SAKHI_STAGING_FULL_ADMIN_TOKEN = "b".repeat(64);
    const account = {
      id: "8b1cae61-1111-4111-8111-111111111111",
      phoneE164: "+15551234567",
      createdAt: new Date("2026-01-01T00:00:00.000Z"),
      status: "PENDING_VERIFICATION",
      verificationStatus: "UNVERIFIED",
      profile: {
        displayName: "Test Member",
        dateOfBirth: new Date("1990-01-02T00:00:00.000Z"),
        email: "member.private@example.com",
      },
      eligibilitySubmissions: [],
      sessions: [],
    };
    const prisma = {
      adminStaffAccount: { findMany: vi.fn().mockResolvedValue([stagingStaffRow()]) },
      auditEvent: { findMany: vi.fn().mockResolvedValue([]) },
      memberAccount: {
        findMany: vi.fn().mockResolvedValue([account]),
        count: vi.fn().mockResolvedValue(1),
      },
      eligibilitySubmission: {
        count: vi.fn().mockResolvedValue(0),
      },
    } as unknown as PrismaService;
    const staffSession = await createStagingStaffSession(prisma);
    const service = new AdminReviewService(prisma);

    const result = await service.members(staffSession, "1", "1");

    expect(result.items[0]).toMatchObject({
      dateOfBirth: null,
      phoneMasked: "********4567",
      phoneE164: "********4567",
      emailMasked: "m********@example.com",
    });
    expect(result.items[0]?.email).toBeUndefined();
  });

  it("blocks direct member-state overrides and demo-data seeding in staging", async () => {
    configureStagingReviewer();
    const prisma = {
      adminStaffAccount: { findMany: vi.fn().mockResolvedValue([stagingStaffRow()]) },
      auditEvent: { findMany: vi.fn().mockResolvedValue([]) },
    } as unknown as PrismaService;
    const staffSession = await createStagingStaffSession(prisma);
    const service = new AdminReviewService(prisma);

    await expect(service.updateMemberState(
      "8b1cae61-1111-4111-8111-111111111111",
      {
        accountStatus: "ACTIVE",
        verificationStatus: "VERIFIED",
        reason: "Local test override must be blocked in staging.",
      } as never,
      staffSession,
    )).rejects.toBeInstanceOf(ForbiddenException);

    await expect(service.seedLiveData(staffSession)).rejects.toBeInstanceOf(ForbiddenException);
  });

  it("queries the explicit pending-submission table rather than all consented profiles", async () => {
    configureLocalReviewer();
    const prisma = {
      eligibilitySubmission: {
        findMany: vi.fn().mockResolvedValue([]),
      },
    } as unknown as PrismaService;
    const service = new AdminReviewService(prisma);

    await expect(service.queue(reviewerToken)).resolves.toEqual([]);
    expect(prisma.eligibilitySubmission.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { status: "PENDING_MANUAL_REVIEW" },
        orderBy: { submittedAt: "asc" },
        take: 100,
      }),
    );
  });

  it("rejects a decision if another reviewer has already claimed the submission", async () => {
    configureLocalReviewer();
    const tx = {
      eligibilitySubmission: {
        findUnique: vi.fn().mockResolvedValue({
          id: "8b1cae61-2222-4222-8222-222222222222",
          accountId: "8b1cae61-1111-4111-8111-111111111111",
          status: "PENDING_MANUAL_REVIEW",
          account: {
            id: "8b1cae61-1111-4111-8111-111111111111",
            status: "PENDING_VERIFICATION",
            verificationStatus: "UNVERIFIED",
            profile: { accountId: "8b1cae61-1111-4111-8111-111111111111" },
          },
        }),
        updateMany: vi.fn().mockResolvedValue({ count: 0 }),
      },
      memberAccount: { updateMany: vi.fn() },
      auditEvent: { create: vi.fn() },
    };
    const prisma = {
      $transaction: vi.fn(async (callback: (transaction: typeof tx) => Promise<unknown>) => callback(tx)),
    } as unknown as PrismaService;
    const service = new AdminReviewService(prisma);

    await expect(service.decide(
      "8b1cae61-2222-4222-8222-222222222222",
      { decision: "approve", reason: "Review completed with required procedure.", reviewedEvidence: true },
      reviewerToken,
    )).rejects.toBeInstanceOf(ConflictException);

    expect(tx.memberAccount.updateMany).not.toHaveBeenCalled();
    expect(tx.auditEvent.create).not.toHaveBeenCalled();
  });

  it("refuses local reviewer-token access when the backend binds to a network interface", async () => {
    process.env.SAKHI_ENV = "dev";
    process.env.NODE_ENV = "test";
    process.env.HOST = "0.0.0.0";
    process.env.SAKHI_ADMIN_REVIEW_TOKEN = "a".repeat(64);
    const service = new AdminReviewService({} as PrismaService);
    await expect(service.session("a".repeat(64))).rejects.toThrow(ForbiddenException);
  });
  it("persists and returns the admin-configured minimum registration age policy", async () => {
    configureLocalReviewer();
    const upsertMock = vi.fn().mockResolvedValue({});
    const auditCreateMock = vi.fn().mockResolvedValue({ id: "audit-1" });
    const transactionClient = {
      platformRegistrationPolicy: { upsert: upsertMock },
      auditEvent: { create: auditCreateMock },
    };
    const prisma = {
      platformRegistrationPolicy: {
        findUnique: vi.fn().mockResolvedValue(null),
        upsert: upsertMock,
      },
      auditEvent: {
        findFirst: vi.fn().mockResolvedValue(null),
        create: auditCreateMock,
      },
      $transaction: vi.fn(
        async (callback: (client: typeof transactionClient) => Promise<unknown>) =>
          callback(transactionClient),
      ),
    } as unknown as PrismaService;
    const service = new AdminReviewService(prisma);

    const updated = await service.updateRegistrationPolicy(
      {
        minimumAgeYears: 21,
        reason: "Raising minimum registration age to 21 for new cohort testing.",
      },
      reviewerToken,
    );

    expect(updated).toMatchObject({
      configured: true,
      minimumAgeYears: 21,
      source: "database_admin_policy",
      updatedBy: "QA Reviewer",
    });
    expect(upsertMock).toHaveBeenCalledOnce();
    expect(auditCreateMock).toHaveBeenCalledOnce();
  });
  it("commits business listings to the primary table and audit log in one transaction", async () => {
    configureLocalReviewer();
    SakhiAdminRbacRegistry.resetForTesting();
    const rows: Record<string, any>[] = [];
    const upsert = vi.fn(async (args: Record<string, any>) => {
      const existing = rows.find((item) => item.id === args.where.id);
      if (existing) Object.assign(existing, args.update);
      else rows.push({ ...args.create });
      return rows.find((item) => item.id === args.where.id);
    });
    const auditCreate = vi.fn().mockResolvedValue({ id: "business-audit-1" });
    const transactionClient = {
      businessDirectoryListing: { upsert },
      auditEvent: { create: auditCreate },
    };
    const prisma = {
      adminStaffAccount: { findMany: vi.fn().mockResolvedValue([]) },
      businessDirectoryListing: {
        findMany: vi.fn(async () => rows),
        upsert,
      },
      auditEvent: {
        findMany: vi.fn().mockResolvedValue([]),
        create: auditCreate,
      },
      platformConfigSetting: {
        findUnique: vi.fn().mockResolvedValue(null),
      },
      $transaction: vi.fn(
        async (callback: (client: typeof transactionClient) => Promise<unknown>) =>
          callback(transactionClient),
      ),
    } as unknown as PrismaService;

    try {
      const service = new AdminReviewService(prisma);
      const result = await service.upsertBusiness(
        {
          businessName: "Sakhi Durable Test Studio",
          ownerDisplayName: "Staging Test Owner",
          category: "Fashion and clothing",
          city: "Tirupati",
          serviceArea: "Tirupati and nearby towns",
          priceRange: "₹800 – ₹3,000",
          description: "Temporary staging verification listing.",
          logoAsset: "https://assets.example.test/logo.webp",
          coverImage: "https://assets.example.test/cover.webp",
          mediaGallery: ["https://assets.example.test/item-1.webp"],
          businessHours: { monday: "09:00-18:00" },
          hidePhoneNumber: true,
          whatsappNumber: "+919876543210",
          instagramHandle: "sakhi_test_shop",
          productsServices: [{ name: "Handmade bags", price: 1200 }],
          offersAndPosts: [{ title: "Opening offer" }],
        },
        reviewerToken,
      );

      expect(result.saved).toBe(true);
      expect(result.business.businessName).toBe("Sakhi Durable Test Studio");
      expect(prisma.$transaction).toHaveBeenCalledOnce();
      expect(upsert).toHaveBeenCalledOnce();
      expect(auditCreate).toHaveBeenCalledOnce();

      const directory = await service.listBusinesses(reviewerToken);
      expect(directory.businesses).toHaveLength(1);
      expect(directory.businesses[0]).toMatchObject({
        businessName: "Sakhi Durable Test Studio",
        serviceArea: "Tirupati and nearby towns",
        priceRange: "₹800 – ₹3,000",
        logoAsset: "https://assets.example.test/logo.webp",
        coverImage: "https://assets.example.test/cover.webp",
        mediaGallery: ["https://assets.example.test/item-1.webp"],
        businessHours: { monday: "09:00-18:00" },
        hidePhoneNumber: true,
        whatsappNumber: "+919876543210",
        instagramHandle: "sakhi_test_shop",
        productsServices: [{ name: "Handmade bags", price: 1200 }],
        offersAndPosts: [{ title: "Opening offer" }],
      });
    } finally {
      SakhiAdminRbacRegistry.resetForTesting();
    }
  });

  it("does not report a business listing saved when the primary table write fails", async () => {
    configureLocalReviewer();
    SakhiAdminRbacRegistry.resetForTesting();
    const upsert = vi.fn().mockRejectedValue(new Error("database unavailable"));
    const auditCreate = vi.fn().mockResolvedValue({ id: "should-not-commit" });
    const transactionClient = {
      businessDirectoryListing: { upsert },
      auditEvent: { create: auditCreate },
    };
    const prisma = {
      adminStaffAccount: { findMany: vi.fn().mockResolvedValue([]) },
      businessDirectoryListing: {
        findMany: vi.fn().mockResolvedValue([]),
        upsert,
      },
      auditEvent: {
        findMany: vi.fn().mockResolvedValue([]),
        create: auditCreate,
      },
      platformConfigSetting: {
        findUnique: vi.fn().mockResolvedValue(null),
      },
      $transaction: vi.fn(
        async (callback: (client: typeof transactionClient) => Promise<unknown>) =>
          callback(transactionClient),
      ),
    } as unknown as PrismaService;

    try {
      const service = new AdminReviewService(prisma);
      await expect(
        service.upsertBusiness(
          {
            businessName: "Sakhi Failed Persistence Test",
            ownerDisplayName: "Staging Test Owner",
            category: "Fashion and clothing",
            city: "Tirupati",
          },
          reviewerToken,
        ),
      ).rejects.toThrow(ServiceUnavailableException);

      expect(upsert).toHaveBeenCalledOnce();
      expect(auditCreate).not.toHaveBeenCalled();

      const directory = await service.listBusinesses(reviewerToken);
      expect(directory.businesses).toHaveLength(0);
    } finally {
      SakhiAdminRbacRegistry.resetForTesting();
    }
  });
  it("does not report staff deletion success or remove the active registry entry when persistence fails", async () => {
    configureLocalReviewer();
    SakhiAdminRbacRegistry.resetForTesting();
    let staffRow: Record<string, any> | null = null;
    const transactionClient = {
      adminStaffAccount: {
        create: vi.fn(async ({ data }: any) => {
          staffRow = { ...data };
          return staffRow;
        }),
        findUnique: vi.fn(async () => staffRow),
        count: vi.fn().mockResolvedValue(2),
        updateMany: vi.fn().mockRejectedValue(new Error("simulated database failure")),
        upsert: vi.fn(async ({ create, update }: any) => {
          staffRow = staffRow ? { ...staffRow, ...update } : { ...create };
          return staffRow;
        }),
      },
      adminStaffSession: { updateMany: vi.fn().mockResolvedValue({ count: 0 }) },
      adminStaffBackupCode: { updateMany: vi.fn().mockResolvedValue({ count: 0 }) },
      adminStaffRecoveryRequest: { updateMany: vi.fn().mockResolvedValue({ count: 0 }) },
      auditEvent: { create: vi.fn().mockResolvedValue({ id: "audit-id" }) },
    };
    const prisma = {
      adminStaffAccount: {
        findMany: vi.fn(async () => (staffRow ? [staffRow] : [])),
      },
      auditEvent: { findMany: vi.fn().mockResolvedValue([]) },
      $transaction: vi.fn(
        async (callback: (client: typeof transactionClient) => Promise<unknown>) =>
          callback(transactionClient),
      ),
    } as unknown as PrismaService;

    try {
      const created = await SakhiAdminRbacRegistry.createStaffAccount(
        prisma,
        { fullName: "Security Test Admin", email: "security-test@sakhi.test", role: "VERIFICATION_ADMIN" },
        "Security Test",
      );
      await expect(
        SakhiAdminRbacRegistry.deleteStaffAccount(
          prisma,
          created.staff.id,
          "Security Test Super Admin",
        ),
      ).rejects.toThrow(ServiceUnavailableException);
      expect(SakhiAdminRbacRegistry.findStaffByToken(created.issuedAccessToken)).not.toBeNull();
      expect(transactionClient.adminStaffAccount.updateMany).toHaveBeenCalledOnce();
    } finally {
      SakhiAdminRbacRegistry.resetForTesting();
    }
  });

  it("does not treat profile-only business names as approved directory listings", async () => {
    configureLocalReviewer();
    SakhiAdminRbacRegistry.resetForTesting();
    const memberProfileFindMany = vi.fn().mockResolvedValue([
      {
        accountId: "0891332c-2add-45f6-8ed1-cab2325606e7",
        displayName: "Member With Profile Business Name",
        businessProfileName: "Profile-Only Business",
        businessCategory: "Fashion and clothing",
        location: "Tirupati",
        bio: "Profile bio",
        businessProfileUrl: null,
        createdAt: new Date("2026-01-01T00:00:00.000Z"),
        updatedAt: new Date("2026-01-01T00:00:00.000Z"),
      },
    ]);
    const prisma = {
      adminStaffAccount: { findMany: vi.fn().mockResolvedValue([]) },
      businessDirectoryListing: {
        findMany: vi.fn().mockResolvedValue([]),
      },
      memberProfile: { findMany: memberProfileFindMany },
      auditEvent: { findMany: vi.fn().mockResolvedValue([]) },
      platformConfigSetting: {
        findUnique: vi.fn().mockResolvedValue(null),
      },
    } as unknown as PrismaService;

    try {
      const service = new AdminReviewService(prisma);
      const result = await service.listBusinesses(reviewerToken);

      expect(result.metrics.totalBusinesses).toBe(0);
      expect(result.businesses).toEqual([]);
      expect(memberProfileFindMany).not.toHaveBeenCalled();
    } finally {
      SakhiAdminRbacRegistry.resetForTesting();
    }
  });
});
