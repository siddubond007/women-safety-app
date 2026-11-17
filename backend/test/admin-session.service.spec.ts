import { createHash } from "node:crypto";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AdminSessionService } from "../src/admin-security/admin-session.service.js";
import type { PrismaService } from "../src/database/prisma.service.js";

const STAFF_ID = "2d5fce37-6aab-4cb4-8a6c-6a2d07f87e91";

describe("AdminSessionService", () => {
  const oldSigningKey = process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY;

  afterEach(() => {
    if (oldSigningKey === undefined)
      delete process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY;
    else process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY = oldSigningKey;
    vi.restoreAllMocks();
  });

  it("revokes one individual server-side session and writes a durable audit event", async () => {
    const token = "staff-admin.test-individual-revocation-token";
    const sessionRow = {
      id: "3e6fce37-6aab-4cb4-8a6c-6a2d07f87e92",
      staffId: STAFF_ID,
      revokedAt: null,
    };
    const tx = {
      adminStaffSession: {
        updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      },
      auditEvent: {
        create: vi.fn().mockResolvedValue({ id: "audit-revoke" }),
      },
    };
    const prisma = {
      adminStaffSession: {
        findUnique: vi.fn().mockResolvedValue(sessionRow),
      },
      $transaction: vi.fn(async (callback: (txArg: any) => Promise<unknown>) =>
        callback(tx),
      ),
    } as unknown as PrismaService;
    const service = new AdminSessionService(prisma);

    await expect(service.revokeSession(token, "LOGOUT")).resolves.toEqual({
      revoked: true,
    });
    expect(tx.adminStaffSession.updateMany).toHaveBeenCalledWith({
      where: { id: sessionRow.id, revokedAt: null },
      data: expect.objectContaining({ revokeReason: "LOGOUT" }),
    });
    expect(tx.auditEvent.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        actorId: STAFF_ID,
        action: "admin.staff_session.revoked",
        targetType: "admin_staff_session",
        targetId: sessionRow.id,
        outcome: "success",
      }),
    });
  });

  it("rechecks first-time setup state inside the session-creation transaction", async () => {
    process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY =
      Buffer.alloc(32, 0x73).toString("base64");
    const now = new Date();
    const createHarness = (account: Record<string, unknown>) => {
      const tx = {
        adminStaffAccount: {
          findUnique: vi.fn().mockResolvedValue({ id: STAFF_ID, status: "ACTIVE", ...account }),
          update: vi.fn().mockResolvedValue({ id: STAFF_ID }),
        },
        adminStaffMfa: {
          findUnique: vi.fn().mockResolvedValue({ enrollmentVerifiedAt: now, disabledAt: null }),
        },
        adminStaffSession: { create: vi.fn().mockResolvedValue({ id: "session-id" }) },
        auditEvent: { create: vi.fn().mockResolvedValue({ id: "audit-id" }) },
      };
      const prisma = {
        $transaction: vi.fn(async (callback: (txArg: any) => Promise<unknown>) => callback(tx)),
      } as unknown as PrismaService;
      return { service: new AdminSessionService(prisma), tx };
    };

    const pendingSetup = createHarness({ passwordHash: null, mustResetPassword: true });
    await expect(
      pendingSetup.service.issueSession(STAFF_ID, undefined, "INITIAL_SETUP"),
    ).resolves.toMatchObject({ sessionId: expect.any(String) });
    expect(pendingSetup.tx.adminStaffSession.create).toHaveBeenCalledTimes(1);

    const completedSetup = createHarness({
      passwordHash: "scrypt$fixture",
      mustResetPassword: false,
    });
    await expect(
      completedSetup.service.issueSession(STAFF_ID, undefined, "INITIAL_SETUP"),
    ).rejects.toThrow(/setup has already been completed/i);
    expect(completedSetup.tx.adminStaffSession.create).not.toHaveBeenCalled();

    const passwordLoginBeforeSetup = createHarness({
      passwordHash: "scrypt$fixture",
      mustResetPassword: true,
    });
    await expect(
      passwordLoginBeforeSetup.service.issueSession(STAFF_ID),
    ).rejects.toThrow(/complete initial staff password setup/i);
    expect(passwordLoginBeforeSetup.tx.adminStaffSession.create).not.toHaveBeenCalled();
  });

  it("stores only token digests, validates persistent sessions, rotates and revokes on rotated-token reuse", async () => {
    process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY =
      Buffer.alloc(32, 0x73).toString("base64");
    const now = new Date();
    const createdSessions: any[] = [];
    let oldSession: any = null;
    const tx = {
      adminStaffAccount: {
        findUnique: vi
          .fn()
          .mockResolvedValue({ id: STAFF_ID, status: "ACTIVE" }),
        update: vi.fn().mockResolvedValue({ id: STAFF_ID, lastLoginAt: now }),
      },
      adminStaffMfa: {
        findUnique: vi.fn().mockResolvedValue({
          enrollmentVerifiedAt: now,
          disabledAt: null,
        }),
      },
      adminStaffSession: {
        create: vi.fn(async ({ data }: any) => {
          createdSessions.push(data);
          if (!oldSession) {
            oldSession = {
              ...data,
              lastSeenAt: new Date(),
              revokedAt: null,
              staff: { id: STAFF_ID, status: "ACTIVE", deletedAt: null },
            };
          }
          return data;
        }),
        updateMany: vi.fn(async ({ where, data }: any) => {
          if (where.sessionFamilyId) {
            let count = 0;
            for (const item of createdSessions) {
              if (item.sessionFamilyId === where.sessionFamilyId && !item.revokedAt) {
                Object.assign(item, data);
                count += 1;
              }
            }
            if (oldSession?.sessionFamilyId === where.sessionFamilyId && !oldSession.revokedAt) {
              Object.assign(oldSession, data);
              count = Math.max(count, 1);
            }
            return { count };
          }
          const target = createdSessions.find((item) => item.id === where.id);
          if (!target || (where.revokedAt === null && target.revokedAt)) {
            return { count: 0 };
          }
          Object.assign(target, data);
          if (oldSession?.id === where.id) Object.assign(oldSession, data);
          return { count: 1 };
        }),
      },
      auditEvent: {
        create: vi.fn().mockResolvedValue({ id: "audit-id" }),
      },
    };
    const prisma = {
      $transaction: vi.fn(async (callback: (txArg: any) => Promise<unknown>) =>
        callback(tx),
      ),
      adminStaffMfa: {
        findUnique: vi.fn().mockResolvedValue({
          enrollmentVerifiedAt: new Date(),
          disabledAt: null,
        }),
      },
      adminStaffSession: {
        findUnique: vi.fn(async ({ where }: any) => {
          if (createdSessions.length === 0) return null;
          if (where.tokenDigest === createdSessions[0].tokenDigest)
            return oldSession;
          const row = createdSessions.find(
            (item) => item.tokenDigest === where.tokenDigest,
          );
          return row
            ? {
                ...row,
                lastSeenAt: new Date(),
                revokedAt: row.revokedAt ?? null,
                staff: { id: STAFF_ID, status: "ACTIVE", deletedAt: null },
              }
            : null;
        }),
        updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      },
    } as unknown as PrismaService;

    const service = new AdminSessionService(prisma);
    const issued = await service.issueSession(STAFF_ID);
    expect(issued.value).toMatch(/^staff-admin\./);
    expect(createdSessions[0].tokenDigest).toBe(
      createHash("sha256").update(issued.value).digest("hex"),
    );
    expect(createdSessions[0].tokenDigest).not.toContain(issued.value);

    const validated = await service.validateSession(issued.value);
    expect(validated.staff.id).toBe(STAFF_ID);

    const rotated = await service.rotateSession(issued.value);
    expect(rotated.value).not.toBe(issued.value);
    expect(createdSessions).toHaveLength(2);

    oldSession = {
      ...oldSession,
      revokedAt: new Date(),
      revokeReason: "ROTATED",
      sessionFamilyId: createdSessions[0].sessionFamilyId,
      staff: { id: STAFF_ID, status: "ACTIVE", deletedAt: null },
    };
    await expect(service.validateSession(issued.value)).rejects.toThrow(
      /revoked/i,
    );
    await expect(service.validateSession(rotated.value)).rejects.toThrow(
      /revoked/i,
    );
  });
});
  it("refuses to issue a persistent session unless staff MFA enrollment is verified and active", async () => {
    process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY = Buffer.alloc(
      32,
      7,
    ).toString("base64");
    const tx = {
      adminStaffAccount: {
        findUnique: vi.fn().mockResolvedValue({
          id: STAFF_ID,
          status: "ACTIVE",
          suspendedAt: null,
          deletedAt: null,
        }),
        update: vi.fn(),
      },
      adminStaffMfa: {
        findUnique: vi.fn().mockResolvedValue({
          enrollmentVerifiedAt: null,
          disabledAt: null,
        }),
      },
      adminStaffSession: { create: vi.fn() },
      auditEvent: { create: vi.fn() },
    };
    const prisma = {
      $transaction: vi.fn(async (callback: (value: any) => Promise<unknown>) =>
        callback(tx),
      ),
    };
    const service = new AdminSessionService(prisma as any);

    await expect(service.issueSession(STAFF_ID)).rejects.toThrow(
      /Verified staff MFA enrollment is required/i,
    );
    expect(tx.adminStaffSession.create).not.toHaveBeenCalled();
    expect(tx.auditEvent.create).not.toHaveBeenCalled();
  });

  it("revokes an already-issued session when its MFA enrollment is disabled", async () => {
    process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY = Buffer.alloc(
      32,
      8,
    ).toString("base64");
    const now = new Date();
    let storedSession: any;
    const tx = {
      adminStaffAccount: {
        findUnique: vi.fn().mockResolvedValue({
          id: STAFF_ID,
          status: "ACTIVE",
          suspendedAt: null,
          deletedAt: null,
        }),
        update: vi.fn(),
      },
      adminStaffMfa: {
        findUnique: vi.fn().mockResolvedValue({
          enrollmentVerifiedAt: now,
          disabledAt: null,
        }),
      },
      adminStaffSession: {
        create: vi.fn(async ({ data }: any) => {
          storedSession = {
            ...data,
            revokedAt: null,
            revokeReason: null,
            lastSeenAt: now,
            staff: {
              id: STAFF_ID,
              status: "ACTIVE",
              suspendedAt: null,
              deletedAt: null,
            },
          };
          return storedSession;
        }),
        updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      },
      auditEvent: { create: vi.fn().mockResolvedValue({ id: "audit-mfa-revoke" }) },
    };
    const prisma = {
      $transaction: vi.fn(async (callback: (value: any) => Promise<unknown>) =>
        callback(tx),
      ),
      adminStaffSession: {
        findUnique: vi.fn(async () => storedSession),
      },
      adminStaffMfa: {
        findUnique: vi.fn().mockResolvedValue({
          enrollmentVerifiedAt: now,
          disabledAt: new Date(),
        }),
      },
    };
    const service = new AdminSessionService(prisma as any);
    const issued = await service.issueSession(STAFF_ID);

    await expect(service.validateSession(issued.value)).rejects.toThrow(
      /MFA is no longer active/i,
    );
    expect(tx.adminStaffSession.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ revokeReason: "MFA_NOT_ACTIVE" }),
      }),
    );
  });

