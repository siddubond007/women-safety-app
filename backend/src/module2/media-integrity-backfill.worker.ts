import { randomUUID } from "node:crypto";
import { Injectable, Logger } from "@nestjs/common";
import type { OnModuleInit } from "@nestjs/common";
import { PrismaService } from "../database/prisma.service.js";
import { GoogleDriveStorageService } from "./google-drive-storage.service.js";

const BACKFILL_ACTION = "media.integrity.receipt_backfilled";
const COMPLETION_ACTION = "media.integrity.receipt_backfill.completed";
const COMPLETION_TARGET_ID = "staging_media_integrity_receipts_v1";
const APPLY_CONFIRMATION = "APPLY_STAGING_MEDIA_INTEGRITY_BACKFILL_V1";
const MAX_ASSETS_PER_RUN = 25;

type BackfillMode = "preview" | "apply";

type BackfillLogResult = {
  mediaId: string;
  status: string;
  receiptState?: string;
  reason?: string;
};

@Injectable()
export class MediaIntegrityBackfillWorker implements OnModuleInit {
  private readonly logger = new Logger(MediaIntegrityBackfillWorker.name);
  private running = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly googleDrive: GoogleDriveStorageService,
  ) {}

  async onModuleInit(): Promise<void> {
    const mode = process.env.SAKHI_STAGING_MEDIA_INTEGRITY_BACKFILL_MODE;
    if (!mode || mode === "disabled") return;

    if (process.env.SAKHI_ENV !== "staging" || process.env.NODE_ENV !== "production") {
      this.logger.error("Legacy media integrity backfill refused outside the staging production runtime.");
      return;
    }
    if (mode !== "preview" && mode !== "apply") {
      this.logger.error("Legacy media integrity backfill mode must be preview, apply, or disabled.");
      return;
    }
    if (mode === "apply" && process.env.SAKHI_STAGING_MEDIA_INTEGRITY_BACKFILL_CONFIRM !== APPLY_CONFIRMATION) {
      this.logger.error("Legacy media integrity backfill apply mode refused because its confirmation value is missing or invalid.");
      return;
    }

    try {
      const summary = await this.runOnce(mode);
      this.logger.log(JSON.stringify({ event: "sakhi.media_integrity_backfill.finished", ...summary }));
    } catch (error) {
      this.logger.error(
        JSON.stringify({
          event: "sakhi.media_integrity_backfill.failed",
          errorType: error instanceof Error ? error.name : "UnknownError",
        }),
      );
    }
  }

  async runOnce(mode: BackfillMode) {
    if (process.env.SAKHI_ENV !== "staging" || process.env.NODE_ENV !== "production") {
      return { mode, skipped: true, reason: "staging_only", scanned: 0, verified: 0, persisted: 0, failed: 0 };
    }
    if (mode === "apply" && process.env.SAKHI_STAGING_MEDIA_INTEGRITY_BACKFILL_CONFIRM !== APPLY_CONFIRMATION) {
      return { mode, skipped: true, reason: "apply_confirmation_required", scanned: 0, verified: 0, persisted: 0, failed: 0 };
    }
    if (this.running) {
      return { mode, skipped: true, reason: "already_running", scanned: 0, verified: 0, persisted: 0, failed: 0 };
    }
    this.running = true;
    try {
      const completed = await this.prisma.withSystemAdminIdentity((tx) =>
        tx.auditEvent.findFirst({
          where: {
            action: COMPLETION_ACTION,
            targetType: "maintenance_job",
            targetId: COMPLETION_TARGET_ID,
            outcome: "success",
          },
          select: { id: true },
        }),
      );
      if (completed) {
        return { mode, skipped: true, reason: "already_completed", scanned: 0, verified: 0, persisted: 0, failed: 0 };
      }

      const assets = await this.prisma.withSystemAdminIdentity((tx) =>
        tx.mediaAsset.findMany({
          where: {
            storageProvider: "GOOGLE_DRIVE",
            purpose: { in: ["PROFILE_PHOTO", "COMMUNITY_POST_IMAGE"] },
            status: { in: ["UPLOADED", "ATTACHED"] },
            sha256Checksum: null,
            deletedAt: null,
            driveFileId: { not: null },
            driveFolderId: { not: null },
          },
          orderBy: { createdAt: "asc" },
          take: MAX_ASSETS_PER_RUN + 1,
          select: {
            id: true,
            ownerAccountId: true,
            purpose: true,
            categorySlug: true,
            driveFileId: true,
            driveFolderId: true,
            contentType: true,
            byteSize: true,
          },
        }),
      );

      if (assets.length > MAX_ASSETS_PER_RUN) {
        this.logger.error("Legacy media integrity backfill refused because the eligible asset count exceeded its safety limit.");
        return { mode, skipped: true, reason: "asset_limit_exceeded", scanned: assets.length, verified: 0, persisted: 0, failed: assets.length };
      }

      const inputs = assets.map((asset) => ({
        mediaId: asset.id,
        driveFileId: asset.driveFileId!,
        ownerAccountId: asset.ownerAccountId,
        purpose: asset.purpose === "PROFILE_PHOTO" ? "avatar" as const : "post" as const,
        categorySlug: asset.categorySlug,
        driveFolderId: asset.driveFolderId!,
        contentType: asset.contentType,
        byteSize: asset.byteSize,
      }));
      const results = await this.googleDrive.backfillLegacyMemberMediaIntegrityReceipts(inputs, mode === "apply");
      if (results.length !== assets.length) {
        throw new Error("legacy_media_backfill_result_count_mismatch");
      }

      let verified = 0;
      let persisted = 0;
      let failed = 0;
      let bytesProcessed = 0;
      const logResults: BackfillLogResult[] = [];

      for (let index = 0; index < assets.length; index += 1) {
        const asset = assets[index]!;
        const result = results[index]!;
        if (
          result.status !== "verified" ||
          !result.sha256Checksum ||
          result.byteSize !== asset.byteSize ||
          (mode === "apply" && result.receiptState === "missing")
        ) {
          failed += 1;
          logResults.push({ mediaId: asset.id, status: result.status, reason: result.reason ?? "verification_failed" });
          continue;
        }

        verified += 1;
        bytesProcessed += result.byteSize;
        if (mode === "preview") {
          logResults.push({ mediaId: asset.id, status: "verified", receiptState: result.receiptState });
          continue;
        }

        try {
          const persistence = await this.prisma.withSystemAdminIdentity(async (tx) => {
            const updated = await tx.mediaAsset.updateMany({
              where: {
                id: asset.id,
                driveFileId: asset.driveFileId,
                sha256Checksum: null,
                deletedAt: null,
              },
              data: { sha256Checksum: result.sha256Checksum },
            });
            if (updated.count === 1) {
              await tx.auditEvent.create({
                data: {
                  actorType: "SYSTEM",
                  actorId: null,
                  action: BACKFILL_ACTION,
                  targetType: "media_asset",
                  targetId: asset.id,
                  outcome: "success",
                  requestId: randomUUID(),
                  redactedMetadata: {
                    source: "google_drive_verified_download",
                    receiptPatched: result.receiptState === "patched",
                    byteSize: asset.byteSize,
                  },
                },
              });
              return "updated";
            }

            const current = await tx.mediaAsset.findUnique({
              where: { id: asset.id },
              select: { sha256Checksum: true },
            });
            if (current?.sha256Checksum?.toLowerCase() === result.sha256Checksum!.toLowerCase()) {
              return "already_current";
            }
            throw new Error("media_asset_changed_during_backfill");
          });
          if (persistence === "updated") persisted += 1;
          logResults.push({ mediaId: asset.id, status: persistence, receiptState: result.receiptState });
        } catch (error) {
          failed += 1;
          logResults.push({
            mediaId: asset.id,
            status: "failed",
            reason: error instanceof Error ? error.message : "database_update_failed",
          });
        }
      }

      if (mode === "apply" && failed === 0 && verified === assets.length) {
        await this.prisma.withSystemAdminIdentity((tx) =>
          tx.auditEvent.create({
            data: {
              actorType: "SYSTEM",
              actorId: SYSTEM_ACTOR_ID,
              action: COMPLETION_ACTION,
              targetType: "maintenance_job",
              targetId: COMPLETION_TARGET_ID,
              outcome: "success",
              requestId: randomUUID(),
              redactedMetadata: {
                assetsScanned: assets.length,
                assetsPersisted: persisted,
                bytesProcessed,
                version: 1,
              },
            },
          }),
        );
      }

      const summary = {
        mode,
        skipped: false,
        scanned: assets.length,
        verified,
        persisted,
        failed,
        bytesProcessed,
        results: logResults,
      };
      this.logger.log(JSON.stringify({ event: "sakhi.media_integrity_backfill.summary", ...summary }));
      return summary;
    } finally {
      this.running = false;
    }
  }
}
