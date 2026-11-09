import "reflect-metadata";
import { randomInt, randomUUID } from "node:crypto";
import { PrismaPg } from "@prisma/adapter-pg";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import type { AuthenticationService } from "../src/auth/auth.service.js";
import { assertSakhiDatabaseTarget } from "../src/config/database-target.js";
import { Module2Service } from "../src/module2/module2.service.js";
import type { PrismaService } from "../src/database/prisma.service.js";
import { PrismaClient } from "../src/generated/prisma/client.js";

describe.skipIf(process.env.SAKHI_DB_INTEGRATION !== "true")(
  "Module 2 direct messages against the local Sakhi database",
  () => {
    let appDb: PrismaClient | undefined;
    let cleanupDb: PrismaClient | undefined;
    let service: Module2Service | undefined;
    let authenticatedAccountId: string | undefined;
    const fixtureAccountIds: string[] = [];
    const fixtureDirectoryIds: string[] = [];
    const fixtureMessageIds: string[] = [];

    beforeAll(async () => {
      if (process.env.SAKHI_ENV !== "dev") {
        throw new Error("DM database integration requires SAKHI_ENV=dev.");
      }
      if (process.env.NODE_ENV === "production") {
        throw new Error(
          "DM database integration cannot run in production mode.",
        );
      }
      if ((process.env.HOST ?? "127.0.0.1") !== "127.0.0.1") {
        throw new Error("DM database integration only supports loopback.");
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
      if (
        new URL(appUrl).hostname !== "127.0.0.1" ||
        new URL(appUrl).pathname !== "/sakhi_dev" ||
        new URL(migratorUrl).hostname !== "127.0.0.1" ||
        new URL(migratorUrl).pathname !== "/sakhi_dev"
      ) {
        throw new Error("Refusing any database other than local sakhi_dev.");
      }

      appDb = new PrismaClient({
        adapter: new PrismaPg({
          connectionString: appUrl,
          options: "-c timezone=UTC",
          max: 3,
          connectionTimeoutMillis: 5000,
          idleTimeoutMillis: 10000,
        }),
      });
      cleanupDb = new PrismaClient({
        adapter: new PrismaPg({
          connectionString: migratorUrl,
          options: "-c timezone=UTC",
          max: 2,
          connectionTimeoutMillis: 5000,
          idleTimeoutMillis: 10000,
        }),
      });

      const roleCheck = await appDb.$queryRaw<
        Array<{
          database_name: string;
          database_user: string;
          can_select: boolean;
          can_insert: boolean;
          can_update: boolean;
          can_delete: boolean;
        }>
      >`
        SELECT
          current_database() AS database_name,
          current_user AS database_user,
          has_table_privilege(current_user, 'public.direct_messages', 'SELECT') AS can_select,
          has_table_privilege(current_user, 'public.direct_messages', 'INSERT') AS can_insert,
          has_table_privilege(current_user, 'public.direct_messages', 'UPDATE') AS can_update,
          has_table_privilege(current_user, 'public.direct_messages', 'DELETE') AS can_delete
      `;
      const privileges = roleCheck[0];
      if (
        privileges?.database_name !== "sakhi_dev" ||
        privileges.database_user !== "sakhi_dev_app" ||
        !privileges.can_select ||
        !privileges.can_insert ||
        privileges.can_update ||
        privileges.can_delete
      ) {
        throw new Error(
          "The runtime DB role must have SELECT/INSERT only on direct_messages before integration testing.",
        );
      }

      const authStub = {
        authenticateAuthorization: async () => {
          if (!authenticatedAccountId) {
            throw new Error(
              "Integration test did not select a synthetic member.",
            );
          }
          return {
            accountId: authenticatedAccountId,
            account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
          };
        },
      };
      service = new Module2Service(
        authStub as unknown as AuthenticationService,
        appDb as unknown as PrismaService,
      );
    }, 30000);

    afterAll(async () => {
      try {
        if (cleanupDb && fixtureAccountIds.length > 0) {
          await cleanupDb.auditEvent.deleteMany({
            where: {
              actorId: { in: fixtureAccountIds },
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
        await appDb?.$disconnect();
        appDb = undefined;
        await cleanupDb?.$disconnect();
        cleanupDb = undefined;
      }
    }, 30000);

    async function createSyntheticMember(label: string) {
      if (!cleanupDb) throw new Error("Cleanup database client is not ready.");
      const suffix = randomUUID().replaceAll("-", "").slice(0, 12);
      const username = `@dm-it-${suffix}`;
      const displayName = `DM Integration ${label}`;
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

      return {
        accountId: account.id,
        directoryProfileId: directoryProfile.id,
        username,
      };
    }

    it("persists a synthetic message, returns it to both participants, and hides it from a third account", async () => {
      if (!appDb || !service)
        throw new Error("DM integration harness is not ready.");

      const sender = await createSyntheticMember("Sender");
      const recipient = await createSyntheticMember("Recipient");
      const observer = await createSyntheticMember("Observer");
      const body = `synthetic DM integration ${randomUUID()}`;

      authenticatedAccountId = sender.accountId;
      const sent = await service.sendDirectMessage(
        "Bearer synthetic-test-token",
        {
          recipientId: recipient.directoryProfileId,
          recipientHandle: recipient.username,
          recipientName: "Client supplied display name must not win",
          message: `  ${body}  `,
        },
      );

      expect(sent.sent).toBe(true);
      expect(sent.message.body).toBe(body);
      expect(sent.message.senderAccountId).toBe(sender.accountId);
      expect(sent.message.recipientAccountId).toBe(recipient.accountId);
      expect(sent.message.recipientName).toBe("DM Integration Recipient");
      fixtureMessageIds.push(sent.message.id);

      const stored = await appDb.directMessage.findUnique({
        where: { id: sent.message.id },
      });
      expect(stored).toMatchObject({
        id: sent.message.id,
        senderAccountId: sender.accountId,
        recipientAccountId: recipient.accountId,
        body,
      });

      const audit = await appDb.auditEvent.findFirst({
        where: {
          action: "module3.direct_message.persisted",
          targetId: sent.message.id,
        },
        select: { redactedMetadata: true },
      });
      expect(audit?.redactedMetadata).toEqual({
        messageId: sent.message.id,
        recipientAccountId: recipient.accountId,
      });
      expect(audit?.redactedMetadata).not.toHaveProperty("body");

      authenticatedAccountId = sender.accountId;
      const senderConversation = await service.listDirectMessages(
        "Bearer synthetic-test-token",
        recipient.accountId,
      );
      expect(senderConversation.items).toHaveLength(1);
      expect(senderConversation.items[0]).toMatchObject({
        id: sent.message.id,
        body,
        isOwnMessage: true,
      });

      authenticatedAccountId = recipient.accountId;
      const recipientConversation = await service.listDirectMessages(
        "Bearer synthetic-test-token",
        sender.accountId,
      );
      expect(recipientConversation.items).toHaveLength(1);
      expect(recipientConversation.items[0]).toMatchObject({
        id: sent.message.id,
        body,
        isOwnMessage: false,
      });

      authenticatedAccountId = observer.accountId;
      const observerConversation = await service.listDirectMessages(
        "Bearer synthetic-test-token",
        sender.accountId,
      );
      expect(observerConversation.items).toEqual([]);
      const observerInbox = await service.listDirectMessages(
        "Bearer synthetic-test-token",
      );
      expect(observerInbox.items).toEqual([]);
    }, 30000);
  },
);
