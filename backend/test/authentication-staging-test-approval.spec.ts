import "reflect-metadata";

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { PrismaService } from "../src/database/prisma.service.js";
import { AuthenticationService } from "../src/auth/auth.service.js";

const ENV_KEYS = [
  "SAKHI_ENV",
  "NODE_ENV",
  "HOST",
  "SAKHI_OTP_MODE",
  "SAKHI_STAGING_TEST_PHONE_ALLOWLIST",
  "SAKHI_STAGING_TEST_OTP_CODE",
  "SAKHI_STAGING_TEST_MINIMUM_AGE_YEARS",
  "SAKHI_STAGING_TEST_ADMIN_ENABLED",
  "SAKHI_STAGING_TEST_ADMIN_TOKEN",
] as const;
const ORIGINAL_ENV = Object.fromEntries(
  ENV_KEYS.map((key) => [key, process.env[key]]),
) as Record<(typeof ENV_KEYS)[number], string | undefined>;

describe("AuthenticationService staging test approval", () => {
  beforeEach(() => {
    process.env.SAKHI_ENV = "staging";
    process.env.NODE_ENV = "production";
    process.env.HOST = "0.0.0.0";
    process.env.SAKHI_OTP_MODE = "staging_test";
    process.env.SAKHI_STAGING_TEST_PHONE_ALLOWLIST = "+91*";
    process.env.SAKHI_STAGING_TEST_OTP_CODE = "314159";
    process.env.SAKHI_STAGING_TEST_MINIMUM_AGE_YEARS = "18";
    process.env.SAKHI_STAGING_TEST_ADMIN_ENABLED = "true";
    process.env.SAKHI_STAGING_TEST_ADMIN_TOKEN = "staging-admin-token-that-is-more-than-32-characters";
  });

  afterEach(() => {
    for (const key of ENV_KEYS) {
      const value = ORIGINAL_ENV[key];
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
    vi.restoreAllMocks();
  });

  it("honors the latest staging test approval for app authorization without changing actual verification", async () => {
    const account = {
      id: "account-id",
      phoneE164: "+919123456789",
      status: "PENDING_VERIFICATION",
      verificationStatus: "UNVERIFIED",
    };
    const prisma = {
      authSession: {
        findUnique: vi.fn().mockResolvedValue({
          id: "session-id",
          accountId: "account-id",
          tokenDigest: "digest",
          revokedAt: null,
          expiresAt: new Date(Date.now() + 60_000),
          account,
        }),
      },
      auditEvent: {
        findFirst: vi.fn().mockResolvedValue({ action: "staging.test_access.approved" }),
      },
    };
    const service = new AuthenticationService(prisma as unknown as PrismaService);

    const approved = await service.authenticateAuthorization("Bearer " + "x".repeat(32));
    expect(approved.testAccessApproved).toBe(true);
    expect(approved.account.status).toBe("PENDING_VERIFICATION");
    expect(approved.account.verificationStatus).toBe("UNVERIFIED");

    prisma.auditEvent.findFirst.mockResolvedValue({ action: "staging.test_access.revoked" });
    const revoked = await service.authenticateAuthorization("Bearer " + "x".repeat(32));
    expect(revoked.testAccessApproved).toBe(false);
    expect(revoked.account.status).toBe("PENDING_VERIFICATION");
    expect(revoked.account.verificationStatus).toBe("UNVERIFIED");
    expect(prisma.auditEvent.findFirst).toHaveBeenCalledTimes(2);
  });

  it("ignores stored test-approval events unless the dedicated server-side admin gate is enabled", async () => {
    process.env.SAKHI_STAGING_TEST_ADMIN_ENABLED = "false";
    const prisma = {
      authSession: {
        findUnique: vi.fn().mockResolvedValue({
          id: "session-id",
          accountId: "account-id",
          revokedAt: null,
          expiresAt: new Date(Date.now() + 60_000),
          account: {
            id: "account-id",
            phoneE164: "+919123456789",
            status: "PENDING_VERIFICATION",
            verificationStatus: "UNVERIFIED",
          },
        }),
      },
      auditEvent: { findFirst: vi.fn() },
    };
    const service = new AuthenticationService(prisma as unknown as PrismaService);
    const result = await service.authenticateAuthorization("Bearer " + "x".repeat(32));
    expect(result.testAccessApproved).toBe(false);
    expect(prisma.auditEvent.findFirst).not.toHaveBeenCalled();
  });
});
