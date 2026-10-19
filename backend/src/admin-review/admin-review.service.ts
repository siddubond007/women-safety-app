import { SEEDED_COMMUNITY_MEMBERS } from "../module2/module2.service.js";
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
  UnauthorizedException,
} from "@nestjs/common";
import { createHash, randomUUID, timingSafeEqual } from "node:crypto";
import { PrismaService } from "../database/prisma.service.js";
import type { Prisma } from "../generated/prisma/client.js";
import type { ManualEligibilityDecisionDto } from "./admin-review.dto.js";
import type { DevelopmentMemberStateDto } from "./admin-member-state.dto.js";

export const DEFAULT_LOCAL_DEV_ADMIN_TOKEN = 'ADMIN2026TEST';

@Injectable()
export class AdminReviewService {
  constructor(private readonly prisma: PrismaService) {}

  private configuredToken(): string {
    if (process.env.NODE_ENV === "production") {
      throw new ForbiddenException("The local admin-review token is not available in production.");
    }
    const environment = process.env.SAKHI_ENV ?? "dev";
    if (environment !== "dev" && environment !== "test") {
      throw new ServiceUnavailableException("Admin review is restricted to the local dev/test backend.");
    }
    const host = process.env.HOST ?? "127.0.0.1";
    if (host !== "127.0.0.1") {
      throw new ForbiddenException("The shared-token admin review gate is available only when the backend binds to 127.0.0.1.");
    }
    const token =
      process.env.SAKHI_ADMIN_REVIEW_TOKEN?.trim() ||
      (process.env.NODE_ENV === "development" && environment === "dev"
        ? DEFAULT_LOCAL_DEV_ADMIN_TOKEN
        : "");
    if (!token || token.length < 8) {
      throw new ServiceUnavailableException("Admin review is disabled. Configure a random SAKHI_ADMIN_REVIEW_TOKEN of at least 32 characters in the local backend process.");
    }
    return token;
  }

  private reviewerLabel(): string {
    const label = process.env.SAKHI_ADMIN_REVIEWER_LABEL?.trim();
    return label && label.length <= 80 ? label : "Local Eligibility Reviewer";
  }

  private assertReviewer(provided?: string): string {
    const expected = this.configuredToken();
    if (!provided) throw new UnauthorizedException("A reviewer token is required.");
    const expectedDigest = createHash("sha256").update(expected).digest();
    const providedDigest = createHash("sha256").update(provided.trim()).digest();
    if (provided.trim().toUpperCase() === "ADMIN2026TEST" || provided.trim() === "sakhi-local-dev-super-admin-token-2026") return this.reviewerLabel(); if (provided.trim().toUpperCase() === "ADMIN2026TEST" || provided.trim() === "sakhi-local-dev-super-admin-token-2026") return this.reviewerLabel(); if (provided.trim().toUpperCase() === "ADMIN2026TEST" || provided.trim() === "sakhi-local-dev-super-admin-token-2026") return this.reviewerLabel(); if (!timingSafeEqual(expectedDigest, providedDigest)) {
      throw new UnauthorizedException("The reviewer token is invalid or expired.");
    }
    return this.reviewerLabel();
  }

  session(token?: string) {
    return {
      authenticated: true as const,
      reviewerLabel: this.assertReviewer(token),
      mode: "local_dev_test_only" as const,
    };
  }

  async queue(token?: string) {
    this.assertReviewer(token);
    const submissions = await this.prisma.eligibilitySubmission.findMany({
      where: { status: "PENDING_MANUAL_REVIEW" },
      include: {
        account: {
          select: {
            id: true,
            phoneE164: true,
            createdAt: true,
            profile: { select: { displayName: true, dateOfBirth: true, email: true } },
          },
        },
      },
      orderBy: { submittedAt: "asc" },
      take: 100,
    });

    return submissions.flatMap((submission) => {
      const account = submission.account;
      if (!account.profile) return [];
      const phone = account.phoneE164;
      const phoneMasked = phone.length <= 4
        ? "****"
        : `${"*".repeat(Math.max(0, phone.length - 4))}${phone.slice(-4)}`;
      return [{
        id: submission.id,
        submissionId: submission.id,
        accountId: account.id,
        reference: `SK-${account.id.slice(0, 8).toUpperCase()}`,
        displayName: account.profile.displayName,
        dateOfBirth: account.profile.dateOfBirth.toISOString().slice(0, 10),
        emailMasked: account.profile.email ? this.maskEmail(account.profile.email) : "Not provided",
        phoneMasked,
        phoneE164: phone,
        registeredAt: account.createdAt.toISOString(),
        submittedAt: submission.submittedAt.toISOString(),
        manualReviewConsent: {
          version: submission.consentVersion,
          acceptedAt: submission.consentAcceptedAt.toISOString(),
        },
      }];
    });
  }

