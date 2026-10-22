import "reflect-metadata";

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { PrismaService } from "../src/database/prisma.service.js";
import { StagingTestAdminService } from "../src/staging-test-admin/staging-test-admin.service.js";

const ENV_KEYS = [
  "SAKHI_ENV",
  "NODE_ENV",
  "SAKHI_STAGING_TEST_ADMIN_ENABLED",
  "SAKHI_STAGING_TEST_ADMIN_TOKEN",
  "SAKHI_STAGING_TEST_ADMIN_REVIEWER_LABEL",
  "SAKHI_STAGING_FULL_ADMIN_ENABLED",
  "SAKHI_STAGING_FULL_ADMIN_TOKEN",
  "SAKHI_STAGING_FULL_ADMIN_REVIEWER_LABEL",
  "SAKHI_ADMIN_CORS_ORIGIN",
] as const;

const ORIGINAL_ENV = Object.fromEntries(
  ENV_KEYS.map((key) => [key, process.env[key]]),
) as Record<(typeof ENV_KEYS)[number], string | undefined>;

function makeService() {
  const tx = {
    auditEvent: {
      create: vi.fn().mockResolvedValue({ id: "audit-id" }),
    },
  };
  const prisma = {
    memberAccount: {
      findMany: vi.fn(),
      findUnique: vi.fn(),
    },
    auditEvent: {
      findMany: vi.fn().mockResolvedValue([]),
      findFirst: vi.fn().mockResolvedValue(null),
    },
    $transaction: vi.fn(async (callback: (transaction: typeof tx) => Promise<unknown>) =>
      callback(tx),
    ),
  };
  return {
    service: new StagingTestAdminService(prisma as unknown as PrismaService),
    prisma,
    tx,
  };
}

