import "reflect-metadata";
import { createHash, randomUUID } from "node:crypto";
import { ConfigService } from "@nestjs/config";
import { Pool } from "pg";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import { Module2Service } from "../src/module2/module2.service.js";
import { PrismaService } from "../src/database/prisma.service.js";
import { runWithDatabaseRequestIdentity } from "../src/database/database-request-identity.context.js";
import { ComplaintEvidenceRetentionWorker } from "../src/complaints/complaint-evidence-retention.worker.js";

const enabled = process.env.SAKHI_DB_INTEGRATION === "true";

describe.skipIf(!enabled)(
  "synthetic account deletion and complaint retention database lifecycle",
  () => {
    let prisma: PrismaService | undefined;
    let cleanupPool: Pool | undefined;
    const accountId = randomUUID();
    const sessionId = randomUUID();
    const complaintId = randomUUID();
    const requestTokenDigest = createHash("sha256")
      .update(randomUUID())
      .digest("hex");
    const mediaFileId =
      "synthetic_drive_media_" + randomUUID().replace(/-/g, "");
    const complaintFileId =
      "synthetic_drive_evidence_" + randomUUID().replace(/-/g, "");
    const evidenceId =
      "synthetic_evidence_" + randomUUID().replace(/-/g, "").slice(0, 20);
    const evidenceBytes = Buffer.from(
      "synthetic complaint evidence lifecycle bytes only",
    );
    const evidenceDigest = createHash("sha256")
      .update(evidenceBytes)
      .digest("hex");
    const complaintReference =
      "#SKH-ANON-SYNTH-" + complaintId.replace(/-/g, "").slice(0, 12);
    let deletionRequestId = "";

    beforeAll(async () => {
      if (process.env.SAKHI_ENV !== "test" || process.env.NODE_ENV !== "test") {
        throw new Error(
          "Lifecycle integration requires SAKHI_ENV=test and NODE_ENV=test.",
        );
      }
      const appUrl = new URL(process.env.SAKHI_APP_DATABASE_URL ?? "");
      if (
        appUrl.hostname !== "127.0.0.1" ||
        appUrl.pathname !== "/sakhi_test"
      ) {
        throw new Error(
          "Refusing lifecycle integration against anything except local sakhi_test.",
        );
      }
      const migratorUrl = new URL(
        process.env.SAKHI_MIGRATOR_DATABASE_URL ?? "",
      );
      if (
        migratorUrl.hostname !== "127.0.0.1" ||
        migratorUrl.pathname !== "/sakhi_test" ||
        migratorUrl.port !== appUrl.port
      ) {
        throw new Error(
          "Refusing synthetic fixture cleanup unless the migrator URL targets the same local sakhi_test instance as the application URL.",
        );
      }
      cleanupPool = new Pool({
        connectionString: process.env.SAKHI_MIGRATOR_DATABASE_URL,
      });
      prisma = new PrismaService(new ConfigService(process.env));
      const databasePrincipal = await prisma.$queryRaw<
        Array<{ role: string; canDeleteLocationShares: boolean }>
      >`SELECT
        current_user::text AS role,
        has_table_privilege(current_user, 'public.safety_location_shares', 'DELETE') AS "canDeleteLocationShares"`;
      expect(databasePrincipal[0]).toMatchObject({
        role: "sakhi_test_app",
        canDeleteLocationShares: true,
      });
      await prisma.withSystemAdminIdentity(async (tx) => {
        await tx.memberAccount.create({
          data: {
            id: accountId,
            phoneE164: "+999" + accountId.replace(/-/g, "").slice(0, 12),
            phoneVerifiedAt: new Date(),
            status: "ACTIVE",
            verificationStatus: "VERIFIED",
          },
        });
        await tx.memberProfile.create({
          data: {
            accountId,
            displayName: "Synthetic Lifecycle Member",
            username: "synthetic_" + accountId.replace(/-/g, "").slice(0, 12),
            dateOfBirth: new Date("1990-01-01T00:00:00.000Z"),
            email: "synthetic-" + accountId + "@example.invalid",
          },
        });
        await tx.authSession.create({
          data: {
            id: sessionId,
            accountId,
            tokenDigest: requestTokenDigest,
            expiresAt: new Date(Date.now() + 60 * 60 * 1000),
            deviceName: "Synthetic lifecycle integration test",
          },
        });
        await tx.mediaAsset.create({
          data: {
            ownerAccountId: accountId,
            purpose: "COMMUNITY_POST_IMAGE",
            storageProvider: "GOOGLE_DRIVE",
            status: "UPLOADED",
            driveFileId: mediaFileId,
            driveFolderId: "synthetic_folder_member",
            driveFolderPath: "Sakhi Staging Media/users/synthetic/member",
            originalFileName: "synthetic-member-image.png",
            contentType: "image/png",
            byteSize: 48,
            sha256Checksum: createHash("sha256")
              .update("synthetic member media")
              .digest("hex"),
          },
        });
        await tx.discreetComplaint.create({
          data: {
            id: complaintId,
            referenceNumber: complaintReference,
            passkeyDigest: createHash("sha256")
              .update(randomUUID())
              .digest("hex"),
            disguisedBackupSerial:
              "SYNTH-" + complaintId.replace(/-/g, "").slice(0, 12),
            categorySlug: "synthetic-test",
            categoryTitle: "Synthetic lifecycle test",
            description:
              "Synthetic evidence lifecycle test. No real complaint.",
            approximateDateLabel: "synthetic test date",
            approximateTimeWindow: "synthetic test window",
            status: "CLOSED",
            retentionExpiresAt: new Date("2020-01-01T00:00:00.000Z"),
            evidenceFiles: [
              {
                id: evidenceId,
                driveFileId: complaintFileId,
                sha256Digest: evidenceDigest,
                byteSize: evidenceBytes.length,
                fileName: "synthetic-evidence.bin",
                isPurged: false,
              },
            ],
          },
        });
      });
    }, 30_000);

    afterAll(async () => {
      if (cleanupPool) {
        await cleanupPool.query(
          `DELETE FROM public.audit_events
           WHERE target_id IN (SELECT id::text FROM public.account_deletion_requests WHERE account_id = $1)
              OR target_id = $2`,
          [accountId, complaintReference],
        );
        await cleanupPool.query(
          "DELETE FROM public.account_deletion_requests WHERE account_id = $1",
          [accountId],
        );
        await cleanupPool.query(
          "DELETE FROM public.media_assets WHERE owner_account_id = $1",
          [accountId],
        );
        await cleanupPool.query(
          "DELETE FROM public.auth_sessions WHERE account_id = $1",
          [accountId],
        );
        await cleanupPool.query(
          "DELETE FROM public.member_profiles WHERE account_id = $1",
          [accountId],
        );
        await cleanupPool.query(
          "DELETE FROM public.member_accounts WHERE id = $1",
          [accountId],
        );
        await cleanupPool.query(
          "DELETE FROM public.discreet_complaints WHERE id = $1",
          [complaintId],
        );
        await cleanupPool.end();
      }
      await prisma?.$disconnect();
    });

    it("scrubs a synthetic member, queues and completes Drive media deletion, and purges due complaint evidence with RLS-scoped audit", async () => {
      const auth = {
        authenticateAuthorization: vi.fn().mockResolvedValue({
          id: sessionId,
          accountId,
          account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
        }),
      };
      const scopedIdentity = await runWithDatabaseRequestIdentity(
        () =>
          prisma!.$transaction(
            (tx) =>
              tx.$queryRaw<Array<{ role: string; accountId: string }>>`SELECT
            current_user::text AS role,
            current_setting('app.account_id', true) AS "accountId"`,
          ),
        { accountId, sessionId },
      );
      expect(scopedIdentity[0]).toMatchObject({
        role: "sakhi_test_app",
        accountId,
      });
      const service = new Module2Service(auth as any, prisma!, {} as any);

      const requested = await runWithDatabaseRequestIdentity(
        () =>
          service.requestAccountDeletion("Bearer synthetic-lifecycle-token", {
            confirmation: "DELETE",
          }),
        { accountId, sessionId },
      );
      expect(requested).toMatchObject({
        status: "REQUESTED",
        externalMediaPurgePending: true,
      });
      deletionRequestId = requested.requestId;

      const scrubbed = await prisma!.withSystemAdminIdentity(async (tx) => ({
        account: await tx.memberAccount.findUniqueOrThrow({
          where: { id: accountId },
        }),
        profile: await tx.memberProfile.findUniqueOrThrow({
          where: { accountId },
        }),
        session: await tx.authSession.findUniqueOrThrow({
          where: { id: sessionId },
        }),
        asset: await tx.mediaAsset.findFirstOrThrow({
          where: { ownerAccountId: accountId },
        }),
        request: await tx.accountDeletionRequest.findUniqueOrThrow({
          where: { id: deletionRequestId },
        }),
        audit: await tx.auditEvent.findFirstOrThrow({
          where: {
            action: "module2.account.deletion_requested",
            targetId: deletionRequestId,
          },
        }),
      }));
      expect(scrubbed.account.status).toBe("DELETED");
      expect(scrubbed.account.phoneE164).toMatch(/^\+999/);
      expect(scrubbed.profile.displayName).toBe("Deleted member");
      expect(scrubbed.profile.email).toBeNull();
      expect(scrubbed.session.revokedAt).toBeInstanceOf(Date);
      expect(scrubbed.asset.status).toBe("PENDING_PURGE");
      expect(scrubbed.request.status).toBe("REQUESTED");
      expect(scrubbed.audit).toMatchObject({
        actorType: "MEMBER",
        actorId: accountId,
      });

      const drive = {
        deleteMemberMediaFile: vi.fn().mockResolvedValue(undefined),
        deleteComplaintEvidence: vi.fn().mockResolvedValue(undefined),
      };
      const worker = new ComplaintEvidenceRetentionWorker(
        prisma!,
        drive as any,
      );
      await expect(worker.runAccountDeletionOnce()).resolves.toEqual({
        examined: 1,
        completed: 1,
      });

      const completed = await prisma!.withSystemAdminIdentity(async (tx) => ({
        asset: await tx.mediaAsset.findFirstOrThrow({
          where: { ownerAccountId: accountId },
        }),
        request: await tx.accountDeletionRequest.findUniqueOrThrow({
          where: { id: deletionRequestId },
        }),
      }));
      expect(drive.deleteMemberMediaFile).toHaveBeenCalledWith(
        mediaFileId,
        accountId,
      );
      expect(completed.asset).toMatchObject({
        status: "PURGED",
        driveFileId: null,
        driveFolderId: null,
        byteSize: 0,
        sha256Checksum: null,
      });
      expect(completed.request.status).toBe("COMPLETED");
      expect(completed.request.processedAt).toBeInstanceOf(Date);

      await expect(worker.runOnce(new Date())).resolves.toEqual({
        examined: 1,
        purged: 1,
      });
      const purgedComplaint = await prisma!.withSystemAdminIdentity((tx) =>
        tx.discreetComplaint.findUniqueOrThrow({ where: { id: complaintId } }),
      );
      expect(drive.deleteComplaintEvidence).toHaveBeenCalledWith(
        complaintFileId,
        evidenceId,
        evidenceDigest,
        evidenceBytes.length,
      );
      expect(purgedComplaint.mediaPurgedAt).toBeInstanceOf(Date);
      expect(purgedComplaint.evidenceFiles).toEqual([
        expect.objectContaining({
          id: evidenceId,
          isPurged: true,
          byteSize: 0,
          fileName: "[PURGED_BY_RETENTION_POLICY]",
        }),
      ]);
    }, 30_000);
  },
);
