import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from "@nestjs/common";
import { createHmac, randomUUID, timingSafeEqual } from "node:crypto";
import { AuthenticationService } from "../auth/auth.service.js";
import { PrismaService } from "../database/prisma.service.js";
import type {
  InitiateDecentroVerificationDto,
  LocalEligibilitySimulationDto,
} from "./eligibility.dto.js";

type JsonRecord = Record<string, unknown>;

type DecentroConfig = {
  baseUrl: string;
  clientId: string;
  clientSecret: string;
  moduleSecret?: string;
  redirectUrl: string;
  webhookSecret?: string;
};

function asRecord(value: unknown): JsonRecord {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as JsonRecord)
    : {};
}

function firstString(...values: unknown[]): string | undefined {
  for (const value of values) {
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return undefined;
}

function calculateAgeYears(dob: Date, today = new Date()): number {
  let age = today.getUTCFullYear() - dob.getUTCFullYear();
  const monthDelta = today.getUTCMonth() - dob.getUTCMonth();
  if (
    monthDelta < 0 ||
    (monthDelta === 0 && today.getUTCDate() < dob.getUTCDate())
  ) {
    age--;
  }
  return age;
}

function parseDateOfBirth(value: string): Date {
  const dateOnly = value.trim().slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateOnly)) {
    throw new BadRequestException(
      "The provider did not return a supported date-of-birth value.",
    );
  }
  const date = new Date(dateOnly + "T00:00:00.000Z");
  if (
    Number.isNaN(date.getTime()) ||
    date.toISOString().slice(0, 10) !== dateOnly ||
    date.getTime() > Date.now()
  ) {
    throw new BadRequestException(
      "The provider returned an invalid date-of-birth value.",
    );
  }
  return date;
}

function normalizeProviderDateOfBirth(value: string): string {
  const trimmed = value.trim();
  const dayFirst = /^(\d{2})-(\d{2})-(\d{4})$/.exec(trimmed);
  if (dayFirst) {
    return `${dayFirst[3]}-${dayFirst[2]}-${dayFirst[1]}`;
  }
  return trimmed.slice(0, 10);
}
@Injectable()
export class DecentroKycService {
  constructor(
    private readonly auth: AuthenticationService,
    private readonly prisma: PrismaService,
  ) {}

  private localSimulatorEnabled(): boolean {
    return (
      process.env.SAKHI_ENABLE_LOCAL_ELIGIBILITY_SIMULATOR === "true" &&
      process.env.SAKHI_ENV === "dev" &&
      process.env.NODE_ENV === "development" &&
      (process.env.HOST ?? "127.0.0.1") === "127.0.0.1"
    );
  }

  private readProviderConfig(): DecentroConfig | null {
    const baseUrl = (
      process.env.DECENTRO_BASE_URL ?? "https://in.staging.decentro.tech"
    ).trim();
    const clientId = process.env.DECENTRO_CLIENT_ID?.trim() ?? "";
    const clientSecret = process.env.DECENTRO_CLIENT_SECRET?.trim() ?? "";
    const moduleSecret = process.env.DECENTRO_KYC_MODULE_SECRET?.trim() ?? "";
    const redirectUrl = process.env.APP_VERIFICATION_CALLBACK_URL?.trim() ?? "";
    const webhookSecret = process.env.DECENTRO_WEBHOOK_SECRET?.trim() ?? "";

    if (
      !clientId ||
      !clientSecret ||
      !redirectUrl ||
      process.env.SAKHI_DECENTRO_POLICY_APPROVED !== "true"
    ) {
      return null;
    }

    try {
      const parsedBase = new URL(baseUrl);
      const parsedRedirect = new URL(redirectUrl);
      if (
        parsedBase.protocol !== "https:" ||
        parsedBase.hostname !== "in.staging.decentro.tech" ||
        parsedBase.pathname !== "/" ||
        parsedBase.search ||
        parsedBase.hash ||
        parsedRedirect.protocol !== "https:" ||
        parsedRedirect.username ||
        parsedRedirect.password ||
        parsedRedirect.hash
      ) {
        return null;
      }
      return {
        baseUrl: parsedBase.origin,
        clientId,
        clientSecret,
        moduleSecret: moduleSecret || undefined,
        redirectUrl: parsedRedirect.toString(),
        webhookSecret: webhookSecret || undefined,
      };
    } catch {
      return null;
    }
  }

