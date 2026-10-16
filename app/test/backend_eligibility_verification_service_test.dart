import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/features/auth/backend_api_client.dart';
import 'package:women_safety_app/features/eligibility/backend_eligibility_verification_service.dart';
import 'package:women_safety_app/features/eligibility/eligibility_verification_models.dart';

class _FakeEligibilityApiClient extends BackendApiClient {
  _FakeEligibilityApiClient({
    Map<String, Map<String, dynamic>> getResponses =
        const <String, Map<String, dynamic>>{},
    this.postResponse = const <String, dynamic>{},
    this.getError,
    this.postError,
  }) : getResponses = getResponses,
       super(baseUrl: 'http://127.0.0.1:3001/api/v1');

  final Map<String, Map<String, dynamic>> getResponses;
  Map<String, dynamic> postResponse;
  BackendApiException? getError;
  BackendApiException? postError;

  final getRequests = <({String path, bool authenticated})>[];
  final postRequests =
      <({String path, bool authenticated, Map<String, Object?> body})>[];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = false,
  }) async {
    getRequests.add((path: path, authenticated: authenticated));
    if (getError != null) throw getError!;
    return getResponses[path] ?? const <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?> body = const <String, Object?>{},
    bool authenticated = false,
  }) async {
    postRequests.add((
      path: path,
      authenticated: authenticated,
      body: Map<String, Object?>.from(body),
    ));
    if (postError != null) throw postError!;
    return postResponse;
  }
}

void main() {
  group('backend eligibility configuration', () {
    test('maps provider readiness and remains fail-closed without approval', () async {
      final api = _FakeEligibilityApiClient(
        getResponses: {
          'eligibility/configuration': <String, dynamic>{
            'providerConfigured': false,
            'policyApproved': false,
            'biometricProcessingSupported': false,
            'biometricProcessingRequired': false,
            'providerDisplayName': null,
            'methodDescription': null,
            'attributesCheckedDescription': null,
            'selfieOrLivenessDescription': null,
            'dataHandlingDescription': null,
            'retentionAndDeletionDescription': null,
            'declineOrFailureDescription': null,
            'manualReviewDescription': 'Manual review is not enabled.',
            'consentVersion': null,
            'canStartVerification': false,
            'mode': 'development_preview',
          },
        },
      );
      final service = BackendEligibilityVerificationService(apiClient: api);

      final configuration = await service.loadConfiguration();

      expect(api.getRequests, [
        (path: 'eligibility/configuration', authenticated: false),
      ]);
      expect(configuration.providerConfigured, isFalse);
      expect(configuration.policyApproved, isFalse);
      expect(configuration.biometricProcessingRequired, isFalse);
      expect(configuration.hasApprovedConfiguration, isFalse);
      expect(configuration.canStartVerification, isFalse);
    });
  });

  group('backend eligibility status', () {
    test('requests status with the stored authenticated session', () async {
      final api = _FakeEligibilityApiClient(
        getResponses: {
          'eligibility/status': <String, dynamic>{
            'status': 'providerUnavailable',
            'eligibilityStatus': 'notVerified',
            'providerConfigured': false,
            'policyApproved': false,
            'canStartVerification': false,
            'message':
                'No approved eligibility provider or policy is configured. No verification session exists.',
            'isDemo': true,
          },
        },
      );
      final service = BackendEligibilityVerificationService(apiClient: api);

      final result = await service.readStatus();

      expect(api.getRequests, [
        (path: 'eligibility/status', authenticated: true),
      ]);
      expect(result.status, EligibilityStatus.providerUnavailable);
      expect(result.isDemo, isTrue);
      expect(result.message, contains('No approved eligibility provider'));
    });

    test('maps the canonical persisted status separately from provider readiness', () async {
      final api = _FakeEligibilityApiClient(
        getResponses: {
          'eligibility/status': <String, dynamic>{
            'status': 'providerConfigured',
            'eligibilityStatus': 'verified',
            'providerConfigured': true,
            'policyApproved': true,
            'canStartVerification': true,
            'message': 'Status returned by the trusted backend.',
            'isDemo': false,
          },
        },
      );
      final service = BackendEligibilityVerificationService(apiClient: api);

      final result = await service.readStatus();

      expect(result.status, EligibilityStatus.verified);
      expect(result.isDemo, isFalse);
    });
  });

  group('backend eligibility start contract', () {
    test('sends explicit consent fields and omits client timestamp fields', () async {
      final api = _FakeEligibilityApiClient(
        postError: const BackendApiException(
          statusCode: 409,
          code: 'eligibility_provider_unavailable',
          message: 'No verification session was created.',
        ),
      );
      final service = BackendEligibilityVerificationService(apiClient: api);

      final result = await service.startVerification(
        consent: EligibilityConsentRecord(
          consentVersion: 'approved-notice-v1',
          acceptedAt: DateTime.utc(2026, 10, 16),
          biometricProcessingConsented: true,
        ),
      );

      expect(api.postRequests, hasLength(1));
      expect(api.postRequests.single.path, 'eligibility/start');
      expect(api.postRequests.single.authenticated, isTrue);
      expect(api.postRequests.single.body, {
        'consentAccepted': true,
        'consentVersion': 'approved-notice-v1',
        'biometricProcessingConsented': true,
      });
      expect(api.postRequests.single.body.containsKey('acceptedAt'), isFalse);
      expect(result.status, EligibilityStatus.providerUnavailable);
      expect(result.isDemo, isTrue);
    });

    test('maps a trusted in-progress response without labelling it a demo', () async {
      final api = _FakeEligibilityApiClient(
        postResponse: const <String, dynamic>{
          'status': 'verificationInProgress',
          'eligibilityStatus': 'verificationInProgress',
          'message': 'Continue with the approved provider.',
          'isDemo': false,
        },
      );
      final service = BackendEligibilityVerificationService(apiClient: api);

      final result = await service.startVerification(
        consent: EligibilityConsentRecord(
          consentVersion: 'approved-notice-v1',
          acceptedAt: DateTime.utc(2026, 10, 16),
        ),
      );

      expect(result.status, EligibilityStatus.inProgress);
      expect(result.isDemo, isFalse);
    });
  });
}
