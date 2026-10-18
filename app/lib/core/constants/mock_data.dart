import 'package:flutter/material.dart';

import '../../features/module2/module2_models.dart';
import '../../features/module2/module2_state.dart';

/// Kept at the prototype's original import path to minimize screen churn. All
/// account/feed/preference data in this adapter is hydrated from Module2State;
/// this class deliberately contains no fictional member or post records.
class UserProfileModel {
  String displayName;
  String username;
  String bio;
  String location;
  String avatarAsset;
  int postsCount;
  int followersCount;
  int followingCount;
  List<String> interests;
  String? email;

  UserProfileModel({
    required this.displayName,
    required this.username,
    required this.bio,
    required this.location,
    required this.avatarAsset,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.interests,
    this.email,
  });
}

class FeedPostModel {
  FeedPostModel({
    required this.id,
    required this.authorName,
    required this.authorUsername,
    required this.authorAvatar,
    required this.timestamp,
    required this.content,
    this.imageAsset,
    this.categoryBadge,
    this.hasBreathingExerciseCard = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.authorAccountId = '',
    this.audience = 'VERIFIED_MEMBERS',
    this.isOwnPost = false,
  });

  final String id;
  final String authorName;
  final String authorUsername;
  final String authorAvatar;
  final String timestamp;
  final String content;
  final String? imageAsset;
  final String? categoryBadge;
  final bool hasBreathingExerciseCard;
  final String authorAccountId;
  final String audience;
  final bool isOwnPost;
  int likesCount;
  int commentsCount;
  bool isLiked;
  bool isSaved;
}

class FollowerUserModel {
  FollowerUserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.avatarAsset,
    required this.isFollowing,
  });

  final String id;
  final String name;
  final String username;
  final String avatarAsset;
  bool isFollowing;
  String? bio;
}

class PrivacySettingItem {
  PrivacySettingItem({
    required this.id,
    required this.title,
    required this.selectedValue,
    required this.options,
    required this.icon,
  });

  final String id;
  final String title;
  String selectedValue;
  final List<String> options;
  final IconData icon;
}

class NotificationPrefItem {
  NotificationPrefItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isEnabled,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  bool isEnabled;
}

/// UI-facing adapter. The visual screens observe this ChangeNotifier, while all
/// reads and mutations delegate to the authenticated Module 2 API and database.
class SakhiPrototypeState extends ChangeNotifier {
  SakhiPrototypeState._internal();

  static final SakhiPrototypeState instance = SakhiPrototypeState._internal();

  Module2State? _backend;
  bool isLoading = true;
  String searchQuery = '';
  final List<String> exploreFilters = const ['All', 'Posts', 'Groups', 'Experts', 'Events'];
  final List<String> trendingHashtags = const [
    '#MentalWellness',
    '#CareerGrowth',
    '#SelfCare',
    '#SafetyTips',
    '#StudentLife',
    '#WomenInTech',
  ];

  UserProfileModel currentUser = UserProfileModel(
    displayName: '',
    username: '@member',
    bio: '',
    location: '',
    avatarAsset: '',
    postsCount: 0,
    followersCount: 0,
    followingCount: 0,
    interests: <String>[],
  );

  List<FeedPostModel> communityPosts = [];
  List<FeedPostModel> profilePosts = [];
  List<FeedPostModel> savedPosts = [];
  bool showSavedPostsFirst = false;
  List<FeedPostModel> get exploreRecommendedPosts => communityPosts;
  List<FollowerUserModel> followers = [];
  List<FollowerUserModel> following = [];
  List<PrivacySettingItem> privacySettings = [];
  List<NotificationPrefItem> notificationPreferences = [];
  final Map<String, Module2Member> _memberById = <String, Module2Member>{};
  final Map<String, Module2Post> _postById = <String, Module2Post>{};

  Module2State? get backend => _backend;
  String get verificationStatus => _backend?.profile?.verificationStatus ?? 'UNVERIFIED';
  bool get phoneVerified => _backend?.profile?.phoneVerified ?? false;
  String get maskedPhone => _backend?.profile?.phoneMasked ?? '';

