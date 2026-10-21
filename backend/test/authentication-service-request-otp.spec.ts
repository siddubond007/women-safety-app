import "reflect-metadata";

import { createHash } from "node:crypto";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { PrismaService } from "../src/database/prisma.service.js";
import { AuthenticationService } from "../src/auth/auth.service.js";

const ENV_KEYS = [
  "SAKHI_ENV",
  "NODE_ENV",
  "SAKHI_OTP_MODE",
  "HOST",
  "SAKHI_PREVIEW_MINIMUM_AGE_YEARS",
  "SAKHI_STAGING_TEST_PHONE_ALLOWLIST",
  "SAKHI_STAGING_TEST_OTP_CODE",
  "SAKHI_STAGING_TEST_MINIMUM_AGE_YEARS",
] as const;

const ORIGINAL_ENV = Object.fromEntries(
  ENV_KEYS.map((key) => [key, process.env[key]]),
) as Record<(typeof ENV_KEYS)[number], string | undefined>;

function createService(account: { id: string; status?: string } | null) {
  const tx = {
    otpChallenge: {
      count: vi.fn().mockResolvedValue(0),
      create: vi.fn().mockResolvedValue({ id: "challenge-id" }),
      findUnique: vi.fn(),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      update: vi.fn().mockResolvedValue({ id: "challenge-id" }),
    },
    memberAccount: {
      findUnique: vi.fn().mockResolvedValue(account),
      create: vi.fn().mockResolvedValue({
        id: "created-account",
        status: "PENDING_VERIFICATION",
      }),
      update: vi.fn().mockResolvedValue({ id: account?.id ?? "account-id" }),
    },
    memberProfile: {
      findUnique: vi.fn().mockResolvedValue(null),
      create: vi.fn().mockResolvedValue({ accountId: "account-id" }),
      upsert: vi.fn(),
    },
    policyDocumentVersion: {
      findFirst: vi.fn().mockResolvedValue(null),
    },
    memberConsent: {
      findFirst: vi.fn().mockResolvedValue(null),
      create: vi.fn().mockResolvedValue({ id: "consent-id" }),
    },
    memberCommunicationPreference: {
      upsert: vi.fn().mockResolvedValue({ accountId: "account-id" }),
    },
    authSession: {
      create: vi.fn().mockResolvedValue({ id: "session-id" }),
    },
    auditEvent: {
      createMany: vi.fn().mockResolvedValue({ count: 1 }),
    },
  };

  const prisma = {
    authSession: {
      findUnique: vi.fn(),
    },
    memberProfile: {
      findUnique: vi.fn(),
    },
    $transaction: vi.fn(
      async (callback: (transaction: typeof tx) => Promise<unknown>) =>
        callback(tx),
    ),
  };

  return {
    service: new AuthenticationService(prisma as unknown as PrismaService),
    tx,
    prisma,
  };
}

