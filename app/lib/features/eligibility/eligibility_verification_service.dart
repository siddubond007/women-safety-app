import 'eligibility_verification_models.dart';

/// Contract for the trusted Sakhi eligibility backend and safe preview.
///
/// Implementations retrieve authoritative status from the backend, never trust
/// a client-side redirect as proof, and fail closed when configuration is missing.
abstract interface class EligibilityVerificationService {
  bool get isDevelopmentBackend;

  Future<EligibilityConfiguration> loadConfiguration();

  Future<EligibilityStatusResult> readStatus();

  /// Starts a configured hosted-provider flow. This remains separately gated
  /// by mobile handoff support.
  Future<EligibilityStatusResult> startVerification({
    required EligibilityConsentRecord consent,
  });

  /// Creates an explicit manual-review submission, when server policy permits it.
  /// This stores submission/consent metadata only; it does not upload evidence.
  Future<EligibilityStatusResult> submitManualReview({
    required EligibilityConsentRecord consent,
  });
}

/// Safe local preview. It never creates a transaction, contacts a provider,
/// persists consent, collects identity evidence, or grants access.
class DemoEligibilityVerificationService
    implements EligibilityVerificationService {
  const DemoEligibilityVerificationService();

  @override
  bool get isDevelopmentBackend => false;

  @override
  Future<EligibilityConfiguration> loadConfiguration() async =>
      const EligibilityConfiguration.previewUnavailable();

  @override
  Future<EligibilityStatusResult> readStatus() async =>
      const EligibilityStatusResult(
        status: EligibilityStatus.providerUnavailable,
        message: 'No approved eligibility-verification provider or manual-review process is configured. No request was created.',
        isDemo: true,
      );

  @override
  Future<EligibilityStatusResult> startVerification({
    required EligibilityConsentRecord consent,
  }) async => const EligibilityStatusResult(
    status: EligibilityStatus.providerUnavailable,
    message: 'Verification was not started. The provider and approved policy are not configured; no identity data was collected.',
    isDemo: true,
  );

  @override
  Future<EligibilityStatusResult> submitManualReview({
    required EligibilityConsentRecord consent,
  }) async => const EligibilityStatusResult(
    status: EligibilityStatus.providerUnavailable,
    message: 'No manual-review request was sent. This is a preview; no request or consent was persisted.',
    isDemo: true,
  );
}
