import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { createHash, randomUUID } from "node:crypto";
import type { Prisma } from "../generated/prisma/client.js";
import { AuthenticationService } from "../auth/auth.service.js";
import { PrismaService } from "../database/prisma.service.js";
import type {
  CreateBusinessProfileDto,
  CreateCommunityEventDto,
  CreateCommunityGroupDto,
  CreatePostCommentDto,
  CreatePostDto,
  ReportMemberDto,
  RequestAccountDeletionDto,
  UpdateMarketingConsentDto,
  UpdateNotificationPreferencesDto,
  UpdatePrivacySettingsDto,
  UpdateProfileDto,
} from "./module2.dto.js";

const DEFAULT_PAGE_SIZE = 20;
const MAX_PAGE_SIZE = 50;
const UUID_V4_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const profilePublicSelect = {
  accountId: true,
  displayName: true,
  profilePhotoRef: true,
  bio: true,
  locationCity: true,
  interests: true,
} as const;

type Session = Awaited<ReturnType<AuthenticationService["authenticateAuthorization"]>>;

@Injectable()
export class Module2Service {
  constructor(
    private readonly auth: AuthenticationService,
    private readonly prisma: PrismaService,
  ) {}

  private tokenDigest(authorization?: string): string {
    if (!authorization?.startsWith("Bearer ")) {
      throw new ForbiddenException("Sign in again to continue.");
    }
    return createHash("sha256")
      .update(authorization.slice("Bearer ".length).trim())
      .digest("hex");
  }

  private async requireMember(authorization?: string): Promise<Session> {
    const session = await this.auth.authenticateAuthorization(authorization);
    if (
      session.account.status !== "ACTIVE" ||
      session.account.verificationStatus !== "VERIFIED"
    ) {
      throw new ForbiddenException(
        "Module 2 features are available only to active, verified Sakhi members.",
      );
    }
    const profile = await this.prisma.memberProfile.findUnique({
      where: { accountId: session.accountId },
      select: { accountId: true },
    });
    if (!profile) {
      throw new ConflictException(
        "Complete your Sakhi profile before using member features.",
      );
    }
    return session;
  }

  private async ensureDefaultSettings(accountId: string): Promise<void> {
    await this.prisma.$transaction([
      this.prisma.memberPrivacySettings.upsert({
        where: { accountId },
        create: { accountId },
        update: {},
      }),
      this.prisma.memberNotificationPreferences.upsert({
        where: { accountId },
        create: { accountId },
        update: {},
      }),
    ]);
  }

  private async recordAudit(
    accountId: string,
    action: string,
    targetType: string,
    targetId: string,
    outcome = "success",
    metadata: Record<string, string | number | boolean | null> = {},
  ): Promise<void> {
    await this.prisma.auditEvent.createMany({
      data: {
        actorType: "MEMBER",
        actorId: accountId,
        action,
        targetType,
        targetId,
        outcome,
        requestId: randomUUID(),
        redactedMetadata: metadata,
      },
    });
  }

  private pageSize(value?: string): number {
    if (value == null || value.trim() === "") return DEFAULT_PAGE_SIZE;
    const parsed = Number(value);
    if (!Number.isInteger(parsed) || parsed < 1 || parsed > MAX_PAGE_SIZE) {
      throw new BadRequestException(
        `limit must be an integer between 1 and ${MAX_PAGE_SIZE}.`,
      );
    }
    return parsed;
  }

  private async ensureNotBlocked(
    firstAccountId: string,
    secondAccountId: string,
  ): Promise<void> {
    const blocked = await this.prisma.memberBlock.findFirst({
      where: {
        OR: [
          { blockerAccountId: firstAccountId, blockedAccountId: secondAccountId },
          { blockerAccountId: secondAccountId, blockedAccountId: firstAccountId },
        ],
      },
      select: { blockerAccountId: true },
    });
    if (blocked) {
      throw new NotFoundException("This member or resource is unavailable.");
    }
  }

  private postWhere(
    viewerAccountId: string,
    options: { authorAccountId?: string; query?: string } = {},
  ): Prisma.MemberPostWhereInput {
    const query = options.query?.trim().slice(0, 100);
    return {
      status: "PUBLISHED",
      deletedAt: null,
      ...(options.authorAccountId ? { accountId: options.authorAccountId } : {}),
      ...(query ? { body: { contains: query, mode: "insensitive" } } : {}),
      account: {
        is: {
          status: "ACTIVE",
          verificationStatus: "VERIFIED",
          OR: [
            { privacySettings: { is: null } },
            { privacySettings: { is: { profileVisibility: "VERIFIED_MEMBERS" } } },
            {
              privacySettings: { is: { profileVisibility: "FOLLOWERS_ONLY" } },
              followsAsFollowing: { some: { followerAccountId: viewerAccountId } },
            },
            { privacySettings: { is: { profileVisibility: "ONLY_ME" } }, id: viewerAccountId },
          ],
          AND: [
            { NOT: { blockedAccounts: { some: { blockedAccountId: viewerAccountId } } } },
            { NOT: { blockedByAccounts: { some: { blockerAccountId: viewerAccountId } } } },
          ],
        },
      },
      OR: [
        { accountId: viewerAccountId },
        { audience: "VERIFIED_MEMBERS" },
        {
          audience: "FOLLOWERS",
          account: { is: { followsAsFollowing: { some: { followerAccountId: viewerAccountId } } } },
        },
        {
          audience: "SELECTED_MEMBERS",
          audienceMembers: { some: { accountId: viewerAccountId } },
        },
        { audience: "ONLY_ME", accountId: viewerAccountId },
      ],
    };
  }

  private postInclude(viewerAccountId: string) {
    return {
      account: {
        include: {
          profile: { select: profilePublicSelect },
          privacySettings: true,
          followsAsFollowing: {
            where: { followerAccountId: viewerAccountId },
            select: { followerAccountId: true },
            take: 1,
          },
        },
      },
      likes: { where: { accountId: viewerAccountId }, select: { accountId: true }, take: 1 },
      bookmarks: { where: { accountId: viewerAccountId }, select: { accountId: true }, take: 1 },
      _count: {
        select: {
          likes: {
            where: {
              account: { is: { status: "ACTIVE", verificationStatus: "VERIFIED" } },
            },
          },
          comments: {
            where: {
              deletedAt: null,
              account: {
                is: {
                  status: "ACTIVE",
                  verificationStatus: "VERIFIED",
                  AND: [
                    { NOT: { blockedAccounts: { some: { blockedAccountId: viewerAccountId } } } },
                    { NOT: { blockedByAccounts: { some: { blockerAccountId: viewerAccountId } } } },
                  ],
                },
              },
            },
          },
        },
      },
    } as const;
  }

  private serializePost(post: any, viewerAccountId: string) {
    const profile = post.account?.profile;
    const privacy = post.account?.privacySettings;
    const canShowCity =
      privacy?.locationSharing === "CITY_ONLY" && Boolean(profile?.locationCity);
    return {
      id: post.id as string,
      body: post.body as string,
      mediaRef: post.mediaRef as string | null,
      audience: post.audience as string,
      createdAt: (post.createdAt as Date).toISOString(),
      updatedAt: (post.updatedAt as Date).toISOString(),
      author: {
        accountId: post.accountId as string,
        displayName: profile?.displayName ?? "Sakhi member",
        profilePhotoRef: profile?.profilePhotoRef ?? null,
        locationCity: canShowCity ? profile.locationCity : null,
        isFollowing: (post.account?.followsAsFollowing?.length ?? 0) > 0,
      },
      likeCount: post._count.likes as number,
      commentCount: post._count.comments as number,
      isLikedByViewer: (post.likes?.length ?? 0) > 0,
      isSavedByViewer: (post.bookmarks?.length ?? 0) > 0,
      isOwnPost: post.accountId === viewerAccountId,
    };
  }

