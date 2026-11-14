import { afterEach, describe, expect, it } from "vitest";
import { SakhiAdminRbacRegistry } from "../src/admin-review/admin-rbac.helper.js";

const row = (overrides: Record<string, unknown> = {}) => ({
  id: "2d5fce37-6aab-4cb4-8a6c-6a2d07f87e91",
  staffCode: "#SA-123",
  username: null,
  fullName: "Initial Super Admin",
  email: "initial.superadmin@example.test",
  role: "SUPER_ADMIN",
  status: "ACTIVE",
  passwordHash: null,
  mustResetPassword: false,
  accessTokenDigest: "a".repeat(64),
  accessTokenPreview: "SAKHI-SA-••••",
  isAuthorisedComplaintReviewer: true,
  clearanceLevel: "LEVEL_4_MASTER_GOVERNANCE",
  permissions: {
    view: true, create: true, edit: true, approve: true,
    suspend: true, export: true, delete: true,
  },
  createdBy: "bootstrap",
  lastLoginAt: null,
  createdAt: new Date("2026-11-14T00:00:00.000Z"),
  updatedAt: new Date("2026-11-14T00:00:00.000Z"),
  ...overrides,
});

afterEach(() => SakhiAdminRbacRegistry.resetForTesting());

describe("initial Super Admin password setup state", () => {
  it("requires password setup when an existing Super Admin has no password hash", () => {
    const staff = SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase(row());
    expect(staff.mustResetPassword).toBe(true);
  });

  it("does not force password setup for token-authenticated non-Super-Admin staff without a password hash", () => {
    const staff = SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase(
      row({ role: "VERIFICATION_ADMIN", passwordHash: null, mustResetPassword: false }),
    );
    expect(staff.mustResetPassword).toBe(false);
  });

  it("preserves an explicitly required password reset when a hash exists", () => {
    const staff = SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase(
      row({ passwordHash: "scrypt$fixture", mustResetPassword: true }),
    );
    expect(staff.mustResetPassword).toBe(true);
  });

  it("does not require a reset for a Super Admin with a password hash and no reset flag", () => {
    const staff = SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase(
      row({ passwordHash: "scrypt$fixture", mustResetPassword: false }),
    );
    expect(staff.mustResetPassword).toBe(false);
  });
});
