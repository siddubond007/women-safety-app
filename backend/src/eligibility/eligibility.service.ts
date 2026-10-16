import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  ServiceUnavailableException,
  TooManyRequestsException,
} from "@nestjs/common";
import { randomUUID } from "node:crypto";
import { AuthenticationService } from "../auth/auth.service.js";
import { PrismaService } from "../database/prisma.service.js";
import {
  ELIGIBILITY_STATUS_API_VALUE,
  ELIGIBILITY_VERIFICATION_STATUS,
  canTransitionEligibilityStatus,
  type EligibilityVerificationStatus,
} from "./eligibility-status.js";
import {
  ELIGIBILITY_PROVIDER,
  type EligibilityProviderAdapter,
  type EligibilityProviderConfiguration,
  type EligibilityProviderSession,
} from "./eligibility-provider.js";
import type {
  CreateEligibilitySupportRequestDto,
  EligibilitySupportRequestCategoryApi,
  StartEligibilityVerificationDto,
} from "./eligibility.dto.js";

const SUPPORT_CATEGORY_TO_DB = {
  verificationHelp: "VERIFICATION_HELP",
  manualReviewRequest: "MANUAL_REVIEW_REQUEST",
  accessibilityAlternative: "ACCESSIBILITY_ALTERNATIVE",
  appealGuidance: "APPEAL_GUIDANCE",
} as const satisfies Record<
  EligibilitySupportRequestCategoryApi,
  | "VERIFICATION_HELP"
  | "MANUAL_REVIEW_REQUEST"
  | "ACCESSIBILITY_ALTERNATIVE"
  | "APPEAL_GUIDANCE"
>;

const SUPPORT_CATEGORY_FROM_DB: Record<string, EligibilitySupportRequestCategoryApi> = {
  VERIFICATION_HELP: "verificationHelp",
  MANUAL_REVIEW_REQUEST: "manualReviewRequest",
  ACCESSIBILITY_ALTERNATIVE: "accessibilityAlternative",
  APPEAL_GUIDANCE: "appealGuidance",
};

const SUPPORT_STATUS_FROM_DB: Record<string, string> = {
  OPEN: "open",
  IN_REVIEW: "inReview",
  RESOLVED: "resolved",
  CLOSED: "closed",
};

const SUPPORT_REQUEST_WINDOW_MS = 24 * 60 * 60 * 1000;
const MAX_SUPPORT_REQUESTS_PER_WINDOW = 5;

@Injectable()
export class EligibilityService {
  constructor(
    private readonly auth: AuthenticationService,
    private readonly prisma: PrismaService,
    @Inject(ELIGIBILITY_PROVIDER)
    private readonly provider: EligibilityProviderAdapter,
  ) {}

  private providerConfiguration(): EligibilityProviderConfiguration {
    return this.provider.configuration();
  }

  configuration() {
    const provider = this.providerConfiguration();
    const canStartVerification =
      provider.providerConfigured &&
      provider.policyApproved &&
      Boolean(provider.providerKey) &&
      Boolean(provider.consentVersion);

    return {
      providerConfigured: provider.providerConfigured,
      policyApproved: provider.policyApproved,
      providerDisplayName: provider.providerDisplayName,
      methodDescription: provider.methodDescription,
      attributesCheckedDescription: provider.attributesCheckedDescription,
      selfieOrLivenessDescription: provider.biometricProcessingSupported
        ? provider.biometricProcessingRequired
          ? "Biometric processing is required by the approved provider flow and needs separate explicit consent."
          : "Biometric processing is supported but optional; it requires separate explicit consent if selected."
        : null,
      dataHandlingDescription: provider.dataHandlingDescription,
      retentionAndDeletionDescription: provider.retentionAndDeletionDescription,
      declineOrFailureDescription: provider.declineOrFailureDescription,
      manualReviewDescription: provider.manualReviewDescription,
      consentVersion: provider.consentVersion,
      canStartVerification,
      supportRequestsAvailable: true,
      reviewDecisionsEnabled: false,
      rawIdentityDataCollectedBySakhi: false,
      mode: canStartVerification ? ("configured" as const) : ("development_preview" as const),
    };
  }