  async getProfile(authorization?: string) {
    const session = await this.requireMember(authorization);
    await this.ensureDefaultSettings(session.accountId);
    const [account, followersCount, followingCount, postCount, savedCount, businessProfile] =
      await Promise.all([
        this.prisma.memberAccount.findUniqueOrThrow({
          where: { id: session.accountId },
          include: { profile: true, privacySettings: true, notificationSettings: true },
        }),
        this.prisma.socialFollow.count({
          where: {
            followingAccountId: session.accountId,
            follower: { is: { status: "ACTIVE", verificationStatus: "VERIFIED" } },
          },
        }),
        this.prisma.socialFollow.count({
          where: {
            followerAccountId: session.accountId,
            following: { is: { status: "ACTIVE", verificationStatus: "VERIFIED" } },
          },
        }),
        this.prisma.memberPost.count({
          where: { accountId: session.accountId, status: "PUBLISHED", deletedAt: null },
        }),
        this.prisma.memberPostBookmark.count({
          where: {
            accountId: session.accountId,
            post: { is: this.postWhere(session.accountId) },
          },
        }),
        this.prisma.businessProfile.findUnique({ where: { accountId: session.accountId } }),
      ]);
    const phone = account.phoneE164;
    return {
      accountId: account.id,
      accountStatus: account.status,
      verificationStatus: account.verificationStatus,
      phone: `${phone.slice(0, Math.max(1, phone.length - 4)).replace(/\d/g, "•")}${phone.slice(-4)}`,
      phoneVerified: account.phoneVerifiedAt !== null,
      profile: {
        accountId: account.profile?.accountId,
        displayName: account.profile?.displayName ?? "",
        dateOfBirth: account.profile?.dateOfBirth.toISOString().slice(0, 10) ?? null,
        email: account.profile?.email ?? null,
        profilePhotoRef: account.profile?.profilePhotoRef ?? null,
        bio: account.profile?.bio ?? "",
        locationCity: account.profile?.locationCity ?? "",
        interests: account.profile?.interests ?? [],
        updatedAt: account.profile?.updatedAt.toISOString() ?? null,
      },
      counts: { posts: postCount, followers: followersCount, following: followingCount, saved: savedCount },
      privacySettings: account.privacySettings,
      notificationPreferences: account.notificationSettings,
      businessProfile,
    };
  }

  async updateProfile(authorization: string | undefined, dto: UpdateProfileDto) {
    const session = await this.requireMember(authorization);
    const update: Prisma.MemberProfileUpdateInput = {};
    if (dto.displayName !== undefined) {
      const value = dto.displayName.trim();
      if (!value) throw new BadRequestException("Display name cannot be blank.");
      update.displayName = value;
    }
    if (dto.email !== undefined) update.email = dto.email?.trim().toLowerCase() || null;
    if (dto.bio !== undefined) update.bio = dto.bio?.trim() || null;
    if (dto.locationCity !== undefined) update.locationCity = dto.locationCity?.trim() || null;
    if (dto.profilePhotoRef !== undefined) {
      const photoRef = dto.profilePhotoRef?.trim() || null;
      const pathSegments = photoRef?.split("/") ?? [];
      if (
        photoRef &&
        (!photoRef.startsWith(`profile/${session.accountId}/`) ||
          pathSegments.some((segment) => segment === "." || segment === ".." || segment.length === 0))
      ) {
        throw new BadRequestException(
          "Profile photo references must use safe path segments scoped to the signed-in member.",
        );
      }
      update.profilePhotoRef = photoRef;
    }
    if (dto.interests !== undefined) {
      const interests = [...new Set(dto.interests.map((value) => value.trim()).filter(Boolean))];
      if (interests.length > 20) throw new BadRequestException("Choose no more than 20 interests.");
      update.interests = interests;
    }
    if (Object.keys(update).length === 0) {
      throw new BadRequestException("Provide at least one profile field to update.");
    }
    const profile = await this.prisma.memberProfile.update({
      where: { accountId: session.accountId },
      data: update,
      select: {
        accountId: true,
        displayName: true,
        email: true,
        profilePhotoRef: true,
        bio: true,
        locationCity: true,
        interests: true,
        updatedAt: true,
      },
    });
    await this.recordAudit(session.accountId, "module2.profile.updated", "member_profile", session.accountId, "success", {
      fields: Object.keys(update).join(","),
    });
    return { profile: { ...profile, updatedAt: profile.updatedAt.toISOString() } };
  }

  async getMemberProfile(authorization: string | undefined, targetAccountId: string) {
    const session = await this.requireMember(authorization);
    if (targetAccountId === session.accountId) return this.getProfile(authorization);
    await this.ensureNotBlocked(session.accountId, targetAccountId);
    const target = await this.prisma.memberAccount.findFirst({
      where: {
        id: targetAccountId,
        status: "ACTIVE",
        verificationStatus: "VERIFIED",
      },
      include: { profile: true, privacySettings: true },
    });
    if (!target?.profile) throw new NotFoundException("This member is unavailable.");
    const privacy = target.privacySettings;
    const isFollowing = await this.prisma.socialFollow.findUnique({
      where: {
        followerAccountId_followingAccountId: {
          followerAccountId: session.accountId,
          followingAccountId: targetAccountId,
        },
      },
      select: { followerAccountId: true },
    });
    if (
      privacy?.profileVisibility === "ONLY_ME" ||
      (privacy?.profileVisibility === "FOLLOWERS_ONLY" && !isFollowing)
    ) {
      throw new NotFoundException("This member is unavailable.");
    }
    const [postsCount, followersCount, followingCount] = await Promise.all([
      this.prisma.memberPost.count({ where: this.postWhere(session.accountId, { authorAccountId: targetAccountId }) }),
      this.prisma.socialFollow.count({
        where: {
          followingAccountId: targetAccountId,
          follower: { is: { status: "ACTIVE", verificationStatus: "VERIFIED" } },
        },
      }),
      this.prisma.socialFollow.count({
        where: {
          followerAccountId: targetAccountId,
          following: { is: { status: "ACTIVE", verificationStatus: "VERIFIED" } },
        },
      }),
    ]);
    return {
      accountId: target.id,
      profile: {
        accountId: target.profile.accountId,
        displayName: target.profile.displayName,
        profilePhotoRef: target.profile.profilePhotoRef,
        bio: target.profile.bio,
        interests: target.profile.interests,
        locationCity: privacy?.locationSharing === "CITY_ONLY" ? target.profile.locationCity : null,
      },
      counts: { posts: postsCount, followers: followersCount, following: followingCount },
      isFollowing: Boolean(isFollowing),
      privacy: {
        profileVisibility: privacy?.profileVisibility ?? "VERIFIED_MEMBERS",
        locationSharing: privacy?.locationSharing ?? "HIDDEN",
      },
    };
  }

