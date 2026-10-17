import { afterEach, describe, expect, it, vi } from "vitest";
import { ForbiddenException, ConflictException, UnauthorizedException, ServiceUnavailableException } from "@nestjs/common";
import { AdminReviewService } from "../src/admin-review/admin-review.service.js";
import type { PrismaService } from "../src/database/prisma.service.js";

const originalToken = process.env.SAKHI_ADMIN_REVIEW_TOKEN;
const originalLabel = process.env.SAKHI_ADMIN_REVIEWER_LABEL;
const originalEnvironment = process.env.SAKHI_ENV;
const originalNodeEnvironment = process.env.NODE_ENV;
const originalHost = process.env.HOST;
const reviewerToken = "a".repeat(64);

function configureLocalReviewer() {
  process.env.SAKHI_ENV = "test";
  process.env.NODE_ENV = "test";
  process.env.SAKHI_ADMIN_REVIEW_TOKEN = reviewerToken;
  process.env.SAKHI_ADMIN_REVIEWER_LABEL = "QA Reviewer";
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
  });});
