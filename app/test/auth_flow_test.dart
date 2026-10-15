import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/features/auth/auth_policy.dart';
import 'package:women_safety_app/features/auth/auth_service.dart';
import 'package:women_safety_app/features/auth/sakhi_consent_screen.dart';
import 'package:women_safety_app/features/auth/sakhi_login_screen.dart';
import 'package:women_safety_app/features/auth/sakhi_otp_screen.dart';
import 'package:women_safety_app/features/auth/sakhi_profile_screen.dart';
import 'package:women_safety_app/features/auth/sakhi_registration_screen.dart';
import 'package:women_safety_app/features/auth/widgets/auth_widgets.dart';
import 'package:women_safety_app/main.dart';

void main() {
  group('mobile-first auth entry', () {
    testWidgets('registration starts with mobile number, not email/password', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SakhiRegistrationScreen(authService: DemoAuthService()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create your Sakhi account'), findsOneWidget);
      expect(find.byKey(const Key('sakhi-logo-lockup')), findsOneWidget);
      expect(find.byKey(const Key('auth-mobile-number-field')), findsOneWidget);
      expect(
        find.byKey(const Key('auth-country-code-dropdown')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('auth-send-otp-button')), findsOneWidget);
      expect(find.byKey(const Key('auth-demo-banner')), findsOneWidget);
      expect(find.byKey(const Key('auth-password-field')), findsNothing);
      expect(find.byKey(const Key('auth-email-field')), findsNothing);
      expect(find.text('Already have an account? Sign in'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('login is mobile-first and links to registration', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SakhiLoginScreen(authService: DemoAuthService()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byKey(const Key('auth-mobile-number-field')), findsOneWidget);
      expect(find.byKey(const Key('auth-send-otp-button')), findsOneWidget);
      expect(find.byKey(const Key('auth-password-field')), findsNothing);

      await tester.tap(find.byKey(const Key('auth-switch-method-button')));
      await tester.pumpAndSettle();
      expect(find.text('Create your Sakhi account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('registration links to existing-user login', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SakhiRegistrationScreen(authService: DemoAuthService()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('auth-switch-method-button')));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byKey(const Key('auth-mobile-number-field')), findsOneWidget);
    });

    testWidgets('validates empty and malformed mobile numbers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SakhiRegistrationScreen(authService: DemoAuthService()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('auth-send-otp-button')));
      await tester.pumpAndSettle();
      expect(find.text('Enter your mobile number.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('auth-mobile-number-field')),
        '12345',
      );
      await tester.tap(find.byKey(const Key('auth-send-otp-button')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a 10-digit mobile number.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unconfigured release service states that no SMS was sent', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SakhiLoginScreen(authService: UnconfiguredAuthService()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('auth-mobile-number-field')),
        '9876543210',
      );
      await tester.tap(find.byKey(const Key('auth-send-otp-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('No SMS was sent'), findsOneWidget);
      expect(find.byKey(const Key('auth-otp-code-field')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pending OTP request prevents duplicate submissions', (
      tester,
    ) async {
      final service = _FakeAuthService();
      service.requestGate = Completer<AuthOtpSession>();
      await tester.pumpWidget(
        MaterialApp(home: SakhiLoginScreen(authService: service)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('auth-mobile-number-field')),
        '9876543210',
      );
      await tester.tap(find.byKey(const Key('auth-send-otp-button')));
      await tester.pump();

      expect(service.requestCalls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      service.requestGate!.complete(_session());
      await tester.pumpAndSettle();
      expect(find.text('Verify your number'), findsOneWidget);
      expect(service.requestCalls, 1);
    });
  });

  group('OTP verification', () {
    testWidgets(
      'shows masked phone, six digit input and change-number action',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: SakhiOtpScreen(
              authService: const DemoAuthService(),
              session: _session(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Verify your number'), findsOneWidget);
        expect(find.text('+91 ••••••3210'), findsOneWidget);
        expect(find.byKey(const Key('auth-otp-code-field')), findsOneWidget);
        expect(find.byKey(const Key('auth-verify-otp-button')), findsOneWidget);
        expect(find.byKey(const Key('auth-resend-otp-button')), findsOneWidget);
        expect(
          find.byKey(const Key('auth-change-number-button')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Demo only: enter any six digits'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('requires all six OTP digits before verify', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SakhiOtpScreen(
            authService: const DemoAuthService(),
            session: _session(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('auth-verify-otp-button')));
      await tester.pumpAndSettle();
      expect(find.text('Enter all six digits.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('change number returns to the mobile entry screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SakhiLoginScreen(authService: const DemoAuthService()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-mobile-number-field')),
        '9876543210',
      );
      await tester.tap(find.byKey(const Key('auth-send-otp-button')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('auth-change-number-button')),
      );
      await tester.tap(find.byKey(const Key('auth-change-number-button')));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byKey(const Key('auth-mobile-number-field')), findsOneWidget);
      expect(find.byKey(const Key('auth-otp-code-field')), findsNothing);
    });

    testWidgets('invalid, expired and rate-limited responses are displayed', (
      tester,
    ) async {
      for (final entry in <(OtpVerificationStatus, String)>[
        (OtpVerificationStatus.invalid, 'Code is invalid for this test.'),
        (OtpVerificationStatus.expired, 'Code expired for this test.'),
        (
          OtpVerificationStatus.tooManyAttempts,
          'Try again later for this test.',
        ),
      ]) {
        final service = _FakeAuthService()
          ..verificationStatus = entry.$1
          ..verificationMessage = entry.$2;
        await tester.pumpWidget(
          MaterialApp(
            home: SakhiOtpScreen(authService: service, session: _session()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('auth-otp-code-field')),
          '123456',
        );
        await tester.tap(find.byKey(const Key('auth-verify-otp-button')));
        await tester.pumpAndSettle();
        expect(find.text(entry.$2), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('registration OTP demo moves to profile, not Home', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SakhiRegistrationScreen(authService: DemoAuthService()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-mobile-number-field')),
        '9876543210',
      );
      await tester.tap(find.byKey(const Key('auth-send-otp-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-otp-code-field')),
        '123456',
      );
      await tester.tap(find.byKey(const Key('auth-verify-otp-button')));
      await tester.pumpAndSettle();

      expect(find.text('Tell us about yourself'), findsOneWidget);
      expect(find.byKey(const Key('auth-profile-name-field')), findsOneWidget);
      expect(find.byKey(const Key('auth-profile-dob-picker')), findsOneWidget);
      expect(find.byKey(const Key('auth-profile-email-field')), findsOneWidget);
      expect(
        find.byKey(const Key('auth-profile-add-photo-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('auth-age-policy-provisional')),
        findsOneWidget,
      );
      expect(find.textContaining('minimum age 13'), findsOneWidget);
      expect(find.text('Welcome to Sakhi'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'a new number entered from login continues to profile registration',
      (tester) async {
        final service = _FakeAuthService()
          ..accountState = AuthAccountState.newAccount;
        await tester.pumpWidget(
          MaterialApp(home: SakhiLoginScreen(authService: service)),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('auth-mobile-number-field')),
          '9876543210',
        );
        await tester.tap(find.byKey(const Key('auth-send-otp-button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('auth-otp-code-field')),
          '123456',
        );
        await tester.tap(find.byKey(const Key('auth-verify-otp-button')));
        await tester.pumpAndSettle();

        expect(find.text('Tell us about yourself'), findsOneWidget);
        expect(
          find.byKey(const Key('auth-profile-name-field')),
          findsOneWidget,
        );
        expect(find.text('Welcome to Sakhi'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('login demo does not open protected Home or claim real auth', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SakhiLoginScreen(authService: DemoAuthService()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-mobile-number-field')),
        '9876543210',
      );
      await tester.tap(find.byKey(const Key('auth-send-otp-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-otp-code-field')),
        '654321',
      );
      await tester.tap(find.byKey(const Key('auth-verify-otp-button')));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(
        find.textContaining('no authenticated session exists'),
        findsOneWidget,
      );
      expect(find.text('Welcome to Sakhi'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('profile and consent', () {
    testWidgets('requires a name and date of birth; email is optional', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SakhiProfileScreen(
            authService: const DemoAuthService(),
            countryCode: '+91',
            phoneNumber: '9876543210',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('auth-profile-continue-button')),
      );
      await tester.tap(find.byKey(const Key('auth-profile-continue-button')));
      await tester.pumpAndSettle();
      expect(find.text('Enter your name.'), findsOneWidget);
      expect(find.text('Select your date of birth.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'profile photo can be skipped and optional email can be blank',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: SakhiProfileScreen(
              authService: const DemoAuthService(),
              countryCode: '+91',
              phoneNumber: '9876543210',
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('auth-profile-name-field')),
          'Asha Rao',
        );
        await tester.tap(find.byKey(const Key('auth-profile-dob-picker')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm date'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('auth-profile-skip-photo-button')),
        );
        await tester.tap(
          find.byKey(const Key('auth-profile-skip-photo-button')),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('auth-profile-continue-button')),
        );
        await tester.tap(find.byKey(const Key('auth-profile-continue-button')));
        await tester.pumpAndSettle();

        expect(find.text('Privacy and consent'), findsOneWidget);
        expect(
          find.byKey(const Key('auth-required-consent-checkbox')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('auth-optional-updates-checkbox')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'terms consent is required and age-policy absence blocks creation',
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

        final createFinder = find.byKey(
          const Key('auth-create-account-button'),
        );
        final optionalUpdatesFinder = find.byKey(
          const Key('auth-optional-updates-checkbox'),
        );
        expect(
          tester.widget<SakhiAuthSubmitButton>(createFinder).onPressed,
          isNull,
        );
        expect(
          tester.widget<CheckboxListTile>(optionalUpdatesFinder).value,
          isFalse,
          reason: 'Optional product-update consent must be off by default.',
        );
        expect(find.textContaining('minimum registration age'), findsOneWidget);

        await tester.ensureVisible(
          find.byKey(const Key('auth-required-consent-checkbox')),
        );
        await tester.tap(
          find.byKey(const Key('auth-required-consent-checkbox')),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<CheckboxListTile>(optionalUpdatesFinder).value,
          isFalse,
          reason: 'Accepting legal terms must not opt into marketing updates.',
        );
        expect(
          tester.widget<SakhiAuthSubmitButton>(createFinder).onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'successful account creation follows service-returned account state',
      (tester) async {
        final service = _FakeAuthService()
          ..createResult = const AccountCreationResult(
            accountState: AuthAccountState.pendingVerification,
            message: 'Account request accepted for test.',
          );
        final profile = MemberProfileDraft(
          countryCode: '+91',
          phoneNumber: '9876543210',
          displayName: 'Asha Rao',
          dateOfBirth: DateTime(1995, 5, 5),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: SakhiConsentScreen(
              authService: service,
              profile: profile,
              // Inject a test-only policy to exercise the success route.
              minimumAgeYears: 0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('auth-required-consent-checkbox')),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('auth-create-account-button')),
        );
        await tester.tap(find.byKey(const Key('auth-create-account-button')));
        await tester.pumpAndSettle();

        expect(service.createCalls, 1);
        expect(find.text('Account request accepted for test.'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const Key('auth-consent-next-button')),
        );
        await tester.tap(find.byKey(const Key('auth-consent-next-button')));
        await tester.pumpAndSettle();

        expect(find.text('One more step'), findsOneWidget);
        expect(
          find.textContaining(
            'requires follow-up from a configured authentication service',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('policy links open explicitly marked draft legal content', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SakhiLoginScreen(authService: DemoAuthService()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('auth-privacy-link')));
      await tester.tap(find.byKey(const Key('auth-privacy-link')));
      await tester.pumpAndSettle();
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('DRAFT — NOT APPROVED FOR PRODUCTION'), findsOneWidget);
      expect(
        find.textContaining('temporary privacy-policy placeholder'),
        findsOneWidget,
      );
      expect(
        find.textContaining('not an approved production policy'),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('auth-terms-link')));
      await tester.tap(find.byKey(const Key('auth-terms-link')));
      await tester.pumpAndSettle();
      expect(find.text('Terms and Conditions'), findsOneWidget);
      expect(find.text('DRAFT — NOT APPROVED FOR PRODUCTION'), findsOneWidget);
      expect(find.text('2. Eligibility and age'), findsOneWidget);
      expect(
        find.textContaining('provisional minimum age of 13'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('narrow login and registration layouts do not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: SakhiRegistrationScreen(authService: DemoAuthService()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth-send-otp-button')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        const MaterialApp(
          home: SakhiLoginScreen(authService: DemoAuthService()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth-mobile-number-field')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  test('debug preview uses provisional age 13', () {
    expect(SakhiAuthPolicy.provisionalPreviewMinimumAgeYears, 13);
    expect(SakhiAuthPolicy.minimumRegistrationAgeYears, 13);
    expect(SakhiAuthPolicy.usesProvisionalPreviewPolicy, isTrue);
  });

  test('minimum-age calculation enforces birthday boundary at 13', () {
    final today = DateTime(2026, 10, 15);
    expect(isAtLeastMinimumAge(DateTime(2013, 10, 15), today, 13), isTrue);
    expect(isAtLeastMinimumAge(DateTime(2013, 10, 16), today, 13), isFalse);
    expect(isAtLeastMinimumAge(DateTime(2014, 10, 15), today, 13), isFalse);
    expect(isAtLeastMinimumAge(DateTime(2000, 1, 1), today, 13), isTrue);
  });

  testWidgets('onboarding Get started enters mobile-first registration', (
    tester,
  ) async {
    await tester.pumpWidget(const SakhiApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('skip-onboarding-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('get-started-button')));
    await tester.pumpAndSettle();

    expect(find.text('Create your Sakhi account'), findsOneWidget);
    expect(find.byKey(const Key('auth-mobile-number-field')), findsOneWidget);
    expect(find.byKey(const Key('auth-send-otp-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

AuthOtpSession _session({
  AuthPurpose purpose = AuthPurpose.registration,
  DateTime? expiresAt,
  DateTime? resendAvailableAt,
}) {
  final now = DateTime.now();
  return AuthOtpSession(
    id: 'unit-test-session',
    countryCode: '+91',
    phoneNumber: '9876543210',
    purpose: purpose,
    expiresAt: expiresAt ?? now.add(const Duration(minutes: 5)),
    resendAvailableAt:
        resendAvailableAt ?? now.add(const Duration(seconds: 30)),
    isDemo: true,
  );
}

class _FakeAuthService implements AuthService {
  bool demo = false;
  int requestCalls = 0;
  int resendCalls = 0;
  int verifyCalls = 0;
  int createCalls = 0;
  AccountCreationResult? createResult;
  Completer<AuthOtpSession>? requestGate;
  OtpVerificationStatus verificationStatus = OtpVerificationStatus.verified;
  AuthAccountState accountState = AuthAccountState.newAccount;
  String verificationMessage = 'Code is invalid for this test.';

  @override
  bool get isDemo => demo;

  @override
  bool get isDevelopmentBackend => false;

  @override
  Future<AuthOtpSession> requestOtp({
    required String countryCode,
    required String phoneNumber,
    required AuthPurpose purpose,
  }) {
    requestCalls++;
    if (requestGate != null) return requestGate!.future;
    return Future.value(
      AuthOtpSession(
        id: 'fake-session',
        countryCode: countryCode,
        phoneNumber: phoneNumber,
        purpose: purpose,
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        resendAvailableAt: DateTime.now().add(const Duration(seconds: 30)),
        isDemo: demo,
      ),
    );
  }

  @override
  Future<AuthOtpSession> resendOtp(AuthOtpSession previousSession) async {
    resendCalls++;
    return AuthOtpSession(
      id: 'fake-resend-session',
      countryCode: previousSession.countryCode,
      phoneNumber: previousSession.phoneNumber,
      purpose: previousSession.purpose,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      resendAvailableAt: DateTime.now().add(const Duration(seconds: 30)),
      isDemo: demo,
    );
  }

  @override
  Future<OtpVerificationResult> verifyOtp({
    required AuthOtpSession session,
    required String code,
  }) async {
    verifyCalls++;
    return OtpVerificationResult(
      status: verificationStatus,
      accountState: accountState,
      message: verificationMessage,
    );
  }

  @override
  Future<AccountCreationResult> createAccount({
    required MemberProfileDraft profile,
    required MemberConsentRecord consent,
  }) async {
    createCalls++;
    if (createResult != null) return createResult!;
    throw const AuthServiceException(
      'No account was created. This is a fake service.',
      code: 'not_configured',
    );
  }
}
