import { afterEach, describe, expect, it, vi } from "vitest";
import { SakhiAdminRbacRegistry } from "../src/admin-review/admin-rbac.helper.js";

const ACTOR_ID = "2d5fce37-6aab-4cb4-8a6c-6a2d07f87e91";
const PASSWORD_HASH = "scrypt$16384$8$1$salt$" + "c".repeat(128);

function createHarness(failAudit = false) {
  const tx = {
    adminStaffAccount: {
      create: vi.fn().mockResolvedValue({ id: "created-staff" }),
    },
    auditEvent: {
      create: vi.fn(async () => {
        if (failAudit) throw new Error("audit write failed");
        return { id: "audit-id" };
      }),
    },
  };
  const prisma = {
    $transaction: vi.fn(async (callback: (client: typeof tx) => Promise<unknown>) => callback(tx)),
  };
  return { prisma, tx };
}

afterEach(() => {
  SakhiAdminRbacRegistry.resetForTesting();
  vi.restoreAllMocks();
});

describe("atomic staff account creation", () => {
  it("persists username, initial password hash, reset requirement and creation audit in one transaction", async () => {
    vi.spyOn(SakhiAdminRbacRegistry, "ensureHydrated").mockResolvedValue(undefined);
    const { prisma, tx } = createHarness();

    const created = await SakhiAdminRbacRegistry.createStaffAccount(
      prisma as never,
      {
        fullName: "New Reviewer",
        email: "new.reviewer@example.test",
        role: "VERIFICATION_ADMIN",
        username: "new.reviewer",
        initialPasswordHash: PASSWORD_HASH,
        mustResetPassword: true,
      },
      "Super Admin",
      ACTOR_ID,
    );

    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    const accountCreate = tx.adminStaffAccount.create.mock.calls[0]?.[0] as any;
    expect(accountCreate.data).toMatchObject({
      username: "new.reviewer",
      passwordHash: PASSWORD_HASH,
      mustResetPassword: true,
    });
    expect(accountCreate.data.passwordUpdatedAt).toBeInstanceOf(Date);
    const audit = tx.auditEvent.create.mock.calls[0]?.[0] as any;
    expect(audit.data.action).toBe("admin.staff_account.created");
    expect(audit.data.redactedMetadata).toMatchObject({
      username: "new.reviewer",
      mustResetPassword: true,
    });
    expect(JSON.stringify(audit.data.redactedMetadata)).not.toContain(PASSWORD_HASH);
    expect(created.staff.username).toBe("new.reviewer");
    expect(created.staff).not.toHaveProperty("passwordHash");
    expect(created.issuedAccessToken).toMatch(/^SAKHI-VA-/);
  });

  it("does not accept a staff creation when its audit insert fails", async () => {
    vi.spyOn(SakhiAdminRbacRegistry, "ensureHydrated").mockResolvedValue(undefined);
    const { prisma, tx } = createHarness(true);

    await expect(
      SakhiAdminRbacRegistry.createStaffAccount(
        prisma as never,
        {
          fullName: "Audit Failure Reviewer",
          email: "audit.failure@example.test",
          role: "VERIFICATION_ADMIN",
          username: "audit.failure",
          initialPasswordHash: PASSWORD_HASH,
          mustResetPassword: true,
        },
        "Super Admin",
        ACTOR_ID,
      ),
    ).rejects.toThrow(/must commit together/i);
    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(tx.adminStaffAccount.create).toHaveBeenCalledTimes(1);
    expect(tx.auditEvent.create).toHaveBeenCalledTimes(1);
    expect(SakhiAdminRbacRegistry.listStaff()).not.toEqual(
      expect.arrayContaining([expect.objectContaining({ email: "audit.failure@example.test" })]),
    );
  });
});
