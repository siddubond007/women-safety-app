import { afterEach, describe, expect, it, vi } from "vitest";
import { AdminReviewService } from "../src/admin-review/admin-review.service.js";
import { SakhiAdminRbacRegistry } from "../src/admin-review/admin-rbac.helper.js";

const STAFF_ID = "2d5fce37-6aab-4cb4-8a6c-6a2d07f87e91";

afterEach(() => {
  vi.restoreAllMocks();
  SakhiAdminRbacRegistry.resetForTesting();
});

describe("Super Admin self-modification boundary", () => {
  it("blocks direct creation of an additional Super Admin without independent approval", async () => {
    const staff = SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase({
      id: STAFF_ID,
      staffCode: "#SA-101",
      fullName: "Primary Super Admin",
      email: "primary.admin@example.test",
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
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    vi.spyOn(SakhiAdminRbacRegistry, "ensureHydrated").mockResolvedValue(undefined);
    const service = new AdminReviewService({} as any);
    vi.spyOn(service as any, "resolveAdminPrincipal").mockReturnValue(
      SakhiAdminRbacRegistry.principalFromStaff(staff),
    );

    await expect(
      service.createAdminStaff(
        {
          fullName: "Second Super Admin",
          email: "second.admin@example.test",
          role: " super_admin ",
        },
        "staff-admin.test",
      ),
    ).rejects.toThrow(/independent two-person approval workflow/i);
  });

  it("blocks promotion of an existing staff member to Super Admin without independent approval", async () => {
    const primary = SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase({
      id: STAFF_ID,
      staffCode: "#SA-101",
      fullName: "Primary Super Admin",
      email: "primary.admin@example.test",
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
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase({
      id: "b7f3e4d2-7a65-4b12-9c21-5a6d7e8f9012",
      staffCode: "#VA-102",
      fullName: "Verification Admin",
      email: "verification.admin@example.test",
      role: "VERIFICATION_ADMIN",
      status: "ACTIVE",
      accessTokenDigest: "b".repeat(64),
      accessTokenPreview: "REDACTED",
      isAuthorisedComplaintReviewer: false,
      clearanceLevel: null,
      permissions: {
        ...SakhiAdminRbacRegistry.getRoleDefaults("VERIFICATION_ADMIN"),
      },
      createdBy: "test",
      lastLoginAt: null,
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    vi.spyOn(SakhiAdminRbacRegistry, "ensureHydrated").mockResolvedValue(undefined);
    const service = new AdminReviewService({} as any);
    vi.spyOn(service as any, "resolveAdminPrincipal").mockReturnValue(
      SakhiAdminRbacRegistry.principalFromStaff(primary),
    );

    await expect(
      service.updateAdminStaff(
        "b7f3e4d2-7a65-4b12-9c21-5a6d7e8f9012",
        { role: "SUPER_ADMIN" },
        "staff-admin.test",
      ),
    ).rejects.toThrow(/independent two-person approval workflow/i);
  });

  it("blocks a Super Admin from changing their own role or security privileges", async () => {
    const staff = SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase({
      id: STAFF_ID,
      staffCode: "#SA-101",
      fullName: "Self Admin",
      email: "self.admin@example.test",
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
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    vi.spyOn(SakhiAdminRbacRegistry, "ensureHydrated").mockResolvedValue(undefined);
    const service = new AdminReviewService({} as any);
    vi.spyOn(service as any, "resolveAdminPrincipal").mockReturnValue(
      SakhiAdminRbacRegistry.principalFromStaff(staff),
    );

    await expect(
      service.updateAdminStaff(
        STAFF_ID,
        { role: "VERIFICATION_ADMIN" },
        "staff-admin.test",
      ),
    ).rejects.toThrow(/cannot change their own role, status, permissions/i);
  });
});
