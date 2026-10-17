import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/features/auth/auth_service.dart';
import 'package:women_safety_app/features/home/sakhi_home_dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpDashboard(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SakhiHomeDashboardScreen(
          authService: _DashboardTestAuthService(),
          loadDisplayName: () async => 'Siddu',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('home matches the Sakhi prototype content and authenticated greeting', (
    tester,
  ) async {
    await pumpDashboard(tester);

    expect(find.byKey(const Key('home-dashboard-search')), findsOneWidget);
    expect(find.byKey(const Key('home-action-explore')), findsOneWidget);
    expect(find.byKey(const Key('home-action-community')), findsOneWidget);
    expect(find.byKey(const Key('home-action-wellness')), findsOneWidget);
    expect(find.byKey(const Key('home-action-sos')), findsOneWidget);
    expect(find.text('Siddu'), findsOneWidget);
    expect(find.text('For You Today'), findsOneWidget);
    expect(find.text('5 new posts'), findsOneWidget);
    expect(find.text('2 community updates'), findsOneWidget);
    expect(find.text('Featured resources'), findsOneWidget);
    expect(find.byKey(const Key('home-create-post-button')), findsOneWidget);
    expect(find.textContaining('not connected yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home search filters local preview topics instead of showing a dead end', (
    tester,
  ) async {
    await pumpDashboard(tester);

    await tester.enterText(
      find.byKey(const Key('home-dashboard-search')),
      'safety',
    );
    await tester.pumpAndSettle();

    expect(find.text('Matching prototype topics'), findsOneWidget);
    expect(find.text('#SafetyTips'), findsOneWidget);
    expect(find.textContaining('not connected'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick actions and bottom navigation open their preview screens', (
    tester,
  ) async {
    await pumpDashboard(tester);

    await tester.tap(find.byKey(const Key('home-action-explore')));
    await tester.pumpAndSettle();
    expect(find.text('Trending Topics'), findsOneWidget);
    expect(find.text('Explore by category'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-bottom-nav-Community')));
    await tester.pumpAndSettle();
    expect(find.text('Kavya Nair'), findsOneWidget);
    expect(find.text('Sample community posts are shown for visual testing; likes, saves and drafts remain local to this screen.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-bottom-nav-Profile')));
    await tester.pumpAndSettle();
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create-post action adds a local preview post to Community', (
    tester,
  ) async {
    await pumpDashboard(tester);

    await tester.tap(find.byKey(const Key('home-create-post-button')));
    await tester.pumpAndSettle();

    expect(find.text('Create a post'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).last,
      'A test post from the preview',
    );
    await tester.tap(find.text('Add to preview'));
    await tester.pumpAndSettle();

    expect(find.text('Community'), findsOneWidget);
    expect(find.text('A test post from the preview'), findsOneWidget);
    expect(find.textContaining('not connected yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SOS opens a safety preview and clearly avoids dispatching a real alert', (
    tester,
  ) async {
    await pumpDashboard(tester);

    await tester.tap(find.byKey(const Key('home-action-sos')));
    await tester.pumpAndSettle();

    expect(find.text('Safety & SOS preview'), findsOneWidget);
    expect(find.textContaining('does not place calls, send SMS'), findsOneWidget);
    expect(find.textContaining('dispatch an emergency alert'), findsOneWidget);

    await tester.tap(find.text('View safety guidance'));
    await tester.pumpAndSettle();
    expect(find.text('Safety map preview'), findsOneWidget);
    expect(find.byKey(const Key('safety-preview-sos-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile edits and notification preferences react locally without claiming persistence', (
    tester,
  ) async {
    await pumpDashboard(tester);

    await tester.tap(find.byKey(const Key('home-bottom-nav-Profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Chakravarthi');
    await tester.tap(find.text('Save preview changes'));
    await tester.pumpAndSettle();
    expect(find.text('Chakravarthi'), findsWidgets);

    await tester.tap(find.byKey(const Key('home-notifications-button')));
    await tester.pumpAndSettle();
    expect(find.text('Notification Preferences'), findsOneWidget);
    expect(find.text('These switches are interactive preview preferences. They do not change push-notification delivery on the backend.'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(7));

    final firstSwitch = tester.widget<SwitchListTile>(find.byType(SwitchListTile).first);
    expect(firstSwitch.value, isTrue);
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value, isFalse);
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
