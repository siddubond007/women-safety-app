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
    if (path == 'auth/otp/request') {
      return const <String, dynamic>{
        'challengeId': 'challenge-1',
        'expiresAt': '2026-11-01T10:15:00.000Z',
        'resendAvailableAt': '2026-11-01T10:01:00.000Z',
        'deliveryMode': 'development_echo',
        'developmentCode': '123456',
      };
    }
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
    test('does not contact the server and clears account state when no token is stored', () async {
      final api = _FakeBackendApiClient();
      var clearedAccountState = 0;
      final service = BackendAuthService(
        apiClient: api,
        onSessionCleared: () async {
          clearedAccountState++;
        },
      );

      expect(await service.restoreSession(), isNull);
      expect(api.getRequests, isEmpty);
      expect(api.clearCalls, 0);
      expect(clearedAccountState, 1);
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

    test(
      'clears an expired or invalid token and returns to onboarding',
      () async {
        final api = _FakeBackendApiClient(
          token: 'stale-token',
          meError: const BackendApiException(
            statusCode: 401,
            code: 'unauthorized',
            message: 'Sign in to continue.',
          ),
        );
        var clearedAccountState = 0;
        final service = BackendAuthService(
          apiClient: api,
          onSessionCleared: () async {
            clearedAccountState++;
          },
        );

        expect(await service.restoreSession(), isNull);
        expect(api.token, isNull);
        expect(api.clearCalls, 1);
        expect(clearedAccountState, 1);
      },
    );
  });

  group('backend OTP request', () {
    test(
      'clears the previous account state before starting a new login',
      () async {
        final api = _FakeBackendApiClient(token: 'previous-account-token');
        var clearedAccountState = false;
        final service = BackendAuthService(
          apiClient: api,
          onSessionCleared: () async {
            clearedAccountState = true;
          },
        );

        final session = await service.requestOtp(
          countryCode: '+91',
          phoneNumber: '9876543210',
          purpose: AuthPurpose.login,
        );

        expect(clearedAccountState, isTrue);
        expect(api.token, isNull);
        expect(api.clearCalls, 1);
        expect(api.postRequests, [('auth/otp/request', false)]);
        expect(session.id, 'challenge-1');
      },
    );
  });

  group('backend logout', () {
    test(
      'calls the logout endpoint and clears local token and account state',
      () async {
        final api = _FakeBackendApiClient(token: 'development-token');
        var clearedAccountState = 0;
        final service = BackendAuthService(
          apiClient: api,
          onSessionCleared: () async {
            clearedAccountState++;
          },
        );

        await service.logout();

        expect(api.postRequests, [('auth/logout', true)]);
        expect(api.token, isNull);
        expect(api.clearCalls, 1);
        expect(clearedAccountState, 1);
      },
    );

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
