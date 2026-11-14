import "reflect-metadata";

import { createHash } from "node:crypto";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { PrismaService } from "../src/database/prisma.service.js";
import { StagingTestAdminService } from "../src/staging-test-admin/staging-test-admin.service.js";
import { SakhiAdminRbacRegistry } from "../src/admin-review/admin-rbac.helper.js";
import { databaseRequestIdentityStorage } from "../src/database/database-request-identity.context.js";

const ENV_KEYS = [
  "SAKHI_ENV",
  "NODE_ENV",
  "SAKHI_SYNTHETIC_FIXTURE_ENABLED",
  "SAKHI_STAGING_TEST_ADMIN_ENABLED",
  "SAKHI_STAGING_TEST_ADMIN_TOKEN",
  "SAKHI_STAGING_TEST_ADMIN_REVIEWER_LABEL",
  "SAKHI_STAGING_FULL_ADMIN_ENABLED",
  "SAKHI_STAGING_FULL_ADMIN_TOKEN",
  "SAKHI_STAGING_FULL_ADMIN_REVIEWER_LABEL",
  "SAKHI_ADMIN_CORS_ORIGIN",
  "SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY",
  "SAKHI_ADMIN_MFA_ENCRYPTION_KEY",
] as const;

const ORIGINAL_ENV = Object.fromEntries(
  ENV_KEYS.map((key) => [key, process.env[key]]),
) as Record<(typeof ENV_KEYS)[number], string | undefined>;

async function createStaffSession(
  prisma: ReturnType<typeof makeService>["prisma"],
  sessions: ReturnType<typeof makeService>["sessions"],
  role: "SUPER_ADMIN" | "VERIFICATION_ADMIN" | "COMPLAINT_REVIEWER" = "VERIFICATION_ADMIN",
) {
  const now = new Date();
  const row = {
    id: role === "SUPER_ADMIN"
      ? "2d5fce37-6aab-4cb4-8a6c-6a2d07f87e91"
      : "3e6fce37-6aab-4cb4-8a6c-6a2d07f87e92",
    staffCode: role === "SUPER_ADMIN" ? "#SA-123" : "#VA-123",
    fullName: "Staging Staff Test",
    email: "staging.staff@example.test",
    role,
    status: "ACTIVE",
    accessTokenDigest: createHash("sha256").update("first-factor-test-token").digest("hex"),
    accessTokenPreview: "SAKHI-STAFF-••••",
    isAuthorisedComplaintReviewer: role === "COMPLAINT_REVIEWER",
    clearanceLevel: role === "SUPER_ADMIN" ? "LEVEL_4_MASTER_GOVERNANCE" : "LEVEL_2_ELIGIBILITY_SUPPORT",
    permissions: {},
    createdBy: "Test fixture",
    lastLoginAt: null,
    createdAt: now,
    updatedAt: now,
  };
  prisma.adminStaffAccount.findMany.mockResolvedValue([row]);
  await SakhiAdminRbacRegistry.ensureHydrated(prisma as unknown as PrismaService);
  const staff = SakhiAdminRbacRegistry.listStaff()[0];
  if (!staff) throw new Error("Staff session fixture did not hydrate.");
  sessions.validateSession.mockResolvedValue({ staff: row });
  return SakhiAdminRbacRegistry.createSignedStaffSessionToken(
    staff,
    process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY!,
  ).value;
}

