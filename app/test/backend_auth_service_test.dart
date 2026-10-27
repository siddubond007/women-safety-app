import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/features/auth/auth_service.dart';
import 'package:women_safety_app/features/auth/backend_api_client.dart';
import 'package:women_safety_app/features/auth/backend_auth_service.dart';

class _FakeBackendApiClient extends BackendApiClient {
  _FakeBackendApiClient({
    this.token,
    this.meResponse = const <String, dynamic>{},
    this.meError,
    this.logoutError,
  }) : super();

  String? token;
  Map<String, dynamic> meResponse;
  BackendApiException? meError;
  BackendApiException? logoutError;
  int clearCalls = 0;
  final getRequests = <(String, bool)>[];
  final postRequests = <(String, bool)>[];

  @override
  Future<String?> readAccessToken() async => token;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = false,
    Map<String, String>? headers,
  }) async {
    getRequests.add((path, authenticated));
    if (meError != null) throw meError!;
    return meResponse;
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?> body = const <String, Object?>{},
    bool authenticated = false,
    Map<String, String>? headers,
  }) async {
    postRequests.add((path, authenticated));
    if (logoutError != null) throw logoutError!;
    return const <String, dynamic>{'status': 'signed_out'};
  }

  @override
  Future<void> clearAccessToken() async {
    clearCalls++;
    token = null;
  }

  @override
  Future<void> storeAccessToken(String value) async {
    token = value;
  }
}

void main() {
  group('backend session restore', () {
    test('does not contact the server when no token is stored', () async {
      final api = _FakeBackendApiClient();
      final service = BackendAuthService(apiClient: api);

      expect(await service.restoreSession(), isNull);
      expect(api.getRequests, isEmpty);
      expect(api.clearCalls, 0);
    });

    test('restores a saved pending-verification account', () async {
      final api = _FakeBackendApiClient(
        token: 'development-token',
        meResponse: const <String, dynamic>{
          'accountId': 'account-id',
          'status': 'PENDING_VERIFICATION',
          'verificationStatus': 'VERIFIED',
          'profile': <String, dynamic>{
            'displayName': 'Test member',
            'dateOfBirth': '2001-10-16',
            'email': null,
          },
          'isDemo': true,
        },
      );
      final service = BackendAuthService(apiClient: api);

      expect(
        await service.restoreSession(),
        AuthAccountState.pendingVerification,
      );
      expect(api.getRequests, [('auth/me', true)]);
      expect(api.token, 'development-token');
    });

    test('restores incomplete profiles to the registration state', () async {
      final api = _FakeBackendApiClient(
        token: 'development-token',
        meResponse: const <String, dynamic>{
          'accountId': 'account-id',
          'status': 'PENDING_VERIFICATION',
          'verificationStatus': 'VERIFIED',
          'profile': null,
          'isDemo': true,
        },
      );
      final service = BackendAuthService(apiClient: api);

      expect(await service.restoreSession(), AuthAccountState.newAccount);
    });

    test('clears an expired or invalid token and returns to onboarding', () async {
      final api = _FakeBackendApiClient(
        token: 'stale-token',
        meError: const BackendApiException(
          statusCode: 401,
          code: 'unauthorized',
          message: 'Sign in to continue.',
        ),
      );
      final service = BackendAuthService(apiClient: api);

      expect(await service.restoreSession(), isNull);
      expect(api.token, isNull);
      expect(api.clearCalls, 1);
    });
  });

  group('backend logout', () {
    test('calls the logout endpoint and clears the local token', () async {
      final api = _FakeBackendApiClient(token: 'development-token');
      final service = BackendAuthService(apiClient: api);

      await service.logout();

      expect(api.postRequests, [('auth/logout', true)]);
      expect(api.token, isNull);
      expect(api.clearCalls, 1);
    });

    test('clears the local token even when remote revocation fails', () async {
      final api = _FakeBackendApiClient(
        token: 'development-token',
        logoutError: const BackendApiException(
          statusCode: 0,
          code: 'network_unavailable',
          message: 'Sakhi backend is unreachable.',
        ),
      );
      final service = BackendAuthService(apiClient: api);

      await expectLater(service.logout(), throwsA(isA<AuthServiceException>()));
      expect(api.token, isNull);
      expect(api.clearCalls, 1);
    });
  });
}
