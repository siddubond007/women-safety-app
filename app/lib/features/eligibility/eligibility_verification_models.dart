/// Provider-neutral models for Sakhi's eligibility-verification boundary.
///
/// These types describe UI/service states only. They do not prove identity,
/// gender, age, or community eligibility.
enum EligibilityStatus {
  notStarted,
  consentRequired,
  inProgress,
  pendingManualReview,
  verified,
  verificationFailed,
  rejected,
  cancelled,
  reverificationRequired,
  providerUnavailable,
  consentNotGiven,
}

/// Configuration is usable only when the provider and its legal/policy setup
/// have both been explicitly approved and supplied by a trusted service.
class EligibilityConfiguration {
  const EligibilityConfiguration({
    required this.providerConfigured,
    required this.policyApproved,
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

  bool get canStartVerification {
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
        requiredDisclosures.every(
          (value) => value != null && value.trim().isNotEmpty,
        );
  }
}

/// A future trusted service associates this record with an authenticated
/// account. The current demo never persists this record.
class EligibilityConsentRecord {
  const EligibilityConsentRecord({
    required this.consentVersion,
    required this.acceptedAt,
  });

  final String consentVersion;
  final DateTime acceptedAt;
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
