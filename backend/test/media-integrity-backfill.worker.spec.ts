import { afterEach, describe, expect, it, vi } from "vitest";
import { MediaIntegrityBackfillWorker } from "../src/module2/media-integrity-backfill.worker.js";
import type { PrismaService } from "../src/database/prisma.service.js";
import type { GoogleDriveStorageService } from "../src/module2/google-drive-storage.service.js";

const mediaId = "99999999-9999-4999-8999-999999999999";
const accountId = "2f6f7fa1-8c5c-4bb0-ae1a-0f7e3a2e5a41";
const driveFileId = "drive_file_1234567890";
const driveFolderId = "synthetic-media-folder";
const sha256Checksum = "a".repeat(64);

const asset = {
  id: mediaId,
  ownerAccountId: accountId,
  purpose: "COMMUNITY_POST_IMAGE",
  categorySlug: "community",
  driveFileId,
  driveFolderId,
  contentType: "image/jpeg",
  byteSize: 42,
};

function createHarness(options?: {
  completed?: boolean;
  assets?: typeof asset[];
  result?: {
    mediaId: string;
    status: "verified" | "rejected" | "failed";
    receiptState: "present" | "missing" | "patched";
    sha256Checksum?: string;
    byteSize?: number;
    reason?: string;
  };
}) {
  const tx = {
    auditEvent: {
      findFirst: vi.fn().mockResolvedValue(options?.completed ? { id: "completed-marker" } : null),
      create: vi.fn().mockResolvedValue({ id: "audit-event" }),
    },
    mediaAsset: {
      findMany: vi.fn().mockResolvedValue(options?.assets ?? [asset]),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      findUnique: vi.fn().mockResolvedValue({ sha256Checksum }),
    },
  };
  const prisma = {
    withSystemAdminIdentity: vi.fn(async (operation: (transaction: typeof tx) => unknown) => operation(tx)),
  } as unknown as PrismaService;
  const drive = {
    backfillLegacyMemberMediaIntegrityReceipts: vi.fn().mockResolvedValue([
      options?.result ?? {
        mediaId, status: "verified", receiptState: "patched", sha256Checksum, byteSize: asset.byteSize,
      },
    ]),
  } as unknown as GoogleDriveStorageService;
  return { worker: new MediaIntegrityBackfillWorker(prisma, drive), prisma, drive, tx };
}

afterEach(() => {
  delete process.env.SAKHI_STAGING_MEDIA_INTEGRITY_BACKFILL_MODE;
  delete process.env.SAKHI_STAGING_MEDIA_INTEGRITY_BACKFILL_CONFIRM;
  delete process.env.SAKHI_ENV;
});

describe("MediaIntegrityBackfillWorker", () => {
  it("previews verified legacy media without writing to Drive metadata or PostgreSQL", async () => {
    const { worker, drive, tx } = createHarness();

    const result = await worker.runOnce("preview");

    expect(result).toMatchObject({ mode: "preview", scanned: 1, verified: 1, persisted: 0, failed: 0 });
    expect(drive.backfillLegacyMemberMediaIntegrityReceipts).toHaveBeenCalledWith([
      expect.objectContaining({ mediaId, ownerAccountId: accountId, driveFileId, driveFolderId }),
    ], false);
    expect(tx.mediaAsset.updateMany).not.toHaveBeenCalled();
    expect(tx.auditEvent.create).not.toHaveBeenCalled();
  });

  it("persists the checksum and audit records only after Drive has patched the receipt", async () => {
    const { worker, drive, tx } = createHarness();

    const result = await worker.runOnce("apply");

    expect(result).toMatchObject({ mode: "apply", scanned: 1, verified: 1, persisted: 1, failed: 0 });
    expect(drive.backfillLegacyMemberMediaIntegrityReceipts).toHaveBeenCalledWith(expect.any(Array), true);
    expect(tx.mediaAsset.updateMany).toHaveBeenCalledWith({
      where: { id: mediaId, driveFileId, sha256Checksum: null, deletedAt: null },
      data: { sha256Checksum },
    });
    expect(tx.auditEvent.create).toHaveBeenCalledTimes(2);
    expect(tx.auditEvent.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        action: "media.integrity.receipt_backfilled",
        targetType: "media_asset",
        targetId: mediaId,
        outcome: "success",
      }),
    });
    expect(tx.auditEvent.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        action: "media.integrity.receipt_backfill.completed",
        targetType: "maintenance_job",
        targetId: "staging_media_integrity_receipts_v1",
        outcome: "success",
      }),
    });
  });

  it("does not persist a rejected Drive object or mark the backfill complete", async () => {
    const { worker, drive, tx } = createHarness({
      result: { mediaId, status: "rejected", receiptState: "missing", reason: "upload_id_metadata_mismatch" },
    });

    const result = await worker.runOnce("apply");

    expect(result).toMatchObject({ scanned: 1, verified: 0, persisted: 0, failed: 1 });
    expect(tx.mediaAsset.updateMany).not.toHaveBeenCalled();
    expect(tx.auditEvent.create).not.toHaveBeenCalled();
    expect(drive.backfillLegacyMemberMediaIntegrityReceipts).toHaveBeenCalled();
  });

  it("skips a backfill whose completion marker already exists", async () => {
    const { worker, drive, tx } = createHarness({ completed: true });

    const result = await worker.runOnce("apply");

    expect(result).toMatchObject({ skipped: true, reason: "already_completed" });
    expect(tx.mediaAsset.findMany).not.toHaveBeenCalled();
    expect(drive.backfillLegacyMemberMediaIntegrityReceipts).not.toHaveBeenCalled();
  });

  it("refuses to process more than the configured safety limit", async () => {
    const { worker, drive } = createHarness({ assets: Array.from({ length: 26 }, (_, index) => ({ ...asset, id: `99999999-9999-4999-8999-${String(index).padStart(12, "0")}` })) });

    const result = await worker.runOnce("preview");

    expect(result).toMatchObject({ skipped: true, reason: "asset_limit_exceeded", scanned: 26 });
    expect(drive.backfillLegacyMemberMediaIntegrityReceipts).not.toHaveBeenCalled();
  });

  it("does not start the maintenance worker when no explicit staging mode is configured", async () => {
    const { worker, prisma } = createHarness();
    process.env.SAKHI_ENV = "staging";
    process.env.NODE_ENV = "production";

    await worker.onModuleInit();

    expect(prisma.withSystemAdminIdentity).not.toHaveBeenCalled();
  });

  it("requires the staging runtime and explicit confirmation before apply mode", async () => {
    const { worker, prisma } = createHarness();
    process.env.SAKHI_ENV = "staging";
    process.env.NODE_ENV = "production";
    process.env.SAKHI_STAGING_MEDIA_INTEGRITY_BACKFILL_MODE = "apply";

    await worker.onModuleInit();

    expect(prisma.withSystemAdminIdentity).not.toHaveBeenCalled();
  });
});
