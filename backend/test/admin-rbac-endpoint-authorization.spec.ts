import { afterEach, describe, expect, it, vi } from "vitest";
import { AdminReviewService } from "../src/admin-review/admin-review.service.js";
import { ADMIN_ROLE_DEFINITIONS, SakhiAdminRbacRegistry } from "../src/admin-review/admin-rbac.helper.js";
import { StagingTestAdminService } from "../src/staging-test-admin/staging-test-admin.service.js";
import { ComplaintsService } from "../src/complaints/complaints.service.js";
import type { AuthenticatedAdminPrincipal } from "../src/admin-review/admin-rbac.helper.js";

const SESSION = "staff-admin.test-session-token";

function principal(
  role: AuthenticatedAdminPrincipal["role"],
  overrides: Partial<AuthenticatedAdminPrincipal> = {},
): AuthenticatedAdminPrincipal {
  return {
    staffId: "2d5fce37-6aab-4cb4-8a6c-6a2d07f87e91",
    staffCode: "#SA-123",
    reviewerLabel: "Security Test Staff",
    fullName: "Security Test Staff",
    email: "security.test@example.test",
    role,
    roleTitle: role,
    badgeLabel: role,
    clearanceLevel: "TEST",
    isAuthorisedComplaintReviewer: role === "COMPLAINT_REVIEWER",
    permissions: {
      view: true,
      create: true,
      edit: true,
      approve: true,
      suspend: true,
      export: true,
      delete: true,
    },
    allowedRoutes: [],
    ...overrides,
  };
}

