import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/features/auth/auth_service.dart';
import 'package:women_safety_app/features/auth/sakhi_consent_screen.dart';
import 'package:women_safety_app/features/auth/widgets/auth_widgets.dart';
import 'package:women_safety_app/features/eligibility/eligibility_consent_screen.dart';
import 'package:women_safety_app/features/eligibility/eligibility_information_screen.dart';
import 'package:women_safety_app/features/eligibility/eligibility_intro_screen.dart';
import 'package:women_safety_app/features/eligibility/eligibility_status_screen.dart';
import 'package:women_safety_app/features/eligibility/eligibility_verification_models.dart';
import 'package:women_safety_app/features/eligibility/eligibility_verification_service.dart';

void main() {
  group('eligibility verification preview', () {
    testWidgets(
      'introduction explains separate verification and preview limits',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: EligibilityIntroScreen(
              service: DemoEligibilityVerificationService(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Help us keep Sakhi a trusted space'), findsOneWidget);
        expect(
          find.textContaining('does not verify identity or eligibility'),
          findsOneWidget,
        );
        expect(find.textContaining('never infer gender'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'information screen discloses unknown provider and data policy',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: EligibilityInformationScreen(
              service: DemoEligibilityVerificationService(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Verification information'), findsOneWidget);
        expect(
          find.text('No authorised provider is configured.'),
          findsOneWidget,
        );
        expect(find.text('Retention and deletion'), findsOneWidget);
        expect(find.textContaining('Not configured or approved'), findsWidgets);
        expect(
          find.textContaining('does not request government identity documents'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'consent starts unchecked and demo preview never starts session',
      (tester) async {
        final service = _FakeEligibilityService(
          configuration: const EligibilityConfiguration.previewUnavailable(),
          result: const EligibilityStatusResult(
            status: EligibilityStatus.providerUnavailable,
            message: 'No provider is configured.',
            isDemo: true,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: EligibilityConsentScreen(
              service: service,
              configuration:
                  const EligibilityConfiguration.previewUnavailable(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final consentFinder = find.byKey(
          const Key('eligibility-consent-checkbox'),
        );
        final startFinder = find.byKey(
          const Key('eligibility-start-verification-button'),
        );
        final previewFinder = find.byKey(
          const Key('eligibility-preview-status-button'),
        );

        expect(tester.widget<CheckboxListTile>(consentFinder).value, isFalse);
        expect(
          tester.widget<SakhiAuthSubmitButton>(startFinder).onPressed,
          isNull,
        );
        expect(service.startCalls, 0);

        await tester.ensureVisible(consentFinder);
        await tester.tap(consentFinder);
        await tester.pumpAndSettle();
        await tester.ensureVisible(previewFinder);
        expect(
          tester.widget<OutlinedButton>(previewFinder).onPressed,
          isNotNull,
        );
        await tester.tap(previewFinder);
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'DEMO RESULT — no real identity verification occurred.',
          ),
          findsOneWidget,
        );
        expect(find.text('Verification is not available yet'), findsOneWidget);
        expect(service.statusCalls, 1);
        expect(service.startCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('configured service can start only after explicit consent', (
      tester,
    ) async {
      final service = _FakeEligibilityService(
        configuration: _approvedTestConfiguration,
        result: const EligibilityStatusResult(
          status: EligibilityStatus.inProgress,
          message: 'Test service reports an in-progress state.',
          isDemo: false,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: EligibilityConsentScreen(
            service: service,
            configuration: _approvedTestConfiguration,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final consentFinder = find.byKey(
        const Key('eligibility-consent-checkbox'),
      );
      final startFinder = find.byKey(
        const Key('eligibility-start-verification-button'),
      );

      expect(tester.widget<CheckboxListTile>(consentFinder).value, isFalse);
      await tester.ensureVisible(startFinder);
      expect(
        tester.widget<SakhiAuthSubmitButton>(startFinder).onPressed,
        isNull,
      );
      expect(service.startCalls, 0);

      await tester.ensureVisible(consentFinder);
      await tester.tap(consentFinder);
      await tester.pumpAndSettle();
      await tester.ensureVisible(startFinder);
      await tester.tap(startFinder);
      await tester.pumpAndSettle();

      expect(service.startCalls, 1);
      expect(service.lastConsent?.consentVersion, 'test-approved-v1');
      expect(service.lastConsent?.acceptedAt, isNotNull);
      expect(find.text('Verification in progress'), findsOneWidget);
      expect(find.textContaining('DEMO RESULT'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'required biometric consent is separate from general eligibility consent',
      (tester) async {
        const configuration = EligibilityConfiguration(
          providerConfigured: true,
          policyApproved: true,
          biometricProcessingSupported: true,
          biometricProcessingRequired: true,
          mobileHandoffSupported: true,
          providerDisplayName: 'Test-only fake provider',
          methodDescription: 'Test-only fake verification method.',
          attributesCheckedDescription: 'Test-only attributes description.',
          selfieOrLivenessDescription:
              'Biometric processing is required in this test.',
          dataHandlingDescription: 'No data leaves this fake test service.',
          retentionAndDeletionDescription: 'Not applicable to this fake test.',
          declineOrFailureDescription:
              'This test does not create a real request.',
          manualReviewDescription:
              'No manual review is implemented in this test.',
          consentVersion: 'test-approved-v1',
        );
        final service = _FakeEligibilityService(
          configuration: configuration,
          result: const EligibilityStatusResult(
            status: EligibilityStatus.inProgress,
            message: 'Test service reports an in-progress state.',
            isDemo: false,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: EligibilityConsentScreen(
              service: service,
              configuration: configuration,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final generalConsent = find.byKey(
          const Key('eligibility-consent-checkbox'),
        );
        final biometricConsent = find.byKey(
          const Key('eligibility-biometric-consent-checkbox'),
        );
        final start = find.byKey(
          const Key('eligibility-start-verification-button'),
        );

        expect(biometricConsent, findsOneWidget);
        await tester.ensureVisible(generalConsent);
        await tester.tap(generalConsent);
        await tester.pumpAndSettle();
        expect(tester.widget<SakhiAuthSubmitButton>(start).onPressed, isNull);

        await tester.ensureVisible(biometricConsent);
        await tester.tap(biometricConsent);
        await tester.pumpAndSettle();
        expect(
          tester.widget<SakhiAuthSubmitButton>(start).onPressed,
          isNotNull,
        );

        await tester.ensureVisible(start);
        await tester.tap(start);
        await tester.pumpAndSettle();

        expect(service.startCalls, 1);
        expect(service.lastConsent?.biometricProcessingConsented, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'provider-unavailable entry is reachable from registration consent',
      (tester) async {
        final profile = MemberProfileDraft(
          countryCode: '+91',
          phoneNumber: '9876543210',
          displayName: 'Asha Rao',
          dateOfBirth: DateTime(1995, 5, 5),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: SakhiConsentScreen(
              authService: const DemoAuthService(),
              profile: profile,
              minimumAgeYears: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final entry = find.byKey(const Key('eligibility-preview-entry-button'));
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pumpAndSettle();

        expect(find.text('Help us keep Sakhi a trusted space'), findsOneWidget);
        expect(
          find.textContaining('no approved verification provider'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('technical failure is distinct from rejection', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EligibilityStatusScreen(
            result: EligibilityStatusResult(
              status: EligibilityStatus.verificationFailed,
              message: 'Provider timeout.',
              isDemo: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to verify right now'), findsOneWidget);
      expect(
        find.textContaining('does not establish ineligibility'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'DEMO RESULT — no real identity verification occurred.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('all seven canonical backend statuses have clear labels', (
      tester,
    ) async {
      const labels = <EligibilityStatus, String>{
        EligibilityStatus.notVerified: 'Not Verified',
        EligibilityStatus.inProgress: 'Verification In Progress',
        EligibilityStatus.pendingManualReview: 'Pending Manual Review',
        EligibilityStatus.verified: 'Verified',
        EligibilityStatus.verificationFailed: 'Verification Failed',
        EligibilityStatus.temporarilyRestricted: 'Temporarily Restricted',
        EligibilityStatus.reverificationRequired: 'Reverification Required',
      };

      for (final entry in labels.entries) {
        await tester.pumpWidget(
          MaterialApp(
            home: EligibilityStatusScreen(
              result: EligibilityStatusResult(
                status: entry.key,
                message: 'Synthetic status fixture.',
                isDemo: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(entry.value), findsOneWidget);
        expect(
          find.textContaining(
            'DEMO RESULT — no real identity verification occurred.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets(
      'information, consent and status screens fit a narrow phone viewport',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: EligibilityInformationScreen(
              service: DemoEligibilityVerificationService(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('eligibility-information-continue-button')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          const MaterialApp(
            home: EligibilityConsentScreen(
              service: DemoEligibilityVerificationService(),
              configuration: EligibilityConfiguration.previewUnavailable(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('eligibility-consent-checkbox')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          const MaterialApp(
            home: EligibilityStatusScreen(
              result: EligibilityStatusResult(
                status: EligibilityStatus.temporarilyRestricted,
                message: 'Synthetic status fixture.',
                isDemo: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Temporarily Restricted'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('eligibility introduction fits a narrow phone viewport', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: EligibilityIntroScreen(
            service: DemoEligibilityVerificationService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('eligibility-review-details-button')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

const _approvedTestConfiguration = EligibilityConfiguration(
  providerConfigured: true,
  policyApproved: true,
  mobileHandoffSupported: true,
  providerDisplayName: 'Test-only fake provider',
  methodDescription: 'Test-only fake verification method.',
  attributesCheckedDescription: 'Test-only attributes description.',
  selfieOrLivenessDescription: 'No biometric sample in this test.',
  dataHandlingDescription: 'No data leaves this fake test service.',
  retentionAndDeletionDescription: 'Not applicable to this fake test.',
  declineOrFailureDescription: 'This test does not create a real request.',
  manualReviewDescription: 'No manual review is implemented in this test.',
  consentVersion: 'test-approved-v1',
);

class _FakeEligibilityService implements EligibilityVerificationService {
  _FakeEligibilityService({required this.configuration, required this.result});

  @override
  bool get isDevelopmentBackend => false;

  final EligibilityConfiguration configuration;
  final EligibilityStatusResult result;
  int startCalls = 0;
  int statusCalls = 0;
  EligibilityConsentRecord? lastConsent;

  @override
  Future<EligibilityConfiguration> loadConfiguration() async => configuration;

  @override
  Future<EligibilityStatusResult> readStatus() async {
    statusCalls++;
    return result;
  }

  @override
  Future<EligibilityStatusResult> startVerification({
    required EligibilityConsentRecord consent,
  }) async {
    startCalls++;
    lastConsent = consent;
    return result;
  }

  @override
  Future<EligibilityStatusResult> submitManualReview({
    required EligibilityConsentRecord consent,
  }) async {
    startCalls++;
    lastConsent = consent;
    return result;
  }
}
