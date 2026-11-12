import { createHmac } from "node:crypto";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AdminMfaService } from "../src/admin-security/admin-mfa.service.js";
import type { PrismaService } from "../src/database/prisma.service.js";

const STAFF_ID = "2d5fce37-6aab-4cb4-8a6c-6a2d07f87e91";

function decodeBase32(input: string): Buffer {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  let bits = 0;
  let value = 0;
  const bytes: number[] = [];
  for (const character of input) {
    value = (value << 5) | alphabet.indexOf(character);
    bits += 5;
    if (bits >= 8) {
      bytes.push((value >>> (bits - 8)) & 255);
      bits -= 8;
    }
  }
  return Buffer.from(bytes);
}

function totp(secret: string, timestamp: number): string {
  const step = Math.floor(timestamp / 1000 / 30);
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(step));
  const digest = createHmac("sha1", decodeBase32(secret))
    .update(counter)
    .digest();
  const offset = digest[digest.length - 1]! & 0x0f;
  const value =
    ((digest[offset]! & 0x7f) << 24) |
    ((digest[offset + 1]! & 0xff) << 16) |
    ((digest[offset + 2]! & 0xff) << 8) |
    (digest[offset + 3]! & 0xff);
  return String(value % 1_000_000).padStart(6, "0");
}