describe("admin endpoint server-side role and permission enforcement", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    SakhiAdminRbacRegistry.resetForTesting();
  });

  it("rejects a legacy shared reviewer token before resolving a principal", () => {
    const resolve = vi.spyOn(
      StagingTestAdminService,
      "resolvePrincipalFromSessionToken",
    );
    const service = new AdminReviewService({} as any);

    expect(() => service.resolveAdminPrincipal("legacy-shared-reviewer-token")).toThrow(
      /persistent MFA-verified staff session/i,
    );
    expect(resolve).not.toHaveBeenCalled();
  });

  it("defines the canonical auditor role as read-only and excludes complaint clearance", () => {
    expect(ADMIN_ROLE_DEFINITIONS.READ_ONLY_AUDITOR.defaultPermissions).toEqual({
      view: true,
      create: false,
      edit: false,
      approve: false,
      suspend: false,
      export: false,
      delete: false,
    });
    expect(ADMIN_ROLE_DEFINITIONS.READ_ONLY_AUDITOR.canAccessDiscreetComplaints).toBe(false);
    expect(ADMIN_ROLE_DEFINITIONS.READ_ONLY_AUDITOR.allowedRoutes).toEqual([
      "/dashboard",
      "/audit-security",
    ]);
  });

  it("allows the read-only auditor to retrieve redacted audit metadata only", async () => {
    vi.spyOn(
      StagingTestAdminService,
      "resolvePrincipalFromSessionToken",
    ).mockReturnValue(
      principal("READ_ONLY_AUDITOR", {
        permissions: {
          view: true,
          create: false,
          edit: false,
          approve: false,
          suspend: false,
          export: false,
          delete: false,
        },
      }),
    );
    const findMany = vi.fn().mockResolvedValue([
      {
        id: "event-1",
        actorType: "ADMIN",
        actorId: "staff-1",
        action: "admin.staff_session.created",
        targetType: "admin_staff_session",
        targetId: "session-1",
        outcome: "success",
        requestId: "request-1",
        createdAt: new Date("2026-11-10T10:00:00.000Z"),
        redactedMetadata: { mustNotBeReturned: "secret" },
      },
    ]);
    const service = new AdminReviewService({ auditEvent: { findMany } } as any);

    const result = await service.listAuditEvents(SESSION, "999");

    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({ take: 200, orderBy: { createdAt: "desc" } }),
    );
    expect(result.events[0]).not.toHaveProperty("redactedMetadata");
    expect(result.events[0]).toMatchObject({
      id: "event-1",
      action: "admin.staff_session.created",
    });
  });

  it("denies the read-only auditor access to mutation endpoints even if supplied broad UI permissions", async () => {
    vi.spyOn(
      StagingTestAdminService,
      "resolvePrincipalFromSessionToken",
    ).mockReturnValue(principal("READ_ONLY_AUDITOR"));
    const service = new AdminReviewService({} as any);

    await expect(service.deleteAdminPost("post-1", SESSION)).rejects.toThrow(
      /not authorised/i,
    );
  });

  it("denies a Content Moderator access to eligibility queue endpoints", async () => {
    vi.spyOn(
      StagingTestAdminService,
      "resolvePrincipalFromSessionToken",
    ).mockReturnValue(principal("CONTENT_MODERATOR"));
    const service = new AdminReviewService({} as any);

    await expect(service.queue(SESSION)).rejects.toThrow(/not authorised/i);
  });

  it("denies a role even when its generic delete permission is enabled if the module role is not allowed", async () => {
    vi.spyOn(
      StagingTestAdminService,
      "resolvePrincipalFromSessionToken",
    ).mockReturnValue(principal("BUSINESS_ADMIN"));
    const service = new AdminReviewService({} as any);

    await expect(service.deleteAdminPost("post-1", SESSION)).rejects.toThrow(
      /not authorised/i,
    );
  });

  it("denies a permitted module role when the specific operation permission is false", async () => {
    vi.spyOn(
      StagingTestAdminService,
      "resolvePrincipalFromSessionToken",
    ).mockReturnValue(
      principal("CONTENT_MODERATOR", {
        permissions: {
          view: true,
          create: true,
          edit: true,
          approve: true,
          suspend: true,
          export: true,
          delete: false,
        },
      }),
    );
    const service = new AdminReviewService({} as any);

    await expect(service.deleteAdminPost("post-1", SESSION)).rejects.toThrow(
      /delete permission/i,
    );
  });

  it("restricts complaint category governance to Super Admin despite complaint-reviewer clearance", async () => {
    vi.spyOn(
      StagingTestAdminService,
      "resolvePrincipalFromSessionToken",
    ).mockReturnValue(principal("COMPLAINT_REVIEWER"));
    const service = new ComplaintsService({} as any, {} as any);

    await expect(
      service.adminUpsertCategory(SESSION, {
        slug: "test",
        name: "Test",
        description: "Test category",
      } as any),
    ).rejects.toThrow(/Only a Super Admin/i);
  });

  it("enforces granular complaint edit permission server-side", async () => {
    vi.spyOn(
      StagingTestAdminService,
      "resolvePrincipalFromSessionToken",
    ).mockReturnValue(
      principal("COMPLAINT_REVIEWER", {
        permissions: {
          view: true,
          create: true,
          edit: false,
          approve: true,
          suspend: true,
          export: true,
          delete: false,
        },
      }),
    );
    const service = new ComplaintsService({} as any, {} as any);

    await expect(
      service.adminAssignAndClassify(SESSION, "SKH-CASE", {} as any),
    ).rejects.toThrow(/edit permission/i);
  });
  it("rejects unknown persisted staff roles instead of mapping them to a complaint reviewer", () => {
    expect(() => SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase({
      id: "2d5fce37-6aab-4cb4-8a6c-6a2d07f87e91",
      staffCode: "#XX-001",
      fullName: "Unknown Role",
      email: "unknown@example.test",
      role: "UNRECOGNIZED_ROLE",
      status: "ACTIVE",
      accessTokenDigest: "a".repeat(64),
      accessTokenPreview: "REDACTED",
      isAuthorisedComplaintReviewer: false,
      clearanceLevel: "TEST",
      permissions: { view: true },
      createdBy: "test",
      createdAt: new Date(),
      updatedAt: new Date(),
    })).toThrow(/role is not recognized/i);
  });

  it("rejects string-valued permissions rather than coercing false-like strings to true", () => {
    expect(() => SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase({
      id: "2d5fce37-6aab-4cb4-8a6c-6a2d07f87e91",
      staffCode: "#XX-002",
      fullName: "Malformed Permissions",
      email: "malformed@example.test",
      role: "CONTENT_MODERATOR",
      status: "ACTIVE",
      accessTokenDigest: "b".repeat(64),
      accessTokenPreview: "REDACTED",
      isAuthorisedComplaintReviewer: false,
      clearanceLevel: "TEST",
      permissions: { view: "false" },
      createdBy: "test",
      createdAt: new Date(),
      updatedAt: new Date(),
    })).toThrow(/not a boolean/i);
  });

  it("requires delete permission for report actions that remove content even when approve is granted", async () => {
    vi.spyOn(StagingTestAdminService, "resolvePrincipalFromSessionToken").mockReturnValue(
      principal("CONTENT_MODERATOR", {
        permissions: { view: true, create: true, edit: true, approve: true, suspend: true, export: true, delete: false },
      }),
    );
    const service = new AdminReviewService({} as any);
    await expect(service.resolveReport("report-1", { actionType: "REMOVE_POST" }, SESSION))
      .rejects.toThrow(/permission required/i);
  });

  it("prevents demoting the last active Super Admin", async () => {
    const row = {
      id: "2d5fce37-6aab-4cb4-8a6c-6a2d07f87e91",
      staffCode: "#SA-001",
      fullName: "Only Super Admin",
      email: "only-sa@example.test",
      role: "SUPER_ADMIN",
      status: "ACTIVE",
      accessTokenDigest: "c".repeat(64),
      accessTokenPreview: "REDACTED",
      isAuthorisedComplaintReviewer: true,
      clearanceLevel: "LEVEL_4_MASTER_GOVERNANCE",
      permissions: { view: true, create: true, edit: true, approve: true, suspend: true, export: true, delete: true },
      createdBy: "test",
      lastLoginAt: null,
      createdAt: new Date(),
      updatedAt: new Date("2026-11-10T00:00:00Z"),
    };
    const tx = {
      adminStaffAccount: {
        count: vi.fn().mockResolvedValue(1),
        updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      },
      adminStaffSession: { updateMany: vi.fn().mockResolvedValue({ count: 0 }) },
      adminStaffBackupCode: { updateMany: vi.fn().mockResolvedValue({ count: 0 }) },
      adminStaffRecoveryRequest: { updateMany: vi.fn().mockResolvedValue({ count: 0 }) },
      auditEvent: { create: vi.fn().mockResolvedValue({ id: "audit" }) },
    };
    const prisma = {
      adminStaffAccount: { findMany: vi.fn().mockResolvedValue([row]), findUnique: vi.fn().mockResolvedValue(row) },
      auditEvent: { findMany: vi.fn().mockResolvedValue([]) },
      businessDirectoryListing: { findMany: vi.fn().mockResolvedValue([]) },
      platformConfigSetting: { findUnique: vi.fn().mockResolvedValue(null) },
      $transaction: vi.fn(async (callback: (tx: any) => Promise<unknown>) => callback(tx)),
    } as any;
    await expect(SakhiAdminRbacRegistry.updateStaffAccount(
      prisma, row.id, { role: "VERIFICATION_ADMIN" }, "test", "2d5fce37-6aab-4cb4-8a6c-6a2d07f87e92",
    )).rejects.toThrow(/last active Super Admin/i);
    expect(tx.adminStaffAccount.updateMany).not.toHaveBeenCalled();
  });

  it("changes a staff email transactionally, revokes sessions, and writes a dedicated audit event", async () => {
    const staffId = "7d5fce37-6aab-4cb4-8a6c-6a2d07f87e91";
    const row = {
      id: staffId, staffCode: "#SA-777", fullName: "Initial Owner",
      email: "temporary@example.test", role: "SUPER_ADMIN", status: "ACTIVE",
      accessTokenDigest: "d".repeat(64), accessTokenPreview: "REDACTED",
      isAuthorisedComplaintReviewer: true, clearanceLevel: "LEVEL_4_MASTER_GOVERNANCE",
      permissions: { view: true, create: true, edit: true, approve: true, suspend: true, export: true, delete: true },
      createdBy: "Bootstrap", lastLoginAt: null, createdAt: new Date(),
      updatedAt: new Date("2026-11-10T00:00:00Z"),
    };
    const tx = {
      adminStaffAccount: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
      adminStaffSession: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
      adminStaffBackupCode: { updateMany: vi.fn().mockResolvedValue({ count: 0 }) },
      adminStaffRecoveryRequest: { updateMany: vi.fn().mockResolvedValue({ count: 0 }) },
      auditEvent: { create: vi.fn().mockResolvedValue({ id: "email-change-audit" }) },
    };
    const prisma = {
      adminStaffAccount: { findMany: vi.fn().mockResolvedValue([row]), findUnique: vi.fn().mockResolvedValue(row) },
      auditEvent: { findMany: vi.fn().mockResolvedValue([]) },
      businessDirectoryListing: { findMany: vi.fn().mockResolvedValue([]) },
      platformConfigSetting: { findUnique: vi.fn().mockResolvedValue(null) },
      $transaction: vi.fn(async (callback: (value: any) => Promise<unknown>) => callback(tx)),
    } as any;

    const updated = await SakhiAdminRbacRegistry.updateStaffAccount(
      prisma, staffId, { email: "  Owner.New@Example.com ", emailChangeReason: "Client provided the permanent work email." }, "Verified Super Admin",
      "00000000-0000-4000-8000-000000000001",
    );

    expect(updated.staff.email).toBe("owner.new@example.com");
    expect(tx.adminStaffAccount.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({ email: "owner.new@example.com" }),
    }));
    expect(tx.adminStaffSession.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { staffId, revokedAt: null },
      data: expect.objectContaining({ revokeReason: "STAFF_ACCOUNT_CHANGED" }),
    }));
    expect(tx.auditEvent.create).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({
        action: "admin.staff_account.email_changed",
        targetId: staffId,
        redactedMetadata: expect.objectContaining({ emailChanged: true, reason: "Client provided the permanent work email." }),
      }),
    }));
  });

  it("rejects malformed staff email updates before persisting", async () => {
    const staffId = "8d5fce37-6aab-4cb4-8a6c-6a2d07f87e91";
    const row = {
      id: staffId, staffCode: "#CM-777", fullName: "Moderator",
      email: "moderator@example.test", role: "CONTENT_MODERATOR", status: "ACTIVE",
      accessTokenDigest: "e".repeat(64), accessTokenPreview: "REDACTED",
      isAuthorisedComplaintReviewer: false, clearanceLevel: "LEVEL_2_MODERATION",
      permissions: { view: true, create: true, edit: true, approve: false, suspend: false, export: false, delete: false },
      createdBy: "Bootstrap", lastLoginAt: null, createdAt: new Date(), updatedAt: new Date(),
    };
    const prisma = {
      adminStaffAccount: { findMany: vi.fn().mockResolvedValue([row]), findUnique: vi.fn().mockResolvedValue(row) },
      auditEvent: { findMany: vi.fn().mockResolvedValue([]) },
      businessDirectoryListing: { findMany: vi.fn().mockResolvedValue([]) },
      platformConfigSetting: { findUnique: vi.fn().mockResolvedValue(null) },
      $transaction: vi.fn(),
    } as any;
    await expect(SakhiAdminRbacRegistry.updateStaffAccount(
      prisma, staffId, { email: "not-an-email" }, "Verified Super Admin",
      "00000000-0000-4000-8000-000000000001",
    )).rejects.toThrow(/valid staff email/i);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it("rejects a stale concurrent staff update instead of overwriting the newer row", async () => {
    const row = {
      id: "3d5fce37-6aab-4cb4-8a6c-6a2d07f87e91",
      staffCode: "#CM-001",
      fullName: "Moderator",
      email: "moderator@example.test",
      role: "CONTENT_MODERATOR",
      status: "ACTIVE",
      accessTokenDigest: "d".repeat(64),
      accessTokenPreview: "REDACTED",
      isAuthorisedComplaintReviewer: false,
      clearanceLevel: "LEVEL_2_MODERATION",
      permissions: { view: true, create: true, edit: true, approve: true, suspend: false, export: false, delete: true },
      createdBy: "test",
      lastLoginAt: null,
      createdAt: new Date(),
      updatedAt: new Date("2026-11-10T00:00:00Z"),
    };
    const tx = {
      adminStaffAccount: { updateMany: vi.fn().mockResolvedValue({ count: 0 }) },
      adminStaffSession: { updateMany: vi.fn().mockResolvedValue({ count: 0 }) },
      adminStaffBackupCode: { updateMany: vi.fn().mockResolvedValue({ count: 0 }) },
      adminStaffRecoveryRequest: { updateMany: vi.fn().mockResolvedValue({ count: 0 }) },
      auditEvent: { create: vi.fn().mockResolvedValue({ id: "audit" }) },
    };
    const prisma = {
      adminStaffAccount: { findMany: vi.fn().mockResolvedValue([row]), findUnique: vi.fn().mockResolvedValue(row) },
      auditEvent: { findMany: vi.fn().mockResolvedValue([]) },
      businessDirectoryListing: { findMany: vi.fn().mockResolvedValue([]) },
      platformConfigSetting: { findUnique: vi.fn().mockResolvedValue(null) },
      $transaction: vi.fn(async (callback: (tx: any) => Promise<unknown>) => callback(tx)),
    } as any;
    await expect(SakhiAdminRbacRegistry.updateStaffAccount(
      prisma, row.id, { fullName: "Concurrent Name" }, "test", "2d5fce37-6aab-4cb4-8a6c-6a2d07f87e92",
    )).rejects.toThrow(/changed concurrently/i);
  });

});
  it("revokes persistent sessions and invalidates recovery material when a staff account is suspended", async () => {
    const staffId = "5cbdc2d4-37e4-4c39-86e7-77c7f1a4a401";
    const row = {
      id: staffId,
      staffCode: "#VA-123",
      fullName: "Verification Reviewer",
      email: "verification@example.test",
      role: "VERIFICATION_ADMIN",
      status: "ACTIVE",
      accessTokenDigest: "a".repeat(64),
      accessTokenPreview: "SAKHI-VA-••••",
      isAuthorisedComplaintReviewer: false,
      clearanceLevel: "LEVEL_2_VERIFICATION",
      permissions: { view: true, create: false, edit: true, approve: true, suspend: true, export: false, delete: false },
      createdBy: "Test Super Admin",
      lastLoginAt: null,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    const tx = {
      adminStaffAccount: {
        updateMany: vi.fn().mockResolvedValue({ count: 1 }),
        count: vi.fn().mockResolvedValue(2),
      },
      adminStaffSession: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
      adminStaffBackupCode: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
      adminStaffRecoveryRequest: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
      auditEvent: { create: vi.fn().mockResolvedValue({ id: "audit-suspend" }) },
    };
    const prisma = {
      adminStaffAccount: {
        findMany: vi.fn().mockResolvedValue([row]),
        findUnique: vi.fn().mockResolvedValue(row),
      },
      auditEvent: { findMany: vi.fn().mockResolvedValue([]) },
      businessDirectoryListing: { findMany: vi.fn().mockResolvedValue([]) },
      platformConfigSetting: { findUnique: vi.fn().mockResolvedValue(null) },
      $transaction: vi.fn(async (callback: (value: any) => Promise<unknown>) =>
        callback(tx),
      ),
    };

    await SakhiAdminRbacRegistry.updateStaffAccount(
      prisma as any,
      staffId,
      { status: "SUSPENDED" },
      "Test Super Admin",
      "00000000-0000-4000-8000-000000000001",
    );

    expect(tx.adminStaffSession.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { staffId, revokedAt: null },
        data: expect.objectContaining({
          revokeReason: "STAFF_ACCOUNT_CHANGED",
        }),
      }),
    );
    expect(tx.adminStaffBackupCode.updateMany).toHaveBeenCalled();
    expect(tx.adminStaffRecoveryRequest.updateMany).toHaveBeenCalled();
  });

  it("revokes sessions and invalidates backup/recovery material when a staff account is deleted", async () => {
    SakhiAdminRbacRegistry.resetForTesting();
    const staffId = "6cbdc2d4-37e4-4c39-86e7-77c7f1a4a402";
    const row = {
      id: staffId,
      staffCode: "#CM-124",
      fullName: "Content Moderator",
      email: "moderator@example.test",
      role: "CONTENT_MODERATOR",
      status: "ACTIVE",
      accessTokenDigest: "b".repeat(64),
      accessTokenPreview: "SAKHI-CM-••••",
      isAuthorisedComplaintReviewer: false,
      clearanceLevel: "LEVEL_2_MODERATION",
      permissions: { view: true, create: true, edit: true, approve: true, suspend: false, export: false, delete: true },
      createdBy: "Test Super Admin",
      lastLoginAt: null,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    const tx = {
      adminStaffAccount: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
      adminStaffSession: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
      adminStaffBackupCode: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
      adminStaffRecoveryRequest: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
      auditEvent: { create: vi.fn().mockResolvedValue({ id: "audit-delete" }) },
    };
    const prisma = {
      adminStaffAccount: { findMany: vi.fn().mockResolvedValue([row]) },
      auditEvent: { findMany: vi.fn().mockResolvedValue([]) },
      businessDirectoryListing: { findMany: vi.fn().mockResolvedValue([]) },
      platformConfigSetting: { findUnique: vi.fn().mockResolvedValue(null) },
      $transaction: vi.fn(async (callback: (value: any) => Promise<unknown>) =>
        callback(tx),
      ),
    };

    await SakhiAdminRbacRegistry.ensureHydrated(prisma as any);
    expect(SakhiAdminRbacRegistry.listStaff()).toEqual(
      expect.arrayContaining([expect.objectContaining({ id: staffId })]),
    );
    await SakhiAdminRbacRegistry.deleteStaffAccount(
      prisma as any,
      staffId,
      "Test Super Admin",
      "00000000-0000-4000-8000-000000000001",
    );

    expect(tx.adminStaffAccount.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          id: staffId,
          role: "CONTENT_MODERATOR",
          status: "ACTIVE",
          updatedAt: expect.any(Date),
        }),
        data: expect.objectContaining({ status: "REVOKED" }),
      }),
    );
    expect(tx.adminStaffSession.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { staffId, revokedAt: null },
        data: expect.objectContaining({ revokeReason: "STAFF_DELETED" }),
      }),
    );
    expect(tx.adminStaffBackupCode.updateMany).toHaveBeenCalled();
    expect(tx.adminStaffRecoveryRequest.updateMany).toHaveBeenCalled();
  });

  it("requires both create and edit permission for an upsert endpoint that can modify existing resources", async () => {
    vi.spyOn(
      StagingTestAdminService,
      "resolvePrincipalFromSessionToken",
    ).mockReturnValue(
      principal("CONTENT_MODERATOR", {
        permissions: {
          view: true,
          create: true,
          edit: false,
          approve: true,
          suspend: false,
          export: false,
          delete: false,
        },
      }),
    );
    const service = new AdminReviewService({} as any);

    await expect(
      service.upsertWellnessResource(
        { slug: "existing-guide", title: "Updated title" },
        SESSION,
      ),
    ).rejects.toThrow(/edit permission/i);
  });

  it("requires suspend permission when a staff account update changes its status", async () => {
    vi.spyOn(
      StagingTestAdminService,
      "resolvePrincipalFromSessionToken",
    ).mockReturnValue(
      principal("SUPER_ADMIN", {
        permissions: {
          view: true,
          create: true,
          edit: true,
          approve: true,
          suspend: false,
          export: true,
          delete: true,
        },
      }),
    );
    const prisma = {
      adminStaffAccount: { findMany: vi.fn().mockResolvedValue([]) },
      auditEvent: { findMany: vi.fn().mockResolvedValue([]) },
      businessDirectoryListing: { findMany: vi.fn().mockResolvedValue([]) },
      platformConfigSetting: { findUnique: vi.fn().mockResolvedValue(null) },
    };
    const service = new AdminReviewService(prisma as any);

    await expect(
      service.updateAdminStaff("staff-2", { status: "SUSPENDED" }, SESSION),
    ).rejects.toThrow(/suspend permission/i);
  });

