import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/core/constants/mock_data.dart';
import 'package:women_safety_app/features/account_security/screens/account_security_screen.dart';
import 'package:women_safety_app/features/auth/backend_api_client.dart';

class _FakeSessionApi extends BackendApiClient {
  _FakeSessionApi() : super(baseUrl: 'http://127.0.0.1:3001/api/v1');

  bool otherSessionRevoked = false;
  bool failDeleteAccount = false;
  String? token = 'synthetic-test-session-token-with-more-than-32-characters';
  final currentId = 'f8d31bca-b3d7-4953-8ff1-9c0b1354d3bc';
  final otherId = '5a23b326-329c-4f20-9c5b-b2d1268855e8';

  @override
  Future<String?> readAccessToken() async => token;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = false,
    Map<String, String>? headers,
  }) async {
    if (path != 'module2/sessions') {
      throw StateError('Unexpected GET path: $path');
    }
    return {
      'sessions': [
        {
          'id': currentId,
          'createdAt': '2026-11-01T08:00:00.000Z',
          'expiresAt': '2026-11-30T08:00:00.000Z',
          'isActive': true,
          'isCurrent': true,
          'deviceName': 'Android app',
        },
        {
          'id': otherId,
          'createdAt': '2026-10-30T08:00:00.000Z',
          'expiresAt': '2026-11-29T08:00:00.000Z',
          'isActive': !otherSessionRevoked,
          'isCurrent': false,
          'deviceName': 'Windows app',
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
    if (path != 'module2/sessions/$otherId') {
      throw StateError('Unexpected DELETE path: $path');
    }
    otherSessionRevoked = true;
    return {'revoked': true, 'currentSession': false};
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?> body = const <String, Object?>{},
    bool authenticated = false,
    Map<String, String>? headers,
  }) async {
    if (path == 'module2/account/delete') {
      if (failDeleteAccount) {
        throw StateError('simulated account deletion failure');
      }
      return {'requestId': 'req-123', 'status': 'REQUESTED'};
    }
    throw StateError('Unexpected POST path: $path');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Account & Security opens real login sessions and revokes another session',
    (tester) async {
      final api = _FakeSessionApi();
      SakhiPrototypeState.instance.configureApiClient(api);

      await tester.pumpWidget(const MaterialApp(home: AccountSecurityScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Login devices & sessions'), findsOneWidget);
      expect(
        find.text('Unavailable • no second-factor provider is configured'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Unavailable • no verifiable PIN/password credential is stored',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Login devices & sessions'));
      await tester.pumpAndSettle();

      expect(find.text('This device • Current session'), findsOneWidget);
      expect(find.text('Windows app • Other session'), findsOneWidget);
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
    'Two-factor setting explains that no second-factor provider is configured',
    (tester) async {
      SakhiPrototypeState.instance.configureApiClient(_FakeSessionApi());

      await tester.pumpWidget(const MaterialApp(home: AccountSecurityScreen()));
      await tester.pumpAndSettle();

      final twoFactorRow = find.text('Two-factor authentication');
      await tester.ensureVisible(twoFactorRow);
      await tester.tap(twoFactorRow);
      await tester.pumpAndSettle();

      expect(find.text('Two-factor authentication'), findsNWidgets(2));
      expect(
        find.text(
          'Sakhi does not currently have an enrolled TOTP, passkey, or other second-factor provider. This setting cannot be enabled yet and no two-factor protection is active.',
        ),
        findsOneWidget,
      );
      expect(find.text('Enable'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an open Login devices & sessions sheet clears immediately when the account session changes',
    (tester) async {
      final api = _FakeSessionApi();
      final state = SakhiPrototypeState.instance;
      state.configureApiClient(api);

      await tester.pumpWidget(const MaterialApp(home: AccountSecurityScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Login devices & sessions'));
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

  testWidgets(
    'Account deactivation explains truthfully that deactivation is not exposed by the backend',
    (tester) async {
      SakhiPrototypeState.instance.configureApiClient(_FakeSessionApi());

      await tester.pumpWidget(const MaterialApp(home: AccountSecurityScreen()));
      await tester.pumpAndSettle();

      final deactRow = find.text('Account deactivation');
      await tester.ensureVisible(deactRow);
      await tester.tap(deactRow);
      await tester.pumpAndSettle();

      expect(find.text('Temporarily deactivate account'), findsOneWidget);
      expect(
        find.textContaining('Deactivation is not exposed by the current backend'),
        findsOneWidget,
      );
      expect(find.text('Deactivate'), findsNothing);
    },
  );

  testWidgets(
    'Delete account fails closed when backend deletion request fails',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _FakeSessionApi()..failDeleteAccount = true;
      SakhiPrototypeState.instance.configureApiClient(api);

      await tester.pumpWidget(const MaterialApp(home: AccountSecurityScreen()));
      await tester.pumpAndSettle();

      final deleteRow = find.text('Delete account');
      await tester.scrollUntilVisible(
        deleteRow,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(deleteRow);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Type DELETE to confirm'),
        'DELETE',
      );
      await tester.tap(find.text('Request Deletion'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Account deletion could not be completed. No change was confirmed by the server.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Account deletion request recorded. Signing out…'),
        findsNothing,
      );
    },
  );
}
