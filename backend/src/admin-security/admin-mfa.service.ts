import {
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from "@nestjs/common";
import {
  createCipheriv,
  createDecipheriv,
  createHash,
  createHmac,
  randomBytes,
  randomUUID,
  timingSafeEqual,
} from "node:crypto";
import { PrismaService } from "../database/prisma.service.js";

const TOTP_PERIOD_SECONDS = 30;
const TOTP_DIGITS = 6;
const TOTP_WINDOW = 1;
const BACKUP_CODE_COUNT = 10;
const MFA_MAX_FAILED_ATTEMPTS = 5;
const MFA_LOCKOUT_MS = 15 * 60 * 1000;
const RECOVERY_TTL_MS = 30 * 60 * 1000;

function sha256Hex(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function currentEncryptionKeyVersion(): string {
  const version = process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY_VERSION?.trim() || "v1";
  if (!/^v[1-9][0-9]{0,3}$/.test(version)) {
    throw new UnauthorizedException("The MFA encryption key version is invalid.");
  }
  return version;
}

function encryptionKey(version = currentEncryptionKeyVersion()): Buffer {
  const versionedName = `SAKHI_ADMIN_MFA_ENCRYPTION_KEY_${version.toUpperCase()}`;
  const encoded =
    process.env[versionedName] ??
    (version === "v1" ? process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY : undefined) ??
    "";
  const key = Buffer.from(encoded, "base64");
  if (key.length !== 32 || key.toString("base64") !== encoded) {
    throw new UnauthorizedException(
      `The dedicated 32-byte base64 MFA encryption key for ${version} is not configured.`,
    );
  }
  const sessionKey = process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY ?? "";
  if (encoded === sessionKey || key.toString("utf8") === sessionKey) {
    throw new UnauthorizedException(
      "MFA encryption and staff session keys must be distinct.",
    );
  }
  return key;
}

function encodeBase32(input: Buffer): string {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  let bits = 0;
  let value = 0;
  let output = "";
  for (const byte of input) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      output += alphabet[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) output += alphabet[(value << (5 - bits)) & 31];
  return output;
}

function decodeBase32(input: string): Buffer {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  let bits = 0;
  let value = 0;
  const output: number[] = [];
  for (const character of input.replace(/=+$/g, "").toUpperCase()) {
    const index = alphabet.indexOf(character);
    if (index < 0) throw new Error("Invalid TOTP secret encoding.");
    value = (value << 5) | index;
    bits += 5;
    if (bits >= 8) {
      output.push((value >>> (bits - 8)) & 255);
      bits -= 8;
    }
  }
  return Buffer.from(output);
}

function encryptSecret(secret: string) {
  const encryptionKeyVersion = currentEncryptionKeyVersion();
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", encryptionKey(encryptionKeyVersion), iv);
  const encrypted = Buffer.concat([
    cipher.update(secret, "utf8"),
    cipher.final(),
  ]);
  return {
    encryptedSecret: encrypted.toString("base64"),
    secretIv: iv.toString("hex"),
    secretAuthTag: cipher.getAuthTag().toString("hex"),
    encryptionKeyVersion,
  };
}

function decryptSecret(record: {
  encryptedSecret: string;
  secretIv: string;
  secretAuthTag: string;
  encryptionKeyVersion?: string | null;
}): string {
  const version = record.encryptionKeyVersion || "v1";
  const decipher = createDecipheriv(
    "aes-256-gcm",
    encryptionKey(version),
    Buffer.from(record.secretIv, "hex"),
  );
  decipher.setAuthTag(Buffer.from(record.secretAuthTag, "hex"));
  return Buffer.concat([
    decipher.update(Buffer.from(record.encryptedSecret, "base64")),
    decipher.final(),
  ]).toString("utf8");
}

function totpAtStep(secret: string, step: number): string {
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(step));
  const digest = createHmac("sha1", decodeBase32(secret))
    .update(counter)
    .digest();
  const offset = digest[digest.length - 1]! & 0x0f;
  const binary =
    ((digest[offset]! & 0x7f) << 24) |
    ((digest[offset + 1]! & 0xff) << 16) |
    ((digest[offset + 2]! & 0xff) << 8) |
    (digest[offset + 3]! & 0xff);
  return String(binary % 10 ** TOTP_DIGITS).padStart(TOTP_DIGITS, "0");
}

function matchedTotpStep(
  secret: string,
  code: string,
  now = Date.now(),
): number | null {
  if (!/^\d{6}$/.test(code)) return null;
  const currentStep = Math.floor(now / 1000 / TOTP_PERIOD_SECONDS);
  let matched: number | null = null;
  for (let drift = -TOTP_WINDOW; drift <= TOTP_WINDOW; drift += 1) {
    const step = currentStep + drift;
    const expected = Buffer.from(totpAtStep(secret, step));
    const supplied = Buffer.from(code);
    if (
      expected.length === supplied.length &&
      timingSafeEqual(expected, supplied)
    ) {
      matched = matched === null ? step : Math.max(matched, step);
    }
  }
  return matched;
}

function normalizeBackupCode(code: string): string {
  return code.trim().replace(/[-\s]/g, "").toUpperCase();
}

function makeBackupCodes(): string[] {
  return Array.from({ length: BACKUP_CODE_COUNT }, () =>
    randomBytes(12).toString("base64url").toUpperCase(),
  );
}

@Injectable()
export class AdminMfaService {
  constructor(private readonly prisma: PrismaService) {}

  async beginEnrollment(staffId: string) {
    const staff = await this.prisma.adminStaffAccount.findUnique({
      where: { id: staffId },
      select: { id: true, email: true, fullName: true, status: true },
    });
    if (!staff || staff.status !== "ACTIVE") {
      throw new UnauthorizedException("The staff account is not active.");
    }
    const existing = await this.prisma.adminStaffMfa.findUnique({
      where: { staffId },
    });
    if (existing?.enrollmentVerifiedAt && !existing.disabledAt) {
      throw new ConflictException(
        "MFA is already enrolled. Use the approved recovery process to reset it.",
      );
    }

    const secret = encodeBase32(randomBytes(20));
    const encrypted = encryptSecret(secret);
    await this.prisma.$transaction(async (tx) => {
      await tx.adminStaffMfa.upsert({
        where: { staffId },
        create: { staffId, ...encrypted, lastAcceptedTimeStep: BigInt(-1) },
        update: {
          ...encrypted,
          enrollmentVerifiedAt: null,
          lastAcceptedTimeStep: BigInt(-1),
          failedAttemptCount: 0,
          lockedUntil: null,
          disabledAt: null,
          encryptionKeyVersion: encrypted.encryptionKeyVersion,
        },
      });
      await tx.auditEvent.create({
        data: {
          actorType: "ADMIN",
          actorId: staffId,
          action: "admin.mfa.enrollment_started",
          targetType: "admin_staff_account",
          targetId: staffId,
          outcome: "pending",
          requestId: randomUUID(),
          redactedMetadata: { method: "RFC6238_TOTP" },
        },
      });
    });

    const label = encodeURIComponent(`Sakhi Admin:${staff.email}`);
    const issuer = encodeURIComponent("Sakhi Admin");
    const otpauthUri = `otpauth://totp/${label}?secret=${secret}&issuer=${issuer}&algorithm=SHA1&digits=6&period=30`;
    return { secret, otpauthUri, accountLabel: staff.fullName };
  }

  private async recordFailedAttempt(
    staffId: string,
    mfaId: string,
    action: "admin.mfa.enrollment_failed" | "admin.mfa.login_failed",
  ) {
    await this.prisma.$transaction(async (tx) => {
      const updated = await tx.adminStaffMfa.update({
        where: { id: mfaId },
        data: { failedAttemptCount: { increment: 1 } },
        select: { failedAttemptCount: true },
      });
      const locked = updated.failedAttemptCount >= MFA_MAX_FAILED_ATTEMPTS;
      if (locked) {
        await tx.adminStaffMfa.update({
          where: { id: mfaId },
          data: {
            failedAttemptCount: 0,
            lockedUntil: new Date(Date.now() + MFA_LOCKOUT_MS),
          },
        });
      }
      await tx.auditEvent.create({
        data: {
          actorType: "ADMIN",
          actorId: staffId,
          action,
          targetType: "admin_staff_account",
          targetId: staffId,
          outcome: "denied",
          requestId: randomUUID(),
          redactedMetadata: {
            failedAttemptsBeforeReset: updated.failedAttemptCount,
            temporarilyLocked: locked,
            lockoutSeconds: locked ? MFA_LOCKOUT_MS / 1000 : 0,
          },
        },
      });
    });
  }

  private assertNotLocked(record: { lockedUntil?: Date | null }) {
    if (record.lockedUntil && record.lockedUntil.getTime() > Date.now()) {
      throw new UnauthorizedException(
        "Staff MFA is temporarily locked after repeated failures. Try again after the lockout expires.",
      );
    }
  }

  async verifyEnrollment(staffId: string, code: string) {
    const record = await this.prisma.adminStaffMfa.findUnique({
      where: { staffId },
    });
    if (!record || record.disabledAt || record.enrollmentVerifiedAt) {
      throw new ConflictException("No pending MFA enrollment exists.");
    }
    this.assertNotLocked(record);
    const secret = decryptSecret(record);
    const step = matchedTotpStep(secret, code);
    if (step === null) {
      await this.recordFailedAttempt(staffId, record.id, "admin.mfa.enrollment_failed");
      throw new UnauthorizedException("The authenticator code is invalid or expired.");
    }

    const backupCodes = makeBackupCodes();
    let accepted = false;
    await this.prisma.$transaction(async (tx) => {
      const updated = await tx.adminStaffMfa.updateMany({
        where: {
          id: record.id,
          enrollmentVerifiedAt: null,
          disabledAt: null,
          lastAcceptedTimeStep: { lt: BigInt(step) },
          OR: [{ lockedUntil: null }, { lockedUntil: { lte: new Date() } }],
        },
        data: {
          enrollmentVerifiedAt: new Date(),
          lastAcceptedTimeStep: BigInt(step),
          failedAttemptCount: 0,
          lockedUntil: null,
        },
      });
      if (updated.count !== 1) return;
      accepted = true;
      await tx.adminStaffBackupCode.createMany({
        data: backupCodes.map((backupCode) => ({
          staffId,
          codeDigest: sha256Hex(normalizeBackupCode(backupCode)),
        })),
      });
      await tx.auditEvent.create({
        data: {
          actorType: "ADMIN",
          actorId: staffId,
          action: "admin.mfa.enrollment_verified",
          targetType: "admin_staff_account",
          targetId: staffId,
          outcome: "success",
          requestId: randomUUID(),
          redactedMetadata: {
            method: "RFC6238_TOTP",
            backupCodeCount: backupCodes.length,
          },
        },
      });
    });
    if (!accepted) {
      await this.recordFailedAttempt(staffId, record.id, "admin.mfa.enrollment_failed");
      throw new ConflictException("The authenticator code was already used or enrollment changed.");
    }
    return { enrolled: true, backupCodes };
  }

  async verifyLoginFactor(staffId: string, code?: string) {
    if (!code?.trim()) {
      throw new UnauthorizedException("A staff MFA code is required.");
    }
    const record = await this.prisma.adminStaffMfa.findUnique({
      where: { staffId },
    });
    if (!record || !record.enrollmentVerifiedAt || record.disabledAt) {
      throw new UnauthorizedException(
        "Staff MFA enrollment is required before privileged access.",
      );
    }
    this.assertNotLocked(record);
    const secret = decryptSecret(record);
    const step = matchedTotpStep(secret, code.trim());
    if (step !== null) {
      let accepted = false;
      await this.prisma.$transaction(async (tx) => {
        const updated = await tx.adminStaffMfa.updateMany({
          where: {
            id: record.id,
            disabledAt: null,
            enrollmentVerifiedAt: { not: null },
            lastAcceptedTimeStep: { lt: BigInt(step) },
            OR: [{ lockedUntil: null }, { lockedUntil: { lte: new Date() } }],
          },
          data: {
            lastAcceptedTimeStep: BigInt(step),
            failedAttemptCount: 0,
            lockedUntil: null,
          },
        });
        if (updated.count !== 1) return;
        accepted = true;
        await tx.auditEvent.create({
          data: {
            actorType: "ADMIN",
            actorId: staffId,
            action: "admin.mfa.login_verified",
            targetType: "admin_staff_account",
            targetId: staffId,
            outcome: "success",
            requestId: randomUUID(),
            redactedMetadata: { method: "RFC6238_TOTP", timeStep: step },
          },
        });
      });
      if (accepted) return { method: "TOTP" as const };
    } else {
      const digest = sha256Hex(normalizeBackupCode(code));
      let consumedCode = false;
      await this.prisma.$transaction(async (tx) => {
        const consumed = await tx.adminStaffBackupCode.updateMany({
          where: { staffId, codeDigest: digest, usedAt: null },
          data: { usedAt: new Date() },
        });
        if (consumed.count !== 1) return;
        consumedCode = true;
        const unlocked = await tx.adminStaffMfa.updateMany({
          where: {
            id: record.id,
            disabledAt: null,
            OR: [{ lockedUntil: null }, { lockedUntil: { lte: new Date() } }],
          },
          data: { failedAttemptCount: 0, lockedUntil: null },
        });
        if (unlocked.count !== 1) {
          throw new UnauthorizedException(
            "Staff MFA is temporarily locked after repeated failures.",
          );
        }
        await tx.auditEvent.create({
          data: {
            actorType: "ADMIN",
            actorId: staffId,
            action: "admin.mfa.backup_code_consumed",
            targetType: "admin_staff_account",
            targetId: staffId,
            outcome: "success",
            requestId: randomUUID(),
            redactedMetadata: { method: "BACKUP_CODE" },
          },
        });
      });
      if (consumedCode) return { method: "BACKUP_CODE" as const };
    }

    await this.recordFailedAttempt(staffId, record.id, "admin.mfa.login_failed");
    throw new UnauthorizedException("The authenticator or backup code is invalid or already used.");
  }

  async requestRecovery(staffId: string) {
    const staff = await this.prisma.adminStaffAccount.findUnique({
      where: { id: staffId },
      select: {
        id: true,
        status: true,
        mfa: { select: { enrollmentVerifiedAt: true, disabledAt: true } },
      },
    });
    if (!staff || staff.status !== "ACTIVE") {
      throw new UnauthorizedException("The staff account is not active.");
    }
    if (!staff.mfa?.enrollmentVerifiedAt || staff.mfa.disabledAt) {
      throw new UnauthorizedException("MFA recovery is available only for an account with an active, verified authenticator enrollment.");
    }
    const requestId = randomUUID();
    try {
      await this.prisma.$transaction(async (tx) => {
        const now = new Date();
        await tx.adminStaffRecoveryRequest.updateMany({
          where: {
            staffId,
            status: { in: ["PENDING", "APPROVED"] },
            expiresAt: { lte: now },
          },
          data: { status: "EXPIRED" },
        });
        const pending = await tx.adminStaffRecoveryRequest.findFirst({
          where: {
            staffId,
            status: { in: ["PENDING", "APPROVED"] },
            expiresAt: { gt: now },
          },
          select: { id: true },
        });
        if (pending) {
          throw new ConflictException(
            "An active MFA recovery request already exists.",
          );
        }
        await tx.adminStaffRecoveryRequest.create({
          data: {
            id: requestId,
            staffId,
            challengeDigest: sha256Hex(randomBytes(32).toString("base64url")),
            expiresAt: new Date(now.getTime() + 24 * 60 * 60 * 1000),
          },
        });
        await tx.auditEvent.create({
          data: {
            actorType: "ADMIN",
            actorId: staffId,
            action: "admin.mfa.recovery_requested",
            targetType: "admin_staff_recovery_request",
            targetId: requestId,
            outcome: "pending",
            requestId: randomUUID(),
            redactedMetadata: { requiresIndependentSuperAdminApproval: true },
          },
        });
      });
    } catch (error) {
      const record =
        error && typeof error === "object"
          ? (error as {
              code?: unknown;
              message?: unknown;
              meta?: { target?: unknown };
            })
          : null;
      const uniqueTarget = Array.isArray(record?.meta?.target)
        ? record.meta.target.join(",")
        : String(record?.meta?.target ?? "");
      if (
        record?.code === "P2002" &&
        (uniqueTarget.includes("staff_id") ||
          String(record.message ?? "").includes(
            "admin_staff_recovery_one_active_per_staff_unique",
          ))
      ) {
        throw new ConflictException(
          "An active MFA recovery request already exists.",
        );
      }
      throw error;
    }
    return { requestId, status: "PENDING" as const };
  }

  async listPendingRecoveryRequests() {
    const rows = await this.prisma.adminStaffRecoveryRequest.findMany({
      where: { status: "PENDING", expiresAt: { gt: new Date() } },
      orderBy: { requestedAt: "asc" },
      select: {
        id: true,
        staffId: true,
        requestedAt: true,
        expiresAt: true,
        attemptCount: true,
        staff: { select: { staffCode: true, fullName: true, email: true, role: true, status: true } },
      },
    });
    return rows;
  }

  /**
   * Re-encrypts all enrolled TOTP secrets using the configured current key
   * version. Previous versioned keys must remain configured until this commits.
   * The data and audit events commit together.
   */
  async rotateStoredEncryptionKeys(actorStaffId: string) {
    const targetVersion = currentEncryptionKeyVersion();
    const targetKey = encryptionKey(targetVersion);
    void targetKey;
    return this.prisma.$transaction(async (tx) => {
      const records = await tx.adminStaffMfa.findMany({
        where: { disabledAt: null, encryptionKeyVersion: { not: targetVersion } },
      });
      let rotated = 0;
      for (const record of records) {
        const secret = decryptSecret(record);
        const encrypted = encryptSecret(secret);
        await tx.adminStaffMfa.update({
          where: { id: record.id },
          data: encrypted,
        });
        rotated += 1;
      }
      await tx.auditEvent.create({
        data: {
          actorType: "ADMIN",
          actorId: actorStaffId,
          action: "admin.mfa.encryption_keys_rotated",
          targetType: "admin_staff_mfa",
          outcome: "success",
          requestId: randomUUID(),
          redactedMetadata: { targetVersion, rotatedRecords: rotated },
        },
      });
      return { rotated, targetVersion };
    }, { isolationLevel: "Serializable" });
  }

  async approveRecoveryRequest(requestId: string, approverStaffId: string) {
    const approver = await this.prisma.adminStaffAccount.findUnique({
      where: { id: approverStaffId },
      select: { id: true, role: true, status: true },
    });
    const approverMfa = await this.prisma.adminStaffMfa.findUnique({
      where: { staffId: approverStaffId },
      select: { enrollmentVerifiedAt: true, disabledAt: true },
    });
    if (
      !approver ||
      approver.status !== "ACTIVE" ||
      approver.role !== "SUPER_ADMIN" ||
      !approverMfa?.enrollmentVerifiedAt ||
      approverMfa.disabledAt
    ) {
      throw new UnauthorizedException(
        "An active MFA-verified Super Admin must approve recovery.",
      );
    }

    const request = await this.prisma.adminStaffRecoveryRequest.findUnique({
      where: { id: requestId },
    });
    if (
      !request ||
      request.status !== "PENDING" ||
      request.expiresAt.getTime() <= Date.now() ||
      request.staffId === approverStaffId
    ) {
      throw new ConflictException(
        "The recovery request is unavailable or cannot be self-approved.",
      );
    }
    const recoveryToken = randomBytes(32).toString("base64url");
    const expiresAt = new Date(Date.now() + RECOVERY_TTL_MS);
    await this.prisma.$transaction(async (tx) => {
      const updated = await tx.adminStaffRecoveryRequest.updateMany({
        where: {
          id: requestId,
          status: "PENDING",
          expiresAt: { gt: new Date() },
        },
        data: {
          status: "APPROVED",
          challengeDigest: sha256Hex(recoveryToken),
          approvedByStaffId: approverStaffId,
          expiresAt,
        },
      });
      if (updated.count !== 1)
        throw new ConflictException(
          "The recovery request changed before approval.",
        );
      await tx.auditEvent.create({
        data: {
          actorType: "ADMIN",
          actorId: approverStaffId,
          action: "admin.mfa.recovery_approved",
          targetType: "admin_staff_recovery_request",
          targetId: requestId,
          outcome: "approved",
          requestId: randomUUID(),
          redactedMetadata: {
            targetStaffId: request.staffId,
            expiresAt: expiresAt.toISOString(),
          },
        },
      });
    });
    return { recoveryToken, expiresAt };
  }

  async completeRecovery(staffId: string, recoveryToken: string) {
    const digest = sha256Hex(recoveryToken);
    const request = await this.prisma.adminStaffRecoveryRequest.findUnique({
      where: { challengeDigest: digest },
    });
    if (
      !request ||
      request.staffId !== staffId ||
      request.status !== "APPROVED" ||
      request.expiresAt.getTime() <= Date.now()
    ) {
      throw new UnauthorizedException(
        "The approved recovery token is invalid or expired.",
      );
    }

    await this.prisma.$transaction(async (tx) => {
      const consumed = await tx.adminStaffRecoveryRequest.updateMany({
        where: {
          id: request.id,
          status: "APPROVED",
          challengeDigest: digest,
          expiresAt: { gt: new Date() },
        },
        data: { status: "COMPLETED", completedAt: new Date() },
      });
      if (consumed.count !== 1)
        throw new UnauthorizedException(
          "The recovery token has already been used.",
        );
      await tx.adminStaffMfa.updateMany({
        where: { staffId },
        data: {
          disabledAt: new Date(),
          enrollmentVerifiedAt: null,
          lastAcceptedTimeStep: BigInt(-1),
        },
      });
      await tx.adminStaffBackupCode.updateMany({
        where: { staffId, usedAt: null },
        data: { usedAt: new Date() },
      });
      const revoked = await tx.adminStaffSession.updateMany({
        where: { staffId, revokedAt: null },
        data: { revokedAt: new Date(), revokeReason: "MFA_RECOVERY" },
      });
      await tx.auditEvent.create({
        data: {
          actorType: "ADMIN",
          actorId: staffId,
          action: "admin.mfa.recovery_completed",
          targetType: "admin_staff_account",
          targetId: staffId,
          outcome: "success",
          requestId: randomUUID(),
          redactedMetadata: {
            approvedByStaffId: request.approvedByStaffId,
            revokedSessions: revoked.count,
            reenrollmentRequired: true,
          },
        },
      });
    });
    return { recovered: true, mfaEnrollmentRequired: true };
  }
}
