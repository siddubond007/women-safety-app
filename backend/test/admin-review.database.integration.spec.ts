import "reflect-metadata";
import { createHash, randomBytes, randomInt } from "node:crypto";
import type { INestApplication } from "@nestjs/common";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { Test } from "@nestjs/testing";
import request from "supertest";
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
import { ManualEligibilityDecisionDto } from "../src/admin-review/admin-review.dto.js";
import { EligibilityController } from "../src/eligibility/eligibility.controller.js";
import { EligibilityModule } from "../src/eligibility/eligibility.module.js";
import { EligibilityService } from "../src/eligibility/eligibility.service.js";
import { StartManualReviewDto } from "../src/eligibility/eligibility.dto.js";
import { createGlobalValidationPipe } from "../src/common/validation/create-validation-pipe.js";
import { validateRuntimeEnvironment, assertSakhiDatabaseTarget } from "../src/config/database-target.js";
import { PrismaService } from "../src/database/prisma.service.js";
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "../src/generated/prisma/client.js";

describe.skipIf(process.env.SAKHI_DB_INTEGRATION !== "true")(
  "database-backed manual eligibility review workflow",
  () => {
    let app: INestApplication | undefined;
    let db: PrismaService | undefined;
    let cleanupClient: PrismaClient | undefined;
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
      if (process.env.SAKHI_ADMIN_REVIEW_TOKEN?.trim().length !== 64) {
        throw new Error("The test runner did not provide its ephemeral reviewer token.");
      }
      if (
        process.env.SAKHI_MANUAL_REVIEW_POLICY_APPROVED !== "true" ||
        process.env.SAKHI_MANUAL_REVIEW_EVIDENCE_PROCEDURE_APPROVED !== "true"
      ) {
        throw new Error("Synthetic review policy flags must be scoped to this test process.");
      }

      const appUrl = process.env.SAKHI_APP_DATABASE_URL;
      const migratorUrl = process.env.SAKHI_MIGRATOR_DATABASE_URL;
      assertSakhiDatabaseTarget(appUrl, "app", "test");
      assertSakhiDatabaseTarget(migratorUrl, "migrator", "test");

      // tsx/Vitest uses esbuild and does not emit Nest design:paramtypes metadata.
      Reflect.defineMetadata("design:paramtypes", [ConfigService], PrismaService);
      Reflect.defineMetadata("design:paramtypes", [PrismaService], AuthenticationService);
      Reflect.defineMetadata("design:paramtypes", [AuthenticationService], AuthController);
      Reflect.defineMetadata("design:paramtypes", [RequestOtpDto], AuthController.prototype, "requestOtp");
      Reflect.defineMetadata("design:paramtypes", [ResendOtpDto], AuthController.prototype, "resendOtp");
      Reflect.defineMetadata("design:paramtypes", [VerifyOtpDto], AuthController.prototype, "verifyOtp");
      Reflect.defineMetadata("design:paramtypes", [String, CreateProfileDto], AuthController.prototype, "createProfile");
      Reflect.defineMetadata("design:paramtypes", [String], AuthController.prototype, "me");
      Reflect.defineMetadata("design:paramtypes", [String], AuthController.prototype, "logout");
      Reflect.defineMetadata("design:paramtypes", [AuthenticationService, PrismaService], EligibilityService);
      Reflect.defineMetadata("design:paramtypes", [EligibilityService], EligibilityController);
      Reflect.defineMetadata("design:paramtypes", [String, StartManualReviewDto], EligibilityController.prototype, "start");
      Reflect.defineMetadata("design:paramtypes", [PrismaService], AdminReviewService);
      Reflect.defineMetadata("design:paramtypes", [AdminReviewService], AdminReviewController);
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
      app.useGlobalPipes(createGlobalValidationPipe());
      await app.init();
      db = app.get(PrismaService);

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
    }, 30000);

    afterAll(async () => {
      try {
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
        db = undefined;
        await cleanupClient?.$disconnect();
        cleanupClient = undefined;
      }
    }, 30000);

    async function createSyntheticMember(displayName: string) {
      if (!db) throw new Error("Integration-test database client is not ready.");
      const [terms, privacy] = await Promise.all([
        db.policyDocumentVersion.findFirst({
          where: { documentType: "TERMS", status: "DRAFT" },
          orderBy: { createdAt: "desc" },
          select: { id: true },
        }),
        db.policyDocumentVersion.findFirst({
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
        const existing = await db.memberAccount.findUnique({
          where: { phoneE164: candidate },
          select: { id: true },
        });
        if (!existing) {
          phoneE164 = candidate;
          break;
        }
      }
      if (!phoneE164) throw new Error("Could not allocate a unique synthetic phone number.");

      const account = await db.memberAccount.create({
        data: {
          phoneE164,
          phoneVerifiedAt: new Date(),
          status: "PENDING_VERIFICATION",
          verificationStatus: "UNVERIFIED",
        },
        select: { id: true },
      });
      fixtureAccountIds.push(account.id);

      await db.memberProfile.create({
        data: {
          accountId: account.id,
          displayName,
          dateOfBirth: new Date("1999-04-12T00:00:00.000Z"),
          email: "review-integration@example.invalid",
        },
      });
      await db.memberConsent.create({
        data: {
          accountId: account.id,
          termsVersionId: terms.id,
          privacyVersionId: privacy.id,
          acceptedAt: new Date(),
          source: "admin_review_integration_test",
        },
      });

      const accessToken = randomBytes(32).toString("base64url");
      await db.authSession.create({
        data: {
          accountId: account.id,
          tokenDigest: createHash("sha256").update(accessToken).digest("hex"),
          expiresAt: new Date(Date.now() + 60 * 60 * 1000),
        },
      });
      return { accountId: account.id, authorization: "Bearer " + accessToken };
    }

    it("persists submission, approval/rejection, member status and audit history", async () => {
      if (!app) throw new Error("Integration-test API did not initialize.");
      const reviewerToken = process.env.SAKHI_ADMIN_REVIEW_TOKEN!;

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

      const queueResponse = await request(app.getHttpServer())
        .get("/api/v1/admin-review/queue")
        .set("X-Sakhi-Admin-Token", reviewerToken)
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
        .set("X-Sakhi-Admin-Token", reviewerToken)
        .send({
          decision: "approve",
          reason: "Synthetic integration test approval.",
          reviewedEvidence: true,
        })
        .expect(201);
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
        .set("X-Sakhi-Admin-Token", reviewerToken)
        .send({
          decision: "reject",
          reason: "Synthetic integration test rejection.",
          reviewedEvidence: true,
        })
        .expect(201);
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
        .set("X-Sakhi-Admin-Token", reviewerToken)
        .expect(200);
      expect(history.body.map((item: { outcome: string }) => item.outcome)).toEqual(
        expect.arrayContaining(["approve", "reject"]),
      );
    }, 30000);
  },
);