function makeService() {
  const transactionIdentities: Array<{ adminStaffId?: string; adminRole?: string } | undefined> = [];
  const tx = {
    adminStaffAccount: { create: vi.fn().mockResolvedValue({}) },
    memberAccount: { create: vi.fn().mockResolvedValue({ id: "synthetic-account" }) },
    memberProfile: { create: vi.fn().mockResolvedValue({ accountId: "synthetic-account" }) },
    authSession: { create: vi.fn().mockResolvedValue({ id: "synthetic-session" }) },
    auditEvent: {
      create: vi.fn().mockResolvedValue({ id: "audit-id" }),
    },
  };
  const prisma = {
    memberAccount: {
      findMany: vi.fn(),
      findUnique: vi.fn(),
    },
    adminStaffAccount: {
      findMany: vi.fn().mockResolvedValue([]),
      findFirst: vi.fn().mockResolvedValue(null),
    },
    adminStaffMfa: {
      findUnique: vi.fn().mockResolvedValue(null),
    },
    auditEvent: {
      findMany: vi.fn().mockResolvedValue([]),
      findFirst: vi.fn().mockResolvedValue(null),
    },
    $transaction: vi.fn(
      async (callback: (transaction: typeof tx) => Promise<unknown>) => {
        const identity = databaseRequestIdentityStorage.getStore();
        transactionIdentities.push(identity ? { ...identity } : undefined);
        return callback(tx);
      },
    ),
  };
  const sessions = {
    issueSession: vi.fn(),
    validateSession: vi.fn(),
    rotateSession: vi.fn(),
    revokeSession: vi.fn(),
  };
  const mfa = {
    beginEnrollment: vi.fn(),
    verifyEnrollment: vi.fn(),
    verifyLoginFactor: vi.fn(),
    requestRecovery: vi.fn(),
    approveRecoveryRequest: vi.fn(),
    completeRecovery: vi.fn(),
  };
  return {
    service: new StagingTestAdminService(
      prisma as unknown as PrismaService,
      sessions as any,
      mfa as any,
    ),
    prisma,
    tx,
    transactionIdentities,
    sessions,
    mfa,
  };
}

