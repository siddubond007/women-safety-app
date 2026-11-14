import "reflect-metadata";
import {
  createHash,
  createHmac,
  randomBytes,
  randomUUID,
  scryptSync,
} from "node:crypto";
import { ConfigService } from "@nestjs/config";
import { Pool } from "pg";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { PrismaService } from "../src/database/prisma.service.js";
import { runWithDatabaseRequestIdentity } from "../src/database/database-request-identity.context.js";
import { AdminMfaService } from "../src/admin-security/admin-mfa.service.js";
import { AdminSessionService } from "../src/admin-security/admin-session.service.js";
import { StagingTestAdminService } from "../src/staging-test-admin/staging-test-admin.service.js";
import { AdminReviewService } from "../src/admin-review/admin-review.service.js";
import { assertSakhiDatabaseTarget } from "../src/config/database-target.js";

function totpAtStep(secret: string, step: number): string {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  let bits = 0;
  let value = 0;
  const bytes: number[] = [];
  for (const character of secret) {
    value = (value << 5) | alphabet.indexOf(character);
    bits += 5;
    if (bits >= 8) {
      bytes.push((value >>> (bits - 8)) & 255);
      bits -= 8;
    }
  }
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(step));
  const digest = createHmac("sha1", Buffer.from(bytes))
    .update(counter)
    .digest();
  const offset = digest[digest.length - 1]! & 0x0f;
  const binary =
    ((digest[offset]! & 0x7f) << 24) |
    ((digest[offset + 1]! & 0xff) << 16) |
    ((digest[offset + 2]! & 0xff) << 8) |
    (digest[offset + 3]! & 0xff);
  return String(binary % 1_000_000).padStart(6, "0");
}

const enabled = process.env.SAKHI_STAGING_MFA_DB_INTEGRATION === "true";

