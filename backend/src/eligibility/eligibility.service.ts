import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
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
  ELIGIBILITY_PROVIDER_CALLBACK_OUTCOMES,
  type EligibilityProviderCallbackOutcome,
  type NormalizedEligibilityProviderCallback,
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

class EligibilityRateLimitException extends HttpException {
  constructor(message: string) {
    super(message, HttpStatus.TOO_MANY_REQUESTS);
  }
}

const SUPPORT_REQUEST_WINDOW_MS = 24 * 60 * 60 * 1000;
const MAX_SUPPORT_REQUESTS_PER_WINDOW = 5;

const PROVIDER_CALLBACK_STATUS: Record<
  EligibilityProviderCallbackOutcome,
  EligibilityVerificationStatus
> = {
  VERIFIED: ELIGIBILITY_VERIFICATION_STATUS.VERIFIED,
  PENDING_MANUAL_REVIEW:
    ELIGIBILITY_VERIFICATION_STATUS.PENDING_MANUAL_REVIEW,
  VERIFICATION_FAILED: ELIGIBILITY_VERIFICATION_STATUS.VERIFICATION_FAILED,
};

const PROVIDER_CALLBACK_SESSION_STATUS: Record<
  EligibilityProviderCallbackOutcome,
  "COMPLETED" | "FAILED"
