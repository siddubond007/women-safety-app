import { BadRequestException } from "@nestjs/common";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AuthenticationService } from "../src/auth/auth.service.js";
import { PrismaService } from "../src/database/prisma.service.js";

const environmentKeys = [
  "SAKHI_ENV",
  "NODE_ENV",
  "SAKHI_OTP_MODE",
  "HOST",
] as const;

const originalEnvironment = Object.fromEntries(
  environmentKeys.map((key) => [key, process.env[key]]),
) as Record<(typeof environmentKeys)[number], string | undefined>;

function enableLocalDevelopmentOtp(): void {
  process.env.SAKHI_ENV = "dev";
  process.env.NODE_ENV = "test";
  process.env.SAKHI_OTP_MODE = "development";
  process.env.HOST = "127.0.0.1";
}

function restoreEnvironment(): void {
  for (const key of environmentKeys) {
    const previous = originalEnvironment[key];
    if (previous === undefined) {
      delete process.env[key];
    } else {
      process.env[key] = previous;
    }
  }
}

function createHarness(account: { id: string } | null) {
  const tx = {
    otpChallenge: {
      count: vi.fn().mockResolvedValue(0),
      create: vi.fn().mockResolvedValue({}),
    },
    memberAccount: {
      findUnique: vi.fn().mockResolvedValue(account),
    },
    auditEvent: {
      create: vi.fn().mockResolvedValue({ id: "audit-id" }),
    },
  };
  const transaction = vi.fn(
    async (callback: (tx: unknown) => Promise<unknown>) => callback(tx),
  );
  const prisma = { $transaction: transaction } as unknown as PrismaService;

  return {
    service: new AuthenticationService(prisma),
    tx,
    transaction,
  };
}

describe("development authentication service", () => {
  afterEach(() => {
    restoreEnvironment();
    vi.restoreAllMocks();
  });

  it("does not issue an OTP challenge for an unregistered sign-in number", async () => {
    enableLocalDevelopmentOtp();
    const { service, tx, transaction } = createHarness(null);

    const error = await service
      .requestOtp({
        countryCode: "+91",
        phoneNumber: "9876543210",
        purpose: "login",
      })
      .catch((caught: unknown) => caught);

    expect(error).toBeInstanceOf(BadRequestException);
    expect(error).toHaveProperty(
      "message",
      "No Sakhi account was found for this number. Choose Create account to register.",
    );
    expect(transaction).toHaveBeenCalledTimes(1);
    expect(tx.memberAccount.findUnique).toHaveBeenCalled();
    expect(tx.otpChallenge.create).not.toHaveBeenCalled();
    expect(tx.auditEvent.create).not.toHaveBeenCalled();
  });

  it("still allows an unregistered number to start explicit registration", async () => {
    enableLocalDevelopmentOtp();
    const { service, tx } = createHarness(null);

    const result = await service.requestOtp({
      countryCode: "+91",
      phoneNumber: "9876543210",
      purpose: "registration",
    });

    expect(result.deliveryMode).toBe("development_echo");
    expect(result.isDemo).toBe(true);
    expect(result.developmentCode).toMatch(/^\d{6}$/);
    expect(tx.otpChallenge.create).toHaveBeenCalledTimes(1);
    expect(tx.auditEvent.create).toHaveBeenCalledTimes(1);
  });
});
