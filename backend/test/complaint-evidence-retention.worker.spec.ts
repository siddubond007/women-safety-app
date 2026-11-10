import { describe, expect, it, vi } from "vitest";
import { ComplaintEvidenceRetentionWorker } from "../src/complaints/complaint-evidence-retention.worker.js";
import { PrismaService } from "../src/database/prisma.service.js";
import { GoogleDriveStorageService } from "../src/module2/google-drive-storage.service.js";

describe("ComplaintEvidenceRetentionWorker", () => {
  it("purges only due terminal evidence, then atomically records metadata and audit", async () => {
    const complaint = {
      id: "complaint-1",
      referenceNumber: "#SKH-ANON-2026-0001",
      evidenceFiles: [
        {
          id: "evidence_1234567890",
          driveFileId: "drive_file_1234567890",
          byteSize: 123,
          fileName: "opaque.bin",
          isPurged: false,
        },
      ],
    };
    const updateMany = vi.fn().mockResolvedValue({ count: 1 });
    const auditCreate = vi.fn().mockResolvedValue({ id: "audit-1" });
    const transaction = vi.fn(async (fn: (tx: any) => Promise<unknown>) =>
      fn({
        discreetComplaint: { updateMany },
        auditEvent: { create: auditCreate },
      }),
    );
    const prisma = {
      discreetComplaint: { findMany: vi.fn().mockResolvedValue([complaint]) },
      $transaction: transaction,
    };
    const storage = {
      deleteComplaintEvidence: vi.fn().mockResolvedValue(undefined),
    };
    const worker = new ComplaintEvidenceRetentionWorker(
      prisma as unknown as PrismaService,
      storage as unknown as GoogleDriveStorageService,
    );

    const result = await worker.runOnce(new Date("2026-11-11T00:00:00.000Z"));

    expect(result).toEqual({ examined: 1, purged: 1 });
    expect(prisma.discreetComplaint.findMany).toHaveBeenCalledWith({
      where: {
        status: { in: ["CLOSED", "REJECTED_WITH_REASON"] },
        retentionExpiresAt: { lte: new Date("2026-11-11T00:00:00.000Z") },
        mediaPurgedAt: null,
      },
      orderBy: { retentionExpiresAt: "asc" },
      take: 20,
    });
    expect(storage.deleteComplaintEvidence).toHaveBeenCalledWith(
      "drive_file_1234567890",
      "evidence_1234567890",
    );
    expect(updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: "complaint-1", mediaPurgedAt: null },
        data: expect.objectContaining({
          evidenceFiles: [
            expect.objectContaining({
              isPurged: true,
              byteSize: 0,
              fileName: "[PURGED_BY_RETENTION_POLICY]",
            }),
          ],
        }),
      }),
    );
    expect(auditCreate).toHaveBeenCalledWith({
      data: expect.objectContaining({
        actorType: "SYSTEM",
        action: "module5.complaint.evidence.retention_purged",
        targetId: complaint.referenceNumber,
        redactedMetadata: { retentionPurge: true, evidenceCount: 1 },
      }),
    });
  });

  it("does not mark evidence purged when Drive deletion fails", async () => {
    const complaint = {
      id: "complaint-2",
      referenceNumber: "#SKH-ANON-2026-0002",
      evidenceFiles: [
        { id: "evidence_1234567890", driveFileId: "drive_file_1234567890" },
      ],
    };
    const updateMany = vi.fn();
    const prisma = {
      discreetComplaint: { findMany: vi.fn().mockResolvedValue([complaint]) },
      $transaction: vi.fn(),
    };
    const storage = {
      deleteComplaintEvidence: vi
        .fn()
        .mockRejectedValue(new Error("Drive unavailable")),
    };
    const worker = new ComplaintEvidenceRetentionWorker(
      prisma as unknown as PrismaService,
      storage as unknown as GoogleDriveStorageService,
    );

    await expect(worker.runOnce()).rejects.toThrow("Drive unavailable");
    expect(updateMany).not.toHaveBeenCalled();
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
});