  configuration() {
    const config = this.readProviderConfig();
    const simulatorEnabled = this.localSimulatorEnabled();
    return {
      providerConfigured: config !== null,
      providerDisplayName: config ? "Decentro DigiLocker (Staging)" : null,
      callbackSignatureConfigured: Boolean(
        process.env.DECENTRO_WEBHOOK_SECRET?.trim(),
      ),
      policyApproved: process.env.SAKHI_DECENTRO_POLICY_APPROVED === "true",
      canStartVerification: config !== null,
      localSimulatorEnabled: simulatorEnabled,
      mode: config
        ? ("decentro_staging" as const)
        : simulatorEnabled
          ? ("local_simulator" as const)
          : ("development_preview" as const),
      message: config
        ? "Decentro staging credentials and the explicit verification policy gate are configured. A member is marked verified only after Sakhi retrieves a successful, correlated e-Aadhaar result directly from Decentro."
        : simulatorEnabled
          ? "The local eligibility simulator is enabled for the loopback development backend only. It is not identity verification."
          : "Provider verification is not enabled. Configure staging secrets and explicitly approve the verification policy; no client-supplied demographic result can mark an account verified.",
    };
  }

  async initiate(
    authorization: string | undefined,
    dto: InitiateDecentroVerificationDto,
  ) {
    const session = await this.auth.authenticateAuthorization(authorization);
    if (dto?.consent !== true && dto?.consentAccepted !== true) {
      throw new ConflictException({
        code: "decentro_consent_required",
        message:
          "Explicit consent is required before starting DigiLocker identity verification.",
      });
    }

    const consentPurpose =
      dto.consentPurpose?.trim() ||
      "Verifying eligibility for Sakhi membership using DigiLocker demographic attributes";
    if (consentPurpose.length < 21) {
      throw new BadRequestException(
        "The verification purpose must explain why eligibility data is requested.",
      );
    }

    const config = this.readProviderConfig();
    if (!config) {
      throw new ServiceUnavailableException({
        code: "decentro_not_configured",
        message:
          "Decentro staging initiation is disabled until staging client credentials, explicit verification-policy approval, and the HTTPS callback URL are configured.",
      });
    }

    const policy = await this.auth.getRegistrationPolicy();
    if (typeof policy.minimumAgeYears !== "number" || !Number.isInteger(policy.minimumAgeYears) || policy.minimumAgeYears < 13) {
      throw new ServiceUnavailableException(
        "The minimum registration age policy is not configured.",
      );
    }

    const referenceId = randomUUID();
    const callbackUrl = new URL(config.redirectUrl);
    callbackUrl.searchParams.set("referenceId", referenceId);
    const payload = {
      reference_id: referenceId,
      consent: true,
      consent_purpose: consentPurpose,
      redirect_url: callbackUrl.toString(),
      redirect_to_signup: true,
      abstract_access_token: true,
    };

    const abortController = new AbortController();
    const timeout = setTimeout(() => abortController.abort(), 8000);
    let response: Response;
    let responseBody: JsonRecord;
    try {
      response = await fetch(
        config.baseUrl + "/v2/kyc/digilocker/initiate_session",
        {
          method: "POST",
          headers: {
            client_id: config.clientId,
            client_secret: config.clientSecret,
            ...(config.moduleSecret
              ? { module_secret: config.moduleSecret }
              : {}),
            "Content-Type": "application/json",
            Accept: "application/json",
          },
          body: JSON.stringify(payload),
          signal: abortController.signal,
        },
      );
      responseBody = asRecord(await response.json().catch(() => ({})));
    } catch {
      throw new ServiceUnavailableException({
        code: "decentro_unreachable",
        message:
          "The Decentro staging service could not be reached. No verification status was changed; retry later.",
      });
    } finally {
      clearTimeout(timeout);
    }

    const data = asRecord(responseBody.data);
    const authorizationUrl = firstString(
      data.authorizationUrl,
      data.authorization_url,
      responseBody.authorizationUrl,
      responseBody.authorization_url,
      data.url,
    );
    const decentroTxnId = firstString(
      responseBody.decentroTxnId,
      responseBody.decentro_txn_id,
      data.decentroTxnId,
      data.decentro_txn_id,
    );
    const providerStatus = firstString(
      responseBody.status,
      responseBody.responseKey,
      responseBody.response_key,
    )?.toUpperCase();
    if (
      !response.ok ||
      !authorizationUrl ||
      !decentroTxnId ||
      (providerStatus &&
        !["SUCCESS", "S00000", "SUCCESS_INITIATE_SESSION"].includes(
          providerStatus,
        ))
    ) {
      throw new ServiceUnavailableException({
        code: "decentro_session_failed",
        message:
          "Decentro did not return a valid DigiLocker session. No verification status was changed.",
      });
    }

    let parsedAuthorizationUrl: URL;
    try {
      parsedAuthorizationUrl = new URL(authorizationUrl);
    } catch {
      throw new ServiceUnavailableException(
        "Decentro returned an invalid authorization URL.",
      );
    }
    if (
      parsedAuthorizationUrl.protocol !== "https:" ||
      parsedAuthorizationUrl.username ||
      parsedAuthorizationUrl.password
    ) {
      throw new ServiceUnavailableException(
        "Decentro returned an unsafe authorization URL.",
      );
    }

    await this.prisma.auditEvent.create({
      data: {
        actorType: "MEMBER",
        actorId: session.accountId,
        action: "eligibility.decentro.session_initiated",
        targetType: "decentro_verification_session",
        targetId: referenceId,
        outcome: "initiated",
        requestId: randomUUID(),
        redactedMetadata: {
          provider: "Decentro DigiLocker Staging",
          referenceId,
          decentroTxnId,
          consentVersion: dto.consentVersion ?? "sakhi-decentro-kyc-v1",
          consentAccepted: true,
          biometricProcessingConsented:
            dto.biometricProcessingConsented === true,
          rawIdentityDataRetained: false,
        },
      },
    });

    return {
      status: "SUCCESS",
      eligibilityStatus: "VERIFICATION_IN_PROGRESS",
      referenceId,
      decentroTxnId,
      authorizationUrl: parsedAuthorizationUrl.toString(),
      callbackUrl: callbackUrl.toString(),
      message:
        "DigiLocker session initiated. Sakhi will not mark the account verified until it retrieves a successful, correlated e-Aadhaar result directly from Decentro.",
      isDemo: false,
    };
  }

