import 'dart:io';

import 'auth_service.dart';
import 'backend_api_client.dart';

/// Real database-backed development adapter. It deliberately uses a local
/// test OTP provider, not SMS; the backend refuses production startup.
class BackendAuthService implements AuthService {
  BackendAuthService({BackendApiClient? apiClient})
    : apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient apiClient;

  @override
  bool get isDemo => false;

  @override
  bool get isDevelopmentBackend => true;

  AuthServiceException _mapError(BackendApiException error) =>
      AuthServiceException(error.message, code: error.code);

  DateTime _dateFromResponse(Object? value, String label) {
    if (value is! String) {
      throw AuthServiceException(
        'The backend returned an invalid $label.',
        code: 'invalid_response',
      );
    }
    final date = DateTime.tryParse(value);
    if (date == null) {
      throw AuthServiceException(
        'The backend returned an invalid $label.',
        code: 'invalid_response',
      );
    }
    return date;
  }

  AuthOtpSession _sessionFromResponse(
    Map<String, dynamic> data, {
    required String countryCode,
    required String phoneNumber,
    required AuthPurpose purpose,
  }) {
    final id = data['challengeId'];
    if (id is! String || id.isEmpty) {
      throw const AuthServiceException(
        'The backend did not return an OTP request ID.',
        code: 'invalid_response',
      );
    }
    final code = data['developmentCode'];
    if (data['deliveryMode'] == 'development_echo' &&
        (code is! String || !RegExp(r'^\d{6}$').hasMatch(code))) {
      throw const AuthServiceException(
        'The backend did not return a valid local development code.',
        code: 'invalid_response',
      );
    }
    return AuthOtpSession(
      id: id,
      countryCode: countryCode,
      phoneNumber: phoneNumber,
      purpose: purpose,
      expiresAt: _dateFromResponse(data['expiresAt'], 'expiry time'),
      resendAvailableAt: _dateFromResponse(
        data['resendAvailableAt'],
        'resend time',
      ),
      isDemo:
          data['isDemo'] == true || data['deliveryMode'] == 'development_echo',
      developmentCode: code is String ? code : null,
    );
  }

  AuthAccountState _restoredAccountState(Map<String, dynamic> data) {
    final status = data['status'];
    if (status is! String) {
      throw const AuthServiceException(
        'The backend returned an invalid saved-session status.',
        code: 'invalid_response',
      );
    }

    final verificationStatus = data['verificationStatus'];
    switch (status) {
      case 'ACTIVE':
        return verificationStatus == 'VERIFIED'
            ? AuthAccountState.existingAccount
            : AuthAccountState.pendingVerification;
      case 'RESTRICTED':
      case 'SUSPENDED':
      case 'DELETED':
        return AuthAccountState.restricted;
      case 'PENDING_VERIFICATION':
        return data['profile'] == null
            ? AuthAccountState.newAccount
            : AuthAccountState.pendingVerification;
      default:
        throw const AuthServiceException(
          'The backend returned an unknown saved-session status.',
          code: 'invalid_response',
        );
    }
  }

  @override
  Future<AuthAccountState?> restoreSession() async {
    final token = await apiClient.readAccessToken();
    if (token == null || token.isEmpty) return null;

    try {
      final data = await apiClient.get('auth/me', authenticated: true);
      return _restoredAccountState(data);
    } on BackendApiException catch (error) {
      if (error.statusCode == 401) {
        await apiClient.clearAccessToken();
        return null;
      }
      throw _mapError(error);
    } on AuthServiceException {
      rethrow;
    } catch (_) {
      throw const AuthServiceException(
        'The saved Sakhi session could not be checked. Check the local backend connection and retry.',
        code: 'session_restore_failed',
      );
    }
  }

  @override
  Future<void> logout() async {
    AuthServiceException? failure;
    try {
      await apiClient.post('auth/logout', authenticated: true);
    } on BackendApiException catch (error) {
      // An already-invalid server session is effectively signed out.
      if (error.statusCode != 401) failure = _mapError(error);
    } on AuthServiceException catch (error) {
      failure = error;
    } catch (_) {
      failure = const AuthServiceException(
        'The server could not confirm session revocation.',
        code: 'logout_revoke_failed',
      );
    }

    // Clear the credential on this device even if server revocation failed.
    try {
      await apiClient.clearAccessToken();
    } catch (_) {
      failure ??= const AuthServiceException(
        'The saved session could not be cleared from this device.',
        code: 'logout_clear_failed',
      );
    }

    if (failure != null) throw failure;
  }

