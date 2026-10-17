/// Provider-neutral models for Sakhi's eligibility-verification boundary.
///
/// These types describe UI/service states only. They do not prove identity,
/// gender, age, or community eligibility.
enum EligibilityStatus {
  // Canonical persisted backend statuses (mapped below into user-facing labels).
  notVerified,
  inProgress,
  pendingManualReview,
  verified,
  verificationFailed,
  temporarilyRestricted,
  reverificationRequired,

  // Non-decision UI/service states that are not persisted eligibility outcomes.
  notStarted,
  consentRequired,
  cancelled,
  providerUnavailable,
  consentNotGiven,
}

/// Configuration is usable only when the provider and its legal/policy setup
/// have both been explicitly approved and supplied by a trusted service.
class EligibilityConfiguration {
  const EligibilityConfiguration({
    required this.providerConfigured,
    required this.policyApproved,
    this.biometricProcessingSupported = false,
    this.biometricProcessingRequired = false,
    this.mobileHandoffSupported = false,
    this.providerDisplayName,
    this.methodDescription,
    this.attributesCheckedDescription,
    this.selfieOrLivenessDescription,
    this.dataHandlingDescription,
    this.retentionAndDeletionDescription,
    this.declineOrFailureDescription,
    this.manualReviewDescription,
    this.consentVersion,
  });

  const EligibilityConfiguration.previewUnavailable()
    : providerConfigured = false,
      policyApproved = false,
      biometricProcessingSupported = false,
      biometricProcessingRequired = false,
      mobileHandoffSupported = false,
      providerDisplayName = null,
      methodDescription = null,
      attributesCheckedDescription = null,
      selfieOrLivenessDescription = null,
      dataHandlingDescription = null,
      retentionAndDeletionDescription = null,
      declineOrFailureDescription = null,
      manualReviewDescription = null,
      consentVersion = null;

  final bool providerConfigured;
  final bool policyApproved;

  /// Provider disclosures are still required if a supported method needs them.
  final bool biometricProcessingSupported;
  final bool biometricProcessingRequired;

  /// False until this client can safely launch the provider handoff and handle return.
  final bool mobileHandoffSupported;

  final String? providerDisplayName;
  final String? methodDescription;
  final String? attributesCheckedDescription;
  final String? selfieOrLivenessDescription;
  final String? dataHandlingDescription;
  final String? retentionAndDeletionDescription;
  final String? declineOrFailureDescription;
  final String? manualReviewDescription;

  /// A version supplied by approved configuration, not a client-side guess.
  final String? consentVersion;

  bool get hasApprovedConfiguration {
    final requiredDisclosures = <String?>[
      providerDisplayName,
      methodDescription,
      attributesCheckedDescription,
      selfieOrLivenessDescription,
      dataHandlingDescription,
      retentionAndDeletionDescription,
      declineOrFailureDescription,
      manualReviewDescription,
      consentVersion,
    ];
    return providerConfigured &&
        policyApproved &&
        (!biometricProcessingRequired || biometricProcessingSupported) &&
        requiredDisclosures.every(
          (value) => value != null && value.trim().isNotEmpty,
        );
  }

  /// Do not start a provider session until a secure app-to-provider handoff
  /// and safe return/status-retrieval flow are implemented.
  bool get canStartVerification =>
      hasApprovedConfiguration && mobileHandoffSupported;
}

/// A future trusted service associates this record with an authenticated
/// account. The current demo never persists this record.
class EligibilityConsentRecord {
  const EligibilityConsentRecord({
    required this.consentVersion,
    required this.acceptedAt,
    this.biometricProcessingConsented = false,
  });

  final String consentVersion;
  final DateTime acceptedAt;
  final bool biometricProcessingConsented;
}

class EligibilityStatusResult {
  const EligibilityStatusResult({
    required this.status,
    required this.message,
    required this.isDemo,
  });

  final EligibilityStatus status;
  final String message;

  /// True means this is a preview state and must never grant access.
  final bool isDemo;
}