  Future<void> bind(Module2State state) async {
    if (identical(_backend, state)) return;
    _backend?.removeListener(_syncFromBackend);
    _backend = state;
    state.addListener(_syncFromBackend);
    isLoading = true;
    notifyListeners();
    await state.initialize();
    await _loadRouteData('/home');
    _syncFromBackend();
  }

  Future<void> loadRouteData(String route) => _loadRouteData(route);

  Future<void> _loadRouteData(String route) async {
    final state = _backend;
    if (state == null) return;
    switch (route) {
      case '/home':
        await state.loadProfile();
        await state.loadFeed();
        break;
      case '/explore':
        await Future.wait([
          state.loadDiscover(query: searchQuery),
          state.loadGroups(query: searchQuery),
          state.loadEvents(query: searchQuery),
          state.loadExperts(query: searchQuery),
          if (searchQuery.trim().isNotEmpty) state.loadFeed(query: searchQuery),
        ]);
        break;
      case '/groups':
        await Future.wait([
          state.loadGroups(),
          state.loadGroups(mine: true),
          state.loadEvents(),
        ]);
        break;
      case '/my-groups':
        await Future.wait([
          state.loadGroups(mine: true),
          state.loadEvents(),
        ]);
        break;
      case '/community':
        await state.loadFeed(query: searchQuery);
        break;
      case '/profile':
        if (state.profile == null) await state.loadProfile();
        final id = state.profile?.accountId;
        if (id != null && id.isNotEmpty) {
          await state.loadFeed(accountId: id);
        }
        break;
      case '/followers':
        await Future.wait([
          state.loadFollowers(showFollowing: false),
          state.loadFollowers(showFollowing: true),
        ]);
        break;
      case '/privacy-settings':
        await state.loadPrivacySettings();
        break;
      case '/notification-preferences':
        await state.loadNotificationPreferences();
        break;
      case '/more-options':
        await state.loadBusinessProfile();
        await state.loadBlockedMembers();
        break;
      case '/account-security':
        await state.loadSessions();
        break;
    }
    _syncFromBackend();
  }

  void _syncFromBackend() {
    final state = _backend;
    if (state == null) return;
    isLoading = state.isLoading;
    final profile = state.profile;
    if (profile != null) {
      currentUser = UserProfileModel(
        displayName: profile.displayName,
        username: '@member',
        bio: profile.bio,
        location: profile.locationCity,
        avatarAsset: _safeImageRef(profile.profilePhotoRef),
        postsCount: profile.postsCount,
        followersCount: profile.followersCount,
        followingCount: profile.followingCount,
        interests: List<String>.from(profile.interests),
        email: profile.email,
      );
    }

    _postById
      ..clear()
      ..addEntries([
        for (final post in [...state.feedPosts, ...state.profilePosts, ...state.savedPosts])
          MapEntry(post.id, post),
      ]);
    communityPosts = state.feedPosts.map(_uiPost).toList();
    profilePosts = state.profilePosts.map(_uiPost).toList();
    savedPosts = state.savedPosts.map(_uiPost).toList();

    _memberById
      ..clear()
      ..addEntries([
        for (final member in [
          ...state.discoveredMembers,
          ...state.followers,
          ...state.following,
          ...state.blockedMembers,
        ])
          MapEntry(member.accountId, member),
      ]);
    followers = state.followers.map(_uiMember).toList();
    following = state.following.map(_uiMember).toList();

    privacySettings = _buildPrivacyItems(state.privacySettings);
    notificationPreferences = _buildNotificationItems(state.notificationPreferences);
    notifyListeners();
  }

  String _safeImageRef(String? ref) {
    if (ref == null || ref.trim().isEmpty) return '';
    if (ref.startsWith('http://') || ref.startsWith('https://')) return ref;
    return '';
  }

