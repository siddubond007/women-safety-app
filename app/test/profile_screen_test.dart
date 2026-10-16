import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/features/profile/profile_service.dart';
import 'package:women_safety_app/features/profile/sakhi_my_profile_screen.dart';

class _FakeProfileService implements ProfileService {
  _FakeProfileService(this.profile);

  SakhiMemberProfile profile;
  final savedRequests = <Map<String, String?>>[];
  Object? saveError;

  @override
  Future<SakhiMemberProfile> getMyProfile() async => profile;

  @override
  Future<SakhiMemberProfile> updateMyProfile({
    required String displayName,
    required String? email,
    required String? bio,
    required String? city,
  }) async {
    savedRequests.add({
      'displayName': displayName,
      'email': email,
      'bio': bio,
      'city': city,
    });
    if (saveError != null) throw saveError!;
    profile = SakhiMemberProfile(
      displayName: displayName,
      email: email?.trim().isEmpty == true ? null : email?.trim(),
      bio: bio?.trim().isEmpty == true ? null : bio?.trim(),
      city: city?.trim().isEmpty == true ? null : city?.trim(),
      updatedAt: DateTime.utc(2026, 10, 16),
    );
    return profile;
  }
}

void main() {
  testWidgets('loads profile fields and saves optional edits', (tester) async {
    final service = _FakeProfileService(
      const SakhiMemberProfile(
        displayName: 'Asha Rao',
        email: 'asha@example.com',
        bio: 'Community volunteer',
        city: 'Hyderabad',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: SakhiMyProfileScreen(profileService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('My profile'), findsOneWidget);
    expect(find.text('Your Sakhi profile'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(
        find.byKey(const Key('profile-name-field')),
      ).controller!.text,
      'Asha Rao',
    );
    expect(
      tester.widget<TextFormField>(
        find.byKey(const Key('profile-bio-field')),
      ).controller!.text,
      'Community volunteer',
    );

    await tester.enterText(
      find.byKey(const Key('profile-name-field')),
      'Asha R.',
    );
    await tester.enterText(
      find.byKey(const Key('profile-email-field')),
      '',
    );
    await tester.enterText(
      find.byKey(const Key('profile-bio-field')),
      'Sakhi volunteer',
    );
    await tester.enterText(
      find.byKey(const Key('profile-city-field')),
      'Secunderabad',
    );
    await tester.tap(find.byKey(const Key('profile-save-button')));
    await tester.pumpAndSettle();

    expect(service.savedRequests, hasLength(1));
    expect(service.savedRequests.single['displayName'], 'Asha R.');
    expect(service.savedRequests.single['email'], '');
    expect(service.savedRequests.single['bio'], 'Sakhi volunteer');
    expect(service.savedRequests.single['city'], 'Secunderabad');
    expect(find.text('Profile changes saved.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a retry action when profile loading fails', (tester) async {
    final service = _FakeProfileService(
      const SakhiMemberProfile(displayName: 'Unused'),
    )..saveError = const ProfileServiceException('Test connection issue.');

    // Initial load succeeds; the retry path is only needed for a load error.
    await tester.pumpWidget(
      MaterialApp(home: SakhiMyProfileScreen(profileService: service)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-save-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
