import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/features/eligibility/eligibility_consent_screen.dart';
import 'package:women_safety_app/features/eligibility/eligibility_verification_models.dart';
import 'package:women_safety_app/features/eligibility/eligibility_verification_service.dart';

const _manualReviewConfiguration = EligibilityConfiguration(
  providerConfigured: false,
  policyApproved: false,
  manualReviewEnabled: true,
  manualReviewConsentVersion: 'manual-test-v1',
  manualReviewConsentText:
      'I consent to submit my manual eligibility-review request.',
  manualReviewDescription:
      'A reviewer follows the separately approved external evidence procedure.',
  manualReviewDataHandlingDescription:
      'This app sends request and consent metadata only.',
  manualReviewRetentionDescription:
      'The configured policy explains metadata retention and deletion.',
);

class _ManualReviewTestService implements EligibilityVerificationService {
  int submissionCalls = 0;
  int providerStartCalls = 0;
  EligibilityConsentRecord? submittedConsent;

  @override
  bool get isDevelopmentBackend => true;

  @override
  Future<EligibilityConfiguration> loadConfiguration() async =>
      _manualReviewConfiguration;

  @override
  Future<EligibilityStatusResult> readStatus() async =>
      const EligibilityStatusResult(
        status: EligibilityStatus.notVerified,
        message: 'Synthetic test status.',
        isDemo: true,
      );

  @override
  Future<EligibilityStatusResult> startVerification({
    required EligibilityConsentRecord consent,
  }) async {
    providerStartCalls++;
    return const EligibilityStatusResult(
      status: EligibilityStatus.providerUnavailable,
      message: 'Provider handoff is unavailable.',
      isDemo: true,
    );
  }

  @override
  Future<EligibilityStatusResult> submitManualReview({
    required EligibilityConsentRecord consent,
  }) async {
    submissionCalls++;
    submittedConsent = consent;
    return const EligibilityStatusResult(
      status: EligibilityStatus.pendingManualReview,
      message: 'Synthetic manual-review request was recorded.',
      isDemo: true,
    );
  }
}

void main() {
  testWidgets(
    'submits metadata-only manual review and displays the backend pending status',
    (tester) async {
      final service = _ManualReviewTestService();
      await tester.pumpWidget(
        MaterialApp(
          home: EligibilityConsentScreen(
            service: service,
            configuration: _manualReviewConfiguration,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('This request sends your consent and a manual-review request'),
        findsOneWidget,
      );
      expect(
        find.text(_manualReviewConfiguration.manualReviewConsentText!),
        findsOneWidget,
      );

      final consent = find.byKey(
        const Key('eligibility-consent-checkbox'),
      );
      await tester.ensureVisible(consent);
      await tester.tap(consent);
      await tester.pumpAndSettle();

      final submit = find.byKey(
        const Key('eligibility-submit-manual-review-button'),
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(service.submissionCalls, 1);
      expect(service.providerStartCalls, 0);
      expect(service.submittedConsent?.consentVersion, 'manual-test-v1');
      expect(find.text('Pending Manual Review'), findsOneWidget);
      expect(
        find.text('Synthetic manual-review request was recorded.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