  String _relativeTime(DateTime? date) {
    if (date == null) return '';
    final age = DateTime.now().difference(date);
    if (age.inMinutes < 1) return 'Just now';
    if (age.inMinutes < 60) return age.inMinutes.toString() + ' min ago';
    if (age.inHours < 24) return age.inHours.toString() + ' hours ago';
    if (age.inDays < 7) return age.inDays.toString() + ' days ago';
    return date.toLocal().toString().split(' ').first;
  }

  FeedPostModel _uiPost(Module2Post post) => FeedPostModel(
    id: post.id,
    authorName: post.authorName,
    authorUsername: '@member',
    authorAvatar: _safeImageRef(post.authorPhotoRef),
    timestamp: _relativeTime(post.createdAt),
    content: post.body,
    likesCount: post.likeCount,
    commentsCount: post.commentCount,
    isLiked: post.isLiked,
    isSaved: post.isSaved,
    authorAccountId: post.authorAccountId,
    audience: post.audience,
    isOwnPost: post.isOwnPost,
  );

  FollowerUserModel _uiMember(Module2Member member) {
    final result = FollowerUserModel(
      id: member.accountId,
      name: member.displayName,
      username: '@member',
      avatarAsset: _safeImageRef(member.profilePhotoRef),
      isFollowing: member.isFollowing,
    );
    result.bio = member.bio;
    return result;
  }

  List<PrivacySettingItem> _buildPrivacyItems(Map<String, dynamic> settings) {
    String value(String key, Map<String, String> labels, String fallback) {
      final raw = settings[key];
      return labels[raw?.toString()] ?? fallback;
    }

    return [
      PrivacySettingItem(
        id: 'view_profile',
        title: 'Who can view my profile',
        selectedValue: value('profileVisibility', {
          'VERIFIED_MEMBERS': 'Verified members only',
          'FOLLOWERS_ONLY': 'Followers only',
          'ONLY_ME': 'Only me',
        }, 'Verified members only'),
        options: const ['Verified members only', 'Followers only', 'Only me'],
        icon: Icons.person_outline_rounded,
      ),
      PrivacySettingItem(
        id: 'message_me',
        title: 'Who can message me',
        selectedValue: value('messagePermission', {
          'VERIFIED_MEMBERS': 'Verified members only',
          'FOLLOWING_ONLY': 'People I follow',
          'NO_ONE': 'No one',
        }, 'Verified members only'),
        options: const ['Verified members only', 'People I follow', 'No one'],
        icon: Icons.mark_email_unread_outlined,
      ),
      PrivacySettingItem(
        id: 'see_posts',
        title: 'Who can see my posts',
        selectedValue: value('defaultPostAudience', {
          'VERIFIED_MEMBERS': 'Verified members only',
          'FOLLOWERS': 'My followers',
          'ONLY_ME': 'Only me',
        }, 'Verified members only'),
        options: const ['Verified members only', 'My followers', 'Only me'],
        icon: Icons.contact_page_outlined,
      ),
      PrivacySettingItem(
        id: 'show_location',
        title: 'Show my location',
        selectedValue: value('locationSharing', {
          'CITY_ONLY': 'City only',
          'HIDDEN': 'Hidden',
        }, 'Hidden'),
        options: const ['City only', 'Hidden'],
        icon: Icons.location_on_outlined,
      ),
      PrivacySettingItem(
        id: 'search_results',
        title: 'Appear in search results',
        selectedValue: settings['appearInSearch'] == true ? 'Yes' : 'No',
        options: const ['Yes', 'No'],
        icon: Icons.search_rounded,
      ),
      PrivacySettingItem(
        id: 'business_enquiries',
        title: 'Allow business enquiries',
        selectedValue: value('businessEnquiryPermission', {
          'ALL_VERIFIED': 'All verified members',
          'VERIFIED_BUSINESSES': 'Verified businesses only',
          'NONE': 'No',
        }, 'Verified businesses only'),
        options: const ['All verified members', 'Verified businesses only', 'No'],
        icon: Icons.business_center_outlined,
      ),
    ];
  }

