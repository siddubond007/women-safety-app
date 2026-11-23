import { ConflictException, ForbiddenException, NotFoundException } from "@nestjs/common";
import { createHash, randomUUID } from "node:crypto";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { Module2Service } from "../src/module2/module2.service.js";

const accountId = randomUUID();
const ownerAccountId = randomUUID();
const sessionId = randomUUID();
const uploadId = randomUUID();
const postId = randomUUID();
const imageBytes = Buffer.from([0xff, 0xd8, 0xff, 0x00]);
const sha256 = createHash("sha256").update(imageBytes).digest("hex");

describe("Module 2 community media authorization and persistence", () => {
  let tx: any;
  let prisma: any;
  let auth: any;
  let drive: any;
  let service: Module2Service;

  const memberSession = () => ({
    id: sessionId,
    accountId,
    account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
  });
  const communityAsset = (overrides: Record<string, unknown> = {}) => ({
    id: uploadId,
    ownerAccountId,
    postId,
    purpose: "COMMUNITY_POST_IMAGE",
    storageProvider: "GOOGLE_DRIVE",
    status: "ATTACHED",
    driveFileId: "drive-file-1",
    driveFolderId: "drive-folder-1",
    driveFolderPath: "Sakhi Staging Media/feeds/community/test",
    originalFileName: "test.jpg",
    contentType: "image/jpeg",
    byteSize: imageBytes.length,
    sha256Checksum: sha256,
    categorySlug: "community",
    cropAspectRatio: "4:5",
    visibility: "VERIFIED_MEMBERS",
    deletedAt: null,
    createdAt: new Date("2026-11-19T10:00:00.000Z"),
    ...overrides,
  });
  const publishedPost = (overrides: Record<string, unknown> = {}) => ({
    id: postId,
    authorAccountId: ownerAccountId,
    authorName: "Owner",
    authorUsername: "@owner",
    authorAvatar: "avatar.webp",
    authorVerified: true,
    content: "Existing post",
    imageAsset: `/api/v1/module2/media/object/${uploadId}`,
    categorySlug: "community",
    visibility: "VERIFIED_MEMBERS",
    status: "PUBLISHED",
    deletedAt: null,
    createdAt: new Date("2026-11-19T10:00:00.000Z"),
    ...overrides,
  });

  beforeEach(() => {
    tx = {
      auditEvent: { createMany: vi.fn().mockResolvedValue({ count: 1 }), findFirst: vi.fn() },
      mediaAsset: {
        findUnique: vi.fn().mockResolvedValue(null),
        findMany: vi.fn().mockResolvedValue([]),
        create: vi.fn().mockResolvedValue({}),
      },
      directMessage: { findFirst: vi.fn().mockResolvedValue(null) },
      communityPost: {
        findUnique: vi.fn().mockResolvedValue(null),
        create: vi.fn().mockResolvedValue(publishedPost()),
        updateMany: vi.fn().mockResolvedValue({ count: 0 }),
      },
      communityDirectoryProfile: {
        findUnique: vi.fn().mockResolvedValue(null),
        updateMany: vi.fn().mockResolvedValue({ count: 0 }),
      },
      memberFollow: { findUnique: vi.fn().mockResolvedValue(null) },
      memberProfile: {
        findUnique: vi.fn().mockResolvedValue(null),
        update: vi.fn().mockResolvedValue({ username: "@member" }),
      },
    };
    prisma = {
      withMemberIdentity: vi.fn(async (_identity: unknown, operation: (client: unknown) => unknown) =>
        operation(tx),
      ),
    };
    auth = {
      authenticateAuthorization: vi.fn().mockResolvedValue(memberSession()),
      hasActiveStagingTestApproval: vi.fn().mockResolvedValue(false),
    };
    drive = {
      uploadImage: vi.fn().mockResolvedValue({
        driveFileId: "drive-file-1",
        driveFolderId: "drive-folder-1",
        driveFolderPath: "Sakhi Staging Media/feeds/community/test",
        storedName: "post_test.jpg",
        size: imageBytes.length,
        sha256Checksum: sha256,
        reusedExisting: false,
      }),
      deleteMemberMediaFile: vi.fn().mockResolvedValue(undefined),
      downloadMemberMediaFile: vi.fn().mockResolvedValue({
        buffer: imageBytes,
        contentType: "image/jpeg",
      }),
    };
    service = new Module2Service(auth, prisma, drive);
  });

  it("persists upload audit and media metadata in one explicit member-identity transaction", async () => {
    const result = await service.uploadMediaFile(
      "Bearer synthetic-token",
      { originalname: "test.jpg", mimetype: "image/jpeg", buffer: imageBytes, size: imageBytes.length },
      { purpose: "post", categorySlug: "community", uploadId },
    );
    expect(result.uploadId).toBe(uploadId);
    expect(prisma.withMemberIdentity).toHaveBeenCalledTimes(2);
    expect(tx.auditEvent.createMany).toHaveBeenCalledTimes(1);
    expect(tx.mediaAsset.create).toHaveBeenCalledTimes(1);
    expect(drive.uploadImage).toHaveBeenCalledWith(expect.objectContaining({ uploadId, accountId }));
    expect(drive.deleteMemberMediaFile).not.toHaveBeenCalled();
  });

  it("reuses a matching upload receipt on retry instead of uploading or inserting twice", async () => {
    tx.mediaAsset.findUnique.mockResolvedValue(
      communityAsset({ ownerAccountId: accountId, status: "UPLOADED", postId: null }),
    );
    const result = await service.uploadMediaFile(
      "Bearer synthetic-token",
      { originalname: "test.jpg", mimetype: "image/jpeg", buffer: imageBytes, size: imageBytes.length },
      { purpose: "post", categorySlug: "community", uploadId },
    );
    expect(result.uploadId).toBe(uploadId);
    expect(drive.uploadImage).not.toHaveBeenCalled();
    expect(tx.auditEvent.createMany).not.toHaveBeenCalled();
    expect(tx.mediaAsset.create).not.toHaveBeenCalled();
  });

  it("rejects reuse of an upload ID when the media bytes have changed", async () => {
    tx.mediaAsset.findUnique.mockResolvedValue(
      communityAsset({ ownerAccountId: accountId, status: "UPLOADED", postId: null }),
    );
    const changedBytes = Buffer.from([0xff, 0xd8, 0xff, 0x01]);
    await expect(
      service.uploadMediaFile(
        "Bearer synthetic-token",
        { originalname: "test.jpg", mimetype: "image/jpeg", buffer: changedBytes, size: changedBytes.length },
        { purpose: "post", categorySlug: "community", uploadId },
      ),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(drive.uploadImage).not.toHaveBeenCalled();
  });

  it("compensates a newly-created Drive object if the atomic database transaction fails", async () => {
    prisma.withMemberIdentity
      .mockImplementationOnce(async (_identity: unknown, operation: (client: unknown) => unknown) => operation(tx))
      .mockRejectedValueOnce(new Error("synthetic RLS persistence failure"));
    await expect(
      service.uploadMediaFile(
        "Bearer synthetic-token",
        { originalname: "test.jpg", mimetype: "image/jpeg", buffer: imageBytes, size: imageBytes.length },
        { purpose: "post", categorySlug: "community", uploadId },
      ),
    ).rejects.toThrow("synthetic RLS persistence failure");
    expect(drive.deleteMemberMediaFile).toHaveBeenCalledWith("drive-file-1", accountId);
  });

  it("returns the existing post for a repeated clientPostId instead of creating a duplicate", async () => {
    const existing = publishedPost({
      id: postId,
      authorAccountId: accountId,
      imageAsset: `/api/v1/module2/media/object/${uploadId}`,
    });
    tx.communityPost.findUnique.mockResolvedValue(existing);
    tx.mediaAsset.findUnique.mockResolvedValue({ contentType: "image/jpeg" });

    const result = await service.createPost("Bearer synthetic-token", {
      clientPostId: postId,
      content: "Existing post",
      categorySlug: "community",
      visibility: "VERIFIED_MEMBERS",
      mediaUploadIds: [uploadId],
    } as any);

    expect(result.id).toBe(postId);
    expect(tx.communityPost.create).not.toHaveBeenCalled();
    expect(tx.auditEvent.createMany).not.toHaveBeenCalled();
  });

  it("resolves published media from media_assets without attempting an audit_events read", async () => {
    tx.mediaAsset.findUnique.mockResolvedValue(communityAsset());
    tx.communityPost.findUnique.mockResolvedValue(publishedPost());
    const result = await service.resolveMediaObject("Bearer synthetic-token", uploadId);
    expect(result.contentType).toBe("image/jpeg");
    expect(result.buffer).toEqual(imageBytes);
    expect(tx.auditEvent.findFirst).not.toHaveBeenCalled();
    expect(drive.downloadMemberMediaFile).toHaveBeenCalledWith(
      expect.objectContaining({
        driveFileId: "drive-file-1",
        ownerAccountId,
        expectedSha256: sha256,
        expectedByteSize: imageBytes.length,
      }),
    );
  });

  it("resolves legacy published media when the database checksum is null and delegates Drive receipt verification", async () => {
    tx.mediaAsset.findUnique.mockResolvedValue(communityAsset({ sha256Checksum: null }));
    tx.communityPost.findUnique.mockResolvedValue(publishedPost());

    const result = await service.resolveMediaObject("Bearer synthetic-token", uploadId);

    expect(result.buffer).toEqual(imageBytes);
    expect(drive.downloadMemberMediaFile).toHaveBeenCalledWith({
      driveFileId: "drive-file-1",
      ownerAccountId,
      expectedSha256: null,
      expectedByteSize: imageBytes.length,
    });
    expect(tx.auditEvent.findFirst).not.toHaveBeenCalled();
  });

  it("does not expose an unattached community draft to another member", async () => {
    tx.mediaAsset.findUnique.mockResolvedValue(communityAsset({
      postId: null, status: "UPLOADED", visibility: "VERIFIED_MEMBERS",
    }));
    await expect(service.resolveMediaObject("Bearer synthetic-token", uploadId))
      .rejects.toBeInstanceOf(NotFoundException);
    expect(drive.downloadMemberMediaFile).not.toHaveBeenCalled();
  });

  it("does not expose profile media when the owner's directory profile is hidden", async () => {
    tx.mediaAsset.findUnique.mockResolvedValue(communityAsset({
      postId: null, purpose: "PROFILE_PHOTO", visibility: "VERIFIED_MEMBERS",
    }));
    tx.communityDirectoryProfile.findUnique.mockResolvedValue(null);
    await expect(service.resolveMediaObject("Bearer synthetic-token", uploadId))
      .rejects.toBeInstanceOf(ForbiddenException);
    expect(drive.downloadMemberMediaFile).not.toHaveBeenCalled();
  });

  it("requires a real follow relationship for FOLLOWERS_ONLY media", async () => {
    tx.mediaAsset.findUnique.mockResolvedValue(communityAsset({ visibility: "FOLLOWERS_ONLY" }));
    tx.communityPost.findUnique.mockResolvedValue(publishedPost({ visibility: "FOLLOWERS_ONLY" }));
    tx.communityDirectoryProfile.findUnique.mockResolvedValue({
      id: randomUUID(), profileVisibility: "FOLLOWERS_ONLY", searchable: true,
    });
    tx.memberFollow.findUnique.mockResolvedValue({ isFollowing: false });
    await expect(service.resolveMediaObject("Bearer synthetic-token", uploadId))
      .rejects.toBeInstanceOf(ForbiddenException);
    expect(drive.downloadMemberMediaFile).not.toHaveBeenCalled();
  });

  it("rejects direct-message attachments while the recipient request is pending", async () => {
    tx.mediaAsset.findUnique.mockResolvedValue(communityAsset({
      postId: null, purpose: "DIRECT_MESSAGE_IMAGE", visibility: "PRIVATE_SELF",
    }));
    tx.directMessage.findFirst.mockResolvedValue({
      senderAccountId: ownerAccountId, recipientAccountId: accountId, requestStatus: "PENDING",
    });
    await expect(service.resolveMediaObject("Bearer synthetic-token", uploadId))
      .rejects.toBeInstanceOf(ForbiddenException);
    expect(drive.downloadMemberMediaFile).not.toHaveBeenCalled();
  });

  it("keeps complaint evidence outside the member media-object route", async () => {
    tx.mediaAsset.findUnique.mockResolvedValue(communityAsset({
      postId: null, purpose: "COMPLAINT_EVIDENCE",
    }));
    await expect(service.resolveMediaObject("Bearer synthetic-token", uploadId))
      .rejects.toBeInstanceOf(NotFoundException);
    expect(drive.downloadMemberMediaFile).not.toHaveBeenCalled();
  });
});
