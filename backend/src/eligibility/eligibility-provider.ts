import { Injectable, ServiceUnavailableException } from "@nestjs/common";

export const ELIGIBILITY_PROVIDER = Symbol("ELIGIBILITY_PROVIDER");

export interface EligibilityProviderConfiguration {
  providerConfigured: boolean;
  policyApproved: boolean;
  providerKey: string | null;
  providerDisplayName: string | null;
  methodDescription: string | null;
  attributesCheckedDescription: string | null;
  biometricProcessingRequired: boolean;
  dataHandlingDescription: string | null;
  retentionAndDeletionDescription: string | null;
  declineOrFailureDescription: string | null;
  manualReviewDescription: string | null;
  consentVersion: string | null;
}

export interface CreateEligibilityProviderSession {
  localSessionId: string;
  accountId: string;
  consentVersion: string;
  biometricProcessingConsented: boolean;
}

export interface EligibilityProviderSession {
  providerReference: string;
  redirectUrl: string;
  expiresAt: Date;
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
      providerDisplayName: null,
      methodDescription: null,
      attributesCheckedDescription: null,
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
}
