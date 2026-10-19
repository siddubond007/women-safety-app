import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { randomUUID } from "node:crypto";
import { AuthenticationService } from "../auth/auth.service.js";
import { PrismaService } from "../database/prisma.service.js";
import { GoogleDriveStorageService } from "./google-drive-storage.service.js";
import type {
  CreateCommunityPostDto,
  CreateEmergencyContactDto,
  CreatePostCommentDto,
  RecordSafetyEventDto,
  ReportUserOrPostDto,
  RequestMediaUploadDto,
  ToggleBlockedUserDto,
  ToggleTwoFactorDto,
  UpdateAvatarDto,
  UpdateModule2ProfileDto,
  UpdateNotificationPreferenceDto,
  UpdatePrivacyPreferenceDto,
  UpdateSecurityPinDto,
  UploadMediaObjectDto,
  UploadBinaryMediaDto,
} from "./module2.dto.js";

const DEFAULT_INTERESTS = [
  "Mental Wellness",
  "Travel",
  "Reading",
  "WomenInTech",
  "Art",
  "Fitness",
];

const BASE_FOLLOWERS_COUNT = 560;
const BASE_FOLLOWING_COUNT = 310;
const BASE_POSTS_COUNT = 123;

export const SEEDED_COMMUNITY_MEMBERS = [
  {
    phoneE164: "+919999992222",
    displayName: "Siddhu",
    username: "@siddhu",
    avatarAsset: "assets/images/profile/avatar_siddhu.webp",
    bio: "A passionate learner, exploring wellness, technology and meaningful connections. 💜",
    location: "Bangalore, India",
    email: "siddhu@sakhi.dev",
    status: "ACTIVE" as const,
    verificationStatus: "VERIFIED" as const,
    defaultFollowing: false,
    interests: ["Mental Wellness", "Travel", "Reading", "WomenInTech", "Art", "Fitness"],
  },
  {
    phoneE164: "+919845010101",
    displayName: "Ananya Rao",
    username: "@ananya",
    avatarAsset: "assets/images/profile/avatar_ananya.webp",
    bio: "Mental wellness advocate, peer counselor & Hyderabad community builder 🌸",
    location: "Hyderabad, India",
    email: "ananya.rao@sakhi.dev",
    status: "ACTIVE" as const,
    verificationStatus: "VERIFIED" as const,
    defaultFollowing: true,
    interests: ["Mental Wellness", "Mindfulness", "Peer Support", "Reading"],
  },
  {
    phoneE164: "+919845010102",
    displayName: "Dr. Meera Iyer",
    username: "@meera",
    avatarAsset: "assets/images/profile/avatar_meera.webp",
    bio: "Mindfulness coach & clinical breathwork guide helping women reset daily ✨",
    location: "Chennai, India",
    email: "meera.iyer@sakhi.dev",
    status: "ACTIVE" as const,
    verificationStatus: "VERIFIED" as const,
    defaultFollowing: true,
    interests: ["Mental Wellness", "Meditation", "Fitness", "Yoga"],
  },
  {
    phoneE164: "+919845010103",
    displayName: "Kavya Nair",
    username: "@kavya",
    avatarAsset: "assets/images/profile/avatar_kavya.webp",
    bio: "Evening walks, botanical art & slow mindful living by the coast 🌿",
    location: "Kochi, India",
    email: "kavya.nair@sakhi.dev",
    status: "ACTIVE" as const,
    verificationStatus: "VERIFIED" as const,
    defaultFollowing: false,
    interests: ["Art", "Travel", "Photography", "Mental Wellness"],
  },
  {
    phoneE164: "+919845010104",
    displayName: "Ishita Reddy",
    username: "@ishita",
    avatarAsset: "assets/images/profile/avatar_ishita.webp",
    bio: "Staff cloud architect, WomenInTech mentor & community safety lead 💻🛡️",
    location: "Bangalore, India",
    email: "ishita.reddy@sakhi.dev",
    status: "ACTIVE" as const,
    verificationStatus: "VERIFIED" as const,
    defaultFollowing: true,
    interests: ["WomenInTech", "Career", "Safety", "Mentorship"],
  },
  {
    phoneE164: "+919845010105",
    displayName: "Priya Sharma",
    username: "@priya",
    avatarAsset: "assets/images/profile/avatar_priya.webp",
    bio: "Strength coach & cycle-synced hormonal nutrition researcher 🥗💪",
    location: "Mumbai, India",
    email: "priya.sharma@sakhi.dev",
    status: "ACTIVE" as const,
    verificationStatus: "VERIFIED" as const,
    defaultFollowing: true,
    interests: ["Fitness", "Nutrition", "Menstrual Health", "Wellness"],
  },
  {
    phoneE164: "+919845010106",
    displayName: "Sneha Verma",
    username: "@sneha",
    avatarAsset: "assets/images/profile/avatar_sneha.webp",
    bio: "Sunday book club host, poet & creative journaling enthusiast 📚🌸",
    location: "Pune, India",
    email: "sneha.verma@sakhi.dev",
    status: "PENDING_VERIFICATION" as const,
    verificationStatus: "UNVERIFIED" as const,
    defaultFollowing: false,
    interests: ["Reading", "Art", "Creative Writing", "Mental Wellness"],
  },
  {
    phoneE164: "+919845010107",
    displayName: "Riya Deshmukh",
    username: "@riya",
    avatarAsset: "assets/images/profile/avatar_ananya.webp",
    bio: "Solo traveler, campus safety coordinator & self-defense workshop host 🛡️",
    location: "New Delhi, India",
    email: "riya.deshmukh@sakhi.dev",
    status: "PENDING_VERIFICATION" as const,
    verificationStatus: "UNVERIFIED" as const,
    defaultFollowing: false,
    interests: ["Travel", "Safety", "Community", "Fitness"],
  },
];

@Injectable()
export class Module2Service {
  constructor(
    private readonly auth: AuthenticationService,
    private readonly prisma: PrismaService,
    private readonly googleDrive: GoogleDriveStorageService = new GoogleDriveStorageService(),
  ) {}