  async status(authorization?: string) {
    const session = await this.auth.authenticateAuthorization(authorization);
    const provider = this.providerConfiguration();
    const eligibilityStatus =
      session.account.eligibilityStatus as EligibilityVerificationStatus;

    return {
      // Keep the existing providerUnavailable contract until an approved
      // adapter is actually configured and the mobile client supports it.
      status:
        provider.providerConfigured && provider.policyApproved
          ? ("providerConfigured" as const)
          : ("providerUnavailable" as const),
      eligibilityStatus: ELIGIBILITY_STATUS_API_VALUE[eligibilityStatus],
      providerConfigured: provider.providerConfigured,
      policyApproved: provider.policyApproved,
      canStartVerification: this.configuration().canStartVerification,
      supportRequestsAvailable: true,
      message:
        provider.providerConfigured && provider.policyApproved
          ? "An approved provider is configured. Eligibility is still determined only by the trusted backend result."
          : "No approved eligibility provider or policy is configured. No verification session exists.",
      isDemo: !(provider.providerConfigured && provider.policyApproved),
    };
  }

  async start(
    authorization?: string,
    dto?: StartEligibilityVerificationDto,
  ) {
    const authSession = await this.auth.authenticateAuthorization(authorization);
    const provider = this.providerConfiguration();

    // Check availability before validation so existing mobile callers that
    // do not yet submit consent continue to receive the safe 409 response.
    const providerKey = provider.providerKey;
    const consentVersion = provider.consentVersion;
    if (
      !provider.providerConfigured ||
      !provider.policyApproved ||
      !providerKey ||
      !consentVersion
    ) {
      throw new ConflictException({
        statusCode: 409,
        code: "eligibility_provider_unavailable",
        status: "providerUnavailable",
        message:
          "Eligibility verification has not been configured. No session was created and no identity data was collected.",
        isDemo: true,
      });
    }

    if (!dto || dto.consentAccepted !== true) {
      throw new BadRequestException({
        code: "eligibility_consent_required",
        message: "Explicit acceptance of the current eligibility notice is required.",
      });
    }
    if (dto.consentVersion !== provider.consentVersion) {
      throw new ConflictException({
        code: "eligibility_consent_version_changed",
        message: "The eligibility notice has changed. Review the current notice before continuing.",
      });
    }
    if (
      provider.biometricProcessingRequired &&
      dto.biometricProcessingConsented !== true
    ) {
      throw new BadRequestException({
        code: "eligibility_biometric_consent_required",
        message: "Separate explicit consent is required for the biometric processing described by this provider.",
      });
    }
    if (
      dto.biometricProcessingConsented === true &&
      !provider.biometricProcessingSupported
    ) {
      throw new BadRequestException({
        code: "eligibility_biometric_processing_not_supported",
        message: "The configured method does not support biometric processing.",
      });
    }

    const accountId = authSession.accountId;
    const currentStatus =
      authSession.account.eligibilityStatus as EligibilityVerificationStatus;

    if (
      !canTransitionEligibilityStatus(
        currentStatus,
        ELIGIBILITY_VERIFICATION_STATUS.VERIFICATION_IN_PROGRESS,
        "SYSTEM",
      )
    ) {
      throw new ConflictException({
        code: "eligibility_status_transition_not_allowed",
        message: "Verification cannot be started from the account's current eligibility status.",
        eligibilityStatus: ELIGIBILITY_STATUS_API_VALUE[currentStatus],
      });
    }

    const profile = await this.prisma.memberProfile.findUnique({
      where: { accountId },
      select: { accountId: true },
    });
    if (!profile) {
      throw new ForbiddenException({
        code: "profile_setup_required",
        message: "Complete account registration before starting eligibility verification.",
      });
    }

    const activeSession = await this.prisma.eligibilityVerificationSession.findFirst({
      where: {
        accountId,
        OR: [
          { status: "CREATED" },
          {
            status: "REDIRECT_READY",
            expiresAt: { gt: new Date() },
          },
        ],
      },
      select: { id: true },
    });
    if (activeSession) {
      throw new ConflictException({
        code: "eligibility_session_already_active",
        message: "A verification session is already in progress. Resume it or wait for it to expire.",
      });
    }

    const localSessionId = randomUUID();
    await this.prisma.$transaction(async (tx) => {
      const consent = await tx.eligibilityConsent.create({
        data: {
          accountId,
          noticeVersion: consentVersion,
          acceptedAt: new Date(),
          biometricProcessingConsented: dto.biometricProcessingConsented === true,
          source: "sakhi_mobile",
        },
        select: { id: true },
      });

      await tx.eligibilityVerificationSession.create({
        data: {
          id: localSessionId,
          accountId,
          consentId: consent.id,
          providerKey,
          status: "CREATED",
        },
        select: { id: true },
      });

      const updated = await tx.memberAccount.updateMany({
        where: { id: accountId, eligibilityStatus: currentStatus },
        data: {
          eligibilityStatus:
            ELIGIBILITY_VERIFICATION_STATUS.VERIFICATION_IN_PROGRESS,
        },
      });
      if (updated.count !== 1) {
        throw new ConflictException({
          code: "eligibility_status_changed",
          message: "The eligibility status changed. Refresh status and try again.",
        });
      }

      await tx.auditEvent.create({
        data: {
          actorType: "MEMBER",
          actorId: accountId,
          action: "eligibility.consent.recorded",
          targetType: "eligibility_verification_session",
          targetId: localSessionId,
          outcome: "success",
          requestId: localSessionId,
          redactedMetadata: {
            noticeVersion: provider.consentVersion,
            biometricProcessingConsented: dto.biometricProcessingConsented === true,
          },
        },
        select: { id: true },
      });
      await tx.auditEvent.create({
        data: {
          actorType: "SYSTEM",
          action: "eligibility.status.changed",
          targetType: "member_account",
          targetId: accountId,
          outcome: "success",
          requestId: localSessionId,
          redactedMetadata: {
            from: currentStatus,
            to: ELIGIBILITY_VERIFICATION_STATUS.VERIFICATION_IN_PROGRESS,
          },
        },
        select: { id: true },
      });
    });

    let providerSession: EligibilityProviderSession;
    try {
      providerSession = await this.provider.startSession({
        localSessionId,
        accountId,
        consentVersion,
        biometricProcessingConsented: dto.biometricProcessingConsented === true,
      });
      this.validateProviderSession(providerSession);
    } catch {
      await this.failProviderStart(localSessionId, accountId).catch(() => undefined);
      throw new ServiceUnavailableException({
        code: "eligibility_provider_start_failed",
        message: "The verification session could not be started. Your account remains not verified; retry later or contact support.",
      });
    }

    try {
      await this.prisma.$transaction(async (tx) => {
        await tx.eligibilityVerificationSession.update({
          where: { id: localSessionId },
          data: {
            providerReference: providerSession.providerReference,
            status: "REDIRECT_READY",
            expiresAt: providerSession.expiresAt,
          },
          select: { id: true },
        });
        await tx.auditEvent.create({
          data: {
            actorType: "SYSTEM",
            action: "eligibility.provider_session.created",
            targetType: "eligibility_verification_session",
            targetId: localSessionId,
            outcome: "success",
            requestId: localSessionId,
            redactedMetadata: {
              providerKey,
              expiresAt: providerSession.expiresAt.toISOString(),
            },
          },
          select: { id: true },
        });
      });
    } catch {
      if (this.provider.cancelSession) {
        await this.provider
          .cancelSession({ providerReference: providerSession.providerReference })
          .catch(() => undefined);
      }
      await this.failProviderStart(localSessionId, accountId).catch(() => undefined);
      throw new ServiceUnavailableException({
        code: "eligibility_session_persistence_failed",
        message: "The provider session could not be safely recorded. No eligibility approval was granted; retry later or contact support.",
      });
    }

    return {
      status: "verificationInProgress" as const,
      eligibilityStatus: "verificationInProgress" as const,
      sessionId: localSessionId,
      redirectUrl: providerSession.redirectUrl,
      expiresAt: providerSession.expiresAt.toISOString(),
      providerConfigured: true,
      message: "Continue with the approved provider. Eligibility is not granted until the backend validates the provider result.",
      isDemo: false,
    };
  }

