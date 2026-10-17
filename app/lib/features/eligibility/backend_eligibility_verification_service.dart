import '../auth/backend_api_client.dart';
import 'eligibility_verification_models.dart';
import 'eligibility_verification_service.dart';

/// Maps the authenticated mobile screens to the backend eligibility API.
/// Hosted-provider handoff and manual review have independent gates.
class BackendEligibilityVerificationService
    implements EligibilityVerificationService {
  const BackendEligibilityVerificationService({
    required this.apiClient,
    this.mobileHandoffSupported = false,
  });

  final BackendApiClient apiClient;

  /// Must remain false until the hosted-provider handoff/return flow is implemented.
  final bool mobileHandoffSupported;

  @override
  bool get isDevelopmentBackend => true;

  String? _optionalString(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  @override
  Future<EligibilityConfiguration> loadConfiguration() async {
    try {
      final data = await apiClient.get('eligibility/configuration');
      return EligibilityConfiguration(
        providerConfigured: data['providerConfigured'] == true,
        policyApproved: data['policyApproved'] == true,
        biometricProcessingSupported:
            data['biometricProcessingSupported'] == true,
        biometricProcessingRequired:
            data['biometricProcessingRequired'] == true,
        mobileHandoffSupported: mobileHandoffSupported,
        providerDisplayName: _optionalString(data, 'providerDisplayName'),
        methodDescription: _optionalString(data, 'methodDescription'),
        attributesCheckedDescription: _optionalString(
          data,
          'attributesCheckedDescription',
        ),
        selfieOrLivenessDescription: _optionalString(
          data,
          'selfieOrLivenessDescription',
        ),
        dataHandlingDescription: _optionalString(data, 'dataHandlingDescription'),
        retentionAndDeletionDescription: _optionalString(
          data,
          'retentionAndDeletionDescription',
        ),
        declineOrFailureDescription: _optionalString(
          data,
          'declineOrFailureDescription',
        ),
        manualReviewDescription: _optionalString(
          data,
          'manualReviewDescription',
        ),
        consentVersion: _optionalString(data, 'consentVersion'),
        manualReviewEnabled: data['manualReviewEnabled'] == true,
        manualReviewConsentVersion: _optionalString(
          data,
          'manualReviewConsentVersion',
        ),
        manualReviewConsentText: _optionalString(
          data,
          'manualReviewConsentText',
        ),
        manualReviewDataHandlingDescription: _optionalString(
          data,
          'manualReviewDataHandlingDescription',
        ),
        manualReviewRetentionDescription: _optionalString(
          data,
          'manualReviewRetentionDescription',
        ),
      );
    } on BackendApiException catch (error) {
      throw Exception(error.message);
    }
  }

  EligibilityStatus _status(Object? value) {
    switch (value) {
      case 'notStarted':
      case 'not_started':
        return EligibilityStatus.notStarted;
      case 'notVerified':
      case 'NOT_VERIFIED':
      case 'UNVERIFIED':
        return EligibilityStatus.notVerified;
      case 'consentRequired':
      case 'consent_required':
        return EligibilityStatus.consentRequired;
      case 'inProgress':
      case 'in_progress':
      case 'verificationInProgress':
      case 'VERIFICATION_IN_PROGRESS':
        return EligibilityStatus.inProgress;
      case 'pendingManualReview':
      case 'pending_manual_review':
      case 'PENDING_MANUAL_REVIEW':
        return EligibilityStatus.pendingManualReview;
      case 'verified':
      case 'VERIFIED':
        return EligibilityStatus.verified;
      case 'rejected':
      case 'REJECTED':
        return EligibilityStatus.rejected;
      case 'verificationFailed':
      case 'verification_failed':
      case 'VERIFICATION_FAILED':
        return EligibilityStatus.verificationFailed;
      case 'temporarilyRestricted':
      case 'TEMPORARILY_RESTRICTED':
        return EligibilityStatus.temporarilyRestricted;
      case 'reverificationRequired':
      case 'reverification_required':
      case 'REVERIFICATION_REQUIRED':
        return EligibilityStatus.reverificationRequired;
      case 'cancelled':
        return EligibilityStatus.cancelled;
      case 'consentNotGiven':
      case 'consent_not_given':
        return EligibilityStatus.consentNotGiven;
      case 'providerUnavailable':
      case 'provider_unavailable':
      default:
        return EligibilityStatus.providerUnavailable;
    }
  }

  @override
  Future<EligibilityStatusResult> readStatus() async {
    try {
      final data = await apiClient.get(
        'eligibility/status',
        authenticated: true,
      );
      final message = data['message'];
      final rawEligibilityStatus = data['eligibilityStatus'];
      const canonicalStatuses = <String>{
        'notVerified',
        'NOT_VERIFIED',
        'UNVERIFIED',
        'inProgress',
        'in_progress',
        'verificationInProgress',
        'VERIFICATION_IN_PROGRESS',
        'pendingManualReview',
        'pending_manual_review',
        'PENDING_MANUAL_REVIEW',
        'verified',
        'VERIFIED',
        'rejected',
        'REJECTED',
        'verificationFailed',
        'verification_failed',
        'VERIFICATION_FAILED',
        'temporarilyRestricted',
        'TEMPORARILY_RESTRICTED',
        'reverificationRequired',
        'reverification_required',
        'REVERIFICATION_REQUIRED',
      };
      final hasCanonicalStatus = rawEligibilityStatus is String &&
          canonicalStatuses.contains(rawEligibilityStatus);
      return EligibilityStatusResult(
        // Provider readiness is not an eligibility decision. Keep the account's
        // persisted eligibilityStatus visible even when no provider can start.
        status: hasCanonicalStatus
            ? _status(rawEligibilityStatus)
            : _status(data['status']),
        message: message is String
            ? message
            : 'The backend did not return an eligibility status.',
        isDemo: data['isDemo'] == true,
      );
    } on BackendApiException catch (error) {
      if (error.statusCode == 409 || error.statusCode == 503) {
        return EligibilityStatusResult(
          status: EligibilityStatus.providerUnavailable,
          message: error.message,
          isDemo: true,
        );
      }
      rethrow;
    }
  }

  @override
  Future<EligibilityStatusResult> startVerification({
    required EligibilityConsentRecord consent,
  }) async {
    // The hosted provider stays disabled until safe provider handoff and return
    // handling are implemented and verified.
    if (!mobileHandoffSupported) {
      return const EligibilityStatusResult(
        status: EligibilityStatus.providerUnavailable,
        message: 'The secure provider handoff and return flow is not implemented in this mobile build. No verification session was created.',
        isDemo: true,
      );
    }

    try {
      final data = await apiClient.post(
        'eligibility/start',
        authenticated: true,
        body: {
          'consentAccepted': true,
          'consentVersion': consent.consentVersion,
          'biometricProcessingConsented': consent.biometricProcessingConsented,
        },
      );
      return EligibilityStatusResult(
        status: _status(data['eligibilityStatus'] ?? data['status']),
        message: data['message'] is String
            ? data['message'] as String
            : 'The backend did not confirm a verification session.',
        isDemo: data['isDemo'] == true,
      );
    } on BackendApiException catch (error) {
      if (error.statusCode == 409 ||
          error.code == 'eligibility_provider_unavailable') {
        return EligibilityStatusResult(
          status: EligibilityStatus.providerUnavailable,
          message: error.message,
          isDemo: true,
        );
      }
      rethrow;
    }
  }

  @override
  Future<EligibilityStatusResult> submitManualReview({
    required EligibilityConsentRecord consent,
  }) async {
    // Re-check the server-owned policy immediately before creating the request;
    // a client-side consent checkbox never enables the backend on its own.
    final configuration = await loadConfiguration();
    if (!configuration.canRequestManualReview ||
        configuration.manualReviewConsentVersion != consent.consentVersion) {
      return const EligibilityStatusResult(
        status: EligibilityStatus.providerUnavailable,
        message: 'Manual review is not currently enabled by the backend policy. No request was created.',
        isDemo: true,
      );
    }

    try {
      final data = await apiClient.post(
        'eligibility/start',
        authenticated: true,
        body: {
          'consentAccepted': true,
          'consentVersion': consent.consentVersion,
        },
      );
      return EligibilityStatusResult(
        status: _status(data['eligibilityStatus'] ?? data['status']),
        message: data['message'] is String
            ? data['message'] as String
            : 'The backend did not confirm the manual-review request.',
        isDemo: data['isDemo'] == true,
      );
    } on BackendApiException catch (error) {
      if (error.statusCode == 503 ||
          error.code == 'manual_review_not_configured') {
        return EligibilityStatusResult(
          status: EligibilityStatus.providerUnavailable,
          message: error.message,
          isDemo: true,
        );
      }
      if (error.statusCode == 409) {
        // An existing submission is not a failed eligibility decision. Ask the
        // backend for the canonical current state rather than masking it.
        return readStatus();
      }
      rethrow;
    }
  }
}
