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
    const token = process.env.SAKHI_ADMIN_REVIEW_TOKEN?.trim();
    if (!token || token.length < 32) {
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
    if (!timingSafeEqual(expectedDigest, providedDigest)) {
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
      // PostgreSQL UUID columns support equality, not arbitrary substring
      // searches. Avoid issuing an invalid LIKE predicate against the UUID.
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
          emailMasked: this.maskedMemberEmail(account.profile?.email ?? null),
          phoneMasked: this.maskedPhone(account.phoneE164),
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
    if (dto.accountStatus === undefined && dto.verificationStatus === undefined) {
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
        dto.verificationStatus === "UNVERIFIED" &&
        account.verificationStatus !== "UNVERIFIED" &&
        latestSubmission?.status === "PENDING_MANUAL_REVIEW"
      ) {
        throw new ConflictException(
          "This member has a real pending review submission. Use the Eligibility Review page to decide it instead of overriding its state.",
        );
      }

      if (
        dto.verificationStatus !== undefined &&
        latestSubmission &&
        dto.verificationStatus !== "UNVERIFIED"
      ) {
        const submissionStatus =
          dto.verificationStatus === "VERIFIED" ? "APPROVED" : "REJECTED";
        await tx.eligibilitySubmission.update({
          where: { id: latestSubmission.id },
          data: {
            status: submissionStatus,
            reviewedAt: now,
            reviewerLabel,
            decisionReason: `Development admin state override: ${reason}`.slice(0, 500),
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

      // Conditional transition prevents two reviewers both deciding the same submission.
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
          status: "PENDING_VERIFICATION",
          verificationStatus: "UNVERIFIED",
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
}
