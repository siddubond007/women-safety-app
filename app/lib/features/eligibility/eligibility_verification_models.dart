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
  rejected,
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

/// Provider and manual-review configuration returned by the trusted backend.
/// Provider handoff and manual review are separate workflows with separate gates.
class EligibilityConfiguration {
  const EligibilityConfiguration({
    required this.providerConfigured,
    required this.policyApproved,
    this.biometricProcessingSupported = false,
    this.biometricProcessingRequired = false,
    this.mobileHandoffSupported = false,
    this.localSimulatorEnabled = false,
    this.stagingDemoEnabled = false,
    this.providerDisplayName,
    this.methodDescription,
    this.attributesCheckedDescription,
    this.selfieOrLivenessDescription,
    this.dataHandlingDescription,
    this.retentionAndDeletionDescription,
    this.declineOrFailureDescription,
    this.manualReviewDescription,
    this.consentVersion,
    this.manualReviewEnabled = false,
    this.manualReviewConsentVersion,
    this.manualReviewConsentText,
    this.manualReviewDataHandlingDescription,
    this.manualReviewRetentionDescription,
  });

  const EligibilityConfiguration.previewUnavailable()
    : providerConfigured = false,
      policyApproved = false,
      biometricProcessingSupported = false,
      biometricProcessingRequired = false,
      mobileHandoffSupported = false,
      localSimulatorEnabled = false,
      stagingDemoEnabled = false,
      providerDisplayName = null,
      methodDescription = null,
      attributesCheckedDescription = null,
      selfieOrLivenessDescription = null,
      dataHandlingDescription = null,
      retentionAndDeletionDescription = null,
      declineOrFailureDescription = null,
      manualReviewDescription = null,
      consentVersion = null,
      manualReviewEnabled = false,
      manualReviewConsentVersion = null,
      manualReviewConsentText = null,
      manualReviewDataHandlingDescription = null,
      manualReviewRetentionDescription = null;

  final bool providerConfigured;
  final bool policyApproved;
  final bool biometricProcessingSupported;
  final bool biometricProcessingRequired;

  /// False until this client can safely launch the hosted provider and handle return.
  final bool mobileHandoffSupported;

  /// Loopback-only simulator available for local development.
  final bool localSimulatorEnabled;

  /// Synthetic session flow enabled only on the explicitly configured staging API.
  final bool stagingDemoEnabled;

  final String? providerDisplayName;
  final String? methodDescription;
  final String? attributesCheckedDescription;
  final String? selfieOrLivenessDescription;
  final String? dataHandlingDescription;
  final String? retentionAndDeletionDescription;
  final String? declineOrFailureDescription;
  final String? manualReviewDescription;

  /// Version of the approved provider consent, not a client-side guess.
  final String? consentVersion;

  /// True only when the backend enables the separate manual-review pathway.
  final bool manualReviewEnabled;
  final String? manualReviewConsentVersion;
  final String? manualReviewConsentText;
  final String? manualReviewDataHandlingDescription;
  final String? manualReviewRetentionDescription;

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

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
        requiredDisclosures.every(_hasText);
  }

  /// A server-enabled, separately disclosed manual review can be requested
  /// without enabling a hosted identity-provider handoff.
  bool get canRequestManualReview =>
      manualReviewEnabled &&
      _hasText(manualReviewConsentVersion) &&
      _hasText(manualReviewConsentText) &&
      _hasText(manualReviewDescription) &&
      _hasText(manualReviewDataHandlingDescription) &&
      _hasText(manualReviewRetentionDescription);

  bool get canStartVerification =>
      hasApprovedConfiguration && mobileHandoffSupported;
}

/// Explicit consent captured by the mobile UI. The server timestamps receipt.
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

  /// True means this is a dev/test or preview result and must never grant access.
  final bool isDemo;
}