  async getDiscover(authorization: string | undefined, query = "", limit?: string) {
    const session = await this.requireMember(authorization);
    const take = this.pageSize(limit);
    const normalized = query.trim().slice(0, 100);
    const accounts = await this.prisma.memberAccount.findMany({
      where: {
        id: { not: session.accountId },
        status: "ACTIVE",
        verificationStatus: "VERIFIED",
        profile: {
          is: {
            ...(normalized
              ? {
                  OR: [
                    { displayName: { contains: normalized, mode: "insensitive" } },
                    { bio: { contains: normalized, mode: "insensitive" } },
                    { locationCity: { contains: normalized, mode: "insensitive" } },
                    { interests: { hasSome: [normalized] } },
                  ],
                }
              : {}),
          },
        },
        OR: [
          { privacySettings: { is: null } },
          {
            privacySettings: {
              is: {
                appearInSearch: true,
                profileVisibility: "VERIFIED_MEMBERS",
              },
            },
          },
          {
            AND: [
              {
                privacySettings: {
                  is: {
                    appearInSearch: true,
                    profileVisibility: "FOLLOWERS_ONLY",
                  },
                },
              },
              {
                followsAsFollowing: {
                  some: { followerAccountId: session.accountId },
                },
              },
            ],
          },
        ],
        AND: [
          { NOT: { blockedAccounts: { some: { blockedAccountId: session.accountId } } } },
          { NOT: { blockedByAccounts: { some: { blockerAccountId: session.accountId } } } },
        ],
      },
      select: {
        id: true,
        profile: { select: profilePublicSelect },
        privacySettings: true,
        _count: {
          select: {
            posts: { where: { status: "PUBLISHED", deletedAt: null } },
            followsAsFollowing: {
              where: { follower: { is: { status: "ACTIVE", verificationStatus: "VERIFIED" } } },
            },
            followsAsFollower: {
              where: { following: { is: { status: "ACTIVE", verificationStatus: "VERIFIED" } } },
            },
          },
        },
      },
      orderBy: { createdAt: "desc" },
      take,
    });
    const followed = await this.prisma.socialFollow.findMany({
      where: { followerAccountId: session.accountId },
      select: { followingAccountId: true },
    });
    const followingIds = new Set(followed.map((row) => row.followingAccountId));
    return {
      members: accounts.map((account) => ({
        accountId: account.id,
        displayName: account.profile?.displayName ?? "Sakhi member",
        profilePhotoRef: account.profile?.profilePhotoRef ?? null,
        bio: account.profile?.bio ?? null,
        locationCity:
          account.privacySettings?.locationSharing === "CITY_ONLY"
            ? account.profile?.locationCity ?? null
            : null,
        interests: account.profile?.interests ?? [],
        isFollowing: followingIds.has(account.id),
        counts: {
          posts: account._count.posts,
          followers: account._count.followsAsFollowing,
          following: account._count.followsAsFollower,
        },
      })),
      hasMore: accounts.length === take,
      limit: take,
    };
  }

  async listPosts(
    authorization: string | undefined,
    options: { accountId?: string; query?: string; cursor?: string; limit?: string } = {},
  ) {
    const session = await this.requireMember(authorization);
    if (options.accountId && !UUID_V4_PATTERN.test(options.accountId)) {
      throw new BadRequestException("accountId must be a valid UUID.");
    }
    const take = this.pageSize(options.limit);
    if (options.cursor && !UUID_V4_PATTERN.test(options.cursor)) {
      throw new BadRequestException("cursor must be a valid UUID.");
    }
    const where = this.postWhere(session.accountId, {
      authorAccountId: options.accountId,
      query: options.query,
    });
    const page = await this.prisma.memberPost.findMany({
      where,
      include: this.postInclude(session.accountId),
      orderBy: [{ createdAt: "desc" }, { id: "desc" }],
      take,
      ...(options.cursor ? { skip: 1, cursor: { id: options.cursor } } : {}),
    });
    return {
      posts: page.map((post) => this.serializePost(post, session.accountId)),
      nextCursor: page.length === take ? page[page.length - 1]?.id ?? null : null,
      limit: take,
    };
  }

  async listSavedPosts(authorization?: string) {
    const session = await this.requireMember(authorization);
    const bookmarks = await this.prisma.memberPostBookmark.findMany({
      where: {
        accountId: session.accountId,
        // Reapply current audience, profile-visibility and block policies when
        // rendering saved posts; authorization at bookmark time is not permanent.
        post: { is: this.postWhere(session.accountId) },
      },
      orderBy: { createdAt: "desc" },
      include: {
        post: { include: this.postInclude(session.accountId) },
      },
      take: MAX_PAGE_SIZE,
    });
    return {
      posts: bookmarks.map((row) => this.serializePost(row.post, session.accountId)),
    };
  }

  async createPost(authorization: string | undefined, dto: CreatePostDto) {
    const session = await this.requireMember(authorization);
    const body = dto.body.trim();
    if (!body) throw new BadRequestException("A post cannot be empty.");
    const settings = await this.prisma.memberPrivacySettings.findUnique({
      where: { accountId: session.accountId },
    });
    const audience = dto.audience ?? settings?.defaultPostAudience ?? "VERIFIED_MEMBERS";
    const selectedIds = [...new Set(dto.selectedAudienceAccountIds ?? [])];
    if (audience === "SELECTED_MEMBERS") {
      if (selectedIds.length === 0) {
        throw new BadRequestException("Choose at least one member for a selected-audience post.");
      }
      const targets = await this.prisma.memberAccount.findMany({
        where: {
          id: { in: selectedIds },
          status: "ACTIVE",
          verificationStatus: "VERIFIED",
          NOT: { id: session.accountId },
        },
        select: { id: true },
      });
      if (targets.length !== selectedIds.length) {
        throw new BadRequestException("One or more selected audience members are unavailable.");
      }
      for (const target of targets) await this.ensureNotBlocked(session.accountId, target.id);
    } else if (selectedIds.length > 0) {
      throw new BadRequestException("Selected audience members are only valid for SELECTED_MEMBERS posts.");
    }
    const post = await this.prisma.$transaction(async (tx) => {
      const created = await tx.memberPost.create({
        data: {
          accountId: session.accountId,
          body,
          audience,
        },
        select: { id: true, createdAt: true, audience: true },
      });
      if (audience === "SELECTED_MEMBERS") {
        await tx.postAudienceMember.createMany({
          data: selectedIds.map((accountId) => ({ postId: created.id, accountId })),
          skipDuplicates: true,
        });
      }
      await tx.auditEvent.createMany({
        data: {
          actorType: "MEMBER",
          actorId: session.accountId,
          action: "module2.post.created",
          targetType: "member_post",
          targetId: created.id,
          outcome: "success",
          requestId: randomUUID(),
          redactedMetadata: { audience, bodyLength: body.length },
        },
      });
      return created;
    });
    return { post: { id: post.id, audience: post.audience, createdAt: post.createdAt.toISOString() } };
  }

  private async findVisiblePost(accountId: string, postId: string) {
    const post = await this.prisma.memberPost.findFirst({
      where: { id: postId, ...this.postWhere(accountId) },
      select: { id: true, accountId: true, status: true, deletedAt: true },
    });
    if (!post) throw new NotFoundException("This post is unavailable.");
    return post;
  }

  async setPostLike(authorization: string | undefined, postId: string, liked: boolean) {
    const session = await this.requireMember(authorization);
    await this.findVisiblePost(session.accountId, postId);
    if (liked) {
      await this.prisma.memberPostLike.upsert({
        where: { postId_accountId: { postId, accountId: session.accountId } },
        create: { postId, accountId: session.accountId },
        update: {},
      });
    } else {
      await this.prisma.memberPostLike.deleteMany({
        where: { postId, accountId: session.accountId },
      });
    }
    const likeCount = await this.prisma.memberPostLike.count({ where: { postId } });
    return { postId, liked, likeCount };
  }

  async setPostBookmark(authorization: string | undefined, postId: string, saved: boolean) {
    const session = await this.requireMember(authorization);
    await this.findVisiblePost(session.accountId, postId);
    if (saved) {
      await this.prisma.memberPostBookmark.upsert({
        where: { postId_accountId: { postId, accountId: session.accountId } },
        create: { postId, accountId: session.accountId },
        update: {},
      });
    } else {
      await this.prisma.memberPostBookmark.deleteMany({
        where: { postId, accountId: session.accountId },
      });
    }
    return { postId, saved };
  }

