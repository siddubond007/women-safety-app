import { afterEach, describe, expect, it, vi } from "vitest";
import { AdminReviewService } from "../src/admin-review/admin-review.service.js";
import { SakhiAdminRbacRegistry } from "../src/admin-review/admin-rbac.helper.js";

const adminId = "11111111-1111-4111-8111-111111111111";
const targetId = "22222222-2222-4222-8222-222222222222";

function staffRow(id: string, role: string) {
  const isSuperAdmin = role === "SUPER_ADMIN";
  return {
    id,
    staffCode: isSuperAdmin ? "#SA-101" : "#VA-102",
    fullName: isSuperAdmin ? "Current Super Admin" : "Verification Admin",
    email: isSuperAdmin ? "admin@example.test" : "verification@example.test",
    role,
    status: "ACTIVE",
    accessTokenDigest: "a".repeat(64),
    accessTokenPreview: "REDACTED",
    isAuthorisedComplaintReviewer: isSuperAdmin,
    clearanceLevel: isSuperAdmin ? "LEVEL_4_MASTER_GOVERNANCE" : "LEVEL_1_STANDARD",
    permissions: isSuperAdmin
      ? { view: true, create: true, edit: true, approve: true, suspend: true, export: true, delete: true }
      : { view: true, create: false, edit: false, approve: false, suspend: false, export: false, delete: false },
    createdBy: "test",
    lastLoginAt: null,
    createdAt: new Date(),
    updatedAt: new Date(),
  };
}

afterEach(() => {
  vi.restoreAllMocks();
  SakhiAdminRbacRegistry.resetForTesting();
});

describe("Super Admin promotion dual-control gate", () => {
  it("blocks single-actor creation of another Super Admin", async () => {
    const current = SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase(
      staffRow(adminId, "SUPER_ADMIN"),
    );
    vi.spyOn(SakhiAdminRbacRegistry, "ensureHydrated").mockResolvedValue(undefined);
    const service = new AdminReviewService({} as any);
    vi.spyOn(service as any, "resolveAdminPrincipal").mockReturnValue(
      SakhiAdminRbacRegistry.principalFromStaff(current),
    );

    await expect(
      service.createAdminStaff(
        { fullName: "New Super Admin", email: "new.admin@example.test", role: "SUPER_ADMIN" },
        "staff-admin.test",
      ),
    ).rejects.toThrow(/independent two-person approval workflow/i);
  });

  it("blocks a single Super Admin from promoting an existing lower-role staff member", async () => {
    const current = SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase(
      staffRow(adminId, "SUPER_ADMIN"),
    );
    SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase(
      staffRow(targetId, "VERIFICATION_ADMIN"),
    );
    vi.spyOn(SakhiAdminRbacRegistry, "ensureHydrated").mockResolvedValue(undefined);
    const service = new AdminReviewService({} as any);
    vi.spyOn(service as any, "resolveAdminPrincipal").mockReturnValue(
      SakhiAdminRbacRegistry.principalFromStaff(current),
    );

    await expect(
      service.updateAdminStaff(
        targetId,
        { role: "SUPER_ADMIN" },
        "staff-admin.test",
      ),
    ).rejects.toThrow(/independent two-person approval workflow/i);
  });
});
