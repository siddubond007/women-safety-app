import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/auth/backend_api_client.dart';

const List<String> kSakhiCuratedInterests = <String>[
  'Mental Wellness',
  'Travel',
  'Reading',
  'WomenInTech',
  'Art',
  'Fitness',
  'Entrepreneurship',
  'Small Business',
  'Education',
  'Family',
  'Safety',
  'Wellness',
];

/// SRS 5.3 Feed Category model.
class FeedCategoryModel {
  final String slug;
  final String name;
  final String description;
  final String iconKey;
  final String accentColorHex;
  final bool isEnabled;
  final int displayOrder;

  const FeedCategoryModel({
    required this.slug,
    required this.name,
    required this.description,
    this.iconKey = 'sparkles',
    this.accentColorHex = '#C84B73',
    this.isEnabled = true,
    this.displayOrder = 1,
  });

  static const List<FeedCategoryModel> defaultCategories = [
    FeedCategoryModel(
      slug: 'following',
      name: 'Following',
      description: 'Updates from verified women and creators you follow.',
      iconKey: 'people',
      accentColorHex: '#C84B73',
      displayOrder: 1,
    ),
    FeedCategoryModel(
      slug: 'community',
      name: 'Community',
      description:
          'Everyday stories, encouragement, and local circles across Sakhi.',
      iconKey: 'sparkles',
      accentColorHex: '#9E3D64',
      displayOrder: 2,
    ),
    FeedCategoryModel(
      slug: 'trending',
      name: 'Trending',
      description: 'Most-engaged conversations and community highlights today.',
      iconKey: 'trending_up',
      accentColorHex: '#D46B3E',
      displayOrder: 3,
    ),
    FeedCategoryModel(
      slug: 'business_updates',
      name: 'Business Updates',
      description: 'Showcases, launches, and offers from women-led businesses.',
      iconKey: 'storefront',
      accentColorHex: '#7B4B94',
      displayOrder: 4,
    ),
    FeedCategoryModel(
      slug: 'safety_awareness',
      name: 'Safety Awareness',
      description: 'Verified commute tips, helpline resources, and neighbourhood alerts.',
      iconKey: 'shield',
      accentColorHex: '#2E7D67',
      displayOrder: 5,
    ),
    FeedCategoryModel(
      slug: 'wellness_lifestyle',
      name: 'Wellness and Lifestyle',
      description:
          'Cycle care, mindfulness, nutrition, and holistic wellbeing.',
      iconKey: 'spa',
      accentColorHex: '#4A7C9B',
      displayOrder: 6,
    ),
  ];
}

class PostCommentItem {
  final String id;
  final String authorAccountId;
  final String authorName;
  final String authorUsername;
  final String authorAvatar;
  String body;
  final String createdAt;
  final String? parentCommentId;
  final String? replyToHandle;
  final bool isOwnComment;
  final bool canEdit;
  final bool canDelete;

  PostCommentItem({
    required this.id,
    this.authorAccountId = '',
    required this.authorName,
    this.authorUsername = '@member',
    required this.authorAvatar,
    required this.body,
    required this.createdAt,
    this.parentCommentId,
    this.replyToHandle,
    this.isOwnComment = false,
    this.canEdit = false,
    this.canDelete = false,
  });

  factory PostCommentItem.fromJson(Map<String, dynamic> json) {
    final authorId = json['authorAccountId']?.toString() ?? '';
    final authorName = json['authorName']?.toString() ?? 'Sakhi Member';
    final rawAvatar = json['authorAvatar']?.toString() ?? '';
    return PostCommentItem(
      id: (json['id'] ?? json['commentId'] ?? '').toString(),
      authorAccountId: authorId,
      authorName: authorName,
      authorUsername: json['authorUsername']?.toString() ?? '@member',
      authorAvatar: rawAvatar,
      body: (json['body'] ?? json['content'] ?? json['text'] ?? '').toString(),
      createdAt: json['createdAt']?.toString() ?? 'Just now',
      parentCommentId: json['parentCommentId']?.toString(),
      replyToHandle: json['replyToHandle']?.toString(),
      isOwnComment: json['isOwnComment'] == true,
      canEdit: json['canEdit'] == true || json['isOwnComment'] == true,
      canDelete: json['canDelete'] == true || json['isOwnComment'] == true,
    );
  }
}

class UserProfileModel {
  String accountId;
  String displayName;
  String username;
  String bio;
  String location;
  String avatarAsset;
  String email;
  String phoneMasked;
  bool phoneVerified;
  String verificationStatus;
  int postsCount;
  int followersCount;
  int followingCount;
  List<String> interests;
  String? businessProfileUrl;
  bool twoFactorEnabled;
  int activeSessionsCount;

  UserProfileModel({
    this.accountId = '',
    required this.displayName,
    required this.username,
    required this.bio,
    required this.location,
    required this.avatarAsset,
    this.email = '',
    this.phoneMasked = '',
    this.phoneVerified = false,
    this.verificationStatus = 'UNVERIFIED',
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.interests,
    this.businessProfileUrl,
    this.twoFactorEnabled = false,
    this.activeSessionsCount = 0,
  });

  String get name => displayName;
}

class FeedPostModel {
  final String id;
  final String authorAccountId;
  final String authorName;
  final String authorUsername;
  final String authorAvatar;
  final bool authorVerified;
  final String timestamp;
  String content;
  String? imageAsset;
  String? mediaContentType;
  String? categoryBadge;
  String categorySlug;
  String visibility;
  String cropPreset;
  List<String> hashtags;
  String? locationTag;
  bool allowComments;
  bool shareToBusinessProfile;
  final bool hasBreathingExerciseCard;
  int likesCount;
  int commentsCount;
  int savesCount;
  int sharesCount;
  bool isLiked;
  bool isSaved;
  bool isOwnPost;
  bool canEdit;
  bool canDelete;
  String? viewerReaction;
  Map<String, int> reactionBreakdown;
  List<PostCommentItem> comments;

  FeedPostModel({
    required this.id,
    this.authorAccountId = '',
    required this.authorName,
    required this.authorUsername,
    required this.authorAvatar,
    this.authorVerified = true,
    required this.timestamp,
    required this.content,
    this.imageAsset,
    this.mediaContentType,
    this.categoryBadge,
    this.categorySlug = 'community',
    this.visibility = 'VERIFIED_MEMBERS',
    this.cropPreset = '4:5',
    this.hashtags = const [],
    this.locationTag,
    this.allowComments = true,
    this.shareToBusinessProfile = false,
    this.hasBreathingExerciseCard = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.savesCount = 0,
    this.sharesCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.isOwnPost = false,
    this.canEdit = false,
    this.canDelete = false,
    this.viewerReaction,
    Map<String, int>? reactionBreakdown,
    List<PostCommentItem>? comments,
  }) : reactionBreakdown = reactionBreakdown ?? <String, int>{},
       comments = comments ?? <PostCommentItem>[];

  String get audience => visibility;
  String get timeAgo => timestamp;
  String? get reactionType => viewerReaction;
  int get reactionsCount => likesCount;
  List<String> get mediaItems => imageAsset != null && imageAsset!.isNotEmpty
      ? <String>[imageAsset!]
      : const <String>[];

  factory FeedPostModel.fromJson(Map<String, dynamic> json) {
    final authorId = json['authorAccountId']?.toString() ?? '';
    final authorName = json['authorName']?.toString() ?? 'Sakhi Member';
    final rawAvatar =
        (json['authorAvatar'] ??
                json['authorAvatarUrl'] ??
                json['authorAvatarAsset'] ??
                '')
            .toString();
    final rawComments = json['comments'];
    final parsedComments = rawComments is List
        ? rawComments
              .whereType<Map<String, dynamic>>()
              .map(PostCommentItem.fromJson)
              .toList()
        : <PostCommentItem>[];
    final rawBreakdown = json['reactionBreakdown'];
    final parsedBreakdown = <String, int>{};
    if (rawBreakdown is Map) {
      for (final e in rawBreakdown.entries) {
        if (e.value is num && (e.value as num) > 0) {
          parsedBreakdown[e.key.toString()] = (e.value as num).toInt();
        }
      }
    }
    final rawTags = json['hashtags'];
    final parsedTags = rawTags is List
        ? rawTags.map((e) => e.toString()).toList()
        : <String>[];

    return FeedPostModel(
      id: json['id']?.toString() ?? '',
      authorAccountId: authorId,
      authorName: authorName,
      authorUsername: json['authorUsername']?.toString() ?? '@member',
      authorAvatar: rawAvatar,
      authorVerified: json['authorVerified'] == true,
      timestamp: (json['timestamp'] ?? json['createdAt'] ?? 'Just now')
          .toString(),
      content: (json['content'] ?? json['body'] ?? json['caption'] ?? '')
          .toString(),
      imageAsset:
          (json['imageAsset'] ?? json['mediaAsset'] ?? json['mediaUrl'])
              as String?,
      mediaContentType: json['mediaContentType']?.toString(),
      categoryBadge: (json['categoryBadge'] ?? json['categorySlug']) as String?,
      categorySlug: (json['categorySlug'] ?? 'community').toString(),
      visibility: (json['visibility'] ?? 'VERIFIED_MEMBERS').toString(),
      cropPreset: (json['cropPreset'] ?? '4:5').toString(),
      hashtags: parsedTags,
      locationTag: json['locationTag'] as String?,
      allowComments: json['allowComments'] != false,
      shareToBusinessProfile: json['shareToBusinessProfile'] == true,
      hasBreathingExerciseCard: json['hasBreathingExerciseCard'] == true,
      likesCount:
          ((json['reactionsCount'] ?? json['likesCount']) as num?)?.toInt() ??
          0,
      commentsCount:
          (json['commentsCount'] as num?)?.toInt() ?? parsedComments.length,
      savesCount: (json['savesCount'] as num?)?.toInt() ?? 0,
      sharesCount: (json['sharesCount'] as num?)?.toInt() ?? 0,
      isLiked: json['isLiked'] == true || json['likedByViewer'] == true,
      isSaved: json['isSaved'] == true || json['savedByViewer'] == true,
      isOwnPost: json['isOwnPost'] == true,
      canEdit: json['canEdit'] == true || json['isOwnPost'] == true,
      canDelete: json['canDelete'] == true || json['isOwnPost'] == true,
      viewerReaction: json['viewerReaction'] as String?,
      reactionBreakdown: parsedBreakdown,
      comments: parsedComments,
    );
  }
}

