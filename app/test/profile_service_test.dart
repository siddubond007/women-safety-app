import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/features/auth/backend_api_client.dart';
import 'package:women_safety_app/features/profile/profile_service.dart';

class _FakeProfileApiClient extends BackendApiClient {
  _FakeProfileApiClient({
    required this.getResponse,
    required this.patchResponse,
  }) : super();

  final Map<String, dynamic> getResponse;
  final Map<String, dynamic> patchResponse;
  final getRequests = <(String, bool)>[];
  final patchRequests = <(String, bool, Map<String, Object?>)>[];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = false,
  }) async {
    getRequests.add((path, authenticated));
    return getResponse;
  }

  @override
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, Object?> body = const <String, Object?>{},
    bool authenticated = false,
  }) async {
    patchRequests.add((path, authenticated, body));
    return patchResponse;
  }
}

void main() {
  group('backend member profile service', () {
    test('loads the authenticated member profile', () async {
      final api = _FakeProfileApiClient(
        getResponse: const <String, dynamic>{
          'profile': <String, dynamic>{
            'displayName': 'Asha Rao',
            'email': 'asha@example.com',
            'bio': 'Community volunteer',
            'city': 'Hyderabad',
            'updatedAt': '2026-10-16T06:30:00.000Z',
          },
          'isDemo': true,
        },
        patchResponse: const <String, dynamic>{},
      );
      final service = BackendProfileService(apiClient: api);

      final profile = await service.getMyProfile();

      expect(profile.displayName, 'Asha Rao');
      expect(profile.email, 'asha@example.com');
      expect(profile.bio, 'Community volunteer');
      expect(profile.city, 'Hyderabad');
      expect(api.getRequests, [('profile/me', true)]);
    });

    test('rejects an account without a saved profile', () async {
      final api = _FakeProfileApiClient(
        getResponse: const <String, dynamic>{'profile': null},
        patchResponse: const <String, dynamic>{},
      );
      final service = BackendProfileService(apiClient: api);

      await expectLater(
        service.getMyProfile(),
        throwsA(
          isA<ProfileServiceException>().having(
            (error) => error.message,
            'message',
            contains('Complete registration first'),
          ),
        ),
      );
    });

    test('sends explicit nulls when optional fields are cleared', () async {
      final api = _FakeProfileApiClient(
        getResponse: const <String, dynamic>{},
        patchResponse: const <String, dynamic>{
          'profile': <String, dynamic>{
            'displayName': 'Asha Rao',
            'email': null,
            'bio': null,
            'city': null,
            'updatedAt': '2026-10-16T06:30:00.000Z',
          },
        },
      );
      final service = BackendProfileService(apiClient: api);

      final updated = await service.updateMyProfile(
        displayName: ' Asha Rao ',
        email: ' ',
        bio: '',
        city: '  ',
      );

      expect(updated.email, isNull);
      expect(updated.bio, isNull);
      expect(updated.city, isNull);
      expect(api.patchRequests, hasLength(1));
      final request = api.patchRequests.single;
      expect(request.$1, 'profile/me');
      expect(request.$2, isTrue);
      expect(request.$3, {
        'displayName': 'Asha Rao',
        'email': null,
        'bio': null,
        'city': null,
      });
      expect(request.$3.containsKey('accountId'), isFalse);
    });

    test('reports malformed server profile data without throwing a cast error', () async {
      final api = _FakeProfileApiClient(
        getResponse: const <String, dynamic>{
          'profile': <String, dynamic>{'displayName': 42},
        },
        patchResponse: const <String, dynamic>{},
      );
      final service = BackendProfileService(apiClient: api);

      await expectLater(
        service.getMyProfile(),
        throwsA(isA<ProfileServiceException>()),
      );
    });
  });
}