  async status(authorization: string | undefined) {
    const session = await this.auth.authenticateAuthorization(authorization);
    const latestSession = await this.prisma.auditEvent.findFirst({
      where: {
        actorId: session.accountId,
        action: "eligibility.decentro.session_initiated",
        targetType: "decentro_verification_session",
      },
      orderBy: { createdAt: "desc" },
      select: { targetId: true, createdAt: true, redactedMetadata: true },
    });
    const latestCallback = await this.prisma.auditEvent.findFirst({
      where: {
        actorId: session.accountId,
        action: "eligibility.decentro.callback_processed",
      },
      orderBy: { createdAt: "desc" },
      select: { outcome: true, createdAt: true },
    });
    const verified = session.account.verificationStatus === "VERIFIED";
    const testAccessApproved = session.testAccessApproved === true;
    return {
      eligibilityStatus: verified
        ? "VERIFIED"
        : session.account.verificationStatus === "REJECTED"
          ? "REJECTED"
          : latestSession
            ? "VERIFICATION_IN_PROGRESS"
            : "UNVERIFIED",
      accountStatus: session.account.status,
      verificationStatus: session.account.verificationStatus,
      referenceId: latestSession?.targetId ?? null,
      sessionInitiatedAt: latestSession?.createdAt.toISOString() ?? null,
      lastProviderCallbackAt: latestCallback?.createdAt.toISOString() ?? null,
      lastProviderCallbackOutcome: latestCallback?.outcome ?? null,
      testAccessApproved,
      localSimulatorEnabled: this.localSimulatorEnabled(),
      message: testAccessApproved
        ? "Staging test access is active. Features are unlocked for testing only; phone ownership and identity eligibility remain unverified."
        : verified
          ? "An authorized provider result or admin decision marked this account verified."
          : latestCallback
            ? "A provider result was received but has not yet produced a verified eligibility decision."
            : latestSession
              ? "DigiLocker session started. Return to Sakhi and refresh status after completing the provider flow."
              : "No completed provider verification is recorded.",
      isDemo: false,
    };
  }

