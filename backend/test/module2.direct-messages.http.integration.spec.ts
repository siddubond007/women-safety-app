import "reflect-metadata";
import type { INestApplication } from "@nestjs/common";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { Test } from "@nestjs/testing";
import { PrismaPg } from "@prisma/adapter-pg";
import { createHash, randomBytes, randomInt, randomUUID } from "node:crypto";
import request from "supertest";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { AuthController } from "../src/auth/auth.controller.js";
import { AuthenticationService } from "../src/auth/auth.service.js";
import { AuthModule } from "../src/auth/auth.module.js";
import {
  CreateProfileDto,
  RequestOtpDto,
  ResendOtpDto,
  VerifyOtpDto,
} from "../src/auth/auth.dto.js";
import { createGlobalValidationPipe } from "../src/common/validation/create-validation-pipe.js";
import { assertSakhiDatabaseTarget } from "../src/config/database-target.js";
import { PrismaService } from "../src/database/prisma.service.js";
import { PrismaClient } from "../src/generated/prisma/client.js";
import { GoogleDriveIntegrationController } from "../src/module2/google-drive-integration.controller.js";
import { GoogleDriveStorageService } from "../src/module2/google-drive-storage.service.js";
import { Module2Controller } from "../src/module2/module2.controller.js";
import { Module2Service } from "../src/module2/module2.service.js";
import { SendDirectMessageDto } from "../src/module2/module2.dto.js";
import { Module2Module } from "../src/module2/module2.module.js";

