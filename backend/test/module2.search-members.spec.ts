import { beforeEach, describe, expect, it, vi } from "vitest";
import { AuthenticationService } from "../src/auth/auth.service.js";
import { PrismaService } from "../src/database/prisma.service.js";
import { Module2Service } from "../src/module2/module2.service.js";

const viewerId = "2f6f7fa1-8c5c-4bb0-ae1a-0f7e3a2e5a41";
const visibleId = "3a7f8fb2-9d6d-4cc1-bf2b-1a8f4b3e6d52";
const hiddenId = "4b8f9fc3-ad7e-4dd2-c03c-2b9f5c4f7e63";
const blockedId = "5c9a0ad4-be8f-4ee3-d14d-3c0a6d5a8f74";
const blockedMeId = "6dab1be5-cf90-4ff4-e25e-4d1b7e6b9a85";

const profile = (
  accountId: string,
  username: string,
  searchResults: string,
) => ({
  accountId,
  displayName: username === "@visible" ? "A visible member" : username,
  username,
  bio: "Member bio",
  interests: ["Mental Wellness"],
  avatarAsset: "assets/images/profile/avatar_ananya.webp",
  avatarMediaAssetId: null,
  businessProfileUrl:
    username === "@visible" ? "https://business.example" : null,
  businessProfileName: username === "@visible" ? "Visible Studio" : null,
  businessCategory: username === "@visible" ? "Artisan" : null,
  account: {
    status: "ACTIVE",
    verificationStatus: "VERIFIED",
    privacyPreference: { searchResults },
  },
});

describe("Module2Service privacy-aware member search", () => {
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
      $queryRaw: vi.fn().mockResolvedValue([{ accountId: visibleId }]),
      memberProfile: {
        findUnique: vi.fn().mockResolvedValue({
          accountId: viewerId,
          username: "@viewer",
        }),
        findMany: vi
          .fn()
          .mockResolvedValue([
            profile(visibleId, "@visible", "Yes"),
            profile(hiddenId, "@hidden", "No"),
            profile(blockedId, "@blocked", "Yes"),
          ]),
      },
      memberModerationBlock: {
        findMany: vi.fn(async (args: any) => {
          if (args.where.accountId === viewerId) {
            return [{ blockedUsername: "@blocked" }];
          }
          if (args.where.blockedUsername?.in?.includes("@viewer")) {
            return [{ accountId: blockedMeId }];
          }
          return [];
        }),
      },
      communityDirectoryProfile: {
        findMany: vi.fn().mockResolvedValue([
          { id: "7ebc2cf6-d0a1-4000-a36f-5e2c8f9a1b26", username: "@visible" },
          { id: "8fcd3d07-e1b2-4111-b470-6f3d90a2c237", username: "@blocked" },
        ]),
      },
      memberFollow: {
        findMany: vi
          .fn()
          .mockResolvedValue([
            { directoryProfileId: "7ebc2cf6-d0a1-4000-a36f-5e2c8f9a1b26" },
          ]),
      },
    };
    service = new Module2Service(
      auth as unknown as AuthenticationService,
      prisma as unknown as PrismaService,
    );
  });

  it("returns verified, visible members and real follow/business metadata only", async () => {
    const result = await service.searchMembers("Bearer test-token", "wellness");

    expect(result.source).toBe("postgresql_live");
    expect(result.members).toHaveLength(1);
    expect(result.members[0]).toMatchObject({
      accountId: visibleId,
      name: "A visible member",
      username: "@visible",
      isVerified: true,
      isFollowing: true,
      canFollow: true,
      businessProfileName: "Visible Studio",
      businessCategory: "Artisan",
    });

    const profileQuery = prisma.memberProfile.findMany.mock.calls[0][0];
    expect(profileQuery.where.account.is).toMatchObject({
      status: "ACTIVE",
      verificationStatus: "VERIFIED",
    });
    expect(profileQuery.where.accountId.not).toBe(viewerId);
    expect(profileQuery.where.accountId.notIn).toContain(blockedMeId);
    expect(
      profileQuery.where.OR.some(
        (branch: any) => branch.accountId?.in?.includes(visibleId) === true,
      ),
    ).toBe(true);
    expect(prisma.$queryRaw).toHaveBeenCalledTimes(1);
    expect(prisma.memberModerationBlock.findMany).toHaveBeenCalledTimes(2);
  });

  it("returns an empty result without a member query for a blank search", async () => {
    const result = await service.searchMembers("Bearer test-token", "  ");

    expect(result.members).toEqual([]);
    expect(prisma.memberProfile.findMany).not.toHaveBeenCalled();
    expect(prisma.communityDirectoryProfile.findMany).not.toHaveBeenCalled();
  });
});