  @override
  Future<AuthOtpSession> requestOtp({
    required String countryCode,
    required String phoneNumber,
    required AuthPurpose purpose,
  }) async {
    try {
      // Starting another authentication flow must not reuse an older account token.
      await apiClient.clearAccessToken();
      final data = await apiClient.post(
        'auth/otp/request',
        body: {
          'countryCode': countryCode,
          'phoneNumber': phoneNumber,
          'purpose': purpose == AuthPurpose.login ? 'login' : 'registration',
        },
      );
      return _sessionFromResponse(
        data,
        countryCode: countryCode,
        phoneNumber: phoneNumber,
        purpose: purpose,
      );
    } on BackendApiException catch (error) {
      throw _mapError(error);
    } on AuthServiceException {
      rethrow;
    } on SocketException {
      throw const AuthServiceException(
        'Sakhi backend is unreachable. Start the local backend and check the USB connection.',
        code: 'network_unavailable',
      );
    } catch (_) {
      throw const AuthServiceException(
        'The development OTP request could not be completed.',
        code: 'request_failed',
      );
    }
  }

  @override
  Future<AuthOtpSession> resendOtp(AuthOtpSession previousSession) async {
    try {
      final data = await apiClient.post(
        'auth/otp/resend',
        body: {'challengeId': previousSession.id},
      );
      return _sessionFromResponse(
        data,
        countryCode: previousSession.countryCode,
        phoneNumber: previousSession.phoneNumber,
        purpose: previousSession.purpose,
      );
    } on BackendApiException catch (error) {
      throw _mapError(error);
    } on AuthServiceException {
      rethrow;
    } catch (_) {
      throw const AuthServiceException(
        'A new development code could not be requested.',
        code: 'resend_failed',
      );
    }
  }

  @override
  Future<OtpVerificationResult> verifyOtp({
    required AuthOtpSession session,
    required String code,
  }) async {
    try {
      final data = await apiClient.post(
        'auth/otp/verify',
        body: {'challengeId': session.id, 'code': code},
      );
      final status = data['status'];
      if (status == 'invalid') {
        return OtpVerificationResult(
          status: OtpVerificationStatus.invalid,
          message: data['message'] is String
              ? data['message'] as String
              : 'That code is not correct. Try again.',
        );
      }
      if (status == 'expired') {
        return OtpVerificationResult(
          status: OtpVerificationStatus.expired,
          message: data['message'] is String
              ? data['message'] as String
              : 'This code has expired. Request another code.',
        );
      }
      if (status == 'tooManyAttempts') {
        return OtpVerificationResult(
          status: OtpVerificationStatus.tooManyAttempts,
          message: data['message'] is String
              ? data['message'] as String
              : 'Too many attempts. Request another code later.',
        );
      }
      if (status != 'verified') {
        throw const AuthServiceException(
          'The backend returned an unknown OTP verification status.',
          code: 'invalid_response',
        );
      }

      final token = data['accessToken'];
      if (token is String && token.isNotEmpty) {
        await apiClient.storeAccessToken(token);
      } else {
        await apiClient.clearAccessToken();
      }

      return OtpVerificationResult(
        status: OtpVerificationStatus.verified,
        accountState: _accountState(data['accountState']),
        message: data['message'] is String
            ? data['message'] as String
            : 'Development backend verification completed. No SMS was sent.',
      );
    } on BackendApiException catch (error) {
      throw _mapError(error);
    } on AuthServiceException {
      rethrow;
    } catch (_) {
      throw const AuthServiceException(
        'Verification could not be completed. Check the local backend connection.',
        code: 'verify_failed',
      );
    }
  }

  AuthAccountState _accountState(Object? value) {
    switch (value) {
      case 'newAccount':
        return AuthAccountState.newAccount;
      case 'existingAccount':
        return AuthAccountState.existingAccount;
      case 'pendingVerification':
        return AuthAccountState.pendingVerification;
      case 'restricted':
        return AuthAccountState.restricted;
      default:
        throw const AuthServiceException(
          'The backend returned an unknown account state.',
          code: 'invalid_response',
        );
    }
  }

  @override
  Future<AccountCreationResult> createAccount({
    required MemberProfileDraft profile,
    required MemberConsentRecord consent,
  }) async {
    try {
      final dob = profile.dateOfBirth;
      final acceptedAt = consent.acceptedAt.toUtc();
      final dateString =
          "${dob.year.toString().padLeft(4, '0')}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}";
      final data = await apiClient.post(
        'auth/profile',
        authenticated: true,
        body: {
          'displayName': profile.displayName.trim(),
          'dateOfBirth': dateString,
          'email': profile.email,
          'termsVersion': consent.termsVersion,
          'privacyVersion': consent.privacyVersion,
          'acceptedAt': acceptedAt.toIso8601String(),
          'optionalUpdatesAccepted': consent.optionalUpdatesAccepted,
        },
      );

      return AccountCreationResult(
        accountState: _accountState(data['accountState']),
        message: data['message'] is String
            ? data['message'] as String
            : 'Profile saved by the development backend.',
      );
    } on BackendApiException catch (error) {
      throw _mapError(error);
    } on AuthServiceException {
      rethrow;
    } catch (_) {
      throw const AuthServiceException(
        'The profile could not be saved. No success was confirmed.',
        code: 'profile_save_failed',
      );
    }
  }
}
