import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
  UnauthorizedException,
} from "@nestjs/common";
import { createHash, randomUUID, timingSafeEqual } from "node:crypto";
import { PrismaService } from "../database/prisma.service.js";
import type { ManualEligibilityDecisionDto } from "./admin-review.dto.js";

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