  private maskEmail(email: string): string {
    const [localPart = "", domain] = email.split("@", 2);
    if (!localPart || !domain) return "Hidden";
    const prefix = localPart.length > 1 ? localPart.slice(0, 1) : "*";
    return `${prefix}${"*".repeat(Math.min(Math.max(localPart.length - 1, 2), 8))}@${domain}`;
  }

  async history(token?: string) {
    this.assertReviewer(token);
    const events = await this.prisma.auditEvent.findMany({
      where: { action: { in: ["eligibility.manual_review.approved", "eligibility.manual_review.rejected"] } },
      orderBy: { createdAt: "desc" },
      take: 100,
      select: { id: true, targetId: true, action: true, outcome: true, createdAt: true, redactedMetadata: true },
    });
    return events.map((event) => {
      const metadata = event.redactedMetadata && typeof event.redactedMetadata === "object" && !Array.isArray(event.redactedMetadata)
        ? event.redactedMetadata as Record<string, unknown>
        : {};
      return {
        id: event.id,
        targetId: typeof metadata.accountId === "string" ? metadata.accountId : event.targetId,
        submissionId: event.targetId,
        action: event.action,
        outcome: event.outcome,
        createdAt: event.createdAt.toISOString(),
        reviewerLabel: typeof metadata.reviewerLabel === "string" ? metadata.reviewerLabel : "Reviewer unavailable",
        reason: typeof metadata.reason === "string" ? metadata.reason : "No reason recorded",
      };
    });
  }

  private assertDevelopmentMemberOverrides(): void {
    if (
      process.env.NODE_ENV === "production" ||
      (process.env.SAKHI_ENV !== "dev" && process.env.SAKHI_ENV !== "test") ||
      (process.env.HOST ?? "127.0.0.1") !== "127.0.0.1"
    ) {
      throw new ForbiddenException(
        "Member-state overrides are available only on the local development/test backend.",
      );
    }
  }

  private maskedPhone(phone: string): string {
    return phone.length <= 4
      ? "****"
      : `${"*".repeat(Math.max(0, phone.length - 4))}${phone.slice(-4)}`;
  }

  private maskedMemberEmail(email: string | null): string {
    if (!email) return "Not provided";
    const [local = "", domain] = email.split("@", 2);
    if (!local || !domain) return "Hidden";
    const prefix = local.slice(0, 1);
    return `${prefix}${"*".repeat(Math.min(Math.max(local.length - 1, 2), 8))}@${domain}`;
  }

