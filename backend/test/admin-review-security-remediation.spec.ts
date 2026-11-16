import { afterEach, describe, expect, it, vi } from "vitest";
import { randomBytes, scryptSync } from "node:crypto";
import { AdminReviewService } from "../src/admin-review/admin-review.service.js";
import {
  SakhiAdminRbacRegistry,
  type AuthenticatedAdminPrincipal,
} from "../src/admin-review/admin-rbac.helper.js";

const restrictedSuperAdmin: AuthenticatedAdminPrincipal = {
  staffId: "2d5fce37-6aab-4cb4-8a6c-6a2d07f87e91",
  staffCode: "#SA-123",
  reviewerLabel: "Restricted Super Admin",
  fullName: "Restricted Super Admin",
  email: "restricted@example.test",
  role: "SUPER_ADMIN",
  roleTitle: "Super Admin",
  badgeLabel: "Super Admin",
  clearanceLevel: "LEVEL_4_MASTER_GOVERNANCE",
  isAuthorisedComplaintReviewer: true,
  permissions: {
    view: true,
    create: true,
    edit: true,
    approve: false,
    suspend: true,
    export: true,
    delete: true,
  },
  allowedRoutes: ["/admin-users"],
};

afterEach(() => {
  vi.restoreAllMocks();
  SakhiAdminRbacRegistry.resetForTesting();
});

