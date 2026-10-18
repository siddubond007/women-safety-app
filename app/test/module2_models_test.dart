import 'package:flutter_test/flutter_test.dart';

import '../lib/features/module2/module2_models.dart';

void main() {
  group('Module2Profile', () {
    test('parses the nested profile and account counts from the API response', () {
      final profile = Module2Profile.fromPayload(<String, dynamic>{
        'accountId': 'account-1',
        'phone': '••••••1234',
        'phoneVerified': true,
        'verificationStatus': 'VERIFIED',
        'profile': <String, dynamic>{
          'displayName': 'Sakhi Member',
          'dateOfBirth': '2002-06-12',
          'email': 'member@example.com',
          'profilePhotoRef': 'profile/account-1/avatar.webp',
          'bio': 'Learning together',
          'locationCity': 'Tirupati',
          'interests': <String>['Wellness', 'Women in Tech'],
        },
        'counts': <String, dynamic>{
          'posts': 4,
          'followers': 12,
          'following': 9,
          'saved': 2,
        },
      });

      expect(profile.accountId, 'account-1');
      expect(profile.displayName, 'Sakhi Member');
      expect(profile.phoneMasked, '••••••1234');
      expect(profile.phoneVerified, isTrue);
      expect(profile.verificationStatus, 'VERIFIED');
      expect(profile.dateOfBirth, '2002-06-12');
      expect(profile.email, 'member@example.com');
      expect(profile.profilePhotoRef, 'profile/account-1/avatar.webp');
      expect(profile.interests, <String>['Wellness', 'Women in Tech']);
      expect(profile.postsCount, 4);
      expect(profile.followersCount, 12);
      expect(profile.followingCount, 9);
      expect(profile.savedCount, 2);
    });

    test('uses safe defaults for incomplete API payloads', () {
      final profile = Module2Profile.fromPayload(<String, dynamic>{});

      expect(profile.displayName, isEmpty);
      expect(profile.phoneVerified, isFalse);
      expect(profile.interests, isEmpty);
      expect(profile.postsCount, 0);
      expect(profile.dateOfBirth, isNull);
    });
  });

  group('Community models', () {
    test('parses group membership state without assuming a member joined', () {
      final group = Module2Group.fromMap(<String, dynamic>{
        'id': 'group-1',
        'name': 'Women in Technology',
        'slug': 'women-in-tech',
        'visibility': 'PRIVATE',
        'creator': <String, dynamic>{'displayName': 'Group owner'},
        'memberCount': 8,
        'upcomingEventsCount': 2,
        'membershipStatus': 'PENDING',
        'membershipRole': 'MEMBER',
        'isOwner': false,
      });

      expect(group.name, 'Women in Technology');
      expect(group.visibility, 'PRIVATE');
      expect(group.membershipStatus, 'PENDING');
      expect(group.isOwner, isFalse);
      expect(group.memberCount, 8);
    });

    test('parses event time and nested group from API response', () {
      final event = Module2Event.fromMap(<String, dynamic>{
        'id': 'event-1',
        'title': 'Community meetup',
        'description': 'A member-led meetup',
        'locationCity': 'Tirupati',
        'startsAt': '2026-11-10T10:00:00.000Z',
        'endsAt': '2026-11-10T11:00:00.000Z',
        'group': <String, dynamic>{'id': 'group-1', 'name': 'Women in Technology'},
        'isRegistered': true,
        'registrationCount': 14,
      });

      expect(event.groupId, 'group-1');
      expect(event.groupName, 'Women in Technology');
      expect(event.startsAt, DateTime.parse('2026-11-10T10:00:00.000Z'));
      expect(event.isRegistered, isTrue);
      expect(event.registrationCount, 14);
    });

    test('parses viewer-specific feed interaction flags', () {
      final post = Module2Post.fromMap(<String, dynamic>{
        'id': 'post-1',
        'body': 'Welcome to Sakhi',
        'audience': 'VERIFIED_MEMBERS',
        'createdAt': '2026-10-18T00:00:00.000Z',
        'author': <String, dynamic>{
          'accountId': 'account-2',
          'displayName': 'Other member',
          'profilePhotoRef': null,
        },
        'likeCount': 7,
        'commentCount': 3,
        'isLikedByViewer': true,
        'isSavedByViewer': false,
        'isOwnPost': false,
      });

      expect(post.authorAccountId, 'account-2');
      expect(post.likeCount, 7);
      expect(post.commentCount, 3);
      expect(post.isLiked, isTrue);
      expect(post.isSaved, isFalse);
      expect(post.isOwnPost, isFalse);
    });
  });
}