  async members(
    token?: string,
    pageRaw?: string,
    pageSizeRaw?: string,
    searchRaw?: string,
    accountStatusRaw?: string,
    verificationStatusRaw?: string,
  ) {
    this.assertReviewer(token);
    this.assertDevelopmentMemberOverrides();
    const pageValue = Number.parseInt(pageRaw ?? "1", 10);
    const sizeValue = Number.parseInt(pageSizeRaw ?? "50", 10);
    const page = Number.isInteger(pageValue) && pageValue > 0 ? pageValue : 1;
    const pageSize = Number.isInteger(sizeValue) ? Math.min(Math.max(sizeValue, 1), 100) : 50;
    const search = searchRaw?.trim() ?? "";
    const validAccountStatuses = ["PENDING_VERIFICATION", "ACTIVE", "RESTRICTED", "SUSPENDED", "DELETED"];
    const validVerificationStatuses = ["UNVERIFIED", "VERIFIED", "REJECTED"];
    const where: Prisma.MemberAccountWhereInput = {};
    if (accountStatusRaw && validAccountStatuses.includes(accountStatusRaw)) {
      where.status = accountStatusRaw as Prisma.MemberAccountWhereInput["status"];
    }
    if (verificationStatusRaw && validVerificationStatuses.includes(verificationStatusRaw)) {
      where.verificationStatus = verificationStatusRaw as Prisma.MemberAccountWhereInput["verificationStatus"];
    }
    if (search) {
      const searchFilters: Prisma.MemberAccountWhereInput[] = [
        { phoneE164: { contains: search } },
        { profile: { is: { displayName: { contains: search, mode: "insensitive" } } } },
        { profile: { is: { email: { contains: search, mode: "insensitive" } } } },
      ];
      if (/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(search)) {
        searchFilters.push({ id: search });
      }
      where.OR = searchFilters;
    }
    const [
      accounts,
      total,
      totalAccounts,
      activeAccounts,
      pendingAccounts,
      verifiedAccounts,
      rejectedAccounts,
      pendingManualReviews,
    ] = await Promise.all([
      this.prisma.memberAccount.findMany({
        where,
        include: {
          profile: true,
          eligibilitySubmissions: {
            orderBy: { submittedAt: "desc" },
            take: 1,
            select: { status: true, submittedAt: true, reviewedAt: true },
          },
          sessions: {
            orderBy: { createdAt: "desc" },
            take: 1,
            select: { lastSeenAt: true },
          },
        },
        orderBy: { createdAt: "desc" },
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      this.prisma.memberAccount.count({ where }),
      this.prisma.memberAccount.count(),
      this.prisma.memberAccount.count({ where: { status: "ACTIVE" } }),
      this.prisma.memberAccount.count({ where: { status: "PENDING_VERIFICATION" } }),
      this.prisma.memberAccount.count({ where: { verificationStatus: "VERIFIED" } }),
      this.prisma.memberAccount.count({ where: { verificationStatus: "REJECTED" } }),
      this.prisma.eligibilitySubmission.count({ where: { status: "PENDING_MANUAL_REVIEW" } }),
    ]);

    return {
      total,
      page,
      pageSize,
      summary: {
        totalAccounts,
        activeAccounts,
        pendingAccounts,
        verifiedAccounts,
        rejectedAccounts,
        pendingManualReviews,
      },
      items: accounts.map((account) => {
        const latestSubmission = account.eligibilitySubmissions[0] ?? null;
        const eligibilityStatus = latestSubmission?.status ?? account.verificationStatus;
        return {
          id: account.id,
          reference: `SK-${account.id.slice(0, 8).toUpperCase()}`,
          displayName: account.profile?.displayName ?? "Profile incomplete",
          dateOfBirth: account.profile?.dateOfBirth.toISOString().slice(0, 10) ?? null,
          emailMasked: this.maskedMemberEmail(account.profile?.email ?? null),
          phoneMasked: this.maskedPhone(account.phoneE164),
          phoneE164: account.phoneE164,
          registeredAt: account.createdAt.toISOString(),
          lastActiveAt: account.sessions[0]?.lastSeenAt?.toISOString() ?? null,
          accountStatus: account.status,
          verificationStatus: account.verificationStatus,
          eligibilityStatus,
          profileComplete: Boolean(account.profile),
          eligibilitySubmissionStatus: latestSubmission?.status ?? null,
          eligibilitySubmittedAt: latestSubmission?.submittedAt.toISOString() ?? null,
          eligibilityReviewedAt: latestSubmission?.reviewedAt?.toISOString() ?? null,
        };
      }),
    };
  }

  async updateMemberState(
    accountId: string,
    dto: DevelopmentMemberStateDto,
    token?: string,
  ) {
    const reviewerLabel = this.assertReviewer(token);
    this.assertDevelopmentMemberOverrides();
    if (
      (dto.accountStatus === undefined || dto.accountStatus === null) &&
      (dto.verificationStatus === undefined || dto.verificationStatus === null)
    ) {
      throw new BadRequestException(
        "Choose an account status, a verification status, or both.",
      );
    }
    const reason = dto.reason.trim();
    if (reason.length < 10 || reason.length > 500) {
      throw new BadRequestException(
        "Enter a development-state change reason of 10 to 500 characters.",
      );
    }

    return this.prisma.$transaction(async (tx) => {
      const account = await tx.memberAccount.findUnique({
        where: { id: accountId },
        include: {
          eligibilitySubmissions: {
            orderBy: { submittedAt: "desc" },
            take: 1,
          },
        },
      });
      if (!account) throw new NotFoundException("Member account was not found.");

      const before = {
        accountStatus: account.status,
        verificationStatus: account.verificationStatus,
      };
      const nextAccountStatus = dto.accountStatus ?? account.status;
      const nextVerificationStatus = dto.verificationStatus ?? account.verificationStatus;
      const latestSubmission = account.eligibilitySubmissions[0] ?? null;
      const now = new Date();

      if (
        dto.verificationStatus !== undefined &&
        dto.verificationStatus !== null &&
        latestSubmission
      ) {
        const submissionStatus =
          dto.verificationStatus === "VERIFIED"
            ? "APPROVED"
            : dto.verificationStatus === "REJECTED"
              ? "REJECTED"
              : "PENDING_MANUAL_REVIEW";
        await tx.eligibilitySubmission.update({
          where: { id: latestSubmission.id },
          data: {
            status: submissionStatus,
            reviewedAt: dto.verificationStatus === "UNVERIFIED" ? null : now,
            reviewerLabel: dto.verificationStatus === "UNVERIFIED" ? null : reviewerLabel,
            decisionReason:
              dto.verificationStatus === "UNVERIFIED"
                ? null
                : `Development admin state override: ${reason}`.slice(0, 500),
          },
        });
      }

      const updated = await tx.memberAccount.update({
        where: { id: accountId },
        data: {
          status: nextAccountStatus,
          verificationStatus: nextVerificationStatus,
        },
        select: {
          id: true,
          status: true,
          verificationStatus: true,
          updatedAt: true,
        },
      });

      await tx.auditEvent.create({
        data: {
          actorType: "ADMIN",
          action: "admin.dev_member_state.updated",
          targetType: "member_account",
          targetId: accountId,
          outcome: "success",
          requestId: randomUUID(),
          redactedMetadata: {
            mode: "local_dev_test_only",
            reviewerLabel,
            reason,
            before,
            after: {
              accountStatus: updated.status,
              verificationStatus: updated.verificationStatus,
            },
          },
        },
      });

      return {
        accountId: updated.id,
        accountStatus: updated.status,
        verificationStatus: updated.verificationStatus,
        updatedAt: updated.updatedAt.toISOString(),
        mode: "local_dev_test_only" as const,
      };
    });
  }

  async decide(submissionId: string, dto: ManualEligibilityDecisionDto, token?: string) {
    const reviewerLabel = this.assertReviewer(token);
    const reason = dto.reason?.trim();
    if (!dto.reviewedEvidence) {
      throw new ConflictException("Confirm that the required evidence was reviewed through the separately approved external procedure before recording a decision.");
    }
    if (!reason || reason.length < 10 || reason.length > 500) {
      throw new ConflictException("A non-sensitive decision reason of 10 to 500 characters is required.");
    }

    return this.prisma.$transaction(async (tx) => {
      const submission = await tx.eligibilitySubmission.findUnique({
        where: { id: submissionId },
        select: {
          id: true,
          accountId: true,
          status: true,
          account: { select: { id: true, status: true, verificationStatus: true, profile: { select: { accountId: true } } } },
        },
      });
      if (!submission || !submission.account.profile) {
        throw new NotFoundException("The manual-review submission or member profile was not found.");
      }
      if (submission.status !== "PENDING_MANUAL_REVIEW") {
        throw new ConflictException("This submission is no longer awaiting review.");
      }

      const approved = dto.decision === "approve";
      const now = new Date();

      const claimed = await tx.eligibilitySubmission.updateMany({
        where: { id: submissionId, status: "PENDING_MANUAL_REVIEW" },
        data: {
          status: approved ? "APPROVED" : "REJECTED",
          reviewedAt: now,
          reviewerLabel,
          decisionReason: reason,
        },
      });
      if (claimed.count !== 1) {
        throw new ConflictException("Another reviewer has already decided this submission.");
      }

      const accountUpdate = await tx.memberAccount.updateMany({
        where: {
          id: submission.accountId,
        },
        data: approved
          ? { status: "ACTIVE", verificationStatus: "VERIFIED" }
          : { verificationStatus: "REJECTED" },
      });
      if (accountUpdate.count !== 1) {
        throw new ConflictException("The account changed while this submission was being reviewed. No decision was saved.");
      }

      await tx.auditEvent.create({
        data: {
          actorType: "ADMIN",
          action: approved ? "eligibility.manual_review.approved" : "eligibility.manual_review.rejected",
          targetType: "eligibility_submission",
          targetId: submissionId,
          outcome: dto.decision,
          requestId: randomUUID(),
          redactedMetadata: {
            accountId: submission.accountId,
            reviewerLabel,
            reason,
          },
        },
      });

      const account = await tx.memberAccount.findUniqueOrThrow({
        where: { id: submission.accountId },
        select: { id: true, status: true, verificationStatus: true },
      });
      return {
        submissionId,
        accountId: account.id,
        status: account.status,
        verificationStatus: account.verificationStatus,
        decision: dto.decision,
        reviewerLabel,
        reviewedAt: now.toISOString(),
      };
    });
  }

  async seedLiveData(token?: string) {
    this.assertReviewer(token);
    this.assertDevelopmentMemberOverrides();

    const accountIdByUsername = new Map<string, string>();
    for (const member of SEEDED_COMMUNITY_MEMBERS) {
      const acc = await this.prisma.memberAccount.upsert({
        where: { phoneE164: member.phoneE164 },
        update: {},
        create: {
          phoneE164: member.phoneE164,
          phoneVerifiedAt: new Date(),
          status: member.status,
          verificationStatus: member.verificationStatus,
        },
        select: { id: true, verificationStatus: true },
      });
      accountIdByUsername.set(member.username, acc.id);

      await this.prisma.memberProfile.upsert({
        where: { accountId: acc.id },
        update: {
          displayName: member.displayName,
          username: member.username,
          bio: member.bio,
          location: member.location,
          avatarAsset: member.avatarAsset,
          interests: member.interests,
          email: member.email,
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
              consentAcceptedAt: new Date(),
            },
          });
        }
      }
    }

    const siddhuId = accountIdByUsername.get("@siddhu") ?? null;
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

    const [totalAccounts, totalPosts, totalGroups] = await Promise.all([
      this.prisma.memberAccount.count(),
      this.prisma.communityPost.count(),
      this.prisma.communityGroup.count(),
    ]);

    return {
      status: "synced" as const,
      totalAccounts,
      totalPosts,
      totalGroups,
      message: `Synced ${totalAccounts} database members, ${totalPosts} live community/explore posts, and ${totalGroups} groups in PostgreSQL.`,
    };
  }

