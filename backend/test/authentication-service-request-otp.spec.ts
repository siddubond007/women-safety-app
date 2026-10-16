import "reflect-metadata";

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { PrismaService } from "../src/database/prisma.service.js";
import { AuthenticationService } from "../src/auth/auth.service.js";

const ENV_KEYS = [
  "SAKHI_ENV",
  "NODE_ENV",
  "SAKHI_OTP_MODE",
  "HOST",
] as const;

const ORIGINAL_ENV = Object.fromEntries(
  ENV_KEYS.map((key) => [key, process.env[key]]),
) as Record<(typeof ENV_KEYS)[number], string | undefined>;

function createService(account: { id: string } | null) {
  const tx = {
    otpChallenge: {
      count: vi.fn().mockResolvedValue(0),
      create: vi.fn().mockResolvedValue({ id: "challenge-id" }),
    },
    memberAccount: {
      findUnique: vi.fn().mockResolvedValue(account),
    },
    auditEvent: {
      createMany: vi.fn().mockResolvedValue({ count: 1 }),
    },
  };

  const prisma = {
    $transaction: vi.fn(
      async (callback: (transaction: typeof tx) => Promise<unknown>) =>
        callback(tx),
    ),
  } as unknown as PrismaService;

  return { service: new AuthenticationService(prisma), tx };
}

describe("AuthenticationService.requestOtp account checks", () => {
  beforeEach(() => {
    process.env.SAKHI_ENV = "test";
    process.env.NODE_ENV = "development";
    process.env.SAKHI_OTP_MODE = "development";
    process.env.HOST = "127.0.0.1";
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
});