  List<NotificationPrefItem> _buildNotificationItems(Map<String, dynamic> prefs) => [
    NotificationPrefItem(id: 'community_updates', title: 'Community updates', subtitle: 'New posts, comments and likes', icon: Icons.groups_outlined, isEnabled: prefs['communityUpdates'] == true),
    NotificationPrefItem(id: 'group_activity', title: 'Group activity', subtitle: 'Updates from your groups', icon: Icons.people_outline_rounded, isEnabled: prefs['groupActivity'] == true),
    NotificationPrefItem(id: 'wellness_reminders', title: 'Wellness reminders', subtitle: 'Tips and suggestions', icon: Icons.health_and_safety_outlined, isEnabled: prefs['wellnessReminders'] == true),
    NotificationPrefItem(id: 'safety_alerts', title: 'Safety alerts', subtitle: 'Important safety notifications', icon: Icons.where_to_vote_outlined, isEnabled: prefs['safetyAlerts'] == true),
    NotificationPrefItem(id: 'messages', title: 'Messages', subtitle: 'Direct messages', icon: Icons.chat_bubble_outline_rounded, isEnabled: prefs['messages'] == true),
    NotificationPrefItem(id: 'business_enquiries', title: 'Business enquiries', subtitle: 'Service and collaboration requests', icon: Icons.mark_chat_unread_outlined, isEnabled: prefs['businessEnquiries'] == true),
    NotificationPrefItem(id: 'marketing_updates', title: 'Marketing updates', subtitle: 'Optional product updates and news', icon: Icons.campaign_outlined, isEnabled: prefs['marketingUpdates'] == true),
  ];

  Future<bool> updateProfile({
    required String displayName,
    required String bio,
    required String location,
    required List<String> interests,
    String? email,
  }) async {
    final backend = _backend;
    if (backend == null) return false;
    final success = await backend.updateProfile(
      displayName: displayName,
      bio: bio,
      locationCity: location,
      interests: interests,
      email: email,
    );
    _syncFromBackend();
    return success;
  }

  Future<bool> addInterest(String interest) async {
    final trimmed = interest.trim();
    if (trimmed.isEmpty || currentUser.interests.contains(trimmed)) return false;
    return updateProfile(
      displayName: currentUser.displayName,
      bio: currentUser.bio,
      location: currentUser.location,
      interests: [...currentUser.interests, trimmed],
    );
  }

  Future<bool> removeInterest(String interest) => updateProfile(
    displayName: currentUser.displayName,
    bio: currentUser.bio,
    location: currentUser.location,
    interests: currentUser.interests.where((value) => value != interest).toList(),
  );

  Future<bool> toggleFollow(String memberId) async {
    final member = _memberById[memberId];
    final backend = _backend;
    if (member == null || backend == null) return false;
    final success = await backend.setFollowing(member, !member.isFollowing);
    _syncFromBackend();
    return success;
  }

  Future<bool> togglePostLike(FeedPostModel post) async {
    final backend = _backend;
    final apiPost = _postById[post.id];
    if (backend == null || apiPost == null) return false;
    final success = await backend.toggleLike(apiPost);
    _syncFromBackend();
    return success;
  }

  Future<bool> togglePostSaved(FeedPostModel post) async {
    final backend = _backend;
    final apiPost = _postById[post.id];
    if (backend == null || apiPost == null) return false;
    final success = await backend.toggleBookmark(apiPost);
    _syncFromBackend();
    return success;
  }