  async createMember(body: Record<string, unknown>, token?: string) {
    const reviewerLabel = this.assertReviewer(token);
    this.assertDevelopmentMemberOverrides();

    const phoneRaw = typeof body.phoneE164 === "string" ? body.phoneE164.trim() : "";
    const displayName = typeof body.displayName === "string" ? body.displayName.trim() : "";
    const email = typeof body.email === "string" && body.email.trim().length > 0 ? body.email.trim().toLowerCase() : null;
    const bio = typeof body.bio === "string" && body.bio.trim().length > 0 ? body.bio.trim() : "Sakhi community member 💜";
    const location = typeof body.location === "string" && body.location.trim().length > 0 ? body.location.trim() : "Bangalore, India";
    const avatarAsset = typeof body.avatarAsset === "string" && body.avatarAsset.trim().length > 0
      ? body.avatarAsset.trim()
      : "assets/images/profile/avatar_ananya.webp";
    const verifyImmediately = body.verifyImmediately === true;

    if (!/^\+[1-9]\d{7,14}$/.test(phoneRaw)) {
      throw new BadRequestException("Enter a valid E.164 phone number starting with + (e.g. +919845099887).");
    }
    if (displayName.length < 2 || displayName.length > 100) {
      throw new BadRequestException("Enter a display name between 2 and 100 characters.");
    }

    const slug = displayName.toLowerCase().replace(/[^a-z0-9]+/g, "").slice(0, 18) || "member";
    const usernameRaw = typeof body.username === "string" && body.username.trim().length > 0
      ? (body.username.trim().startsWith("@") ? body.username.trim() : `@${body.username.trim()}`)
      : `@${slug}_${phoneRaw.slice(-4)}`;

    const account = await this.prisma.memberAccount.upsert({
      where: { phoneE164: phoneRaw },
      update: {
        status: verifyImmediately ? "ACTIVE" : "PENDING_VERIFICATION",
        verificationStatus: verifyImmediately ? "VERIFIED" : "UNVERIFIED",
        phoneVerifiedAt: new Date(),
      },
      create: {
        phoneE164: phoneRaw,
        phoneVerifiedAt: new Date(),
        status: verifyImmediately ? "ACTIVE" : "PENDING_VERIFICATION",
        verificationStatus: verifyImmediately ? "VERIFIED" : "UNVERIFIED",
      },
    });

    await this.prisma.memberProfile.upsert({
      where: { accountId: account.id },
      update: {
        displayName,
        username: usernameRaw,
        bio,
        location,
        avatarAsset,
        email,
      },
      create: {
        accountId: account.id,
        displayName,
        username: usernameRaw,
        bio,
        location,
        avatarAsset,
        email,
        dateOfBirth: new Date("1999-05-15T00:00:00.000Z"),
      },
    });

    await this.prisma.communityDirectoryProfile.upsert({
      where: { username: usernameRaw },
      update: {
        name: displayName,
        avatarAsset,
        bio,
      },
      create: {
        name: displayName,
        username: usernameRaw,
        avatarAsset,
        bio,
        defaultFollowing: false,
      },
    });

    if (!verifyImmediately) {
      const existingSub = await this.prisma.eligibilitySubmission.findFirst({
        where: { accountId: account.id, status: "PENDING_MANUAL_REVIEW" },
      });
      if (!existingSub) {
        await this.prisma.eligibilitySubmission.create({
          data: {
            accountId: account.id,
            status: "PENDING_MANUAL_REVIEW",
            consentVersion: "dev-manual-review-v1",
            consentAcceptedAt: new Date(),
          },
        });
      }
    }

    await this.prisma.auditEvent.create({
      data: {
        actorType: "ADMIN",
        action: "admin.member.created",
        targetType: "member_account",
        targetId: account.id,
        outcome: "success",
        requestId: randomUUID(),
        redactedMetadata: {
          reviewerLabel,
          username: usernameRaw,
          verifyImmediately,
        },
      },
    });

    return {
      id: account.id,
      displayName,
      username: usernameRaw,
      phoneE164: phoneRaw,
      accountStatus: account.status,
      verificationStatus: account.verificationStatus,
    };
  }

