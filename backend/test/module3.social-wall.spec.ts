import { BadRequestException, ForbiddenException } from "@nestjs/common";
import { describe, expect, it, vi } from "vitest";
import { AuthenticationService } from "../src/auth/auth.service.js";
import { PrismaService } from "../src/database/prisma.service.js";
import { GoogleDriveStorageService } from "../src/module2/google-drive-storage.service.js";
import { Module2Service } from "../src/module2/module2.service.js";

describe("Module 3 Social Wall, Google Drive Hierarchy & Reactions", () => {
  it("builds opaque per-user and per-category Google Drive folder paths", () => {
    const drive = new GoogleDriveStorageService();
    const profilePath = drive.buildMediaHierarchySegments({
      purpose: "avatar",
      accountId: "11111111-2222-4333-8444-555555555555",
    });
    expect(profilePath.displayPath).toBe(
      "Sakhi Media/users/11111111-2222-4333-8444-555555555555/profile",
    );

    const feedPath = drive.buildMediaHierarchySegments({
      purpose: "post",
      accountId: "11111111-2222-4333-8444-555555555555",
      categorySlug: "safety_awareness",
      postId: "post-uuid-01",
    });
    expect(feedPath.displayPath).toBe(
      "Sakhi Media/feeds/safety_awareness/11111111-2222-4333-8444-555555555555/post-uuid-01",
    );
  });

  it("toggles and updates 8-reaction types on a Social Wall post", async () => {
    const auth = {
      authenticateAuthorization: vi.fn().mockResolvedValue({
        accountId: "user-1",
        account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
      }),
    };
    const prisma = {
      communityPost: {
        findUnique: vi.fn().mockResolvedValue({
          id: "post-1",
          likesCount: 10,
          deletedAt: null,
        }),
        update: vi.fn().mockResolvedValue({
          id: "post-1",
          likesCount: 11,
        }),
      },
      communityPostReaction: {
        findUnique: vi.fn().mockResolvedValue(null),
        create: vi.fn().mockResolvedValue({ id: "r-1" }),
        findMany: vi.fn().mockResolvedValue([{ reactionType: "SUPPORT" }]),
      },
      communityPostLike: {
        upsert: vi.fn().mockResolvedValue({}),
      },
    };
    const service = new Module2Service(
      auth as unknown as AuthenticationService,
      prisma as unknown as PrismaService,
    );
    const res = await service.reactToPost("Bearer token", "post-1", "SUPPORT");
    expect(res.viewerReaction).toBe("SUPPORT");
    expect(res.reactionBreakdown.SUPPORT).toBe(1);
  });

  it("forbids a non-owner from deleting another member comment unless post owner", async () => {
    const auth = {
      authenticateAuthorization: vi.fn().mockResolvedValue({
        accountId: "viewer-other",
        account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
      }),
    };
    const prisma = {
      communityPostComment: {
        findUnique: vi.fn().mockResolvedValue({
          id: "comment-1",
          postId: "post-1",
          accountId: "comment-owner",
          deletedAt: null,
        }),
      },
      communityPost: {
        findUnique: vi.fn().mockResolvedValue({
          id: "post-1",
          authorAccountId: "post-owner",
        }),
      },
    };
    const service = new Module2Service(
      auth as unknown as AuthenticationService,
      prisma as unknown as PrismaService,
    );
    await expect(
      service.deletePostComment("Bearer token", "post-1", "comment-1"),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});

it("persists media-only posts and attaches the member-owned media ID with metadata", async () => {
  const uploadId = "a1111111-2222-4333-8444-555555555555";
  const createdAt = new Date("2026-10-20T09:00:00.000Z");
  const savedPost = {
    id: "b2222222-3333-4444-8555-666666666666",
    authorAccountId: "member-1",
    authorName: "Test Member",
    authorUsername: "@test_member",
    authorAvatar: "assets/images/profile/avatar_siddhu.webp",
    authorVerified: true,
    content: "",
    imageAsset: `/api/v1/module2/media/object/${uploadId}`,
    categoryBadge: "Safety Awareness",
    categorySlug: "safety_awareness",
    visibility: "VERIFIED_MEMBERS",
    cropPreset: "4:5",
    hashtags: ["#SafeCommute"],
    locationTag: "Hyderabad",
    allowComments: true,
    shareToBusinessProfile: false,
    feedSection: "community",
    status: "PUBLISHED",
    hasBreathingExerciseCard: false,
    likesCount: 0,
    commentsCount: 0,
    savesCount: 0,
    sharesCount: 0,
    createdAt,
    updatedAt: createdAt,
    deletedAt: null,
  };
  const tx = {
    mediaAsset: {
      findMany: vi.fn().mockResolvedValue([{ id: uploadId }]),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
    },
    communityPost: {
      create: vi.fn().mockResolvedValue(savedPost),
    },
    auditEvent: {
      create: vi.fn().mockResolvedValue({ id: "audit-1" }),
    },
  };
  const auth = {
    authenticateAuthorization: vi.fn().mockResolvedValue({
      accountId: "member-1",
      account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
    }),
  };
  const prisma = {
    memberProfile: {
      findUnique: vi.fn().mockResolvedValue({
        displayName: "Test Member",
        username: "@test_member",
        avatarAsset: "assets/images/profile/avatar_siddhu.webp",
      }),
    },
    $transaction: vi.fn(async (work: (client: typeof tx) => Promise<unknown>) =>
      work(tx),
    ),
  };
  const service = new Module2Service(
    auth as unknown as AuthenticationService,
    prisma as unknown as PrismaService,
  );

  const result = await service.createPost("Bearer test-token", {
    body: "",
    categoryBadge: "Safety Awareness",
    categorySlug: "safety_awareness",
    visibility: "VERIFIED_MEMBERS",
    cropPreset: "4:5",
    hashtags: ["SafeCommute"],
    locationTag: "Hyderabad",
    allowComments: true,
    shareToBusinessProfile: false,
    mediaUploadIds: [uploadId],
  });

  expect(result.id).toBe(savedPost.id);
  expect(result.imageAsset).toBe(`/api/v1/module2/media/object/${uploadId}`);
  expect(result.hashtags).toEqual(["#SafeCommute"]);
  expect(tx.communityPost.create).toHaveBeenCalledWith(
    expect.objectContaining({
      data: expect.objectContaining({
        content: "",
        categorySlug: "safety_awareness",
        visibility: "VERIFIED_MEMBERS",
        hashtags: ["#SafeCommute"],
        locationTag: "Hyderabad",
      }),
    }),
  );
  expect(tx.mediaAsset.updateMany).toHaveBeenCalledWith(
    expect.objectContaining({
      where: expect.objectContaining({
        id: { in: [uploadId] },
        ownerAccountId: "member-1",
        postId: null,
        status: "UPLOADED",
      }),
      data: expect.objectContaining({
        postId: savedPost.id,
        status: "ATTACHED",
        visibility: "VERIFIED_MEMBERS",
      }),
    }),
  );
});

it("rejects an upload ID that is not an unattached media asset owned by the caller", async () => {
  const uploadId = "a1111111-2222-4333-8444-555555555555";
  const tx = {
    mediaAsset: {
      findMany: vi.fn().mockResolvedValue([]),
      updateMany: vi.fn().mockResolvedValue({ count: 0 }),
    },
    communityPost: {
      create: vi.fn(),
    },
    auditEvent: {
      create: vi.fn(),
    },
  };
  const auth = {
    authenticateAuthorization: vi.fn().mockResolvedValue({
      accountId: "member-1",
      account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
    }),
  };
  const prisma = {
    memberProfile: {
      findUnique: vi.fn().mockResolvedValue({
        displayName: "Test Member",
        username: "@test_member",
        avatarAsset: "assets/images/profile/avatar_siddhu.webp",
      }),
    },
    $transaction: vi.fn(async (work: (client: typeof tx) => Promise<unknown>) =>
      work(tx),
    ),
  };
  const service = new Module2Service(
    auth as unknown as AuthenticationService,
    prisma as unknown as PrismaService,
  );

  await expect(
    service.createPost("Bearer test-token", {
      body: "",
      mediaUploadIds: [uploadId],
    }),
  ).rejects.toBeInstanceOf(BadRequestException);
  expect(tx.communityPost.create).not.toHaveBeenCalled();
});

it("denies an unrelated verified member access to private media before downloading it", async () => {
  const uploadId = "a1111111-2222-4333-8444-555555555555";
  const auth = {
    authenticateAuthorization: vi.fn().mockResolvedValue({
      accountId: "viewer-2",
      account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
    }),
  };
  const prisma = {
    auditEvent: {
      findFirst: vi.fn().mockResolvedValue({
        id: "audit-media-1",
        actorId: "owner-1",
        targetId: uploadId,
        action: "module2.media.uploaded",
        redactedMetadata: {
          driveFileId: "private-drive-file",
          provider: "google_drive",
          contentType: "image/png",
        },
        createdAt: new Date("2026-10-20T09:00:00.000Z"),
      }),
    },
    mediaAsset: {
      findUnique: vi.fn().mockResolvedValue({
        id: uploadId,
        ownerAccountId: "owner-1",
        postId: null,
        purpose: "PROFILE_PHOTO",
        status: "ATTACHED",
        visibility: "PRIVATE_SELF",
        deletedAt: null,
        driveFileId: "private-drive-file",
        contentType: "image/png",
        storageProvider: "GOOGLE_DRIVE",
      }),
    },
  };
  const drive = { downloadFile: vi.fn() };
  const service = new Module2Service(
    auth as unknown as AuthenticationService,
    prisma as unknown as PrismaService,
    drive as unknown as GoogleDriveStorageService,
  );

  await expect(
    service.resolveMediaObject("Bearer viewer-token", uploadId),
  ).rejects.toBeInstanceOf(ForbiddenException);
  expect(drive.downloadFile).not.toHaveBeenCalled();
});
