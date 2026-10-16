enum AuthPurpose { login, registration }

enum AuthAccountState {
  existingAccount,
  newAccount,
  pendingVerification,
  restricted,
}

enum OtpVerificationStatus { verified, invalid, expired, tooManyAttempts }

class AuthServiceException implements Exception {
  const AuthServiceException(this.message, {this.code = 'unavailable'});

  final String message;
  final String code;

  @override
  String toString() => 'AuthServiceException($code): $message';
}

class AuthOtpSession {
  const AuthOtpSession({
    required this.id,
    required this.countryCode,
    required this.phoneNumber,
    required this.purpose,
    required this.expiresAt,
    required this.resendAvailableAt,
    required this.isDemo,
    this.developmentCode,
  });

  final String id;
  final String countryCode;
  final String phoneNumber;
  final AuthPurpose purpose;
  final DateTime expiresAt;
  final DateTime resendAvailableAt;
  final bool isDemo;

  /// Present only when the local dev/test backend deliberately echoes its
  /// generated test code. Never present in a production provider response.
  final String? developmentCode;

  String get maskedPhoneNumber {
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final visible = digits.length > 4
        ? digits.substring(digits.length - 4)
        : digits;
    final hiddenLength = (digits.length - visible.length).clamp(0, 12);
    final concealed = List<String>.filled(hiddenLength, '•').join();
    return '$countryCode $concealed$visible';
  }
}

class OtpVerificationResult {
  const OtpVerificationResult({
    required this.status,
    this.accountState,
    this.message,
  });

  final OtpVerificationStatus status;
  final AuthAccountState? accountState;
  final String? message;
}

class AccountCreationResult {
  const AccountCreationResult({required this.accountState, this.message});

  final AuthAccountState accountState;
  final String? message;
}

class MemberProfileDraft {
  const MemberProfileDraft({
    required this.countryCode,
    required this.phoneNumber,
    required this.displayName,
    required this.dateOfBirth,
    this.email,
    this.photoPath,
  });

  final String countryCode;
  final String phoneNumber;
  final String displayName;
  final DateTime dateOfBirth;
  final String? email;
  final String? photoPath;
}

class MemberConsentRecord {
  const MemberConsentRecord({
    required this.termsVersion,
    required this.privacyVersion,
    required this.acceptedAt,
    required this.optionalUpdatesAccepted,
  });

  final String termsVersion;
  final String privacyVersion;
  final DateTime acceptedAt;
  final bool optionalUpdatesAccepted;
}

abstract interface class AuthService {
  bool get isDemo;

  /// True when the app is connected to the local backend using development
  /// authentication. This differs from the no-persistence demo simulator.
  bool get isDevelopmentBackend;

  /// Restores a persisted session from the configured service. Returns null
  /// when no valid session exists; implementations must not infer access.
  Future<AuthAccountState?> restoreSession();

  /// Revokes the current session where supported and clears local credentials.
  Future<void> logout();

  Future<AuthOtpSession> requestOtp({
    required String countryCode,
    required String phoneNumber,
    required AuthPurpose purpose,
  });

  Future<AuthOtpSession> resendOtp(AuthOtpSession previousSession);

  Future<OtpVerificationResult> verifyOtp({
    required AuthOtpSession session,
    required String code,
  });

  Future<AccountCreationResult> createAccount({
    required MemberProfileDraft profile,
    required MemberConsentRecord consent,
  });
}

/// Visible, debug-only flow simulator. It never sends a real SMS, creates a
/// real account, persists identity data, or establishes an authenticated session.
/// Any six digits simulate verification; this is not a valid production OTP.
class DemoAuthService implements AuthService {
  const DemoAuthService();

  @override
  bool get isDemo => true;

  @override
  bool get isDevelopmentBackend => false;

  @override
  Future<AuthAccountState?> restoreSession() async => null;

  @override
  Future<void> logout() async {}

  AuthOtpSession _newSession({
    required String countryCode,
    required String phoneNumber,
    required AuthPurpose purpose,
  }) {
    final now = DateTime.now();
    return AuthOtpSession(
      id: 'demo-${now.microsecondsSinceEpoch}',
      countryCode: countryCode,
      phoneNumber: phoneNumber,
      purpose: purpose,
      expiresAt: now.add(const Duration(minutes: 5)),
      resendAvailableAt: now.add(const Duration(seconds: 30)),
      isDemo: true,
    );
  }

  @override
  Future<AuthOtpSession> requestOtp({
    required String countryCode,
    required String phoneNumber,
    required AuthPurpose purpose,
  }) async => _newSession(
    countryCode: countryCode,
    phoneNumber: phoneNumber,
    purpose: purpose,
  );

  @override
  Future<AuthOtpSession> resendOtp(AuthOtpSession previousSession) async =>
      _newSession(
        countryCode: previousSession.countryCode,
        phoneNumber: previousSession.phoneNumber,
        purpose: previousSession.purpose,
      );

  @override
  Future<OtpVerificationResult> verifyOtp({
    required AuthOtpSession session,
    required String code,
  }) async {
    if (DateTime.now().isAfter(session.expiresAt)) {
      return const OtpVerificationResult(
        status: OtpVerificationStatus.expired,
        message:
            'This demo verification session has expired. Request a new code.',
      );
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      return const OtpVerificationResult(
        status: OtpVerificationStatus.invalid,
        message: 'Enter all six digits.',
      );
    }
    return OtpVerificationResult(
      status: OtpVerificationStatus.verified,
      accountState: session.purpose == AuthPurpose.login
          ? AuthAccountState.existingAccount
          : AuthAccountState.newAccount,
      message: 'Demo verification only. Your number was not verified by SMS.',
    );
  }

  @override
  Future<AccountCreationResult> createAccount({
    required MemberProfileDraft profile,
    required MemberConsentRecord consent,
  }) async {
    throw const AuthServiceException(
      'Demo mode cannot create accounts. No account or session was created because the backend is not connected.',
      code: 'not_configured',
    );
  }
}

/// Used in release builds until a real SMS/authentication API is selected.
class UnconfiguredAuthService implements AuthService {
  const UnconfiguredAuthService();

  @override
  bool get isDemo => false;

  @override
  bool get isDevelopmentBackend => false;

  @override
  Future<AuthAccountState?> restoreSession() async => null;

  @override
  Future<void> logout() async {}

  @override
  Future<AuthOtpSession> requestOtp({
    required String countryCode,
    required String phoneNumber,
    required AuthPurpose purpose,
  }) async {
    throw const AuthServiceException(
      'Sakhi authentication is not connected yet. No SMS was sent.',
      code: 'not_configured',
    );
  }

  @override
  Future<AuthOtpSession> resendOtp(AuthOtpSession previousSession) async {
    throw const AuthServiceException(
      'Sakhi authentication is not connected yet. No SMS was sent.',
      code: 'not_configured',
    );
  }

  @override
  Future<OtpVerificationResult> verifyOtp({
    required AuthOtpSession session,
    required String code,
  }) async {
    throw const AuthServiceException(
      'OTP verification is unavailable because Sakhi authentication is not connected.',
      code: 'not_configured',
    );
  }

  @override
  Future<AccountCreationResult> createAccount({
    required MemberProfileDraft profile,
    required MemberConsentRecord consent,
  }) async {
    throw const AuthServiceException(
      'No account was created. Sakhi backend services are not connected yet.',
      code: 'not_configured',
    );
  }
}
