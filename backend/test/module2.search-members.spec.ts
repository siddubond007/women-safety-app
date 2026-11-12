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
      memberProfile: {
        findUnique: vi.fn().mockResolvedValue({
          accountId: viewerId,
          username: "@viewer",
        }),
      },
      memberModerationBlock: {
        findMany: vi.fn().mockResolvedValue([{ blockedUsername: "@blocked" }]),
      },
      communityDirectoryProfile: {
        findMany: vi.fn().mockResolvedValue([
          {
            id: "7ebc2cf6-d0a1-4000-a36f-5e2c8f9a1b26",
            accountId: visibleId,
            name: "A visible member",
            username: "@visible",
            bio: "Public directory bio",
            avatarAsset: "avatar.webp",
          },
          {
            id: "8fcd3d07-e1b2-4111-b470-6f3d90a2c237",
            accountId: blockedId,
            name: "Blocked member",
            username: "@blocked",
            bio: "Blocked directory bio",
            avatarAsset: "blocked.webp",
          },
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

  it("returns only safe, RLS-filtered public directory fields and real follow state", async () => {
    const result = await service.searchMembers("Bearer test-token", "wellness");

    expect(result.source).toBe("postgresql_live");
    expect(result.members).toHaveLength(1);
    expect(result.members[0]).toMatchObject({
      accountId: visibleId,
      name: "A visible member",
      username: "@visible",
      bio: "Public directory bio",
      isVerified: true,
      isFollowing: true,
      canFollow: true,
    });
    expect(result.members[0]).not.toHaveProperty("businessProfileName");
    expect(result.members[0]).not.toHaveProperty("businessProfileUrl");
    expect(result.members[0]).not.toHaveProperty("email");
    expect(result.members.map((item) => item.username)).not.toContain("@blocked");

    const directoryQuery = prisma.communityDirectoryProfile.findMany.mock.calls[0][0];
    expect(directoryQuery.where).toMatchObject({
      accountId: { not: viewerId },
      searchable: true,
    });
    expect(directoryQuery.select).toEqual({
      id: true,
      accountId: true,
      name: true,
      username: true,
      bio: true,
      avatarAsset: true,
    });
    expect(JSON.stringify(directoryQuery)).not.toMatch(/email|dateOfBirth|phone|location/i);
    expect(prisma.memberProfile.findMany).toBeUndefined();
    expect(prisma.memberModerationBlock.findMany).toHaveBeenCalledTimes(1);
  });

  it("returns an empty result without a member query for a blank search", async () => {
    const result = await service.searchMembers("Bearer test-token", "  ");

    expect(result.members).toEqual([]);
    expect(prisma.communityDirectoryProfile.findMany).not.toHaveBeenCalled();
  });
});