  Future<bool> updatePrivacySetting(String id, String newValue) async {
    final backend = _backend;
    if (backend == null) return false;
    final updates = <String, Object>{};
    switch (id) {
      case 'view_profile':
        updates['profileVisibility'] = <String, String>{
          'Verified members only': 'VERIFIED_MEMBERS',
          'Followers only': 'FOLLOWERS_ONLY',
          'Only me': 'ONLY_ME',
        }[newValue] ?? 'VERIFIED_MEMBERS';
        break;
      case 'message_me':
        updates['messagePermission'] = <String, String>{
          'Verified members only': 'VERIFIED_MEMBERS',
          'People I follow': 'FOLLOWING_ONLY',
          'No one': 'NO_ONE',
        }[newValue] ?? 'VERIFIED_MEMBERS';
        break;
      case 'see_posts':
        updates['defaultPostAudience'] = <String, String>{
          'Verified members only': 'VERIFIED_MEMBERS',
          'My followers': 'FOLLOWERS',
          'Only me': 'ONLY_ME',
        }[newValue] ?? 'VERIFIED_MEMBERS';
        break;
      case 'show_location':
        updates['locationSharing'] = newValue == 'City only' ? 'CITY_ONLY' : 'HIDDEN';
        break;
      case 'search_results':
        updates['appearInSearch'] = newValue == 'Yes';
        break;
      case 'business_enquiries':
        updates['businessEnquiryPermission'] = <String, String>{
          'All verified members': 'ALL_VERIFIED',
          'Verified businesses only': 'VERIFIED_BUSINESSES',
          'No': 'NONE',
        }[newValue] ?? 'VERIFIED_BUSINESSES';
        break;
    }
    if (updates.isEmpty) return false;
    final success = await backend.updatePrivacySetting(updates.keys.first, updates.values.first);
    _syncFromBackend();
    return success;
  }

  Future<bool> reportMember({
    required String accountId,
    required String reason,
    String? postId,
    String? details,
  }) async {
    final backend = _backend;
    if (backend == null) return false;
    final success = await backend.reportMember(
      accountId: accountId,
      reason: reason,
      postId: postId,
      details: details,
    );
    _syncFromBackend();
    return success;
  }

  Future<bool> toggleNotificationPref(String id, bool value) async {
    final backend = _backend;
    if (backend == null) return false;
    final key = <String, String>{
      'community_updates': 'communityUpdates',
      'group_activity': 'groupActivity',
      'wellness_reminders': 'wellnessReminders',
      'safety_alerts': 'safetyAlerts',
      'messages': 'messages',
      'business_enquiries': 'businessEnquiries',
      'marketing_updates': 'marketingUpdates',
    }[id];
    if (key == null) return false;
    final success = await backend.updateNotificationPreference(key, value);
    _syncFromBackend();
    return success;
  }

  Future<List<Module2Comment>> loadComments(String postId) async {
    final backend = _backend;
    if (backend == null) return <Module2Comment>[];
    final success = await backend.loadComments(postId);
    if (!success) return <Module2Comment>[];
    return backend.commentsByPost[postId] ?? <Module2Comment>[];
  }

  Future<bool> addComment(String postId, String body) async {
    final backend = _backend;
    if (backend == null) return false;
    final success = await backend.createComment(postId, body);
    _syncFromBackend();
    return success;
  }

  Future<bool> removeComment(String postId, String commentId) async {
    final backend = _backend;
    if (backend == null) return false;
    final success = await backend.deleteComment(commentId, postId);
    _syncFromBackend();
    return success;
  }

  Future<bool> setMarketingConsent(bool accepted) async {
    final backend = _backend;
    if (backend == null) return false;
    final success = await backend.updateMarketingConsent(accepted);
    _syncFromBackend();
    return success;
  }

  Future<bool> createPost(String body, {String audience = 'VERIFIED_MEMBERS'}) async {
    final backend = _backend;
    if (backend == null) return false;
    final success = await backend.createPost(body, audience: audience);
    _syncFromBackend();
    return success;
  }

  Future<bool> loadFeed({String query = ''}) async {
    final backend = _backend;
    if (backend == null) return false;
    final success = await backend.loadFeed(query: query);
    _syncFromBackend();
    return success;
  }

  Future<bool> loadDiscover({String query = ''}) async {
    final backend = _backend;
    if (backend == null) return false;
    final success = await backend.loadDiscover(query: query);
    _syncFromBackend();
    return success;
  }

  Future<bool> loadFollowers({required bool showFollowing, String query = ''}) async {
    final backend = _backend;
    if (backend == null) return false;
    final success = await backend.loadFollowers(showFollowing: showFollowing, query: query);
    _syncFromBackend();
    return success;
  }

  @override
  void dispose() {
    _backend?.removeListener(_syncFromBackend);
    super.dispose();
  }
}
