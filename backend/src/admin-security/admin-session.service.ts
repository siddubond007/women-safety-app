import { Injectable, UnauthorizedException } from "@nestjs/common";
import {
  createHash,
  createHmac,
  randomUUID,
  timingSafeEqual,
} from "node:crypto";
import { PrismaService } from "../database/prisma.service.js";

const SESSION_TTL_SECONDS = 8 * 60 * 60;
const SESSION_IDLE_TIMEOUT_MS = 30 * 60 * 1000;
const sha256Hex = (value: string) =>
  createHash("sha256").update(value).digest("hex");

function signingKey(): string {
  const encoded = process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY ?? "";
  const key = Buffer.from(encoded, "base64");
  if (key.length !== 32 || key.toString("base64") !== encoded) {
    throw new UnauthorizedException(
      "A dedicated base64-encoded 32-byte staff-session signing key is not configured.",
    );
  }
  return encoded;
}

function signStaffSession(
  staffId: string,
  sessionId: string,
  expiresAtSeconds: number,
): string {
  const payload = `staff-admin.${staffId}.${sessionId}.${expiresAtSeconds}`;
  const signature = createHmac("sha256", Buffer.from(signingKey(), "base64"))
    .update(`sakhi-staff-session:${payload}`)
    .digest("base64url");
  return `${payload}.${signature}`;
}

function verifySignedToken(token: string) {
  const parts = token.split(".");
  if (parts.length !== 5 || parts[0] !== "staff-admin") return null;
  const staffId = parts[1] ?? "";
  const sessionId = parts[2] ?? "";
  const expiresAtSeconds = Number(parts[3] ?? "");
  const supplied = Buffer.from(parts[4] ?? "", "base64url");
  if (
    !/^[0-9a-f-]{36}$/i.test(staffId) ||
    !/^[0-9a-f-]{36}$/i.test(sessionId) ||
    !Number.isSafeInteger(expiresAtSeconds) ||
    expiresAtSeconds <= Math.floor(Date.now() / 1000)
  )
    return null;
  const payload = `staff-admin.${staffId}.${sessionId}.${expiresAtSeconds}`;
  const expected = createHmac("sha256", Buffer.from(signingKey(), "base64"))
    .update(`sakhi-staff-session:${payload}`)
    .digest();
  if (
    supplied.length !== expected.length ||
    !timingSafeEqual(supplied, expected)
  )
    return null;
  return { staffId, sessionId, expiresAt: new Date(expiresAtSeconds * 1000) };
}

@Injectable()
export class AdminSessionService {
  constructor(private readonly prisma: PrismaService) {}

  async issueSession(
    staffId: string,
    sessionFamilyId = randomUUID(),
    authenticationMode: "INITIAL_SETUP" | "PASSWORD_MFA" = "PASSWORD_MFA",
  ) {
    const sessionId = randomUUID();
    const expiresAt = new Date(Date.now() + SESSION_TTL_SECONDS * 1000);
    const token = signStaffSession(
      staffId,
      sessionId,
      Math.floor(expiresAt.getTime() / 1000),
    );

    await this.prisma.$transaction(async (tx) => {
      const staff = await tx.adminStaffAccount.findUnique({
        where: { id: staffId },
        select: {
          id: true,
          status: true,
          suspendedAt: true,
          deletedAt: true,
          passwordHash: true,
          mustResetPassword: true,
        },
      });
      if (!staff || staff.status !== "ACTIVE" || staff.suspendedAt || staff.deletedAt) {
        throw new UnauthorizedException("The staff account is not active.");
      }
      const requiresInitialSetup = Boolean(
        staff.mustResetPassword || staff.passwordHash === null,
      );
      if (
        (authenticationMode === "INITIAL_SETUP" && !requiresInitialSetup) ||
        (authenticationMode === "PASSWORD_MFA" && requiresInitialSetup)
      ) {
        throw new UnauthorizedException(
          authenticationMode === "INITIAL_SETUP"
            ? "Initial setup has already been completed. Sign in with password and TOTP."
            : "Complete initial staff password setup before credential sign-in.",
        );
      }
      await tx.adminStaffAccount.update({
        where: { id: staffId },
        data: { lastLoginAt: new Date() },
      });
      const mfa = await tx.adminStaffMfa.findUnique({
        where: { staffId },
        select: { enrollmentVerifiedAt: true, disabledAt: true },
      });
      if (!mfa?.enrollmentVerifiedAt || mfa.disabledAt) {
        throw new UnauthorizedException(
          "Verified staff MFA enrollment is required.",
        );
      }
      await tx.adminStaffSession.create({
        data: {
          id: sessionId,
          staffId,
          sessionFamilyId,
          tokenDigest: sha256Hex(token),
          expiresAt,
        },
      });
      await tx.auditEvent.create({
        data: {
          actorType: "ADMIN",
          actorId: staffId,
          action: "admin.staff_session.created",
          targetType: "admin_staff_session",
          targetId: sessionId,
          outcome: "success",
          requestId: randomUUID(),
          redactedMetadata: {
            sessionFamilyId,
            expiresAt: expiresAt.toISOString(),
          },
        },
      });
    });
    return { value: token, sessionId, expiresAt };
  }

