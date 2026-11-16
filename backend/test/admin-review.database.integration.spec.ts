import "reflect-metadata";
import { createHash, createHmac, randomBytes, randomInt, randomUUID, scryptSync } from "node:crypto";
import type { INestApplication } from "@nestjs/common";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { Test } from "@nestjs/testing";
import request from "supertest";
import type { NextFunction, Request, Response } from "express";
import { AuthController } from "../src/auth/auth.controller.js";
import { AuthModule } from "../src/auth/auth.module.js";
import { AuthenticationService } from "../src/auth/auth.service.js";
import {
  CreateProfileDto,
  RequestOtpDto,
  ResendOtpDto,
  VerifyOtpDto,
} from "../src/auth/auth.dto.js";
import { AdminReviewController } from "../src/admin-review/admin-review.controller.js";
import { AdminReviewModule } from "../src/admin-review/admin-review.module.js";
import { AdminReviewService } from "../src/admin-review/admin-review.service.js";
import { GoogleDriveStorageService } from "../src/module2/google-drive-storage.service.js";
import { AdminStaffSessionGuard } from "../src/admin-security/admin-staff-session.guard.js";
import { ManualEligibilityDecisionDto } from "../src/admin-review/admin-review.dto.js";
import { DevelopmentMemberStateDto } from "../src/admin-review/admin-member-state.dto.js";
import { EligibilityController } from "../src/eligibility/eligibility.controller.js";
import { EligibilityModule } from "../src/eligibility/eligibility.module.js";
import { EligibilityService } from "../src/eligibility/eligibility.service.js";
import { StartManualReviewDto } from "../src/eligibility/eligibility.dto.js";
import { createGlobalValidationPipe } from "../src/common/validation/create-validation-pipe.js";
import { validateRuntimeEnvironment, assertSakhiDatabaseTarget } from "../src/config/database-target.js";
import { PrismaService } from "../src/database/prisma.service.js";
import { AdminMfaService } from "../src/admin-security/admin-mfa.service.js";
import { AdminSessionService } from "../src/admin-security/admin-session.service.js";
import { runWithDatabaseRequestIdentity } from "../src/database/database-request-identity.context.js";
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "../src/generated/prisma/client.js";