  async listComments(authorization: string | undefined, postId: string) {
    const session = await this.requireMember(authorization);
    await this.findVisiblePost(session.accountId, postId);
    const comments = await this.prisma.memberPostComment.findMany({
      where: {
        postId,
        deletedAt: null,
        account: {
          is: {
            status: "ACTIVE",
            verificationStatus: "VERIFIED",
            AND: [
              { NOT: { blockedAccounts: { some: { blockedAccountId: session.accountId } } } },
              { NOT: { blockedByAccounts: { some: { blockerAccountId: session.accountId } } } },
            ],
          },
        },
      },
      include: { account: { include: { profile: { select: profilePublicSelect } } } },
      orderBy: { createdAt: "asc" },
      take: MAX_PAGE_SIZE,
    });
    return {
      comments: comments.map((comment) => ({
        id: comment.id,
        body: comment.body,
        createdAt: comment.createdAt.toISOString(),
        author: {
          accountId: comment.accountId,
          displayName: comment.account.profile?.displayName ?? "Sakhi member",
          profilePhotoRef: comment.account.profile?.profilePhotoRef ?? null,
        },
        isOwnComment: comment.accountId === session.accountId,
      })),
    };
  }

  async createComment(authorization: string | undefined, postId: string, dto: CreatePostCommentDto) {
    const session = await this.requireMember(authorization);
    await this.findVisiblePost(session.accountId, postId);
    const body = dto.body.trim();
    if (!body) throw new BadRequestException("A comment cannot be empty.");
    const comment = await this.prisma.memberPostComment.create({
      data: { postId, accountId: session.accountId, body },
      select: { id: true, createdAt: true },
    });
    await this.recordAudit(session.accountId, "module2.comment.created", "member_post", postId);
    return { id: comment.id, createdAt: comment.createdAt.toISOString() };
  }

  async deleteComment(authorization: string | undefined, commentId: string) {
    const session = await this.requireMember(authorization);
    const comment = await this.prisma.memberPostComment.findFirst({
      where: { id: commentId, accountId: session.accountId, deletedAt: null },
      select: { id: true },
    });
    if (!comment) throw new NotFoundException("This comment is unavailable.");
    await this.prisma.memberPostComment.update({
      where: { id: comment.id },
      data: { body: "[removed]", deletedAt: new Date() },
    });
    return { id: comment.id, removed: true };
  }

  async listFollowers(
    authorization: string | undefined,
    direction: "followers" | "following",
    query = "",
    limit?: string,
  ) {
    const session = await this.requireMember(authorization);
    const take = this.pageSize(limit);
    const normalizedQuery = query.trim().slice(0, 100);
    const where: Prisma.SocialFollowWhereInput =
      direction === "followers"
        ? {
            followingAccountId: session.accountId,
            follower: {
              is: {
                status: "ACTIVE",
                verificationStatus: "VERIFIED",
                profile: { is: { displayName: { contains: normalizedQuery, mode: "insensitive" } } },
                AND: [
                  { NOT: { blockedAccounts: { some: { blockedAccountId: session.accountId } } } },
                  { NOT: { blockedByAccounts: { some: { blockerAccountId: session.accountId } } } },
                ],
                OR: [
                  { privacySettings: { is: null } },
                  { privacySettings: { is: { profileVisibility: "VERIFIED_MEMBERS" } } },
                  {
                    AND: [
                      { privacySettings: { is: { profileVisibility: "FOLLOWERS_ONLY" } } },
                      { followsAsFollowing: { some: { followerAccountId: session.accountId } } },
                    ],
                  },
                ],
              },
            },
          }
        : {
            followerAccountId: session.accountId,
            following: {
              is: {
                status: "ACTIVE",
                verificationStatus: "VERIFIED",
                profile: { is: { displayName: { contains: normalizedQuery, mode: "insensitive" } } },
                AND: [
                  { NOT: { blockedAccounts: { some: { blockedAccountId: session.accountId } } } },
                  { NOT: { blockedByAccounts: { some: { blockerAccountId: session.accountId } } } },
                ],
                OR: [
                  { privacySettings: { is: null } },
                  { privacySettings: { is: { profileVisibility: "VERIFIED_MEMBERS" } } },
                  {
                    AND: [
                      { privacySettings: { is: { profileVisibility: "FOLLOWERS_ONLY" } } },
                      { followsAsFollowing: { some: { followerAccountId: session.accountId } } },
                    ],
                  },
                ],
              },
            },
          };
    const [rows, existingFollowing] = await Promise.all([
      this.prisma.socialFollow.findMany({
        where,
        include: {
          follower: { include: { profile: { select: profilePublicSelect } } },
          following: { include: { profile: { select: profilePublicSelect } } },
        },
        orderBy: { createdAt: "desc" },
        take,
      }),
      this.prisma.socialFollow.findMany({
        where: { followerAccountId: session.accountId },
        select: { followingAccountId: true },
      }),
    ]);
    const followingIds = new Set(existingFollowing.map((row) => row.followingAccountId));
    return {
      members: rows.map((row) => {
        const member = direction === "followers" ? row.follower : row.following;
        return {
          accountId: member.id,
          displayName: member.profile?.displayName ?? "Sakhi member",
          profilePhotoRef: member.profile?.profilePhotoRef ?? null,
          bio: member.profile?.bio ?? null,
          isFollowing: followingIds.has(member.id),
        };
      }),
      direction,
      hasMore: rows.length === take,
    };
  }

  async followMember(authorization: string | undefined, targetAccountId: string) {
    const session = await this.requireMember(authorization);
    if (session.accountId === targetAccountId) {
      throw new BadRequestException("You cannot follow your own account.");
    }
    await this.ensureNotBlocked(session.accountId, targetAccountId);
    const target = await this.prisma.memberAccount.findFirst({
      where: {
        id: targetAccountId,
        status: "ACTIVE",
        verificationStatus: "VERIFIED",
        profile: { isNot: null },
        OR: [
          { privacySettings: { is: null } },
          { privacySettings: { is: { profileVisibility: { not: "ONLY_ME" } } } },
        ],
      },
      select: { id: true },
    });
    if (!target) throw new NotFoundException("This member is unavailable.");
    await this.prisma.socialFollow.upsert({
      where: {
        followerAccountId_followingAccountId: {
          followerAccountId: session.accountId,
          followingAccountId: targetAccountId,
        },
      },
      create: { followerAccountId: session.accountId, followingAccountId: targetAccountId },
      update: {},
    });
    const followersCount = await this.prisma.socialFollow.count({
      where: {
        followingAccountId: targetAccountId,
        follower: { is: { status: "ACTIVE", verificationStatus: "VERIFIED" } },
      },
    });
    return { accountId: targetAccountId, isFollowing: true, followersCount };
  }

  async unfollowMember(authorization: string | undefined, targetAccountId: string) {
    const session = await this.requireMember(authorization);
    await this.prisma.socialFollow.deleteMany({
      where: { followerAccountId: session.accountId, followingAccountId: targetAccountId },
    });
    const followersCount = await this.prisma.socialFollow.count({
      where: {
        followingAccountId: targetAccountId,
        follower: { is: { status: "ACTIVE", verificationStatus: "VERIFIED" } },
      },
    });
    return { accountId: targetAccountId, isFollowing: false, followersCount };
  }

  async getPrivacySettings(authorization?: string) {
    const session = await this.requireMember(authorization);
    await this.ensureDefaultSettings(session.accountId);
    return this.prisma.memberPrivacySettings.findUniqueOrThrow({
      where: { accountId: session.accountId },
    });
  }

  async updatePrivacySettings(
    authorization: string | undefined,
    dto: UpdatePrivacySettingsDto,
  ) {
    const session = await this.requireMember(authorization);
    await this.ensureDefaultSettings(session.accountId);
    if (Object.keys(dto).length === 0) {
      throw new BadRequestException("Provide at least one privacy setting to update.");
    }
    const updated = await this.prisma.memberPrivacySettings.update({
      where: { accountId: session.accountId },
      data: dto,
    });
    await this.recordAudit(session.accountId, "module2.privacy.updated", "member_privacy_settings", session.accountId, "success", {
      fields: Object.keys(dto).join(","),
    });
    return updated;
  }

