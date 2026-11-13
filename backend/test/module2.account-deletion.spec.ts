import { beforeEach, describe, expect, it, vi } from "vitest";
import { AuthenticationService } from "../src/auth/auth.service.js";
import { PrismaService } from "../src/database/prisma.service.js";
import { Module2Service } from "../src/module2/module2.service.js";

const accountId = "2f6f7fa1-8c5c-4bb0-ae1a-0f7e3a2e5a41";
const requestId = "4b1f7f84-2f0d-4f39-8bd9-73ac2a7763a1";
const requestedAt = new Date("2026-10-18T00:00:00.000Z");
const emptyDelegate = () => ({
  deleteMany: vi.fn().mockResolvedValue({ count: 0 }),
  updateMany: vi.fn().mockResolvedValue({ count: 0 }),
});

describe("Module2Service account deletion request", () => {
  let service: Module2Service;
  let prisma: Record<string, any>;
  let tx: Record<string, any>;

  beforeEach(() => {
    tx = {
      accountDeletionRequest: {
        findFirst: vi.fn().mockResolvedValue(null),
        create: vi.fn().mockResolvedValue({ id: requestId, status: "REQUESTED", requestedAt }),
      },
      memberAccount: { update: vi.fn().mockResolvedValue({}) },
      memberProfile: { update: vi.fn().mockResolvedValue({}) },
      communityPost: { updateMany: vi.fn().mockResolvedValue({ count: 0 }) },
      communityPostComment: { ...emptyDelegate() },
      communityPostLike: emptyDelegate(),
      communityPostSave: emptyDelegate(),
      communityPostReaction: emptyDelegate(),
      memberFollow: emptyDelegate(),
      memberPrivacyPreference: emptyDelegate(),
      memberNotificationPreference: emptyDelegate(),
      memberCommunicationPreference: emptyDelegate(),
      memberWellnessPreference: emptyDelegate(),
      memberPushToken: emptyDelegate(),
      memberNotification: emptyDelegate(),
      memberModerationBlock: emptyDelegate(),
      communityCircleMembership: emptyDelegate(),
      communityCirclePost: { updateMany: vi.fn().mockResolvedValue({ count: 0 }) },
      directMessage: emptyDelegate(),
      safetyEmergencyContact: emptyDelegate(),
      safetySosEvent: emptyDelegate(),
      safetyLocationShare: emptyDelegate(),
      menstrualCycleLog: emptyDelegate(),
      menstrualDailyLog: emptyDelegate(),
      menstrualTrackerPreference: emptyDelegate(),
      eligibilitySubmission: emptyDelegate(),
      memberUserReport: { updateMany: vi.fn().mockResolvedValue({ count: 0 }) },
      businessReport: { updateMany: vi.fn().mockResolvedValue({ count: 0 }) },
      businessEnquiry: emptyDelegate(),
      businessDirectoryListing: emptyDelegate(),
      communityGroup: emptyDelegate(),
      mediaAsset: { updateMany: vi.fn().mockResolvedValue({ count: 2 }) },
      discreetComplaint: { updateMany: vi.fn().mockResolvedValue({ count: 0 }) },
      authSession: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
      auditEvent: { createMany: vi.fn().mockResolvedValue({ count: 1 }) },
    };

    const auth = {
      authenticateAuthorization: vi.fn().mockResolvedValue({
        id: "session-1",
        accountId,
        account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
      }),
    };
    prisma = {
      $transaction: vi.fn(async (operation: (tx: Record<string, any>) => Promise<unknown>) => operation(tx)),
    };
    service = new Module2Service(auth as unknown as AuthenticationService, prisma as unknown as PrismaService);
  });

  it("deactivates and scrubs the account, revokes sessions and queues Drive media purge", async () => {
    await expect(service.requestAccountDeletion("Bearer test-token", { confirmation: "DELETE" })).resolves.toMatchObject({
      requestId,
      status: "REQUESTED",
      requestedAt: requestedAt.toISOString(),
      externalMediaPurgePending: true,
    });

    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(tx.accountDeletionRequest.create).toHaveBeenCalledWith({
      data: { accountId, status: "REQUESTED", requestReason: null },
    });
    expect(tx.memberAccount.update).toHaveBeenCalledWith({
      where: { id: accountId },
      data: expect.objectContaining({ status: "DELETED", phoneVerifiedAt: null, verificationStatus: "REJECTED" }),
    });
    expect(tx.memberProfile.update).toHaveBeenCalledWith({
      where: { accountId },
      data: expect.objectContaining({
        displayName: "Deleted member", email: null, profilePhotoRef: null,
        username: null, bio: "", location: "", avatarAsset: "assets/images/profile/default_avatar.webp",
        businessProfileUrl: null, businessProfileName: null, businessCategory: null,
        dateOfBirth: new Date("1970-01-01T00:00:00.000Z"), twoFactorEnabled: false,
        securityPinUpdatedAt: null, interests: [],
      }),
    });
    expect(tx.communityPost.updateMany).toHaveBeenCalled();
    expect(tx.directMessage.deleteMany).toHaveBeenCalledWith({
      where: { OR: [{ senderAccountId: accountId }, { recipientAccountId: accountId }] },
    });
    expect(tx.mediaAsset.updateMany).toHaveBeenCalledWith({
      where: { ownerAccountId: accountId, deletedAt: null },
      data: expect.objectContaining({ status: "PENDING_PURGE", deletedAt: expect.any(Date) }),
    });
    expect(tx.discreetComplaint.updateMany).toHaveBeenCalledWith({
      where: { confidentialAccountId: accountId }, data: { confidentialAccountId: null },
    });
    expect(tx.authSession.updateMany).toHaveBeenCalledWith({
      where: { accountId, revokedAt: null }, data: { revokedAt: expect.any(Date) },
    });
    expect(tx.auditEvent.createMany).toHaveBeenCalledWith({
      data: [expect.objectContaining({
        actorType: "MEMBER", actorId: accountId, action: "module2.account.deletion_requested",
        targetType: "account_deletion_request", targetId: requestId, outcome: "requested",
        redactedMetadata: { accountErasure: true, externalMediaPurgePending: true },
      })],
    });
  });
});
