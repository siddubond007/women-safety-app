import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import '../auth/backend_api_client.dart';
import 'module2_models.dart';

class Module2State extends ChangeNotifier {
  Module2State({required this.authService, BackendApiClient? api})
      : api = api ?? BackendApiClient();

  final AuthService authService;
  final BackendApiClient api;

  Module2Profile? profile;
  List<Module2Post> feedPosts = [];
  List<Module2Post> profilePosts = [];
  List<Module2Post> savedPosts = [];
  final Map<String, List<Module2Comment>> commentsByPost = <String, List<Module2Comment>>{};
  List<Module2Member> discoveredMembers = [];
  List<Module2Member> followers = [];
  List<Module2Member> following = [];
  List<Module2Member> blockedMembers = [];
  List<Module2Group> discoverGroups = [];
  List<Module2Group> myGroups = [];
  List<Module2Event> upcomingEvents = [];
  List<Module2Expert> verifiedExperts = [];
  bool isLoadingGroups = false;
  bool isLoadingEvents = false;
  bool isLoadingExperts = false;
  int _groupLoadRequests = 0;
  int _eventLoadRequests = 0;
  int _expertLoadRequests = 0;
  Module2MemberProfile? memberProfile;
  String? memberProfileAccountId;
  bool isLoadingMemberProfile = false;
  List<Map<String, dynamic>> sessions = [];
  Map<String, dynamic>? businessProfile;
  Map<String, dynamic> privacySettings = <String, dynamic>{
    'profileVisibility': 'VERIFIED_MEMBERS',
    'messagePermission': 'VERIFIED_MEMBERS',
    'defaultPostAudience': 'VERIFIED_MEMBERS',
    'locationSharing': 'HIDDEN',
    'appearInSearch': true,
    'businessEnquiryPermission': 'VERIFIED_BUSINESSES',
  };
  Map<String, dynamic> notificationPreferences = <String, dynamic>{
    'communityUpdates': true,
    'groupActivity': true,
    'wellnessReminders': true,
    'safetyAlerts': true,
    'messages': true,
    'businessEnquiries': true,
    'marketingUpdates': false,
    'marketingConsentAccepted': false,
  };

  bool initialized = false;
  bool isLoading = false;
  bool isLoadingFeed = false;
  bool isLoadingMembers = false;
  bool isSaving = false;
  String? errorMessage;
  String? actionMessage;