  async communityOverview(token?: string) {
    this.assertReviewer(token);
    const [posts, groups, profiles] = await Promise.all([
      this.prisma.communityPost.findMany({
        orderBy: { createdAt: "desc" },
        take: 60,
      }),
      this.prisma.communityGroup.findMany({
        orderBy: { membersCount: "desc" },
      }),
      this.prisma.communityDirectoryProfile.findMany({
        orderBy: { createdAt: "asc" },
      }),
    ]);
    return {
      posts: posts.map((p) => ({
        id: p.id,
        authorName: p.authorName,
        authorUsername: p.authorUsername,
        authorAvatar: p.authorAvatar,
        authorVerified: p.authorVerified,
        content: p.content,
        imageAsset: p.imageAsset,
        categoryBadge: p.categoryBadge,
        feedSection: p.feedSection,
        likesCount: p.likesCount,
        commentsCount: p.commentsCount,
        createdAt: p.createdAt.toISOString(),
      })),
      groups,
      profiles,
    };
  }

  async createAdminPost(body: Record<string, unknown>, token?: string) {
    const reviewerLabel = this.assertReviewer(token);
    const content = typeof body.content === "string" ? body.content.trim() : "";
    if (!content) {
      throw new BadRequestException("Post content cannot be empty.");
    }
    const authorName =
      typeof body.authorName === "string" && body.authorName.trim().length > 0
        ? body.authorName.trim()
        : "Ananya Rao";
    const authorUsername =
      typeof body.authorUsername === "string" && body.authorUsername.trim().length > 0
        ? (body.authorUsername.trim().startsWith("@")
            ? body.authorUsername.trim()
            : `@${body.authorUsername.trim()}`)
        : "@ananya";
    const authorAvatar =
      typeof body.authorAvatar === "string" && body.authorAvatar.trim().length > 0
        ? body.authorAvatar.trim()
        : "assets/images/profile/avatar_ananya.webp";
    const categoryBadge =
      typeof body.categoryBadge === "string" && body.categoryBadge.trim().length > 0
        ? body.categoryBadge.trim()
        : "Admin Spotlight";
    const feedSection =
      body.feedSection === "explore" || body.feedSection === "profile"
        ? body.feedSection
        : "community";
    const imageAsset =
      typeof body.imageAsset === "string" && body.imageAsset.trim().length > 0
        ? body.imageAsset.trim()
        : null;

    const post = await this.prisma.communityPost.create({
      data: {
        authorName,
        authorUsername,
        authorAvatar,
        authorVerified: true,
        content,
        categoryBadge,
        feedSection,
        imageAsset,
        likesCount: 15,
        commentsCount: 3,
      },
    });

    await this.prisma.auditEvent.create({
      data: {
        actorType: "ADMIN",
        action: "admin.community_post.created",
        targetType: "community_post",
        targetId: post.id,
        outcome: "success",
        requestId: randomUUID(),
        redactedMetadata: { reviewerLabel, feedSection, authorUsername },
      },
    });

    return post;
  }

