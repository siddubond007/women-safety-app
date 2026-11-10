import { describe, expect, it, vi } from "vitest";
import { PrismaService } from "../src/database/prisma.service.js";
import type { Prisma } from "../src/generated/prisma/client.js";
import { createAuthenticatedMemberIdentity } from "../src/auth/member-identity.js";

describe("PrismaService.withMemberIdentity", () => {
  it("sets transaction-local account context before invoking work on that transaction", async () => {
    const tx = {
      $queryRaw: vi.fn().mockResolvedValue([{ set_config: "account-id" }]),
    };
    const transaction = vi.fn(
      async (callback: (value: typeof tx) => Promise<unknown>) => callback(tx),
    );
    const prisma = Object.create(PrismaService.prototype) as PrismaService;
    Object.defineProperty(prisma, "$transaction", { value: transaction });
    const transactionClient = tx as unknown as Prisma.TransactionClient;
    const operation = vi.fn(async (value: Prisma.TransactionClient) =>
      value === transactionClient ? "scoped-result" : "wrong-client",
    );
    const identity = createAuthenticatedMemberIdentity({
      accountId: "a0b1c2d3-e4f5-4678-9123-456789abcdef",
      sessionId: "b0b1c2d3-e4f5-4678-9123-456789abcdef",
    });

    await expect(prisma.withMemberIdentity(identity, operation)).resolves.toBe(
      "scoped-result",
    );
    expect(transaction).toHaveBeenCalledOnce();
    expect(tx.$queryRaw).toHaveBeenCalledOnce();
    expect(operation).toHaveBeenCalledWith(transactionClient);
    const [queryTemplate, accountIdParameter] =
      tx.$queryRaw.mock.calls[0] ?? [];
    expect(
      Array.from(queryTemplate as TemplateStringsArray).join("?"),
    ).toContain("set_config('app.account_id', ?, true)");
    expect(accountIdParameter).toBe(identity.accountId);
  });

  it("rejects malformed session identity before opening a transaction", async () => {
    const transaction = vi.fn();
    const prisma = Object.create(PrismaService.prototype) as PrismaService;
    Object.defineProperty(prisma, "$transaction", { value: transaction });

    await expect(
      prisma.withMemberIdentity(
        {
          accountId: "a0b1c2d3-e4f5-4678-9123-456789abcdef",
          sessionId: "not-a-session-uuid",
        },
        async () => "unreachable",
      ),
    ).rejects.toThrow(/valid authenticated member identity/);
    expect(transaction).not.toHaveBeenCalled();
  });

  it("rejects malformed identity before opening a transaction", async () => {
    const transaction = vi.fn();
    const prisma = Object.create(PrismaService.prototype) as PrismaService;
    Object.defineProperty(prisma, "$transaction", { value: transaction });

    await expect(
      prisma.withMemberIdentity(
        {
          accountId: "attacker-controlled",
          sessionId: "b0b1c2d3-e4f5-4678-9123-456789abcdef",
        },
        async () => "unreachable",
      ),
    ).rejects.toThrow(/valid authenticated member identity/);
    expect(transaction).not.toHaveBeenCalled();
  });
});
