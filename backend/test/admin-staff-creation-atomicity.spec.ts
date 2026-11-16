import { afterEach, describe, expect, it, vi } from "vitest";
import { SakhiAdminRbacRegistry, type AdminStaffRecord } from "../src/admin-review/admin-rbac.helper.js";

const ACTOR_ID = "2d5fce37-6aab-4cb4-8a6c-6a2d07f87e91";
const STAFF_ID = "3e6fce37-6aab-4cb4-8a6c-6a2d07f87e92";

function staffRecord(): AdminStaffRecord {
  const now = new Date().toISOString();
  return {
    id: STAFF_ID,
    staffCode: "#VA-456",
    username: "new.reviewer",
    fullName: "New Reviewer",
    email: "new.reviewer@example.test",
    role: "VERIFICATION_ADMIN",
    status: "ACTIVE",
    mustResetPassword: true,
    accessTokenDigest: "b".repeat(64),
    accessTokenPreview: "SAKHI-VA-••••",
    isAuthorisedComplaintReviewer: false,
    clearanceLevel: "LEVEL_2_ELIGIBILITY_SUPPORT",
    permissions: {
      view: true, create: false, edit: false, approve: false,
      suspend: false, export: false, delete: false,
    },
    allowedRoutes: ["/eligibility"],
    createdBy: "Super Admin",
    lastLoginAt: null,
    createdAt: now,
    updatedAt: now,
  };
}

afterEach(() => {
  SakhiAdminRbacRegistry.resetForTesting();
  vi.restoreAllMocks();
});

describe("atomic staff account creation", () => {
  it("persists username, initial password hash, reset requirement and creation audit in one transaction", async () => {
    const tx = {
      adminStaffAccount: { create: vi.fn().mockResolvedValue({ id: STAFF_ID }) },
      auditEvent: { create: vi.fn().mockResolvedValue({ id: "audit-id" }) },
    };
    const prisma = {
      $transaction: vi.fn(async (callback: (client: typeof tx) => Promise<unknown>) => callback(tx)),
    };
    const passwordHash = "scrypt$16384$8$1$salt$" + "c".repeat(128);

    await SakhiAdminRbacRegistry.persistStaffRecord(
      prisma as never,
      staffRecord(),
      "created",
      "Super Admin",
      ACTOR_ID,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      passwordHash,
    );

    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    const accountCreate = tx.adminStaffAccount.create.mock.calls[0]?.[0] as any;
    expect(accountCreate.data).toMatchObject({
      id: STAFF_ID,
      username: "new.reviewer",
      passwordHash,
      mustResetPassword: true,
    });
    expect(accountCreate.data.passwordUpdatedAt).toBeInstanceOf(Date);
    const audit = tx.auditEvent.create.mock.calls[0]?.[0] as any;
    expect(audit.data.action).toBe("admin.staff_account.created");
    expect(audit.data.redactedMetadata).toMatchObject({
      id: STAFF_ID,
      username: "new.reviewer",
      mustResetPassword: true,
    });
    expect(JSON.stringify(audit.data.redactedMetadata)).not.toContain(passwordHash);
  });

  it("does not accept a staff creation when its audit insert fails", async () => {
    const tx = {
      adminStaffAccount: { create: vi.fn().mockResolvedValue({ id: STAFF_ID }) },
      auditEvent: { create: vi.fn().mockRejectedValue(new Error("audit write failed")) },
    };
    const prisma = {
      $transaction: vi.fn(async (callback: (client: typeof tx) => Promise<unknown>) => callback(tx)),
    };

    await expect(
      SakhiAdminRbacRegistry.persistStaffRecord(
        prisma as never,
        staffRecord(),
        "created",
        "Super Admin",
        ACTOR_ID,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        "scrypt$fixture",
      ),
    ).rejects.toThrow(/must commit together/i);
    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(tx.adminStaffAccount.create).toHaveBeenCalledTimes(1);
    expect(tx.auditEvent.create).toHaveBeenCalledTimes(1);
  });
});