describe("AdminMfaService", () => {
  const oldEncryptionKey = process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY;
  const oldEncryptionKeyVersion = process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY_VERSION;
  const oldEncryptionKeyV1 = process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY_V1;
  const oldEncryptionKeyV2 = process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY_V2;
  const oldSigningKey = process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY;

  afterEach(() => {
    vi.useRealTimers();
    if (oldEncryptionKey === undefined)
      delete process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY;
    else process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY = oldEncryptionKey;
    if (oldEncryptionKeyVersion === undefined) delete process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY_VERSION;
    else process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY_VERSION = oldEncryptionKeyVersion;
    if (oldEncryptionKeyV1 === undefined) delete process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY_V1;
    else process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY_V1 = oldEncryptionKeyV1;
    if (oldEncryptionKeyV2 === undefined) delete process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY_V2;
    else process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY_V2 = oldEncryptionKeyV2;
    if (oldSigningKey === undefined)
      delete process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY;
    else process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY = oldSigningKey;
    vi.restoreAllMocks();
  });

  it("encrypts TOTP secrets, verifies enrollment, rejects replay, and consumes backup codes once", async () => {
    process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY = Buffer.alloc(
      32,
      0x31,
    ).toString("base64");
    process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY =
      Buffer.alloc(32, 0x73).toString("base64");
    vi.useFakeTimers();
    const start = new Date("2026-11-09T12:00:00.000Z");
    vi.setSystemTime(start);

    let record: any = null;
    let acceptedStep = BigInt(-1);
    const backupDigests: string[] = [];
    let backupConsumed = false;
    const tx = {
      adminStaffMfa: {
        upsert: vi.fn(async ({ create, update }: any) => {
          record = {
            id: "mfa-record-id",
            failedAttemptCount: 0,
            lockedUntil: null,
            ...create,
          };
          return record;
        }),
        update: vi.fn(async ({ data }: any) => {
          const next = { ...record };
          for (const [key, value] of Object.entries(data)) {
            if (key === "failedAttemptCount" && (value as any)?.increment) {
              next.failedAttemptCount += (value as any).increment;
            } else {
              (next as any)[key] = value;
            }
          }
          record = next;
          return record;
        }),
        updateMany: vi.fn(async ({ where, data }: any) => {
          const replayThreshold = where.lastAcceptedTimeStep?.lt;
          if (
            (replayThreshold !== undefined &&
              record.lastAcceptedTimeStep >= replayThreshold) ||
            (where.enrollmentVerifiedAt === null && record.enrollmentVerifiedAt) ||
            (where.disabledAt === null && record.disabledAt)
          )
            return { count: 0 };
          record = { ...record, ...data };
          acceptedStep = data.lastAcceptedTimeStep ?? acceptedStep;
          return { count: 1 };
        }),
      },
      adminStaffBackupCode: {
        createMany: vi.fn(async ({ data }: any) => {
          backupDigests.push(...data.map((item: any) => item.codeDigest));
          return { count: data.length };
        }),
        updateMany: vi.fn(async ({ where }: any) => {
          if (backupConsumed || !backupDigests.includes(where.codeDigest))
            return { count: 0 };
          backupConsumed = true;
          return { count: 1 };
        }),
      },
      auditEvent: { create: vi.fn().mockResolvedValue({ id: "audit-id" }) },
    };
    const prisma = {
      adminStaffAccount: {
        findUnique: vi.fn().mockResolvedValue({
          id: STAFF_ID,
          email: "staff@sakhi.test",
          fullName: "Sakhi Staff",
          status: "ACTIVE",
        }),
      },
      adminStaffMfa: {
        findUnique: vi.fn(async () => record),
      },
      $transaction: vi.fn(async (callback: (txArg: any) => Promise<unknown>) =>
        callback(tx),
      ),
    } as unknown as PrismaService;

    const service = new AdminMfaService(prisma);
    const enrollment = await service.beginEnrollment(STAFF_ID);
    expect(enrollment.otpauthUri).toContain("otpauth://totp/");
    expect(record.encryptedSecret).not.toBe(enrollment.secret);
    expect(record.secretIv).toBeTruthy();
    expect(record.secretAuthTag).toBeTruthy();

    const enrollmentCode = totp(enrollment.secret, Date.now());
    const verified = await service.verifyEnrollment(STAFF_ID, enrollmentCode);
    expect(verified.enrolled).toBe(true);
    expect(verified.backupCodes).toHaveLength(10);
    expect(record.enrollmentVerifiedAt).toBeInstanceOf(Date);
    expect(backupDigests).toHaveLength(10);
    expect(backupDigests).not.toContain(verified.backupCodes[0]);

    vi.setSystemTime(new Date(start.getTime() + 30_000));
    const loginCode = totp(enrollment.secret, Date.now());
    await expect(
      service.verifyLoginFactor(STAFF_ID, loginCode),
    ).resolves.toEqual({ method: "TOTP" });
    await expect(
      service.verifyLoginFactor(STAFF_ID, loginCode),
    ).rejects.toThrow(/already used/i);

    await expect(
      service.verifyLoginFactor(STAFF_ID, verified.backupCodes[0]),
    ).resolves.toEqual({ method: "BACKUP_CODE" });
    await expect(
      service.verifyLoginFactor(STAFF_ID, verified.backupCodes[0]),
    ).rejects.toThrow(/invalid/i);
    for (let attempt = 0; attempt < 5 && !record.lockedUntil; attempt += 1) {
      await expect(service.verifyLoginFactor(STAFF_ID, "ABCDEF")).rejects.toThrow(/invalid/i);
    }
    expect(record.lockedUntil).toBeInstanceOf(Date);
    await expect(service.verifyLoginFactor(STAFF_ID, loginCode)).rejects.toThrow(/temporarily locked/i);
    expect(acceptedStep).toBeGreaterThan(BigInt(-1));
  });
  it("re-encrypts enrolled TOTP secrets from an old key version and records the new version atomically", async () => {
    const keyV1 = Buffer.alloc(32, 0x21).toString("base64");
    const keyV2 = Buffer.alloc(32, 0x42).toString("base64");
    process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY_V1 = keyV1;
    process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY_V2 = keyV2;
    process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY_VERSION = "v1";
    process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY = Buffer.alloc(32, 0x73).toString("base64");

    let record: any = null;
    const tx = {
      adminStaffMfa: {
        upsert: vi.fn(async ({ create }: any) => {
          record = { id: "mfa-rotation-record", staffId: STAFF_ID, ...create };
          return record;
        }),
        findMany: vi.fn(async () => record ? [record] : []),
        update: vi.fn(async ({ data }: any) => {
          record = { ...record, ...data };
          return record;
        }),
      },
      auditEvent: { create: vi.fn().mockResolvedValue({ id: "rotation-audit" }) },
    };
    const prisma = {
      adminStaffAccount: {
        findUnique: vi.fn().mockResolvedValue({
          id: STAFF_ID, email: "staff@sakhi.test", fullName: "Sakhi Staff", status: "ACTIVE",
        }),
      },
      adminStaffMfa: { findUnique: vi.fn(async () => record) },
      $transaction: vi.fn(async (callback: (txArg: any) => Promise<unknown>) => callback(tx)),
    } as unknown as PrismaService;
    const service = new AdminMfaService(prisma);
    const enrollment = await service.beginEnrollment(STAFF_ID);
    expect(record.encryptionKeyVersion).toBe("v1");

    process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY_VERSION = "v2";
    const result = await service.rotateStoredEncryptionKeys("00000000-0000-4000-8000-000000000001");
    expect(result).toEqual({ rotated: 1, targetVersion: "v2" });
    expect(record.encryptionKeyVersion).toBe("v2");
    expect(record.encryptedSecret).not.toBe(enrollment.secret);
    expect(tx.auditEvent.create).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({ action: "admin.mfa.encryption_keys_rotated" }),
    }));
  });

});