class FollowerUserModel {
  final String id;
  final String name;
  final String username;
  final String location;
  final String? bio;
  final String avatarAsset;
  final bool isVerified;
  final bool canFollow;
  final bool followsMe;
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final List<String> interests;
  final String? businessProfileUrl;
  final String? businessProfileName;
  final String? businessCategory;
  bool isFollowing;

  FollowerUserModel({
    required this.id,
    required this.name,
    required this.username,
    this.location = 'India',
    this.bio,
    required this.avatarAsset,
    required this.isFollowing,
    this.followsMe = false,
    this.postsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isVerified = false,
    this.canFollow = true,
    this.interests = const <String>[],
    this.businessProfileUrl,
    this.businessProfileName,
    this.businessCategory,
  });

  String get accountId => id;

  factory FollowerUserModel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['accountId'] ?? '').toString();
    final name = (json['name'] ?? json['displayName'] ?? '').toString();
    final rawAvatar = (json['avatarUrl'] ?? json['avatarAsset'] ?? '')
        .toString();
    final rawInterests = json['interests'];
    return FollowerUserModel(
      id: id,
      name: name,
      username: json['username']?.toString() ?? '',
      location: (json['location'] ?? json['city'] ?? 'India').toString(),
      bio: json['bio'] as String?,
      avatarAsset: rawAvatar,
      isFollowing: json['isFollowing'] == true,
      followsMe: json['followsMe'] == true,
      postsCount: (json['postsCount'] as num?)?.toInt() ?? 0,
      followersCount: (json['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
      isVerified:
          json['isVerified'] == true ||
          json['verificationStatus'] == 'VERIFIED',
      canFollow: json['canFollow'] != false,
      interests: rawInterests is List
          ? rawInterests
                .map((value) => value.toString())
                .toList(growable: false)
          : const <String>[],
      businessProfileUrl: json['businessProfileUrl']?.toString(),
      businessProfileName: json['businessProfileName']?.toString(),
      businessCategory: json['businessCategory']?.toString(),
    );
  }
}

class CommunityGroupModel {
  final String id;
  final String name;
  final String description;
  final String category;
  final int membersCount;
  final int newPostsToday;

  bool get isJoined => SakhiPrototypeState.instance.isCircleJoined(name);

  const CommunityGroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.membersCount,
    required this.newPostsToday,
  });

  factory CommunityGroupModel.fromJson(Map<String, dynamic> json) {
    return CommunityGroupModel(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? json['title'] ?? '').toString(),
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      membersCount: (json['membersCount'] as num?)?.toInt() ?? 1,
      newPostsToday: (json['newPostsToday'] as num?)?.toInt() ?? 0,
    );
  }
}

class EmergencyContactModel {
  final String id;
  final String name;
  final String relationship;
  final String phoneE164;

  const EmergencyContactModel({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phoneE164,
  });

  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) {
    return EmergencyContactModel(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? json['contactName'] ?? '').toString(),
      relationship: json['relationship']?.toString() ?? '',
      phoneE164: (json['phoneE164'] ?? json['phoneNumberMasked'] ?? '')
          .toString(),
    );
  }
}

class BlockedUserModel {
  final String id;
  final String blockedUsername;
  final String blockedDisplayName;

  const BlockedUserModel({
    required this.id,
    required this.blockedUsername,
    required this.blockedDisplayName,
  });

  factory BlockedUserModel.fromJson(Map<String, dynamic> json) {
    return BlockedUserModel(
      id: (json['id'] ?? json['accountId'] ?? '').toString(),
      blockedUsername: (json['blockedUsername'] ?? json['username'] ?? '')
          .toString(),
      blockedDisplayName: (json['blockedDisplayName'] ?? json['name'] ?? '')
          .toString(),
    );
  }
}

class PrivacySettingItem {
  final String id;
  final String title;
  String selectedValue;
  final List<String> options;
  final IconData icon;

  PrivacySettingItem({
    required this.id,
    required this.title,
    required this.selectedValue,
    required this.options,
    required this.icon,
  });
}

class NotificationPrefItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  bool isEnabled;

  NotificationPrefItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isEnabled,
  });
}

/// Unified domain state and backend repository store for Module 2 & Module 3.
class SakhiPrototypeState extends ChangeNotifier {
  static final SakhiPrototypeState instance = SakhiPrototypeState._internal();
  SakhiPrototypeState._internal();

  BackendApiClient? _apiClient;
  dynamic _boundBackend;
  bool _isBackendSynced = false;
  bool _isBackendSyncing = false;

  /// Persistent shell navigation state so minimizing/resuming the app never resets to Home.
  int activeShellTabIndex = 0;
  String? activeShellSubRoute;
  final List<int> activeShellTabHistory = <int>[];

  /// Per-account seen post IDs so Home "new posts in Community" reflects real unviewed posts.
  final Set<String> _seenPostIds = <String>{};
  final Set<String> joinedCircleNames = <String>{};

  bool isCircleJoined(String circleName) =>
      joinedCircleNames.contains(circleName.trim());

