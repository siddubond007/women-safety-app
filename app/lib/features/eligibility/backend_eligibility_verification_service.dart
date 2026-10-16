import '../auth/backend_api_client.dart';
import 'eligibility_verification_models.dart';
import 'eligibility_verification_service.dart';

/// Connects the eligibility preview to the backend's fail-closed contract.
/// This currently reads an explicit unavailable status; it never simulates a
/// verified outcome or sends identity evidence.
class BackendEligibilityVerificationService
    implements EligibilityVerificationService {
  const BackendEligibilityVerificationService({required this.apiClient});

  final BackendApiClient apiClient;

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
        // Keep session start disabled until provider redirect and app-return
        // handling are implemented and tested.
        mobileHandoffSupported: false,
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
        dataHandlingDescription: _optionalString(
          data,
          'dataHandlingDescription',
        ),
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
      final providerUnavailable = data['canStartVerification'] != true;
      return EligibilityStatusResult(
        // The status field describes provider readiness; eligibilityStatus is
        // the canonical persisted account decision. Keep them distinct.
        status: providerUnavailable
            ? EligibilityStatus.providerUnavailable
            : _status(data['eligibilityStatus']),
        message: message is String
            ? message
            : 'No approved eligibility-verification provider is configured.',
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
    try {
      final data = await apiClient.post(
        'eligibility/start',
        authenticated: true,
        body: {
          'consentAccepted': true,
          'consentVersion': consent.consentVersion,
          'biometricProcessingConsented':
              consent.biometricProcessingConsented,
        },
      );
      return EligibilityStatusResult(
        status: _status(data['eligibilityStatus'] ?? data['status']),
        message: data['message'] is String
            ? data['message'] as String
            : 'The backend did not confirm an eligibility session.',
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
}