describe("admin authentication security remediation", () => {
  it.each(["SUPER_ADMIN", "super_admin", " Super_Admin ", "super_admin  "])(
    "requires approve permission for normalized role %s",
    async (role) => {
      vi.spyOn(SakhiAdminRbacRegistry, "ensureHydrated").mockResolvedValue(undefined);
      const createSpy = vi
        .spyOn(SakhiAdminRbacRegistry, "createStaffAccount")
        .mockResolvedValue({ staff: {} as never, issuedAccessToken: "never-returned" });
      const service = new AdminReviewService({} as never);
      vi.spyOn(service, "resolveAdminPrincipal").mockReturnValue(restrictedSuperAdmin);

      await expect(
        service.createAdminStaff(
          {
            fullName: "New Super Admin",
            email: "new.superadmin@example.test",
            role,
          },
          "staff-admin.test",
        ),
      ).rejects.toThrow(/approve permission is required/i);
      expect(createSpy).not.toHaveBeenCalled();
    },
  );

  it("requires password plus TOTP for subsequent sign-ins after setup", async () => {
    const password = "Established-Admin-Password-2026";
    const salt = randomBytes(16).toString("hex");
    const hash = scryptSync(password, salt, 64, { N: 16384, r: 8, p: 1 }).toString("hex");
    const staff = {
      id: restrictedSuperAdmin.staffId,
      staffCode: "#SA-123",
      fullName: "Configured Super Admin",
      email: "configured@example.test",
      username: "configured.admin",
      role: "SUPER_ADMIN",
      status: "ACTIVE",
      suspendedAt: null,
      deletedAt: null,
      lockedUntil: null,
      passwordHash: `scrypt$16384$8$1${salt}${hash}`,
      mustResetPassword: false,
      clearanceLevel: "LEVEL_4_MASTER_GOVERNANCE",
      isAuthorisedComplaintReviewer: true,
      permissions: restrictedSuperAdmin.permissions,
    };
    const tx = {
      adminStaffAccount: { update: vi.fn().mockResolvedValue({}) },
      auditEvent: { create: vi.fn().mockResolvedValue({}) },
    };
    const prisma = {
      adminStaffAccount: { findFirst: vi.fn().mockResolvedValue(staff) },
      $transaction: vi.fn(async (callback: (client: typeof tx) => Promise<unknown>) => callback(tx)),
    };
    const mfa = { verifyLoginFactor: vi.fn().mockResolvedValue({ method: "TOTP" }) };
    const sessions = {
      issueSession: vi.fn().mockResolvedValue({
        value: "staff-admin.verified-session",
        expiresAt: new Date(Date.now() + 60_000),
      }),
    };
    const service = new AdminReviewService(prisma as never, undefined, mfa as never, sessions as never);

    const result = await service.loginWithCredentials({
      identifier: "configured.admin",
      password,
      mfaCode: "123456",
    });

    expect(result).toMatchObject({ authenticated: true, mode: "credential_session", mustResetPassword: false });
    expect(mfa.verifyLoginFactor).toHaveBeenCalledWith(staff.id, "123456");
    expect(sessions.issueSession).toHaveBeenCalledWith(staff.id);
  });

  it("does not allow password sign-in until first-time password setup is completed", async () => {
    const password = "Temporary-Admin-Password-2026";
    const salt = randomBytes(16).toString("hex");
    const hash = scryptSync(password, salt, 64, { N: 16384, r: 8, p: 1 }).toString("hex");
    const staff = {
      id: restrictedSuperAdmin.staffId,
      staffCode: "#SA-123",
      fullName: "Pending Setup Admin",
      email: "pending@example.test",
      username: "pending.admin",
      role: "SUPER_ADMIN",
      status: "ACTIVE",
      suspendedAt: null,
      deletedAt: null,
      lockedUntil: null,
      passwordHash: `scrypt$16384$8$1${salt}${hash}`,
      mustResetPassword: true,
      clearanceLevel: "LEVEL_4_MASTER_GOVERNANCE",
      isAuthorisedComplaintReviewer: true,
      permissions: restrictedSuperAdmin.permissions,
    };
    const prisma = {
      adminStaffAccount: { findFirst: vi.fn().mockResolvedValue(staff) },
    };
    const mfa = { verifyLoginFactor: vi.fn() };
    const sessions = { issueSession: vi.fn() };
    const service = new AdminReviewService(prisma as never, undefined, mfa as never, sessions as never);

    await expect(service.loginWithCredentials({
      identifier: "pending.admin",
      password,
      mfaCode: "123456",
    })).rejects.toThrow(/complete first-time staff setup/i);
    expect(mfa.verifyLoginFactor).not.toHaveBeenCalled();
    expect(sessions.issueSession).not.toHaveBeenCalled();
  });

  it("passes only a password hash into the atomic staff-creation transaction", async () => {
    vi.spyOn(SakhiAdminRbacRegistry, "ensureHydrated").mockResolvedValue(undefined);
    const creator = vi
      .spyOn(SakhiAdminRbacRegistry, "createStaffAccount")
      .mockResolvedValue({
        staff: {
          id: "3e6fce37-6aab-4cb4-8a6c-6a2d07f87e92",
          staffCode: "#VA-456",
          username: "new.reviewer",
        } as never,
        issuedAccessToken: "one-time-generated-token",
      });
    const service = new AdminReviewService({} as never);
    vi.spyOn(service, "resolveAdminPrincipal").mockReturnValue({
      ...restrictedSuperAdmin,
      permissions: { ...restrictedSuperAdmin.permissions, approve: true, create: true },
    });

    await service.createAdminStaff(
      {
        fullName: "New Reviewer",
        email: "new.reviewer@example.test",
        role: "VERIFICATION_ADMIN",
        username: "new.reviewer",
        initialPassword: "Temporary-Admin-Password-2026",
      },
      "staff-admin.test",
    );

    const dto = creator.mock.calls[0]?.[1] as Record<string, unknown>;
    expect(dto).toMatchObject({
      username: "new.reviewer",
      mustResetPassword: true,
    });
    expect(dto.initialPasswordHash).toEqual(
      expect.stringMatching(/^scrypt\$16384\$8\$1\$/),
    );
    expect(dto).not.toHaveProperty("initialPassword");
  });

  it("counts concurrent failed password attempts atomically before applying the five-attempt lockout", async () => {
    let failedLoginAttempts = 3;
    let lockedUntil: Date | null = null;
    const incrementCalls: number[] = [];
    const tx = {
      adminStaffAccount: {
        update: vi.fn(async ({ data }: { data: Record<string, any> }) => {
          if (data.failedLoginAttempts?.increment === 1) {
            failedLoginAttempts += 1;
            incrementCalls.push(failedLoginAttempts);
            return { failedLoginAttempts };
          }
          if (data.failedLoginAttempts === 0) failedLoginAttempts = 0;
          if (Object.prototype.hasOwnProperty.call(data, "lockedUntil")) {
            lockedUntil = data.lockedUntil;
          }
          return { failedLoginAttempts };
        }),
      },
      auditEvent: { create: vi.fn().mockResolvedValue({}) },
    };
    const staff = {
      id: restrictedSuperAdmin.staffId,
      role: "SUPER_ADMIN",
      status: "ACTIVE",
      suspendedAt: null,
      deletedAt: null,
      lockedUntil: null,
      failedLoginAttempts: 3,
      passwordHash: null,
    };
    const prisma = {
      adminStaffAccount: {
        findFirst: vi.fn().mockResolvedValue(staff),
      },
      $transaction: vi.fn(async (callback: (client: typeof tx) => Promise<unknown>) =>
        callback(tx),
      ),
    };
    const service = new AdminReviewService(
      prisma as never,
      undefined,
      {} as never,
      {} as never,
    );

    const attempts = await Promise.allSettled([
      service.loginWithCredentials({ identifier: "restricted@example.test", password: "wrong-1" }),
      service.loginWithCredentials({ identifier: "restricted@example.test", password: "wrong-2" }),
    ]);

    expect(attempts.every((attempt) => attempt.status === "rejected")).toBe(true);
    expect(incrementCalls).toEqual([4, 5]);
    expect(failedLoginAttempts).toBe(0);
    expect(lockedUntil).toBeInstanceOf(Date);
    expect(tx.auditEvent.create).toHaveBeenCalledTimes(2);
    expect(tx.auditEvent.create).toHaveBeenLastCalledWith({
      data: expect.objectContaining({
        action: "admin.auth.account_locked",
        redactedMetadata: expect.objectContaining({
          failedLoginAttempts: 5,
          locked: true,
        }),
      }),
    });
  });
});