  private formatRelativeTime(createdAt: Date): string {
    const diffMs = Math.max(0, Date.now() - createdAt.getTime());
    const minutes = Math.floor(diffMs / 60_000);
    if (minutes < 1) return "Just now";
    if (minutes < 60) return `${minutes} min ago`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours} ${hours === 1 ? "hour" : "hours"} ago`;
    const days = Math.floor(hours / 24);
    return `${days} ${days === 1 ? "day" : "days"} ago`;
  }

  private maskPhone(phoneE164: string): string {
    if (phoneE164.startsWith("+91") && phoneE164.length >= 7) {
      return `+91 ••••••${phoneE164.slice(-4)}`;
    }
    return phoneE164.length > 4
      ? `••••••${phoneE164.slice(-4)}`
      : phoneE164;
  }

  private parseInterests(raw: unknown): string[] {
    if (Array.isArray(raw)) {
      const items = raw
        .filter((item): item is string => typeof item === "string")
        .map((item) => item.trim())
        .filter((item) => item.length > 0);
      if (items.length > 0) return items;
    }
    return [...DEFAULT_INTERESTS];
  }

  private deriveUsername(displayName: string, existingUsername?: string | null): string {
    if (existingUsername && existingUsername.trim().length > 0) {
      return existingUsername.startsWith("@")
        ? existingUsername.trim()
        : `@${existingUsername.trim()}`;
    }
    const slug = displayName
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "")
      .slice(0, 20);
    return `@${slug || "siddhu"}`;
  }

  async ensureDefaultCatalogSeeded(preferredAccountId?: string): Promise<void> {
    // 1. Ensure all 8 realistic community members exist as real MemberAccount + MemberProfile + CommunityDirectoryProfile rows
    const accountIdByUsername = new Map<string, string>();
    for (const member of SEEDED_COMMUNITY_MEMBERS) {
      try {
        const acc = await this.prisma.memberAccount.upsert({
          where: { phoneE164: member.phoneE164 },
          update: {},
          create: {
            phoneE164: member.phoneE164,
            phoneVerifiedAt: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000),
            status: member.status,
            verificationStatus: member.verificationStatus,
          },
          select: { id: true, status: true, verificationStatus: true },
        });
        accountIdByUsername.set(member.username, acc.id);

        await this.prisma.memberProfile.upsert({
          where: { accountId: acc.id },
          update: {
            username: member.username,
            avatarAsset: member.avatarAsset,
          },
          create: {
            accountId: acc.id,
            displayName: member.displayName,
            username: member.username,
            bio: member.bio,
            location: member.location,
            avatarAsset: member.avatarAsset,
            interests: member.interests,
            email: member.email,
            dateOfBirth: new Date("1999-06-15T00:00:00.000Z"),
          },
        });

        if (member.username !== "@siddhu") {
          await this.prisma.communityDirectoryProfile.upsert({
            where: { username: member.username },
            update: {
              name: member.displayName,
              avatarAsset: member.avatarAsset,
              bio: member.bio,
              defaultFollowing: member.defaultFollowing,
            },
            create: {
              name: member.displayName,
              username: member.username,
              avatarAsset: member.avatarAsset,
              bio: member.bio,
              defaultFollowing: member.defaultFollowing,
            },
          });
        }

        // Ensure pending members have an active EligibilitySubmission in the Super Admin queue
        if (acc.verificationStatus === "UNVERIFIED") {
          const existingSub = await this.prisma.eligibilitySubmission.findFirst({
            where: { accountId: acc.id, status: "PENDING_MANUAL_REVIEW" },
            select: { id: true },
          });
          if (!existingSub) {
            await this.prisma.eligibilitySubmission.create({
              data: {
                accountId: acc.id,
                status: "PENDING_MANUAL_REVIEW",
                consentVersion: "dev-manual-review-v1",
                consentAcceptedAt: new Date(Date.now() - 2 * 60 * 60 * 1000),
              },
            });
          }
        }
      } catch {
        // Ignore individual duplicate conflicts during concurrent requests
      }
    }

    // 2. Ensure 4 active Community Groups exist
    const defaultGroups = [
      {
        name: "Women in Tech Bangalore",
        description: "1.4k members • System design, cloud careers & mentorship",
        category: "Education & Career",
        membersCount: 1420,
        newPostsToday: 5,
      },
      {
        name: "Mindful Mornings Circle",
        description: "820 members • Daily breathwork & emotional grounding",
        category: "Health & Wellness",
        membersCount: 820,
        newPostsToday: 4,
      },
      {
        name: "Safe Solo Travelers India",
        description: "640 members • Verified city guides & SOS check-in buddies",
        category: "Safety & Travel",
        membersCount: 640,
        newPostsToday: 3,
      },
      {
        name: "PCOS & Hormonal Wellness Hub",
        description: "950 members • Doctor Q&As, cycle nutrition & strength",
        category: "Health & Wellness",
        membersCount: 950,
        newPostsToday: 6,
      },
    ];
    for (const group of defaultGroups) {
      await this.prisma.communityGroup.upsert({
        where: { name: group.name },
        update: group,
        create: group,
      });
    }

    // 3. Ensure Wellness Resources exist
    const defaultWellness = [
      {
        slug: "menstrual-health",
        category: "menstrual_health",
        title: "Menstrual Health",
        subtitle: "Cycle care guides, symptom tracking & doctor Q&As",
        durationLabel: "4 guides",
        thumbAsset: "assets/images/wellness/wellness_hero_illustration.webp",
      },
      {
        slug: "mental-wellness",
        category: "mental_wellness",
        title: "Mental Wellness",
        subtitle: "Daily grounding rituals, stress relief & peer support",
        durationLabel: "6 exercises",
        thumbAsset: "assets/images/community/breathing_exercise_illustration.webp",
      },
      {
        slug: "fitness-nutrition",
        category: "fitness_nutrition",
        title: "Fitness & Nutrition",
        subtitle: "Balanced strength routines & nourishing meal ideas",
        durationLabel: "5 plans",
        thumbAsset: "assets/images/wellness/wellness_hero_illustration.webp",
      },
      {
        slug: "expert-articles",
        category: "expert_articles",
        title: "Expert Articles",
        subtitle: "Evidence-based women's health & safety columns",
        durationLabel: "8 articles",
        thumbAsset: "assets/images/wellness/wellness_hero_illustration.webp",
      },
      {
        slug: "guided-meditation-pick",
        category: "todays_pick",
        title: "Guided Meditation",
        subtitle: "10 min • Audio",
        durationLabel: "10 min • Audio",
        thumbAsset: "assets/images/wellness/guided_meditation_thumb.webp",
      },
    ];
    for (const item of defaultWellness) {
      await this.prisma.wellnessResource.upsert({
        where: { slug: item.slug },
        update: item,
        create: item,
      });
    }

    // 4. Upsert 11 rich, unmistakably live PostgreSQL Community, Explore, and Profile posts
    const siddhuId =
      preferredAccountId ??
      accountIdByUsername.get("@siddhu") ??
      null;

    const livePosts = [
      {
        id: "11111111-1111-4111-8111-111111111105",
        authorAccountId: accountIdByUsername.get("@ananya") ?? null,
        authorName: "Ananya Rao",
        authorUsername: "@ananya",
        authorAvatar: "assets/images/profile/avatar_ananya.webp",
        authorVerified: true,
        content:
          "Morning check-in from Hyderabad! 🌸 Our peer support circle just crossed 600 verified women on Sakhi. Remember to drink water, unclench your shoulders, and take 3 slow breaths today. 💜",
        imageAsset: "assets/images/community/evening_walk_sunset.webp",
        categoryBadge: "Live DB • Wellness",
        feedSection: "community",
        hasBreathingExerciseCard: false,
        likesCount: 184,
        commentsCount: 27,
        createdAt: new Date(Date.now() - 25 * 60 * 1000),
      },
      {
        id: "11111111-1111-4111-8111-111111111106",
        authorAccountId: accountIdByUsername.get("@ishita") ?? null,
        authorName: "Ishita Reddy",
        authorUsername: "@ishita",
        authorAvatar: "assets/images/profile/avatar_ishita.webp",
        authorVerified: true,
        content:
          "Hosting our Saturday Women in Tech Bangalore mentorship session at 11 AM! 💻✨ We are reviewing backend architecture, cloud storage pipelines, and portfolio projects. Drop a comment to join!",
        imageAsset: null,
        categoryBadge: "WomenInTech",
        feedSection: "community",
        hasBreathingExerciseCard: false,
        likesCount: 165,
        commentsCount: 34,
        createdAt: new Date(Date.now() - 75 * 60 * 1000),
      },
      {
        id: "11111111-1111-4111-8111-111111111101",
        authorAccountId: accountIdByUsername.get("@kavya") ?? null,
        authorName: "Kavya Nair",
        authorUsername: "@kavya",
        authorAvatar: "assets/images/profile/avatar_kavya.webp",
        authorVerified: true,
        content:
          "A peaceful evening walk by the Kochi backwaters 🌸\nTaking 20 minutes away from screens every evening helps me reset. Stay kind, stay strong! 💜",
        imageAsset: "assets/images/community/evening_walk_sunset.webp",
        categoryBadge: "Self-Care",
        feedSection: "community",
        hasBreathingExerciseCard: false,
        likesCount: 124,
        commentsCount: 18,
        createdAt: new Date(Date.now() - 3 * 60 * 60 * 1000),
      },
      {
        id: "11111111-1111-4111-8111-111111111102",
        authorAccountId: accountIdByUsername.get("@meera") ?? null,
        authorName: "Dr. Meera Iyer",
        authorUsername: "@meera",
        authorAvatar: "assets/images/profile/avatar_meera.webp",
        authorVerified: true,
        content:
          "Here are 5 simple 4-7-8 clinical breathing exercises that calm cortisol spikes during stressful days.",
        imageAsset: null,
        categoryBadge: "Wellness",
        feedSection: "community",
        hasBreathingExerciseCard: true,
        likesCount: 142,
        commentsCount: 19,
        createdAt: new Date(Date.now() - 4 * 60 * 60 * 1000),
      },
      {
        id: "11111111-1111-4111-8111-111111111107",
        authorAccountId: accountIdByUsername.get("@priya") ?? null,
        authorName: "Priya Sharma",
        authorUsername: "@priya",
        authorAvatar: "assets/images/profile/avatar_priya.webp",
        authorVerified: true,
        content:
          "Cycle-synced nutrition tip: pairing iron-rich greens with citrus during your luteal phase boosts energy naturally without afternoon caffeine crashes! 🥗💪",
        imageAsset: "assets/images/wellness/wellness_hero_illustration.webp",
        categoryBadge: "Fitness & Nutrition",
        feedSection: "community",
        hasBreathingExerciseCard: false,
        likesCount: 112,
        commentsCount: 15,
        createdAt: new Date(Date.now() - 6 * 60 * 60 * 1000),
      },
      {
        id: "11111111-1111-4111-8111-111111111108",
        authorAccountId: accountIdByUsername.get("@sneha") ?? null,
        authorName: "Sneha Verma",
        authorUsername: "@sneha",
        authorAvatar: "assets/images/profile/avatar_sneha.webp",
        authorVerified: false,
        content:
          "Our Sakhi Sunday Reading Circle is picking our next mindfulness + fiction read in Pune 📚🌸 Which book helped you most during a life transition?",
        imageAsset: null,
        categoryBadge: "Book Club",
        feedSection: "community",
        hasBreathingExerciseCard: false,
        likesCount: 78,
        commentsCount: 22,
        createdAt: new Date(Date.now() - 9 * 60 * 60 * 1000),
      },
      {
        id: "11111111-1111-4111-8111-111111111103",
        authorAccountId: accountIdByUsername.get("@ananya") ?? null,
        authorName: "Ananya Rao",
        authorUsername: "@ananya",
        authorAvatar: "assets/images/profile/avatar_ananya.webp",
        authorVerified: true,
        content:
          "Small steps every day make a big difference in your mental wellness and emotional boundaries. 💜",
        imageAsset: "assets/images/explore/beach_sunset.webp",
        categoryBadge: "Trending",
        feedSection: "explore",
        hasBreathingExerciseCard: false,
        likesCount: 196,
        commentsCount: 24,
        createdAt: new Date(Date.now() - 2 * 60 * 60 * 1000),
      },
      {
        id: "11111111-1111-4111-8111-111111111109",
        authorAccountId: accountIdByUsername.get("@riya") ?? null,
        authorName: "Riya Deshmukh",
        authorUsername: "@riya",
        authorAvatar: "assets/images/profile/avatar_ananya.webp",
        authorVerified: false,
        content:
          "Solo evening commute checklist: share your live Sakhi SOS route with 2 trusted contacts and keep 112 / 181 active on your quick-action tile. 🛡️",
        imageAsset: "assets/images/safety/safety_map_preview.webp",
        categoryBadge: "Safety Tips",
        feedSection: "explore",
        hasBreathingExerciseCard: false,
        likesCount: 154,
        commentsCount: 16,
        createdAt: new Date(Date.now() - 5 * 60 * 60 * 1000),
      },
      {
        id: "11111111-1111-4111-8111-111111111110",
        authorAccountId: accountIdByUsername.get("@meera") ?? null,
        authorName: "Dr. Meera Iyer",
        authorUsername: "@meera",
        authorAvatar: "assets/images/profile/avatar_meera.webp",
        authorVerified: true,
        content:
          "10-minute evening body scan meditation for deep, restorative sleep — now available in the Wellness Hub. 🌙✨",
        imageAsset: "assets/images/wellness/guided_meditation_thumb.webp",
        categoryBadge: "Guided Audio",
        feedSection: "explore",
        hasBreathingExerciseCard: false,
        likesCount: 131,
        commentsCount: 11,
        createdAt: new Date(Date.now() - 8 * 60 * 60 * 1000),
      },
      {
        id: "11111111-1111-4111-8111-111111111104",
        authorAccountId: siddhuId,
        authorName: "Siddhu",
        authorUsername: "@siddhu",
        authorAvatar: "assets/images/profile/avatar_siddhu.webp",
        authorVerified: true,
        content:
          "Grateful for the little moments that bring peace and the inspiring women building this Sakhi community together. 🌸💜",
        imageAsset: "assets/images/community/evening_walk_sunset.webp",
        categoryBadge: "Community",
        feedSection: "profile",
        hasBreathingExerciseCard: false,
        likesCount: 94,
        commentsCount: 14,
        createdAt: new Date(Date.now() - 24 * 60 * 60 * 1000),
      },
      {
        id: "11111111-1111-4111-8111-111111111111",
        authorAccountId: siddhuId,
        authorName: "Siddhu",
        authorUsername: "@siddhu",
        authorAvatar: "assets/images/profile/avatar_siddhu.webp",
        authorVerified: true,
        content:
          "Connected our Sakhi mobile app to live PostgreSQL database feeds, Super Admin member verification, and Cloud Media uploads! 🚀✨",
        imageAsset: null,
        categoryBadge: "WomenInTech",
        feedSection: "profile",
        hasBreathingExerciseCard: false,
        likesCount: 82,
        commentsCount: 12,
        createdAt: new Date(Date.now() - 12 * 60 * 60 * 1000),
      },
    ];

    for (const post of livePosts) {
      await this.prisma.communityPost.upsert({
        where: { id: post.id },
        update: {
          authorName: post.authorName,
          authorUsername: post.authorUsername,
          authorVerified: post.authorVerified,
          content: post.content,
          imageAsset: post.imageAsset,
          categoryBadge: post.categoryBadge,
          feedSection: post.feedSection,
          hasBreathingExerciseCard: post.hasBreathingExerciseCard,
        },
        create: post,
      });
    }
  }

  async publicFeed() {
    await this.ensureDefaultCatalogSeeded();
    const [allPosts, directoryProfiles, groups, wellnessResources, totalMembers] =
      await Promise.all([
        this.prisma.communityPost.findMany({
          orderBy: { createdAt: "desc" },
          take: 50,
        }),
        this.prisma.communityDirectoryProfile.findMany({
          orderBy: { createdAt: "asc" },
        }),
        this.prisma.communityGroup.findMany({
          orderBy: { membersCount: "desc" },
        }),
        this.prisma.wellnessResource.findMany({
          orderBy: { createdAt: "asc" },
        }),
        this.prisma.memberAccount.count(),
      ]);

    const mappedPosts = allPosts.map((post) => ({
      id: post.id,
      authorName: post.authorName,
      authorUsername: post.authorUsername,
      authorAvatar: post.authorAvatar,
      authorVerified: post.authorVerified,
      timestamp: this.formatRelativeTime(post.createdAt),
      content: post.content,
      imageAsset: post.imageAsset,
      categoryBadge: post.categoryBadge,
      feedSection: post.feedSection,
      hasBreathingExerciseCard: post.hasBreathingExerciseCard,
      likesCount: post.likesCount,
      commentsCount: post.commentsCount,
      isLiked: false,
      isSaved: false,
    }));

    return {
      source: "postgresql_live" as const,
      totalDatabaseMembers: totalMembers,
      totalDatabasePosts: allPosts.length,
      communityPosts: mappedPosts.filter((p) => p.feedSection === "community"),
      exploreRecommendedPosts: mappedPosts.filter((p) => p.feedSection === "explore"),
      profilePosts: mappedPosts.filter((p) => p.feedSection === "profile"),
      groups: groups.map((g) => ({
        id: g.id,
        name: g.name,
        description: g.description,
        category: g.category,
        membersCount: g.membersCount,
        newPostsToday: g.newPostsToday,
      })),
      followers: directoryProfiles.map((dir) => ({
        id: dir.id,
        name: dir.name,
        username: dir.username,
        avatarAsset: dir.avatarAsset,
        bio: dir.bio,
        isFollowing: dir.defaultFollowing,
      })),
      wellnessResources: wellnessResources.map((w) => ({
        id: w.id,
        slug: w.slug,
        category: w.category,
        title: w.title,
        subtitle: w.subtitle,
        durationLabel: w.durationLabel,
        thumbAsset: w.thumbAsset,
      })),
    };
  }

  async bootstrap(authorization?: string) {
    const session = await this.auth.authenticateAuthorization(authorization);
    await this.ensureDefaultCatalogSeeded(session.accountId);

    const [
      profile,
      privacyPref,
      notificationPref,
      allPosts,
      userLikes,
      userSaves,
      directoryProfiles,
      userFollows,
      groups,
      wellnessResources,
      emergencyContacts,
      blockedUsers,
      activeSessionsCount,
      totalDatabaseMembers,
    ] = await Promise.all([
      this.prisma.memberProfile.findUnique({
        where: { accountId: session.accountId },
      }),
      this.prisma.memberPrivacyPreference.findUnique({
        where: { accountId: session.accountId },
      }),
      this.prisma.memberNotificationPreference.findUnique({
        where: { accountId: session.accountId },
      }),
      this.prisma.communityPost.findMany({
        orderBy: { createdAt: "desc" },
        take: 50,
      }),
      this.prisma.communityPostLike.findMany({
        where: { accountId: session.accountId },
        select: { postId: true },
      }),
      this.prisma.communityPostSave.findMany({
        where: { accountId: session.accountId },
        select: { postId: true },
      }),
      this.prisma.communityDirectoryProfile.findMany({
        orderBy: { createdAt: "asc" },
      }),
      this.prisma.memberFollow.findMany({
        where: { accountId: session.accountId },
      }),
      this.prisma.communityGroup.findMany({
        orderBy: { membersCount: "desc" },
      }),
      this.prisma.wellnessResource.findMany({
        orderBy: { createdAt: "asc" },
      }),
      this.prisma.safetyEmergencyContact.findMany({
        where: { accountId: session.accountId },
        orderBy: { createdAt: "asc" },
      }),
      this.prisma.memberModerationBlock.findMany({
        where: { accountId: session.accountId },
        orderBy: { createdAt: "desc" },
      }),
      this.prisma.authSession.count({
        where: {
          accountId: session.accountId,
          revokedAt: null,
          expiresAt: { gt: new Date() },
        },
      }),
      this.prisma.memberAccount.count(),
    ]);

    const likedSet = new Set(userLikes.map((item) => item.postId));
    const savedSet = new Set(userSaves.map((item) => item.postId));
    const followMap = new Map(
      userFollows.map((item) => [item.directoryProfileId, item.isFollowing]),
    );

    const mappedFollowers = directoryProfiles.map((dir) => {
      const isFollowing = followMap.has(dir.id)
        ? followMap.get(dir.id)!
        : dir.defaultFollowing;
      return {
        id: dir.id,
        name: dir.name,
        username: dir.username,
        avatarAsset: dir.avatarAsset,
        bio: dir.bio,
        isFollowing,
      };
    });

    const activeFollowingCount =
      BASE_FOLLOWING_COUNT +
      mappedFollowers.filter((f) => f.isFollowing).length;

    const mapPost = (post: (typeof allPosts)[number]) => ({
      id: post.id,
      authorName: post.authorName,
      authorUsername: post.authorUsername,
      authorAvatar: post.authorAvatar,
      authorVerified: post.authorVerified,
      timestamp: this.formatRelativeTime(post.createdAt),
      content: post.content,
      imageAsset: post.imageAsset,
      categoryBadge: post.categoryBadge,
      feedSection: post.feedSection,
      hasBreathingExerciseCard: post.hasBreathingExerciseCard,
      likesCount: post.likesCount,
      commentsCount: post.commentsCount,
      isLiked:
        likedSet.has(post.id) ||
        (userLikes.length === 0 &&
          (post.id === "11111111-1111-4111-8111-111111111105" ||
            post.id === "11111111-1111-4111-8111-111111111104")),
      isSaved:
        savedSet.has(post.id) ||
        (userSaves.length === 0 &&
          post.id === "11111111-1111-4111-8111-111111111102"),
    });

    const mappedPosts = allPosts.map(mapPost);
    const communityPosts = mappedPosts.filter(
      (p) => p.feedSection === "community",
    );
    const exploreRecommendedPosts = mappedPosts.filter(
      (p) => p.feedSection === "explore",
    );
    const currentUsername = this.deriveUsername(
      profile?.displayName ?? "Siddhu",
      profile?.username,
    );
    const profilePosts = mappedPosts.filter(
      (p) =>
        p.feedSection === "profile" ||
        p.authorUsername === currentUsername,
    );

    const displayName = profile?.displayName ?? "Siddhu";
    const username = currentUsername;

    return {
      source: "postgresql_live" as const,
      totalDatabaseMembers,
      totalDatabasePosts: allPosts.length,
      user: {
        accountId: session.accountId,
        displayName,
        username,
        bio:
          profile?.bio ??
          "A passionate learner, exploring wellness, technology and meaningful connections. 💜",
        location: profile?.location ?? "Bangalore, India",
        avatarAsset:
          profile?.avatarAsset ?? "assets/images/profile/avatar_siddhu.webp",
        email: profile?.email ?? "siddhu@example.com",
        phoneMasked: this.maskPhone(session.account.phoneE164),
        phoneVerified: Boolean(session.account.phoneVerifiedAt),
        verificationStatus: session.account.verificationStatus,
        accountStatus: session.account.status,
        postsCount: BASE_POSTS_COUNT + profilePosts.length,
        followersCount: BASE_FOLLOWERS_COUNT,
        followingCount: activeFollowingCount,
        interests: this.parseInterests(profile?.interests),
        businessProfileUrl: profile?.businessProfileUrl ?? null,
        twoFactorEnabled: profile?.twoFactorEnabled ?? false,
        activeSessionsCount: Math.max(1, activeSessionsCount),
      },
      communityPosts,
      exploreRecommendedPosts,
      profilePosts,
      groups: groups.map((g) => ({
        id: g.id,
        name: g.name,
        description: g.description,
        category: g.category,
        membersCount: g.membersCount,
        newPostsToday: g.newPostsToday,
      })),
      followers: mappedFollowers,
      privacySettings: {
        view_profile: privacyPref?.viewProfile ?? "Verified members only",
        message_me: privacyPref?.messageMe ?? "Verified members only",
        see_posts: privacyPref?.seePosts ?? "Verified members only",
        show_location: privacyPref?.showLocation ?? "General location only",
        search_results: privacyPref?.searchResults ?? "Yes",
        business_enquiries: privacyPref?.businessEnquiries ?? "Yes",
      },
      notificationPreferences: {
        community_updates: notificationPref?.communityUpdates ?? true,
        group_activity: notificationPref?.groupActivity ?? true,
        wellness_reminders: notificationPref?.wellnessReminders ?? true,
        safety_alerts: notificationPref?.safetyAlerts ?? true,
        messages: notificationPref?.messages ?? true,
        business_enquiries: notificationPref?.businessEnquiries ?? true,
        marketing_updates: notificationPref?.marketingUpdates ?? false,
      },
      wellnessResources: wellnessResources.map((w) => ({
        id: w.id,
        slug: w.slug,
        category: w.category,
        title: w.title,
        subtitle: w.subtitle,
        durationLabel: w.durationLabel,
        thumbAsset: w.thumbAsset,
      })),
      emergencyContacts: emergencyContacts.map((c) => ({
        id: c.id,
        name: c.name,
        relationship: c.relationship,
        phoneE164: c.phoneE164,
        isTrustedLocationContact: c.isTrustedLocationContact,
      })),
      blockedUsers: blockedUsers.map((b) => ({
        id: b.id,
        blockedUsername: b.blockedUsername,
        blockedDisplayName: b.blockedDisplayName,
      })),
    };
  }

  async updateProfile(
    authorization: string | undefined,
    dto: UpdateModule2ProfileDto,
  ) {
    const session = await this.auth.authenticateAuthorization(authorization);
    const displayName = dto.displayName.trim();
    const bio = dto.bio.trim();
    const location = dto.location.trim();
    const interests = dto.interests
      .map((item) => item.trim())
      .filter((item) => item.length > 0);

    const existing = await this.prisma.memberProfile.findUnique({
      where: { accountId: session.accountId },
    });

    const updated = await this.prisma.memberProfile.upsert({
      where: { accountId: session.accountId },
      create: {
        accountId: session.accountId,
        displayName,
        username: this.deriveUsername(displayName, null),
        bio,
        location,
        interests,
        email: dto.email?.trim().toLowerCase() ?? null,
        businessProfileUrl: dto.businessProfileUrl?.trim() ?? null,
        avatarAsset: dto.avatarAsset?.trim() || "assets/images/profile/avatar_siddhu.webp",
        dateOfBirth: new Date("2000-01-01T00:00:00.000Z"),
      },
      update: {
        displayName,
        bio,
        location,
        interests,
        ...(dto.email !== undefined
          ? { email: dto.email.trim().toLowerCase() || null }
          : {}),
        ...(dto.businessProfileUrl !== undefined
          ? { businessProfileUrl: dto.businessProfileUrl.trim() || null }
          : {}),
        ...(dto.avatarAsset !== undefined && dto.avatarAsset.trim().length > 0
          ? { avatarAsset: dto.avatarAsset.trim() }
          : {}),
      },
    });

    await this.prisma.auditEvent.create({
      data: {
        actorType: "MEMBER",
        actorId: session.accountId,
        action: "module2.profile.updated",
        targetType: "member_profile",
        targetId: session.accountId,
        outcome: "success",
        requestId: randomUUID(),
        redactedMetadata: {
          interestsCount: interests.length,
          hadExistingProfile: Boolean(existing),
        },
      },
    });

    return {
      displayName: updated.displayName,
      username: this.deriveUsername(updated.displayName, updated.username),
      bio: updated.bio,
      location: updated.location,
      avatarAsset: updated.avatarAsset,
      interests: this.parseInterests(updated.interests),
      email: updated.email,
      businessProfileUrl: updated.businessProfileUrl,
    };
  }

  async createPost(
    authorization: string | undefined,
    dto: CreateCommunityPostDto,
  ) {
    const session = await this.auth.authenticateAuthorization(authorization);
    const profile = await this.prisma.memberProfile.findUnique({
      where: { accountId: session.accountId },
    });

    const authorName = profile?.displayName ?? "Siddhu";
    const authorUsername = this.deriveUsername(authorName, profile?.username);
    const authorAvatar =
      profile?.avatarAsset ?? "assets/images/profile/avatar_siddhu.webp";

    const post = await this.prisma.communityPost.create({
      data: {
        authorAccountId: session.accountId,
        authorName,
        authorUsername,
        authorAvatar,
        authorVerified: session.account.verificationStatus === "VERIFIED",
        content: dto.content.trim(),
        categoryBadge: dto.categoryBadge?.trim() || "Live Community",
        imageAsset: dto.imageAsset?.trim() || null,
        feedSection: "community",
      },
    });

    await this.prisma.auditEvent.create({
      data: {
        actorType: "MEMBER",
        actorId: session.accountId,
        action: "module2.community_post.created",
        targetType: "community_post",
        targetId: post.id,
        outcome: "success",
        requestId: randomUUID(),
      },
    });

    return {
      id: post.id,
      authorName: post.authorName,
      authorUsername: post.authorUsername,
      authorAvatar: post.authorAvatar,
      authorVerified: post.authorVerified,
      timestamp: "Just now",
      content: post.content,
      imageAsset: post.imageAsset,
      categoryBadge: post.categoryBadge,
      feedSection: post.feedSection,
      hasBreathingExerciseCard: post.hasBreathingExerciseCard,
      likesCount: post.likesCount,
      commentsCount: post.commentsCount,
      isLiked: false,
      isSaved: false,
    };
  }

  async togglePostLike(authorization: string | undefined, postId: string) {
    const session = await this.auth.authenticateAuthorization(authorization);
    const post = await this.prisma.communityPost.findUnique({
      where: { id: postId },
    });
    if (!post) throw new NotFoundException("Community post was not found.");

    const existing = await this.prisma.communityPostLike.findUnique({
      where: {
        postId_accountId: {
          postId,
          accountId: session.accountId,
        },
      },
    });

    if (existing) {
      await this.prisma.communityPostLike.delete({
        where: { id: existing.id },
      });
      const updated = await this.prisma.communityPost.update({
        where: { id: postId },
        data: { likesCount: Math.max(0, post.likesCount - 1) },
      });
      return {
        postId,
        isLiked: false,
        likesCount: updated.likesCount,
      };
    }

    await this.prisma.communityPostLike.create({
      data: {
        postId,
        accountId: session.accountId,
      },
    });
    const updated = await this.prisma.communityPost.update({
      where: { id: postId },
      data: { likesCount: post.likesCount + 1 },
    });
    return {
      postId,
      isLiked: true,
      likesCount: updated.likesCount,
    };
  }

  async togglePostSave(authorization: string | undefined, postId: string) {
    const session = await this.auth.authenticateAuthorization(authorization);
    const post = await this.prisma.communityPost.findUnique({
      where: { id: postId },
    });
    if (!post) throw new NotFoundException("Community post was not found.");

    const existing = await this.prisma.communityPostSave.findUnique({
      where: {
        postId_accountId: {
          postId,
          accountId: session.accountId,
        },
      },
    });

    if (existing) {
      await this.prisma.communityPostSave.delete({
        where: { id: existing.id },
      });
      return { postId, isSaved: false };
    }

    await this.prisma.communityPostSave.create({
      data: {
        postId,
        accountId: session.accountId,
      },
    });
    return { postId, isSaved: true };
  }

  async addPostComment(
    authorization: string | undefined,
    postId: string,
    dto: CreatePostCommentDto,
  ) {
    const session = await this.auth.authenticateAuthorization(authorization);
    const post = await this.prisma.communityPost.findUnique({
      where: { id: postId },
    });
    if (!post) throw new NotFoundException("Community post was not found.");

    const profile = await this.prisma.memberProfile.findUnique({
      where: { accountId: session.accountId },
    });

    const comment = await this.prisma.communityPostComment.create({
      data: {
        postId,
        accountId: session.accountId,
        authorName: profile?.displayName ?? "Siddhu",
        content: dto.content.trim(),
      },
    });

    const updated = await this.prisma.communityPost.update({
      where: { id: postId },
      data: { commentsCount: post.commentsCount + 1 },
    });

    return {
      commentId: comment.id,
      postId,
      authorName: comment.authorName,
      content: comment.content,
      commentsCount: updated.commentsCount,
      createdAt: comment.createdAt.toISOString(),
    };
  }

  async toggleFollow(authorization: string | undefined, profileId: string) {
    const session = await this.auth.authenticateAuthorization(authorization);
    const dirProfile = await this.prisma.communityDirectoryProfile.findUnique({
      where: { id: profileId },
    });
    if (!dirProfile) {
      throw new NotFoundException("Directory profile was not found.");
    }

    const existing = await this.prisma.memberFollow.findUnique({
      where: {
        accountId_directoryProfileId: {
          accountId: session.accountId,
          directoryProfileId: profileId,
        },
      },
    });

    const nextFollowing = existing
      ? !existing.isFollowing
      : !dirProfile.defaultFollowing;

    await this.prisma.memberFollow.upsert({
      where: {
        accountId_directoryProfileId: {
          accountId: session.accountId,
          directoryProfileId: profileId,
        },
      },
      create: {
        accountId: session.accountId,
        directoryProfileId: profileId,
        isFollowing: nextFollowing,
      },
      update: {
        isFollowing: nextFollowing,
      },
    });

    return {
      profileId,
      isFollowing: nextFollowing,
    };
  }

  async updatePrivacyPreference(
    authorization: string | undefined,
    dto: UpdatePrivacyPreferenceDto,
  ) {
    const session = await this.auth.authenticateAuthorization(authorization);
    const fieldMap: Record<
      UpdatePrivacyPreferenceDto["settingId"],
      | "viewProfile"
      | "messageMe"
      | "seePosts"
      | "showLocation"
      | "searchResults"
      | "businessEnquiries"
    > = {
      view_profile: "viewProfile",
      message_me: "messageMe",
      see_posts: "seePosts",
      show_location: "showLocation",
      search_results: "searchResults",
      business_enquiries: "businessEnquiries",
    };
    const column = fieldMap[dto.settingId];
    if (!column) throw new BadRequestException("Unknown privacy setting.");

    const updated = await this.prisma.memberPrivacyPreference.upsert({
      where: { accountId: session.accountId },
      create: {
        accountId: session.accountId,
        [column]: dto.selectedValue.trim(),
      },
      update: {
        [column]: dto.selectedValue.trim(),
      },
    });

    return {
      settingId: dto.settingId,
      selectedValue: updated[column],
    };
  }

  async updateNotificationPreference(
    authorization: string | undefined,
    dto: UpdateNotificationPreferenceDto,
  ) {
    const session = await this.auth.authenticateAuthorization(authorization);
    const fieldMap: Record<
      UpdateNotificationPreferenceDto["prefId"],
      | "communityUpdates"
      | "groupActivity"
      | "wellnessReminders"
      | "safetyAlerts"
      | "messages"
      | "businessEnquiries"
      | "marketingUpdates"
    > = {
      community_updates: "communityUpdates",
      group_activity: "groupActivity",
      wellness_reminders: "wellnessReminders",
      safety_alerts: "safetyAlerts",
      messages: "messages",
      business_enquiries: "businessEnquiries",
      marketing_updates: "marketingUpdates",
    };
    const column = fieldMap[dto.prefId];
    if (!column) throw new BadRequestException("Unknown notification setting.");

    const updated = await this.prisma.memberNotificationPreference.upsert({
      where: { accountId: session.accountId },
      create: {
        accountId: session.accountId,
        [column]: dto.isEnabled,
      },
      update: {
        [column]: dto.isEnabled,
      },
    });

    if (dto.prefId === "marketing_updates") {
      await this.prisma.memberCommunicationPreference.upsert({
        where: { accountId: session.accountId },
        create: {
          accountId: session.accountId,
          productUpdatesAccepted: dto.isEnabled,
        },
        update: {
          productUpdatesAccepted: dto.isEnabled,
        },
      });
    }

    return {
      prefId: dto.prefId,
      isEnabled: updated[column],
    };
  }

  async recordSafetyEvent(
    authorization: string | undefined,
    dto: RecordSafetyEventDto,
  ) {
    const session = await this.auth.authenticateAuthorization(authorization);
    const event = await this.prisma.safetySosEvent.create({
      data: {
        accountId: session.accountId,
        eventType: dto.eventType,
        status: "RECORDED",
        locationLabel: dto.locationLabel?.trim() || "Bangalore, India",
      },
    });

    await this.prisma.auditEvent.create({
      data: {
        actorType: "MEMBER",
        actorId: session.accountId,
        action: `module2.safety.${dto.eventType.toLowerCase()}`,
        targetType: "safety_sos_event",
        targetId: event.id,
        outcome: "recorded",
        requestId: randomUUID(),
      },
    });

    return {
      eventId: event.id,
      eventType: event.eventType,
      status: event.status,
      createdAt: event.createdAt.toISOString(),
    };
  }

  async addEmergencyContact(
    authorization: string | undefined,
    dto: CreateEmergencyContactDto,
  ) {
    const session = await this.auth.authenticateAuthorization(authorization);
    const contact = await this.prisma.safetyEmergencyContact.create({
      data: {
        accountId: session.accountId,
        name: dto.name.trim(),
        relationship: dto.relationship.trim(),
        phoneE164: dto.phoneE164.trim(),
        isTrustedLocationContact: true,
      },
    });

    return {
      id: contact.id,
      name: contact.name,
      relationship: contact.relationship,
      phoneE164: contact.phoneE164,
      isTrustedLocationContact: contact.isTrustedLocationContact,
    };
  }

  async toggleTwoFactor(
    authorization: string | undefined,
    dto: ToggleTwoFactorDto,
  ) {
    const session = await this.auth.authenticateAuthorization(authorization);
    const updated = await this.prisma.memberProfile.update({
      where: { accountId: session.accountId },
      data: { twoFactorEnabled: dto.enabled },
    });

    await this.prisma.auditEvent.create({
      data: {
        actorType: "MEMBER",
        actorId: session.accountId,
        action: "module2.security.two_factor_updated",
        targetType: "member_account",
        targetId: session.accountId,
        outcome: dto.enabled ? "enabled" : "disabled",
        requestId: randomUUID(),
      },
    });

    return {
      twoFactorEnabled: updated.twoFactorEnabled,
    };
  }

  async updateSecurityPin(
    authorization: string | undefined,
    dto: UpdateSecurityPinDto,
  ) {
    const session = await this.auth.authenticateAuthorization(authorization);
    if (!/^\d{4,6}$/.test(dto.newPin)) {
      throw new BadRequestException("PIN must be 4 to 6 digits.");
    }
    const now = new Date();
    await this.prisma.memberProfile.update({
      where: { accountId: session.accountId },
      data: { securityPinUpdatedAt: now },
    });

    await this.prisma.auditEvent.create({
      data: {
        actorType: "MEMBER",
        actorId: session.accountId,
        action: "module2.security.pin_updated",
        targetType: "member_account",
        targetId: session.accountId,
        outcome: "success",
        requestId: randomUUID(),
      },
    });

    return {
      updatedAt: now.toISOString(),
      status: "updated" as const,
    };
  }

  async reportUserOrPost(
    authorization: string | undefined,
    dto: ReportUserOrPostDto,
  ) {
    const session = await this.auth.authenticateAuthorization(authorization);
    const report = await this.prisma.memberUserReport.create({
      data: {
        reporterAccountId: session.accountId,
        targetHandle: dto.targetHandle.trim(),
        reason: dto.reason.trim(),
        status: "SUBMITTED",
      },
    });

    await this.prisma.auditEvent.create({
      data: {
        actorType: "MEMBER",
        actorId: session.accountId,
        action: "module2.moderation.reported",
        targetType: "member_user_report",
        targetId: report.id,
        outcome: "submitted",
        requestId: randomUUID(),
      },
    });

    return {
      reportId: report.id,
      status: report.status,
      createdAt: report.createdAt.toISOString(),
    };
  }

  async updateAvatar(
    authorization: string | undefined,
    dto: UpdateAvatarDto,
  ) {
    const session = await this.auth.authenticateAuthorization(authorization);
    const avatarAsset = dto.avatarAsset.trim();
    const updated = await this.prisma.memberProfile.update({
      where: { accountId: session.accountId },
      data: { avatarAsset },
    });
    await this.prisma.communityPost.updateMany({
      where: { authorAccountId: session.accountId },
      data: { authorAvatar: avatarAsset },
    });
    await this.prisma.auditEvent.create({
      data: {
        actorType: "MEMBER",
        actorId: session.accountId,
        action: "module2.profile.avatar_updated",
        targetType: "member_profile",
        targetId: session.accountId,
        outcome: "success",
        requestId: randomUUID(),
      },
    });
    return {
      avatarAsset: updated.avatarAsset,
      updatedAt: new Date().toISOString(),
    };
  }

  async requestMediaUpload(
    _authorization: string | undefined,
    _dto: RequestMediaUploadDto,
  ): Promise<never> {
    throw new BadRequestException(
      "Metadata-only upload requests are disabled. Authorize Google Drive and upload the actual image using POST /api/v1/module2/media/binary-upload.",
    );
  }

  async uploadMediaObject(
    _authorization: string | undefined,
    _dto: UploadMediaObjectDto,
  ): Promise<never> {
    throw new BadRequestException(
      "JSON media placeholders are disabled. Choose an actual image file and upload it using POST /api/v1/module2/media/binary-upload.",
    );
  }

  async uploadMediaFile(
    authorization: string | undefined,
    file: {
      originalname: string;
      mimetype: string;
      buffer: Buffer;
      size: number;
    },
    dto: UploadBinaryMediaDto,
  ) {
    const session = await this.auth.authenticateAuthorization(authorization);
    if (!Buffer.isBuffer(file.buffer) || file.buffer.length === 0) {
      throw new BadRequestException("The selected image file is empty.");
    }
    if (file.size > 10 * 1024 * 1024 || file.buffer.length > 10 * 1024 * 1024) {
      throw new BadRequestException("Images must be 10 MB or smaller.");
    }
    const allowedTypes = ["image/jpeg", "image/png", "image/webp"] as const;
    if (!allowedTypes.includes(file.mimetype as (typeof allowedTypes)[number])) {
      throw new BadRequestException("Use a JPG, PNG, or WebP image.");
    }
    if (!this.hasExpectedImageSignature(file.mimetype, file.buffer)) {
      throw new BadRequestException("The selected file content does not match its image type.");
    }

    const uploadId = randomUUID();
    const stored = await this.googleDrive.uploadImage({
      uploadId,
      accountId: session.accountId,
      purpose: dto.purpose,
      fileName: file.originalname,
      contentType: file.mimetype as (typeof allowedTypes)[number],
      buffer: file.buffer,
    });
    const localBaseUrl = (
      process.env.SAKHI_PUBLIC_API_BASE_URL?.trim() ||
      `http://127.0.0.1:${process.env.PORT?.trim() || "3001"}/api/v1`
    ).replace(/\/+$/, "");
    const publicUrl = `${localBaseUrl}/module2/media/object/${uploadId}`;
    const uploadedAt = new Date().toISOString();

    await this.prisma.auditEvent.create({
      data: {
        actorType: "MEMBER",
        actorId: session.accountId,
        action: "module2.media.uploaded",
        targetType: "media_upload",
        targetId: uploadId,
        outcome: "stored",
        requestId: uploadId,
        redactedMetadata: {
          uploadId,
          fileName: stored.storedName,
          purpose: dto.purpose,
          contentType: file.mimetype,
          provider: "google_drive",
          driveFileId: stored.driveFileId,
          objectKey: `google-drive/${stored.driveFileId}`,
          publicUrl,
          sizeBytes: stored.size,
          uploadedAt,
        },
      },
    });

    if (dto.purpose === "avatar") {
      await this.prisma.memberProfile.update({
        where: { accountId: session.accountId },
        data: { avatarAsset: publicUrl },
      });
      await this.prisma.communityPost.updateMany({
        where: { authorAccountId: session.accountId },
        data: { authorAvatar: publicUrl },
      });
    }

    return {
      uploadId,
      provider: "google_drive",
      purpose: dto.purpose,
      objectKey: `google-drive/${stored.driveFileId}`,
      contentType: file.mimetype,
      sizeBytes: stored.size,
      publicUrl,
      status: "stored" as const,
      createdAt: uploadedAt,
    };
  }

  private hasExpectedImageSignature(contentType: string, buffer: Buffer): boolean {
    if (contentType === "image/jpeg") {
      return buffer.length >= 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff;
    }
    if (contentType === "image/png") {
      return buffer.length >= 8 && buffer.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
    }
    if (contentType === "image/webp") {
      return buffer.length >= 12 && buffer.toString("ascii", 0, 4) === "RIFF" && buffer.toString("ascii", 8, 12) === "WEBP";
    }
    return false;
  }

  async listMediaObjects(authorization: string | undefined) {
    const session = await this.auth.authenticateAuthorization(authorization);
    const events = await this.prisma.auditEvent.findMany({
      where: {
        actorId: session.accountId,
        action: "module2.media.uploaded",
      },
      orderBy: { createdAt: "desc" },
      take: 40,
    });
    return events.map((event) => {
      const meta =
        event.redactedMetadata &&
        typeof event.redactedMetadata === "object" &&
        !Array.isArray(event.redactedMetadata)
          ? (event.redactedMetadata as Record<string, unknown>)
          : {};
      return {
        uploadId: event.targetId ?? event.id,
        action: event.action,
        actorId: event.actorId,
        fileName: typeof meta.fileName === "string" ? meta.fileName : "media",
        purpose: typeof meta.purpose === "string" ? meta.purpose : "post",
        contentType: typeof meta.contentType === "string" ? meta.contentType : "image/jpeg",
        provider: typeof meta.provider === "string" ? meta.provider : "google_drive",
        objectKey: typeof meta.objectKey === "string" ? meta.objectKey : "",
        driveFileId: typeof meta.driveFileId === "string" ? meta.driveFileId : null,
        sizeBytes: typeof meta.sizeBytes === "number" ? meta.sizeBytes : null,
        publicUrl: typeof meta.publicUrl === "string" ? meta.publicUrl : "",
        createdAt: event.createdAt.toISOString(),
      };
    });
  }

  async resolveMediaObject(uploadId: string): Promise<{
    contentType: string;
    buffer: Buffer;
    redirectUrl?: string;
  }> {
    const event = await this.prisma.auditEvent.findFirst({
      where: {
        targetId: uploadId,
        action: "module2.media.uploaded",
      },
      orderBy: { createdAt: "desc" },
    });
    if (!event) {
      throw new NotFoundException("The media upload record was not found.");
    }

    const meta =
      event.redactedMetadata &&
      typeof event.redactedMetadata === "object" &&
      !Array.isArray(event.redactedMetadata)
        ? (event.redactedMetadata as Record<string, unknown>)
        : {};
    if (typeof meta.driveFileId !== "string" || meta.provider !== "google_drive") {
      throw new NotFoundException(
        "This legacy media record has no actual Google Drive file. Upload the image again to replace it.",
      );
    }

    const media = await this.googleDrive.downloadFile(meta.driveFileId);
    const storedContentType =
      typeof meta.contentType === "string" &&
      ["image/jpeg", "image/png", "image/webp"].includes(meta.contentType)
        ? meta.contentType
        : media.contentType;
    return {
      contentType: storedContentType,
      buffer: media.buffer,
    };
  }

  async toggleBlockedUser(
    authorization: string | undefined,
    dto: ToggleBlockedUserDto,
  ) {
    const session = await this.auth.authenticateAuthorization(authorization);
    const username = dto.blockedUsername.trim();
    const existing = await this.prisma.memberModerationBlock.findUnique({
      where: {
        accountId_blockedUsername: {
          accountId: session.accountId,
          blockedUsername: username,
        },
      },
    });

    if (existing) {
      await this.prisma.memberModerationBlock.delete({
        where: { id: existing.id },
      });
      return { blockedUsername: username, isBlocked: false };
    }

    const created = await this.prisma.memberModerationBlock.create({
      data: {
        accountId: session.accountId,
        blockedUsername: username,
        blockedDisplayName: dto.blockedDisplayName.trim(),
      },
    });
    return {
      id: created.id,
      blockedUsername: created.blockedUsername,
      blockedDisplayName: created.blockedDisplayName,
      isBlocked: true,
    };
  }
}



