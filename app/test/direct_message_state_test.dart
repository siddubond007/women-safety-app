import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
// The secure-storage platform interface is a transitive dependency of the
// package under test; importing it here lets widget tests install its adapter.
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/core/constants/mock_data.dart';
import 'package:women_safety_app/features/auth/backend_api_client.dart';
import 'package:women_safety_app/features/followers/screens/followers_following_screen.dart';

class _FakeBootstrapApi extends BackendApiClient {
  _FakeBootstrapApi(this.payload)
    : super(baseUrl: 'http://127.0.0.1:3001/api/v1');

  final Map<String, dynamic> payload;

  @override
  Future<String?> readAccessToken() async => 'authenticated-session-token';

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = false,
    Map<String, String>? headers,
  }) async {
    if (path != 'module2/bootstrap' || !authenticated) {
      throw StateError('Unexpected bootstrap request: $path');
    }
    return payload;
  }
}

class _FakeSessionApi extends BackendApiClient {
  _FakeSessionApi() : super(baseUrl: 'http://127.0.0.1:3001/api/v1');

  final Completer<Map<String, dynamic>> sessionsResponse =
      Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = false,
    Map<String, String>? headers,
  }) {
    if (!authenticated || path != 'module2/sessions') {
      throw StateError('Unexpected session request: $path');
    }
    return sessionsResponse.future;
  }
}

class _FakeDirectMessageApi extends BackendApiClient {
  _FakeDirectMessageApi() : super(baseUrl: 'http://127.0.0.1:3001/api/v1');

  String? token = 'authenticated-session-token';
  bool failGet = false;
  Completer<Map<String, dynamic>>? pendingGetResponse;
  Completer<void>? getStarted;
  Completer<Map<String, dynamic>>? pendingPostResponse;
  Completer<void>? postStarted;
  Map<String, dynamic> getResponse = const <String, dynamic>{
    'messages': <Map<String, dynamic>>[],
  };
  Map<String, dynamic> postResponse = const <String, dynamic>{
    'sent': true,
    'message': <String, dynamic>{'id': 'message-1', 'message': 'Hello'},
  };
  Map<String, Object?>? lastPostBody;

