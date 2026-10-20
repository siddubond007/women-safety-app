import { ForbiddenException } from "@nestjs/common";
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
