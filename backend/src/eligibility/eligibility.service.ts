import {
  ConflictException,
  Injectable,
  ServiceUnavailableException,
} from "@nestjs/common";
import { randomUUID } from "node:crypto";
import { AuthenticationService } from "../auth/auth.service.js";
import { PrismaService } from "../database/prisma.service.js";
import type { StartManualReviewDto } from "./eligibility.dto.js";

type ManualReviewPolicy = {
  enabled: boolean;
  consentVersion: string | null;
  consentText: string | null;
  description: string | null;
  dataHandlingDescription: string | null;
  retentionDescription: string | null;
};

@Injectable()
export class EligibilityService {
  constructor(
    private readonly auth: AuthenticationService,
    private readonly prisma: PrismaService,
  ) {}

  private manualReviewPolicy(): ManualReviewPolicy {
    const environment = process.env.SAKHI_ENV ?? "dev";
    const isLocalDevProcess =
      process.env.NODE_ENV === "development" && environment === "dev";
    const consentVersion =
      process.env.SAKHI_MANUAL_REVIEW_CONSENT_VERSION?.trim() ||
      (isLocalDevProcess ? "dev-manual-review-v1" : null);
    const consentText =
      process.env.SAKHI_MANUAL_REVIEW_CONSENT_TEXT?.trim() ||
      (isLocalDevProcess
        ? "I consent to submitting my Sakhi development profile for local Super Admin eligibility verification."
        : null);
    const description =
      process.env.SAKHI_MANUAL_REVIEW_DESCRIPTION?.trim() ||
      (isLocalDevProcess
        ? "Your account request will appear in the local Super Admin review queue for verification."
        : null);
    const dataHandlingDescription =
      process.env.SAKHI_MANUAL_REVIEW_DATA_HANDLING_DESCRIPTION?.trim() ||
      (isLocalDevProcess
        ? "Only your display name, date of birth, and masked phone/email are shown to the local Super Admin reviewer."
        : null);
    const retentionDescription =
      process.env.SAKHI_MANUAL_REVIEW_RETENTION_DESCRIPTION?.trim() ||
      (isLocalDevProcess
        ? "Review records are stored only in your local sakhi_dev PostgreSQL database."
        : null);
    const policyApproved =
      process.env.SAKHI_MANUAL_REVIEW_POLICY_APPROVED === "true" ||
      isLocalDevProcess;
    const procedureApproved =
      process.env.SAKHI_MANUAL_REVIEW_EVIDENCE_PROCEDURE_APPROVED === "true" ||
      isLocalDevProcess;
    const enabled =
      process.env.NODE_ENV !== "production" &&
      (environment === "dev" || environment === "test") &&
      policyApproved &&
      procedureApproved &&
      Boolean(
        consentVersion &&
          consentText &&
          description &&
          dataHandlingDescription &&
          retentionDescription,
      );

    return {
      enabled,
      consentVersion,
      consentText,
      description,
      dataHandlingDescription,
      retentionDescription,
    };
  }

  configuration() {
    const policy = this.manualReviewPolicy();
    return {
      providerConfigured: false,
      policyApproved: false,
      providerDisplayName: null,
      methodDescription: null,
      attributesCheckedDescription: null,
      selfieOrLivenessDescription: null,
      dataHandlingDescription: null,
      retentionAndDeletionDescription: null,
      declineOrFailureDescription: null,
      consentVersion: null,
      canStartVerification: false,
      mode: "development_preview" as const,
      manualReviewEnabled: policy.enabled,
      manualReviewConsentVersion: policy.consentVersion,
      manualReviewConsentText: policy.consentText,
      manualReviewDescription: policy.description,
      manualReviewDataHandlingDescription: policy.dataHandlingDescription,
      manualReviewRetentionDescription: policy.retentionDescription,
      message: policy.enabled
        ? "Provider-based verification is unavailable. The separately approved local manual-review route is configured."
        : "Neither provider verification nor manual review is enabled. Explicit policy and external evidence-procedure configuration is required.",
    };
  }