describe.skipIf(process.env.SAKHI_DB_INTEGRATION !== "true")(
  "Module 2 direct-message HTTP flow with real authentication and local PostgreSQL",
  () => {
    let app: INestApplication | undefined;
    let cleanupDb: PrismaClient | undefined;
    const fixtureAccountIds: string[] = [];
    const fixtureDirectoryIds: string[] = [];
    const fixtureMessageIds: string[] = [];

    beforeAll(async () => {
      if (process.env.SAKHI_ENV !== "dev") {
        throw new Error("DM HTTP integration requires SAKHI_ENV=dev.");
      }
      if (process.env.NODE_ENV !== "development") {
        throw new Error("DM HTTP integration requires NODE_ENV=development.");
      }
      if ((process.env.HOST ?? "127.0.0.1") !== "127.0.0.1") {
        throw new Error("DM HTTP integration only supports loopback.");
      }

      const appUrl = process.env.SAKHI_APP_DATABASE_URL;
      const migratorUrl = process.env.SAKHI_MIGRATOR_DATABASE_URL;
      if (!appUrl || !migratorUrl) {
        throw new Error(
          "Load both protected local Sakhi dev database credentials first.",
        );
      }
      assertSakhiDatabaseTarget(appUrl, "app", "dev");
      assertSakhiDatabaseTarget(migratorUrl, "migrator", "dev");
      for (const candidate of [appUrl, migratorUrl]) {
        const parsed = new URL(candidate);
        if (
          parsed.hostname !== "127.0.0.1" ||
          parsed.pathname !== "/sakhi_dev"
        ) {
          throw new Error("Refusing any database other than local sakhi_dev.");
        }
      }

      cleanupDb = new PrismaClient({
        adapter: new PrismaPg({
          connectionString: migratorUrl,
          options: "-c timezone=UTC",
          max: 2,
          connectionTimeoutMillis: 5000,
          idleTimeoutMillis: 10000,
        }),
      });

      // tsx/vitest does not emit Nest design:paramtypes metadata.
      Reflect.defineMetadata(
        "design:paramtypes",
        [ConfigService],
        PrismaService,
      );
      Reflect.defineMetadata(
        "design:paramtypes",
        [PrismaService],
        AuthenticationService,
      );
      Reflect.defineMetadata(
        "design:paramtypes",
        [AuthenticationService],
        AuthController,
      );
      Reflect.defineMetadata(
        "design:paramtypes",
        [Module2Service],
        Module2Controller,
      );
      Reflect.defineMetadata(
        "design:paramtypes",
        [GoogleDriveStorageService],
        GoogleDriveIntegrationController,
      );
      Reflect.defineMetadata(
        "design:paramtypes",
        [AuthenticationService, PrismaService, GoogleDriveStorageService],
        Module2Service,
      );

      Reflect.defineMetadata(
        "design:paramtypes",
        [RequestOtpDto],
        AuthController.prototype,
        "requestOtp",
      );
      Reflect.defineMetadata(
        "design:paramtypes",
        [ResendOtpDto],
        AuthController.prototype,
        "resendOtp",
      );
      Reflect.defineMetadata(
        "design:paramtypes",
        [VerifyOtpDto],
        AuthController.prototype,
        "verifyOtp",
      );
      Reflect.defineMetadata(
        "design:paramtypes",
        [String, CreateProfileDto],
        AuthController.prototype,
        "createProfile",
      );
      Reflect.defineMetadata(
        "design:paramtypes",
        [String],
        AuthController.prototype,
        "me",
      );
      Reflect.defineMetadata(
        "design:paramtypes",
        [String],
        AuthController.prototype,
        "logout",
      );
      Reflect.defineMetadata(
        "design:paramtypes",
        [String, String],
        Module2Controller.prototype,
        "listDirectMessages",
      );
      Reflect.defineMetadata(
        "design:paramtypes",
        [String, SendDirectMessageDto],
        Module2Controller.prototype,
        "sendDirectMessage",
      );

      const testingModule = await Test.createTestingModule({
        imports: [
          ConfigModule.forRoot({ isGlobal: true, ignoreEnvFile: true }),
          AuthModule,
          Module2Module,
        ],
      }).compile();

      app = testingModule.createNestApplication();
      app.setGlobalPrefix("api/v1");
      app.useGlobalPipes(createGlobalValidationPipe());
      await app.init();

      const roleCheck = await app.get(PrismaService).$queryRaw<
        Array<{
          database_name: string;
          database_user: string;
          can_read_sessions: boolean;
          can_read_messages: boolean;
          can_insert_messages: boolean;
        }>
      >`
        SELECT
          current_database() AS database_name,
          current_user AS database_user,
          has_table_privilege(current_user, 'public.auth_sessions', 'SELECT') AS can_read_sessions,
          has_table_privilege(current_user, 'public.direct_messages', 'SELECT') AS can_read_messages,
          has_table_privilege(current_user, 'public.direct_messages', 'INSERT') AS can_insert_messages
      `;
      expect(roleCheck[0]).toMatchObject({
        database_name: "sakhi_dev",
        database_user: "sakhi_dev_app",
        can_read_sessions: true,
        can_read_messages: true,
        can_insert_messages: true,
      });
    }, 30000);

    afterAll(async () => {
      try {
        if (cleanupDb && fixtureAccountIds.length > 0) {
          await cleanupDb.authSession.deleteMany({
            where: { accountId: { in: fixtureAccountIds } },
          });
          await cleanupDb.auditEvent.deleteMany({
            where: {
              OR: [
                { actorId: { in: fixtureAccountIds } },
                { targetId: { in: fixtureMessageIds } },
              ],
              action: "module3.direct_message.persisted",
            },
          });
          await cleanupDb.directMessage.deleteMany({
            where: {
              OR: [
                { id: { in: fixtureMessageIds } },
                { senderAccountId: { in: fixtureAccountIds } },
                { recipientAccountId: { in: fixtureAccountIds } },
              ],
            },
          });
          await cleanupDb.memberFollow.deleteMany({
            where: { accountId: { in: fixtureAccountIds } },
          });
          await cleanupDb.memberModerationBlock.deleteMany({
            where: { accountId: { in: fixtureAccountIds } },
          });
          await cleanupDb.memberPrivacyPreference.deleteMany({
            where: { accountId: { in: fixtureAccountIds } },
          });
          await cleanupDb.memberProfile.deleteMany({
            where: { accountId: { in: fixtureAccountIds } },
          });
          await cleanupDb.communityDirectoryProfile.deleteMany({
            where: { id: { in: fixtureDirectoryIds } },
          });
          await cleanupDb.memberAccount.deleteMany({
            where: { id: { in: fixtureAccountIds } },
          });
        }
      } finally {
        await app?.close();
        app = undefined;
        await cleanupDb?.$disconnect();
        cleanupDb = undefined;
      }
    }, 30000);

    async function createSyntheticMember(label: string) {
      if (!cleanupDb) throw new Error("Cleanup database client is not ready.");
      const suffix = randomUUID().replaceAll("-", "").slice(0, 12);
      const username = `@dm-http-${suffix}`;
      const displayName = `DM HTTP Integration ${label}`;
      const account = await cleanupDb.memberAccount.create({
        data: {
          phoneE164: `+1555${randomInt(10_000_000, 99_999_999)}`,
          phoneVerifiedAt: new Date(),
          status: "ACTIVE",
          verificationStatus: "VERIFIED",
          profile: {
            create: {
              displayName,
              username,
              dateOfBirth: new Date("1990-01-01T00:00:00.000Z"),
            },
          },
        },
        select: { id: true },
      });
      fixtureAccountIds.push(account.id);

      const directoryProfile = await cleanupDb.communityDirectoryProfile.create(
        {
          data: {
            name: displayName,
            username,
            avatarAsset: "assets/images/profile/avatar_siddhu.webp",
          },
          select: { id: true },
        },
      );
      fixtureDirectoryIds.push(directoryProfile.id);

      const token = randomBytes(32).toString("base64url");
      await cleanupDb.authSession.create({
        data: {
          accountId: account.id,
          tokenDigest: createHash("sha256").update(token).digest("hex"),
          expiresAt: new Date(Date.now() + 60 * 60 * 1000),
        },
      });

      return {
        accountId: account.id,
        directoryProfileId: directoryProfile.id,
        username,
        authorization: `Bearer ${token}`,
      };
    }

    it("sends and retrieves a DM over HTTP, enforces sessions, and isolates the conversation", async () => {
      if (!app) throw new Error("DM HTTP integration app is not initialized.");

      const sender = await createSyntheticMember("Sender");
      const recipient = await createSyntheticMember("Recipient");
      const observer = await createSyntheticMember("Observer");
      const body = `synthetic HTTP DM integration ${randomUUID()}`;

      await request(app.getHttpServer())
        .get("/api/v1/module2/messages")
        .expect(401);

      await request(app.getHttpServer())
        .get("/api/v1/module2/messages")
        .set("Authorization", "Bearer invalid-synthetic-session-token")
        .expect(401);

      const sendResponse = await request(app.getHttpServer())
        .post("/api/v1/module2/messages")
        .set("Authorization", sender.authorization)
        .send({
          recipientId: recipient.directoryProfileId,
          recipientHandle: recipient.username,
          recipientName: "Client supplied name must not win",
          message: `  ${body}  `,
        })
        .expect(201);

      expect(sendResponse.body).toMatchObject({
        sent: true,
        message: {
          senderAccountId: sender.accountId,
          recipientAccountId: recipient.accountId,
          recipientName: "DM HTTP Integration Recipient",
          body,
          isOwnMessage: true,
        },
      });
      const messageId = sendResponse.body.message.id as string;
      fixtureMessageIds.push(messageId);

      const stored = await app.get(PrismaService).directMessage.findUnique({
        where: { id: messageId },
      });
      expect(stored).toMatchObject({
        id: messageId,
        senderAccountId: sender.accountId,
        recipientAccountId: recipient.accountId,
        body,
      });

      const audit = await app.get(PrismaService).auditEvent.findFirst({
        where: {
          action: "module3.direct_message.persisted",
          targetId: messageId,
        },
        select: { redactedMetadata: true },
      });
      expect(audit?.redactedMetadata).toEqual({
        messageId,
        recipientAccountId: recipient.accountId,
      });
      expect(audit?.redactedMetadata).not.toHaveProperty("body");

      const senderConversation = await request(app.getHttpServer())
        .get("/api/v1/module2/messages")
        .query({ peerId: recipient.accountId })
        .set("Authorization", sender.authorization)
        .expect(200);
      expect(senderConversation.body.items).toHaveLength(1);
      expect(senderConversation.body.items[0]).toMatchObject({
        id: messageId,
        body,
        isOwnMessage: true,
      });

      const recipientConversation = await request(app.getHttpServer())
        .get("/api/v1/module2/messages")
        .query({ peerId: sender.accountId })
        .set("Authorization", recipient.authorization)
        .expect(200);
      expect(recipientConversation.body.items).toHaveLength(1);
      expect(recipientConversation.body.items[0]).toMatchObject({
        id: messageId,
        body,
        isOwnMessage: false,
      });

      const observerConversation = await request(app.getHttpServer())
        .get("/api/v1/module2/messages")
        .query({ peerId: sender.accountId })
        .set("Authorization", observer.authorization)
        .expect(200);
      expect(observerConversation.body.items).toEqual([]);

      const observerInbox = await request(app.getHttpServer())
        .get("/api/v1/module2/messages")
        .set("Authorization", observer.authorization)
        .expect(200);
      expect(observerInbox.body.items).toEqual([]);
    }, 30000);
  },
);