  private validateProviderSession(session: EligibilityProviderSession): void {
    if (
      !session ||
      typeof session.providerReference !== "string" ||
      session.providerReference.trim().length === 0 ||
      session.providerReference.length > 255
    ) {
      throw new Error("Invalid provider reference");
    }

    let redirect: URL;
    try {
      redirect = new URL(session.redirectUrl);
    } catch {
      throw new Error("Invalid provider redirect URL");
    }
    if (
      redirect.protocol !== "https:" ||
      redirect.username.length > 0 ||
      redirect.password.length > 0
    ) {
      throw new Error("Provider redirect must use HTTPS without embedded credentials");
    }

    if (
      !(session.expiresAt instanceof Date) ||
      !Number.isFinite(session.expiresAt.getTime()) ||
      session.expiresAt.getTime() <= Date.now()
    ) {
      throw new Error("Invalid or expired provider session");
    }
  }

  private async failProviderStart(
    localSessionId: string,
    accountId: string,
  ): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      await tx.eligibilityVerificationSession.update({
        where: { id: localSessionId },
        data: { status: "FAILED", completedAt: new Date() },
        select: { id: true },
      });
      await tx.memberAccount.updateMany({
        where: {
          id: accountId,
          eligibilityStatus: "VERIFICATION_IN_PROGRESS",
        },
        data: { eligibilityStatus: "NOT_VERIFIED" },
      });
      await tx.auditEvent.create({
        data: {
          actorType: "SYSTEM",
          action: "eligibility.provider_session.failed",
          targetType: "eligibility_verification_session",
          targetId: localSessionId,
          outcome: "failed",
          requestId: localSessionId,
          redactedMetadata: { reason: "provider_start_or_persistence_failure" },
        },
        select: { id: true },
      });
    });
  }

  async createSupportRequest(
    authorization: string | undefined,
    dto: CreateEligibilitySupportRequestDto,
  ) {
    const session = await this.auth.authenticateAuthorization(authorization);
    const since = new Date(Date.now() - SUPPORT_REQUEST_WINDOW_MS);
    const recentCount = await this.prisma.eligibilitySupportRequest.count({
      where: {
        accountId: session.accountId,
        createdAt: { gte: since },
      },
    });
    if (recentCount >= MAX_SUPPORT_REQUESTS_PER_WINDOW) {
      throw new TooManyRequestsException(
        "Too many eligibility support requests. Try again later.",
      );
    }

    const category = SUPPORT_CATEGORY_TO_DB[dto.category];
    const requestId = randomUUID();
    const row = await this.prisma.$transaction(async (tx) => {
      const created = await tx.eligibilitySupportRequest.create({
        data: {
          id: requestId,
          accountId: session.accountId,
          category,
          status: "OPEN",
        },
        select: {
          id: true,
          category: true,
          status: true,
          createdAt: true,
        },
      });
      await tx.auditEvent.create({
        data: {
          actorType: "MEMBER",
          actorId: session.accountId,
          action: "eligibility.support_request.created",
          targetType: "eligibility_support_request",
          targetId: requestId,
          outcome: "created",
          requestId,
          redactedMetadata: { category },
        },
        select: { id: true },
      });
      return created;
    });

    return {
      requestId: row.id,
      category: SUPPORT_CATEGORY_FROM_DB[row.category],
      status: SUPPORT_STATUS_FROM_DB[row.status],
      createdAt: row.createdAt.toISOString(),
      eligibilityStatus:
        ELIGIBILITY_STATUS_API_VALUE[
          session.account.eligibilityStatus as EligibilityVerificationStatus
        ],
      message:
        "Your support request was recorded. It does not change eligibility status or grant protected access. Human eligibility decisions are not yet enabled.",
      isDemo: true,
    };
  }

  async listSupportRequests(authorization?: string) {
    const session = await this.auth.authenticateAuthorization(authorization);
    const rows = await this.prisma.eligibilitySupportRequest.findMany({
      where: { accountId: session.accountId },
      orderBy: { createdAt: "desc" },
      take: 20,
      select: {
        id: true,
        category: true,
        status: true,
        createdAt: true,
        updatedAt: true,
      },
    });
    return {
      requests: rows.map((row) => ({
        requestId: row.id,
        category: SUPPORT_CATEGORY_FROM_DB[row.category],
        status: SUPPORT_STATUS_FROM_DB[row.status],
        createdAt: row.createdAt.toISOString(),
        updatedAt: row.updatedAt.toISOString(),
      })),
      message:
        "Only support-request metadata is stored. Identity documents and free-text identity claims are not collected by this endpoint.",
      isDemo: true,
    };
  }
}
