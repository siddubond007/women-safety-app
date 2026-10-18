import { beforeEach, describe, expect, it, vi } from "vitest";
import { AuthenticationService } from "../src/auth/auth.service.js";
import { PrismaService } from "../src/database/prisma.service.js";
import { Module2Service } from "../src/module2/module2.service.js";

const accountId = "2f6f7fa1-8c5c-4bb0-ae1a-0f7e3a2e5a41";
const requestId = "4b1f7f84-2f0d-4f39-8bd9-73ac2a7763a1";
const requestedAt = new Date("2026-10-18T00:00:00.000Z");

describe("Module2Service account deletion request", () => {
  let service: Module2Service;
  let prisma: Record<string, any>;
  let tx: Record<string, any>;

  beforeEach(() => {
    tx = {
      accountDeletionRequest: {
        findFirst: vi.fn().mockResolvedValue(null),
        create: vi.fn().mockResolvedValue({
          id: requestId,
          status: "REQUESTED",
          requestedAt,
        }),
      },
      memberAccount: { update: vi.fn().mockResolvedValue({}) },
      memberProfile: { update: vi.fn().mockResolvedValue({}) },
      memberPost: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
      memberPostComment: { updateMany: vi.fn().mockResolvedValue({ count: 2 }) },
      memberPostLike: { deleteMany: vi.fn().mockResolvedValue({ count: 1 }) },
      memberPostBookmark: { deleteMany: vi.fn().mockResolvedValue({ count: 1 }) },
      socialFollow: { deleteMany: vi.fn().mockResolvedValue({ count: 2 }) },
      memberBlock: { deleteMany: vi.fn().mockResolvedValue({ count: 1 }) },
      eventRegistration: { deleteMany: vi.fn().mockResolvedValue({ count: 1 }) },
      communityEvent: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
      communityGroup: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
      groupMembership: { deleteMany: vi.fn().mockResolvedValue({ count: 1 }) },
      businessProfile: { deleteMany: vi.fn().mockResolvedValue({ count: 1 }) },
      memberPrivacySettings: { deleteMany: vi.fn().mockResolvedValue({ count: 1 }) },
      memberNotificationPreferences: { deleteMany: vi.fn().mockResolvedValue({ count: 1 }) },
      memberCommunicationPreference: { deleteMany: vi.fn().mockResolvedValue({ count: 1 }) },
      authSession: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
      auditEvent: { createMany: vi.fn().mockResolvedValue({ count: 1 }) },
    };

    const auth = {
      authenticateAuthorization: vi.fn().mockResolvedValue({
        accountId,
        account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
      }),
    };
    prisma = {
      memberProfile: { findUnique: vi.fn().mockResolvedValue({ accountId }) },
      $transaction: vi.fn(async (operation: (tx: Record<string, any>) => Promise<unknown>) =>
        operation(tx),
      ),
    };

    service = new Module2Service(
      auth as unknown as AuthenticationService,
      prisma as unknown as PrismaService,
    );
  });

  it("disables access and scrubs related account data transactionally", async () => {
    await expect(
      service.requestAccountDeletion("Bearer test-token", {
        confirmation: "DELETE",
      }),
    ).resolves.toMatchObject({
      requestId,
      status: "REQUESTED",
      requestedAt: requestedAt.toISOString(),
    });

    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(tx.memberAccount.update).toHaveBeenCalledWith({
      where: { id: accountId },
      data: expect.objectContaining({
        status: "DELETED",
        phoneVerifiedAt: null,
      }),
    });
    expect(tx.memberProfile.update).toHaveBeenCalledWith({
      where: { accountId },
      data: expect.objectContaining({
        displayName: "Deleted member",
        email: null,
        profilePhotoRef: null,
        bio: null,
        locationCity: null,
        interests: [],
      }),
    });
    expect(tx.memberPost.updateMany).toHaveBeenCalled();
    expect(tx.memberPostComment.updateMany).toHaveBeenCalledTimes(2);
    expect(tx.memberPostLike.deleteMany).toHaveBeenCalled();
    expect(tx.memberPostBookmark.deleteMany).toHaveBeenCalled();
    expect(tx.socialFollow.deleteMany).toHaveBeenCalled();
    expect(tx.memberBlock.deleteMany).toHaveBeenCalled();
    expect(tx.eventRegistration.deleteMany).toHaveBeenCalled();
    expect(tx.communityEvent.updateMany).toHaveBeenCalled();
    expect(tx.communityGroup.updateMany).toHaveBeenCalled();
    expect(tx.groupMembership.deleteMany).toHaveBeenCalled();
    expect(tx.businessProfile.deleteMany).toHaveBeenCalled();
    expect(tx.memberPrivacySettings.deleteMany).toHaveBeenCalled();
    expect(tx.memberNotificationPreferences.deleteMany).toHaveBeenCalled();
    expect(tx.memberCommunicationPreference.deleteMany).toHaveBeenCalled();
    expect(tx.authSession.updateMany).toHaveBeenCalledWith({
      where: { accountId, revokedAt: null },
      data: { revokedAt: expect.any(Date) },
    });
    expect(tx.auditEvent.createMany).toHaveBeenCalledWith({
      data: expect.objectContaining({
        actorId: accountId,
        action: "module2.account.deletion_requested",
        targetId: requestId,
        outcome: "requested",
      }),
    });
  });
});
