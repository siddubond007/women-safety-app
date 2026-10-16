import '../auth/backend_api_client.dart';

/// Profile data returned for the currently authenticated member only.
class SakhiMemberProfile {
  const SakhiMemberProfile({
    required this.displayName,
    this.email,
    this.bio,
    this.city,
    this.updatedAt,
  });

  final String displayName;
  final String? email;
  final String? bio;
  final String? city;
  final DateTime? updatedAt;
}

/// Public contract for the signed-in member's own profile.
abstract interface class ProfileService {
  Future<SakhiMemberProfile> getMyProfile();

  Future<SakhiMemberProfile> updateMyProfile({
    required String displayName,
    required String? email,
    required String? bio,
    required String? city,
  });
}

class ProfileServiceException implements Exception {
  const ProfileServiceException(this.message);

  final String message;

  @override
  String toString() => 'ProfileServiceException: $message';
}

/// Adapter for the authenticated development backend. Ownership is determined
/// server-side from the bearer session; no account ID is sent by the client.
class BackendProfileService implements ProfileService {
  BackendProfileService({BackendApiClient? apiClient})
    : _apiClient = apiClient ?? BackendApiClient();

  final BackendApiClient _apiClient;

  @override
  Future<SakhiMemberProfile> getMyProfile() async {
    try {
      return _parseProfile(await _apiClient.get('profile/me', authenticated: true));
    } on BackendApiException catch (error) {
      throw ProfileServiceException(error.message);
    }
  }

  @override
  Future<SakhiMemberProfile> updateMyProfile({
    required String displayName,
    required String? email,
    required String? bio,
    required String? city,
  }) async {
    try {
      final response = await _apiClient.patch(
        'profile/me',
        authenticated: true,
        body: <String, Object?>{
          'displayName': displayName.trim(),
          'email': _normalizeOptional(email),
          'bio': _normalizeOptional(bio),
          'city': _normalizeOptional(city),
        },
      );
      return _parseProfile(response);
    } on BackendApiException catch (error) {
      throw ProfileServiceException(error.message);
    }
  }

  String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  SakhiMemberProfile _parseProfile(Map<String, dynamic> response) {
    final raw = response['profile'];
    if (raw == null) {
      throw const ProfileServiceException(
        'No saved profile was found for this account. Complete registration first.',
      );
    }
    if (raw is! Map<String, dynamic>) {
      throw const ProfileServiceException(
        'Sakhi returned an invalid profile response. Please retry.',
      );
    }

    final displayName = raw['displayName'];
    if (displayName is! String || displayName.trim().isEmpty) {
      throw const ProfileServiceException(
        'Sakhi returned an invalid profile name. Please retry.',
      );
    }

    String? optionalString(String key) {
      final value = raw[key];
      if (value == null) return null;
      if (value is! String) {
        throw ProfileServiceException(
          'Sakhi returned an invalid $key field. Please retry.',
        );
      }
      return value;
    }

    final updatedAtValue = raw['updatedAt'];
    DateTime? updatedAt;
    if (updatedAtValue != null) {
      if (updatedAtValue is! String) {
        throw const ProfileServiceException(
          'Sakhi returned an invalid profile timestamp. Please retry.',
        );
      }
      updatedAt = DateTime.tryParse(updatedAtValue);
      if (updatedAt == null) {
        throw const ProfileServiceException(
          'Sakhi returned an invalid profile timestamp. Please retry.',
        );
      }
    }

    return SakhiMemberProfile(
      displayName: displayName,
      email: optionalString('email'),
      bio: optionalString('bio'),
      city: optionalString('city'),
      updatedAt: updatedAt,
    );
  }
}
