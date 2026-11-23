import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/core/constants/mock_data.dart';
import 'package:women_safety_app/features/auth/backend_api_client.dart';
import 'package:women_safety_app/features/settings/screens/privacy_settings_screen.dart';

class _FakePrivacySettingsApi extends BackendApiClient {
  _FakePrivacySettingsApi() : super(baseUrl: 'http://127.0.0.1:3001/api/v1');

  bool failSessions = false;
  bool otherSessionRevoked = false;
  final otherSessionId = '5a23b326-329c-4f20-9c5b-b2d1268855e8';

  @override
  Future<String?> readAccessToken() async =>
      'synthetic-privacy-settings-session-token';

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = false,
    Map<String, String>? headers,
  }) async {
    if (path != 'module2/sessions' || !authenticated) {
      throw StateError('Unexpected GET request: $path');
    }
    if (failSessions) throw StateError('simulated session request failure');
    return {
      'sessions': [
        {
          'id': 'f8d31bca-b3d7-4953-8ff1-9c0b1354d3bc',
          'createdAt': '2026-11-01T08:00:00.000Z',
          'expiresAt': '2026-11-30T08:00:00.000Z',
          'deviceName': 'Android app',
          'isActive': true,
          'isCurrent': true,
        },
        {
          'id': otherSessionId,
          'createdAt': '2026-10-30T08:00:00.000Z',
          'expiresAt': '2026-11-29T08:00:00.000Z',
          'deviceName': 'Windows app',
          'isActive': !otherSessionRevoked,
          'isCurrent': false,
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, Object?>? body,
    bool authenticated = false,
    Map<String, String>? headers,
  }) async {
    if (path != 'module2/sessions/$otherSessionId' || !authenticated) {
      throw StateError('Unexpected DELETE request: $path');
    }
    otherSessionRevoked = true;
    return {'revoked': true, 'currentSession': false};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPrivacySettings(
    WidgetTester tester,
    _FakePrivacySettingsApi api,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SakhiPrototypeState.instance.configureApiClient(api);
    await tester.pumpWidget(const MaterialApp(home: PrivacySettingsScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Two-factor row opens its own unavailable-status dialog, not Account & Security',
    (tester) async {
      await pumpPrivacySettings(tester, _FakePrivacySettingsApi());

      final row = find.text('Two-Factor Authentication');
      await tester.scrollUntilVisible(
        row,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.text('Two-Factor Authentication'), findsNWidgets(2));
      expect(find.textContaining('has not been configured'), findsOneWidget);
      expect(find.text('Phone number'), findsNothing);
    },
  );

  testWidgets(
    'Active Login Sessions opens the session list and revokes another device',
    (tester) async {
      final api = _FakePrivacySettingsApi();
      await pumpPrivacySettings(tester, api);

      final row = find.text('Active Login Sessions');
      await tester.scrollUntilVisible(
        row,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.text('This device • Current session'), findsOneWidget);
      expect(find.text('Windows app • Other session'), findsOneWidget);
      expect(find.text('Bangalore (Current)'), findsNothing);
      expect(find.text('Revoke'), findsOneWidget);

      await tester.tap(find.text('Revoke'));
      await tester.pumpAndSettle();
      expect(find.text('Revoke this login session?'), findsOneWidget);

      await tester.tap(find.text('Revoke session'));
      await tester.pumpAndSettle();

      expect(api.otherSessionRevoked, isTrue);
      expect(find.text('Revoked or expired'), findsOneWidget);
      expect(find.text('Login session revoked.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'session request failure displays an error and retry instead of a false empty state',
    (tester) async {
      final api = _FakePrivacySettingsApi()..failSessions = true;
      await pumpPrivacySettings(tester, api);

      final row = find.text('Active Login Sessions');
      await tester.scrollUntilVisible(
        row,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Login sessions could not be loaded'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(
        find.text('No login sessions were returned for this account.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'an open Active Login Sessions sheet clears immediately when the account session changes',
    (tester) async {
      final api = _FakePrivacySettingsApi();
      final state = SakhiPrototypeState.instance;
      await pumpPrivacySettings(tester, api);

      final row = find.text('Active Login Sessions');
      await tester.scrollUntilVisible(
        row,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.text('Windows app • Other session'), findsOneWidget);

      state.setLocalCacheDeleteOverrideForTesting(() {});
      try {
        await state.clearAccountScopedData();
      } finally {
        state.setLocalCacheDeleteOverrideForTesting(null);
      }
      await tester.pump();

      expect(find.text('Windows app • Other session'), findsNothing);
      expect(
        find.textContaining(
          'Login sessions were cleared because your Sakhi session changed',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