  @override
  Future<String?> readAccessToken() async => token;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = false,
    Map<String, String>? headers,
  }) async {
    if (!authenticated || !path.startsWith('module2/messages?peerId=')) {
      throw StateError('Unexpected direct-message GET request: $path');
    }
    if (failGet) throw StateError('simulated network failure');
    final pending = pendingGetResponse;
    if (pending != null) {
      if (getStarted?.isCompleted == false) getStarted!.complete();
      return pending.future;
    }
    return getResponse;
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?> body = const <String, Object?>{},
    bool authenticated = false,
    Map<String, String>? headers,
  }) async {
    if (!authenticated || path != 'module2/messages') {
      throw StateError('Unexpected direct-message POST request: $path');
    }
    lastPostBody = body;
    final pending = pendingPostResponse;
    if (pending != null) {
      if (postStarted?.isCompleted == false) postStarted!.complete();
      return pending.future;
    }
    return postResponse;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
    <String, String>{},
  );

  test(
    'a failed history request never falls back to another response cache',
    () async {
      final api = _FakeDirectMessageApi();
      final state = SakhiPrototypeState.instance;
      state.configureApiClient(api);

      api.getResponse = {
        'messages': [
          <String, dynamic>{
            'id': 'dm-1',
            'message': 'Account A private message',
          },
        ],
      };
      final first = await state.fetchDirectMessages('peer-123');
      expect(first, hasLength(1));
      expect(first!.single['message'], 'Account A private message');

      api.failGet = true;
      final failed = await state.fetchDirectMessages('peer-123');

      expect(failed, isNull);
    },
  );

  test(
    'a late history response is discarded after account state is cleared',
    () async {
      final api = _FakeDirectMessageApi()
        ..pendingGetResponse = Completer<Map<String, dynamic>>()
        ..getStarted = Completer<void>();
      final state = SakhiPrototypeState.instance;
      state.configureApiClient(api);

      final pendingLoad = state.fetchDirectMessages('peer-old-account');
      await api.getStarted!.future;
      await state.clearAccountScopedData();
      api.pendingGetResponse!.complete({
        'messages': [
          <String, dynamic>{'id': 'old-message', 'body': 'Old account content'},
        ],
      });

      expect(await pendingLoad, isNull);
    },
  );

  test(
    'a late send response is discarded after account state is cleared',
    () async {
      final api = _FakeDirectMessageApi()
        ..pendingPostResponse = Completer<Map<String, dynamic>>()
        ..postStarted = Completer<void>();
      final state = SakhiPrototypeState.instance;
      state.configureApiClient(api);

      final pendingSend = state.sendDirectMessage(
        recipientId: 'peer-old-account',
        recipientHandle: '@peer',
        recipientName: 'Peer',
        message: 'Message from previous account',
      );
      await api.postStarted!.future;
      await state.clearAccountScopedData();
      api.pendingPostResponse!.complete({
        'sent': true,
        'message': <String, dynamic>{'id': 'old-message', 'body': 'Sent'},
      });

      expect(await pendingSend, isNull);
    },
  );

  test('an empty server response is distinct from a failed request', () async {
    final api = _FakeDirectMessageApi();
    final state = SakhiPrototypeState.instance;
    state.configureApiClient(api);
    api.getResponse = const <String, dynamic>{'messages': <dynamic>[]};

    final result = await state.fetchDirectMessages('peer-456');

    expect(result, isEmpty);
  });

  test(
    'a message is sent through the authenticated backend without local caching',
    () async {
      final api = _FakeDirectMessageApi();
      final state = SakhiPrototypeState.instance;
      state.configureApiClient(api);

      final result = await state.sendDirectMessage(
        recipientId: 'peer-123',
        recipientHandle: '@peer',
        recipientName: 'Peer',
        message: '  Hello Sakhi  ',
      );

      expect(result, {'id': 'message-1', 'message': 'Hello'});
      expect(api.lastPostBody?['message'], 'Hello Sakhi');
      expect(api.lastPostBody?['recipientId'], 'peer-123');
    },
  );

  test(
    'message history fails closed when no authenticated session exists',
    () async {
      final api = _FakeDirectMessageApi()..token = null;
      SakhiPrototypeState.instance.configureApiClient(api);

      expect(
        await SakhiPrototypeState.instance.fetchDirectMessages('peer-789'),
        isNull,
      );
    },
  );

  testWidgets(
    'conversation clearly discloses that messages are not end-to-end encrypted',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _FakeDirectMessageApi();
      SakhiPrototypeState.instance.configureApiClient(api);
      final member = FollowerUserModel(
        id: 'peer-account-123',
        name: 'Peer Sakhi',
        username: '@peer',
        avatarAsset: '',
        isFollowing: true,
        isVerified: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showSakhiDirectMessageSheet(context, member),
                  child: const Text('Open conversation'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open conversation'));
      await tester.pumpAndSettle();

      expect(find.textContaining('not end-to-end encrypted'), findsOneWidget);
      expect(find.textContaining("stored on Sakhi's server"), findsOneWidget);
      expect(
        find.textContaining('Do not send passwords, OTPs'),
        findsOneWidget,
      );
      expect(find.text('Encrypted Sakhi Chat'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an open conversation clears its messages and composer when the session changes',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _FakeDirectMessageApi()
        ..getResponse = {
          'messages': [
            <String, dynamic>{
              'id': 'old-account-message',
              'body': 'Account A private conversation message',
              'isOwnMessage': false,
            },
          ],
        };
      final state = SakhiPrototypeState.instance;
      state.configureApiClient(api);
      final member = FollowerUserModel(
        id: 'peer-account-123',
        name: 'Peer Sakhi',
        username: '@peer',
        avatarAsset: '',
        isFollowing: true,
        isVerified: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showSakhiDirectMessageSheet(context, member),
                  child: const Text('Open conversation'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open conversation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(
        find.text('Account A private conversation message'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsOneWidget);

      state.setLocalCacheDeleteOverrideForTesting(() {});
      try {
        await state.clearAccountScopedData();
      } finally {
        state.setLocalCacheDeleteOverrideForTesting(null);
      }
      await tester.pump();

      expect(find.text('Account A private conversation message'), findsNothing);
      expect(
        find.textContaining(
          'conversation was cleared because your Sakhi session changed',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Messaging is disabled until you sign in again.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'a late session response cannot repopulate state after logout cleanup',
    () async {
      final state = SakhiPrototypeState.instance;
      final api = _FakeSessionApi();
      state.configureApiClient(api);

      final pendingLoad = state.loadLoginSessions();
      expect(state.isLoadingLoginSessions, isTrue);

      await state.clearAccountScopedData();
      api.sessionsResponse.complete({
        'sessions': [
          <String, dynamic>{
            'id': 'old-account-session',
            'deviceName': 'Old account device',
            'isActive': true,
          },
        ],
      });

      expect(await pendingLoad, isFalse);
      expect(state.loginSessions, isEmpty);
      expect(state.isLoadingLoginSessions, isFalse);
      expect(state.loginSessionsError, isNull);
    },
  );

  test(
    'logout cleanup clears account-scoped profile and settings state',
    () async {
      final state = SakhiPrototypeState.instance;
      state.currentUser
        ..accountId = 'account-a'
        ..displayName = 'Private Account A'
        ..username = '@private-a';
      state.followers.add(
        FollowerUserModel(
          id: 'follower-a',
          name: 'Follower A',
          username: '@follower-a',
          avatarAsset: '',
          isFollowing: false,
        ),
      );
      state.groups.add(
        const CommunityGroupModel(
          id: 'group-a',
          name: 'Private Group A',
          description: 'Private group',
          category: 'community',
          membersCount: 2,
          newPostsToday: 0,
        ),
      );
      state.loginSessions.add({'id': 'session-a'});
      state.cachedBusinesses
        ..clear()
        ..add({'id': 'business-a', 'isSaved': true});
      state.myBusinessPages = <Map<String, dynamic>>[
        {'id': 'business-a', 'isOwnBusiness': true},
      ];
      state.myBusinessPage = {'id': 'business-a', 'isOwnBusiness': true};
      state.cachedBusinessEnquiries = <Map<String, dynamic>>[
        {'id': 'enquiry-a', 'message': 'Private enquiry from account A'},
      ];
      state.privacySettings.first.selectedValue = 'Followers Only';
      state.joinedCircleNames.add('Private Group A');

      await state.clearAccountScopedData();

      expect(state.currentUser.accountId, isEmpty);
      expect(state.currentUser.displayName, 'Sakhi Member');
      expect(state.followers, isEmpty);
      expect(state.groups, isEmpty);
      expect(state.loginSessions, isEmpty);
      expect(state.cachedBusinesses, isEmpty);
      expect(state.myBusinessPages, isEmpty);
      expect(state.myBusinessPage, isNull);
      expect(state.cachedBusinessEnquiries, isEmpty);
      expect(state.joinedCircleNames, isEmpty);
      expect(state.privacySettings.first.selectedValue, 'All Verified Members');
      expect(state.isBackendSynced, isFalse);
    },
  );

  test(
    'bootstrap account switch discards data left by the previous account',
    () async {
      final state = SakhiPrototypeState.instance;
      state.currentUser.accountId = 'account-a';
      state.followers.add(
        FollowerUserModel(
          id: 'follower-a',
          name: 'Follower A',
          username: '@follower-a',
          avatarAsset: '',
          isFollowing: false,
        ),
      );
      state.groups.add(
        const CommunityGroupModel(
          id: 'group-a',
          name: 'Private Group A',
          description: 'Private group',
          category: 'community',
          membersCount: 2,
          newPostsToday: 0,
        ),
      );
      state.cachedBusinesses
        ..clear()
        ..add({'id': 'business-a', 'isSaved': true});
      state.myBusinessPages = <Map<String, dynamic>>[
        {'id': 'business-a', 'isOwnBusiness': true},
      ];
      state.myBusinessPage = {'id': 'business-a', 'isOwnBusiness': true};
      state.cachedBusinessEnquiries = <Map<String, dynamic>>[
        {'id': 'enquiry-a', 'message': 'Private enquiry from account A'},
      ];
      state.privacySettings.first.selectedValue = 'Followers Only';
      state.configureApiClient(
        _FakeBootstrapApi({
          'currentUser': {
            'accountId': 'account-b',
            'displayName': 'Account B',
            'username': '@account-b',
          },
        }),
      );

      await state.syncFromBackend();

      expect(state.currentUser.accountId, 'account-b');
      expect(state.currentUser.displayName, 'Account B');
      expect(state.followers, isEmpty);
      expect(state.groups, isEmpty);
      expect(state.cachedBusinesses, isEmpty);
      expect(state.myBusinessPages, isEmpty);
      expect(state.myBusinessPage, isNull);
      expect(state.cachedBusinessEnquiries, isEmpty);
      expect(state.privacySettings.first.selectedValue, 'All Verified Members');
      expect(state.isBackendSynced, isTrue);
    },
  );
}
