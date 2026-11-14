import { Injectable, Logger } from "@nestjs/common";
import type { OnModuleDestroy, OnModuleInit } from "@nestjs/common";
import { randomUUID } from "node:crypto";
import { PrismaService } from "../database/prisma.service.js";
import { GoogleDriveStorageService } from "../module2/google-drive-storage.service.js";

type EvidenceReference = {
  id?: string;
  driveFileId?: string;
  sha256Digest?: string;
  isPurged?: boolean;
  byteSize?: number;
  fileName?: string;
  [key: string]: unknown;
};

/**
 * Staging complaint-evidence retention worker.
 *
 * It only processes terminal complaints whose persisted retention deadline has
 * passed. Drive deletion is idempotent; database metadata and audit updates are
 * committed together so a failed DB write is retried on the next sweep.
 */
@Injectable()
export class ComplaintEvidenceRetentionWorker
  implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(ComplaintEvidenceRetentionWorker.name);
  private timer: NodeJS.Timeout | undefined;
  private running = false;
  private deletionRunning = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: GoogleDriveStorageService,
  ) {}

  onModuleInit(): void {
    // Keep automatic destructive retention actions restricted to the explicitly
    // configured staging deployment until production policy is separately approved.
    if (
      process.env.SAKHI_ENV !== "staging" ||
      process.env.SAKHI_EVIDENCE_RETENTION_WORKER_ENABLED !== "true"
    ) {
      return;
    }
    if (process.env.NODE_ENV === "production") {
      this.logger.log(
        "Staging retention worker is in external-scheduler mode; no in-process timer is started.",
      );
      return;
    }
    this.logger.log(
      "Local staging retention worker enabled; running an initial sweep and 15-minute development interval.",
    );
    void this.runOnce().catch(() => undefined);
    void this.runAccountDeletionOnce().catch(() => undefined);
    this.timer = setInterval(() => {
      void this.runOnce().catch(() => undefined);
      void this.runAccountDeletionOnce().catch(() => undefined);
    }, 15 * 60 * 1000);
    this.timer.unref();
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  async runOnce(
    now = new Date(),
  ): Promise<{ examined: number; purged: number }> {
    if (this.running) return { examined: 0, purged: 0 };
    this.running = true;
    let examined = 0;
    let purged = 0;
    try {
      const db = this.prisma as unknown as Record<string, any>;
      if (
        typeof db.discreetComplaint?.findMany !== "function" ||
        typeof this.prisma.withSystemAdminIdentity !== "function"
      ) {
        throw new Error("Retention worker database delegates are unavailable.");
      }
      // Repair legacy rows that were marked purged before the metadata scrub
      // was enforced. The SQL predicate selects only dirty, already-purged JSON
      // records, so clean rows cannot starve later records in the bounded batch.
      const legacyRows = await this.prisma.withSystemAdminIdentity(async (tx) => {
        const txDb = tx as unknown as Record<string, any>;
        if (typeof txDb.$queryRawUnsafe !== "function") return [];
        return txDb.$queryRawUnsafe(
          `SELECT id, reference_number AS "referenceNumber",
                  evidence_files AS "evidenceFiles", media_purged_at AS "mediaPurgedAt"
             FROM public.discreet_complaints
            WHERE status IN ($1, $2)
              AND retention_expires_at <= $3
              AND media_purged_at IS NOT NULL
              AND EXISTS (
                SELECT 1
                  FROM jsonb_array_elements(
                    CASE WHEN jsonb_typeof(evidence_files)='array'
                         THEN evidence_files ELSE '[]'::jsonb END
                  ) AS evidence(value)
                 WHERE evidence.value->>'isPurged' IS DISTINCT FROM 'true'
                    OR (evidence.value - ARRAY['id','isPurged','byteSize','fileName']::text[]) <> '{}'::jsonb
              )
            ORDER BY retention_expires_at ASC
            LIMIT 20`,
          "CLOSED",
          "REJECTED_WITH_REASON",
          now,
        ) as Promise<Array<Record<string, any>>>;
      });
      let legacyMetadataSanitized = 0;
      for (const complaint of legacyRows as Array<Record<string, any>>) {
        const evidence = Array.isArray(complaint.evidenceFiles)
          ? (complaint.evidenceFiles as EvidenceReference[])
          : [];
        const sanitizedEvidence: EvidenceReference[] = [];
        for (const item of evidence) {
          if (item.isPurged !== true) {
            if (typeof item.id !== "string" || typeof item.driveFileId !== "string") {
              throw new Error("A legacy completed complaint has an incomplete unpurged evidence reference; reconciliation was stopped safely.");
            }
            if (typeof item.sha256Digest !== "string" || !/^[a-f0-9]{64}$/i.test(item.sha256Digest) || !Number.isSafeInteger(item.byteSize) || Number(item.byteSize) <= 0) {
              throw new Error("A legacy completed complaint has no valid evidence SHA-256/byte-size receipt; reconciliation was stopped safely.");
            }
            await this.storage.deleteComplaintEvidence(item.driveFileId, item.id, item.sha256Digest, Number(item.byteSize));
          }
          sanitizedEvidence.push({
            id: item.id,
            isPurged: true,
            byteSize: 0,
            fileName: "[PURGED_BY_RETENTION_POLICY]",
          });
        }
        const committed = await this.prisma.withSystemAdminIdentity(async (tx) => {
          const txDb = tx as unknown as Record<string, any>;
          const update = await txDb.discreetComplaint.updateMany({
            where: {
              id: complaint.id,
              mediaPurgedAt: complaint.mediaPurgedAt,
              evidenceFiles: { equals: complaint.evidenceFiles },
            },
            data: { evidenceFiles: sanitizedEvidence, updatedAt: now },
          });
          if (Number(update?.count ?? 0) !== 1) return false;
          await txDb.auditEvent.create({
            data: {
              actorType: "SYSTEM",
              actorId: null,
              action: "module5.complaint.evidence.retention_purged",
              targetType: "module5_complaint",
              targetId: String(complaint.referenceNumber),
              outcome: "purged",
              requestId: randomUUID(),
              redactedMetadata: {
                retentionPurge: true,
                evidenceCount: sanitizedEvidence.length,
              },
            },
          });
          return true;
        });
        if (committed) legacyMetadataSanitized += 1;
      }
      examined += legacyRows.length;

      // The retention scheduler is an internal system actor. Establish the
      // explicit database identity for both selection and the atomic metadata
      // + audit transaction so forced RLS accepts only this trusted worker.
      const due = await this.prisma.withSystemAdminIdentity((tx) =>
        tx.discreetComplaint.findMany({
          where: {
            status: { in: ["CLOSED", "REJECTED_WITH_REASON"] },
            retentionExpiresAt: { lte: now },
            mediaPurgedAt: null,
          },
          orderBy: { retentionExpiresAt: "asc" },
          take: 20,
        }),
      );
      for (const complaint of due as Array<Record<string, any>>) {
        examined += 1;
        const evidence = Array.isArray(complaint.evidenceFiles)
          ? (complaint.evidenceFiles as EvidenceReference[])
          : [];
        const nextEvidence: EvidenceReference[] = [];
        for (const item of evidence) {
          if (item.isPurged === true) {
            // Never retain provider IDs, checksums, names, or arbitrary legacy
            // metadata after the retention boundary, even on a retry path.
            nextEvidence.push({
              id: item.id,
              isPurged: true,
              byteSize: 0,
              fileName: "[PURGED_BY_RETENTION_POLICY]",
            });
            continue;
          }
          if (
            typeof item.id !== "string" ||
            typeof item.driveFileId !== "string"
          ) {
            throw new Error(
              "An expired complaint has an incomplete evidence reference; purge was stopped safely.",
            );
          }
          if (typeof item.sha256Digest !== "string" || !/^[a-f0-9]{64}$/i.test(item.sha256Digest) || !Number.isSafeInteger(item.byteSize) || Number(item.byteSize) <= 0) {
            throw new Error("An expired complaint evidence record has no valid SHA-256/byte-size receipt; purge was stopped safely.");
          }
          await this.storage.deleteComplaintEvidence(item.driveFileId, item.id, item.sha256Digest, Number(item.byteSize));
          // Retain only a stable opaque evidence reference and a purge marker.
          // Drive IDs, checksums, original names, and arbitrary uploaded metadata
          // must not survive the retention boundary in the complaint JSON.
          nextEvidence.push({
            id: item.id,
            isPurged: true,
            byteSize: 0,
            fileName: "[PURGED_BY_RETENTION_POLICY]",
          });
        }

        const purgedAt = new Date().toISOString();
        const committed = await this.prisma.withSystemAdminIdentity(async (tx) => {
          const txDb = tx as unknown as Record<string, any>;
          const update = await txDb.discreetComplaint.updateMany({
            where: { id: complaint.id, mediaPurgedAt: null },
            data: {
              evidenceFiles: nextEvidence,
              mediaPurgedAt: new Date(purgedAt),
              updatedAt: new Date(purgedAt),
            },
          });
          if (Number(update?.count ?? 0) !== 1) return false;
          if (typeof txDb.auditEvent?.create !== "function") {
            throw new Error(
              "Retention purge audit persistence is unavailable.",
            );
          }
          await txDb.auditEvent.create({
            data: {
              actorType: "SYSTEM",
              actorId: null,
              action: "module5.complaint.evidence.retention_purged",
              targetType: "module5_complaint",
              targetId: String(complaint.referenceNumber),
              outcome: "purged",
              requestId: randomUUID(),
              redactedMetadata: {
                retentionPurge: true,
                evidenceCount: nextEvidence.length,
              },
            },
          });
          return true;
        });
        if (committed) purged += 1;
      }
      this.logger.log(
        `Complaint evidence retention sweep completed: examined=${examined}, purged=${purged}, legacyMetadataSanitized=${legacyMetadataSanitized}.`,
      );
      return { examined, purged };
    } catch (error) {
      this.logger.error(
        `Complaint evidence retention sweep failed safely: ${error instanceof Error ? error.message : "unknown error"}`,
      );
      throw error;
    } finally {
      this.running = false;
    }
  }

  /**
   * Completes account erasure after the member-facing request has immediately
   * deactivated the account and scrubbed its relational data. Drive deletion is
   * owner-verified and idempotent; failed objects remain queued for the next run.
   */
  async runAccountDeletionOnce(syntheticFixtureId?: string): Promise<{ examined: number; completed: number }> {
    if (this.deletionRunning) return { examined: 0, completed: 0 };
    this.deletionRunning = true;
    let examined = 0;
    let completed = 0;
    try {
      let syntheticAccountId: string | undefined;
      if (syntheticFixtureId !== undefined) {
        if (!/^[0-9a-f-]{36}$/i.test(syntheticFixtureId)) {
          throw new Error("A valid synthetic fixture ID is required.");
        }
        const fixtureEvent = await this.prisma.withSystemAdminIdentity((tx) =>
          tx.auditEvent.findFirst({
            where: {
              action: "staging.synthetic_member.created",
              targetType: "synthetic_member_fixture",
              targetId: syntheticFixtureId,
              outcome: "created",
            },
            select: { redactedMetadata: true },
          }),
        );
        const metadata =
          fixtureEvent?.redactedMetadata &&
          typeof fixtureEvent.redactedMetadata === "object" &&
          !Array.isArray(fixtureEvent.redactedMetadata)
            ? (fixtureEvent.redactedMetadata as Record<string, unknown>)
            : {};
        const candidateAccountId = metadata.accountId;
        if (
          metadata.testOnly !== true ||
          metadata.syntheticFixture !== true ||
          metadata.fixtureId !== syntheticFixtureId ||
          typeof metadata.expiresAt !== "string" ||
          !Number.isFinite(Date.parse(metadata.expiresAt)) ||
          Date.parse(metadata.expiresAt) <= Date.now() ||
          typeof candidateAccountId !== "string" ||
          !/^[0-9a-f-]{36}$/i.test(candidateAccountId)
        ) {
          throw new Error("The requested synthetic fixture is not registered or its marker is invalid.");
        }
        const fixtureAccount = await this.prisma.withSystemAdminIdentity((tx) =>
          tx.memberAccount.findUnique({
            where: { id: candidateAccountId },
            select: { id: true, status: true },
          }),
        );
        if (!fixtureAccount || fixtureAccount.status !== "DELETED") {
          throw new Error("The synthetic fixture account must complete the member deletion request before retention can run.");
        }
        syntheticAccountId = candidateAccountId;
      }

      const due = await this.prisma.withSystemAdminIdentity((tx) =>
        tx.accountDeletionRequest.findMany({
          where: {
            ...(syntheticAccountId ? { accountId: syntheticAccountId } : {}),
            status: { in: ["REQUESTED", "PROCESSING"] },
          },
          orderBy: { requestedAt: "asc" },
          take: 10,
        }),
      );
      for (const request of due) {
        examined += 1;
        await this.prisma.withSystemAdminIdentity((tx) =>
          tx.accountDeletionRequest.updateMany({
            where: { id: request.id, status: { in: ["REQUESTED", "PROCESSING"] } },
            data: { status: "PROCESSING" },
          }),
        );
        try {
          const assets = await this.prisma.withSystemAdminIdentity((tx) =>
            tx.mediaAsset.findMany({
              where: { ownerAccountId: request.accountId, status: "PENDING_PURGE" },
              select: { id: true, ownerAccountId: true, storageProvider: true, driveFileId: true },
            }),
          );
          for (const asset of assets) {
            if (asset.storageProvider !== "GOOGLE_DRIVE" || !asset.driveFileId) {
              throw new Error("A pending member-media record has no verifiable Google Drive reference.");
            }
            await this.storage.deleteMemberMediaFile(asset.driveFileId, asset.ownerAccountId);
          }
          const processedAt = new Date();
          const completedThisRequest = await this.prisma.withSystemAdminIdentity(async (tx) => {
            await tx.mediaAsset.updateMany({
              where: { ownerAccountId: request.accountId, status: "PENDING_PURGE" },
              data: {
                status: "PURGED",
                driveFileId: null,
                driveFolderId: null,
                localAssetPath: null,
                originalFileName: "[PURGED_BY_ACCOUNT_DELETION]",
                contentType: "application/octet-stream",
                byteSize: 0,
                sha256Checksum: null,
              },
            });
            const updated = await tx.accountDeletionRequest.updateMany({
              where: { id: request.id, status: "PROCESSING" },
              data: { status: "COMPLETED", processedAt },
            });
            if (updated.count !== 1) return false;
            await tx.auditEvent.create({
              data: {
                actorType: "SYSTEM",
                actorId: null,
                action: "module2.account.deletion_completed",
                targetType: "account_deletion_request",
                targetId: request.id,
                outcome: "completed",
                requestId: request.id,
                redactedMetadata: { externalMediaPurged: true, mediaAssetCount: assets.length },
              },
            });
            return true;
          });
          if (completedThisRequest) completed += 1;
        } catch (error) {
          this.logger.error(
            `Account deletion media purge remains queued for request ${request.id}: ${error instanceof Error ? error.message : "unknown error"}`,
          );
          // Keep PROCESSING so the next scheduled invocation retries idempotently.
        }
      }
      this.logger.log(`Account deletion purge sweep completed: examined=${examined}, completed=${completed}.`);
      return { examined, completed };
    } finally {
      this.deletionRunning = false;
    }
  }

}
