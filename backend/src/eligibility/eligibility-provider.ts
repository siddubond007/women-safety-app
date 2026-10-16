import { Injectable, ServiceUnavailableException } from "@nestjs/common";

export const ELIGIBILITY_PROVIDER = Symbol("ELIGIBILITY_PROVIDER");

export interface EligibilityProviderConfiguration {
  providerConfigured: boolean;
  policyApproved: boolean;
  providerKey: string | null;
  redirectHosts: readonly string[];
  providerDisplayName: string | null;
  methodDescription: string | null;
  attributesCheckedDescription: string | null;
  biometricProcessingSupported: boolean;
  biometricProcessingRequired: boolean;
  dataHandlingDescription: string | null;
  retentionAndDeletionDescription: string | null;
  declineOrFailureDescription: string | null;
  manualReviewDescription: string | null;
  consentVersion: string | null;
}

export interface CreateEligibilityProviderSession {
  localSessionId: string;
  consentVersion: string;
  biometricProcessingConsented: boolean;
}

export interface EligibilityProviderSession {
  providerReference: string;
  redirectUrl: string;
  expiresAt: Date;
}

/**
 * Only the approved provider adapter may normalize an authenticated callback
 * into one of these conservative outcomes. Ambiguous or unsupported results
 * must map to PENDING_MANUAL_REVIEW, never to VERIFIED.
 */
export const ELIGIBILITY_PROVIDER_CALLBACK_OUTCOMES = [
  "VERIFIED",
  "PENDING_MANUAL_REVIEW",
  "VERIFICATION_FAILED",
] as const;

export type EligibilityProviderCallbackOutcome =
  (typeof ELIGIBILITY_PROVIDER_CALLBACK_OUTCOMES)[number];

export interface EligibilityProviderCallbackInput {
  /** Exact request bytes, before JSON parsing; never log or persist this value. */
  rawBody: Buffer;
  /** Adapter-specific signature/timestamp headers, supplied without alteration. */
  headers: Readonly<Record<string, string | string[] | undefined>>;
}

export interface NormalizedEligibilityProviderCallback {
  /** Stable provider event identifier used for durable replay protection. */
  eventId: string;
  /** Opaque provider reference previously saved on the matching local session. */
  providerReference: string;
  /** A verified, provider-authenticated normalized result. */
  outcome: EligibilityProviderCallbackOutcome;
}

/**
 * Adapter contract for a legally approved provider. Implementations must only
 * return attributes permitted for the reviewed eligibility criterion. They
 * must never infer gender from appearance or equate phone/Aadhaar OTP success
 * with eligibility approval.
 */
export interface EligibilityProviderAdapter {
  configuration(): EligibilityProviderConfiguration;
  startSession(
    input: CreateEligibilityProviderSession,
  ): Promise<EligibilityProviderSession>;
  /**
   * Verify provider-specific signature/authentication, timestamp freshness,
   * and event schema over rawBody before returning a normalized event. An
   * implementation must reject an invalid signature and must never trust a
   * redirect query string or client-supplied result.
   */
  verifyAndNormalizeCallback(
    input: EligibilityProviderCallbackInput,
  ): Promise<NormalizedEligibilityProviderCallback>;
  cancelSession?(input: { providerReference: string }): Promise<void>;
}

/**
 * Safe default. No identity provider has been selected or approved for Sakhi,
 * so this adapter cannot collect identity data or create provider sessions.
 */
@Injectable()
export class UnconfiguredEligibilityProviderAdapter
  implements EligibilityProviderAdapter
{
  configuration(): EligibilityProviderConfiguration {
    return {
      providerConfigured: false,
      policyApproved: false,
      providerKey: null,
      redirectHosts: [],
      providerDisplayName: null,
      methodDescription: null,
      attributesCheckedDescription: null,
      biometricProcessingSupported: false,
      biometricProcessingRequired: false,
      dataHandlingDescription: null,
      retentionAndDeletionDescription: null,
      declineOrFailureDescription: null,
      manualReviewDescription:
        "Human review decisions are not enabled until an approved review policy and authorized reviewer roles are established.",
      consentVersion: null,
    };
  }

  async startSession(
    _input: CreateEligibilityProviderSession,
  ): Promise<EligibilityProviderSession> {
    throw new ServiceUnavailableException(
      "No approved eligibility provider is configured. No identity data was sent.",
    );
  }

  async verifyAndNormalizeCallback(
    _input: EligibilityProviderCallbackInput,
  ): Promise<NormalizedEligibilityProviderCallback> {
    throw new ServiceUnavailableException(
      "No approved eligibility provider callback validator is configured.",
    );
  }
}
