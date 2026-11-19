import { afterEach, describe, expect, it, vi } from "vitest";
import {
  ADMIN_ROLE_DEFINITIONS,
  SakhiAdminRbacRegistry,
  type SakhiAdminRole,
} from "../src/admin-review/admin-rbac.helper.js";

const STAFF_ID = "2d5fce37-6aab-4cb4-8a6c-6a2d07f87e91";

function persistedRow(overrides: Record<string, unknown> = {}) {
  return {
    id: STAFF_ID,
    staffCode: "#SA-101",
    fullName: "Existing Super Admin",
    email: "super.admin@example.test",
    role: "SUPER_ADMIN",
    status: "ACTIVE",
    accessTokenDigest: "a".repeat(64),
    accessTokenPreview: "REDACTED",
    isAuthorisedComplaintReviewer: true,
    clearanceLevel: "LEVEL_4_MASTER_GOVERNANCE",
    permissions: {
      view: true,
      create: true,
      edit: true,
      approve: true,
      suspend: true,
      export: true,
      delete: true,
    },
    createdBy: "test",
    lastLoginAt: null,
    createdAt: new Date("2026-11-10T00:00:00.000Z"),
    updatedAt: new Date("2026-11-10T00:00:00.000Z"),
    ...overrides,
  };
}

afterEach(() => {
  vi.restoreAllMocks();
  SakhiAdminRbacRegistry.resetForTesting();
});

describe("Stage 4A RBAC remediation", () => {
  it.each(
    Object.keys(ADMIN_ROLE_DEFINITIONS).filter(
      (role) => role !== "SUPER_ADMIN",
    ) as SakhiAdminRole[],
  )("resets inherited Super Admin grants when changing to %s", async (role) => {
    vi.spyOn(SakhiAdminRbacRegistry, "ensureHydrated").mockResolvedValue(undefined);
    vi.spyOn(SakhiAdminRbacRegistry as any, "persistStaffRecord").mockResolvedValue(undefined);
    const prisma = {
      adminStaffAccount: {
        findUnique: vi.fn().mockResolvedValue(persistedRow()),
      },
    };

    const result = await SakhiAdminRbacRegistry.updateStaffAccount(
      prisma as never,
      STAFF_ID,
      { role, permissions: { view: true } },
      "Independent Super Admin",
      "00000000-0000-4000-8000-000000000002",
    );

    expect(result.staff.role).toBe(role);
    expect(result.staff.permissions).toEqual({
      ...ADMIN_ROLE_DEFINITIONS[role].defaultPermissions,
      view: true,
    });
    expect(result.staff.allowedRoutes).toEqual(
      ADMIN_ROLE_DEFINITIONS[role].allowedRoutes,
    );
  });

  it("rejects persisted complaint-reviewer clearance on a non-reviewer role", () => {
    expect(() =>
      SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase(
        persistedRow({
          role: "SOS_SAFETY_ADMIN",
          isAuthorisedComplaintReviewer: true,
        }),
      ),
    ).toThrow(/clearance conflicts with the staff role/i);
  });

  it("continues to allow an explicit reviewer clearance only for an eligible role", () => {
    const reviewer = SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase(
      persistedRow({
        role: "COMPLAINT_REVIEWER",
        isAuthorisedComplaintReviewer: true,
      }),
    );
    expect(reviewer.isAuthorisedComplaintReviewer).toBe(true);
  });

  it("rejects inconsistent reviewer clearance when constructing an authorization principal", () => {
    const inconsistent = {
      ...persistedRow({
        role: "SOS_SAFETY_ADMIN",
        isAuthorisedComplaintReviewer: true,
      }),
    } as any;
    expect(() =>
      SakhiAdminRbacRegistry.principalFromStaff(inconsistent),
    ).toThrow(/clearance conflicts with the staff role/i);
  });

  it("rejects malformed explicit permission overrides before persistence", async () => {
    vi.spyOn(SakhiAdminRbacRegistry, "ensureHydrated").mockResolvedValue(undefined);
    const persist = vi
      .spyOn(SakhiAdminRbacRegistry as any, "persistStaffRecord")
      .mockResolvedValue(undefined);
    const prisma = {
      adminStaffAccount: {
        findUnique: vi.fn().mockResolvedValue(persistedRow()),
      },
    };

    await expect(
      SakhiAdminRbacRegistry.updateStaffAccount(
        prisma as never,
        STAFF_ID,
        { role: "SOS_SAFETY_ADMIN", permissions: { delete: "true" as unknown as boolean } },
        "Independent Super Admin",
      ),
    ).rejects.toThrow(/recognized boolean permission/i);
    expect(persist).not.toHaveBeenCalled();
  });
});
