import { BadRequestException } from "@nestjs/common";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { AuthenticationService } from "../src/auth/auth.service.js";
import { PrismaService } from "../src/database/prisma.service.js";
import { Module2Service } from "../src/module2/module2.service.js";

const viewerId = "2f6f7fa1-8c5c-4bb0-ae1a-0f7e3a2e5a41";
const targetId = "3a7f8fb2-9d6d-4cc1-bf2b-1a8f4b3e6d52";

describe("Module2Service privacy regression checks", () => {
  let service: Module2Service;
  let prisma: Record<string, any>;
  let auth: { authenticateAuthorization: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    auth = {
      authenticateAuthorization: vi.fn().mockResolvedValue({
        accountId: viewerId,
        account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
      }),
    };
    prisma = {
      memberProfile: {
        findUnique: vi.fn().mockResolvedValue({ accountId: viewerId }),
      },
      memberBlock: {
        findFirst: vi.fn().mockResolvedValue(null),
      },
      memberAccount: {
        findMany: vi.fn().mockResolvedValue([]),
        findFirst: vi.fn().mockResolvedValue({
          id: targetId,
          profile: {
            accountId: targetId,
            displayName: "Other member",
            profilePhotoRef: null,
            bio: null,
            interests: [],
            locationCity: "Tirupati",
          },
          privacySettings: null,
        }),
      },
      memberPrivacySettings: {
        upsert: vi.fn(),
      },
      socialFollow: {
        findUnique: vi.fn().mockResolvedValue(null),
        findMany: vi.fn().mockResolvedValue([]),
        count: vi.fn().mockResolvedValue(0),
      },
      memberPost: {
        count: vi.fn().mockResolvedValue(0),
      },
      memberPostBookmark: {
        findMany: vi.fn().mockResolvedValue([]),
      },
    };

    service = new Module2Service(
      auth as unknown as AuthenticationService,
      prisma as unknown as PrismaService,
    );
  });

  it("does not create another member's privacy row merely by viewing their profile", async () => {
    const result = await service.getMemberProfile("Bearer test-token", targetId);

    expect(result.accountId).toBe(targetId);
    expect(prisma.memberPrivacySettings.upsert).not.toHaveBeenCalled();
    expect(result.profile.locationCity).toBeNull();
  });

  it("does not expose follower-only profiles in discovery unless the viewer follows them", async () => {
    await service.getDiscover("Bearer test-token");

    const query = prisma.memberAccount.findMany.mock.calls[0]?.[0];
    const visibilityBranches = query.where.OR as Array<Record<string, any>>;
    expect(visibilityBranches).toContainEqual({
      privacySettings: {
        is: {
          appearInSearch: true,
          profileVisibility: "VERIFIED_MEMBERS",
        },
      },
    });
    expect(
      visibilityBranches.some((branch) =>
        Array.isArray(branch.AND) &&
        branch.AND.some((part: Record<string, any>) =>
          part.privacySettings?.is?.profileVisibility === "FOLLOWERS_ONLY",
        ) &&
        branch.AND.some((part: Record<string, any>) =>
          part.followsAsFollowing?.some?.followerAccountId === viewerId,
        ),
      ),
    ).toBe(true);
  });

  it("does not return ONLY_ME accounts from the followers list query", async () => {
    await service.listFollowers("Bearer test-token", "followers");

    const query = prisma.socialFollow.findMany.mock.calls[0]?.[0];
    const accountWhere = query.where.follower.is;
    expect(accountWhere.OR).toContainEqual({
      privacySettings: { is: null },
    });
    expect(
      accountWhere.OR.some((branch: Record<string, any>) =>
        branch.privacySettings?.is?.profileVisibility === "ONLY_ME",
      ),
    ).toBe(false);
  });

  it("rejects profile photo references scoped to a different account", async () => {
    await expect(
      service.updateProfile("Bearer test-token", {
        profilePhotoRef: `profile/${targetId}/avatar.webp`,
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it("reapplies current audience and block visibility when listing saved posts", async () => {
    await service.listSavedPosts("Bearer test-token");

    const query = prisma.memberPostBookmark.findMany.mock.calls[0]?.[0];
    expect(query.where.accountId).toBe(viewerId);
    expect(query.where.post.is.status).toBe("PUBLISHED");
    expect(query.where.post.is.deletedAt).toBeNull();
    expect(query.where.post.is.account).toBeDefined();
  });
});