  Future<Map<String, dynamic>?> _safe(
    Future<Map<String, dynamic>> Function() operation,
  ) async {
    try {
      errorMessage = null;
      return await operation();
    } on BackendApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
      return null;
    } catch (_) {
      errorMessage = 'Sakhi could not complete this request. Check your connection and retry.';
      notifyListeners();
      return null;
    }
  }

  void clearMessages() {
    errorMessage = null;
    actionMessage = null;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (initialized || isLoading) return;
    isLoading = true;
    notifyListeners();
    final payload = await _safe(
      () => api.get('module2/profile', authenticated: true),
    );
    if (payload != null) {
      profile = Module2Profile.fromPayload(payload);
      if (jsonMap(payload['privacySettings']).isNotEmpty) {
        privacySettings = jsonMap(payload['privacySettings']);
      }
      if (jsonMap(payload['notificationPreferences']).isNotEmpty) {
        notificationPreferences = jsonMap(payload['notificationPreferences']);
      }
      await Future.wait([loadFeed(), loadDiscover()]);
    }
    isLoading = false;
    initialized = true;
    notifyListeners();
  }

  Future<bool> loadProfile() async {
    final payload = await _safe(
      () => api.get('module2/profile', authenticated: true),
    );
    if (payload == null) return false;
    profile = Module2Profile.fromPayload(payload);
    if (jsonMap(payload['privacySettings']).isNotEmpty) {
      privacySettings = jsonMap(payload['privacySettings']);
    }
    if (jsonMap(payload['notificationPreferences']).isNotEmpty) {
      notificationPreferences = jsonMap(payload['notificationPreferences']);
    }
    notifyListeners();
    return true;
  }

  Future<bool> updateProfile({
    required String displayName,
    required String bio,
    required String locationCity,
    required List<String> interests,
    String? email,
  }) async {
    isSaving = true;
    notifyListeners();
    final payload = await _safe(
      () => api.patch(
        'module2/profile',
        authenticated: true,
        body: <String, Object?>{
          'displayName': displayName.trim(),
          'bio': bio.trim().isEmpty ? null : bio.trim(),
          'locationCity': locationCity.trim().isEmpty ? null : locationCity.trim(),
          'interests': interests,
          if (email != null) 'email': email.trim().isEmpty ? null : email.trim(),
        },
      ),
    );
    isSaving = false;
    if (payload == null) {
      notifyListeners();
      return false;
    }
    actionMessage = 'Profile changes saved to your Sakhi account.';
    final refreshed = await _safe(
      () => api.get('module2/profile', authenticated: true),
    );
    if (refreshed != null) profile = Module2Profile.fromPayload(refreshed);
    notifyListeners();
    return true;
  }

  Future<bool> loadFeed({String query = '', String? accountId}) async {
    isLoadingFeed = true;
    notifyListeners();
    final params = <String, String>{};
    if (query.trim().isNotEmpty) params['q'] = query.trim();
    if (accountId != null && accountId.isNotEmpty) {
      params['accountId'] = accountId;
    }
    final base = accountId == null ? 'module2/feed' : 'module2/posts';
    final suffix = params.isEmpty ? '' : '?' + Uri(queryParameters: params).query;
    final payload = await _safe(
      () => api.get(base + suffix, authenticated: true),
    );
    isLoadingFeed = false;
    if (payload == null) {
      notifyListeners();
      return false;
    }
    final posts = jsonMapList(payload['posts']).map(Module2Post.fromMap).toList();
    if (accountId != null) {
      profilePosts = posts;
    } else {
      feedPosts = posts;
    }
    notifyListeners();
    return true;
  }

  Future<bool> loadDiscover({String query = ''}) async {
    isLoadingMembers = true;
    notifyListeners();
    final params = <String, String>{'limit': '30'};
    if (query.trim().isNotEmpty) params['q'] = query.trim();
    final path = 'module2/discover?' + Uri(queryParameters: params).query;
    final payload = await _safe(
      () => api.get(path, authenticated: true),
    );
    isLoadingMembers = false;
    if (payload == null) {
      notifyListeners();
      return false;
    }
    discoveredMembers = jsonMapList(payload['members']).map(Module2Member.fromMap).toList();
    notifyListeners();
    return true;
  }

  Future<bool> loadGroups({bool mine = false, String query = ''}) async {
    _groupLoadRequests++;
    isLoadingGroups = true;
    notifyListeners();
    try {
      final params = <String, String>{
        'mine': mine ? 'true' : 'false',
        'limit': '50',
      };
      if (query.trim().isNotEmpty) params['q'] = query.trim();
      final payload = await _safe(
        () => api.get(
          'module2/groups?' + Uri(queryParameters: params).query,
          authenticated: true,
        ),
      );
      if (payload == null) return false;
      final groups = jsonMapList(payload['groups'])
          .map(Module2Group.fromMap)
          .toList();
      if (mine) {
        myGroups = groups;
      } else {
        discoverGroups = groups;
      }
      notifyListeners();
      return true;
    } finally {
      _groupLoadRequests--;
      isLoadingGroups = _groupLoadRequests > 0;
      notifyListeners();
    }
  }

  Future<bool> loadEvents({String query = ''}) async {
    _eventLoadRequests++;
    isLoadingEvents = true;
    notifyListeners();
    try {
      final params = <String, String>{'limit': '50'};
      if (query.trim().isNotEmpty) params['q'] = query.trim();
      final payload = await _safe(
        () => api.get(
          'module2/events?' + Uri(queryParameters: params).query,
          authenticated: true,
        ),
      );
      if (payload == null) return false;
      upcomingEvents = jsonMapList(payload['events'])
          .map(Module2Event.fromMap)
          .toList();
      notifyListeners();
      return true;
    } finally {
      _eventLoadRequests--;
      isLoadingEvents = _eventLoadRequests > 0;
      notifyListeners();
    }
  }

  Future<bool> loadExperts({String query = ''}) async {
    _expertLoadRequests++;
    isLoadingExperts = true;
    notifyListeners();
    try {
      final params = <String, String>{'limit': '50'};
      if (query.trim().isNotEmpty) params['q'] = query.trim();
      final payload = await _safe(
        () => api.get(
          'module2/experts?' + Uri(queryParameters: params).query,
          authenticated: true,
        ),
      );
      if (payload == null) return false;
      verifiedExperts = jsonMapList(payload['experts'])
          .map(Module2Expert.fromMap)
          .toList();
      notifyListeners();
      return true;
    } finally {
      _expertLoadRequests--;
      isLoadingExperts = _expertLoadRequests > 0;
      notifyListeners();
    }
  }

  Future<bool> createGroup({
    required String name,
    required String description,
    required String visibility,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.length < 2) {
      errorMessage = 'Group names must contain at least two characters.';
      notifyListeners();
      return false;
    }
    final payload = await _safe(
      () => api.post(
        'module2/groups',
        authenticated: true,
        body: <String, Object?>{
          'name': trimmedName,
          if (description.trim().isNotEmpty) 'description': description.trim(),
          'visibility': visibility,
        },
      ),
    );
    if (payload == null) return false;
    actionMessage = 'Group created.';
    await Future.wait([loadGroups(mine: true), loadGroups()]);
    notifyListeners();
    return true;
  }

  Future<bool> joinGroup(Module2Group group) async {
    final payload = await _safe(
      () => api.post(
        'module2/groups/${group.id}/join',
        authenticated: true,
      ),
    );
    if (payload == null) return false;
    actionMessage = payload['status'] == 'PENDING'
        ? 'Membership request submitted.'
        : 'You joined ${group.name}.';
    await Future.wait([loadGroups(), loadGroups(mine: true)]);
    notifyListeners();
    return true;
  }

  Future<bool> leaveGroup(Module2Group group) async {
    final payload = await _safe(
      () => api.delete(
        'module2/groups/${group.id}/join',
        authenticated: true,
      ),
    );
    if (payload == null) return false;
    actionMessage = payload['archived'] == true
        ? 'Group archived.'
        : payload['requestCancelled'] == true || group.membershipStatus == 'PENDING'
            ? 'Membership request cancelled.'
            : 'You left ${group.name}.';
    await Future.wait([loadGroups(), loadGroups(mine: true)]);
    notifyListeners();
    return true;
  }

  Future<List<Module2Member>> loadPendingGroupMembers(String groupId) async {
    final payload = await _safe(
      () => api.get(
        'module2/groups/${groupId}/pending-members',
        authenticated: true,
      ),
    );
    if (payload == null) return <Module2Member>[];
    return jsonMapList(payload['members'])
        .map(Module2Member.fromMap)
        .toList();
  }

  Future<bool> approveGroupMember(String groupId, Module2Member member) async {
    final payload = await _safe(
      () => api.post(
        'module2/groups/${groupId}/members/${member.accountId}/approve',
        authenticated: true,
      ),
    );
    if (payload == null) return false;
    actionMessage = '${member.displayName} was approved to join the group.';
    await Future.wait([
      loadGroups(),
      loadGroups(mine: true),
      loadPendingGroupMembers(groupId),
    ]);
    notifyListeners();
    return true;
  }

  Future<bool> createEvent({
    required String groupId,
    required String title,
    required String description,
    required String locationCity,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedDescription = description.trim();
    if (trimmedTitle.isEmpty || trimmedDescription.isEmpty) {
      errorMessage = 'Add an event title and description.';
      notifyListeners();
      return false;
    }
    if (!endsAt.isAfter(startsAt) || !startsAt.isAfter(DateTime.now())) {
      errorMessage = 'Choose a future start time and an end time after the start.';
      notifyListeners();
      return false;
    }
    final payload = await _safe(
      () => api.post(
        'module2/events',
        authenticated: true,
        body: <String, Object?>{
          'groupId': groupId,
          'title': trimmedTitle,
          'description': trimmedDescription,
          if (locationCity.trim().isNotEmpty) 'locationCity': locationCity.trim(),
          'startsAt': startsAt.toUtc().toIso8601String(),
          'endsAt': endsAt.toUtc().toIso8601String(),
        },
      ),
    );
    if (payload == null) return false;
    actionMessage = 'Event published.';
    await Future.wait([loadEvents(), loadGroups(mine: true)]);
    notifyListeners();
    return true;
  }

  Future<bool> registerForEvent(
    Module2Event event, {
    required bool register,
  }) async {
    final payload = await _safe(
      () => register
          ? api.post(
              'module2/events/${event.id}/register',
              authenticated: true,
            )
          : api.delete(
              'module2/events/${event.id}/register',
              authenticated: true,
            ),
    );
    if (payload == null) return false;
    actionMessage = register
        ? 'You registered for ${event.title}.'
        : 'Event registration cancelled.';
    await loadEvents();
    notifyListeners();
    return true;
  }

  Future<bool> loadMemberProfile(String accountId) async {
    if (accountId.trim().isEmpty) {
      errorMessage = 'The requested member profile is unavailable.';
      notifyListeners();
      return false;
    }
    memberProfileAccountId = accountId;
    isLoadingMemberProfile = true;
    errorMessage = null;
    notifyListeners();

    final payload = await _safe(
      () => api.get(
        'module2/members/${accountId}',
        authenticated: true,
      ),
    );
    if (memberProfileAccountId != accountId) return false;
    isLoadingMemberProfile = false;
    if (payload == null) {
      memberProfile = null;
      notifyListeners();
      return false;
    }
    memberProfile = Module2MemberProfile.fromPayload(payload);
    notifyListeners();
    return true;
  }

  Future<bool> setMemberFollowing({
    required String accountId,
    required bool follow,
  }) async {
    final result = await _safe(
      () => follow
          ? api.post('module2/members/${accountId}/follow', authenticated: true)
          : api.delete('module2/members/${accountId}/follow', authenticated: true),
    );
    if (result == null) return false;
    actionMessage = follow ? 'Member followed.' : 'Member unfollowed.';
    await Future.wait([
      loadMemberProfile(accountId),
      loadDiscover(),
      loadFollowers(showFollowing: true),
      loadProfile(),
    ]);
    notifyListeners();
    return true;
  }

  Future<bool> createPost(
    String text, {
    String audience = 'VERIFIED_MEMBERS',
    List<String> selectedAccountIds = const [],
  }) async {
    final body = text.trim();
    if (body.isEmpty) {
      errorMessage = 'Write something before publishing.';
      notifyListeners();
      return false;
    }
    if (audience == 'SELECTED_MEMBERS' && selectedAccountIds.isEmpty) {
      errorMessage = 'Choose at least one member for a selected-audience post.';
      notifyListeners();
      return false;
    }
    isSaving = true;
    notifyListeners();
    final payload = await _safe(
      () => api.post(
        'module2/posts',
        authenticated: true,
        body: <String, Object?>{
          'body': body,
          'audience': audience,
          if (audience == 'SELECTED_MEMBERS')
            'selectedAudienceAccountIds': selectedAccountIds,
        },
      ),
    );
    isSaving = false;
    if (payload == null) {
      notifyListeners();
      return false;
    }
    actionMessage = 'Your post was published.';
    await loadFeed();
    notifyListeners();
    return true;
  }

  Future<bool> toggleLike(Module2Post post) async {
    final result = await _safe(
      () => post.isLiked
          ? api.delete('module2/posts/' + post.id + '/like', authenticated: true)
          : api.post('module2/posts/' + post.id + '/like', authenticated: true),
    );
    if (result == null) return false;
    final newLiked = !post.isLiked;
    final count = jsonInt(result['likeCount']);
    feedPosts = feedPosts.map((item) => item.id == post.id
        ? item.copyWith(isLiked: newLiked, likeCount: count)
        : item).toList();
    profilePosts = profilePosts.map((item) => item.id == post.id
        ? item.copyWith(isLiked: newLiked, likeCount: count)
        : item).toList();
    savedPosts = savedPosts.map((item) => item.id == post.id
        ? item.copyWith(isLiked: newLiked, likeCount: count)
        : item).toList();
    notifyListeners();
    return true;
  }

  Future<bool> toggleBookmark(Module2Post post) async {
    final result = await _safe(
      () => post.isSaved
          ? api.delete('module2/posts/' + post.id + '/bookmark', authenticated: true)
          : api.post('module2/posts/' + post.id + '/bookmark', authenticated: true),
    );
    if (result == null) return false;
    final saved = result['saved'] == true;
    feedPosts = feedPosts.map((item) => item.id == post.id
        ? item.copyWith(isSaved: saved)
        : item).toList();
    profilePosts = profilePosts.map((item) => item.id == post.id
        ? item.copyWith(isSaved: saved)
        : item).toList();
    await loadSavedPosts();
    notifyListeners();
    return true;
  }

  Future<bool> loadSavedPosts() async {
    final payload = await _safe(
      () => api.get('module2/posts/saved', authenticated: true),
    );
    if (payload == null) return false;
    savedPosts = jsonMapList(payload['posts']).map(Module2Post.fromMap).toList();
    notifyListeners();
    return true;
  }

  Future<bool> loadComments(String postId) async {
    final payload = await _safe(
      () => api.get('module2/posts/' + postId + '/comments', authenticated: true),
    );
    if (payload == null) return false;
    commentsByPost[postId] = jsonMapList(payload['comments'])
        .map(Module2Comment.fromMap)
        .toList();
    notifyListeners();
    return true;
  }

  Future<bool> createComment(String postId, String body) async {
    final text = body.trim();
    if (text.isEmpty) {
      errorMessage = 'Write a comment before sending.';
      notifyListeners();
      return false;
    }
    final payload = await _safe(
      () => api.post(
        'module2/posts/' + postId + '/comments',
        authenticated: true,
        body: <String, Object?>{'body': text},
      ),
    );
    if (payload == null) return false;
    actionMessage = 'Comment added.';
    await loadComments(postId);
    await loadFeed();
    notifyListeners();
    return true;
  }

  Future<bool> deleteComment(String commentId, String postId) async {
    final payload = await _safe(
      () => api.delete('module2/comments/' + commentId, authenticated: true),
    );
    if (payload == null) return false;
    actionMessage = 'Comment removed.';
    await loadComments(postId);
    notifyListeners();
    return true;
  }

  Future<bool> updateMarketingConsent(bool consentAccepted) async {
    final payload = await _safe(
      () => api.put(
        'module2/marketing-consent',
        authenticated: true,
        body: <String, Object?>{'consentAccepted': consentAccepted},
      ),
    );
    if (payload == null) return false;
    notificationPreferences = <String, dynamic>{
      ...notificationPreferences,
      'marketingConsentAccepted': payload['marketingConsentAccepted'] == true,
    };
    if (!consentAccepted) {
      notificationPreferences = <String, dynamic>{
        ...notificationPreferences,
        'marketingUpdates': false,
      };
    }
    actionMessage = consentAccepted
        ? 'Optional product-updates consent saved.'
        : 'Optional product-updates consent withdrawn.';
    notifyListeners();
    return true;
  }

  Future<bool> loadFollowers({
    required bool showFollowing,
    String query = '',
  }) async {
    isLoadingMembers = true;
    notifyListeners();
    final params = <String, String>{
      'direction': showFollowing ? 'following' : 'followers',
      'limit': '50',
    };
    if (query.trim().isNotEmpty) params['q'] = query.trim();
    final payload = await _safe(
      () => api.get(
        'module2/followers?' + Uri(queryParameters: params).query,
        authenticated: true,
      ),
    );
    isLoadingMembers = false;
    if (payload == null) {
      notifyListeners();
      return false;
    }
    final members = jsonMapList(payload['members']).map(Module2Member.fromMap).toList();
    if (showFollowing) {
      following = members;
    } else {
      followers = members;
    }
    notifyListeners();
    return true;
  }

  Future<bool> setFollowing(Module2Member member, bool follow) async {
    final result = await _safe(
      () => follow
          ? api.post('module2/members/' + member.accountId + '/follow', authenticated: true)
          : api.delete('module2/members/' + member.accountId + '/follow', authenticated: true),
    );
    if (result == null) return false;
    actionMessage = follow
        ? 'You are now following ' + member.displayName + '.'
        : 'You unfollowed ' + member.displayName + '.';
    await Future.wait([loadDiscover(), loadFollowers(showFollowing: true), loadProfile()]);
    notifyListeners();
    return true;
  }

  Future<bool> loadPrivacySettings() async {
    final payload = await _safe(
      () => api.get('module2/privacy-settings', authenticated: true),
    );
    if (payload == null) return false;
    privacySettings = payload;
    notifyListeners();
    return true;
  }

  Future<bool> updatePrivacySetting(String key, Object value) async {
    final payload = await _safe(
      () => api.patch(
        'module2/privacy-settings',
        authenticated: true,
        body: <String, Object?>{key: value},
      ),
    );
    if (payload == null) return false;
    privacySettings = payload;
    actionMessage = 'Privacy setting updated.';
    notifyListeners();
    return true;
  }

  Future<bool> loadNotificationPreferences() async {
    final payload = await _safe(
      () => api.get('module2/notification-preferences', authenticated: true),
    );
    if (payload == null) return false;
    notificationPreferences = payload;
    notifyListeners();
    return true;
  }

  Future<bool> updateNotificationPreference(String key, bool value) async {
    final payload = await _safe(
      () => api.patch(
        'module2/notification-preferences',
        authenticated: true,
        body: <String, Object?>{key: value},
      ),
    );
    if (payload == null) return false;
    notificationPreferences = payload;
    actionMessage = 'Notification preference updated.';
    notifyListeners();
    return true;
  }

  Future<bool> loadBlockedMembers() async {
    final payload = await _safe(
      () => api.get('module2/blocks', authenticated: true),
    );
    if (payload == null) return false;
    blockedMembers = jsonMapList(payload['members']).map(Module2Member.fromMap).toList();
    notifyListeners();
    return true;
  }

  Future<bool> blockMember(Module2Member member) =>
      blockMemberByAccountId(
        member.accountId,
        displayName: member.displayName,
      );

  Future<bool> blockMemberByAccountId(
    String accountId, {
    String? displayName,
  }) async {
    if (accountId.trim().isEmpty) {
      errorMessage = 'The selected member is unavailable.';
      notifyListeners();
      return false;
    }
    final payload = await _safe(
      () => api.post('module2/blocks/' + accountId, authenticated: true),
    );
    if (payload == null) return false;
    actionMessage = displayName != null && displayName.trim().isNotEmpty
        ? '${displayName.trim()} has been blocked.'
        : 'Member has been blocked.';
    await Future.wait([
      loadBlockedMembers(),
      loadDiscover(),
      loadFeed(),
      loadFollowers(showFollowing: false),
      loadFollowers(showFollowing: true),
      loadProfile(),
    ]);
    notifyListeners();
    return true;
  }

  Future<bool> unblockMember(Module2Member member) async {
    final payload = await _safe(
      () => api.delete('module2/blocks/' + member.accountId, authenticated: true),
    );
    if (payload == null) return false;
    actionMessage = 'Member unblocked.';
    await loadBlockedMembers();
    notifyListeners();
    return true;
  }

  Future<bool> reportMember({
    required String accountId,
    required String reason,
    String? postId,
    String? details,
  }) async {
    final payload = await _safe(
      () => api.post(
        'module2/reports',
        authenticated: true,
        body: <String, Object?>{
          'reportedAccountId': accountId,
          'reason': reason,
          if (postId != null) 'postId': postId,
          if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
        },
      ),
    );
    if (payload == null) return false;
    actionMessage = 'Report submitted for review.';
    notifyListeners();
    return true;
  }

  Future<bool> loadBusinessProfile() async {
    final payload = await _safe(
      () => api.get('module2/business-profile', authenticated: true),
    );
    if (payload == null) return false;
    final business = jsonMap(payload['businessProfile']);
    businessProfile = business.isEmpty ? null : business;
    notifyListeners();
    return true;
  }

  Future<bool> saveBusinessProfile({
    required String displayName,
    required String description,
    required String websiteUrl,
  }) async {
    final payload = await _safe(
      () => api.put(
        'module2/business-profile',
        authenticated: true,
        body: <String, Object?>{
          'displayName': displayName.trim(),
          if (description.trim().isNotEmpty) 'description': description.trim(),
          if (websiteUrl.trim().isNotEmpty) 'websiteUrl': websiteUrl.trim(),
        },
      ),
    );
    if (payload == null) return false;
    businessProfile = jsonMap(payload['businessProfile']);
    actionMessage = 'Business profile submitted for review.';
    notifyListeners();
    return true;
  }

  Future<bool> loadSessions() async {
    final payload = await _safe(
      () => api.get('module2/sessions', authenticated: true),
    );
    if (payload == null) return false;
    sessions = jsonMapList(payload['sessions']);
    notifyListeners();
    return true;
  }

  Future<bool> revokeSession(String sessionId) async {
    final payload = await _safe(
      () => api.delete('module2/sessions/' + sessionId, authenticated: true),
    );
    if (payload == null) return false;
    final current = payload['currentSession'] == true;
    actionMessage = current ? 'This device session was revoked.' : 'Login session revoked.';
    await loadSessions();
    if (current) await authService.logout();
    notifyListeners();
    return true;
  }

  Future<bool> deactivateAccount() async {
    final payload = await _safe(
      () => api.post(
        'module2/account/deactivate',
        authenticated: true,
        body: const <String, Object?>{'confirmation': 'DEACTIVATE'},
      ),
    );
    if (payload == null) return false;
    await authService.logout();
    actionMessage = 'Your account has been deactivated.';
    notifyListeners();
    return true;
  }

  Future<bool> requestAccountDeletion({String? reason}) async {
    final payload = await _safe(
      () => api.post(
        'module2/account/deletion-request',
        authenticated: true,
        body: <String, Object?>{
          'confirmation': 'DELETE',
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        },
      ),
    );
    if (payload == null) return false;
    await authService.logout();
    actionMessage = 'Account deletion request submitted.';
    notifyListeners();
    return true;
  }
}