function decodeBase32(value: string): Buffer {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  let bits = 0;
  let accumulator = 0;
  const bytes: number[] = [];
  for (const character of value.replace(/=+$/g, "").toUpperCase()) {
    const digit = alphabet.indexOf(character);
    if (digit < 0) throw new Error("Invalid test TOTP secret.");
    accumulator = (accumulator << 5) | digit;
    bits += 5;
    if (bits >= 8) {
      bytes.push((accumulator >>> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return Buffer.from(bytes);
}

function currentTotp(secret: string): string {
  const counter = Math.floor(Date.now() / 30_000);
  const message = Buffer.alloc(8);
  message.writeBigUInt64BE(BigInt(counter));
  const digest = createHmac("sha1", decodeBase32(secret)).update(message).digest();
  const offset = digest[digest.length - 1]! & 0x0f;
  const binary =
    ((digest[offset]! & 0x7f) << 24) |
    ((digest[offset + 1]! & 0xff) << 16) |
    ((digest[offset + 2]! & 0xff) << 8) |
    (digest[offset + 3]! & 0xff);
  return String(binary % 1_000_000).padStart(6, "0");
}

describe.skipIf(process.env.SAKHI_DB_INTEGRATION !== "true")(
  "database-backed manual eligibility review workflow",
  () => {
    let app: INestApplication | undefined;
    let cleanupClient: PrismaClient | undefined;
    let reviewerSessionToken = "";
    let integrationStaffId = "";
    const fixtureAccountIds: string[] = [];

    beforeAll(async () => {
      if (process.env.SAKHI_ENV !== "test") {
        throw new Error("Admin-review integration tests require SAKHI_ENV=test.");
      }
      if (process.env.NODE_ENV === "production") {
        throw new Error("Admin-review integration tests cannot run in production mode.");
      }
      if ((process.env.HOST ?? "127.0.0.1") !== "127.0.0.1") {
        throw new Error("Admin-review integration tests require loopback.");
      }
      process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY ??= Buffer.alloc(32, 0x73).toString("base64");
      process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY ??= Buffer.alloc(32, 0x5a).toString("base64");
      if (process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY === process.env.SAKHI_ADMIN_MFA_ENCRYPTION_KEY) {
        throw new Error("Test MFA encryption and staff session keys must be distinct.");
      }
      if (
        process.env.SAKHI_MANUAL_REVIEW_POLICY_APPROVED !== "true" ||
        process.env.SAKHI_MANUAL_REVIEW_EVIDENCE_PROCEDURE_APPROVED !== "true"
      ) {
        throw new Error("Synthetic review policy flags must be scoped to this test process.");
      }

      const appUrl = process.env.SAKHI_APP_DATABASE_URL;
      const migratorUrl = process.env.SAKHI_MIGRATOR_DATABASE_URL;
      if (!appUrl || !migratorUrl) {
        throw new Error("The test runner did not load both local sakhi_test URLs.");
      }
      assertSakhiDatabaseTarget(appUrl, "app", "test");
      assertSakhiDatabaseTarget(migratorUrl, "migrator", "test");

      // tsx/Vitest uses esbuild and does not emit Nest design:paramtypes metadata.
      Reflect.defineMetadata("design:paramtypes", [ConfigService], PrismaService);
      Reflect.defineMetadata("design:paramtypes", [PrismaService], AuthenticationService);
      Reflect.defineMetadata("design:paramtypes", [AuthenticationService], AuthController);
      Reflect.defineMetadata("design:paramtypes", [RequestOtpDto], AuthController.prototype, "requestOtp");
      Reflect.defineMetadata("design:paramtypes", [ResendOtpDto], AuthController.prototype, "resendOtp");
      Reflect.defineMetadata("design:paramtypes", [VerifyOtpDto, String], AuthController.prototype, "verifyOtp");
      Reflect.defineMetadata("design:paramtypes", [String, CreateProfileDto], AuthController.prototype, "createProfile");
      Reflect.defineMetadata("design:paramtypes", [String], AuthController.prototype, "me");
      Reflect.defineMetadata("design:paramtypes", [String], AuthController.prototype, "logout");
      Reflect.defineMetadata("design:paramtypes", [AuthenticationService, PrismaService], EligibilityService);
      Reflect.defineMetadata("design:paramtypes", [EligibilityService], EligibilityController);
      Reflect.defineMetadata("design:paramtypes", [String, StartManualReviewDto], EligibilityController.prototype, "start");
      Reflect.defineMetadata("design:paramtypes", [PrismaService, GoogleDriveStorageService, AdminMfaService, AdminSessionService], AdminReviewService);
      Reflect.defineMetadata("design:paramtypes", [AdminSessionService], AdminStaffSessionGuard);
      Reflect.defineMetadata("design:paramtypes", [PrismaService], AdminMfaService);
      Reflect.defineMetadata("design:paramtypes", [PrismaService], AdminSessionService);
      Reflect.defineMetadata("design:paramtypes", [AdminReviewService], AdminReviewController);
      Reflect.defineMetadata("design:paramtypes", [String, String, String, String, String, String], AdminReviewController.prototype, "members");
      Reflect.defineMetadata("design:paramtypes", [String, String, DevelopmentMemberStateDto], AdminReviewController.prototype, "updateMemberState");
      Reflect.defineMetadata("design:paramtypes", [String, String, ManualEligibilityDecisionDto], AdminReviewController.prototype, "decide");

      const testingModule = await Test.createTestingModule({
        imports: [
          ConfigModule.forRoot({
            isGlobal: true,
            ignoreEnvFile: true,
            validate: validateRuntimeEnvironment,
          }),
          AuthModule,
          EligibilityModule,
          AdminReviewModule,
        ],
      }).compile();

      app = testingModule.createNestApplication();
      app.setGlobalPrefix("api/v1");
      app.use((_request: Request, _response: Response, next: NextFunction) => runWithDatabaseRequestIdentity(next));
      app.useGlobalPipes(createGlobalValidationPipe());
      await app.init();

      // The runtime API uses the least-privilege app role. The local test migrator
      // is used only to remove synthetic fixtures because the app role has no DELETE grant.
      cleanupClient = new PrismaClient({
        adapter: new PrismaPg({
          connectionString: migratorUrl!,
          options: "-c timezone=UTC",
          max: 2,
          connectionTimeoutMillis: 5000,
          idleTimeoutMillis: 10000,
        }),
      });

      // Create a disposable Super Admin through the migrator, then enroll MFA
      // and issue a genuine DB-backed staff session through the application
      // services. The integration API therefore exercises the real guard.
      integrationStaffId = randomUUID();
      const suffix = randomUUID().slice(0, 8);
      const staffAccessToken = randomBytes(32).toString("base64url");
      const staffPasswordSalt = randomBytes(16).toString("hex");
      const staffPasswordDerived = scryptSync(randomBytes(32), staffPasswordSalt, 64, { N: 16384, r: 8, p: 1 }).toString("hex");
      await cleanupClient.adminStaffAccount.create({
        data: {
          id: integrationStaffId,
          staffCode: "#SA-INT-" + suffix.toUpperCase(),
          username: "integration-admin-" + suffix,
          fullName: "Synthetic Integration Super Admin",
          email: "integration-admin-" + suffix + "@example.test",
          passwordHash: `scrypt$16384$8$1${staffPasswordSalt}${staffPasswordDerived}`,
          mustResetPassword: false,
          role: "SUPER_ADMIN",
          status: "ACTIVE",
          accessTokenDigest: createHash("sha256").update(staffAccessToken).digest("hex"),
          accessTokenPreview: "SAKHI-STAFF-••••",
          isAuthorisedComplaintReviewer: true,
          clearanceLevel: "LEVEL_4_MASTER_GOVERNANCE",
          permissions: {
            view: true, create: true, edit: true, approve: true,
            suspend: true, export: true, delete: true,
          },
          createdBy: "Disposable PostgreSQL 17 integration test",
        },
      });

      await runWithDatabaseRequestIdentity(
        async () => {
          const mfa = app!.get(AdminMfaService);
          const sessions = app!.get(AdminSessionService);
          const enrollment = await mfa.beginEnrollment(integrationStaffId);
          await mfa.verifyEnrollment(integrationStaffId, currentTotp(enrollment.secret));
          const issued = await sessions.issueSession(integrationStaffId);
          reviewerSessionToken = issued.value;
        },
        { adminStaffId: integrationStaffId, adminRole: "SUPER_ADMIN" },
      );
    }, 30000);

    afterAll(async () => {
      try {
        if (cleanupClient && integrationStaffId) {
          await cleanupClient.auditEvent.deleteMany({ where: { actorId: integrationStaffId } });
          await cleanupClient.adminStaffSession.deleteMany({ where: { staffId: integrationStaffId } });
          await cleanupClient.adminStaffBackupCode.deleteMany({ where: { staffId: integrationStaffId } });
          await cleanupClient.adminStaffMfa.deleteMany({ where: { staffId: integrationStaffId } });
          await cleanupClient.adminStaffAccount.deleteMany({ where: { id: integrationStaffId } });
        }
        if (cleanupClient && fixtureAccountIds.length > 0) {
          const submissions = await cleanupClient.eligibilitySubmission.findMany({
            where: { accountId: { in: fixtureAccountIds } },
            select: { id: true },
          });
          const submissionIds = submissions.map((item) => item.id);
          await cleanupClient.auditEvent.deleteMany({
            where: {
              OR: [
                { actorId: { in: fixtureAccountIds } },
                { targetId: { in: submissionIds } },
                { targetType: "member_account", targetId: { in: fixtureAccountIds } },
              ],
            },
          });
          await cleanupClient.eligibilitySubmission.deleteMany({
            where: { accountId: { in: fixtureAccountIds } },
          });
          await cleanupClient.memberConsent.deleteMany({
            where: { accountId: { in: fixtureAccountIds } },
          });
          await cleanupClient.authSession.deleteMany({
            where: { accountId: { in: fixtureAccountIds } },
          });
          await cleanupClient.memberProfile.deleteMany({
            where: { accountId: { in: fixtureAccountIds } },
          });
          await cleanupClient.memberAccount.deleteMany({
            where: { id: { in: fixtureAccountIds } },
          });
        }
      } finally {
        await app?.close();
        app = undefined;
        await cleanupClient?.$disconnect();
        cleanupClient = undefined;
      }
    }, 30000);

    async function createSyntheticMember(displayName: string) {
      if (!cleanupClient) throw new Error("Integration-test migrator client is not ready.");
      // Fixture setup intentionally uses the isolated test migrator (BYPASSRLS),
      // never the least-privilege app role. API reads and writes below still run
      // through the app role and must satisfy the real RLS policies.
      const [terms, privacy] = await Promise.all([
        cleanupClient.policyDocumentVersion.findFirst({
          where: { documentType: "TERMS", status: "DRAFT" },
          orderBy: { createdAt: "desc" },
          select: { id: true },
        }),
        cleanupClient.policyDocumentVersion.findFirst({
          where: { documentType: "PRIVACY", status: "DRAFT" },
          orderBy: { createdAt: "desc" },
          select: { id: true },
        }),
      ]);
      if (!terms || !privacy) {
        throw new Error("Draft policy fixtures are missing. The repository test runner must seed sakhi_test first.");
      }

      let phoneE164 = "";
      for (let attempt = 0; attempt < 12; attempt += 1) {
        const candidate = "+1202555" + String(randomInt(0, 10000)).padStart(4, "0");
        const existing = await cleanupClient.memberAccount.findUnique({
          where: { phoneE164: candidate },
          select: { id: true },
        });
        if (!existing) {
          phoneE164 = candidate;
          break;
        }
      }
      if (!phoneE164) throw new Error("Could not allocate a unique synthetic phone number.");

      const account = await cleanupClient.memberAccount.create({
        data: {
          phoneE164,
          phoneVerifiedAt: new Date(),
          status: "PENDING_VERIFICATION",
          verificationStatus: "UNVERIFIED",
        },
        select: { id: true },
      });
      fixtureAccountIds.push(account.id);

      await cleanupClient.memberProfile.create({
        data: {
          accountId: account.id,
          displayName,
          dateOfBirth: new Date("1999-04-12T00:00:00.000Z"),
          email: "review-integration@example.invalid",
        },
      });
      await cleanupClient.memberConsent.create({
        data: {
          accountId: account.id,
          termsVersionId: terms.id,
          privacyVersionId: privacy.id,
          acceptedAt: new Date(),
          source: "admin_review_integration_test",
        },
      });

      const accessToken = randomBytes(32).toString("base64url");
      const session = await cleanupClient.authSession.create({
        data: {
          accountId: account.id,
          tokenDigest: createHash("sha256").update(accessToken).digest("hex"),
          expiresAt: new Date(Date.now() + 60 * 60 * 1000),
        },
        select: { id: true },
      });
      return {
        accountId: account.id,
        sessionId: session.id,
        authorization: "Bearer " + accessToken,
      };
    }

    it("lists real database members and persists a development-only state override", async () => {
      if (!app) throw new Error("Integration-test API did not initialize.");
      const reviewerToken = reviewerSessionToken;
      const member = await createSyntheticMember("Synthetic Admin State QA");

      const directory = await request(app.getHttpServer())
        .get("/api/v1/admin-review/members?page=1&pageSize=10&search=Synthetic%20Admin%20State%20QA")
        .set("X-Sakhi-Staging-Admin-Session", reviewerToken)
        .expect(200);
      expect(directory.body.total).toBe(1);
      expect(directory.body.items).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            id: member.accountId,
            displayName: "Synthetic Admin State QA",
            accountStatus: "PENDING_VERIFICATION",
            verificationStatus: "UNVERIFIED",
            profileComplete: true,
          }),
        ]),
      );

      await request(app.getHttpServer())
        .post("/api/v1/admin-review/members/" + member.accountId + "/state")
        .set("X-Sakhi-Staging-Admin-Session", reviewerToken)
        .send({
          accountStatus: "ACTIVE",
          verificationStatus: "VERIFIED",
          reason: "Synthetic QA override to validate the development home-access workflow.",
        })
        .expect(201)
        .expect(({ body }) => {
          expect(body).toMatchObject({
            accountId: member.accountId,
            accountStatus: "ACTIVE",
            verificationStatus: "VERIFIED",
            mode: "local_dev_test_only",
          });
        });

      const account = await request(app.getHttpServer())
        .get("/api/v1/auth/me")
        .set("Authorization", member.authorization)
        .expect(200);
      expect(account.body).toMatchObject({
        accountId: member.accountId,
        status: "ACTIVE",
        verificationStatus: "VERIFIED",
      });

      const eligibility = await request(app.getHttpServer())
        .get("/api/v1/eligibility/status")
        .set("Authorization", member.authorization)
        .expect(200);
      expect(eligibility.body.eligibilityStatus).toBe("VERIFIED");
    }, 30000);

    it("isolates member account, profile and eligibility rows under the NOBYPASSRLS app role", async () => {
      if (!app) throw new Error("Integration-test API did not initialize.");
      const owner = await createSyntheticMember("Synthetic RLS Owner");
      const other = await createSyntheticMember("Synthetic RLS Other Member");

      // Create a real Member B eligibility row with the privileged disposable
      // test migrator. Without this fixture, an empty result would be a false
      // positive because there would be no Member B row for RLS to hide.
      if (!cleanupClient) throw new Error("Integration-test migrator client is not ready.");
      const otherSubmission = await cleanupClient.eligibilitySubmission.create({
        data: {
          accountId: other.accountId,
          consentVersion: "synthetic-rls-v1",
          consentAcceptedAt: new Date(),
        },
        select: { id: true, accountId: true },
      });
      const persistedOtherSubmission = await cleanupClient.eligibilitySubmission.findUnique({
        where: { id: otherSubmission.id },
        select: { id: true, accountId: true },
      });
      expect(persistedOtherSubmission).toEqual({
        id: otherSubmission.id,
        accountId: other.accountId,
      });

      // Query through the actual application PrismaService, not the privileged
      // fixture/migrator connection. The request identity is transaction-local.
      const prisma = app.get(PrismaService);
      const visible = await runWithDatabaseRequestIdentity(
        async () => {
          const ownAccount = await prisma.memberAccount.findUnique({
            where: { id: owner.accountId },
            select: { id: true },
          });
          const otherAccount = await prisma.memberAccount.findUnique({
            where: { id: other.accountId },
            select: { id: true },
          });
          const ownProfile = await prisma.memberProfile.findUnique({
            where: { accountId: owner.accountId },
            select: { accountId: true },
          });
          const otherProfile = await prisma.memberProfile.findUnique({
            where: { accountId: other.accountId },
            select: { accountId: true },
          });
          const otherSubmissions = await prisma.eligibilitySubmission.findMany({
            where: { accountId: other.accountId },
            select: { id: true },
          });
          return { ownAccount, otherAccount, ownProfile, otherProfile, otherSubmissions };
        },
        { accountId: owner.accountId, sessionId: owner.sessionId },
      );

      expect(visible.ownAccount?.id).toBe(owner.accountId);
      expect(visible.ownProfile?.accountId).toBe(owner.accountId);
      expect(visible.otherAccount).toBeNull();
      expect(visible.otherProfile).toBeNull();
      expect(visible.otherSubmissions).toEqual([]);
    }, 30000);

    it("persists submission, approval/rejection, member status and audit history", async () => {
      if (!app) throw new Error("Integration-test API did not initialize.");
      const reviewerToken = reviewerSessionToken;

      const approvedMember = await createSyntheticMember("Synthetic Approval QA");
      const initialStatus = await request(app.getHttpServer())
        .get("/api/v1/eligibility/status")
        .set("Authorization", approvedMember.authorization)
        .expect(200);
      expect(initialStatus.body).toMatchObject({
        eligibilityStatus: "UNVERIFIED",
        manualReviewStatus: null,
        canRequestManualReview: true,
      });

      const submissionResponse = await request(app.getHttpServer())
        .post("/api/v1/eligibility/start")
        .set("Authorization", approvedMember.authorization)
        .send({
          consentAccepted: true,
          consentVersion: process.env.SAKHI_MANUAL_REVIEW_CONSENT_VERSION,
        })
        .expect(200);
      expect(submissionResponse.body).toMatchObject({
        status: "pendingManualReview",
        eligibilityStatus: "PENDING_MANUAL_REVIEW",
        isDemo: true,
      });
      const approvedSubmissionId = submissionResponse.body.submissionId as string;
      expect(approvedSubmissionId).toMatch(
        /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
      );

      // The member-facing request runs as the NOBYPASSRLS app role. Verify
      // that its scoped audit insert persisted with an explicit UUID and the
      // authenticated member as actor; the migrator is used only to inspect
      // the disposable test database after the API transaction commits.
      const submissionAudit = await cleanupClient!.auditEvent.findFirst({
        where: {
          actorType: "MEMBER",
          actorId: approvedMember.accountId,
          action: "eligibility.manual_review.submitted",
          targetType: "eligibility_submission",
          targetId: approvedSubmissionId,
        },
        select: { id: true, actorId: true, requestId: true },
      });
      expect(submissionAudit).not.toBeNull();
      expect(submissionAudit?.id).toMatch(
        /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
      );
      expect(submissionAudit?.requestId).toMatch(
        /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
      );
      expect(submissionAudit?.actorId).toBe(approvedMember.accountId);

      const queueResponse = await request(app.getHttpServer())
        .get("/api/v1/admin-review/queue")
        .set("X-Sakhi-Staging-Admin-Session", reviewerToken)
        .expect(200);
      expect(queueResponse.body).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            submissionId: approvedSubmissionId,
            accountId: approvedMember.accountId,
            displayName: "Synthetic Approval QA",
            manualReviewConsent: expect.objectContaining({
              version: process.env.SAKHI_MANUAL_REVIEW_CONSENT_VERSION,
            }),
          }),
        ]),
      );

      const approval = await request(app.getHttpServer())
        .post("/api/v1/admin-review/submissions/" + approvedSubmissionId + "/decision")
        .set("X-Sakhi-Staging-Admin-Session", reviewerToken)
        .send({
          decision: "approve",
          reason: "Synthetic integration test approval.",
          reviewedEvidence: true,
        })
        .expect(200);
      expect(approval.body).toMatchObject({
        submissionId: approvedSubmissionId,
        accountId: approvedMember.accountId,
        status: "ACTIVE",
        verificationStatus: "VERIFIED",
        decision: "approve",
      });

      const approvedStatus = await request(app.getHttpServer())
        .get("/api/v1/eligibility/status")
        .set("Authorization", approvedMember.authorization)
        .expect(200);
      expect(approvedStatus.body.eligibilityStatus).toBe("VERIFIED");
      expect(approvedStatus.body.manualReviewStatus).toBe("APPROVED");

      const rejectedMember = await createSyntheticMember("Synthetic Rejection QA");
      const rejectedSubmission = await request(app.getHttpServer())
        .post("/api/v1/eligibility/start")
        .set("Authorization", rejectedMember.authorization)
        .send({
          consentAccepted: true,
          consentVersion: process.env.SAKHI_MANUAL_REVIEW_CONSENT_VERSION,
        })
        .expect(200);
      const rejectedSubmissionId = rejectedSubmission.body.submissionId as string;

      const rejection = await request(app.getHttpServer())
        .post("/api/v1/admin-review/submissions/" + rejectedSubmissionId + "/decision")
        .set("X-Sakhi-Staging-Admin-Session", reviewerToken)
        .send({
          decision: "reject",
          reason: "Synthetic integration test rejection.",
          reviewedEvidence: true,
        })
        .expect(200);
      expect(rejection.body).toMatchObject({
        submissionId: rejectedSubmissionId,
        accountId: rejectedMember.accountId,
        status: "PENDING_VERIFICATION",
        verificationStatus: "REJECTED",
        decision: "reject",
      });

      const rejectedStatus = await request(app.getHttpServer())
        .get("/api/v1/eligibility/status")
        .set("Authorization", rejectedMember.authorization)
        .expect(200);
      expect(rejectedStatus.body.eligibilityStatus).toBe("REJECTED");
      expect(rejectedStatus.body.manualReviewStatus).toBe("REJECTED");

      const history = await request(app.getHttpServer())
        .get("/api/v1/admin-review/history")
        .set("X-Sakhi-Staging-Admin-Session", reviewerToken)
        .expect(200);
      expect(history.body.map((item: { outcome: string }) => item.outcome)).toEqual(
        expect.arrayContaining(["approve", "reject"]),
      );
    }, 30000);
  },
);