  async updateMarketingConsent(
    authorization: string | undefined,
    dto: UpdateMarketingConsentDto,
  ) {
    const session = await this.requireMember(authorization);
    const preference = await this.prisma.memberCommunicationPreference.upsert({
      where: { accountId: session.accountId },
      create: {
        accountId: session.accountId,
        productUpdatesAccepted: dto.consentAccepted,
      },
      update: { productUpdatesAccepted: dto.consentAccepted },
      select: { productUpdatesAccepted: true, updatedAt: true },
    });
    if (!dto.consentAccepted) {
      await this.prisma.memberNotificationPreferences.updateMany({
        where: { accountId: session.accountId },
        data: { marketingUpdates: false },
      });
    }
    await this.recordAudit(
      session.accountId,
      "module2.marketing_consent.updated",
      "member_communication_preference",
      session.accountId,
      "success",
      { consentAccepted: dto.consentAccepted },
    );
    return {
      marketingConsentAccepted: preference.productUpdatesAccepted,
      updatedAt: preference.updatedAt.toISOString(),
    };
  }

  async getNotificationPreferences(authorization?: string) {
    const session = await this.requireMember(authorization);
    await this.ensureDefaultSettings(session.accountId);
    const [settings, communication] = await Promise.all([
      this.prisma.memberNotificationPreferences.findUniqueOrThrow({
        where: { accountId: session.accountId },
      }),
      this.prisma.memberCommunicationPreference.findUnique({
        where: { accountId: session.accountId },
        select: { productUpdatesAccepted: true },
      }),
    ]);
    return {
      ...settings,
      marketingConsentAccepted: communication?.productUpdatesAccepted ?? false,
    };
  }

  async updateNotificationPreferences(
    authorization: string | undefined,
    dto: UpdateNotificationPreferencesDto,
  ) {
    const session = await this.requireMember(authorization);
    await this.ensureDefaultSettings(session.accountId);
    if (Object.keys(dto).length === 0) {
      throw new BadRequestException("Provide at least one notification preference to update.");
    }
    if (dto.marketingUpdates === true) {
      const consent = await this.prisma.memberCommunicationPreference.findUnique({
        where: { accountId: session.accountId },
        select: { productUpdatesAccepted: true },
      });
      if (!consent?.productUpdatesAccepted) {
        throw new ConflictException({
          code: "marketing_consent_required",
          message: "Accept the optional product-updates consent before enabling marketing notifications.",
        });
      }
    }
    const updated = await this.prisma.memberNotificationPreferences.update({
      where: { accountId: session.accountId },
      data: dto,
    });
    await this.recordAudit(session.accountId, "module2.notifications.updated", "member_notification_preferences", session.accountId, "success", {
      fields: Object.keys(dto).join(","),
    });
    return updated;
  }

  async listBlockedMembers(authorization?: string) {
    const session = await this.requireMember(authorization);
    const rows = await this.prisma.memberBlock.findMany({
      where: { blockerAccountId: session.accountId },
      include: { blocked: { include: { profile: { select: profilePublicSelect } } } },
      orderBy: { createdAt: "desc" },
      take: MAX_PAGE_SIZE,
    });
    return {
      members: rows.map((row) => ({
        accountId: row.blockedAccountId,
        displayName: row.blocked.profile?.displayName ?? "Sakhi member",
        blockedAt: row.createdAt.toISOString(),
      })),
    };
  }

  async blockMember(authorization: string | undefined, targetAccountId: string) {
    const session = await this.requireMember(authorization);
    if (session.accountId === targetAccountId) throw new BadRequestException("You cannot block your own account.");
    const target = await this.prisma.memberAccount.findFirst({
      where: { id: targetAccountId, status: "ACTIVE", verificationStatus: "VERIFIED" },
      select: { id: true },
    });
    if (!target) throw new NotFoundException("This member is unavailable.");
    await this.prisma.$transaction(async (tx) => {
      await tx.memberBlock.upsert({
        where: { blockerAccountId_blockedAccountId: { blockerAccountId: session.accountId, blockedAccountId: targetAccountId } },
        create: { blockerAccountId: session.accountId, blockedAccountId: targetAccountId },
        update: {},
      });
      await tx.socialFollow.deleteMany({
        where: {
          OR: [
            { followerAccountId: session.accountId, followingAccountId: targetAccountId },
            { followerAccountId: targetAccountId, followingAccountId: session.accountId },
          ],
        },
      });
      await tx.auditEvent.createMany({
        data: {
          actorType: "MEMBER",
          actorId: session.accountId,
          action: "module2.member.blocked",
          targetType: "member_account",
          targetId: targetAccountId,
          outcome: "success",
          requestId: randomUUID(),
        },
      });
    });
    return { accountId: targetAccountId, blocked: true };
  }

  async unblockMember(authorization: string | undefined, targetAccountId: string) {
    const session = await this.requireMember(authorization);
    await this.prisma.memberBlock.deleteMany({
      where: { blockerAccountId: session.accountId, blockedAccountId: targetAccountId },
    });
    return { accountId: targetAccountId, blocked: false };
  }

  async reportMember(authorization: string | undefined, dto: ReportMemberDto) {
    const session = await this.requireMember(authorization);
    if (session.accountId === dto.reportedAccountId) {
      throw new BadRequestException("You cannot report your own account.");
    }
    const target = await this.prisma.memberAccount.findFirst({
      where: { id: dto.reportedAccountId, status: { not: "DELETED" } },
      select: { id: true },
    });
    if (!target) throw new NotFoundException("This member is unavailable.");
    if (dto.postId) {
      const post = await this.prisma.memberPost.findFirst({
        where: { id: dto.postId, accountId: dto.reportedAccountId, deletedAt: null },
        select: { id: true },
      });
      if (!post) throw new NotFoundException("The reported post is unavailable.");
    }
    const report = await this.prisma.memberReport.create({
      data: {
        reporterAccountId: session.accountId,
        reportedAccountId: dto.reportedAccountId,
        postId: dto.postId ?? null,
        reason: dto.reason,
        details: dto.details?.trim() || null,
      },
      select: { id: true, status: true, createdAt: true },
    });
    await this.recordAudit(session.accountId, "module2.member.reported", "member_report", report.id, "submitted", {
      reason: dto.reason,
      postIncluded: Boolean(dto.postId),
    });
    return { reportId: report.id, status: report.status, createdAt: report.createdAt.toISOString() };
  }

  async listGroups(
    authorization: string | undefined,
    options: { mine?: boolean; query?: string; limit?: string } = {},
  ) {
    const session = await this.requireMember(authorization);
    const take = this.pageSize(options.limit);
    const query = options.query?.trim().slice(0, 100);
    const groups = await this.prisma.communityGroup.findMany({
      where: {
        status: "ACTIVE",
        // Blocking must suppress the member's groups from discovery as well
        // as suppressing their feed/profile content.
        creator: {
          is: {
            status: "ACTIVE",
            verificationStatus: "VERIFIED",
            AND: [
              { NOT: { blockedAccounts: { some: { blockedAccountId: session.accountId } } } },
              { NOT: { blockedByAccounts: { some: { blockerAccountId: session.accountId } } } },
            ],
          },
        },
        ...(options.mine
          ? { members: { some: { accountId: session.accountId, status: { in: ["ACTIVE", "PENDING"] } } } }
          : {}),
        ...(query
          ? {
              AND: [{
                OR: [
                  { name: { contains: query, mode: "insensitive" } },
                  { description: { contains: query, mode: "insensitive" } },
                ],
              }],
            }
          : {}),
      },
      include: {
        creator: { include: { profile: { select: profilePublicSelect } } },
        members: {
          where: { accountId: session.accountId },
          select: { accountId: true, role: true, status: true },
          take: 1,
        },
        _count: {
          select: {
            members: {
              where: {
                status: "ACTIVE",
                account: { is: { status: "ACTIVE", verificationStatus: "VERIFIED" } },
              },
            },
            events: { where: { status: "PUBLISHED", startsAt: { gte: new Date() } } },
          },
        },
      },
      orderBy: { createdAt: "desc" },
      take,
    });
    return {
      groups: groups.map((group) => ({
        id: group.id,
        name: group.name,
        slug: group.slug,
        description: group.description,
        visibility: group.visibility,
        createdAt: group.createdAt.toISOString(),
        creator: {
          accountId: group.createdByAccountId,
          displayName: group.creator.profile?.displayName ?? "Sakhi member",
        },
        memberCount: group._count.members,
        upcomingEventsCount: group._count.events,
        membershipStatus: group.members[0]?.status ?? null,
        membershipRole: group.members[0]?.role ?? null,
        isOwner: group.createdByAccountId === session.accountId,
      })),
      limit: take,
    };
  }