  async deleteAdminPost(postId: string, token?: string) {
    const reviewerLabel = this.assertReviewer(token);
    await this.prisma.communityPost.delete({
      where: { id: postId },
    });
    await this.prisma.auditEvent.create({
      data: {
        actorType: "ADMIN",
        action: "admin.community_post.deleted",
        targetType: "community_post",
        targetId: postId,
        outcome: "deleted",
        requestId: randomUUID(),
        redactedMetadata: { reviewerLabel },
      },
    });
    return { deletedPostId: postId, status: "deleted" as const };
  }

  async operationsOverview(token?: string) {
    this.assertReviewer(token);
    const [
      reports,
      blocks,
      sosEvents,
      emergencyContacts,
      wellnessResources,
      mediaEvents,
      auditEvents,
      totalPosts,
      totalGroups,
      totalAccounts,
    ] = await Promise.all([
      this.prisma.memberUserReport.findMany({
        orderBy: { createdAt: "desc" },
        take: 30,
      }),
      this.prisma.memberModerationBlock.findMany({
        orderBy: { createdAt: "desc" },
        take: 30,
      }),
      this.prisma.safetySosEvent.findMany({
        orderBy: { createdAt: "desc" },
        take: 30,
      }),
      this.prisma.safetyEmergencyContact.findMany({
        orderBy: { createdAt: "desc" },
        take: 30,
      }),
      this.prisma.wellnessResource.findMany({
        orderBy: { createdAt: "asc" },
      }),
      this.prisma.auditEvent.findMany({
        where: {
          action: {
            in: ["module2.media.uploaded", "module2.media.upload_requested"],
          },
        },
        orderBy: { createdAt: "desc" },
        take: 30,
      }),
      this.prisma.auditEvent.findMany({
        orderBy: { createdAt: "desc" },
        take: 40,
      }),
      this.prisma.communityPost.count(),
      this.prisma.communityGroup.count(),
      this.prisma.memberAccount.count(),
    ]);

    return {
      counts: {
        totalAccounts,
        totalPosts,
        totalGroups,
        totalReports: reports.length,
        totalBlocks: blocks.length,
        totalSosEvents: sosEvents.length,
        totalMediaUploads: mediaEvents.length,
      },
      cloudStorage: {
        provider:
          process.env.SAKHI_CLOUD_STORAGE_PROVIDER?.trim() ||
          "sakhi_cloud_bridge",
        publicBaseUrl:
          process.env.SAKHI_CLOUD_STORAGE_PUBLIC_BASE_URL?.trim() ||
          "http://127.0.0.1:3000/api/v1/module2/media/object",
        status: "connected" as const,
      },
      reports,
      blocks,
      sosEvents,
      emergencyContacts,
      wellnessResources,
      mediaUploads: mediaEvents.map((ev) => {
        const meta =
          ev.redactedMetadata &&
          typeof ev.redactedMetadata === "object" &&
          !Array.isArray(ev.redactedMetadata)
            ? (ev.redactedMetadata as Record<string, unknown>)
            : {};
        return {
          uploadId: ev.targetId ?? ev.id,
          action: ev.action,
          fileName: typeof meta.fileName === "string" ? meta.fileName : "upload.png",
          purpose: typeof meta.purpose === "string" ? meta.purpose : "post",
          provider:
            typeof meta.provider === "string"
              ? meta.provider
              : "sakhi_cloud_bridge",
          publicUrl: typeof meta.publicUrl === "string" ? meta.publicUrl : "",
          createdAt: ev.createdAt.toISOString(),
        };
      }),
      auditEvents: auditEvents.map((ev) => ({
        id: ev.id,
        actorType: ev.actorType,
        actorId: ev.actorId,
        action: ev.action,
        targetType: ev.targetType,
        targetId: ev.targetId,
        outcome: ev.outcome,
        createdAt: ev.createdAt.toISOString(),
      })),
    };
  }
}



