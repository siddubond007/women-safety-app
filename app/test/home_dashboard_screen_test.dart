import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/features/auth/auth_service.dart';
import 'package:women_safety_app/features/home/sakhi_home_dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the integrated dashboard and authenticated profile name', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SakhiHomeDashboardScreen(
          authService: _DashboardTestAuthService(),
          loadDisplayName: () async => 'Siddu',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quick access'), findsOneWidget);
    expect(find.text('For you today'), findsOneWidget);
    expect(find.text('Siddu'), findsOneWidget);
    expect(find.text('Community updates'), findsOneWidget);

    final wellnessResources = find.text('Wellness resources');
    await tester.ensureVisible(wellnessResources);
    await tester.pumpAndSettle();
    expect(wellnessResources, findsOneWidget);

    final safetyGuidance = find.text('Safety guidance');
    await tester.ensureVisible(safetyGuidance);
    await tester.pumpAndSettle();
    expect(safetyGuidance, findsOneWidget);
    expect(find.text('Home-screen development preview'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('labels discovery search as unavailable rather than fabricating results', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SakhiHomeDashboardScreen(
          authService: _DashboardTestAuthService(),
          loadDisplayName: () async => 'Siddu',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('home-dashboard-search')),
      'nearby groups',
    );
    await tester.pump();

    expect(
      find.text(
        'Discovery search is not connected yet. Search results are not being retrieved.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('SOS preview explicitly confirms that no emergency alert is sent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SakhiHomeDashboardScreen(
          authService: _DashboardTestAuthService(),
          loadDisplayName: () async => 'Siddu',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('SOS'));
    await tester.pumpAndSettle();

    expect(find.text('Safety & SOS preview'), findsOneWidget);
    expect(
      find.textContaining(
        'No call, SMS, GPS tracking, or alert has been started.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _DashboardTestAuthService implements AuthService {
  @override
  bool get isDemo => false;

  @override
  bool get isDevelopmentBackend => true;

  @override
  Future<AuthAccountState?> restoreSession() async =>
      AuthAccountState.existingAccount;

  @override
  Future<void> logout() async {}

  @override
  Future<AuthOtpSession> requestOtp({
    required String countryCode,
    required String phoneNumber,
    required AuthPurpose purpose,
  }) async => throw UnimplementedError();

  @override
  Future<AuthOtpSession> resendOtp(AuthOtpSession previousSession) async =>
      throw UnimplementedError();

  @override
  Future<OtpVerificationResult> verifyOtp({
    required AuthOtpSession session,
    required String code,
  }) async => throw UnimplementedError();

  @override
  Future<AccountCreationResult> createAccount({
    required MemberProfileDraft profile,
    required MemberConsentRecord consent,
  }) async => throw UnimplementedError();
}