describe("AuthenticationService.requestOtp account checks", () => {
  beforeEach(() => {
    process.env.SAKHI_ENV = "test";
    process.env.NODE_ENV = "development";
    process.env.SAKHI_OTP_MODE = "development";
    process.env.HOST = "127.0.0.1";
    process.env.SAKHI_PREVIEW_MINIMUM_AGE_YEARS = "13";
  });

  afterEach(() => {
    for (const key of ENV_KEYS) {
      const value = ORIGINAL_ENV[key];
      if (value === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    }
    vi.restoreAllMocks();
  });

  it("rejects login for an unregistered number without creating a challenge", async () => {
    const { service, tx } = createService(null);

    await expect(
      service.requestOtp({
        countryCode: "+91",
        phoneNumber: "9876543210",
        purpose: "login",
      }),
    ).rejects.toThrow(
      "No Sakhi account was found for this number. Choose Create account to register.",
    );

    expect(tx.memberAccount.findUnique).toHaveBeenCalledOnce();
    expect(tx.otpChallenge.create).not.toHaveBeenCalled();
    expect(tx.auditEvent.createMany).not.toHaveBeenCalled();
  });

  it("rejects registration OTP requests when the number already has an account", async () => {
    const { service, tx } = createService({ id: "existing-account" });

    await expect(
      service.requestOtp({
        countryCode: "+91",
        phoneNumber: "9876543210",
        purpose: "registration",
      }),
    ).rejects.toThrow(
      "A Sakhi account already exists for this number. Choose Sign in instead.",
    );

    expect(tx.memberAccount.findUnique).toHaveBeenCalledOnce();
    expect(tx.otpChallenge.create).not.toHaveBeenCalled();
    expect(tx.auditEvent.createMany).not.toHaveBeenCalled();
  });

  it("rejects a registration challenge at verification if the account now exists", async () => {
    const challengeId = "6c12c04a-7a85-411b-9b8a-c2c5902bce00";
    const code = "123456";
    const digest = createHash("sha256")
      .update(challengeId + ":" + code)
      .digest("hex");
    const { service, tx } = createService({
      id: "existing-account",
      status: "ACTIVE",
    });

    tx.otpChallenge.findUnique.mockResolvedValue({
      id: challengeId,
      consumedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
      attemptCount: 0,
      attemptLimit: 5,
      codeDigest: digest,
      phoneE164: "+919876543210",
      purpose: "REGISTRATION",
      accountId: null,
    });

    const result = await service.verifyOtp({ challengeId, code });

    expect(result).toMatchObject({
      status: "invalid",
      message:
        "A Sakhi account already exists for this number. Choose Sign in instead.",
    });
    expect(tx.otpChallenge.update).toHaveBeenCalledWith({
      where: { id: challengeId },
      data: { consumedAt: expect.any(Date) },
    });
    expect(tx.memberAccount.create).not.toHaveBeenCalled();
    expect(tx.memberAccount.update).not.toHaveBeenCalled();
    expect(tx.authSession.create).not.toHaveBeenCalled();
    expect(tx.memberProfile.create).not.toHaveBeenCalled();
  });

  it("does not overwrite an existing profile through the create-profile endpoint", async () => {
    const { service, tx, prisma } = createService({
      id: "existing-account",
      status: "ACTIVE",
    });
    prisma.authSession.findUnique.mockResolvedValue({
      accountId: "existing-account",
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
      account: { status: "ACTIVE" },
    });
    tx.memberProfile.findUnique.mockResolvedValue({
      accountId: "existing-account",
    });

    await expect(
      service.createProfile("Bearer " + "x".repeat(32), {
        displayName: "Changed Name",
        dateOfBirth: "1990-01-01",
        termsVersion: "draft",
        privacyVersion: "draft",
        acceptedAt: new Date().toISOString(),
        optionalUpdatesAccepted: false,
      }),
    ).rejects.toThrow(
      "A profile already exists for this account. Use the profile-management flow to make changes.",
    );

    expect(tx.memberProfile.create).not.toHaveBeenCalled();
    expect(tx.memberProfile.upsert).not.toHaveBeenCalled();
    expect(tx.memberConsent.create).not.toHaveBeenCalled();
    expect(tx.memberCommunicationPreference.upsert).not.toHaveBeenCalled();
  });

  it("still allows an unregistered number to request a registration challenge", async () => {
    const { service, tx } = createService(null);

    const result = await service.requestOtp({
      countryCode: "+91",
      phoneNumber: "9876543210",
      purpose: "registration",
    });

    expect(result.challengeId).toBeTruthy();
    expect(result.developmentCode).toMatch(/^\d{6}$/);
    expect(tx.otpChallenge.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          phoneE164: "+919876543210",
          purpose: "REGISTRATION",
          accountId: null,
        }),
      }),
    );
  });

  it("accepts an arbitrary valid Indian mobile number only in staging test mode and never echoes the shared code", async () => {
    process.env.SAKHI_ENV = "staging";
    process.env.NODE_ENV = "production";
    process.env.SAKHI_OTP_MODE = "staging_test";
    process.env.HOST = "0.0.0.0";
    process.env.SAKHI_PREVIEW_MINIMUM_AGE_YEARS = "";
    process.env.SAKHI_STAGING_TEST_PHONE_ALLOWLIST = "+91*";
    process.env.SAKHI_STAGING_TEST_OTP_CODE = "314159";
    process.env.SAKHI_STAGING_TEST_MINIMUM_AGE_YEARS = "18";

    const { service, tx } = createService(null);
    const result = await service.requestOtp({
      countryCode: "+91",
      phoneNumber: "9123456789",
      purpose: "registration",
    });

    expect(result.deliveryMode).toBe("staging_test_shared_code");
    expect(result).not.toHaveProperty("developmentCode");
    expect(result.message).toMatch(/does not verify phone ownership or eligibility/);
    expect(tx.otpChallenge.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          phoneE164: "+919123456789",
          codeDigest: expect.stringMatching(/^[a-f0-9]{64}$/),
        }),
      }),
    );

    await expect(
      service.requestOtp({
        countryCode: "+91",
        phoneNumber: "5123456789",
        purpose: "registration",
      }),
    ).rejects.toThrow(/not enabled for Sakhi staging test access/);
  });

  it("allows wildcard-accepted staging phones to create profiles and restore test access", async () => {
    process.env.SAKHI_ENV = "staging";
    process.env.NODE_ENV = "production";
    process.env.SAKHI_OTP_MODE = "staging_test";
    process.env.HOST = "0.0.0.0";
    process.env.SAKHI_PREVIEW_MINIMUM_AGE_YEARS = "";
    process.env.SAKHI_STAGING_TEST_PHONE_ALLOWLIST = "+91*";
    process.env.SAKHI_STAGING_TEST_OTP_CODE = "314159";
    process.env.SAKHI_STAGING_TEST_MINIMUM_AGE_YEARS = "18";

    const phoneE164 = "+919123456789";
    const authorization = "Bearer " + "x".repeat(32);
    const account = {
      id: "staging-account",
      status: "PENDING_VERIFICATION",
      verificationStatus: "UNVERIFIED",
      phoneE164,
    };
    const { service, tx, prisma } = createService({
      id: "staging-account",
      status: "PENDING_VERIFICATION",
    });
    prisma.authSession.findUnique.mockResolvedValue({
      id: "staging-session",
      accountId: "staging-account",
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
      account,
    });
    tx.policyDocumentVersion.findFirst.mockImplementation(
      async (args: { where: { documentType: string } }) => ({
        id: args.where.documentType === "TERMS" ? "terms-id" : "privacy-id",
      }),
    );
    tx.memberProfile.create.mockResolvedValue({
      accountId: "staging-account",
      displayName: "Sadhana",
      dateOfBirth: new Date("2001-10-11T00:00:00.000Z"),
      email: null,
    });

    const result = await service.createProfile(authorization, {
      displayName: "Sadhana",
      dateOfBirth: "2001-10-11",
      termsVersion: "draft",
      privacyVersion: "draft",
      acceptedAt: new Date().toISOString(),
      optionalUpdatesAccepted: false,
    });

    expect(result).toMatchObject({
      accountState: "existingAccount",
      testAccess: true,
    });
    expect(tx.memberProfile.create).toHaveBeenCalledOnce();
    expect(tx.memberConsent.create).toHaveBeenCalledOnce();

    prisma.memberProfile.findUnique.mockResolvedValue({
      displayName: "Sadhana",
      dateOfBirth: new Date("2001-10-11T00:00:00.000Z"),
      email: null,
    });
    const restored = await service.getCurrentAccount(authorization);
    expect(restored.testAccess).toBe(true);
    expect(restored.profile).toMatchObject({ displayName: "Sadhana" });
  });
});