describe("StagingTestAdminService", () => {
  beforeEach(() => {
    process.env.SAKHI_ENV = "staging";
    process.env.NODE_ENV = "production";
    process.env.SAKHI_STAGING_TEST_ADMIN_ENABLED = "true";
    process.env.SAKHI_STAGING_TEST_ADMIN_TOKEN = "test-only-secret-token-that-is-over-32-chars";
    process.env.SAKHI_STAGING_TEST_ADMIN_REVIEWER_LABEL = "Friend Testing Reviewer";
    process.env.SAKHI_STAGING_FULL_ADMIN_ENABLED = "true";
    process.env.SAKHI_STAGING_FULL_ADMIN_TOKEN = "full-staging-admin-secret-token-is-over-32-chars";
    process.env.SAKHI_STAGING_FULL_ADMIN_REVIEWER_LABEL = "Staging Super Admin";
    process.env.SAKHI_ADMIN_CORS_ORIGIN = "https://sakhi-staging-admin.onrender.com";
  });

  afterEach(() => {
    for (const key of ENV_KEYS) {
      const value = ORIGINAL_ENV[key];
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
    vi.restoreAllMocks();
  });

  it("requires the separate staging reviewer token and rejects the local token", () => {
    const { service } = makeService();
    expect(() => service.session("ADMIN2026TEST")).toThrow(/invalid/i);
    expect(service.session("test-only-secret-token-that-is-over-32-chars")).toMatchObject({
      authenticated: true,
      reviewerLabel: "Friend Testing Reviewer",
      mode: "staging_test_access_only",
    });
  });

  it("issues a separate full-admin session while rejecting test-only sessions for privileged routes", () => {
    const { service } = makeService();
    const fullToken = "full-staging-admin-secret-token-is-over-32-chars";
    expect(service.session(fullToken)).toMatchObject({
      authenticated: true,
      reviewerLabel: "Staging Super Admin",
      mode: "staging_full_admin",
    });
    const fullSession = service.createSessionToken(fullToken);
    expect(service.sessionFromToken(fullSession.value)).toMatchObject({
      authenticated: true,
      reviewerLabel: "Staging Super Admin",
      mode: "staging_full_admin",
    });
    expect(StagingTestAdminService.assertFullAdminSessionToken(fullSession.value)).toBe("Staging Super Admin");
    const testSession = service.createSessionToken("test-only-secret-token-that-is-over-32-chars");
    expect(() => StagingTestAdminService.assertFullAdminSessionToken(testSession.value)).toThrow(/full staging-admin access/i);
  });

  it("issues an expiring signed session token instead of using the reviewer secret as a session credential", () => {
    const { service } = makeService();
    const token = "test-only-secret-token-that-is-over-32-chars";
    const session = service.createSessionToken(token);

    expect(service.sessionFromToken(session.value)).toMatchObject({
      authenticated: true,
      reviewerLabel: "Friend Testing Reviewer",
      mode: "staging_test_access_only",
    });
    expect(() => service.sessionFromToken(token)).toThrow(/session is invalid/i);
    expect(() => service.assertAdminOrigin("https://untrusted.example")).toThrow(/configured Super Admin origin/i);
    expect(() => service.assertAdminOrigin(undefined)).toThrow(/configured Super Admin origin/i);
    expect(() => service.assertAdminOrigin("https://sakhi-staging-admin.onrender.com")).not.toThrow();
    expect(session.expiresAt.getTime()).toBeGreaterThan(Date.now());
    expect(session.expiresAt.getTime()).toBeLessThanOrEqual(Date.now() + 8 * 60 * 60 * 1000 + 2000);
  });

  it("records a test-only approval in the audit log without mutating real verification fields", async () => {
    const { service, prisma, tx } = makeService();
    const accountId = "30b7f836-0a38-4d43-a30b-9c87b88698a2";
    prisma.memberAccount.findUnique.mockResolvedValue({
      id: accountId,
      status: "PENDING_VERIFICATION",
      verificationStatus: "UNVERIFIED",
      profile: { accountId, displayName: "Friend Tester" },
    });
    prisma.auditEvent.findFirst.mockResolvedValue(null);

    const sessionToken = service.createSessionToken(
      "test-only-secret-token-that-is-over-32-chars",
    ).value;
    const result = await service.approve(
      accountId,
      {
        acknowledgedTestOnly: true,
        reason: "Friend tester needs access to restricted staging features.",
      },
      sessionToken,
    );

    expect(result).toMatchObject({
      accountId,
      testAccessApproved: true,
      status: "test_access_enabled",
    });
    expect(tx.auditEvent.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        action: "staging.test_access.approved",
        targetType: "member_account",
        targetId: accountId,
        outcome: "test_approved",
        redactedMetadata: expect.objectContaining({
          testOnly: true,
          actualEligibilityUnchanged: true,
          reviewerLabel: "Friend Testing Reviewer",
        }),
      }),
    });
    expect(prisma.memberAccount).not.toHaveProperty("update");
  });

  it("records revocation separately and requires a current test approval", async () => {
    const { service, prisma, tx } = makeService();
    const accountId = "30b7f836-0a38-4d43-a30b-9c87b88698a2";
    prisma.memberAccount.findUnique.mockResolvedValue({ id: accountId });
    prisma.auditEvent.findFirst.mockResolvedValue({
      action: "staging.test_access.approved",
      createdAt: new Date(),
    });

    const sessionToken = service.createSessionToken(
      "test-only-secret-token-that-is-over-32-chars",
    ).value;
    const result = await service.revoke(
      accountId,
      {
        acknowledgedTestOnly: true,
        reason: "Friend testing is complete; revoke temporary access.",
      },
      sessionToken,
    );
    expect(result).toMatchObject({
      accountId,
      testAccessApproved: false,
      status: "test_access_revoked",
    });
    expect(tx.auditEvent.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        action: "staging.test_access.revoked",
        targetType: "member_account",
        targetId: accountId,
        outcome: "revoked",
        redactedMetadata: expect.objectContaining({
          testOnly: true,
          actualEligibilityUnchanged: true,
        }),
      }),
    });
  });
});