  Future<bool> hasAuthenticatedSession() async {
    try {
      final token = await _client.readAccessToken();
      return token != null && token.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  int get unreadCommunityPostsCount {
    if (communityPosts.isEmpty) return 0;
    return communityPosts
        .where((p) => !p.isOwnPost && !_seenPostIds.contains(p.id))
        .length;
  }

  void markCommunityPostsAsSeen([Iterable<String>? postIds]) {
    final ids = postIds ?? communityPosts.map((p) => p.id);
    var added = false;
    for (final id in ids) {
      if (id.isNotEmpty && _seenPostIds.add(id)) {
        added = true;
      }
    }
    if (added) {
      notifyListeners();
    }
  }

  String? lastSyncError;
  int totalDatabaseMembers = 0;
  int totalDatabasePosts = 0;
  String lastSyncSource = 'Backend not yet verified';
  bool showSavedPostsFirst = false;
  String searchQuery = '';
  String selectedCategorySlug = 'community';

  dynamic get backend => _boundBackend;
  bool get isBackendSynced => _isBackendSynced;
  bool get isBackendSyncing => _isBackendSyncing;

  void bind(dynamic backendState) {
    _boundBackend = backendState;
    notifyListeners();
  }

  BackendApiClient get _client => _apiClient ??= BackendApiClient();

  void configureApiClient(BackendApiClient client) {
    _apiClient = client;
  }

  List<FeedCategoryModel> feedCategories = List<FeedCategoryModel>.from(
    FeedCategoryModel.defaultCategories,
  );

  /// Neutral empty state until an authenticated backend profile is loaded.
  final UserProfileModel currentUser = UserProfileModel(
    accountId: '',
    displayName: 'Sakhi Member',
    username: '',
    bio: '',
    location: '',
    avatarAsset: '',
    email: '',
    phoneMasked: '',
    phoneVerified: false,
    verificationStatus: 'UNVERIFIED',
    postsCount: 0,
    followersCount: 0,
    followingCount: 0,
    interests: <String>[],
  );

  final List<String> exploreFilters = const [
    'All',
    'Posts',
    'Groups',
    'Experts',
    'Events',
  ];

  /// Hashtags discovered from live posts, ranked by frequency.
  List<String> get trendingHashtags {
    final counts = <String, int>{};
    for (final post in [...communityPosts, ...exploreRecommendedPosts]) {
      for (final rawTag in post.hashtags) {
        final tag = rawTag.startsWith('#') ? rawTag : '#$rawTag';
        if (tag.length > 1) {
          counts.update(tag, (count) => count + 1, ifAbsent: () => 1);
        }
      }
    }
    final tags = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return tags.take(12).toList(growable: false);
  }

  final List<FeedPostModel> communityPosts = [];

  final List<FeedPostModel> exploreRecommendedPosts = [];

  final List<FeedPostModel> profilePosts = [];

  List<FeedPostModel> get savedPosts =>
      communityPosts.where((p) => p.isSaved).toList(growable: false);

  final List<CommunityGroupModel> groups = [];

  final List<FollowerUserModel> followers = [];

  List<FollowerUserModel> get following =>
      followers.where((f) => f.isFollowing).toList(growable: false);

  final List<EmergencyContactModel> emergencyContacts = [];

  final List<BlockedUserModel> blockedUsers = [];

  final List<PrivacySettingItem> privacySettings = [
    PrivacySettingItem(
      id: 'view_profile',
      title: 'Who can view my profile',
      selectedValue: 'All Verified Members',
      options: [
        'All Verified Members',
        'Followers Only',
        'Circle Members Only',
      ],
      icon: Icons.person_outline_rounded,
    ),
    PrivacySettingItem(
      id: 'message_me',
      title: 'Who can message me',
      selectedValue: 'Followers Only',
      options: ['All Verified Members', 'Followers Only', 'No One'],
      icon: Icons.mark_email_unread_outlined,
    ),
    PrivacySettingItem(
      id: 'see_posts',
      title: 'Who can see my posts',
      selectedValue: 'All Verified Members',
      options: [
        'All Verified Members',
        'Followers Only',
        'Circle Members Only',
      ],
      icon: Icons.contact_page_outlined,
    ),
    PrivacySettingItem(
      id: 'show_location',
      title: 'Show my location',
      selectedValue: 'Verified Members',
      options: ['Verified Members', 'Followers Only', 'Hide Location'],
      icon: Icons.location_on_outlined,
    ),
    PrivacySettingItem(
      id: 'search_results',
      title: 'Appear in search results',
      selectedValue: 'Yes',
      options: ['Yes', 'No'],
      icon: Icons.search_rounded,
    ),
    PrivacySettingItem(
      id: 'business_enquiries',
      title: 'Allow business enquiries',
      selectedValue: 'Yes',
      options: ['Yes', 'Verified businesses only', 'No'],
      icon: Icons.business_center_outlined,
    ),
  ];

  final List<NotificationPrefItem> notificationPreferences = [
    NotificationPrefItem(
      id: 'community_updates',
      title: 'Community updates',
      subtitle: 'New posts, comments, likes',
      icon: Icons.groups_outlined,
      isEnabled: true,
    ),
    NotificationPrefItem(
      id: 'group_activity',
      title: 'Group activity',
      subtitle: 'Updates from your groups',
      icon: Icons.people_outline_rounded,
      isEnabled: true,
    ),
    NotificationPrefItem(
      id: 'wellness_reminders',
      title: 'Wellness reminders',
      subtitle: 'Tips and suggestions',
      icon: Icons.health_and_safety_outlined,
      isEnabled: true,
    ),
    NotificationPrefItem(
      id: 'safety_alerts',
      title: 'Safety alerts',
      subtitle: 'Important safety notifications',
      icon: Icons.where_to_vote_outlined,
      isEnabled: true,
    ),
    NotificationPrefItem(
      id: 'messages',
      title: 'Messages',
      subtitle: 'Direct messages',
      icon: Icons.chat_bubble_outline_rounded,
      isEnabled: true,
    ),
    NotificationPrefItem(
      id: 'business_enquiries',
      title: 'Business enquiries',
      subtitle: 'Service or collaboration requests',
      icon: Icons.mark_chat_unread_outlined,
      isEnabled: true,
    ),
    NotificationPrefItem(
      id: 'marketing_updates',
      title: 'Marketing updates',
      subtitle: 'Product updates and news',
      icon: Icons.campaign_outlined,
      isEnabled: false,
    ),
  ];

  Future<void> loadRouteData(String routeName) async {
    await syncFromBackend();
  }

  Future<void> loadFeed({
    String? query,
    String? topic,
    String? categorySlug,
    String? search,
    bool? savedOnly,
  }) async {
    if (categorySlug != null) {
      selectedCategorySlug = categorySlug;
    }
    if (query != null || search != null) {
      searchQuery = (query ?? search ?? '').trim();
    }
    if (savedOnly != null) {
      showSavedPostsFirst = savedOnly;
    }
    notifyListeners();
    try {
      final token = await _client.readAccessToken();
      if (token == null || token.isEmpty) return;
      final params = <String, String>{};
      if (selectedCategorySlug.isNotEmpty && selectedCategorySlug != 'all') {
        params['categorySlug'] = selectedCategorySlug;
      }
      if (searchQuery.isNotEmpty) {
        params['search'] = searchQuery;
      }
      if (showSavedPostsFirst) {
        params['savedOnly'] = 'true';
      }
      final qs = Uri(queryParameters: params).query;
      final res = await _client.get(
        qs.isEmpty ? 'module2/posts' : 'module2/posts?$qs',
        authenticated: true,
      );
      final rawPosts = res['posts'] ?? res['items'];
      if (rawPosts is List) {
        communityPosts
          ..clear()
          ..addAll(
            rawPosts.whereType<Map<String, dynamic>>().map(
              FeedPostModel.fromJson,
            ),
          );
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Reads a filtered feed without mutating the shared Social Wall list.
  /// Returns null when no authenticated API response is available, allowing
  /// callers to distinguish an unavailable request from a real empty result.
  Future<List<FeedPostModel>?> fetchPosts({
    String? search,
    String? categorySlug,
    bool? savedOnly,
    int limit = 30,
  }) async {
    try {
      final token = await _client.readAccessToken();
      if (token == null || token.isEmpty) return null;
      final params = <String, String>{'limit': '$limit'};
      if (categorySlug != null &&
          categorySlug.isNotEmpty &&
          categorySlug != 'all') {
        params['categorySlug'] = categorySlug;
      }
      if (search != null && search.trim().isNotEmpty) {
        params['search'] = search.trim();
      }
      if (savedOnly == true) params['savedOnly'] = 'true';
      final queryString = Uri(queryParameters: params).query;
      final response = await _client.get(
        'module2/posts?$queryString',
        authenticated: true,
      );
      final rows = response['posts'] ?? response['items'];
      if (rows is! List) return <FeedPostModel>[];
      return rows
          .whereType<Map<String, dynamic>>()
          .map(FeedPostModel.fromJson)
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  /// Queries the privacy-filtered, verified-member endpoint. Null means the
  /// server is unavailable; an empty list is a genuine empty result.
  Future<List<FollowerUserModel>?> searchVisibleMembers(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return const <FollowerUserModel>[];
    try {
      final token = await _client.readAccessToken();
      if (token == null || token.isEmpty) return null;
      final response = await _client.get(
        'module2/members/search?q=${Uri.encodeQueryComponent(query)}',
        authenticated: true,
      );
      final rows = response['members'];
      if (rows is! List) return <FollowerUserModel>[];
      return rows
          .whereType<Map<String, dynamic>>()
          .map(FollowerUserModel.fromJson)
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadDiscover({
    String? query,
    String? search,
    String? category,
  }) async {
    await syncFromBackend();
  }

  Future<void> loadFollowers({bool? showFollowing, String? query}) async {
    await syncFromBackend();
  }

  Future<void> loadComments(String postId) async {
    try {
      final token = await _client.readAccessToken();
      if (token == null || token.isEmpty) return;
      final res = await _client.get(
        'module2/posts/$postId/comments',
        authenticated: true,
      );
      final rawComments = res['comments'] ?? res['items'];
      if (rawComments is List) {
        final parsed = rawComments
            .whereType<Map<String, dynamic>>()
            .map(PostCommentItem.fromJson)
            .toList();
        var updatedAny = false;
        for (final collection in [
          communityPosts,
          exploreRecommendedPosts,
          profilePosts,
        ]) {
          for (final p in collection) {
            if (p.id == postId) {
              p.comments = List<PostCommentItem>.from(parsed);
              p.commentsCount = parsed.length;
              updatedAny = true;
            }
          }
        }
        if (updatedAny) {
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  /// Loads live PostgreSQL data from `/api/v1/module2/bootstrap` when an
  /// authenticated backend token is available.
  Future<void> syncFromBackend() async {
    if (_isBackendSyncing) return;
    _isBackendSyncing = true;
    lastSyncError = null;
    notifyListeners();
    try {
      String? token;
      try {
        token = await _client.readAccessToken();
      } catch (_) {
        _isBackendSynced = false;
        lastSyncError = 'Sign in to load your live Social Wall and profile.';
        lastSyncSource = 'Authentication required';
        return;
      }
      if (token == null || token.isEmpty) {
        _isBackendSynced = false;
        lastSyncError = 'Sign in to load your live Social Wall and profile.';
        lastSyncSource = 'Authentication required';
        return;
      }
      final data = await _client.get('module2/bootstrap', authenticated: true);

      final userMap = data['currentUser'] ?? data['user'];
      if (userMap is Map<String, dynamic>) {
        final nextAccountId =
            userMap['accountId']?.toString() ?? currentUser.accountId;
        if (nextAccountId.isNotEmpty &&
            currentUser.accountId.isNotEmpty &&
            nextAccountId != currentUser.accountId) {
          _seenPostIds.clear();
          emergencyContacts.clear();
          joinedCircleNames.clear();
        }
        currentUser.accountId = nextAccountId;
        currentUser.displayName =
            userMap['displayName']?.toString() ?? currentUser.displayName;
        currentUser.username =
            userMap['username']?.toString() ?? currentUser.username;
        currentUser.bio = userMap['bio']?.toString() ?? currentUser.bio;
        currentUser.location =
            (userMap['city'] ?? userMap['location'])?.toString() ??
            currentUser.location;
        final uploadedUrl = userMap['avatarUrl']?.toString();
        final rawAvatarAsset = userMap['avatarAsset']?.toString();
        final candidateAvatar = (uploadedUrl ?? rawAvatarAsset ?? '').trim();
        currentUser.avatarAsset =
            candidateAvatar.startsWith('http://') ||
                candidateAvatar.startsWith('https://') ||
                candidateAvatar.startsWith('/api/v1/') ||
                candidateAvatar.startsWith('assets/')
            ? candidateAvatar
            : '';
        currentUser.email = userMap['email']?.toString() ?? currentUser.email;
        currentUser.phoneMasked =
            userMap['phoneMasked']?.toString() ?? currentUser.phoneMasked;
        currentUser.phoneVerified = userMap['phoneVerified'] != false;
        currentUser.verificationStatus =
            (userMap['eligibilityStatus'] ?? userMap['verificationStatus'])
                ?.toString() ??
            'VERIFIED';
        currentUser.postsCount =
            (userMap['postsCount'] as num?)?.toInt() ?? currentUser.postsCount;
        currentUser.followersCount =
            (userMap['followersCount'] as num?)?.toInt() ??
            currentUser.followersCount;
        currentUser.followingCount =
            (userMap['followingCount'] as num?)?.toInt() ??
            currentUser.followingCount;
        currentUser.twoFactorEnabled = userMap['twoFactorEnabled'] == true;
        currentUser.activeSessionsCount =
            (userMap['activeSessionsCount'] as num?)?.toInt() ?? 1;
        currentUser.businessProfileUrl = userMap['businessProfileUrl']
            ?.toString();
      }

      final rawInterests = data['interests'] ?? userMap['interests'];
      if (rawInterests is List) {
        currentUser.interests = rawInterests.map((e) => e.toString()).toList();
      }

      final rawCategories = data['categories'];
      if (rawCategories is List && rawCategories.isNotEmpty) {
        feedCategories = rawCategories
            .whereType<Map<String, dynamic>>()
            .map(
              (c) => FeedCategoryModel(
                slug: (c['slug'] ?? 'community').toString(),
                name: (c['name'] ?? 'Community').toString(),
                description: (c['description'] ?? '').toString(),
                iconKey: (c['iconKey'] ?? 'sparkles').toString(),
                accentColorHex: (c['accentColorHex'] ?? '#C84B73').toString(),
                isEnabled: c['isEnabled'] != false,
                displayOrder: (c['displayOrder'] as num?)?.toInt() ?? 1,
              ),
            )
            .toList();
      }

      final rawCommunity = data['communityPosts'] ?? data['posts'];
      if (rawCommunity is List) {
        communityPosts
          ..clear()
          ..addAll(
            rawCommunity.whereType<Map<String, dynamic>>().map(
              FeedPostModel.fromJson,
            ),
          );
      }
      final rawExplorePosts = data['exploreRecommendedPosts'];
      if (rawExplorePosts is List) {
        exploreRecommendedPosts
          ..clear()
          ..addAll(
            rawExplorePosts.whereType<Map<String, dynamic>>().map(
              FeedPostModel.fromJson,
            ),
          );
      }
      totalDatabasePosts =
          (data['totalDatabasePosts'] as num?)?.toInt() ??
          communityPosts.length;

      final rawProfilePosts = data['profilePosts'];
      if (rawProfilePosts is List) {
        profilePosts
          ..clear()
          ..addAll(
            rawProfilePosts
                .whereType<Map<String, dynamic>>()
                .map(FeedPostModel.fromJson)
                .where(
                  (post) =>
                      post.id.isNotEmpty &&
                      post.authorAccountId == currentUser.accountId,
                ),
          );
      }

      final rawGroups = data['groups'];
      if (rawGroups is List) {
        groups
          ..clear()
          ..addAll(
            rawGroups.whereType<Map<String, dynamic>>().map(
              CommunityGroupModel.fromJson,
            ),
          );
      }

      final rawFollowers = data['discoverMembers'] ?? data['followers'];
      if (rawFollowers is List) {
        followers
          ..clear()
          ..addAll(
            rawFollowers.whereType<Map<String, dynamic>>().map(
              FollowerUserModel.fromJson,
            ),
          );
      }
      totalDatabaseMembers =
          (data['totalDatabaseMembers'] as num?)?.toInt() ??
          totalDatabaseMembers;

      final rawSafety = data['safety'];
      final rawContacts =
          data['emergencyContacts'] ??
          (rawSafety is Map<String, dynamic>
              ? rawSafety['emergencyContacts']
              : null);
      if (rawContacts is List) {
        emergencyContacts
          ..clear()
          ..addAll(
            rawContacts.whereType<Map<String, dynamic>>().map(
              EmergencyContactModel.fromJson,
            ),
          );
      }

      final rawBlocked = data['blockedUsers'];
      if (rawBlocked is List) {
        blockedUsers
          ..clear()
          ..addAll(
            rawBlocked.whereType<Map<String, dynamic>>().map(
              BlockedUserModel.fromJson,
            ),
          );
      }

      final rawPrivacy = data['privacySettings'];
      if (rawPrivacy is Map<String, dynamic>) {
        for (final setting in privacySettings) {
          final rawValue = rawPrivacy[setting.id];
          if (rawValue == null) continue;
          final value = rawValue.toString().trim();
          final normalized = value.toLowerCase().replaceAll('_', ' ');
          setting.selectedValue = switch (setting.id) {
            'view_profile' || 'see_posts' =>
              normalized.contains('follower')
                  ? 'Followers Only'
                  : normalized.contains('circle')
                  ? 'Circle Members Only'
                  : 'All Verified Members',
            'message_me' =>
              normalized.contains('no one') ||
                      normalized == 'none' ||
                      normalized == 'no'
                  ? 'No One'
                  : normalized.contains('follower')
                  ? 'Followers Only'
                  : 'All Verified Members',
            'show_location' =>
              normalized.contains('hide') ||
                      normalized == 'hidden' ||
                      normalized == 'no location' ||
                      normalized == 'no'
                  ? 'Hide Location'
                  : normalized.contains('follower')
                  ? 'Followers Only'
                  : 'Verified Members',
            'search_results' =>
              normalized == 'no' || normalized == 'false' ? 'No' : 'Yes',
            'business_enquiries' =>
              normalized.contains('verified business')
                  ? 'Verified businesses only'
                  : normalized == 'no' || normalized == 'false'
                  ? 'No'
                  : 'Yes',
            _ => value,
          };
        }
      }
      final rawNotificationPreferences = data['notificationPreferences'];
      if (rawNotificationPreferences is Map<String, dynamic>) {
        for (final preference in notificationPreferences) {
          final value = rawNotificationPreferences[preference.id];
          if (value is bool) preference.isEnabled = value;
        }
      }

      _isBackendSynced = true;
      lastSyncError = null;
      lastSyncSource = 'PostgreSQL Live DB';
    } catch (_) {
      _isBackendSynced = false;
      lastSyncError = 'Live Sakhi data could not be loaded. Check the connection and retry.';
      lastSyncSource = 'Backend unavailable';
    } finally {
      _isBackendSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _sendAuthenticatedRequest(
    Future<void> Function(BackendApiClient client) action,
  ) async {
    try {
      final token = await _client.readAccessToken();
      if (token == null || token.isEmpty) return;
      await action(_client);
    } catch (_) {
      // Optimistic UI remains responsive if backend is offline.
    }
  }

  Future<bool?> checkUsernameAvailability(String username) async {
    final clean = username.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();
    if (clean.length < 3 || !RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(clean)) {
      return false;
    }
    final ownHandle = currentUser.username
        .trim()
        .replaceFirst(RegExp(r'^@'), '')
        .toLowerCase();
    if (ownHandle.isNotEmpty && clean == ownHandle) {
      return true;
    }
    // Immediate local case-insensitive uniqueness check against known directory & posts
    for (final m in followers) {
      final existing = m.username
          .trim()
          .replaceFirst(RegExp(r'^@'), '')
          .toLowerCase();
      if (existing == clean && m.id != currentUser.accountId) {
        return false;
      }
    }
    for (final p in [...communityPosts, ...exploreRecommendedPosts]) {
      final existing = p.authorUsername
          .trim()
          .replaceFirst(RegExp(r'^@'), '')
          .toLowerCase();
      if (existing == clean && p.authorAccountId != currentUser.accountId) {
        return false;
      }
    }
    final query = Uri(queryParameters: {'username': '@$clean'}).query;
    try {
      final token = await _client.readAccessToken();
      if (token != null && token.isNotEmpty) {
        final response = await _client.get(
          'module2/username-availability?$query',
          authenticated: true,
        );
        if (response['available'] is bool) {
          return response['available'] as bool;
        }
      }
    } catch (_) {}
    try {
      final response = await _client.get(
        'auth/username-availability?$query',
        authenticated: false,
      );
      if (response['available'] is bool) {
        return response['available'] as bool;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> updateProfile({
    required String displayName,
    String? username,
    required String bio,
    required String location,
    List<String>? interests,
    String? email,
    String? businessProfileUrl,
    String? avatarAsset,
  }) async {
    final normalizedName = displayName.trim();
    final normalizedUsername = username?.trim();
    if (normalizedName.isEmpty) return false;

    final oldName = currentUser.displayName;
    final oldUsername = currentUser.username;
    final oldBio = currentUser.bio;
    final oldLocation = currentUser.location;
    final oldInterests = List<String>.from(currentUser.interests);
    final oldEmail = currentUser.email;
    final oldBusinessProfileUrl = currentUser.businessProfileUrl;
    final oldAvatarAsset = currentUser.avatarAsset;

    final token = await _client.readAccessToken();
    final hasSession = token != null && token.isNotEmpty;
    if (_isBackendSynced && !hasSession) return false;

    currentUser.displayName = normalizedName;
    if (normalizedUsername != null && normalizedUsername.isNotEmpty) {
      currentUser.username = normalizedUsername.startsWith('@')
          ? normalizedUsername
          : '@$normalizedUsername';
    }
    currentUser.bio = bio.trim();
    currentUser.location = location.trim();
    if (interests != null) {
      currentUser.interests = List<String>.unmodifiable(
        interests.map((item) => item.trim()).where((item) => item.isNotEmpty),
      );
    }
    if (email != null) currentUser.email = email.trim();
    if (businessProfileUrl != null) {
      currentUser.businessProfileUrl = businessProfileUrl.trim().isEmpty
          ? null
          : businessProfileUrl.trim();
    }
    if (avatarAsset != null && avatarAsset.trim().isNotEmpty) {
      currentUser.avatarAsset = avatarAsset.trim();
    }
    notifyListeners();

    if (!hasSession) {
      return true;
    }

    try {
      final response = await _client.put(
        'module2/profile',
        authenticated: true,
        body: {
          'displayName': normalizedName,
          if (normalizedUsername != null &&
              normalizedUsername.isNotEmpty &&
              normalizedUsername != '@')
            'username': normalizedUsername.startsWith('@')
                ? normalizedUsername
                : '@$normalizedUsername',
          'bio': bio.trim(),
          'location': location.trim(),
          if (interests != null) 'interests': currentUser.interests,
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
          if (businessProfileUrl != null &&
              businessProfileUrl.trim().isNotEmpty)
            'businessProfileUrl': businessProfileUrl.trim(),
          if (avatarAsset != null && avatarAsset.trim().isNotEmpty)
            'avatarAsset': avatarAsset.trim(),
        },
      );
      if (response['displayName'] is String) {
        currentUser.displayName = response['displayName'] as String;
      }
      if (response['username'] is String) {
        currentUser.username = response['username'] as String;
      }
      if (response['bio'] is String) {
        currentUser.bio = response['bio'] as String;
      }
      if (response['location'] is String) {
        currentUser.location = response['location'] as String;
      }
      if (response['email'] is String || response.containsKey('email')) {
        currentUser.email = response['email']?.toString() ?? '';
      }
      final rawInterests = response['interests'];
      if (rawInterests is List) {
        currentUser.interests = rawInterests
            .map((item) => item.toString())
            .toList(growable: false);
      }
      if (response['businessProfileUrl'] is String ||
          response.containsKey('businessProfileUrl')) {
        currentUser.businessProfileUrl = response['businessProfileUrl']
            ?.toString();
      }
      if (response['avatarAsset'] is String &&
          (response['avatarAsset'] as String).isNotEmpty) {
        currentUser.avatarAsset = response['avatarAsset'] as String;
      }
      notifyListeners();
      return true;
    } catch (_) {
      currentUser
        ..displayName = oldName
        ..username = oldUsername
        ..bio = oldBio
        ..location = oldLocation
        ..interests = oldInterests
        ..email = oldEmail
        ..businessProfileUrl = oldBusinessProfileUrl
        ..avatarAsset = oldAvatarAsset;
      notifyListeners();
      return false;
    }
  }

  /// Uploads a binary media file (`profile_photo` or `community_post`) to the
  /// backend Google Drive hierarchy (`/api/v1/module2/media/upload`).
  Future<Map<String, String>?> uploadMediaFile({
    required String purpose,
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
    String categorySlug = 'community',
    String cropAspectRatio = '4:5',
  }) async {
    try {
      final token = await _client.readAccessToken();
      if (token == null || token.isEmpty) return null;
      final normalizedPurpose =
          (purpose == 'avatar' || purpose == 'profile_photo')
          ? 'profile_photo'
          : 'community_post';
      final response = await _client.postMultipart(
        'module2/media/upload',
        authenticated: true,
        fields: {
          'purpose': normalizedPurpose,
          'categorySlug': categorySlug,
          'cropAspectRatio': cropAspectRatio,
        },
        fileBytes: fileBytes,
        fileName: fileName,
        contentType: contentType,
      );
      final mediaUrl =
          (response['mediaUrl'] ??
                  response['mediaAsset'] ??
                  response['publicUrl'] ??
                  '')
              .toString();
      final uploadId = (response['uploadId'] ?? response['mediaId'] ?? '')
          .toString();
      if (mediaUrl.isNotEmpty && uploadId.isNotEmpty) {
        if (normalizedPurpose == 'profile_photo') {
          currentUser.avatarAsset = mediaUrl;
          notifyListeners();
        }
        return {'uploadId': uploadId, 'mediaUrl': mediaUrl};
      }
    } catch (_) {}
    return null;
  }

  Future<String?> uploadMediaToCloud({
    required String purpose,
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
    String categorySlug = 'community',
    String cropAspectRatio = '4:5',
  }) async {
    final result = await uploadMediaFile(
      purpose: purpose,
      fileName: fileName,
      fileBytes: fileBytes,
      contentType: contentType,
      categorySlug: categorySlug,
      cropAspectRatio: cropAspectRatio,
    );
    return result?['mediaUrl'];
  }

  void updateAvatar(String avatarAssetOrUrl) {
    final trimmed = avatarAssetOrUrl.trim();
    if (trimmed.isEmpty) return;
    currentUser.avatarAsset = trimmed;
    notifyListeners();

    unawaited(
      _sendAuthenticatedRequest((client) async {
        await client.put(
          'module2/profile',
          authenticated: true,
          body: {
            if (trimmed.startsWith('assets/images/profile/'))
              'avatarAsset': trimmed,
          },
        );
      }),
    );
  }

  Future<bool> addInterest(String interest) async {
    final trimmed = interest.trim();
    if (trimmed.isNotEmpty && !currentUser.interests.contains(trimmed)) {
      currentUser.interests.add(trimmed);
      notifyListeners();
      unawaited(
        _sendAuthenticatedRequest((client) async {
          await client.post(
            'module2/interests',
            authenticated: true,
            body: {'label': trimmed},
          );
        }),
      );
      return true;
    }
    return false;
  }

  Future<bool> removeInterest(String interest) async {
    currentUser.interests.remove(interest);
    notifyListeners();
    unawaited(
      _sendAuthenticatedRequest((client) async {
        await client.delete(
          'module2/interests/${Uri.encodeComponent(interest)}',
          authenticated: true,
        );
      }),
    );
    return true;
  }

  Future<bool> createCommunityPost(
    String content, {
    String? categoryBadge,
    String categorySlug = 'community',
    String visibility = 'VERIFIED_MEMBERS',
    String cropPreset = '4:5',
    List<String> hashtags = const [],
    String? locationTag,
    bool allowComments = true,
    bool shareToBusinessProfile = false,
    String? imageAsset,
    List<String> mediaUploadIds = const [],
  }) async {
    final trimmed = content.trim();
    final hasLocalAsset =
        imageAsset != null && imageAsset.trim().startsWith('assets/');
    if (trimmed.isEmpty && !hasLocalAsset && mediaUploadIds.isEmpty) {
      return false;
    }

    try {
      final token = await _client.readAccessToken();
      if (token == null || token.isEmpty) return false;
      final created = await _client.post(
        'module2/posts',
        authenticated: true,
        body: {
          'content': trimmed,
          'categoryBadge': categoryBadge ?? categorySlug,
          'categorySlug': categorySlug,
          'visibility': visibility,
          'cropPreset': cropPreset,
          'hashtags': hashtags,
          if (locationTag != null && locationTag.trim().isNotEmpty)
            'locationTag': locationTag.trim(),
          'allowComments': allowComments,
          'shareToBusinessProfile': shareToBusinessProfile,
          if (hasLocalAsset) 'imageAsset': imageAsset.trim(),
          if (mediaUploadIds.isNotEmpty) 'mediaUploadIds': mediaUploadIds,
        },
      );
      final postMap = created['post'] is Map<String, dynamic>
          ? created['post'] as Map<String, dynamic>
          : created;
      final serverId = postMap['id']?.toString() ?? '';
      if (serverId.isEmpty || serverId.startsWith('custom_')) return false;

      final parsed = FeedPostModel.fromJson(postMap);
      communityPosts.removeWhere((post) => post.id == parsed.id);
      communityPosts.insert(0, parsed);
      profilePosts.removeWhere(
        (post) =>
            post.id == parsed.id ||
            (post.authorAccountId.isNotEmpty &&
                post.authorAccountId == currentUser.accountId &&
                post.id.startsWith('custom_')),
      );
      if (parsed.authorAccountId == currentUser.accountId) {
        profilePosts.insert(0, parsed);
      }
      currentUser.postsCount =
          (created['postsCount'] as num?)?.toInt() ??
          currentUser.postsCount + 1;
      _isBackendSynced = true;
      lastSyncError = null;
      notifyListeners();
      return true;
    } catch (_) {
      // A failed API call never leaves a fake locally published post behind.
      return false;
    }
  }

  Future<bool> updatePost(
    FeedPostModel post, {
    required String content,
    String? categorySlug,
    String? visibility,
    String? locationTag,
    bool? allowComments,
  }) async {
    final nextContent = content.trim();
    if (nextContent.isEmpty || nextContent.length > 2000) return false;

    final isServerPost = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(post.id);
    if (isServerPost) {
      try {
        await _client.patch(
          'module2/posts/${post.id}',
          authenticated: true,
          body: {
            'body': nextContent,
            'categorySlug': ?categorySlug,
            'visibility': ?visibility,
            'locationTag': ?locationTag,
            'allowComments': ?allowComments,
          },
        );
      } catch (_) {
        return false;
      }
    } else if (_isBackendSynced) {
      return false;
    }

    post.content = nextContent;
    if (categorySlug != null) post.categorySlug = categorySlug;
    if (visibility != null) post.visibility = visibility;
    if (locationTag != null) post.locationTag = locationTag;
    if (allowComments != null) post.allowComments = allowComments;
    notifyListeners();
    return true;
  }

  Future<bool> deletePost(dynamic postOrId) async {
    final postId = postOrId is FeedPostModel
        ? postOrId.id
        : postOrId.toString();
    final isServerPost = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(postId);
    if (isServerPost) {
      try {
        await _client.delete('module2/posts/$postId', authenticated: true);
      } catch (_) {
        return false;
      }
    } else if (_isBackendSynced) {
      return false;
    }

    final matches = <FeedPostModel>[
      ...communityPosts.where((item) => item.id == postId),
      ...profilePosts.where((item) => item.id == postId),
    ];
    final wasOwn = matches.any(
      (item) =>
          item.isOwnPost ||
          (item.authorAccountId.isNotEmpty &&
              item.authorAccountId == currentUser.accountId),
    );
    communityPosts.removeWhere((item) => item.id == postId);
    exploreRecommendedPosts.removeWhere((item) => item.id == postId);
    profilePosts.removeWhere((item) => item.id == postId);
    if (wasOwn) {
      currentUser.postsCount = (currentUser.postsCount - 1).clamp(0, 9999);
    }
    notifyListeners();
    return true;
  }

  Future<bool> reactToPost(FeedPostModel post, String reactionType) async {
    final isServerPost = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(post.id);
    if (!isServerPost && _isBackendSynced) return false;

    final previousReaction = post.viewerReaction;
    final previousLiked = post.isLiked;
    final previousCount = post.likesCount;
    final previousBreakdown = Map<String, int>.from(post.reactionBreakdown);
    final isRemoving = previousReaction == reactionType;

    if (previousReaction != null) {
      final oldVal = (post.reactionBreakdown[previousReaction] ?? 1) - 1;
      if (oldVal <= 0) {
        post.reactionBreakdown.remove(previousReaction);
      } else {
        post.reactionBreakdown[previousReaction] = oldVal;
      }
    }
    if (!isRemoving) {
      post.reactionBreakdown[reactionType] =
          (post.reactionBreakdown[reactionType] ?? 0) + 1;
    }
    final delta = isRemoving ? -1 : (previousReaction == null ? 1 : 0);
    post.likesCount = (post.likesCount + delta).clamp(0, 999999);
    post.viewerReaction = isRemoving ? null : reactionType;
    post.isLiked = !isRemoving;
    notifyListeners();

    if (!isServerPost) return true;
    try {
      final response = await _client.post(
        'module2/posts/${post.id}/react',
        authenticated: true,
        body: {'reactionType': reactionType},
      );
      post.viewerReaction = response['viewerReaction'] as String?;
      post.isLiked = response['isLiked'] == true;
      post.likesCount =
          (response['likesCount'] as num?)?.toInt() ?? post.likesCount;
      post.reactionBreakdown
        ..clear()
        ..addAll(
          (response['reactionBreakdown'] is Map)
              ? (response['reactionBreakdown'] as Map).map(
                  (key, value) => MapEntry(
                    key.toString(),
                    value is num ? value.toInt() : 0,
                  ),
                )
              : previousBreakdown,
        );
      notifyListeners();
      return true;
    } catch (_) {
      post.viewerReaction = previousReaction;
      post.isLiked = previousLiked;
      post.likesCount = previousCount;
      post.reactionBreakdown
        ..clear()
        ..addAll(previousBreakdown);
      notifyListeners();
      return false;
    }
  }

  /// Loads actual followed/follower member records. Null indicates a
  /// connection/API failure; an empty list is a confirmed empty result.
  Future<List<FollowerUserModel>?> fetchMemberConnections({
    required bool following,
    String? targetMemberId,
  }) async {
    if (targetMemberId != null && targetMemberId.trim().isNotEmpty) {
      return fetchTargetMemberConnections(
        targetMemberId.trim(),
        following: following,
      );
    }
    if (!_isBackendSynced) return null;
    final token = await _client.readAccessToken();
    if (token == null || token.isEmpty) return null;
    try {
      final response = await _client.get(
        following ? 'module2/members/following' : 'module2/members/followers',
        authenticated: true,
      );
      final rawItems = response['items'];
      if (rawItems is! List) return <FollowerUserModel>[];
      return rawItems
          .whereType<Map<String, dynamic>>()
          .map(FollowerUserModel.fromJson)
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  Future<List<FollowerUserModel>?> fetchTargetMemberConnections(
    String targetId, {
    required bool following,
  }) async {
    try {
      final token = await _client.readAccessToken();
      if (token == null || token.isEmpty) return null;
      final type = following ? 'following' : 'followers';
      final response = await _client.get(
        'module2/members/${Uri.encodeComponent(targetId)}/connections?mode=$type&type=$type',
        authenticated: true,
      );
      final rawItems = response['items'] ?? response['members'];
      if (rawItems is! List) return <FollowerUserModel>[];
      return rawItems
          .whereType<Map<String, dynamic>>()
          .map(FollowerUserModel.fromJson)
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchTargetMemberProfileOverview(
    String targetId,
  ) async {
    try {
      final token = await _client.readAccessToken();
      if (token == null || token.isEmpty) return null;
      final response = await _client.get(
        'module2/members/${Uri.encodeComponent(targetId)}/profile-overview',
        authenticated: true,
      );
      return response;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchNearbyCircles({
    double? lat,
    double? lng,
    double radiusKm = 25,
    String? city,
  }) async {
    try {
      final token = await _client.readAccessToken();
      final params = <String, String>{
        'radiusKm': radiusKm.toStringAsFixed(0),
        if (lat != null && lat.isFinite) 'lat': lat.toStringAsFixed(5),
        if (lng != null && lng.isFinite) 'lng': lng.toStringAsFixed(5),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      };
      final qs = Uri(queryParameters: params).query;
      final response = await _client.get(
        'module2/nearby-circles?$qs',
        authenticated: token != null && token.isNotEmpty,
      );
      return response;
    } catch (_) {
      return null;
    }
  }

  Future<bool> toggleFollowSearchMember(FollowerUserModel member) async {
    if (!member.canFollow || member.id.isEmpty) return false;
    final isServerMember = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(member.id);
    if (_isBackendSynced && !isServerMember) return false;

    final previousFollowing = member.isFollowing;
    final previousCount = currentUser.followingCount;
    member.isFollowing = !previousFollowing;
    currentUser.followingCount = (previousCount + (member.isFollowing ? 1 : -1))
        .clamp(0, 999999);
    notifyListeners();

    if (!isServerMember) return true;
    try {
      final response = await _client.post(
        'module2/members/${member.id}/follow',
        authenticated: true,
      );
      final confirmed = response['isFollowing'];
      if (confirmed is! bool) {
        member.isFollowing = previousFollowing;
        currentUser.followingCount = previousCount;
        notifyListeners();
        return false;
      }
      member.isFollowing = confirmed;
      currentUser.followingCount = (previousCount + (confirmed ? 1 : -1)).clamp(
        0,
        999999,
      );
      final index = followers.indexWhere(
        (item) => item.id == member.id || item.username == member.username,
      );
      if (index >= 0) followers[index].isFollowing = confirmed;
      notifyListeners();
      return true;
    } catch (_) {
      member.isFollowing = previousFollowing;
      currentUser.followingCount = previousCount;
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleFollow(String followerId) async {
    final idx = followers.indexWhere(
      (f) => f.id == followerId || f.username == followerId,
    );
    if (idx == -1) return false;

    final member = followers[idx];
    final previousFollowing = member.isFollowing;
    final previousCount = currentUser.followingCount;
    final isServerMember = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(member.id);
    if (!isServerMember && _isBackendSynced) return false;

    member.isFollowing = !previousFollowing;
    currentUser.followingCount = (previousCount + (member.isFollowing ? 1 : -1))
        .clamp(0, 999999);
    notifyListeners();

    if (!isServerMember) return true;
    try {
      final response = await _client.post(
        'module2/members/${member.id}/follow',
        authenticated: true,
      );
      final confirmed = response['isFollowing'];
      if (confirmed is bool) {
        member.isFollowing = confirmed;
        currentUser.followingCount = (previousCount + (confirmed ? 1 : -1))
            .clamp(0, 999999);
      }
      notifyListeners();
      return true;
    } catch (_) {
      member.isFollowing = previousFollowing;
      currentUser.followingCount = previousCount;
      notifyListeners();
      return false;
    }
  }

  Future<bool> togglePostLike(dynamic postOrId) async {
    final post = postOrId is FeedPostModel
        ? postOrId
        : _findPost(postOrId.toString());
    if (post == null) return false;
    return reactToPost(post, 'LIKE');
  }

  Future<bool> togglePostSaved(dynamic postOrId) async {
    final post = postOrId is FeedPostModel
        ? postOrId
        : _findPost(postOrId.toString());
    if (post == null) return false;

    final isServerPost = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(post.id);
    if (!isServerPost && _isBackendSynced) return false;
    final previousSaved = post.isSaved;
    final previousCount = post.savesCount;

    post.isSaved = !previousSaved;
    post.savesCount = (previousCount + (post.isSaved ? 1 : -1)).clamp(
      0,
      999999,
    );
    notifyListeners();

    if (!isServerPost) return true;
    try {
      final response = await _client.post(
        'module2/posts/${post.id}/save',
        authenticated: true,
      );
      if (response['isSaved'] is bool) {
        post.isSaved = response['isSaved'] as bool;
        post.savesCount =
            (response['savesCount'] as num?)?.toInt() ??
            (previousCount + (post.isSaved ? 1 : -1)).clamp(0, 999999);
        notifyListeners();
      }
      return true;
    } catch (_) {
      post.isSaved = previousSaved;
      post.savesCount = previousCount;
      notifyListeners();
      return false;
    }
  }

  FeedPostModel? _findPost(String postId) {
    for (final collection in [
      communityPosts,
      exploreRecommendedPosts,
      profilePosts,
    ]) {
      for (final post in collection) {
        if (post.id == postId) return post;
      }
    }
    return null;
  }

  Future<bool> addPostComment(
    FeedPostModel post,
    String commentText, {
    String? parentCommentId,
    String? replyToHandle,
  }) async {
    final trimmed = commentText.trim();
    if (trimmed.isEmpty || trimmed.length > 500 || !post.allowComments) {
      return false;
    }
    final isServerPost = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(post.id);
    if (!isServerPost && _isBackendSynced) return false;

    final item = PostCommentItem(
      id: 'pending_${DateTime.now().microsecondsSinceEpoch}',
      authorAccountId: currentUser.accountId,
      authorName: currentUser.displayName,
      authorUsername: currentUser.username,
      authorAvatar: currentUser.avatarAsset,
      body: trimmed,
      createdAt: 'Just now',
      parentCommentId: parentCommentId,
      replyToHandle: replyToHandle,
      isOwnComment: true,
      canEdit: true,
      canDelete: true,
    );
    post.comments.add(item);
    post.commentsCount++;
    notifyListeners();

    if (!isServerPost) return true;
    try {
      final response = await _client.post(
        'module2/posts/${post.id}/comments',
        authenticated: true,
        body: {
          'body': trimmed,
          'content': trimmed,
          if (parentCommentId != null && parentCommentId.isNotEmpty)
            'parentCommentId': parentCommentId,
          if (replyToHandle != null && replyToHandle.isNotEmpty)
            'replyToHandle': replyToHandle,
        },
      );
      final raw = response['comment'] ?? response;
      if (raw is Map) {
        final serverJson = Map<String, dynamic>.from(raw);
        serverJson['id'] ??= serverJson['commentId'];
        serverJson['body'] ??= serverJson['content'] ?? trimmed;
        serverJson['authorAccountId'] ??= currentUser.accountId;
        serverJson['authorName'] ??= currentUser.displayName;
        serverJson['authorUsername'] ??= currentUser.username;
        serverJson['authorAvatar'] ??= currentUser.avatarAsset;
        final serverComment = PostCommentItem.fromJson(serverJson);
        final idx = post.comments.indexWhere(
          (comment) => comment.id == item.id,
        );
        if (idx != -1 && serverComment.id.isNotEmpty) {
          post.comments[idx] = serverComment;
        }
      }
      notifyListeners();
      return true;
    } catch (_) {
      post.comments.removeWhere((comment) => comment.id == item.id);
      post.commentsCount = (post.commentsCount - 1).clamp(0, 999999);
      notifyListeners();
      return false;
    }
  }

  Future<bool> addComment(String postId, String text) async {
    final post = _findPost(postId);
    if (post == null) return false;
    return addPostComment(post, text);
  }

  Future<bool> editComment(
    String postId,
    String commentId,
    String newBody,
  ) async {
    final trimmed = newBody.trim();
    if (trimmed.isEmpty || trimmed.length > 500) return false;
    final post = _findPost(postId);
    if (post == null) return false;
    final cIdx = post.comments.indexWhere((comment) => comment.id == commentId);
    if (cIdx == -1) return false;
    final isServerPost = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(postId);
    final isServerComment = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(commentId);
    if (_isBackendSynced && (!isServerPost || !isServerComment)) {
      return false;
    }

    if (isServerPost && isServerComment) {
      try {
        await _client.patch(
          'module2/posts/$postId/comments/$commentId',
          authenticated: true,
          body: {'body': trimmed},
        );
      } catch (_) {
        return false;
      }
    }
    post.comments[cIdx].body = trimmed;
    notifyListeners();
    return true;
  }

  Future<bool> removeComment(String postId, String commentId) async {
    final post = _findPost(postId);
    if (post == null) return false;
    final cIdx = post.comments.indexWhere((comment) => comment.id == commentId);
    if (cIdx == -1) return false;
    final isServerPost = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(postId);
    final isServerComment = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(commentId);
    if (_isBackendSynced && (!isServerPost || !isServerComment)) return false;

    if (isServerPost && isServerComment) {
      try {
        await _client.delete(
          'module2/posts/$postId/comments/$commentId',
          authenticated: true,
        );
      } catch (_) {
        return false;
      }
    }
    post.comments.removeAt(cIdx);
    post.commentsCount = (post.commentsCount - 1).clamp(0, 999999);
    notifyListeners();
    return true;
  }

  Future<bool> updatePrivacySetting(String id, String newValue) async {
    final idx = privacySettings.indexWhere((setting) => setting.id == id);
    if (idx == -1) return false;

    final previousValue = privacySettings[idx].selectedValue;
    if ((id == 'view_profile' || id == 'see_posts') &&
        newValue == 'Circle Members Only') {
      return false;
    }

    final token = await _client.readAccessToken();
    final hasSession = token != null && token.isNotEmpty;
    if (_isBackendSynced && !hasSession) return false;

    privacySettings[idx].selectedValue = newValue;
    notifyListeners();
    if (!hasSession) return true;

    final apiValue = switch (id) {
      'view_profile' || 'see_posts' =>
        newValue == 'Followers Only'
            ? 'Followers only'
            : 'Verified members only',
      'message_me' =>
        newValue == 'No One'
            ? 'No one'
            : newValue == 'Followers Only'
            ? 'Followers only'
            : 'Verified members only',
      'show_location' =>
        newValue == 'Hide Location'
            ? 'No location'
            : newValue == 'Followers Only'
            ? 'Followers only'
            : 'General location only',
      'search_results' => newValue == 'No' ? 'No' : 'Yes',
      'business_enquiries' =>
        newValue == 'No'
            ? 'No'
            : newValue == 'Verified businesses only'
            ? 'Verified businesses only'
            : 'Yes',
      _ => newValue,
    };

    try {
      await _client.put(
        'module2/privacy',
        authenticated: true,
        body: {'settingId': id, 'selectedValue': apiValue},
      );
      return true;
    } catch (_) {
      privacySettings[idx].selectedValue = previousValue;
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleNotificationPref(String id, bool value) async {
    final idx = notificationPreferences.indexWhere((item) => item.id == id);
    if (idx == -1) return false;

    final previousValue = notificationPreferences[idx].isEnabled;
    final token = await _client.readAccessToken();
    final hasSession = token != null && token.isNotEmpty;
    if (_isBackendSynced && !hasSession) return false;

    notificationPreferences[idx].isEnabled = value;
    notifyListeners();
    if (!hasSession) return true;

    try {
      await _client.put(
        'module2/notifications',
        authenticated: true,
        body: {'prefId': id, 'isEnabled': value},
      );
      return true;
    } catch (_) {
      notificationPreferences[idx].isEnabled = previousValue;
      notifyListeners();
      return false;
    }
  }

  Future<bool> setMarketingConsent(bool accepted) async {
    return toggleNotificationPref('marketing_updates', accepted);
  }

  void recordSafetyEvent(String eventType, {String? locationLabel}) {
    unawaited(
      _sendAuthenticatedRequest((client) async {
        await client.post(
          'module2/safety/check-ins',
          authenticated: true,
          body: {
            'status': 'SAFE',
            'locationArea': ?locationLabel,
            'note': eventType,
          },
        );
      }),
    );
  }

  void addEmergencyContact({
    required String name,
    required String relationship,
    required String phoneE164,
  }) {
    emergencyContacts.add(
      EmergencyContactModel(
        id: 'ec_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        relationship: relationship,
        phoneE164: phoneE164,
      ),
    );
    notifyListeners();

    unawaited(
      _sendAuthenticatedRequest((client) async {
        await client.post(
          'module2/safety/contacts',
          authenticated: true,
          body: {
            'contactName': name,
            'relationship': relationship,
            'phoneNumber': phoneE164,
          },
        );
      }),
    );
  }

  void toggleTwoFactor() {
    currentUser.twoFactorEnabled = !currentUser.twoFactorEnabled;
    notifyListeners();

    unawaited(
      _sendAuthenticatedRequest((client) async {
        await client.put(
          'module2/security/two-factor',
          authenticated: true,
          body: {
            'enabled': currentUser.twoFactorEnabled,
            'twoFactorEnabled': currentUser.twoFactorEnabled,
          },
        );
      }),
    );
  }

  void updateSecurityPin(String newPin, {String? currentPin}) {
    unawaited(
      _sendAuthenticatedRequest((client) async {
        await client.put(
          'module2/security/pin',
          authenticated: true,
          body: {
            'currentPin': currentPin ?? '0000',
            'newPin': newPin,
            'pin': newPin,
          },
        );
      }),
    );
  }

  Future<bool> requestAccountDeletion({String? reason}) async {
    try {
      final token = await _client.readAccessToken();
      if (token == null || token.isEmpty) return true;
      await _client.post(
        'module2/account/delete',
        authenticated: true,
        body: {
          'confirmation': 'DELETE',
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> reportUserOrPost({
    required String targetHandle,
    required String reason,
    String? postId,
    String? category,
    String? details,
  }) async {
    final target = targetHandle.trim();
    final normalizedReason = reason.trim();
    if (target.isEmpty || normalizedReason.length < 3) return false;
    final isServerPost =
        postId != null && RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(postId);
    if (_isBackendSynced && postId != null && !isServerPost) return false;

    if (_isBackendSynced || isServerPost) {
      try {
        final response = await _client.post(
          'module2/reports',
          authenticated: true,
          body: {
            'targetHandle': target,
            'targetType': postId == null ? 'member' : 'post',
            if (isServerPost) 'postId': postId,
            'category': category ?? 'inappropriate_content',
            'reason': normalizedReason,
            if (details != null && details.trim().isNotEmpty)
              'details': details.trim(),
          },
        );
        return response['reportId'] != null || response['status'] != null;
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  Future<bool> reportMember({
    String? accountId,
    String? reportedAccountId,
    String? targetHandle,
    String? postId,
    String? commentId,
    String? reason,
    String? reasonCode,
    String? details,
  }) async {
    return reportUserOrPost(
      targetHandle: targetHandle ?? reportedAccountId ?? accountId ?? '',
      reason: reason ?? reasonCode ?? 'inappropriate_content',
      postId: postId,
      category: reasonCode ?? reason ?? 'inappropriate_content',
      details: details,
    );
  }

  Future<bool> toggleBlockedUser({
    required String username,
    required String displayName,
    String? accountId,
  }) async {
    final trimmedUsername = username.trim();
    if (trimmedUsername.isEmpty) return false;

    if (_isBackendSynced) {
      try {
        final response = await _client.post(
          'module2/moderation/block',
          authenticated: true,
          body: {
            'blockedUsername': trimmedUsername,
            'blockedDisplayName': displayName.trim().isEmpty
                ? trimmedUsername
                : displayName.trim(),
          },
        );
        final blocked = response['isBlocked'] as bool?;
        if (blocked == null) return false;
        blockedUsers.removeWhere(
          (item) => item.blockedUsername == trimmedUsername,
        );
        if (blocked) {
          blockedUsers.add(
            BlockedUserModel(
              id: (response['id'] ?? accountId ?? trimmedUsername).toString(),
              blockedUsername: trimmedUsername,
              blockedDisplayName: displayName,
            ),
          );
          communityPosts.removeWhere(
            (post) =>
                post.authorUsername == trimmedUsername ||
                post.authorName == displayName,
          );
        } else {
          unawaited(syncFromBackend());
        }
        notifyListeners();
        return true;
      } catch (_) {
        return false;
      }
    }

    final idx = blockedUsers.indexWhere(
      (item) => item.blockedUsername == trimmedUsername,
    );
    if (idx != -1) {
      blockedUsers.removeAt(idx);
    } else {
      blockedUsers.add(
        BlockedUserModel(
          id: accountId ?? 'blk_${DateTime.now().millisecondsSinceEpoch}',
          blockedUsername: trimmedUsername,
          blockedDisplayName: displayName,
        ),
      );
      communityPosts.removeWhere(
        (post) =>
            post.authorUsername == trimmedUsername ||
            post.authorName == displayName,
      );
    }
    notifyListeners();
    return true;
  }

  // ===========================================================================
  // UNIVERSAL POST AUTHOR FOLLOW & ENTERPRISE TRENDING ALGORITHM
  // ===========================================================================
  bool isFollowingAuthor(FeedPostModel post) {
    final handle = post.authorUsername
        .trim()
        .replaceFirst(RegExp(r'^@'), '')
        .toLowerCase();
    for (final f in followers) {
      if (post.authorAccountId.isNotEmpty && f.id == post.authorAccountId) {
        return f.isFollowing;
      }
      if (handle.isNotEmpty &&
          f.username.replaceFirst(RegExp(r'^@'), '').toLowerCase() == handle) {
        return f.isFollowing;
      }
      if (f.name.toLowerCase() == post.authorName.trim().toLowerCase()) {
        return f.isFollowing;
      }
    }
    return false;
  }

  Future<bool> toggleFollowPostAuthor(FeedPostModel post) async {
    final handle = post.authorUsername.trim().isNotEmpty
        ? (post.authorUsername.trim().startsWith('@')
              ? post.authorUsername.trim()
              : '@${post.authorUsername.trim()}')
        : '@${post.authorName.toLowerCase().replaceAll(' ', '_')}';
    final normalized = handle.replaceFirst(RegExp(r'^@'), '').toLowerCase();

    FollowerUserModel? existing;
    for (final f in followers) {
      if ((post.authorAccountId.isNotEmpty && f.id == post.authorAccountId) ||
          f.username.replaceFirst(RegExp(r'^@'), '').toLowerCase() ==
              normalized ||
          f.name.toLowerCase() == post.authorName.trim().toLowerCase()) {
        existing = f;
        break;
      }
    }

    if (existing == null) {
      existing = FollowerUserModel(
        id: post.authorAccountId.isNotEmpty ? post.authorAccountId : handle,
        name: post.authorName,
        username: handle,
        location: post.locationTag ?? 'India',
        avatarAsset: post.authorAvatar,
        isFollowing: false,
        isVerified: post.authorVerified,
        canFollow: true,
      );
      followers.add(existing);
    }

    final previous = existing.isFollowing;
    final previousFollowingCount = currentUser.followingCount;
    existing.isFollowing = !previous;
    currentUser.followingCount =
        (previousFollowingCount + (existing.isFollowing ? 1 : -1)).clamp(
          0,
          999999,
        );
    notifyListeners();

    try {
      final token = await _client.readAccessToken();
      if (token == null || token.isEmpty) return true;
      final targetParam = existing.id.isNotEmpty ? existing.id : handle;
      final res = await _client.post(
        'module2/members/${Uri.encodeComponent(targetParam)}/follow',
        authenticated: true,
      );
      if (res['isFollowing'] is bool) {
        existing.isFollowing = res['isFollowing'] as bool;
      }
      if (res['profileId'] is String &&
          (res['profileId'] as String).isNotEmpty) {
        existing = FollowerUserModel(
          id: res['profileId'] as String,
          name: existing.name,
          username: existing.username,
          location: existing.location,
          avatarAsset: existing.avatarAsset,
          isFollowing: existing.isFollowing,
          isVerified: existing.isVerified,
          canFollow: true,
        );
      }
      notifyListeners();
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Enterprise Multi-Signal Trending Algorithm (Instagram/YouTube/HackerNews Velocity Model).
  List<FeedPostModel> computeEnterpriseTrendingPosts(
    List<FeedPostModel> candidates,
  ) {
    double parseAgeHours(String label) {
      final lower = label.trim().toLowerCase();
      if (lower.contains('just now') || lower.contains('sec')) return 0.15;
      final numMatch = RegExp(r'(\d+)').firstMatch(lower);
      final val = numMatch != null
          ? double.tryParse(numMatch.group(1)!) ?? 1
          : 2.0;
      if (lower.contains('min')) return (val / 60.0).clamp(0.1, 24.0);
      if (lower.contains('hour') ||
          lower.contains('hr') ||
          lower.endsWith('h')) {
        return val.clamp(0.25, 720.0);
      }
      if (lower.contains('day') || lower.endsWith('d')) {
        return (val * 24.0).clamp(12.0, 2160.0);
      }
      if (lower.contains('week') || lower.endsWith('w')) {
        return val * 168.0;
      }
      return 6.0;
    }

    double score(FeedPostModel p) {
      final reactions = p.likesCount;
      final uniqueReactionTypes = p.reactionBreakdown.keys.length;
      final comments = p.commentsCount;
      final threadedReplies = p.comments
          .where(
            (c) =>
                (c.parentCommentId != null && c.parentCommentId!.isNotEmpty) ||
                (c.replyToHandle != null && c.replyToHandle!.isNotEmpty) ||
                c.body.trim().startsWith('@'),
          )
          .length;
      final saves = p.savesCount + (p.isSaved ? 1 : 0);
      final hasMedia = p.imageAsset != null && p.imageAsset!.trim().isNotEmpty;

      final rawEngagement =
          (reactions * 1.8) +
          (math.log(1 + reactions) / math.ln10 * 4.2) +
          (uniqueReactionTypes * 2.8) +
          (comments * 3.4) +
          (threadedReplies * 2.2) +
          (saves * 4.5);

      if (rawEngagement <= 0) return 0;

      final mediaMultiplier = hasMedia ? 1.24 : 1.0;
      final verifiedMultiplier = p.authorVerified ? 1.12 : 1.0;
      final hashtagMultiplier = p.hashtags.isNotEmpty ? 1.08 : 1.0;
      final ageHours = parseAgeHours(p.timeAgo);
      final decay = math.pow(ageHours + 2.0, 1.48);

      return (rawEngagement *
              mediaMultiplier *
              verifiedMultiplier *
              hashtagMultiplier) /
          decay;
    }

    final engaged = candidates
        .where(
          (p) =>
              p.likesCount > 0 ||
              p.commentsCount > 0 ||
              p.savesCount > 0 ||
              p.reactionBreakdown.isNotEmpty,
        )
        .toList();

    if (engaged.isEmpty) return const <FeedPostModel>[];

    engaged.sort((a, b) => score(b).compareTo(score(a)));
    return engaged;
  }

  Future<bool> joinOrCreateCommunityCircle(
    String circleName, {
    String? description,
    String category = 'Community',
  }) async {
    final trimmed = circleName.trim();
    if (trimmed.isEmpty) return false;
    final alreadyJoined = joinedCircleNames.contains(trimmed);
    if (alreadyJoined) {
      joinedCircleNames.remove(trimmed);
    } else {
      joinedCircleNames.add(trimmed);
    }
    final existingIdx = groups.indexWhere(
      (g) => g.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (existingIdx == -1 && !alreadyJoined) {
      groups.insert(
        0,
        CommunityGroupModel(
          id: 'circle_${DateTime.now().millisecondsSinceEpoch}',
          name: trimmed,
          description: description ?? 'Verified Sakhi community support circle',
          category: category,
          membersCount: 1,
          newPostsToday: 0,
        ),
      );
    } else if (existingIdx != -1) {
      final g = groups[existingIdx];
      groups[existingIdx] = CommunityGroupModel(
        id: g.id,
        name: g.name,
        description: g.description,
        category: g.category,
        membersCount: (g.membersCount + (alreadyJoined ? -1 : 1)).clamp(
          1,
          999999,
        ),
        newPostsToday: g.newPostsToday,
      );
    }
    notifyListeners();

    try {
      final token = await _client.readAccessToken();
      if (token != null && token.isNotEmpty) {
        await _client.post(
          'module2/groups/${Uri.encodeComponent(trimmed)}/join',
          authenticated: true,
        );
      }
    } catch (_) {}
    return true;
  }

  // ===========================================================================
  // MODULE 6: WOMEN-OWNED BUSINESS PAGES CLIENT METHODS (SRS Section 8.1 - 8.5)
  // ===========================================================================
  List<Map<String, dynamic>> cachedBusinesses = <Map<String, dynamic>>[];
  Map<String, dynamic>? myBusinessPage;
  List<Map<String, dynamic>> get businesses => cachedBusinesses;

  Future<Map<String, dynamic>?> fetchBusinessDetail(String businessId) async {
    if (businessId.trim().isEmpty) return null;
    try {
      final token = await _client.readAccessToken();
      final response = await _client.get(
        'module2/businesses/${Uri.encodeComponent(businessId.trim())}',
        authenticated: token != null && token.isNotEmpty,
      );
      final raw = response['business'];
      if (raw is Map<String, dynamic>) {
        final business = Map<String, dynamic>.from(raw);
        final index = cachedBusinesses.indexWhere(
          (item) => item['id']?.toString() == business['id']?.toString(),
        );
        if (index >= 0) {
          cachedBusinesses[index] = business;
        }
        if (business['isOwnBusiness'] == true) myBusinessPage = business;
        notifyListeners();
        return business;
      }
    } catch (_) {}
    for (final item in cachedBusinesses) {
      if (item['id']?.toString() == businessId ||
          item['businessCode']?.toString() == businessId) {
        return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }

  List<String> cachedBusinessCategories = <String>[
    'Fashion and clothing',
    'Beauty and personal care',
    'Food and catering',
    'Health and fitness',
    'Education and training',
    'Home services',
    'Professional consulting',
    'Art and handicrafts',
    'Retail and ecommerce',
    'Events and photography',
    'Freelancers and independent professionals',
    'Other',
  ];
  List<Map<String, dynamic>> cachedBusinessEnquiries = <Map<String, dynamic>>[];

  Future<List<Map<String, dynamic>>> fetchBusinesses({
    String? search,
    String? category,
    String? city,
    double? lat,
    double? lng,
    double? radiusKm,
    bool savedOnly = false,
    bool ownerOnly = false,
  }) async {
    try {
      final token = await _client.readAccessToken();
      final params = <String, String>{
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (category != null && category.trim().isNotEmpty && category != 'All')
          'category': category.trim(),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        if (lat != null && lat.isFinite) 'lat': lat.toStringAsFixed(5),
        if (lng != null && lng.isFinite) 'lng': lng.toStringAsFixed(5),
        if (radiusKm != null && radiusKm.isFinite)
          'radiusKm': radiusKm.toStringAsFixed(0),
        if (savedOnly) 'savedOnly': 'true',
        if (ownerOnly) 'ownerOnly': 'true',
      };
      final qs = Uri(queryParameters: params).query;
      final path = qs.isEmpty ? 'module2/businesses' : 'module2/businesses?$qs';
      final res = await _client.get(
        path,
        authenticated: token != null && token.isNotEmpty,
      );
      final rawCats = res['categories'];
      if (rawCats is List && rawCats.isNotEmpty) {
        cachedBusinessCategories = rawCats.map((e) => e.toString()).toList();
      }
      final rawList = res['businesses'] ?? res['items'];
      if (rawList is List) {
        final parsed = rawList
            .whereType<Map<String, dynamic>>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        if (ownerOnly) {
          myBusinessPage = parsed.isEmpty ? null : parsed.first;
        } else if (!savedOnly &&
            (search == null || search.isEmpty) &&
            (category == null || category == 'All') &&
            (city == null || city.isEmpty)) {
          cachedBusinesses = parsed;
        }
        notifyListeners();
        return parsed;
      }
    } catch (_) {}
    return ownerOnly ? const <Map<String, dynamic>>[] : cachedBusinesses;
  }

  Future<Map<String, dynamic>?> createOrUpdateBusiness(
    Map<String, dynamic> payload, {
    String? businessId,
  }) async {
    try {
      final res = businessId != null && businessId.trim().isNotEmpty
          ? await _client.put(
              'module2/businesses/${Uri.encodeComponent(businessId.trim())}',
              authenticated: true,
              body: payload,
            )
          : await _client.post(
              'module2/businesses',
              authenticated: true,
              body: payload,
            );
      final biz = res['business'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(res['business'] as Map<String, dynamic>)
          : Map<String, dynamic>.from(res);
      final id = biz['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        cachedBusinesses.removeWhere((b) => b['id']?.toString() == id);
        cachedBusinesses.insert(0, biz);
        myBusinessPage = biz;
        notifyListeners();
      }
      return biz;
    } catch (_) {
      return null;
    }
  }

  Future<bool> toggleSaveBusiness(String businessId) async {
    final idx = cachedBusinesses.indexWhere(
      (b) => b['id']?.toString() == businessId,
    );
    if (idx != -1) {
      final current = cachedBusinesses[idx]['isSaved'] == true;
      cachedBusinesses[idx]['isSaved'] = !current;
      final count = (cachedBusinesses[idx]['savesCount'] as num?)?.toInt() ?? 0;
      cachedBusinesses[idx]['savesCount'] = (count + (current ? -1 : 1)).clamp(
        0,
        999999,
      );
      notifyListeners();
    }
    try {
      final res = await _client.post(
        'module2/businesses/${Uri.encodeComponent(businessId)}/save',
        authenticated: true,
      );
      if (idx != -1 && res['isSaved'] is bool) {
        cachedBusinesses[idx]['isSaved'] = res['isSaved'];
        cachedBusinesses[idx]['savesCount'] =
            res['savesCount'] ?? cachedBusinesses[idx]['savesCount'];
        notifyListeners();
      }
      return true;
    } catch (_) {
      return idx != -1;
    }
  }

  Future<bool> reportBusinessListing({
    required String businessId,
    required String reason,
    String? details,
  }) async {
    try {
      await _client.post(
        'module2/businesses/${Uri.encodeComponent(businessId)}/report',
        authenticated: true,
        body: {
          'reason': reason.trim(),
          if (details != null && details.trim().isNotEmpty)
            'details': details.trim(),
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> submitBusinessEnquiry({
    required String businessId,
    required String message,
    String? subjectOrProduct,
  }) async {
    try {
      final res = await _client.post(
        'module2/businesses/${Uri.encodeComponent(businessId)}/enquiries',
        authenticated: true,
        body: {
          'message': message.trim(),
          if (subjectOrProduct != null && subjectOrProduct.trim().isNotEmpty)
            'subjectOrProduct': subjectOrProduct.trim(),
        },
      );
      final enq = res['enquiry'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(res['enquiry'] as Map<String, dynamic>)
          : null;
      if (enq != null) {
        cachedBusinessEnquiries.insert(0, enq);
        notifyListeners();
      }
      return enq;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchBusinessEnquiries() async {
    try {
      final res = await _client.get(
        'module2/businesses/enquiries/list',
        authenticated: true,
      );
      final raw = res['enquiries'] ?? res['items'];
      if (raw is List) {
        cachedBusinessEnquiries = raw
            .whereType<Map<String, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
    return cachedBusinessEnquiries;
  }

  Future<Map<String, dynamic>?> replyToBusinessEnquiry({
    required String enquiryId,
    required String message,
    String? status,
  }) async {
    try {
      final body = <String, Object?>{'message': message.trim()};
      if (status != null) {
        body['status'] = status;
      }
      final res = await _client.post(
        'module2/businesses/enquiries/${Uri.encodeComponent(enquiryId)}/messages',
        authenticated: true,
        body: body,
      );
      final enq = res['enquiry'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(res['enquiry'] as Map<String, dynamic>)
          : null;
      if (enq != null) {
        final idx = cachedBusinessEnquiries.indexWhere(
          (e) => e['id']?.toString() == enquiryId,
        );
        if (idx != -1) {
          cachedBusinessEnquiries[idx] = enq;
        } else {
          cachedBusinessEnquiries.insert(0, enq);
        }
        notifyListeners();
      }
      return enq;
    } catch (_) {
      return null;
    }
  }
}
