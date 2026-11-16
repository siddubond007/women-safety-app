import { afterEach, describe, expect, it, vi } from "vitest";
import { AdminReviewService } from "../src/admin-review/admin-review.service.js";
import { SakhiAdminRbacRegistry } from "../src/admin-review/admin-rbac.helper.js";

const ACTOR_ID = "2d5fce37-6aab-4cb4-8a6c-6a2d07f87e91";
const TARGET_ID = "3e6fce37-6aab-4cb4-8a6c-6a2d07f87e92";

function createHarness(failAudit = false) {
  const state = {
    account: {
      id: TARGET_ID,
      staffCode: "#ST-123",
      passwordHash: "old-password-hash",
      passwordUpdatedAt: null as Date | null,
      mustResetPassword: true,
      accessTokenDigest: "a".repeat(64),
      accessTokenPreview: "SAKHI-ST-••••",
      failedLoginAttempts: 4,
      lockedUntil: new Date("2030-01-01T00:00:00.000Z") as Date | null,
    },
    activeSessions: 2,
    audits: [] as Array<Record<string, unknown>>,
  };
  const tx = {
    adminStaffAccount: {
      update: vi.fn(async ({ data }: { data: Record<string, unknown> }) => {
        Object.assign(state.account, data);
        return { id: TARGET_ID, staffCode: "#ST-123" };
      }),
    },
    adminStaffSession: {
      updateMany: vi.fn(async () => {
        const count = state.activeSessions;
        state.activeSessions = 0;
        return { count };
      }),
    },
    auditEvent: {
      create: vi.fn(async ({ data }: { data: Record<string, unknown> }) => {
        if (failAudit) throw new Error("simulated audit persistence failure");
        state.audits.push(data);
        return { id: "audit-test" };
      }),
    },
  };
  const prisma = {
    $transaction: vi.fn(async (callback: (transaction: typeof tx) => Promise<unknown>) => {
      const snapshot = {
        account: { ...state.account },
        activeSessions: state.activeSessions,
        audits: [...state.audits],
      };
      try {
        return await callback(tx);
      } catch (error) {
        // Model the rollback guarantee provided by Prisma/PostgreSQL transactions.
        Object.assign(state.account, snapshot.account);
        state.activeSessions = snapshot.activeSessions;
        state.audits = snapshot.audits;
        throw error;
      }
    }),
  };
  const service = new AdminReviewService(prisma as never);
  vi.spyOn(service, "resolveAdminPrincipal").mockReturnValue({
    staffId: ACTOR_ID,
    role: "SUPER_ADMIN",
  } as never);
  return { state, tx, prisma, service };
}

afterEach(() => {
  vi.restoreAllMocks();
  SakhiAdminRbacRegistry.resetForTesting();
});

describe("admin password change transaction", () => {
  it("changes the password, revokes all active sessions and audits both actions in one transaction", async () => {
    vi.spyOn(SakhiAdminRbacRegistry, "ensureHydrated").mockResolvedValue(undefined);
    const { state, tx, prisma, service } = createHarness();

    await expect(
      service.resetAdminStaffPassword(
        TARGET_ID,
        { newPassword: "Strong-Admin-Password-2026" },
        "staff-admin.test-session",
      ),
    ).resolves.toEqual({
      updated: true,
      staffCode: "#ST-123",
      revokedSessions: 2,
    });

    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(tx.adminStaffAccount.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: TARGET_ID },
        data: expect.objectContaining({
          mustResetPassword: false,
          accessTokenDigest: expect.stringMatching(/^[a-f0-9]{64}$/),
          accessTokenPreview: "REVOKED••••",
          failedLoginAttempts: 0,
          lockedUntil: null,
        }),
      }),
    );
    expect(state.account.passwordHash).not.toBe("old-password-hash");
    expect(state.account.accessTokenDigest).not.toBe("a".repeat(64));
    expect(state.account.accessTokenPreview).toBe("REVOKED••••");
    expect(state.account.passwordHash).not.toContain("Strong-Admin-Password-2026");
    expect(state.activeSessions).toBe(0);
    expect(state.audits).toHaveLength(2);
    expect(state.audits.map((event) => event.action)).toEqual([
      "admin.staff_password.changed",
      "admin.staff_sessions.revoked_all",
    ]);
    expect(JSON.stringify(state.audits)).not.toContain("Strong-Admin-Password-2026");
    expect(state.audits[1]?.redactedMetadata).toEqual({
      reason: "PASSWORD_CHANGED",
      revokedSessions: 2,
    });
  });

  it("rolls back the password update and session revocation if audit persistence fails", async () => {
    vi.spyOn(SakhiAdminRbacRegistry, "ensureHydrated").mockResolvedValue(undefined);
    const { state, tx, prisma, service } = createHarness(true);

    await expect(
      service.resetAdminStaffPassword(
        TARGET_ID,
        { newPassword: "Strong-Admin-Password-2026" },
        "staff-admin.test-session",
      ),
    ).rejects.toThrow("simulated audit persistence failure");

    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(tx.adminStaffAccount.update).toHaveBeenCalledTimes(1);
    expect(tx.adminStaffSession.updateMany).toHaveBeenCalledTimes(1);
    expect(state.account.passwordHash).toBe("old-password-hash");
    expect(state.account.mustResetPassword).toBe(true);
    expect(state.account.accessTokenDigest).toBe("a".repeat(64));
    expect(state.account.accessTokenPreview).toBe("SAKHI-ST-••••");
    expect(state.activeSessions).toBe(2);
    expect(state.audits).toHaveLength(0);
  });
});
