import { BadRequestException, NotFoundException } from "@nestjs/common";
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
        findUnique: vi.fn().mockResolvedValue({
          accountId: viewerId,
          displayName: "Viewer Member",
          username: "@viewer",
        }),
        findMany: vi.fn().mockResolvedValue([]),
      },
      communityDirectoryProfile: {
        findUnique: vi.fn().mockResolvedValue({
          id: "viewer-directory-id",
          username: "@viewer",
        }),
        findMany: vi.fn(async (args: Record<string, any>) => {
          const handles = args.where?.username?.in ?? [];
          return handles
            .filter((username: string) =>
              ["@visible", "@private"].includes(username),
            )
            .map((username: string) => ({
              id:
                username === "@visible"
                  ? "visible-directory-id"
                  : "private-directory-id",
              username,
            }));
        }),
        upsert: vi.fn(),
        update: vi.fn(),
      },
      memberFollow: {
        findMany: vi.fn(async (args: Record<string, any>) => {
          if (args.where?.accountId === viewerId) return [];
          if (args.where?.directoryProfileId === "viewer-directory-id") {
            return [
              {
                account: {
                  accountId: "private-account-id",
                  status: "ACTIVE",
                  verificationStatus: "VERIFIED",
                  profile: {
                    accountId: "private-account-id",
                    displayName: "Private Member",
                    username: "@private",
                    bio: "",
                    avatarAsset: "",
                    avatarMediaAssetId: null,
                    interests: [],
                    businessProfileUrl: null,
                    businessProfileName: null,
                    businessCategory: null,
                  },
                  privacyPreference: {
                    viewProfile: "Only me",
                    searchResults: "No",
                  },
                },
              },
              {
                account: {
                  accountId: "visible-account-id",
                  status: "ACTIVE",
                  verificationStatus: "VERIFIED",
                  profile: {
                    accountId: "visible-account-id",
                    displayName: "Visible Member",
                    username: "@visible",
                    bio: "",
                    avatarAsset: "",
                    avatarMediaAssetId: null,
                    interests: [],
                    businessProfileUrl: null,
                    businessProfileName: null,
                    businessCategory: null,
                  },
                  privacyPreference: {
                    viewProfile: "Verified members only",
                    searchResults: "Yes",
                  },
                },
              },
            ];
          }
          return [];
        }),
      },
      memberModerationBlock: {
        findMany: vi.fn().mockResolvedValue([]),
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
        findFirst: vi.fn().mockResolvedValue(null),
      },
      memberReport: {
        create: vi.fn(),
      },
      memberPostBookmark: {
        findMany: vi.fn().mockResolvedValue([]),
      },
      communityGroup: {
        findMany: vi.fn().mockResolvedValue([]),
      },
    };

    service = new Module2Service(
      auth as unknown as AuthenticationService,
      prisma as unknown as PrismaService,
    );
  });

  it("does not create another member's privacy row merely by viewing their profile", async () => {
    const result = await service.getMemberProfile(
      "Bearer test-token",
      targetId,
    );

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
      visibilityBranches.some(
        (branch) =>
          Array.isArray(branch.AND) &&
          branch.AND.some(
            (part: Record<string, any>) =>
              part.privacySettings?.is?.profileVisibility === "FOLLOWERS_ONLY",
          ) &&
          branch.AND.some(
            (part: Record<string, any>) =>
              part.followsAsFollowing?.some?.followerAccountId === viewerId,
          ),
      ),
    ).toBe(true);
  });

  it("does not search hidden city values in member discovery", async () => {
    await service.getDiscover("Bearer test-token", "Tirupati");

    const query = prisma.memberAccount.findMany.mock.calls[0]?.[0];
    const searchBranches = query.where.AND.find((part: Record<string, any>) =>
      Array.isArray(part.OR),
    ).OR as Array<Record<string, any>>;
    expect(
      searchBranches.some(
        (branch) => branch.profile?.is?.locationCity !== undefined,
      ),
    ).toBe(false);
    expect(
      searchBranches.some(
        (branch) =>
          Array.isArray(branch.AND) &&
          branch.AND.some(
            (part: Record<string, any>) =>
              part.privacySettings?.is?.locationSharing === "CITY_ONLY",
          ),
      ),
    ).toBe(true);
  });

  it("lists groups using only columns present in the installed Prisma schema", async () => {
    await service.listGroups("Bearer test-token");

    const query = prisma.communityGroup.findMany.mock.calls[0]?.[0];
    expect(query).toEqual({
      orderBy: { createdAt: "desc" },
      take: 100,
    });
    expect(query.where).toBeUndefined();
  });

  it("does not return profiles that restrict visibility to only themselves", async () => {
    const result = await service.listFollowers(
      "Bearer test-token",
      "followers",
    );

    expect(
      result.items.map((item: Record<string, any>) => item.username),
    ).toContain("@visible");
    expect(
      result.items.map((item: Record<string, any>) => item.username),
    ).not.toContain("@private");
  });

  it("rejects profile photo references scoped to a different account", async () => {
    await expect(
      service.updateProfile("Bearer test-token", {
        profilePhotoRef: `profile/${targetId}/avatar.webp`,
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it("rejects a group name that is too short after trimming", async () => {
    await expect(
      service.createGroup("Bearer test-token", {
        name: " X ",
        visibility: "PRIVATE",
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it("rejects whitespace-only event content before attempting to persist it", async () => {
    await expect(
      service.createEvent("Bearer test-token", {
        groupId: "4b1f7f84-2f0d-4f39-8bd9-73ac2a7763a1",
        title: "   ",
        description: "   ",
        startsAt: new Date(Date.now() + 86_400_000).toISOString(),
        endsAt: new Date(Date.now() + 90_000_000).toISOString(),
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it("does not allow reporting a post the reporter cannot currently view", async () => {
    await expect(
      service.reportMember("Bearer test-token", {
        reportedAccountId: targetId,
        postId: "4b1f7f84-2f0d-4f39-8bd9-73ac2a7763a1",
        reason: "HARASSMENT",
      }),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(prisma.memberPost.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          id: "4b1f7f84-2f0d-4f39-8bd9-73ac2a7763a1",
          account: expect.any(Object),
        }),
      }),
    );
    expect(prisma.memberReport.create).not.toHaveBeenCalled();
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
