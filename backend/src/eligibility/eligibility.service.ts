import { ConflictException, Injectable } from "@nestjs/common";
import { AuthenticationService } from "../auth/auth.service.js";

@Injectable()
export class EligibilityService {
  constructor(private readonly auth: AuthenticationService) {}

  configuration() {
    // Deliberately unconfigured until an authorised provider, lawful method,
    // policy and reviewed disclosures have been approved.
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
      manualReviewDescription: null,
      consentVersion: null,
      canStartVerification: false,
      mode: "development_preview" as const,
    };
  }

  async status(authorization?: string) {
    const session = await this.auth.authenticateAuthorization(authorization);
    return {
      status: "providerUnavailable" as const,
      message:
        "No approved eligibility provider or policy is configured. No verification session exists.",
      isDemo: true,
    };
  }

  async start(authorization?: string) {
    await this.auth.authenticateAuthorization(authorization);
    // Never create a fake transaction or store a preview consent as production
    // consent. The same fail-closed result is returned until integration is approved.
    throw new ConflictException({
      statusCode: 409,
      code: "eligibility_provider_unavailable",
      status: "providerUnavailable",
      message:
        "Eligibility verification has not been configured. No session was created and no identity data was collected.",
      isDemo: true,
    });
  }
}
