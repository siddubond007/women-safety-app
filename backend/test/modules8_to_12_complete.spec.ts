import { afterEach, describe, expect, it, vi, beforeEach } from "vitest";
import { readFileSync } from "node:fs";
import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from "@nestjs/common";
import { Module2Service } from "../src/module2/module2.service.js";
import { AdminReviewService } from "../src/admin-review/admin-review.service.js";
import { StagingTestAdminService } from "../src/staging-test-admin/staging-test-admin.service.js";
import type { PrismaService } from "../src/database/prisma.service.js";

const VIEWER_ID = "11111111-1111-4111-8111-111111111111";
const PEER_ID = "22222222-2222-4222-8222-222222222222";
const UPLOAD_ID = "33333333-3333-4333-8333-333333333333";
const REPORT_ID = "44444444-4444-4444-8444-444444444444";
const NOTIF_ID = "55555555-5555-4555-8555-555555555555";
const REVIEWER_TOKEN = "staff-admin.unit-test-super-admin-session";

function createMockContext() {
  const blocks: Array<{
    id: string;
    accountId: string;
    blockedUsername: string;
    blockedDisplayName: string;
  }> = [];
  const directMessages: Array<Record<string, any>> = [];
  const notifications: Array<Record<string, any>> = [];
  const reports: Array<Record<string, any>> = [
    {
      id: REPORT_ID,
      reporterAccountId: VIEWER_ID,
      targetHandle: "@peer_user",
      targetType: "POST",
      postId: "66666666-6666-4666-8666-666666666666",
      category: "HARASSMENT",
      reason: "Abusive comment",
      status: "SUBMITTED",
      priority: "P2_NORMAL",
      severity: "S2_MEDIUM",
      internalNotes: [],
      evidenceUrls: [],
      createdAt: new Date(),
      updatedAt: new Date(),
    },
  ];

  const auth = {
    authenticateAuthorization: vi.fn().mockResolvedValue({
      accountId: VIEWER_ID,
      account: {
        id: VIEWER_ID,
        status: "ACTIVE",
        verificationStatus: "VERIFIED",
      },
    }),
  };

  const prisma = {
    memberProfile: {
      findUnique: vi.fn().mockImplementation(({ where }) => {
        if (where.accountId === VIEWER_ID) {
          return Promise.resolve({
            accountId: VIEWER_ID,
            displayName: "Ananya Sharma",
            username: "@ananya",
            avatarAsset: "",
            avatarMediaAssetId: null,
          });
        }
        if (where.accountId === PEER_ID) {
          return Promise.resolve({
            accountId: PEER_ID,
            displayName: "Peer Member",
            username: "@peer_user",
            account: {
              id: PEER_ID,
              status: "ACTIVE",
              verificationStatus: "VERIFIED",
              privacyPreference: {
                messageMe: "Verified members only",
                restrictedHandles: [],
              },
            },
          });
        }
        return Promise.resolve(null);
      }),
      findFirst: vi.fn().mockResolvedValue({
        accountId: PEER_ID,
        displayName: "Peer Member",
        username: "@peer_user",
        account: {
          id: PEER_ID,
          status: "ACTIVE",
          verificationStatus: "VERIFIED",
          privacyPreference: {
            messageMe: "Verified members only",
            restrictedHandles: [],
          },
        },
      }),
      findMany: vi.fn().mockResolvedValue([]),
    },
    communityDirectoryProfile: {
      findUnique: vi.fn().mockResolvedValue(null),
      findFirst: vi.fn().mockResolvedValue({
        id: "77777777-7777-4777-8777-777777777777",
        username: "@peer_user",
      }),
      findMany: vi.fn().mockResolvedValue([]),
    },
    memberModerationBlock: {
      findUnique: vi.fn().mockImplementation(({ where }) => {
        const key = where.accountId_blockedUsername;
        const found = blocks.find(
          (b) =>
            b.accountId === key?.accountId &&
            b.blockedUsername.toLowerCase() ===
              String(key?.blockedUsername ?? "").toLowerCase(),
        );
        return Promise.resolve(found ?? null);
      }),
      findFirst: vi.fn().mockImplementation(({ where }) => {
        const variants: string[] = where.blockedUsername?.in ?? [];
        const lowerSet = new Set(variants.map((v) => v.toLowerCase()));
        const found = blocks.find(
          (b) =>
            b.accountId === where.accountId &&
            lowerSet.has(b.blockedUsername.toLowerCase()),
        );
        return Promise.resolve(found ?? null);
      }),
      findMany: vi.fn().mockImplementation(({ where }) => {
        return Promise.resolve(
          blocks.filter((b) => b.accountId === where.accountId),
        );
      }),
      create: vi.fn().mockImplementation(({ data }) => {
        const row = {
          id: `blk_${blocks.length + 1}`,
          accountId: data.accountId,
          blockedUsername: data.blockedUsername,
          blockedDisplayName: data.blockedDisplayName,
          createdAt: new Date(),
        };
        blocks.push(row);
        return Promise.resolve(row);
      }),
      delete: vi.fn().mockImplementation(({ where }) => {
        const idx = blocks.findIndex((b) => b.id === where.id);
        if (idx >= 0) blocks.splice(idx, 1);
        return Promise.resolve({ id: where.id });
      }),
      deleteMany: vi.fn().mockResolvedValue({ count: 0 }),
    },
    memberFollow: {
      findUnique: vi.fn().mockResolvedValue({ isFollowing: true }),
      findMany: vi.fn().mockResolvedValue([]),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
    },
    memberPrivacyPreference: {
      findUnique: vi.fn().mockResolvedValue({
        accountId: VIEWER_ID,
        mutedHandles: [],
        restrictedHandles: [],
        hiddenPostIds: [],
      }),
      upsert: vi.fn().mockImplementation(({ create, update }) =>
        Promise.resolve({ accountId: VIEWER_ID, ...create, ...update }),
      ),
    },
    memberNotificationPreference: {
      findUnique: vi.fn().mockResolvedValue({
        accountId: VIEWER_ID,
        messages: true,
        businessEnquiries: true,
        wellnessReminders: true,
        safetyAlerts: true,
        communityUpdates: true,
      }),
    },
    memberNotification: {
      upsert: vi.fn().mockImplementation(({ where, create, update }) => {
        const existingIdx = notifications.findIndex(
          (n) => n.idempotencyKey === where.idempotencyKey,
        );
        if (existingIdx >= 0) {
          notifications[existingIdx] = {
            ...notifications[existingIdx],
            ...update,
          };
          return Promise.resolve(notifications[existingIdx]);
        }
        const row = { ...create, createdAt: create.createdAt ?? new Date() };
        notifications.push(row);
        return Promise.resolve(row);
      }),
      create: vi.fn().mockImplementation(({ data }) => {
        const row = { ...data, createdAt: data.createdAt ?? new Date() };
        notifications.push(row);
        return Promise.resolve(row);
      }),
      findFirst: vi.fn().mockImplementation(({ where }) => {
        const orList: Array<Record<string, any>> = where.OR ?? [];
        const match = notifications.find((n) => {
          if (where.accountId && n.accountId !== where.accountId) return false;
          if (where.idempotencyKey) {
            return n.idempotencyKey === where.idempotencyKey;
          }
          return orList.some(
            (cond) =>
              (cond.id && n.id === cond.id) ||
              (cond.idempotencyKey && n.idempotencyKey === cond.idempotencyKey),
          );
        });
        return Promise.resolve(match ?? null);
      }),
      findMany: vi.fn().mockImplementation(({ where, skip = 0, take = 25 }) => {
        const list = notifications.filter((n) => {
          if (where.accountId && n.accountId !== where.accountId) return false;
          if (where.isRead !== undefined && n.isRead !== where.isRead) {
            return false;
          }
          if (where.category && n.category !== where.category) return false;
          return true;
        });
        return Promise.resolve(list.slice(skip, skip + take));
      }),
      count: vi.fn().mockImplementation(({ where }) => {
        const list = notifications.filter((n) => {
          if (where.accountId && n.accountId !== where.accountId) return false;
          if (where.isRead !== undefined && n.isRead !== where.isRead) {
            return false;
          }
          if (where.category && n.category !== where.category) return false;
          return true;
        });
        return Promise.resolve(list.length);
      }),
      update: vi.fn().mockImplementation(({ where, data }) => {
        const idx = notifications.findIndex((n) => n.id === where.id);
        if (idx < 0) throw new Error("Not found");
        notifications[idx] = { ...notifications[idx], ...data };
        return Promise.resolve(notifications[idx]);
      }),
      updateMany: vi.fn().mockImplementation(({ where, data }) => {
        let count = 0;
        for (const n of notifications) {
          if (n.accountId === where.accountId && !n.isRead) {
            Object.assign(n, data);
            count++;
          }
        }
        return Promise.resolve({ count });
      }),
      delete: vi.fn().mockImplementation(({ where }) => {
        const idx = notifications.findIndex((n) => n.id === where.id);
        if (idx < 0) throw new Error("Not found");
        const [removed] = notifications.splice(idx, 1);
        return Promise.resolve(removed);
      }),
    },
    directMessage: {
      findFirst: vi.fn().mockImplementation(({ where }) => {
        const found = where.mediaUploadId
          ? directMessages.find((m) => m.mediaUploadId === where.mediaUploadId)
          : where.OR
            ? directMessages.find((m) =>
                where.OR.some((clause: Record<string, unknown>) =>
                  Object.entries(clause).every(([key, value]) => m[key] === value),
                ),
              )
            : directMessages.find(
                (m) =>
                  m.senderAccountId === where.senderAccountId &&
                  m.clientMessageId === where.clientMessageId,
              );
        return Promise.resolve(found ?? null);
      }),
      findMany: vi.fn().mockImplementation(() => Promise.resolve(directMessages)),
      create: vi.fn().mockImplementation(({ data }) => {
        const row = {
          requestStatus: "ACCEPTED",
          readAt: null,
          attachmentUrl: null,
          attachmentType: null,
          mediaUploadId: null,
          clientMessageId: null,
          ...data,
        };
        directMessages.push(row);
        return Promise.resolve(row);
      }),
      updateMany: vi.fn().mockImplementation(({ where, data }) => {
        let count = 0;
        for (const m of directMessages) {
          if (
            m.senderAccountId === where.senderAccountId &&
            m.recipientAccountId === where.recipientAccountId
          ) {
            Object.assign(m, data);
            count++;
          }
        }
        return Promise.resolve({ count });
      }),
    },
    mediaAsset: {
      findUnique: vi.fn().mockImplementation(({ where }) => {
        if (where.id === UPLOAD_ID) {
          return Promise.resolve({
            id: UPLOAD_ID,
            ownerAccountId: VIEWER_ID,
            contentType: "image/jpeg",
            byteSize: 204800,
            driveFileId: "inline-db-1",
            purpose: "DIRECT_MESSAGE_IMAGE",
            postId: null,
            visibility: "PRIVATE_SELF",
            status: "UPLOADED",
          });
        }
        return Promise.resolve(null);
      }),
    },
    memberUserReport: {
      findUnique: vi.fn().mockImplementation(({ where }) => {
        return Promise.resolve(
          reports.find((r) => r.id === where.id) ?? null,
        );
      }),
      findMany: vi.fn().mockImplementation(() => Promise.resolve(reports)),
      count: vi.fn().mockResolvedValue(1),
      create: vi.fn().mockImplementation(({ data }) => {
        const row = {
          id: `rep_${reports.length + 1}`,
          createdAt: new Date(),
          updatedAt: new Date(),
          ...data,
        };
        reports.push(row);
        return Promise.resolve(row);
      }),
      update: vi.fn().mockImplementation(({ where, data }) => {
        const idx = reports.findIndex((r) => r.id === where.id);
        if (idx < 0) throw new Error("Report not found");
        reports[idx] = { ...reports[idx], ...data, updatedAt: new Date() };
        return Promise.resolve(reports[idx]);
      }),
    },
    wellnessResource: {
      findFirst: vi.fn().mockResolvedValue(null),
      delete: vi.fn().mockRejectedValue(new Error("Record does not exist")),
    },
    auditEvent: {
      findFirst: vi.fn().mockImplementation(({ where }) =>
        where.action === "module2.media.uploaded" && where.targetId === UPLOAD_ID
          ? Promise.resolve({
              id: "audit_upload_1",
              actorId: VIEWER_ID,
              targetId: UPLOAD_ID,
              action: "module2.media.uploaded",
            })
          : Promise.resolve(null),
      ),
      findMany: vi.fn().mockResolvedValue([]),
      create: vi.fn().mockResolvedValue({ id: "audit_1" }),
    },
  };

  // The real Prisma helper opens a transaction and sets a narrowly scoped
  // recipient identity. This unit fixture delegates the callback to its in-memory
  // model; the database/RLS boundary is covered by separate integration tests.
  (prisma as any).withNotificationRecipientIdentity = vi.fn(
    async (_recipientAccountId: string, operation: (tx: any) => Promise<unknown>) =>
      operation(prisma),
  );

  // This callback mock exercises the transaction boundary and delegates used by
  // triageReport. It does not emulate database rollback semantics.
  (prisma as any).$transaction = vi.fn(
    async (callback: (tx: any) => Promise<unknown>, _options?: unknown) =>
      callback({
        memberUserReport: prisma.memberUserReport,
        auditEvent: prisma.auditEvent,
      }),
  );

  return {
    auth,
    prisma: prisma as unknown as PrismaService,
    blocks,
    directMessages,
    notifications,
    reports,
  };
}

