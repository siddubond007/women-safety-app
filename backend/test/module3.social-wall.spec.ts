import { createHash } from "node:crypto";
import { BadRequestException, ForbiddenException, NotFoundException } from "@nestjs/common";
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
  const accountId = "11111111-2222-4333-8444-555555555555";
  const sessionId = "22222222-3333-4444-8555-666666666666";
  const uploadId = "a1111111-2222-4333-8444-555555555555";
  const createdAt = new Date("2026-10-20T09:00:00.000Z");
  const savedPost = {
    id: "b2222222-3333-4444-8555-666666666666",
    authorAccountId: accountId,
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
    memberProfile: {
      findUnique: vi.fn().mockResolvedValue({
        displayName: "Test Member",
        username: "@test_member",
        avatarAsset: "assets/images/profile/avatar_siddhu.webp",
        isVerified: true,
      }),
    },
    mediaAsset: {
      findMany: vi.fn().mockResolvedValue([{ id: uploadId }]),
      findUnique: vi.fn().mockResolvedValue({ contentType: "image/jpeg" }),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
    },
    communityPost: {
      findUnique: vi.fn().mockResolvedValue(null),
      create: vi.fn().mockResolvedValue(savedPost),
    },
    auditEvent: { createMany: vi.fn().mockResolvedValue({ count: 1 }) },
  };
  const auth = {
    authenticateAuthorization: vi.fn().mockResolvedValue({
      id: sessionId,
      accountId,
      account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
    }),
  };
  const prisma = {
    withMemberIdentity: vi.fn(
      async (_identity: unknown, work: (client: typeof tx) => Promise<unknown>) => work(tx),
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
        ownerAccountId: accountId,
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
  const accountId = "11111111-2222-4333-8444-555555555555";
  const sessionId = "22222222-3333-4444-8555-666666666666";
  const uploadId = "a1111111-2222-4333-8444-555555555555";
  const tx = {
    memberProfile: {
      findUnique: vi.fn().mockResolvedValue({
        displayName: "Test Member",
        username: "@test_member",
        avatarAsset: "assets/images/profile/avatar_siddhu.webp",
        isVerified: true,
      }),
    },
    mediaAsset: {
      findMany: vi.fn().mockResolvedValue([]),
      findUnique: vi.fn().mockResolvedValue(null),
      updateMany: vi.fn().mockResolvedValue({ count: 0 }),
    },
    communityPost: { findUnique: vi.fn().mockResolvedValue(null), create: vi.fn() },
    auditEvent: { createMany: vi.fn() },
  };
  const auth = {
    authenticateAuthorization: vi.fn().mockResolvedValue({
      id: sessionId,
      accountId,
      account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
    }),
  };
  const prisma = {
    withMemberIdentity: vi.fn(
      async (_identity: unknown, work: (client: typeof tx) => Promise<unknown>) => work(tx),
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
  const viewerId = "33333333-4444-4555-8666-777777777777";
  const ownerId = "44444444-5555-4666-8777-888888888888";
  const sessionId = "22222222-3333-4444-8555-666666666666";
  const uploadId = "a1111111-2222-4333-8444-555555555555";
  const auth = {
    authenticateAuthorization: vi.fn().mockResolvedValue({
      id: sessionId,
      accountId: viewerId,
      account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
    }),
  };
  const tx = {
    mediaAsset: {
      findUnique: vi.fn().mockResolvedValue({
        id: uploadId,
        ownerAccountId: ownerId,
        postId: null,
        purpose: "PROFILE_PHOTO",
        status: "ATTACHED",
        visibility: "PRIVATE_SELF",
        deletedAt: null,
        driveFileId: "private-drive-file",
        contentType: "image/png",
        storageProvider: "GOOGLE_DRIVE",
        sha256Checksum: "a".repeat(64),
        byteSize: 3,
      }),
    },
    directMessage: { findFirst: vi.fn().mockResolvedValue(null) },
    communityPost: { findUnique: vi.fn().mockResolvedValue(null) },
    communityDirectoryProfile: { findUnique: vi.fn().mockResolvedValue(null) },
    memberFollow: { findUnique: vi.fn().mockResolvedValue(null) },
  };
  const prisma = {
    withMemberIdentity: vi.fn(
      async (_identity: unknown, work: (client: typeof tx) => Promise<unknown>) => work(tx),
    ),
  };
  const drive = { downloadMemberMediaFile: vi.fn() };
  const service = new Module2Service(
    auth as unknown as AuthenticationService,
    prisma as unknown as PrismaService,
    drive as unknown as GoogleDriveStorageService,
  );

  await expect(
    service.resolveMediaObject("Bearer viewer-token", uploadId),
  ).rejects.toBeInstanceOf(ForbiddenException);
  expect(drive.downloadMemberMediaFile).not.toHaveBeenCalled();
});

it("restricts a direct-message attachment to its two participants and requires request acceptance", async () => {
  const senderId = "55555555-6666-4777-8888-999999999999";
  const recipientId = "66666666-7777-4888-8999-aaaaaaaaaaaa";
  const strangerId = "77777777-8888-4999-8aaa-bbbbbbbbbbbb";
  const sessionId = "22222222-3333-4444-8555-666666666666";
  const uploadId = "a2222222-2222-4333-8444-555555555555";
  let viewerId = recipientId;
  const auth = {
    authenticateAuthorization: vi.fn().mockImplementation(async () => ({
      id: sessionId,
      accountId: viewerId,
      account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
    })),
  };
  const directMessage = {
    senderAccountId: senderId,
    recipientAccountId: recipientId,
    requestStatus: "ACCEPTED",
  };
  const tx = {
    mediaAsset: {
      findUnique: vi.fn().mockResolvedValue({
        id: uploadId,
        ownerAccountId: senderId,
        postId: null,
        purpose: "DIRECT_MESSAGE_IMAGE",
        status: "ATTACHED",
        visibility: "PRIVATE_SELF",
        deletedAt: null,
        driveFileId: "private-dm-drive-file",
        contentType: "image/jpeg",
        storageProvider: "GOOGLE_DRIVE",
        sha256Checksum: createHash("sha256").update(Buffer.from([0xff, 0xd8, 0xff])).digest("hex"),
        byteSize: 3,
      }),
    },
    directMessage: { findFirst: vi.fn().mockResolvedValue(directMessage) },
    communityPost: { findUnique: vi.fn().mockResolvedValue(null) },
    communityDirectoryProfile: { findUnique: vi.fn().mockResolvedValue(null) },
    memberFollow: { findUnique: vi.fn().mockResolvedValue(null) },
  };
  const prisma = {
    withMemberIdentity: vi.fn(
      async (_identity: unknown, work: (client: typeof tx) => Promise<unknown>) => work(tx),
    ),
  };
  const drive = {
    downloadMemberMediaFile: vi.fn().mockResolvedValue({
      contentType: "image/jpeg",
      buffer: Buffer.from([0xff, 0xd8, 0xff]),
    }),
  };
  const service = new Module2Service(
    auth as unknown as AuthenticationService,
    prisma as unknown as PrismaService,
    drive as unknown as GoogleDriveStorageService,
  );

  const allowed = await service.resolveMediaObject("Bearer recipient-token", uploadId);
  expect(allowed.buffer).toEqual(Buffer.from([0xff, 0xd8, 0xff]));

  viewerId = strangerId;
  await expect(
    service.resolveMediaObject("Bearer stranger-token", uploadId),
  ).rejects.toBeInstanceOf(NotFoundException);
  expect(drive.downloadMemberMediaFile).toHaveBeenCalledOnce();

  viewerId = recipientId;
  tx.directMessage.findFirst.mockResolvedValueOnce({
    ...directMessage,
    requestStatus: "PENDING_REQUEST",
  });
  await expect(
    service.resolveMediaObject("Bearer recipient-token", uploadId),
  ).rejects.toBeInstanceOf(ForbiddenException);
});

it("stores direct-message uploads as private until attached to a conversation", async () => {
  const senderId = "55555555-6666-4777-8888-999999999999";
  const sessionId = "22222222-3333-4444-8555-666666666666";
  const imageBytes = Buffer.from([0xff, 0xd8, 0xff, 0xd9]);
  const auth = {
    authenticateAuthorization: vi.fn().mockResolvedValue({
      id: sessionId,
      accountId: senderId,
      account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
    }),
  };
  const auditCreateMany = vi.fn().mockResolvedValue({ count: 1 });
  const mediaAssetCreate = vi.fn().mockResolvedValue({ id: "dm-upload-1" });
  const tx = {
    auditEvent: { createMany: auditCreateMany },
    mediaAsset: {
      findUnique: vi.fn().mockResolvedValue(null),
      create: mediaAssetCreate,
    },
  };
  const drive = {
    uploadImage: vi.fn().mockResolvedValue({
      driveFileId: "private-dm-file",
      driveFolderId: "dm-folder",
      driveFolderPath: "Sakhi Media/private/direct-message",
      storedName: "private-photo.jpg",
      size: imageBytes.length,
      sha256Checksum: createHash("sha256").update(imageBytes).digest("hex"),
      reusedExisting: false,
    }),
    deleteMemberMediaFile: vi.fn().mockResolvedValue(undefined),
  };
  const prisma = {
    withMemberIdentity: vi.fn(
      async (_identity: unknown, work: (client: typeof tx) => Promise<unknown>) => work(tx),
    ),
  };
  const service = new Module2Service(
    auth as unknown as AuthenticationService,
    prisma as unknown as PrismaService,
    drive as unknown as GoogleDriveStorageService,
  );

  await service.uploadMediaFile(
    "Bearer sender-token",
    {
      originalname: "private-photo.jpg",
      mimetype: "image/jpeg",
      buffer: imageBytes,
      size: imageBytes.length,
    },
    { purpose: "direct_message", categorySlug: "direct-message" },
  );

  expect(mediaAssetCreate).toHaveBeenCalledWith(
    expect.objectContaining({
      data: expect.objectContaining({
        purpose: "DIRECT_MESSAGE_IMAGE",
        status: "UPLOADED",
        visibility: "PRIVATE_SELF",
        categorySlug: null,
        ownerAccountId: senderId,
      }),
    }),
  );
  expect(drive.uploadImage).toHaveBeenCalledWith(
    expect.objectContaining({
      purpose: "post",
      categorySlug: "direct-message",
      accountId: senderId,
    }),
  );
});

