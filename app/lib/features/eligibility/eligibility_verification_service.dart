import 'eligibility_verification_models.dart';

/// Future integration boundary for the trusted Sakhi backend.
///
/// Implementations must retrieve authoritative status from the backend,
/// never trust a client-side redirect as proof, and fail closed when
/// configuration is missing. The demo never creates provider sessions.
abstract interface class EligibilityVerificationService {
  Future<EligibilityConfiguration> loadConfiguration();

  Future<EligibilityStatusResult> readStatus();

  Future<EligibilityStatusResult> startVerification({
    required EligibilityConsentRecord consent,
  });
}

/// Safe local preview. It does not persist consent, create a transaction,
/// contact an identity provider, collect identity evidence, or grant access.
class DemoEligibilityVerificationService
    implements EligibilityVerificationService {
  const DemoEligibilityVerificationService();

  @override
  Future<EligibilityConfiguration> loadConfiguration() async =>
      const EligibilityConfiguration.previewUnavailable();

  @override
  Future<EligibilityStatusResult> readStatus() async =>
      const EligibilityStatusResult(
        status: EligibilityStatus.providerUnavailable,
        message: 'No approved eligibility-verification provider or policy is configured. No verification session exists.',
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
}