describe("StagingTestAdminService", () => {
  beforeEach(() => {
    process.env.SAKHI_ENV = "staging";
    process.env.NODE_ENV = "production";
    process.env.SAKHI_SYNTHETIC_FIXTURE_ENABLED = "true";
    process.env.SAKHI_STAGING_TEST_ADMIN_ENABLED = "true";
    process.env.SAKHI_STAGING_TEST_ADMIN_TOKEN =
      "test-only-secret-token-that-is-over-32-chars";
    process.env.SAKHI_STAGING_TEST_ADMIN_REVIEWER_LABEL =
      "Friend Testing Reviewer";
    process.env.SAKHI_STAGING_FULL_ADMIN_ENABLED = "true";
    process.env.SAKHI_STAGING_FULL_ADMIN_TOKEN =
      "full-staging-admin-secret-token-is-over-32-chars";
    process.env.SAKHI_STAGING_FULL_ADMIN_REVIEWER_LABEL = "Staging Super Admin";
    process.env.SAKHI_ADMIN_CORS_ORIGIN =
      "https://sakhi-staging-admin.onrender.com";
    process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY = Buffer.alloc(32, 0x73).toString("base64");
    process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY = Buffer.alloc(
      32,
      0x5a,
    ).toString("base64");
  });

  afterEach(() => {
    for (const key of ENV_KEYS) {
      const value = ORIGINAL_ENV[key];
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
    SakhiAdminRbacRegistry.resetForTesting();
    vi.restoreAllMocks();
  });

  it("restricts synthetic fixture creation to Super Admin and keeps the feature disabled by default", async () => {
    const { service, prisma, sessions } = makeService();
    const verificationSession = await createStaffSession(prisma, sessions, "VERIFICATION_ADMIN");
    await expect(
      service.createSyntheticMemberFixture(
        { acknowledgedTestOnly: true, reason: "Test fixture authorization boundary" },
        verificationSession,
      ),
    ).rejects.toThrow(/only an MFA-verified Super Admin/i);
    expect(prisma.$transaction).not.toHaveBeenCalled();

    SakhiAdminRbacRegistry.resetForTesting();
    const superAdminSession = await createStaffSession(prisma, sessions, "SUPER_ADMIN");
    process.env.SAKHI_SYNTHETIC_FIXTURE_ENABLED = "false";
    await expect(
      service.createSyntheticMemberFixture(
        { acknowledgedTestOnly: true, reason: "Test fixture feature flag boundary" },
        superAdminSession,
      ),
    ).rejects.toThrow(/synthetic staging fixtures are disabled/i);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it("creates only a marked synthetic staging member fixture with a hashed short-lived session", async () => {
    const { service, prisma, tx, sessions } = makeService();
    const sessionToken = await createStaffSession(prisma, sessions, "SUPER_ADMIN");

    const result = await service.createSyntheticMemberFixture(
      {
        acknowledgedTestOnly: true,
        reason: "Create isolated synthetic account deletion fixture",
      },
      sessionToken,
    );

    expect(result).toMatchObject({
      created: true,
      testOnly: true,
      fixtureId: expect.any(String),
      accountId: expect.any(String),
      authorization: expect.stringMatching(/^Bearer /),
    });
    expect(result.sessionExpiresAt).toBeTruthy();
    expect(tx.memberAccount.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        id: result.accountId,
        phoneE164: expect.stringMatching(/^\+999/),
        phoneVerifiedAt: null,
        status: "ACTIVE",
        verificationStatus: "UNVERIFIED",
      }),
    });
    expect(tx.memberProfile.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        accountId: result.accountId,
        email: expect.stringMatching(/@example\.invalid$/),
      }),
    });
    const sessionCreate = tx.authSession.create.mock.calls[0]?.[0];
    expect(sessionCreate.data.accountId).toBe(result.accountId);
    expect(sessionCreate.data.tokenDigest).not.toBe(result.authorization.slice(7));
    expect(sessionCreate.data.expiresAt.getTime()).toBeGreaterThan(Date.now());
    expect(tx.auditEvent.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        action: "staging.synthetic_member.created",
        targetType: "synthetic_member_fixture",
        targetId: result.fixtureId,
        redactedMetadata: expect.objectContaining({
          testOnly: true,
          syntheticFixture: true,
          fixtureId: result.fixtureId,
          accountId: result.accountId,
        }),
      }),
    });
  });

  it("rejects shared reviewer credentials as login credentials", async () => {
    const { service } = makeService();
    await expect(
      service.loginWithToken("test-only-secret-token-that-is-over-32-chars"),
    ).rejects.toThrow(/individual staff first-factor credential/i);
  });

  it("exposes the one-time bootstrap setup only while no Super Admin exists", async () => {
    const { service, prisma, sessions } = makeService();
    const fullToken = "full-staging-admin-secret-token-is-over-32-chars";
    await expect(service.loginWithToken(fullToken)).resolves.toMatchObject({
      authenticated: false,
      bootstrapRequired: true,
    });
    expect(sessions.issueSession).not.toHaveBeenCalled();

    prisma.adminStaffAccount.findFirst.mockResolvedValueOnce({ id: "existing-super-admin" } as any);
    await expect(service.loginWithToken(fullToken)).rejects.toThrow(
      /bootstrap is permanently closed/i,
    );
    await expect(
      service.sessionFromToken(
        "full-admin.1899999999.00000000-0000-4000-8000-000000000000.signature",
      ),
    ).rejects.toThrow(/legacy shared and stateless staging admin sessions are disabled/i);
    await expect(
      service.sessionFromToken(
        "test-access.1899999999.00000000-0000-4000-8000-000000000000.signature",
      ),
    ).rejects.toThrow(/legacy shared and stateless staging admin sessions are disabled/i);
  });

  it("creates the initial Super Admin and audit event under the same bootstrap RLS identity", async () => {
    const { service, prisma, tx, transactionIdentities } = makeService();
    const result = await service.bootstrapSuperAdmin(
      "full-staging-admin-secret-token-is-over-32-chars",
      "Initial Super Admin",
      "initial.superadmin@example.test",
    );

    expect(result).toMatchObject({
      created: true,
      staffCode: expect.stringMatching(/^#SA-/),
      accessToken: expect.stringMatching(/^SAKHI-SA-/),
      mfaEnrollmentRequired: true,
    });
    const accountCreate = tx.adminStaffAccount.create.mock.calls[0]?.[0];
    const auditCreate = tx.auditEvent.create.mock.calls[0]?.[0];
    expect(accountCreate.data.id).toEqual(expect.any(String));
    expect(accountCreate.data).toMatchObject({
      role: "SUPER_ADMIN",
      mustResetPassword: true,
    });
    expect(auditCreate.data).toMatchObject({
      actorType: "ADMIN",
      actorId: accountCreate.data.id,
      action: "admin.staff_account.created",
      targetType: "admin_staff_account",
      targetId: accountCreate.data.id,
    });
    expect(transactionIdentities).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          adminStaffId: accountCreate.data.id,
          adminRole: "SUPER_ADMIN",
        }),
      ]),
    );
    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
  });
  it("converts the database-enforced bootstrap uniqueness race into a closed bootstrap conflict", async () => {
    const { service } = makeService();
    const createSpy = vi
      .spyOn(SakhiAdminRbacRegistry, "createStaffAccount")
      .mockRejectedValue({
        code: "P2002",
        meta: { target: ["created_by"] },
      });
    await expect(
      service.bootstrapSuperAdmin(
        "full-staging-admin-secret-token-is-over-32-chars",
        "Initial Super Admin",
        "initial.superadmin@example.test",
      ),
    ).rejects.toThrow(/bootstrap has already been completed/i);
    expect(createSpy).toHaveBeenCalledTimes(1);
  });

  it("authenticates staff from the persisted credential digest and requires TOTP before issuing a persistent session", async () => {
    const { service, prisma, sessions, mfa } = makeService();
    const { SakhiAdminRbacRegistry } =
      await import("../src/admin-review/admin-rbac.helper.js");
    SakhiAdminRbacRegistry.resetForTesting();
    const staffToken = "staff-first-factor-token-".padEnd(48, "x");
    const staffRow = {
      id: "2d5fce37-6aab-4cb4-8a6c-6a2d07f87e91",
      staffCode: "#SA-123",
      fullName: "Initial Super Admin",
      email: "initial.superadmin@example.test",
      role: "SUPER_ADMIN",
      status: "ACTIVE",
      accessTokenDigest: createHash("sha256").update(staffToken).digest("hex"),
      accessTokenPreview: "SAKHI-STAFF-••••",
      isAuthorisedComplaintReviewer: true,
      clearanceLevel: "LEVEL_4_MASTER_GOVERNANCE",
      permissions: {},
      createdBy: "Bootstrap",
      lastLoginAt: null,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    prisma.adminStaffAccount.findFirst.mockResolvedValue(staffRow);
    prisma.adminStaffMfa.findUnique.mockResolvedValue({
      enrollmentVerifiedAt: new Date(),
      disabledAt: null,
    });
    mfa.verifyLoginFactor.mockResolvedValue({ method: "TOTP" });
    sessions.issueSession.mockResolvedValue({
      value: "staff-admin.persistent-session-token",
      expiresAt: new Date(Date.now() + 60_000),
    });

    try {
      const result = await service.loginWithToken(staffToken, "123456");
      expect(result).toMatchObject({
        authenticated: true,
        staffId: staffRow.id,
        role: "SUPER_ADMIN",
        mode: "staging_full_admin",
        sessionToken: "staff-admin.persistent-session-token",
      });
      expect(prisma.adminStaffAccount.findFirst).toHaveBeenCalledWith({
        where: {
          accessTokenDigest: createHash("sha256").update(staffToken).digest("hex"),
          status: "ACTIVE",
          suspendedAt: null,
          deletedAt: null,
        },
      });
      expect(mfa.verifyLoginFactor).toHaveBeenCalledWith(staffRow.id, "123456");
      expect(sessions.issueSession).toHaveBeenCalledWith(staffRow.id);
    } finally {
      SakhiAdminRbacRegistry.resetForTesting();
    }
  });

  it("accepts only signed individual staff sessions and enforces the configured admin origin", async () => {
    const { service, prisma, sessions } = makeService();
    const sessionToken = await createStaffSession(prisma, sessions);
    expect(await service.sessionFromToken(sessionToken)).toMatchObject({
      authenticated: true,
      mode: "staging_full_admin",
      role: "VERIFICATION_ADMIN",
    });
    await expect(service.sessionFromToken("test-only-secret-token-that-is-over-32-chars")).rejects.toThrow(
      /invalid|legacy shared/i,
    );
    expect(() =>
      service.assertAdminOrigin("https://untrusted.example"),
    ).toThrow(/configured Super Admin origin/i);
    expect(() => service.assertAdminOrigin(undefined)).toThrow(
      /configured Super Admin origin/i,
    );
    expect(() =>
      service.assertAdminOrigin("https://sakhi-staging-admin.onrender.com"),
    ).not.toThrow();
  });

  it("limits staging test-access decisions to Super Admin and Verification Admin staff roles", async () => {
    const { service, prisma, sessions } = makeService();
    const complaintSession = await createStaffSession(prisma, sessions, "COMPLAINT_REVIEWER");
    await expect(service.accounts(complaintSession)).rejects.toThrow(
      /Only an MFA-verified Super Admin or Verification Admin/i,
    );
  });

  it("records a test-only approval in the audit log without mutating real verification fields", async () => {
    const { service, prisma, tx, sessions } = makeService();
    const accountId = "30b7f836-0a38-4d43-a30b-9c87b88698a2";
    prisma.memberAccount.findUnique.mockResolvedValue({
      id: accountId,
      status: "PENDING_VERIFICATION",
      verificationStatus: "UNVERIFIED",
      profile: { accountId, displayName: "Friend Tester" },
    });
    prisma.auditEvent.findFirst.mockResolvedValue(null);

    const sessionToken = await createStaffSession(prisma, sessions);
    const result = await service.approve(
      accountId,
      {
        acknowledgedTestOnly: true,
        reason: "Friend tester needs access to restricted staging features.",
      },
      sessionToken,
    );

    expect(result).toMatchObject({
      accountId,
      testAccessApproved: true,
      status: "test_access_enabled",
    });
    expect(tx.auditEvent.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        action: "staging.test_access.approved",
        targetType: "member_account",
        targetId: accountId,
        outcome: "test_approved",
        redactedMetadata: expect.objectContaining({
          testOnly: true,
          actualEligibilityUnchanged: true,
          reviewerLabel: "Staging Staff Test (#VA-123 • Role 1 • Verification Admin)",
        }),
        actorId: "3e6fce37-6aab-4cb4-8a6c-6a2d07f87e92",
      }),
    });
    expect(prisma.memberAccount).not.toHaveProperty("update");
  });

  it("records revocation separately and requires a current test approval", async () => {
    const { service, prisma, tx, sessions } = makeService();
    const accountId = "30b7f836-0a38-4d43-a30b-9c87b88698a2";
    prisma.memberAccount.findUnique.mockResolvedValue({ id: accountId });
    prisma.auditEvent.findFirst.mockResolvedValue({
      action: "staging.test_access.approved",
      createdAt: new Date(),
    });

    const sessionToken = await createStaffSession(prisma, sessions);
    const result = await service.revoke(
      accountId,
      {
        acknowledgedTestOnly: true,
        reason: "Friend testing is complete; revoke temporary access.",
      },
      sessionToken,
    );
    expect(result).toMatchObject({
      accountId,
      testAccessApproved: false,
      status: "test_access_revoked",
    });
    expect(tx.auditEvent.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        action: "staging.test_access.revoked",
        actorId: "3e6fce37-6aab-4cb4-8a6c-6a2d07f87e92",
        targetType: "member_account",
        targetId: accountId,
        outcome: "revoked",
        redactedMetadata: expect.objectContaining({
          testOnly: true,
          actualEligibilityUnchanged: true,
        }),
      }),
    });
  });
});