describe("Sakhi Modules 8–12 Repair & Hardening Regression Suite", () => {
  beforeEach(() => {
    process.env.SAKHI_ENV = "test";
    process.env.NODE_ENV = "test";
    const originalResolve = StagingTestAdminService.resolvePrincipalFromSessionToken;
    vi.spyOn(StagingTestAdminService, "resolvePrincipalFromSessionToken").mockImplementation(
      (token?: string) => {
        if (token !== REVIEWER_TOKEN) return originalResolve(token);
        return {
          staffId: "00000000-0000-4000-8000-000000000001",
          staffCode: "#SA-TEST",
          reviewerLabel: "QA Safety Reviewer",
          fullName: "QA Safety Reviewer",
          email: "qa.safety@example.test",
          role: "SUPER_ADMIN",
          roleTitle: "Super Admin",
          badgeLabel: "Super Admin",
          clearanceLevel: "LEVEL_4_MASTER_GOVERNANCE",
          isAuthorisedComplaintReviewer: true,
          permissions: { view: true, create: true, edit: true, approve: true, suspend: true, export: true, delete: true },
          allowedRoutes: [],
        } as any;
      },
    );
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("Section 4.1: respondToMessageRequest with BLOCK is strictly idempotent and never unblocks on repeated calls", async () => {
    const ctx = createMockContext();
    const service = new Module2Service(ctx.auth as any, ctx.prisma);

    const first = await service.respondToMessageRequest(
      "Bearer valid-token",
      "@peer_user",
      "BLOCK",
    );
    expect(first.requestStatus).toBe("BLOCKED");
    expect(first.blocked?.isBlocked).toBe(true);
    expect(ctx.blocks).toHaveLength(1);

    // A second BLOCK request must preserve the block rather than toggling it off
    const second = await service.respondToMessageRequest(
      "Bearer valid-token",
      "@peer_user",
      "BLOCK",
    );
    expect(second.requestStatus).toBe("BLOCKED");
    expect(second.blocked?.isBlocked).toBe(true);
    expect(ctx.blocks).toHaveLength(1);
  });

  it("Sections 4.2, 4.3 & 4.4: persists direct message attachments, clientMessageId deduplication, requestStatus, and readAt in PostgreSQL", async () => {
    const ctx = createMockContext();
    const service = new Module2Service(ctx.auth as any, ctx.prisma);

    const sendRes = await service.sendDirectMessage("Bearer valid-token", {
      recipientHandle: "@peer_user",
      message: "Sharing product photo",
      mediaUploadId: UPLOAD_ID,
      attachmentType: "image/jpeg",
      clientMessageId: "client_msg_001",
    });

    expect(sendRes.sent).toBe(true);
    expect(ctx.directMessages).toHaveLength(1);
    expect(ctx.directMessages[0]!.attachmentUrl).toBe(
      `/api/v1/module2/media/object/${UPLOAD_ID}`,
    );
    expect(ctx.directMessages[0]!.mediaUploadId).toBe(UPLOAD_ID);
    expect(ctx.directMessages[0]!.clientMessageId).toBe("client_msg_001");

    // Retry with the same clientMessageId must deduplicate via PostgreSQL lookup
    const retryRes = await service.sendDirectMessage("Bearer valid-token", {
      recipientHandle: "@peer_user",
      message: "Sharing product photo",
      mediaUploadId: UPLOAD_ID,
      clientMessageId: "client_msg_001",
    });
    expect(retryRes.deduplicated).toBe(true);
    expect(ctx.directMessages).toHaveLength(1);

    // A private upload is single-use and cannot be attached to another message.
    await expect(
      service.sendDirectMessage("Bearer valid-token", {
        recipientHandle: "@peer_user",
        message: "Try to reuse the same upload",
        mediaUploadId: UPLOAD_ID,
        clientMessageId: "client_msg_002",
      }),
    ).rejects.toThrow(BadRequestException);
    expect(ctx.directMessages).toHaveLength(1);

    // Rejects arbitrary external attachment URLs
    await expect(
      service.sendDirectMessage("Bearer valid-token", {
        recipientHandle: "@peer_user",
        message: "Bad link",
        attachmentUrl: "https://evil.example.com/phish.jpg",
      }),
    ).rejects.toThrow(BadRequestException);

    // Rejects cross-account attachment uploads
    const crossAccountUploadId = "99999999-9999-4999-8999-999999999999";
    (ctx.prisma.mediaAsset.findUnique as any).mockResolvedValueOnce({
      id: crossAccountUploadId,
      ownerAccountId: PEER_ID,
      contentType: "image/jpeg",
      byteSize: 1024,
      purpose: "DIRECT_MESSAGE_IMAGE",
      postId: null,
      visibility: "PRIVATE_SELF",
      status: "UPLOADED",
    });
    (ctx.prisma.auditEvent.findFirst as any).mockResolvedValueOnce({
      id: "audit_cross_account_upload",
      actorId: PEER_ID,
      targetId: crossAccountUploadId,
      action: "module2.media.uploaded",
    });
    await expect(
      service.sendDirectMessage("Bearer valid-token", {
        recipientHandle: "@peer_user",
        message: "Stolen media",
        mediaUploadId: crossAccountUploadId,
      }),
    ).rejects.toThrow(ForbiddenException);
  });

  it("Section 5: persists notifications in member_notifications and enforces account ownership on read/delete", async () => {
    const ctx = createMockContext();
    const service = new Module2Service(ctx.auth as any, ctx.prisma);

    await service.createPersistentNotification(VIEWER_ID, {
      id: NOTIF_ID,
      idempotencyKey: "test:notif:1",
      category: "DIRECT_MESSAGE",
      title: "New message",
      body: "Hello from Ananya",
    });
    expect(ctx.notifications).toHaveLength(1);

    // Idempotent duplicate key does not create a second row
    await service.createPersistentNotification(VIEWER_ID, {
      idempotencyKey: "test:notif:1",
      category: "DIRECT_MESSAGE",
      title: "New message",
      body: "Hello from Ananya",
    });
    expect(ctx.notifications).toHaveLength(1);

    // Marking read persists in PostgreSQL
    const readRes = await service.markNotificationRead(
      "Bearer valid-token",
      NOTIF_ID,
    );
    expect(readRes.isRead).toBe(true);
    expect(ctx.notifications[0]!.isRead).toBe(true);

    // Accessing an unknown / another user's notification throws NotFoundException
    await expect(
      service.markNotificationRead("Bearer valid-token", "non-existent-id"),
    ).rejects.toThrow(NotFoundException);

    const delRes = await service.deleteNotification(
      "Bearer valid-token",
      NOTIF_ID,
    );
    expect(delRes.deleted).toBe(true);
    expect(ctx.notifications).toHaveLength(0);
  });

  it("Sections 6 & 7: persists report triage in PostgreSQL, rejects missing evidence preview with NotFoundException, and validates wellness resource deletion", async () => {
    const ctx = createMockContext();
    const adminService = new AdminReviewService(ctx.prisma);

    const triaged = await adminService.triageReport(
      REPORT_ID,
      {
        priority: "P0_CRITICAL",
        severity: "S1_CRITICAL",
        assignedReviewerId: "rev_01",
        assignedReviewerName: "Senior Safety Lead",
        appealStatus: "UNDER_APPEAL",
        appealReason: "Requested secondary review",
        internalNote: "Escalated due to repeat harassment reports.",
      },
      REVIEWER_TOKEN,
    );

    expect(triaged.priority).toBe("P0_CRITICAL");
    expect(triaged.severity).toBe("S1_CRITICAL");
    expect(triaged.assignedReviewerName).toBe("Senior Safety Lead");
    expect(triaged.internalNotes).toHaveLength(1);
    expect(ctx.reports[0]!.priority).toBe("P0_CRITICAL");
    expect(ctx.reports[0]!.severity).toBe("S1_CRITICAL");
    expect(ctx.reports[0]!.assignedReviewerName).toBe("Senior Safety Lead");
    expect(ctx.reports[0]!.appealStatus).toBe("UNDER_APPEAL");
    expect(ctx.reports[0]!.appealReason).toBe("Requested secondary review");
    expect(ctx.reports[0]!.internalNotes).toHaveLength(1);
    expect(ctx.reports[0]!.internalNotes[0]).toEqual(
      expect.objectContaining({
        author: "QA Safety Reviewer",
        note: "Escalated due to repeat harassment reports.",
      }),
    );
    expect((ctx.prisma as any).$transaction).toHaveBeenCalledWith(
      expect.any(Function),
      { isolationLevel: "Serializable" },
    );
    expect((ctx.prisma as any).auditEvent.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        actorId: "00000000-0000-4000-8000-000000000001",
        action: "admin.report.triaged",
        targetId: REPORT_ID,
        redactedMetadata: expect.objectContaining({ notesCount: 1 }),
      }),
    });

    // Missing evidence must throw NotFoundException instead of returning a fake SVG
    await expect(
      adminService.previewReportedMedia("missing-upload-id", REVIEWER_TOKEN),
    ).rejects.toThrow(NotFoundException);

    // A database lookup failure must not be misreported as missing evidence.
    const lookupFailureContext = createMockContext();
    (lookupFailureContext.prisma as any).mediaAsset.findUnique.mockRejectedValueOnce(
      new Error("media database unavailable"),
    );
    const lookupFailureService = new AdminReviewService(lookupFailureContext.prisma);
    await expect(
      lookupFailureService.previewReportedMedia(UPLOAD_ID, REVIEWER_TOKEN),
    ).rejects.toThrow("media database unavailable");

    // Evidence must not be returned when its required audit record cannot be written.
    const auditFailureContext = createMockContext();
    (auditFailureContext.prisma as any).auditEvent.create.mockRejectedValueOnce(
      new Error("preview audit unavailable"),
    );
    const auditFailureService = new AdminReviewService(auditFailureContext.prisma);
    await expect(
      auditFailureService.previewReportedMedia(UPLOAD_ID, REVIEWER_TOKEN),
    ).rejects.toThrow("preview audit unavailable");

    // Deleting a non-existent wellness resource must throw NotFoundException
    await expect(
      adminService.deleteWellnessResource("missing-resource-id", REVIEWER_TOKEN),
    ).rejects.toThrow(NotFoundException);
  });
});

describe("Modules 8–12 migration rollback contract", () => {
  it("revokes only the migration-added menstrual runtime grants and restores Module 7 RLS state", () => {
    const rollback = readFileSync(
      new URL(
        "../prisma/migrations/20261106010000_modules8_9_10_11_12_complete/rollback.sql",
        import.meta.url,
      ),
      "utf8",
    );

    expect(rollback).toContain(
      "REVOKE SELECT, INSERT, UPDATE, DELETE ON TABLE public.menstrual_cycle_logs, public.menstrual_daily_logs, public.menstrual_tracker_preferences",
    );
    expect(rollback).toContain(
      "ARRAY['sakhi_dev_app', 'sakhi_test_app', 'sakhi_staging_app']",
    );
    expect(rollback).toContain(
      'ALTER TABLE "menstrual_cycle_logs" DISABLE ROW LEVEL SECURITY;',
    );
    expect(rollback).toContain(
      'ALTER TABLE "menstrual_daily_logs" DISABLE ROW LEVEL SECURITY;',
    );
    expect(rollback).toContain(
      'ALTER TABLE "menstrual_tracker_preferences" DISABLE ROW LEVEL SECURITY;',
    );
  });
});
