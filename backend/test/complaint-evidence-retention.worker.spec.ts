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
          sha256Digest: "a".repeat(64),
          fileName: "opaque.bin",
          isPurged: false,
        },
      ],
    };
    const updateMany = vi.fn().mockResolvedValue({ count: 1 });
    const auditCreate = vi.fn().mockResolvedValue({ id: "audit-1" });
    const findMany = vi.fn().mockResolvedValue([complaint]);
    const transaction = vi.fn(async (fn: (tx: any) => Promise<unknown>) =>
      fn({
        discreetComplaint: { findMany, updateMany },
        auditEvent: { create: auditCreate },
      }),
    );
    const prisma = {
      discreetComplaint: { findMany },
      withSystemAdminIdentity: vi.fn((operation: (tx: any) => Promise<unknown>) => transaction(operation)),
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
      "a".repeat(64),
      123,
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
    expect(updateMany.mock.calls[0]?.[0]?.data?.evidenceFiles).toEqual([
      {
        id: "evidence_1234567890",
        isPurged: true,
        byteSize: 0,
        fileName: "[PURGED_BY_RETENTION_POLICY]",
      },
    ]);
    expect(JSON.stringify(updateMany.mock.calls[0]?.[0]?.data?.evidenceFiles)).not.toMatch(
      /driveFileId|sha256Digest|opaque\.bin|drive_file_1234567890/i,
    );
    expect(auditCreate).toHaveBeenCalledWith({
      data: expect.objectContaining({
        actorType: "SYSTEM",
        actorId: null,
        action: "module5.complaint.evidence.retention_purged",
        targetId: complaint.referenceNumber,
        redactedMetadata: { retentionPurge: true, evidenceCount: 1 },
      }),
    });
  });

  it("does not count or audit a complaint another worker already committed", async () => {
    const complaint = {
      id: "complaint-concurrent",
      referenceNumber: "#SKH-ANON-2026-CONCURRENT",
      evidenceFiles: [],
    };
    const updateMany = vi.fn().mockResolvedValue({ count: 0 });
    const auditCreate = vi.fn();
    const findMany = vi.fn().mockResolvedValue([complaint]);
    const transaction = vi.fn(async (fn: (tx: any) => Promise<unknown>) =>
      fn({ discreetComplaint: { findMany, updateMany }, auditEvent: { create: auditCreate } }),
    );
    const prisma = {
      discreetComplaint: { findMany },
      withSystemAdminIdentity: vi.fn((operation: (tx: any) => Promise<unknown>) => transaction(operation)),
    };
    const storage = { deleteComplaintEvidence: vi.fn() };
    const worker = new ComplaintEvidenceRetentionWorker(
      prisma as unknown as PrismaService,
      storage as unknown as GoogleDriveStorageService,
    );

    await expect(worker.runOnce()).resolves.toEqual({ examined: 1, purged: 0 });
    expect(auditCreate).not.toHaveBeenCalled();
  });

  it("does not mark evidence purged when Drive deletion fails", async () => {
    const complaint = {
      id: "complaint-2",
      referenceNumber: "#SKH-ANON-2026-0002",
      evidenceFiles: [
        { id: "evidence_1234567890", driveFileId: "drive_file_1234567890", sha256Digest: "b".repeat(64), byteSize: 456 },
      ],
    };
    const updateMany = vi.fn();
    const findMany = vi.fn().mockResolvedValue([complaint]);
    const transaction = vi.fn(async (fn: (tx: any) => Promise<unknown>) =>
      fn({ discreetComplaint: { findMany, updateMany } }),
    );
    const prisma = {
      discreetComplaint: { findMany },
      withSystemAdminIdentity: vi.fn((operation: (tx: any) => Promise<unknown>) => transaction(operation)),
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
    expect(transaction).toHaveBeenCalledTimes(1);
  });
  it("completes queued account erasure only after owner-verified Drive media deletion", async () => {
    const request = { id: "deletion-1", accountId: "2f6f7fa1-8c5c-4bb0-ae1a-0f7e3a2e5a41", status: "REQUESTED" };
    const asset = {
      id: "asset-1",
      ownerAccountId: request.accountId,
      storageProvider: "GOOGLE_DRIVE",
      driveFileId: "drive_file_1234567890",
    };
    const accountDeletionRequest = {
      findMany: vi.fn().mockResolvedValue([request]),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
    };
    const mediaAsset = {
      findMany: vi.fn().mockResolvedValue([asset]),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
    };
    const auditCreate = vi.fn().mockResolvedValue({ id: "audit-deletion" });
    const tx = { accountDeletionRequest, mediaAsset, auditEvent: { create: auditCreate } };
    const prisma = {
      withSystemAdminIdentity: vi.fn(async (operation: (tx: any) => Promise<unknown>) => operation(tx)),
    };
    const storage = { deleteMemberMediaFile: vi.fn().mockResolvedValue(undefined) };
    const worker = new ComplaintEvidenceRetentionWorker(
      prisma as unknown as PrismaService,
      storage as unknown as GoogleDriveStorageService,
    );

    await expect(worker.runAccountDeletionOnce()).resolves.toEqual({ examined: 1, completed: 1 });
    expect(storage.deleteMemberMediaFile).toHaveBeenCalledWith(asset.driveFileId, request.accountId);
    expect(mediaAsset.updateMany).toHaveBeenCalledWith({
      where: { ownerAccountId: request.accountId, status: "PENDING_PURGE" },
      data: expect.objectContaining({ status: "PURGED", driveFileId: null, byteSize: 0, sha256Checksum: null }),
    });
    expect(accountDeletionRequest.updateMany).toHaveBeenLastCalledWith({
      where: { id: request.id, status: "PROCESSING" },
      data: { status: "COMPLETED", processedAt: expect.any(Date) },
    });
    expect(auditCreate).toHaveBeenCalledWith({
      data: expect.objectContaining({ action: "module2.account.deletion_completed", targetId: request.id }),
    });
  });

  it("keeps account erasure queued when a Drive object cannot be verified or deleted", async () => {
    const request = { id: "deletion-2", accountId: "2f6f7fa1-8c5c-4bb0-ae1a-0f7e3a2e5a41", status: "PROCESSING" };
    const accountDeletionRequest = {
      findMany: vi.fn().mockResolvedValue([request]),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
    };
    const mediaAsset = {
      findMany: vi.fn().mockResolvedValue([{
        id: "asset-2", ownerAccountId: request.accountId,
        storageProvider: "GOOGLE_DRIVE", driveFileId: "drive_file_1234567890",
      }]),
      updateMany: vi.fn(),
    };
    const tx = { accountDeletionRequest, mediaAsset, auditEvent: { create: vi.fn() } };
    const prisma = {
      withSystemAdminIdentity: vi.fn(async (operation: (tx: any) => Promise<unknown>) => operation(tx)),
    };
    const storage = { deleteMemberMediaFile: vi.fn().mockRejectedValue(new Error("Drive unavailable")) };
    const worker = new ComplaintEvidenceRetentionWorker(
      prisma as unknown as PrismaService,
      storage as unknown as GoogleDriveStorageService,
    );

    await expect(worker.runAccountDeletionOnce()).resolves.toEqual({ examined: 1, completed: 0 });
    expect(mediaAsset.updateMany).not.toHaveBeenCalled();
    expect(accountDeletionRequest.updateMany).toHaveBeenCalledTimes(1);
  });


  it("runs account deletion only for a registered synthetic fixture ID", async () => {
    const fixtureId = "f10e1c2a-4b5d-4e6f-8a90-123456789abc";
    const accountId = "2f6f7fa1-8c5c-4bb0-ae1a-0f7e3a2e5a41";
    const request = { id: "synthetic-deletion-1", accountId, status: "REQUESTED" };
    const fixtureLookup = vi.fn().mockResolvedValue({
      redactedMetadata: {
        testOnly: true,
        syntheticFixture: true,
        fixtureId,
        accountId,
        expiresAt: new Date(Date.now() + 60_000).toISOString(),
      },
    });
    const accountDeletionRequest = {
      findMany: vi.fn().mockResolvedValue([request]),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
    };
    const mediaAsset = {
      findMany: vi.fn().mockResolvedValue([]),
      updateMany: vi.fn().mockResolvedValue({ count: 0 }),
    };
    const auditEvent = {
      findFirst: fixtureLookup,
      create: vi.fn().mockResolvedValue({ id: "audit-synthetic" }),
    };
    const tx = {
      auditEvent,
      accountDeletionRequest,
      mediaAsset,
      memberAccount: {
        findUnique: vi.fn().mockResolvedValue({ id: accountId, status: "DELETED" }),
      },
    };
    const prisma = {
      withSystemAdminIdentity: vi.fn(async (operation: (tx: any) => Promise<unknown>) => operation(tx)),
    };
    const storage = { deleteMemberMediaFile: vi.fn().mockResolvedValue(undefined) };
    const worker = new ComplaintEvidenceRetentionWorker(
      prisma as unknown as PrismaService,
      storage as unknown as GoogleDriveStorageService,
    );

    await expect(worker.runAccountDeletionOnce(fixtureId)).resolves.toEqual({
      examined: 1,
      completed: 1,
    });
    expect(fixtureLookup).toHaveBeenCalledWith({
      where: {
        action: "staging.synthetic_member.created",
        targetType: "synthetic_member_fixture",
        targetId: fixtureId,
        outcome: "created",
      },
      select: { redactedMetadata: true },
    });
    expect(accountDeletionRequest.findMany).toHaveBeenCalledWith({
      where: { accountId, status: { in: ["REQUESTED", "PROCESSING"] } },
      orderBy: { requestedAt: "asc" },
      take: 10,
    });
    expect(storage.deleteMemberMediaFile).not.toHaveBeenCalled();
  });

  it("refuses an unregistered synthetic fixture without querying deletion requests", async () => {
    const fixtureId = "f10e1c2a-4b5d-4e6f-8a90-123456789abc";
    const accountDeletionRequest = { findMany: vi.fn() };
    const tx = {
      auditEvent: { findFirst: vi.fn().mockResolvedValue(null) },
      accountDeletionRequest,
    };
    const prisma = {
      withSystemAdminIdentity: vi.fn(async (operation: (tx: any) => Promise<unknown>) => operation(tx)),
    };
    const worker = new ComplaintEvidenceRetentionWorker(
      prisma as unknown as PrismaService,
      {} as GoogleDriveStorageService,
    );

    await expect(worker.runAccountDeletionOnce(fixtureId)).rejects.toThrow(
      "The requested synthetic fixture is not registered or its marker is invalid.",
    );
    expect(accountDeletionRequest.findMany).not.toHaveBeenCalled();
  });

});