  async completeBrowserCallback(referenceId?: string) {
    const ref = referenceId?.trim() ?? "";
    if (!/^[0-9a-f-]{36}$/i.test(ref)) {
      throw new BadRequestException("The Sakhi verification reference is invalid.");
    }
    const config = this.readProviderConfig();
    if (!config) {
      throw new ServiceUnavailableException({
        code: "decentro_callback_not_configured",
        message: "Server-side Decentro result lookup is not configured.",
      });
    }
    const initiation = await this.prisma.auditEvent.findFirst({
      where: {
        action: "eligibility.decentro.session_initiated",
        targetType: "decentro_verification_session",
        targetId: ref,
      },
      orderBy: { createdAt: "desc" },
      select: { actorId: true, createdAt: true, redactedMetadata: true },
    });
    if (!initiation?.actorId) {
      throw new BadRequestException("No matching Sakhi verification session was found.");
    }
    const metadata = asRecord(initiation.redactedMetadata);
    const initialTxnId = firstString(metadata.decentroTxnId);
    if (!initialTxnId) {
      throw new ServiceUnavailableException("The provider transaction reference is missing.");
    }
    const completed = await this.prisma.auditEvent.findFirst({
      where: {
        action: "eligibility.decentro.callback_processed",
        targetType: "decentro_webhook",
        targetId: ref,
      },
      select: { outcome: true },
    });
    if (completed) {
      return {
        status: "already_processed",
        eligibilityStatus: completed.outcome === "verified" ? "VERIFIED" : "REJECTED",
        isDemo: false,
      };
    }
    const ageMs = Date.now() - initiation.createdAt.getTime();
    if (ageMs < 0 || ageMs > 60 * 60 * 1000) {
      throw new ConflictException({
        code: "decentro_session_expired",
        message: "This DigiLocker session has expired. Start a new session in Sakhi.",
      });
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10000);
    let response: Response;
    let body: JsonRecord;
    try {
      response = await fetch(config.baseUrl + "/v2/kyc/digilocker/eaadhaar", {
        method: "POST",
        headers: {
          client_id: config.clientId,
          client_secret: config.clientSecret,
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify({
          initial_decentro_transaction_id: initialTxnId,
          consent: true,
          consent_purpose: "Retrieve DigiLocker-confirmed e-Aadhaar demographics for Sakhi eligibility verification",
          reference_id: randomUUID(),
          generate_xml: false,
          generate_pdf: false,
        }),
        signal: controller.signal,
      });
      body = asRecord(await response.json().catch(() => ({})));
    } catch {
      throw new ServiceUnavailableException({
        code: "decentro_result_unavailable",
        message: "Decentro did not return a result. No verification status was changed.",
      });
    } finally {
      clearTimeout(timeout);
    }

    const data = asRecord(body.data);
    const status = firstString(body.status)?.toUpperCase();
    const code = firstString(body.responseCode);
    const responseKey = firstString(body.responseKey);
    if (
      !response.ok ||
      status !== "SUCCESS" ||
      code !== "S00000" ||
      responseKey !== "success_eaadhaar_download"
    ) {
      throw new ServiceUnavailableException({
        code: "decentro_result_not_successful",
        message: "Decentro has not confirmed a completed e-Aadhaar result. No verification status was changed.",
      });
    }
    const proof = asRecord(data.proofOfIdentity ?? data.proof_of_identity);
    const gender = firstString(proof.gender);
    const dobRaw = firstString(proof.dob, proof.dateOfBirth, proof.date_of_birth);
    if (!gender || !dobRaw) {
      throw new ServiceUnavailableException({
        code: "decentro_demographics_missing",
        message: "The provider response lacks required demographics. No verification status was changed.",
      });
    }
    const dayFirst = /^(\d{2})-(\d{2})-(\d{4})$/.exec(dobRaw.trim());
    const dob = dayFirst
      ? dayFirst[3] + "-" + dayFirst[2] + "-" + dayFirst[1]
      : dobRaw.trim().slice(0, 10);
    const consentVersion =
      typeof metadata.consentVersion === "string"
        ? metadata.consentVersion
        : "sakhi-decentro-kyc-v1";
    // The raw provider response is used in memory only; identity documents,
    // Aadhaar UID, name, address, image and raw DOB are neither stored nor returned.
    return this.applyDemographicDecision({
      accountId: initiation.actorId,
      gender,
      dob,
      referenceId: ref,
      decentroTxnId: initialTxnId,
      callbackTransactionId: ref,
      consentVersion,
      consentAcceptedAt: initiation.createdAt,
      isDemo: false,
    });
  }

  async handleSignedCallback(rawBody: Buffer | undefined, signature?: string) {
    const config = this.readProviderConfig();
    if (!config || !config.webhookSecret) {
      throw new ServiceUnavailableException({
        code: "decentro_callback_not_configured",
        message:
          "The optional signed-webhook adapter is disabled until its separately validated webhook secret is configured.",
      });
    }
    if (!rawBody?.length) {
      throw new BadRequestException(
        "The original callback payload is required for signature validation.",
      );
    }
    if (!signature?.trim()) {
      throw new UnauthorizedException("The provider signature is missing.");
    }
    const received = signature.trim().replace(/^sha256=/i, "");
    const expected = createHmac("sha256", config.webhookSecret)
      .update(rawBody)
      .digest("base64");
    const receivedBytes = Buffer.from(received, "utf8");
    const expectedBytes = Buffer.from(expected, "utf8");
    if (
      receivedBytes.length !== expectedBytes.length ||
      !timingSafeEqual(receivedBytes, expectedBytes)
    ) {
      throw new UnauthorizedException("The provider signature is invalid.");
    }

    let body: JsonRecord;
    try {
      body = asRecord(JSON.parse(rawBody.toString("utf8")) as unknown);
    } catch {
      throw new BadRequestException("The provider callback payload is invalid.");
    }

    const data = asRecord(body.data);
    const proof = asRecord(data.proofOfIdentity ?? data.proof_of_identity);
    const referenceId = firstString(
      body.referenceId,
      body.reference_id,
      data.referenceId,
      data.reference_id,
    );
    const decentroTxnId = firstString(
      body.decentroTxnId,
      body.decentro_txn_id,
      body.decentro_transaction_id,
      data.decentroTxnId,
      data.decentro_txn_id,
      data.decentro_transaction_id,
    );
    const callbackTransactionId = firstString(
      body.callback_transaction_id,
      data.callback_transaction_id,
    );
    if (!referenceId || !decentroTxnId || !callbackTransactionId) {
      throw new BadRequestException(
        "The signed callback is missing a required correlation identifier.",
      );
    }

    const initiation = await this.prisma.auditEvent.findFirst({
      where: {
        action: "eligibility.decentro.session_initiated",
        targetType: "decentro_verification_session",
        targetId: referenceId,
      },
      orderBy: { createdAt: "desc" },
      select: {
        actorId: true,
        createdAt: true,
        redactedMetadata: true,
      },
    });
    if (!initiation?.actorId) {
      throw new BadRequestException(
        "The signed callback does not match a Sakhi verification session.",
      );
    }
    const initiationMetadata = asRecord(initiation.redactedMetadata);
    if (initiationMetadata.decentroTxnId !== decentroTxnId) {
      throw new BadRequestException(
        "The signed callback transaction does not match its Sakhi session.",
      );
    }

    const duplicate = await this.prisma.auditEvent.findFirst({
      where: {
        action: "eligibility.decentro.callback_processed",
        targetType: "decentro_webhook",
        targetId: callbackTransactionId,
      },
      select: { id: true, outcome: true },
    });
    if (duplicate) {
      return {
        status: "already_processed",
        outcome: duplicate.outcome,
        isDemo: false,
      };
    }

    const providerStatus = firstString(
      body.status,
      body.transaction_status,
      body.transactionStatus,
      data.status,
      data.transaction_status,
    )?.toUpperCase();
    const success = ["SUCCESS", "SUCCESSFUL", "COMPLETED", "VERIFIED", "S00000"].includes(
      providerStatus ?? "",
    );
    if (!success) {
      await this.recordCallbackReceipt(
        initiation.actorId,
        referenceId,
        decentroTxnId,
        callbackTransactionId,
        "provider_not_successful",
      );
      return {
        status: "received",
        eligibilityStatus: "UNVERIFIED",
        message:
          "The signed provider callback was received, but the provider did not confirm successful verification.",
        isDemo: false,
      };
    }

    const gender = firstString(
      body.gender,
      data.gender,
      proof.gender,
      data.gender_attribute,
    );
    const dob = firstString(
      body.dob,
      body.dateOfBirth,
      body.date_of_birth,
      data.dob,
      data.dateOfBirth,
      data.date_of_birth,
      proof.dob,
      proof.dateOfBirth,
      proof.date_of_birth,
    );
    if (!gender || !dob) {
      await this.recordCallbackReceipt(
        initiation.actorId,
        referenceId,
        decentroTxnId,
        callbackTransactionId,
        "demographics_missing",
      );
      return {
        status: "received",
        eligibilityStatus: "UNVERIFIED",
        message:
          "The signed callback did not include the required demographic attributes. No account verification status was changed.",
        isDemo: false,
      };
    }

    const consentVersion =
      typeof initiationMetadata.consentVersion === "string"
        ? initiationMetadata.consentVersion
        : "sakhi-decentro-kyc-v1";
    const result = await this.applyDemographicDecision({
      accountId: initiation.actorId,
      gender,
      dob,
      referenceId,
      decentroTxnId,
      callbackTransactionId,
      consentVersion,
      consentAcceptedAt: initiation.createdAt,
      isDemo: false,
    });
    return result;
  }

  async simulateLocalResult(
    authorization: string | undefined,
    dto: LocalEligibilitySimulationDto,
  ) {
    if (!this.localSimulatorEnabled()) {
      throw new ForbiddenException(
        "The eligibility simulator is available only on an explicitly enabled loopback development backend.",
      );
    }
    await this.auth.authenticateAuthorization(authorization);
    if (!dto?.gender?.trim() || !dto?.dob?.trim()) {
      throw new BadRequestException(
        "Provide test demographic values for the local simulation.",
      );
    }

    // This path is a UI/test fixture only. It must not change account,
    // submission, or verification status and can never establish real identity.
    const dob = parseDateOfBirth(dto.dob);
    const policy = await this.auth.getRegistrationPolicy();
    const minimumAge = policy.minimumAgeYears;
    if (
      typeof minimumAge !== "number" ||
      !Number.isInteger(minimumAge) ||
      minimumAge < 13
    ) {
      throw new ServiceUnavailableException(
        "The minimum registration age policy is not configured.",
      );
    }
    const gender = dto.gender.trim().toUpperCase();
    const genderEligible = ["F", "FEMALE", "WOMAN"].includes(gender);
    const ageYears = calculateAgeYears(dob);
    const ageEligible = ageYears >= minimumAge;

    return {
      status: "SIMULATION_ONLY",
      eligibilityStatus:
        genderEligible && ageEligible
          ? "SIMULATION_PASSED"
          : "SIMULATION_REJECTED",
      genderMatchedFemale: genderEligible,
      ageEligible,
      ageYears,
      minimumAgeRequired: minimumAge,
      persisted: false,
      identityVerified: false,
      verificationStatusChanged: false,
      isDemo: true,
      message:
        genderEligible && ageEligible
          ? "Local simulator passed the synthetic demographic test. No identity was verified and no account status was changed."
          : "Local simulator rejected the synthetic demographic test. No identity was verified and no account status was changed.",
    };
  }
  private async recordCallbackReceipt(
    accountId: string,
    referenceId: string,
    decentroTxnId: string,
    callbackTransactionId: string,
    outcome: string,
  ) {
    return this.prisma.auditEvent.create({
      data: {
        actorType: "PROVIDER",
        actorId: accountId,
        action: "eligibility.decentro.callback_processed",
        targetType: "decentro_webhook",
        targetId: callbackTransactionId,
        outcome,
        requestId: randomUUID(),
        redactedMetadata: {
          provider: "Decentro DigiLocker Staging",
          referenceId,
          decentroTxnId,
          callbackTransactionId,
          demographicDataRetained: false,
        },
      },
    });
  }

  private async applyDemographicDecision(input: {
    accountId: string;
    gender: string;
    dob: string;
    referenceId: string;
    decentroTxnId: string;
    callbackTransactionId?: string;
    consentVersion: string;
    consentAcceptedAt: Date;
    isDemo: boolean;
  }) {
    const dob = parseDateOfBirth(input.dob);
    const policy = await this.auth.getRegistrationPolicy();
    const minimumAge = policy.minimumAgeYears;
    if (typeof minimumAge !== "number" || !Number.isInteger(minimumAge) || minimumAge < 13) {
      throw new ServiceUnavailableException(
        "The minimum registration age policy is not configured.",
      );
    }
    const gender = input.gender.trim().toUpperCase();
    const isFemale = gender === "F" || gender === "FEMALE" || gender === "WOMAN";
    const ageYears = calculateAgeYears(dob);
    const ageEligible = ageYears >= minimumAge;
    const verified = isFemale && ageEligible;
    const account = await this.prisma.memberAccount.findUnique({
      where: { id: input.accountId },
      select: { id: true, status: true, verificationStatus: true },
    });
    if (!account) {
      throw new BadRequestException("The member account was not found.");
    }
    if (["RESTRICTED", "SUSPENDED", "DELETED"].includes(account.status)) {
      throw new ForbiddenException(
        "This account cannot be activated by eligibility verification.",
      );
    }

    const nextAccountStatus = verified ? "ACTIVE" : "PENDING_VERIFICATION";
    const nextVerificationStatus = verified ? "VERIFIED" : "REJECTED";
    const nextSubmissionStatus = verified ? "APPROVED" : "REJECTED";
    const decisionReason = verified
      ? "Provider-confirmed demographic eligibility met the configured policy."
      : "Provider-confirmed demographic eligibility did not meet the configured policy.";

    return this.prisma.$transaction(async (tx) => {
      if (input.callbackTransactionId) {
        const duplicate = await tx.auditEvent.findFirst({
          where: {
            action: "eligibility.decentro.callback_processed",
            targetType: "decentro_webhook",
            targetId: input.callbackTransactionId,
          },
          select: { id: true, outcome: true },
        });
        if (duplicate) {
          return {
            status: "already_processed",
            outcome: duplicate.outcome,
            isDemo: false,
          };
        }
      }

      await tx.memberAccount.update({
        where: { id: input.accountId },
        data: {
          status: nextAccountStatus,
          verificationStatus: nextVerificationStatus,
        },
      });

      const latestSubmission = await tx.eligibilitySubmission.findFirst({
        where: { accountId: input.accountId },
        orderBy: { submittedAt: "desc" },
        select: { id: true },
      });
      if (latestSubmission) {
        await tx.eligibilitySubmission.update({
          where: { id: latestSubmission.id },
          data: {
            status: nextSubmissionStatus,
            reviewedAt: new Date(),
            reviewerLabel: input.isDemo
              ? "Local eligibility simulator"
              : "Decentro DigiLocker KYC",
            decisionReason,
          },
        });
      } else {
        await tx.eligibilitySubmission.create({
          data: {
            accountId: input.accountId,
            status: nextSubmissionStatus,
            consentVersion: input.consentVersion,
            consentAcceptedAt: input.consentAcceptedAt,
            reviewedAt: new Date(),
            reviewerLabel: input.isDemo
              ? "Local eligibility simulator"
              : "Decentro DigiLocker KYC",
            decisionReason,
          },
        });
      }

      await tx.auditEvent.create({
        data: {
          actorType: input.isDemo ? "SYSTEM" : "PROVIDER",
          actorId: input.accountId,
          action: input.isDemo
            ? "eligibility.local_simulator.completed"
            : "eligibility.decentro.callback_processed",
          targetType: input.isDemo ? "member_account" : "decentro_webhook",
          targetId: input.isDemo
            ? input.accountId
            : input.callbackTransactionId!,
          outcome: verified ? "verified" : "rejected",
          requestId: input.isDemo
            ? randomUUID()
            : input.callbackTransactionId!,
          redactedMetadata: {
            provider: input.isDemo
              ? "Local development simulator"
              : "Decentro DigiLocker Staging",
            referenceId: input.referenceId,
            decentroTxnId: input.decentroTxnId,
            callbackTransactionId: input.callbackTransactionId ?? null,
            genderMatchedFemale: isFemale,
            ageVerifiedAboveMinimum: ageEligible,
            minimumAgeRequired: minimumAge,
            rawDateOfBirthRetained: false,
            rawIdentityDocumentRetained: false,
            isDemo: input.isDemo,
          },
        },
      });

      return {
        status: verified ? "verified" : "rejected",
        eligibilityStatus: nextSubmissionStatus,
        accountStatus: nextAccountStatus,
        verificationStatus: nextVerificationStatus,
        referenceId: input.referenceId,
        decentroTxnId: input.decentroTxnId,
        genderMatchedFemale: isFemale,
        ageVerifiedAboveMinimum: ageEligible,
        minimumAgeRequired: minimumAge,
        message: verified
          ? input.isDemo
            ? "Local simulator completed. This is not provider identity verification."
            : "The signed Decentro result met the Sakhi eligibility policy."
          : "The demographic result did not meet the Sakhi eligibility policy.",
        isDemo: input.isDemo,
      };
    });
  }
}