> = {
  VERIFIED: "COMPLETED",
  PENDING_MANUAL_REVIEW: "COMPLETED",
  VERIFICATION_FAILED: "FAILED",
};

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
      Boolean(provider.consentVersion) &&
      provider.redirectHosts.length > 0;

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
    const readiness = this.configuration();
    const eligibilityStatus =
      session.account.eligibilityStatus as EligibilityVerificationStatus;

    return {
      // Keep the existing providerUnavailable contract until an approved
      // adapter is actually configured and the mobile client supports it.
      status: readiness.canStartVerification
        ? ("providerConfigured" as const)
        : ("providerUnavailable" as const),
      eligibilityStatus: ELIGIBILITY_STATUS_API_VALUE[eligibilityStatus],
      providerConfigured: provider.providerConfigured,
      policyApproved: provider.policyApproved,
      canStartVerification: readiness.canStartVerification,
      supportRequestsAvailable: true,
      message: readiness.canStartVerification
        ? "An approved provider is configured. Eligibility is still determined only by the trusted backend result."
        : "No approved eligibility provider or policy is configured. No verification session exists.",
      isDemo: !readiness.canStartVerification,
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
      !consentVersion ||
      provider.redirectHosts.length === 0
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
    if (dto.consentVersion !== consentVersion) {
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

    const now = new Date();
    const activeSession = await this.prisma.eligibilityVerificationSession.findFirst({
      where: {
        accountId,
        OR: [
          {
            status: "CREATED",
            expiresAt: { gt: now },
          },
          {
            status: "REDIRECT_READY",
            expiresAt: { gt: now },
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
    // Bound a crash between session creation and provider redirect creation so
    // stale CREATED rows cannot block a member from retrying indefinitely.
    const providerStartDeadline = new Date(Date.now() + 5 * 60 * 1000);
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
          expiresAt: providerStartDeadline,
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
            noticeVersion: consentVersion,
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

    let providerSession: EligibilityProviderSession | undefined;
    try {
      const candidate = await this.provider.startSession({
        localSessionId,
        consentVersion,
        biometricProcessingConsented: dto.biometricProcessingConsented === true,
      });
      providerSession = candidate;
      this.validateProviderSession(candidate, provider.redirectHosts);
    } catch {
      if (providerSession && this.provider.cancelSession) {
        await this.provider
          .cancelSession({ providerReference: providerSession.providerReference })
          .catch(() => undefined);
      }
      await this.failProviderStart(localSessionId, accountId, currentStatus).catch(() => undefined);
      throw new ServiceUnavailableException({
        code: "eligibility_provider_start_failed",
        message: "The verification session could not be started. Your account remains not verified; retry later or contact support.",
      });
    }

    if (!providerSession) {
      await this.failProviderStart(localSessionId, accountId, currentStatus).catch(() => undefined);
      throw new ServiceUnavailableException({
        code: "eligibility_provider_start_failed",
        message: "The verification session could not be started. Your account remains not verified; retry later or contact support.",
      });
    }

    const readyProviderSession = providerSession;
    try {
      await this.prisma.$transaction(async (tx) => {
        await tx.eligibilityVerificationSession.update({
          where: { id: localSessionId },
          data: {
            providerReference: readyProviderSession.providerReference,
            status: "REDIRECT_READY",
            expiresAt: readyProviderSession.expiresAt,
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
              expiresAt: readyProviderSession.expiresAt.toISOString(),
            },
          },
          select: { id: true },
        });
      });
    } catch {
      if (this.provider.cancelSession) {
        await this.provider
          .cancelSession({ providerReference: readyProviderSession.providerReference })
          .catch(() => undefined);
      }
      await this.failProviderStart(localSessionId, accountId, currentStatus).catch(() => undefined);
      throw new ServiceUnavailableException({
        code: "eligibility_session_persistence_failed",
        message: "The provider session could not be safely recorded. No eligibility approval was granted; retry later or contact support.",
      });
    }

    return {
      status: "verificationInProgress" as const,
      eligibilityStatus: "verificationInProgress" as const,
      sessionId: localSessionId,
      redirectUrl: readyProviderSession.redirectUrl,
      expiresAt: readyProviderSession.expiresAt.toISOString(),
      providerConfigured: true,
      message: "Continue with the approved provider. Eligibility is not granted until the backend validates the provider result.",
      isDemo: false,
    };
  }

  /**
   * Processes only an event already authenticated and normalized by the
   * configured provider adapter. The raw payload is transient and never
   * stored or logged. Event claiming, session completion, status change, and
   * audit record are committed in one transaction.
   */
  async processProviderCallback(
    rawBody: Buffer | undefined,
    headers: Readonly<Record<string, string | string[] | undefined>>,
  ): Promise<{ accepted: true; duplicate: boolean }> {
    const configuration = this.providerConfiguration();
    if (
      !configuration.providerConfigured ||
      !configuration.policyApproved ||
      !configuration.providerKey ||
      !configuration.consentVersion ||
      configuration.redirectHosts.length === 0
    ) {
      throw new ServiceUnavailableException({
        code: "eligibility_provider_unavailable",
        message: "Provider callbacks are unavailable because no approved provider is configured.",
      });
    }

    if (
      !Buffer.isBuffer(rawBody) ||
      rawBody.length === 0 ||
      rawBody.length > 64 * 1024
    ) {
      throw new BadRequestException({
        code: "invalid_provider_callback_body",
        message: "A bounded raw provider callback body is required.",
      });
    }

    // Signature format and timestamp rules belong to the specific approved
    // provider adapter. No generic or guessed signature convention is trusted.
    const event = await this.provider.verifyAndNormalizeCallback({
      rawBody,
      headers,
    });
    this.validateNormalizedProviderCallback(event);

    const providerKey = configuration.providerKey;
    const receivedAt = new Date();

    return this.prisma.$transaction(async (tx) => {
      const priorEvent = await tx.eligibilityProviderCallbackEvent.findUnique({
        where: {
          providerKey_providerEventId: {
            providerKey,
            providerEventId: event.eventId,
          },
        },
        select: { id: true },
      });
      if (priorEvent) {
        return { accepted: true as const, duplicate: true as const };
      }

      const verificationSession =
        await tx.eligibilityVerificationSession.findUnique({
          where: {
            providerKey_providerReference: {
              providerKey,
              providerReference: event.providerReference,
            },
          },
          select: {
            id: true,
            accountId: true,
            status: true,
            expiresAt: true,
            account: { select: { eligibilityStatus: true } },
          },
        });

      // Do not disclose whether an unknown provider reference belongs to a member.
      if (!verificationSession) {
        throw new UnauthorizedException({
          code: "eligibility_callback_untrusted",
          message: "The provider callback could not be matched to an active session.",
        });
      }

      if (
        verificationSession.status !== "REDIRECT_READY" ||
        !verificationSession.expiresAt ||
        verificationSession.expiresAt.getTime() <= receivedAt.getTime()
      ) {
        throw new ConflictException({
          code: "eligibility_callback_session_inactive",
          message: "The provider callback session is no longer active.",
        });
      }

      const currentStatus =
        verificationSession.account
          .eligibilityStatus as EligibilityVerificationStatus;
      const nextStatus = PROVIDER_CALLBACK_STATUS[event.outcome];

      if (
        currentStatus !==
          ELIGIBILITY_VERIFICATION_STATUS.VERIFICATION_IN_PROGRESS ||
        !canTransitionEligibilityStatus(currentStatus, nextStatus, "PROVIDER")
      ) {
        throw new ConflictException({
          code: "eligibility_callback_transition_not_allowed",
          message: "The provider result cannot be applied to the current eligibility state.",
        });
      }

      // The database's unique provider/event key is the concurrency-safe replay
      // barrier. Only the transaction that claims the event may apply the result.
      const claimedEvent = await tx.eligibilityProviderCallbackEvent.createMany({
        data: [
          {
            id: randomUUID(),
            providerKey,
            providerEventId: event.eventId,
            sessionId: verificationSession.id,
            outcome: event.outcome,
          },
        ],
        skipDuplicates: true,
      });
      if (claimedEvent.count !== 1) {
        return { accepted: true as const, duplicate: true as const };
      }

      const accountUpdate = await tx.memberAccount.updateMany({
        where: {
          id: verificationSession.accountId,
          eligibilityStatus: currentStatus,
        },
        data: { eligibilityStatus: nextStatus },
      });
      if (accountUpdate.count !== 1) {
        throw new ConflictException({
          code: "eligibility_callback_status_changed",
          message: "The eligibility state changed before the provider result could be applied.",
        });
      }

      const sessionUpdate =
        await tx.eligibilityVerificationSession.updateMany({
          where: {
            id: verificationSession.id,
            status: "REDIRECT_READY",
            expiresAt: { gt: receivedAt },
          },
          data: {
            status: PROVIDER_CALLBACK_SESSION_STATUS[event.outcome],
            completedAt: receivedAt,
          },
        });
      if (sessionUpdate.count !== 1) {
        throw new ConflictException({
          code: "eligibility_callback_session_changed",
          message: "The provider session changed before the callback could be applied.",
        });
      }

      await tx.auditEvent.create({
        data: {
          actorType: "PROVIDER",
          action: "eligibility.provider_result.applied",
          targetType: "eligibility_verification_session",
          targetId: verificationSession.id,
          outcome:
            event.outcome === "VERIFIED"
              ? "success"
              : event.outcome === "PENDING_MANUAL_REVIEW"
                ? "review_required"
                : "failed",
          requestId: randomUUID(),
          redactedMetadata: {
            providerKey,
            providerOutcome: event.outcome,
            from: currentStatus,
            to: nextStatus,
          },
        },
        select: { id: true },
      });

      return { accepted: true as const, duplicate: false as const };
    });
  }

  private validateNormalizedProviderCallback(
    event: NormalizedEligibilityProviderCallback,
  ): void {
    if (
      !event ||
      typeof event !== "object" ||
      typeof event.eventId !== "string" ||
      event.eventId.trim().length === 0 ||
      event.eventId.length > 255 ||
      typeof event.providerReference !== "string" ||
      event.providerReference.trim().length === 0 ||
      event.providerReference.length > 255 ||
      !ELIGIBILITY_PROVIDER_CALLBACK_OUTCOMES.includes(
        event.outcome as EligibilityProviderCallbackOutcome,
      )
    ) {
      throw new UnauthorizedException({
        code: "eligibility_callback_untrusted",
        message: "The provider callback could not be authenticated and normalized.",
      });
    }
  }

  private validateProviderSession(
    session: EligibilityProviderSession,
    allowedRedirectHosts: readonly string[],
  ): void {
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
      redirect.password.length > 0 ||
      !allowedRedirectHosts.some(
        (host) => host.toLowerCase() === redirect.hostname.toLowerCase(),
      )
    ) {
      throw new Error(
        "Provider redirect must use HTTPS, omit embedded credentials, and match the configured provider host allowlist",
      );
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
    originalStatus: EligibilityVerificationStatus,
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
        data: { eligibilityStatus: originalStatus },
      });
      await tx.auditEvent.create({
        data: {
          actorType: "SYSTEM",
          action: "eligibility.provider_session.failed",
          targetType: "eligibility_verification_session",
          targetId: localSessionId,
          outcome: "failed",
          requestId: localSessionId,
          redactedMetadata: { reason: "provider_start_or_persistence_failure", statusRestoredTo: originalStatus },
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
      throw new EligibilityRateLimitException(
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
