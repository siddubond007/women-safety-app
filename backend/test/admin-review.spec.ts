import { afterEach, describe, expect, it, vi } from "vitest";
import { ForbiddenException, ConflictException, UnauthorizedException, ServiceUnavailableException } from "@nestjs/common";
import { AdminReviewService } from "../src/admin-review/admin-review.service.js";
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
const reviewerToken = "a".repeat(64);

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

describe("AdminReviewService reviewer-token boundary", () => {
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
    vi.restoreAllMocks();
  });

  it("fails closed when the shared local reviewer token is not configured", () => {
    process.env.HOST = "127.0.0.1";
    process.env.SAKHI_ENV = "dev";
    delete process.env.SAKHI_ADMIN_REVIEW_TOKEN;
    const service = new AdminReviewService({} as PrismaService);
    expect(() => service.session("anything-long-enough-to-look-like-a-token"))
      .toThrow(ServiceUnavailableException);
  });

  it("rejects a token that does not match the configured local secret", () => {
    configureLocalReviewer();
    const service = new AdminReviewService({} as PrismaService);
    expect(() => service.session("b".repeat(64))).toThrow(UnauthorizedException);
  });

  it("accepts the configured token and returns the server-configured local reviewer label", () => {
    configureLocalReviewer();
    const service = new AdminReviewService({} as PrismaService);
    expect(service.session(reviewerToken)).toEqual({
      authenticated: true,
      reviewerLabel: "QA Reviewer",
      mode: "local_dev_test_only",
    });
  });

  it("allows the shared reviewer portal in staging only with every explicit test gate enabled", () => {
    configureStagingReviewer();
    const service = new AdminReviewService({} as PrismaService);
    expect(service.session(reviewerToken)).toEqual({
      authenticated: true,
      reviewerLabel: "Staging QA Reviewer",
      mode: "staging_test_only",
    });
  });

  it("fails closed when the explicit staging admin gate is not enabled", () => {
    configureStagingReviewer();
    process.env.SAKHI_STAGING_ADMIN_REVIEW_ENABLED = "false";
    const service = new AdminReviewService({} as PrismaService);
    expect(() => service.session(reviewerToken)).toThrow(ForbiddenException);
  });

  it("allows the staging reviewer to read the real member directory", async () => {
    configureStagingReviewer();
    const prisma = {
      memberAccount: {
        findMany: vi.fn().mockResolvedValue([]),
        count: vi.fn().mockResolvedValue(0),
      },
      eligibilitySubmission: {
        count: vi.fn().mockResolvedValue(0),
      },
    } as unknown as PrismaService;
    const service = new AdminReviewService(prisma);

    await expect(service.members(reviewerToken, "1", "1")).resolves.toMatchObject({
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
      memberAccount: {
        findMany: vi.fn().mockResolvedValue([account]),
        count: vi.fn().mockResolvedValue(1),
      },
      eligibilitySubmission: {
        count: vi.fn().mockResolvedValue(0),
      },
    } as unknown as PrismaService;
    const service = new AdminReviewService(prisma);

    const result = await service.members(reviewerToken, "1", "1");

    const firstMember = result.items[0];
    expect(firstMember).toBeDefined();
    if (!firstMember) {
      throw new Error("Expected the first member in the admin review result.");
    }
    expect(firstMember).toMatchObject({
      dateOfBirth: null,
      phoneMasked: "********4567",
      phoneE164: "********4567",
      emailMasked: "m********@example.com",
    });
    expect(firstMember.email).toBeUndefined();
  });

  it("blocks direct member-state overrides and demo-data seeding in staging", async () => {
    configureStagingReviewer();
    const service = new AdminReviewService({} as PrismaService);

    await expect(service.updateMemberState(
      "8b1cae61-1111-4111-8111-111111111111",
      {
        accountStatus: "ACTIVE",
        verificationStatus: "VERIFIED",
        reason: "Local test override must be blocked in staging.",
      } as never,
      reviewerToken,
    )).rejects.toBeInstanceOf(ForbiddenException);

    await expect(service.seedLiveData(reviewerToken)).rejects.toBeInstanceOf(ForbiddenException);
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

  it("refuses local reviewer-token access when the backend binds to a network interface", () => {
    process.env.SAKHI_ENV = "dev";
    process.env.NODE_ENV = "test";
    process.env.HOST = "0.0.0.0";
    process.env.SAKHI_ADMIN_REVIEW_TOKEN = "a".repeat(64);
    const service = new AdminReviewService({} as PrismaService);
    expect(() => service.session("a".repeat(64))).toThrow(ForbiddenException);
  });
  it("persists and returns the admin-configured minimum registration age policy", async () => {
    configureLocalReviewer();
    const upsertMock = vi.fn().mockResolvedValue({});
    const auditCreateMock = vi.fn().mockResolvedValue({ id: "audit-1" });
    const prisma = {
      platformRegistrationPolicy: {
        findUnique: vi.fn().mockResolvedValue(null),
        upsert: upsertMock,
      },
      auditEvent: {
        findFirst: vi.fn().mockResolvedValue(null),
        create: auditCreateMock,
      },
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
});