  async createGroup(
    authorization: string | undefined,
    dto: CreateCommunityGroupDto,
  ) {
    const session = await this.requireMember(authorization);
    const name = dto.name.trim();
    if (!name) throw new BadRequestException("Group name cannot be blank.");
    const slugBase = name
      .toLowerCase()
      .normalize("NFKD")
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-|-$/g, "")
      .slice(0, 120) || "sakhi-group";
    const slug = slugBase + "-" + randomUUID().slice(0, 8);
    const group = await this.prisma.$transaction(async (tx) => {
      const created = await tx.communityGroup.create({
        data: {
          createdByAccountId: session.accountId,
          name,
          slug,
          description: dto.description?.trim() || null,
          visibility: dto.visibility ?? "VERIFIED_MEMBERS",
          status: "ACTIVE",
        },
      });
      await tx.groupMembership.create({
        data: {
          groupId: created.id,
          accountId: session.accountId,
          role: "OWNER",
          status: "ACTIVE",
        },
      });
      await tx.auditEvent.createMany({
        data: {
          actorType: "MEMBER",
          actorId: session.accountId,
          action: "module2.group.created",
          targetType: "community_group",
          targetId: created.id,
          outcome: "success",
          requestId: randomUUID(),
          redactedMetadata: { visibility: created.visibility },
        },
      });
      return created;
    });
    return { group: { id: group.id, name: group.name, slug: group.slug, visibility: group.visibility, createdAt: group.createdAt.toISOString() } };
  }

  async joinGroup(authorization: string | undefined, groupId: string) {
    const session = await this.requireMember(authorization);
    const group = await this.prisma.communityGroup.findFirst({
      where: { id: groupId, status: "ACTIVE" },
      select: { id: true, visibility: true, createdByAccountId: true },
    });
    if (!group) throw new NotFoundException("This group is unavailable.");
    if (group.createdByAccountId !== session.accountId) {
      await this.ensureNotBlocked(session.accountId, group.createdByAccountId);
    }
    const current = await this.prisma.groupMembership.findUnique({
      where: { groupId_accountId: { groupId, accountId: session.accountId } },
      select: { status: true, role: true },
    });
    if (current) return { groupId, status: current.status, role: current.role, alreadyMember: true };
    const membershipStatus = group.visibility === "PRIVATE" ? "PENDING" : "ACTIVE";
    const membership = await this.prisma.groupMembership.create({
      data: { groupId, accountId: session.accountId, role: "MEMBER", status: membershipStatus },
      select: { status: true, role: true },
    });
    await this.recordAudit(session.accountId, "module2.group.join_requested", "community_group", groupId, "success", { membershipStatus });
    return { groupId, status: membership.status, role: membership.role, alreadyMember: false };
  }

  async leaveGroup(authorization: string | undefined, groupId: string) {
    const session = await this.requireMember(authorization);
    const membership = await this.prisma.groupMembership.findUnique({
      where: { groupId_accountId: { groupId, accountId: session.accountId } },
      select: { role: true, status: true },
    });
    if (!membership) return { groupId, left: true };
    if (membership.role === "OWNER") {
      await this.prisma.communityGroup.update({
        where: { id: groupId },
        data: { status: "ARCHIVED" },
      });
      await this.recordAudit(session.accountId, "module2.group.archived", "community_group", groupId);
      return { groupId, left: true, archived: true };
    }
    await this.prisma.groupMembership.delete({
      where: { groupId_accountId: { groupId, accountId: session.accountId } },
    });
    const wasPending = membership.status === "PENDING";
    await this.recordAudit(
      session.accountId,
      wasPending ? "module2.group.join_request_cancelled" : "module2.group.left",
      "community_group",
      groupId,
    );
    return {
      groupId,
      left: true,
      archived: false,
      requestCancelled: wasPending,
    };
  }

  async listPendingGroupMembers(
    authorization: string | undefined,
    groupId: string,
  ) {
    const session = await this.requireMember(authorization);
    const group = await this.prisma.communityGroup.findFirst({
      where: { id: groupId, status: "ACTIVE" },
      select: { id: true },
    });
    if (!group) throw new NotFoundException("This group is unavailable.");

    const managerMembership = await this.prisma.groupMembership.findFirst({
      where: {
        groupId,
        accountId: session.accountId,
        status: "ACTIVE",
        role: { in: ["OWNER", "MODERATOR"] },
      },
      select: { groupId: true },
    });
    if (!managerMembership) {
      throw new ForbiddenException(
        "Only group owners or moderators can view membership requests.",
      );
    }

    const rows = await this.prisma.groupMembership.findMany({
      where: {
        groupId,
        status: "PENDING",
        account: {
          is: {
            status: "ACTIVE",
            verificationStatus: "VERIFIED",
            AND: [
              { NOT: { blockedAccounts: { some: { blockedAccountId: session.accountId } } } },
              { NOT: { blockedByAccounts: { some: { blockerAccountId: session.accountId } } } },
            ],
          },
        },
      },
      include: { account: { include: { profile: { select: profilePublicSelect } } } },
      orderBy: { createdAt: "asc" },
      take: MAX_PAGE_SIZE,
    });

    return {
      members: rows.map((row) => ({
        accountId: row.accountId,
        displayName: row.account.profile?.displayName ?? "Sakhi member",
        profilePhotoRef: row.account.profile?.profilePhotoRef ?? null,
        bio: row.account.profile?.bio ?? null,
        locationCity: row.account.profile?.locationCity ?? null,
        interests: row.account.profile?.interests ?? [],
        counts: { posts: 0, followers: 0, following: 0 },
        isFollowing: false,
        blockedAt: null,
        requestedAt: row.createdAt.toISOString(),
      })),
    };
  }

  async approveGroupMember(
    authorization: string | undefined,
    groupId: string,
    memberAccountId: string,
  ) {
    const session = await this.requireMember(authorization);
    const ownerMembership = await this.prisma.groupMembership.findFirst({
      where: {
        groupId,
        accountId: session.accountId,
        status: "ACTIVE",
        role: { in: ["OWNER", "MODERATOR"] },
        group: { is: { status: "ACTIVE" } },
      },
      select: { groupId: true },
    });
    if (!ownerMembership) throw new ForbiddenException("Only group owners or moderators can approve membership requests.");
    const target = await this.prisma.groupMembership.updateMany({
      where: {
        groupId,
        accountId: memberAccountId,
        status: "PENDING",
        account: {
          is: {
            status: "ACTIVE",
            verificationStatus: "VERIFIED",
            AND: [
              { NOT: { blockedAccounts: { some: { blockedAccountId: session.accountId } } } },
              { NOT: { blockedByAccounts: { some: { blockerAccountId: session.accountId } } } },
            ],
          },
        },
      },
      data: { status: "ACTIVE" },
    });
    if (target.count === 0) throw new NotFoundException("This pending membership request is unavailable.");
    await this.recordAudit(session.accountId, "module2.group.member_approved", "community_group", groupId, "success", { memberAccountId });
    return { groupId, memberAccountId, status: "ACTIVE" };
  }

  async listEvents(
    authorization: string | undefined,
    query = "",
    limit?: string,
  ) {
    const session = await this.requireMember(authorization);
    const take = this.pageSize(limit);
    const startsAt = new Date();
    const normalized = query.trim().slice(0, 100);
    const events = await this.prisma.communityEvent.findMany({
      where: {
        status: "PUBLISHED",
        endsAt: { gte: startsAt },
        group: {
          is: {
            status: "ACTIVE",
            creator: {
              is: {
                status: "ACTIVE",
                verificationStatus: "VERIFIED",
                AND: [
                  { NOT: { blockedAccounts: { some: { blockedAccountId: session.accountId } } } },
                  { NOT: { blockedByAccounts: { some: { blockerAccountId: session.accountId } } } },
                ],
              },
            },
            OR: [
              { visibility: "VERIFIED_MEMBERS" },
              { members: { some: { accountId: session.accountId, status: "ACTIVE" } } },
            ],
          },
        },
        ...(normalized
          ? {
              OR: [
                { title: { contains: normalized, mode: "insensitive" } },
                { description: { contains: normalized, mode: "insensitive" } },
                { locationCity: { contains: normalized, mode: "insensitive" } },
              ],
            }
          : {}),
      },
      include: {
        group: { select: { id: true, name: true, visibility: true } },
        registrations: { where: { accountId: session.accountId, status: "REGISTERED" }, select: { accountId: true }, take: 1 },
        _count: {
          select: {
            registrations: {
              where: {
                status: "REGISTERED",
                account: { is: { status: "ACTIVE", verificationStatus: "VERIFIED" } },
              },
            },
          },
        },
      },
      orderBy: { startsAt: "asc" },
      take,
    });
    return {
      events: events.map((event) => ({
        id: event.id,
        title: event.title,
        description: event.description,
        locationCity: event.locationCity,
        startsAt: event.startsAt.toISOString(),
        endsAt: event.endsAt.toISOString(),
        group: event.group,
        isRegistered: event.registrations.length > 0,
        registrationCount: event._count.registrations,
      })),
      limit: take,
    };
  }

  async createEvent(authorization: string | undefined, dto: CreateCommunityEventDto) {
    const session = await this.requireMember(authorization);
    const startsAt = new Date(dto.startsAt);
    const endsAt = new Date(dto.endsAt);
    if (!Number.isFinite(startsAt.getTime()) || !Number.isFinite(endsAt.getTime()) || endsAt <= startsAt) {
      throw new BadRequestException("Event end time must be after its start time.");
    }
    if (startsAt <= new Date()) throw new BadRequestException("Events must start in the future.");
    const membership = await this.prisma.groupMembership.findFirst({
      where: {
        groupId: dto.groupId,
        accountId: session.accountId,
        status: "ACTIVE",
        role: { in: ["OWNER", "MODERATOR"] },
        group: { is: { status: "ACTIVE" } },
      },
      select: { groupId: true },
    });
    if (!membership) throw new ForbiddenException("Only a group owner or moderator can publish an event for this group.");
    const event = await this.prisma.communityEvent.create({
      data: {
        groupId: dto.groupId,
        hostAccountId: session.accountId,
        title: dto.title.trim(),
        description: dto.description.trim(),
        locationCity: dto.locationCity?.trim() || null,
        startsAt,
        endsAt,
        status: "PUBLISHED",
      },
      select: { id: true, title: true, startsAt: true, endsAt: true },
    });
    await this.recordAudit(session.accountId, "module2.event.created", "community_event", event.id);
    return { event: { ...event, startsAt: event.startsAt.toISOString(), endsAt: event.endsAt.toISOString() } };
  }

  async registerForEvent(authorization: string | undefined, eventId: string) {
    const session = await this.requireMember(authorization);
    const event = await this.prisma.communityEvent.findFirst({
      where: {
        id: eventId,
        status: "PUBLISHED",
        endsAt: { gte: new Date() },
        group: {
          is: {
            status: "ACTIVE",
            creator: {
              is: {
                status: "ACTIVE",
                verificationStatus: "VERIFIED",
                AND: [
                  { NOT: { blockedAccounts: { some: { blockedAccountId: session.accountId } } } },
                  { NOT: { blockedByAccounts: { some: { blockerAccountId: session.accountId } } } },
                ],
              },
            },
            OR: [
              { visibility: "VERIFIED_MEMBERS" },
              { members: { some: { accountId: session.accountId, status: "ACTIVE" } } },
            ],
          },
        },
      },
      select: { id: true, startsAt: true, groupId: true },
    });
    if (!event) throw new NotFoundException("This event is unavailable.");
    await this.prisma.eventRegistration.upsert({
      where: { eventId_accountId: { eventId, accountId: session.accountId } },
      create: { eventId, accountId: session.accountId, status: "REGISTERED" },
      update: { status: "REGISTERED" },
    });
    await this.recordAudit(session.accountId, "module2.event.registered", "community_event", eventId);
    return { eventId, registered: true };
  }

  async cancelEventRegistration(authorization: string | undefined, eventId: string) {
    const session = await this.requireMember(authorization);
    await this.prisma.eventRegistration.updateMany({
      where: { eventId, accountId: session.accountId, status: "REGISTERED" },
      data: { status: "CANCELLED" },
    });
    return { eventId, registered: false };
  }

  async listVerifiedExperts(authorization: string | undefined, query = "", limit?: string) {
    const session = await this.requireMember(authorization);
    const take = this.pageSize(limit);
    const normalized = query.trim().slice(0, 100);
    const businesses = await this.prisma.businessProfile.findMany({
      where: {
        status: "VERIFIED",
        account: {
          is: {
            status: "ACTIVE",
            verificationStatus: "VERIFIED",
            id: { not: session.accountId },
            AND: [
              { NOT: { blockedAccounts: { some: { blockedAccountId: session.accountId } } } },
              { NOT: { blockedByAccounts: { some: { blockerAccountId: session.accountId } } } },
            ],
          },
        },
        ...(normalized
          ? {
              OR: [
                { displayName: { contains: normalized, mode: "insensitive" } },
                { description: { contains: normalized, mode: "insensitive" } },
              ],
            }
          : {}),
      },
      include: { account: { include: { profile: { select: profilePublicSelect } } } },
      orderBy: { updatedAt: "desc" },
      take,
    });
    return {
      experts: businesses.map((business) => ({
        accountId: business.accountId,
        businessName: business.displayName,
        description: business.description,
        websiteUrl: business.websiteUrl,
        displayName: business.account.profile?.displayName ?? "Verified professional",
        profilePhotoRef: business.account.profile?.profilePhotoRef ?? null,
      })),
      limit: take,
    };
  }

  async getBusinessProfile(authorization?: string) {
    const session = await this.requireMember(authorization);
    return {
      businessProfile: await this.prisma.businessProfile.findUnique({
        where: { accountId: session.accountId },
      }),
    };
  }

  async upsertBusinessProfile(
    authorization: string | undefined,
    dto: CreateBusinessProfileDto,
  ) {
    const session = await this.requireMember(authorization);
    const websiteUrl = dto.websiteUrl?.trim() || null;
    if (websiteUrl && new URL(websiteUrl).protocol !== "https:") {
      throw new BadRequestException("Business profile websites must use HTTPS.");
    }
    const businessProfile = await this.prisma.businessProfile.upsert({
      where: { accountId: session.accountId },
      create: {
        accountId: session.accountId,
        displayName: dto.displayName.trim(),
        description: dto.description?.trim() || null,
        websiteUrl,
        status: "PENDING_REVIEW",
      },
      update: {
        displayName: dto.displayName.trim(),
        description: dto.description?.trim() || null,
        websiteUrl,
        status: "PENDING_REVIEW",
      },
    });
    await this.recordAudit(session.accountId, "module2.business_profile.updated", "business_profile", session.accountId, "submitted");
    return { businessProfile, message: "Business profile submitted for review; it is not yet verified." };
  }

  async listSessions(authorization?: string) {
    const session = await this.requireMember(authorization);
    const currentDigest = this.tokenDigest(authorization);
    const rows = await this.prisma.authSession.findMany({
      where: { accountId: session.accountId },
      select: {
        id: true,
        createdAt: true,
        expiresAt: true,
        revokedAt: true,
        lastSeenAt: true,
      },
      orderBy: { createdAt: "desc" },
      take: 25,
    });
    const current = await this.prisma.authSession.findUnique({
      where: { tokenDigest: currentDigest },
      select: { id: true },
    });
    return {
      sessions: rows.map((row) => ({
        id: row.id,
        createdAt: row.createdAt.toISOString(),
        expiresAt: row.expiresAt.toISOString(),
        lastSeenAt: row.lastSeenAt?.toISOString() ?? null,
        revokedAt: row.revokedAt?.toISOString() ?? null,
        isCurrent: row.id === current?.id,
        isActive: row.revokedAt === null && row.expiresAt > new Date(),
      })),
    };
  }

  async revokeSession(authorization: string | undefined, sessionId: string) {
    const session = await this.requireMember(authorization);
    const owned = await this.prisma.authSession.findFirst({
      where: { id: sessionId, accountId: session.accountId },
      select: { id: true, revokedAt: true, tokenDigest: true },
    });
    if (!owned) throw new NotFoundException("This login session is unavailable.");
    const currentDigest = this.tokenDigest(authorization);
    const isCurrent = owned.tokenDigest === currentDigest;
    if (!owned.revokedAt) {
      await this.prisma.authSession.update({
        where: { id: owned.id },
        data: { revokedAt: new Date() },
      });
      await this.recordAudit(session.accountId, "module2.session.revoked", "auth_session", owned.id);
    }
    return { sessionId: owned.id, revoked: true, currentSession: isCurrent };
  }

  async deactivateAccount(authorization?: string) {
    const session = await this.requireMember(authorization);
    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      await tx.memberAccount.update({
        where: { id: session.accountId },
        data: { status: "SUSPENDED" },
      });
      await tx.authSession.updateMany({
        where: { accountId: session.accountId, revokedAt: null },
        data: { revokedAt: now },
      });
      await tx.memberPost.updateMany({
        where: { accountId: session.accountId, status: "PUBLISHED" },
        data: { status: "HIDDEN" },
      });
      await tx.auditEvent.createMany({
        data: {
          actorType: "MEMBER",
          actorId: session.accountId,
          action: "module2.account.deactivated",
          targetType: "member_account",
          targetId: session.accountId,
          outcome: "success",
          requestId: randomUUID(),
        },
      });
    });
    return {
      status: "SUSPENDED",
      sessionsRevoked: true,
      message: "Your account is deactivated and hidden. Contact Sakhi support to reactivate it.",
    };
  }

  async requestAccountDeletion(
    authorization: string | undefined,
    dto: RequestAccountDeletionDto,
  ) {
    const session = await this.requireMember(authorization);
    const now = new Date();
    const deletionRequest = await this.prisma.$transaction(async (tx) => {
      const existing = await tx.accountDeletionRequest.findFirst({
        where: { accountId: session.accountId, status: { in: ["REQUESTED", "PROCESSING"] } },
        select: { id: true, status: true, requestedAt: true },
      });
      if (existing) return existing;

      const request = await tx.accountDeletionRequest.create({
        data: {
          accountId: session.accountId,
          status: "REQUESTED",
          requestReason: dto.reason?.trim() || null,
        },
        select: { id: true, status: true, requestedAt: true },
      });
      // Disable access immediately and scrub profile/post content while retaining
      // a request/audit trail for the configured retention process.
      await tx.memberAccount.update({
        where: { id: session.accountId },
        data: {
          status: "DELETED",
          phoneE164: `+999${session.accountId.replaceAll("-", "").slice(0, 12)}`,
          phoneVerifiedAt: null,
        },
      });
      await tx.memberProfile.update({
        where: { accountId: session.accountId },
        data: {
          displayName: "Deleted member",
          dateOfBirth: new Date("1970-01-01T00:00:00.000Z"),
          email: null,
          profilePhotoRef: null,
          bio: null,
          locationCity: null,
          interests: [],
        },
      });
      await tx.memberPost.updateMany({
        where: { accountId: session.accountId, deletedAt: null },
        data: {
          status: "REMOVED",
          body: "[removed by account deletion request]",
          mediaRef: null,
          deletedAt: now,
        },
      });
      await tx.memberPostComment.updateMany({
        where: { accountId: session.accountId, deletedAt: null },
        data: { body: "[removed]", deletedAt: now },
      });
      // Comments on the deleted member's own posts lose their content context
      // when the parent post is scrubbed, so scrub them in the same transaction.
      await tx.memberPostComment.updateMany({
        where: {
          post: { is: { accountId: session.accountId } },
          deletedAt: null,
        },
        data: { body: "[removed]", deletedAt: now },
      });
      // Remove all social graph and engagement records tied to this account or
      // to its now-removed posts instead of leaving ghost counts behind.
      await tx.memberPostLike.deleteMany({
        where: {
          OR: [
            { accountId: session.accountId },
            { post: { is: { accountId: session.accountId } } },
          ],
        },
      });
      await tx.memberPostBookmark.deleteMany({
        where: {
          OR: [
            { accountId: session.accountId },
            { post: { is: { accountId: session.accountId } } },
          ],
        },
      });
      await tx.socialFollow.deleteMany({
        where: {
          OR: [
            { followerAccountId: session.accountId },
            { followingAccountId: session.accountId },
          ],
        },
      });
      await tx.memberBlock.deleteMany({
        where: {
          OR: [
            { blockerAccountId: session.accountId },
            { blockedAccountId: session.accountId },
          ],
        },
      });
      await tx.eventRegistration.deleteMany({
        where: { accountId: session.accountId },
      });
      await tx.communityEvent.updateMany({
        where: {
          status: "PUBLISHED",
          group: { is: { createdByAccountId: session.accountId } },
        },
        data: { status: "CANCELLED" },
      });
      await tx.communityGroup.updateMany({
        where: { createdByAccountId: session.accountId, status: "ACTIVE" },
        data: { status: "ARCHIVED" },
      });
      await tx.groupMembership.deleteMany({
        where: { accountId: session.accountId },
      });
      await tx.businessProfile.deleteMany({
        where: { accountId: session.accountId },
      });
      await tx.memberPrivacySettings.deleteMany({
        where: { accountId: session.accountId },
      });
      await tx.memberNotificationPreferences.deleteMany({
        where: { accountId: session.accountId },
      });
      await tx.memberCommunicationPreference.deleteMany({
        where: { accountId: session.accountId },
      });
      await tx.authSession.updateMany({
        where: { accountId: session.accountId, revokedAt: null },
        data: { revokedAt: now },
      });
      await tx.auditEvent.createMany({
        data: {
          actorType: "MEMBER",
          actorId: session.accountId,
          action: "module2.account.deletion_requested",
          targetType: "account_deletion_request",
          targetId: request.id,
          outcome: "requested",
          requestId: randomUUID(),
          redactedMetadata: { profileScrubbed: true, sessionsRevoked: true },
        },
      });
      return request;
    });
    return {
      requestId: deletionRequest.id,
      status: deletionRequest.status,
      requestedAt: deletionRequest.requestedAt.toISOString(),
      message: "Access is disabled and profile content is scrubbed. Permanent erasure of retained audit/legal records is completed by Sakhi's approved retention process.",
    };
  }
}