  async validateSession(token: string) {
    const signed = verifySignedToken(token);
    if (!signed)
      throw new UnauthorizedException(
        "The staff session is invalid or expired.",
      );
    const session = await this.prisma.adminStaffSession.findUnique({
      where: { tokenDigest: sha256Hex(token) },
      include: { staff: true },
    });
    if (
      !session ||
      session.id !== signed.sessionId ||
      session.staffId !== signed.staffId
    ) {
      throw new UnauthorizedException("The staff session is invalid.");
    }
    if (session.revokedAt) {
      if (session.revokeReason === "ROTATED") {
        await this.prisma.$transaction(async (tx) => {
          const now = new Date();
          const revoked = await tx.adminStaffSession.updateMany({
            where: {
              sessionFamilyId: session.sessionFamilyId,
              revokedAt: null,
            },
            data: { revokedAt: now, revokeReason: "ROTATED_TOKEN_REUSE" },
          });
          if (revoked.count > 0) {
            await tx.auditEvent.create({
              data: {
                actorType: "ADMIN",
                actorId: session.staffId,
                action: "admin.staff_session.reuse_detected",
                targetType: "admin_staff_session_family",
                targetId: session.sessionFamilyId,
                outcome: "revoked",
                requestId: randomUUID(),
                redactedMetadata: { revokedSessions: revoked.count },
              },
            });
          }
        });
      }
      throw new UnauthorizedException("The staff session has been revoked.");
    }
    if (
      session.expiresAt.getTime() <= Date.now() ||
      session.staff.status !== "ACTIVE" ||
      session.staff.suspendedAt ||
      session.staff.deletedAt
    ) {
      throw new UnauthorizedException(
        "The staff session is expired or its account is inactive.",
      );
    }
    const mfa = await this.prisma.adminStaffMfa.findUnique({
      where: { staffId: session.staffId },
      select: { enrollmentVerifiedAt: true, disabledAt: true },
    });
    if (!mfa?.enrollmentVerifiedAt || mfa.disabledAt) {
      await this.revokeSession(token, "MFA_NOT_ACTIVE");
      throw new UnauthorizedException(
        "Verified staff MFA is no longer active. Complete MFA enrollment before signing in again.",
      );
    }
    if (Date.now() - session.lastSeenAt.getTime() > SESSION_IDLE_TIMEOUT_MS) {
      await this.revokeSession(token, "IDLE_TIMEOUT");
      throw new UnauthorizedException("The staff session expired after inactivity.");
    }
    const touched = await this.prisma.adminStaffSession.updateMany({
      where: {
        id: session.id,
        staffId: session.staffId,
        revokedAt: null,
        expiresAt: { gt: new Date() },
      },
      data: { lastSeenAt: new Date() },
    });
    if (touched.count !== 1) {
      throw new UnauthorizedException(
        "The staff session was revoked or expired during validation.",
      );
    }
    return { session, staff: session.staff };
  }

  async rotateSession(token: string) {
    const { session, staff } = await this.validateSession(token);
    const nextSessionId = randomUUID();
    const expiresAt = new Date(Date.now() + SESSION_TTL_SECONDS * 1000);
    const nextToken = signStaffSession(
      staff.id,
      nextSessionId,
      Math.floor(expiresAt.getTime() / 1000),
    );
    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      const revoked = await tx.adminStaffSession.updateMany({
        where: { id: session.id, revokedAt: null, expiresAt: { gt: now } },
        data: {
          revokedAt: now,
          rotatedAt: now,
          revokeReason: "ROTATED",
          replacedBySessionId: nextSessionId,
        },
      });
      if (revoked.count !== 1)
        throw new UnauthorizedException(
          "The staff session changed; sign in again.",
        );
      await tx.adminStaffSession.create({
        data: {
          id: nextSessionId,
          staffId: staff.id,
          sessionFamilyId: session.sessionFamilyId,
          tokenDigest: sha256Hex(nextToken),
          expiresAt,
        },
      });
      await tx.auditEvent.create({
        data: {
          actorType: "ADMIN",
          actorId: staff.id,
          action: "admin.staff_session.rotated",
          targetType: "admin_staff_session",
          targetId: session.id,
          outcome: "success",
          requestId: randomUUID(),
          redactedMetadata: { replacedBySessionId: nextSessionId },
        },
      });
    });
    return { value: nextToken, sessionId: nextSessionId, expiresAt };
  }

  async revokeSession(token: string, reason = "LOGOUT") {
    const session = await this.prisma.adminStaffSession.findUnique({
      where: { tokenDigest: sha256Hex(token) },
      select: { id: true, staffId: true, revokedAt: true },
    });
    if (!session || session.revokedAt) return { revoked: false };
    await this.prisma.$transaction(async (tx) => {
      const result = await tx.adminStaffSession.updateMany({
        where: { id: session.id, revokedAt: null },
        data: { revokedAt: new Date(), revokeReason: reason.slice(0, 80) },
      });
      if (result.count !== 1)
        throw new UnauthorizedException("The session could not be revoked.");
      await tx.auditEvent.create({
        data: {
          actorType: "ADMIN",
          actorId: session.staffId,
          action: "admin.staff_session.revoked",
          targetType: "admin_staff_session",
          targetId: session.id,
          outcome: "success",
          requestId: randomUUID(),
          redactedMetadata: { reason },
        },
      });
    });
    return { revoked: true };
  }

  async revokeAllForStaff(staffId: string, reason: string) {
    return this.prisma.$transaction(async (tx) => {
      const now = new Date();
      const result = await tx.adminStaffSession.updateMany({
        where: { staffId, revokedAt: null },
        data: { revokedAt: now, revokeReason: reason.slice(0, 80) },
      });
      await tx.auditEvent.create({
        data: {
          actorType: "ADMIN",
          actorId: staffId,
          action: "admin.staff_sessions.revoked_all",
          targetType: "admin_staff_account",
          targetId: staffId,
          outcome: "success",
          requestId: randomUUID(),
          redactedMetadata: { reason, revokedSessions: result.count },
        },
      });
      return { revokedSessions: result.count };
    });
  }
}