describe.skipIf(!enabled)("database-backed staff MFA lifecycle", () => {
  let prisma: PrismaService | undefined;
  let mfa: AdminMfaService;
  let sessions: AdminSessionService;
  let stagingAdmin: StagingTestAdminService;
  let adminReview: AdminReviewService;
  let cleanup: Pool;
  const targetId = randomUUID();
  const approverId = randomUUID();
  const passwordStaffId = randomUUID();
  const passwordStaffEmail = `mfa-password-${passwordStaffId}@example.test`;
  const passwordStaffPassword = `Synthetic-${randomUUID()}-Only`;
  const passwordSalt = randomBytes(16).toString("hex");
  const passwordDerived = scryptSync(passwordStaffPassword, passwordSalt, 64, {
    N: 16384,
    r: 8,
    p: 1,
  }).toString("hex");
  const passwordHash = `scrypt$16384$8$1$${passwordSalt}$${passwordDerived}`;
  const targetCredential = `synthetic-target-credential-${randomUUID()}`;
  const approverCredential = `synthetic-approver-credential-${randomUUID()}`;
  const ids = [targetId, approverId, passwordStaffId];

  const withIdentity = <T>(
    staffId: string,
    role: string,
    operation: () => Promise<T>,
  ) =>
    runWithDatabaseRequestIdentity(operation, {
      adminStaffId: staffId,
      adminRole: role,
    });

  beforeAll(async () => {
    if (process.env.SAKHI_ENV !== "staging" || process.env.NODE_ENV !== "production") {
      throw new Error(
        "Full staff MFA lifecycle integration is staging-only and requires SAKHI_ENV=staging and NODE_ENV=production.",
      );
    }
    const appUrl = process.env.SAKHI_APP_DATABASE_URL ?? "";
    assertSakhiDatabaseTarget(appUrl, "app", "staging");
    const parsed = new URL(appUrl);
    if (!process.env.SAKHI_MIGRATOR_DATABASE_URL) {
      throw new Error(
        "The explicitly configured staging migrator URL is required for synthetic fixture cleanup.",
      );
    }
    assertSakhiDatabaseTarget(
      process.env.SAKHI_MIGRATOR_DATABASE_URL,
      "migrator",
      "staging",
    );
    const migratorUrl = new URL(process.env.SAKHI_MIGRATOR_DATABASE_URL);
    if (
      migratorUrl.hostname !== parsed.hostname ||
      migratorUrl.pathname !== parsed.pathname ||
      migratorUrl.port !== parsed.port
    ) {
      throw new Error(
        "Refusing synthetic MFA fixture cleanup unless the staging migrator URL targets the same staging database host, path, and port as the application URL.",
      );
    }
    process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY = Buffer.alloc(
      32,
      0x31,
    ).toString("base64");
    process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY = Buffer.alloc(
      32,
      0x73,
    ).toString("base64");
    prisma = new PrismaService(new ConfigService(process.env));
    mfa = new AdminMfaService(prisma);
    sessions = new AdminSessionService(prisma);
    stagingAdmin = new StagingTestAdminService(prisma, sessions, mfa);
    adminReview = new AdminReviewService(prisma, undefined, mfa, sessions);
    cleanup = new Pool({
      connectionString: process.env.SAKHI_MIGRATOR_DATABASE_URL,
    });
    const principal = await prisma!.$queryRaw<Array<{ role: string }>>`SELECT current_user::text AS role`;
    expect(principal[0]?.role).toBe("sakhi_staging_app");

    await prisma!.withSystemAdminIdentity(async (tx) => {
      await tx.adminStaffAccount.createMany({
        data: [
          {
            id: targetId,
            staffCode: `SYN-MFA-${targetId.slice(0, 8)}`,
            fullName: "Synthetic MFA Target",
            email: `mfa-target-${targetId}@example.test`,
            role: "COMPLAINT_REVIEWER",
            status: "ACTIVE",
            accessTokenDigest: createHash("sha256")
              .update(targetCredential)
              .digest("hex"),
            accessTokenPreview: "SYNTHETIC",
            isAuthorisedComplaintReviewer: false,
            clearanceLevel: "LEVEL_2_TRUST_SAFETY",
            permissions: {},
          },
          {
            id: approverId,
            staffCode: `SYN-MFA-${approverId.slice(0, 8)}`,
            fullName: "Synthetic MFA Super Admin",
            email: `mfa-approver-${approverId}@example.test`,
            role: "SUPER_ADMIN",
            status: "ACTIVE",
            accessTokenDigest: createHash("sha256")
              .update(approverCredential)
              .digest("hex"),
            accessTokenPreview: "SYNTHETIC",
            isAuthorisedComplaintReviewer: true,
            clearanceLevel: "LEVEL_4_MASTER_GOVERNANCE",
            permissions: { approve: true },
          },
          {
            id: passwordStaffId,
            staffCode: `SYN-MFA-${passwordStaffId.slice(0, 8)}`,
            fullName: "Synthetic Password Login Staff",
            email: passwordStaffEmail,
            passwordHash,
            role: "COMPLAINT_REVIEWER",
            status: "ACTIVE",
            accessTokenDigest: createHash("sha256")
              .update(randomUUID())
              .digest("hex"),
            accessTokenPreview: "SYNTHETIC",
            isAuthorisedComplaintReviewer: false,
            clearanceLevel: "LEVEL_2_TRUST_SAFETY",
            permissions: {},
          },
        ],
      });
    });
  }, 30_000);

  afterAll(async () => {
    if (cleanup) {
      await cleanup.query(
        "DELETE FROM public.admin_staff_recovery_requests WHERE staff_id = ANY($1::uuid[])",
        [ids],
      );
      await cleanup.query(
        "DELETE FROM public.admin_staff_backup_codes WHERE staff_id = ANY($1::uuid[])",
        [ids],
      );
      await cleanup.query(
        "DELETE FROM public.admin_staff_sessions WHERE staff_id = ANY($1::uuid[])",
        [ids],
      );
      await cleanup.query(
        "DELETE FROM public.admin_staff_mfa WHERE staff_id = ANY($1::uuid[])",
        [ids],
      );
      await cleanup.query(
        "DELETE FROM public.admin_staff_accounts WHERE id = ANY($1::uuid[])",
        [ids],
      );
      await cleanup.end();
    }
    await prisma?.$disconnect();
  });

  it("enrolls synthetic staff, enforces TOTP replay and one-time recovery codes, and revokes sessions on approved recovery", async () => {
    let targetSessionToken = "";
    const targetEnrollment = await runWithDatabaseRequestIdentity(
      () => stagingAdmin.startStaffMfaEnrollment(targetCredential),
      {},
    );
    const currentStep = Math.floor(Date.now() / 30_000);
    const targetEnrollmentCode = totpAtStep(
      targetEnrollment.secret,
      currentStep,
    );
    const targetVerified = await runWithDatabaseRequestIdentity(
      () =>
        stagingAdmin.verifyStaffMfaEnrollment(
          targetCredential,
          targetEnrollmentCode,
        ),
      {},
    );
    expect(targetVerified).toMatchObject({ enrolled: true });
    expect(targetVerified.backupCodes).toHaveLength(10);
    await expect(
      withIdentity(targetId, "COMPLAINT_REVIEWER", () =>
        mfa.verifyEnrollment(targetId, targetEnrollmentCode),
      ),
    ).rejects.toThrow();

    const targetCodes = await prisma!.adminStaffMfa.findUniqueOrThrow({
      where: { staffId: targetId },
    });
    expect(targetCodes.enrollmentVerifiedAt).toBeInstanceOf(Date);
    expect(targetCodes.encryptedSecret).not.toBe(targetEnrollment.secret);

    const realNow = Date.now;
    Date.now = () => realNow() + 30_000;
    try {
      const nextStepCode = totpAtStep(targetEnrollment.secret, currentStep + 1);
      const login = await runWithDatabaseRequestIdentity(
        () => stagingAdmin.loginWithToken(targetCredential, nextStepCode),
        {},
      );
      expect(login).toMatchObject({
        authenticated: true,
        role: "COMPLAINT_REVIEWER",
      });
      if (!login.authenticated || !login.sessionToken) {
        throw new Error(
          "Synthetic staff MFA login did not issue a persistent session.",
        );
      }
      expect(login.sessionToken).toMatch(/^staff-admin\./);
      targetSessionToken = login.sessionToken;
      await expect(
        runWithDatabaseRequestIdentity(
          () => stagingAdmin.loginWithToken(targetCredential, nextStepCode),
          {},
        ),
      ).rejects.toThrow(/already used|invalid/i);
    } finally {
      Date.now = realNow;
    }

    const singleUseBackupCode = targetVerified.backupCodes[0]!;
    const backupLogin = await runWithDatabaseRequestIdentity(
      () => stagingAdmin.loginWithToken(targetCredential, singleUseBackupCode),
      {},
    );
    expect(backupLogin).toMatchObject({ authenticated: true });
    await expect(
      runWithDatabaseRequestIdentity(
        () =>
          stagingAdmin.loginWithToken(targetCredential, singleUseBackupCode),
        {},
      ),
    ).rejects.toThrow(/invalid|used/i);

    await expect(
      withIdentity(targetId, "COMPLAINT_REVIEWER", () =>
        sessions.validateSession(targetSessionToken),
      ),
    ).resolves.toMatchObject({ staff: { id: targetId } });

    const passwordEnrollment = await withIdentity(
      passwordStaffId,
      "COMPLAINT_REVIEWER",
      () => mfa.beginEnrollment(passwordStaffId),
    );
    const passwordEnrollmentCode = totpAtStep(
      passwordEnrollment.secret,
      currentStep,
    );
    await withIdentity(passwordStaffId, "COMPLAINT_REVIEWER", () =>
      mfa.verifyEnrollment(passwordStaffId, passwordEnrollmentCode),
    );
    const passwordLoginNow = Date.now;
    Date.now = () => passwordLoginNow() + 30_000;
    try {
      const credentialLogin = await runWithDatabaseRequestIdentity(
        () =>
          adminReview.loginWithCredentials({
            identifier: passwordStaffEmail,
            password: passwordStaffPassword,
            mfaCode: totpAtStep(passwordEnrollment.secret, currentStep + 1),
          }),
        {},
      );
      expect(credentialLogin).toMatchObject({
        authenticated: true,
        mode: "credential_session",
      });
      expect(credentialLogin.sessionToken).toMatch(/^staff-admin\./);
    } finally {
      Date.now = passwordLoginNow;
    }

    const approverEnrollment = await runWithDatabaseRequestIdentity(
      () => stagingAdmin.startStaffMfaEnrollment(approverCredential),
      {},
    );
    const approverCode = totpAtStep(approverEnrollment.secret, currentStep);
    await runWithDatabaseRequestIdentity(
      () =>
        stagingAdmin.verifyStaffMfaEnrollment(approverCredential, approverCode),
      {},
    );

    const recovery = await runWithDatabaseRequestIdentity(
      () => stagingAdmin.requestStaffMfaRecovery(targetCredential),
      {},
    );
    const approved = await withIdentity(approverId, "SUPER_ADMIN", () =>
      mfa.approveRecoveryRequest(recovery.requestId, approverId),
    );
    await runWithDatabaseRequestIdentity(
      () =>
        stagingAdmin.completeStaffMfaRecovery(
          targetCredential,
          approved.recoveryToken,
        ),
      {},
    );

    await expect(
      withIdentity(targetId, "COMPLAINT_REVIEWER", () =>
        sessions.validateSession(targetSessionToken),
      ),
    ).rejects.toThrow(/revoked|MFA/i);

    const finalMfa = await prisma!.adminStaffMfa.findUniqueOrThrow({
      where: { staffId: targetId },
    });
    expect(finalMfa.disabledAt).toBeInstanceOf(Date);
    expect(finalMfa.enrollmentVerifiedAt).toBeNull();
  }, 30_000);
});