  async status(authorization?: string) {
    const session = await this.auth.authenticateAuthorization(authorization);
    const latestSubmission = await this.prisma.eligibilitySubmission.findFirst({
      where: { accountId: session.accountId },
      orderBy: { submittedAt: "desc" },
      select: { id: true, status: true, submittedAt: true, reviewedAt: true },
    });

    let eligibilityStatus: "UNVERIFIED" | "VERIFIED" | "REJECTED" | "PENDING_MANUAL_REVIEW";
    if (session.account.verificationStatus === "VERIFIED") {
      eligibilityStatus = "VERIFIED";
    } else if (session.account.verificationStatus === "REJECTED") {
      eligibilityStatus = "REJECTED";
    } else if (latestSubmission?.status === "PENDING_MANUAL_REVIEW") {
      eligibilityStatus = "PENDING_MANUAL_REVIEW";
    } else {
      eligibilityStatus = "UNVERIFIED";
    }

    const policy = this.manualReviewPolicy();
    return {
      status: "providerUnavailable" as const,
      eligibilityStatus,
      manualReviewStatus: latestSubmission?.status ?? null,
      manualReviewSubmissionId: latestSubmission?.id ?? null,
      manualReviewSubmittedAt: latestSubmission?.submittedAt.toISOString() ?? null,
      manualReviewReviewedAt: latestSubmission?.reviewedAt?.toISOString() ?? null,
      canStartVerification: false,
      canRequestManualReview:
        policy.enabled &&
        session.account.verificationStatus !== "VERIFIED" &&
        latestSubmission?.status !== "PENDING_MANUAL_REVIEW",
      message:
        eligibilityStatus === "VERIFIED"
          ? "An authorized manual reviewer approved this account."
          : eligibilityStatus === "REJECTED"
            ? "The last manual eligibility request was rejected. Follow the separately approved resubmission process."
            : eligibilityStatus === "PENDING_MANUAL_REVIEW"
              ? "Your manual eligibility request is awaiting review in Super Admin."
              : policy.enabled
                ? "Provider verification is unavailable. An explicit request for the approved manual-review process may be submitted."
                : "No approved provider or enabled manual-review policy is configured. No identity evidence is being collected.",
      isDemo: true,
    };
  }

  async start(authorization: string | undefined, dto: StartManualReviewDto) {
    const session = await this.auth.authenticateAuthorization(authorization);
    const policy = this.manualReviewPolicy();
    if (!policy.enabled || !policy.consentVersion) {
      throw new ServiceUnavailableException({
        code: "manual_review_not_configured",
        message: "Manual review is disabled until its policy, consent wording, data handling, retention statement and external evidence procedure are explicitly configured.",
        isDemo: true,
      });
    }
    if (!dto?.consentAccepted || dto.consentVersion !== policy.consentVersion) {
      throw new ConflictException({
        code: "manual_review_consent_required",
        message: "Accept the current manual-review consent before submitting a request.",
        expectedConsentVersion: policy.consentVersion,
      });
    }

    const account = await this.prisma.memberAccount.findUnique({
      where: { id: session.accountId },
      select: {
        id: true,
        status: true,
        verificationStatus: true,
        profile: { select: { accountId: true } },
        consents: { select: { id: true }, take: 1 },
      },
    });
    if (!account || !account.profile || account.consents.length === 0) {
      throw new ConflictException("Complete registration and the required Terms/Privacy acknowledgement before requesting manual review.");
    }
    if (account.status !== "PENDING_VERIFICATION" || account.verificationStatus === "VERIFIED") {
      throw new ConflictException("This account is not eligible to submit a new manual-review request.");
    }

    return this.prisma.$transaction(async (tx) => {
      const previousSubmission = await tx.eligibilitySubmission.findFirst({
        where: { accountId: session.accountId },
        orderBy: { submittedAt: "desc" },
        select: { id: true, status: true, submittedAt: true },
      });
      if (previousSubmission?.status === "PENDING_MANUAL_REVIEW") {
        if (process.env.SAKHI_ENV === "dev") {
          return {
            status: "pendingManualReview" as const,
            eligibilityStatus: "PENDING_MANUAL_REVIEW" as const,
            submissionId: previousSubmission.id,
            submittedAt: (previousSubmission.submittedAt ?? new Date()).toISOString(),
            message: "Your manual-review request is active in the Super Admin review queue.",
            isDemo: true,
          };
        }
        throw new ConflictException("A manual eligibility review is already pending.");
      }
      if (previousSubmission) {
        throw new ConflictException("A previous manual-review request exists. Resubmission and appeals are not enabled in this version.");
      }

      const now = new Date();
      const submission = await tx.eligibilitySubmission.create({
        data: {
          accountId: session.accountId,
          status: "PENDING_MANUAL_REVIEW",
          consentVersion: policy.consentVersion!,
          consentAcceptedAt: now,
        },
        select: { id: true, submittedAt: true, status: true },
      });

      await tx.memberAccount.update({
        where: { id: session.accountId },
        data: { verificationStatus: "UNVERIFIED" },
      });

      await tx.auditEvent.create({
        data: {
          actorType: "MEMBER",
          actorId: session.accountId,
          action: "eligibility.manual_review.submitted",
          targetType: "eligibility_submission",
          targetId: submission.id,
          outcome: "pending",
          requestId: randomUUID(),
          redactedMetadata: { consentVersion: policy.consentVersion, consentAccepted: true },
        },
      });

      return {
        status: "pendingManualReview" as const,
        eligibilityStatus: "PENDING_MANUAL_REVIEW" as const,
        submissionId: submission.id,
        submittedAt: submission.submittedAt.toISOString(),
        message: "Your manual-review request was saved and sent to the Super Admin review queue.",
        isDemo: true,
      };
    });
  }
}
