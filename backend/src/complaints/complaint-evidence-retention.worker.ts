import { Injectable, Logger } from "@nestjs/common";
import type { OnModuleDestroy, OnModuleInit } from "@nestjs/common";
import { randomUUID } from "node:crypto";
import { PrismaService } from "../database/prisma.service.js";
import { GoogleDriveStorageService } from "../module2/google-drive-storage.service.js";

type EvidenceReference = {
  id?: string;
  driveFileId?: string;
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
    this.logger.log(
      "Staging complaint-evidence retention worker enabled; running initial sweep and 15-minute interval.",
    );
    void this.runOnce().catch(() => undefined);
    this.timer = setInterval(
      () => void this.runOnce().catch(() => undefined),
      15 * 60 * 1000,
    );
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
        typeof db.$transaction !== "function"
      ) {
        throw new Error("Retention worker database delegates are unavailable.");
      }
      const due = await db.discreetComplaint.findMany({
        where: {
          status: { in: ["CLOSED", "REJECTED_WITH_REASON"] },
          retentionExpiresAt: { lte: now },
          mediaPurgedAt: null,
        },
        orderBy: { retentionExpiresAt: "asc" },
        take: 20,
      });
      for (const complaint of due as Array<Record<string, any>>) {
        examined += 1;
        const evidence = Array.isArray(complaint.evidenceFiles)
          ? (complaint.evidenceFiles as EvidenceReference[])
          : [];
        const nextEvidence: EvidenceReference[] = [];
        for (const item of evidence) {
          if (item.isPurged) {
            nextEvidence.push(item);
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
          await this.storage.deleteComplaintEvidence(item.driveFileId, item.id);
          nextEvidence.push({
            ...item,
            isPurged: true,
            byteSize: 0,
            fileName: "[PURGED_BY_RETENTION_POLICY]",
          });
        }

        const purgedAt = new Date().toISOString();
        await db.$transaction(async (tx: Record<string, any>) => {
          const update = await tx.discreetComplaint.updateMany({
            where: { id: complaint.id, mediaPurgedAt: null },
            data: {
              evidenceFiles: nextEvidence,
              mediaPurgedAt: new Date(purgedAt),
              updatedAt: new Date(purgedAt),
            },
          });
          if (Number(update?.count ?? 0) !== 1) return;
          if (typeof tx.auditEvent?.create !== "function") {
            throw new Error(
              "Retention purge audit persistence is unavailable.",
            );
          }
          await tx.auditEvent.create({
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
        });
        purged += 1;
      }
      this.logger.log(
        `Complaint evidence retention sweep completed: examined=${examined}, purged=${purged}.`,
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
}
