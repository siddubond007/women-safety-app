import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/auth/backend_api_client.dart';

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
    this.isOwnComment = false,
    this.canEdit = false,
    this.canDelete = false,
  });

  factory PostCommentItem.fromJson(Map<String, dynamic> json) {
    final authorId = json['authorAccountId']?.toString() ?? '';
    final authorName = json['authorName']?.toString() ?? 'Sakhi Member';
    final rawAvatar = json['authorAvatar']?.toString() ?? '';
    return PostCommentItem(
      id: json['id']?.toString() ?? '',
      authorAccountId: authorId,
      authorName: authorName,
      authorUsername: json['authorUsername']?.toString() ?? '@member',
      authorAvatar: rawAvatar,
      body: (json['body'] ?? json['text'] ?? '').toString(),
      createdAt: json['createdAt']?.toString() ?? 'Just now',
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
  bool isFollowing;

  FollowerUserModel({
    required this.id,
    required this.name,
    required this.username,
    this.location = 'India',
    this.bio,
    required this.avatarAsset,
    required this.isFollowing,
  });

  String get accountId => id;

  factory FollowerUserModel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['accountId'] ?? '').toString();
    final name = json['name']?.toString() ?? '';
    final rawAvatar = (json['avatarUrl'] ?? json['avatarAsset'] ?? '')
        .toString();
    return FollowerUserModel(
      id: id,
      name: name,
      username: json['username']?.toString() ?? '',
      location: (json['location'] ?? json['city'] ?? 'India').toString(),
      bio: json['bio'] as String?,
      avatarAsset: rawAvatar,
      isFollowing: json['isFollowing'] == true,
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
      selectedValue: 'Verified members only',
      options: [
        'Everyone on Sakhi',
        'Verified members only',
        'Followers only',
        'Only me',
      ],
      icon: Icons.person_outline_rounded,
    ),
    PrivacySettingItem(
      id: 'message_me',
      title: 'Who can message me',
      selectedValue: 'Verified members only',
      options: ['Verified members only', 'People I follow', 'No one'],
      icon: Icons.mark_email_unread_outlined,
    ),
    PrivacySettingItem(
      id: 'see_posts',
      title: 'Who can see my posts',
      selectedValue: 'Verified members only',
      options: ['Verified members only', 'My followers', 'Only my groups'],
      icon: Icons.contact_page_outlined,
    ),
    PrivacySettingItem(
      id: 'show_location',
      title: 'Show my location',
      selectedValue: 'General location only',
      options: ['General location only', 'City only', 'Hidden'],
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
        final idx = communityPosts.indexWhere((p) => p.id == postId);
        if (idx != -1) {
          communityPosts[idx].comments = rawComments
              .whereType<Map<String, dynamic>>()
              .map(PostCommentItem.fromJson)
              .toList();
          communityPosts[idx].commentsCount =
              communityPosts[idx].comments.length;
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
        currentUser.accountId =
            userMap['accountId']?.toString() ?? currentUser.accountId;
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
    currentUser.displayName = displayName;
    if (username != null && username.trim().isNotEmpty) {
      currentUser.username = username.trim();
    }
    currentUser.bio = bio;
    currentUser.location = location;
    if (interests != null) {
      currentUser.interests = List<String>.from(interests);
    }
    if (email != null) currentUser.email = email;
    if (businessProfileUrl != null) {
      currentUser.businessProfileUrl = businessProfileUrl;
    }
    if (avatarAsset != null && avatarAsset.trim().isNotEmpty) {
      currentUser.avatarAsset = avatarAsset.trim();
    }
    notifyListeners();

    unawaited(
      _sendAuthenticatedRequest((client) async {
        await client.put(
          'module2/profile',
          authenticated: true,
          body: {
            'displayName': displayName,
            'bio': bio,
            'city': location,
            if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
            if (avatarAsset != null &&
                avatarAsset.trim().startsWith('assets/images/profile/'))
              'avatarAsset': avatarAsset.trim(),
          },
        );
      }),
    );
    return true;
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
    post.content = content.trim();
    if (categorySlug != null) post.categorySlug = categorySlug;
    if (visibility != null) post.visibility = visibility;
    if (locationTag != null) post.locationTag = locationTag;
    if (allowComments != null) post.allowComments = allowComments;
    notifyListeners();

    unawaited(
      _sendAuthenticatedRequest((client) async {
        if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(post.id)) {
          await client.patch(
            'module2/posts/${post.id}',
            authenticated: true,
            body: {
              'body': post.content,
              if (categorySlug != null) 'categorySlug': categorySlug,
              if (visibility != null) 'visibility': visibility,
              if (locationTag != null) 'locationTag': locationTag,
              if (allowComments != null) 'allowComments': allowComments,
            },
          );
        }
      }),
    );
    return true;
  }

  Future<bool> deletePost(dynamic postOrId) async {
    final postId = postOrId is FeedPostModel
        ? postOrId.id
        : postOrId.toString();
    communityPosts.removeWhere((p) => p.id == postId);
    profilePosts.removeWhere((p) => p.id == postId);
    currentUser.postsCount = (currentUser.postsCount - 1).clamp(0, 9999);
    notifyListeners();

    unawaited(
      _sendAuthenticatedRequest((client) async {
        if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(postId)) {
          await client.delete('module2/posts/$postId', authenticated: true);
        }
      }),
    );
    return true;
  }

  Future<bool> reactToPost(FeedPostModel post, String reactionType) async {
    final isRemoving = post.viewerReaction == reactionType;
    if (post.viewerReaction != null) {
      final oldKey = post.viewerReaction!;
      final oldVal = (post.reactionBreakdown[oldKey] ?? 1) - 1;
      if (oldVal <= 0) {
        post.reactionBreakdown.remove(oldKey);
      } else {
        post.reactionBreakdown[oldKey] = oldVal;
      }
    }
    if (!isRemoving) {
      post.reactionBreakdown[reactionType] =
          (post.reactionBreakdown[reactionType] ?? 0) + 1;
    }
    final delta = isRemoving ? -1 : (post.viewerReaction == null ? 1 : 0);
    post.likesCount = (post.likesCount + delta).clamp(0, 999999);
    post.viewerReaction = isRemoving ? null : reactionType;
    post.isLiked = !isRemoving;
    notifyListeners();

    unawaited(
      _sendAuthenticatedRequest((client) async {
        if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(post.id)) {
          await client.post(
            'module2/posts/${post.id}/react',
            authenticated: true,
            body: {'reactionType': reactionType},
          );
        }
      }),
    );
    return true;
  }

  void toggleFollow(String followerId) {
    final idx = followers.indexWhere(
      (f) => f.id == followerId || f.username == followerId,
    );
    if (idx != -1) {
      followers[idx].isFollowing = !followers[idx].isFollowing;
      currentUser.followingCount += followers[idx].isFollowing ? 1 : -1;
      notifyListeners();

      unawaited(
        _sendAuthenticatedRequest((client) async {
          if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(followers[idx].id)) {
            await client.post(
              'module2/members/${followers[idx].id}/follow',
              authenticated: true,
            );
          }
        }),
      );
    }
  }

  void togglePostLike(dynamic postOrId) {
    final post = postOrId is FeedPostModel
        ? postOrId
        : communityPosts.firstWhere(
            (p) => p.id == postOrId.toString(),
            orElse: () => communityPosts.first,
          );
    reactToPost(post, 'LIKE');
  }

  void togglePostSaved(dynamic postOrId) {
    final post = postOrId is FeedPostModel
        ? postOrId
        : communityPosts.firstWhere(
            (p) => p.id == postOrId.toString(),
            orElse: () => communityPosts.first,
          );
    post.isSaved = !post.isSaved;
    post.savesCount = (post.savesCount + (post.isSaved ? 1 : -1)).clamp(
      0,
      999999,
    );
    notifyListeners();

    unawaited(
      _sendAuthenticatedRequest((client) async {
        if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(post.id)) {
          await client.post(
            'module2/posts/${post.id}/save',
            authenticated: true,
          );
        }
      }),
    );
  }

  void addPostComment(FeedPostModel post, String commentText) {
    final trimmed = commentText.trim();
    if (trimmed.isEmpty || !post.allowComments) return;
    final item = PostCommentItem(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      authorAccountId: currentUser.accountId,
      authorName: currentUser.displayName,
      authorUsername: currentUser.username,
      authorAvatar: currentUser.avatarAsset,
      body: trimmed,
      createdAt: 'Just now',
      isOwnComment: true,
      canEdit: true,
      canDelete: true,
    );
    post.comments.add(item);
    post.commentsCount = post.comments.length;
    notifyListeners();

    unawaited(
      _sendAuthenticatedRequest((client) async {
        if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(post.id)) {
          final res = await client.post(
            'module2/posts/${post.id}/comments',
            authenticated: true,
            body: {'body': trimmed},
          );
          final serverComment = res['comment'];
          if (serverComment is Map<String, dynamic>) {
            final idx = post.comments.indexWhere((c) => c.id == item.id);
            if (idx != -1) {
              post.comments[idx] = PostCommentItem.fromJson(serverComment);
              notifyListeners();
            }
          }
        }
      }),
    );
  }

  Future<bool> addComment(String postId, String text) async {
    final idx = communityPosts.indexWhere((p) => p.id == postId);
    if (idx == -1) return false;
    addPostComment(communityPosts[idx], text);
    return true;
  }

  Future<bool> editComment(
    String postId,
    String commentId,
    String newBody,
  ) async {
    final trimmed = newBody.trim();
    if (trimmed.isEmpty) return false;
    final idx = communityPosts.indexWhere((p) => p.id == postId);
    if (idx == -1) return false;
    final post = communityPosts[idx];
    final cIdx = post.comments.indexWhere((c) => c.id == commentId);
    if (cIdx == -1) return false;
    post.comments[cIdx].body = trimmed;
    notifyListeners();

    unawaited(
      _sendAuthenticatedRequest((client) async {
        if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(postId) &&
            RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(commentId)) {
          await client.patch(
            'module2/posts/$postId/comments/$commentId',
            authenticated: true,
            body: {'body': trimmed},
          );
        }
      }),
    );
    return true;
  }

  Future<bool> removeComment(String postId, String commentId) async {
    final idx = communityPosts.indexWhere((p) => p.id == postId);
    if (idx == -1) return false;
    final post = communityPosts[idx];
    post.comments.removeWhere((c) => c.id == commentId);
    post.commentsCount = post.comments.length;
    notifyListeners();

    unawaited(
      _sendAuthenticatedRequest((client) async {
        if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(postId) &&
            RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(commentId)) {
          await client.delete(
            'module2/posts/$postId/comments/$commentId',
            authenticated: true,
          );
        }
      }),
    );
    return true;
  }

  Future<bool> updatePrivacySetting(String id, String newValue) async {
    final idx = privacySettings.indexWhere((s) => s.id == id);
    if (idx != -1) {
      privacySettings[idx].selectedValue = newValue;
      notifyListeners();

      unawaited(
        _sendAuthenticatedRequest((client) async {
          await client.put(
            'module2/privacy',
            authenticated: true,
            body: {'appearInSearch': true},
          );
        }),
      );
      return true;
    }
    return false;
  }

  Future<bool> toggleNotificationPref(String id, bool value) async {
    final idx = notificationPreferences.indexWhere((n) => n.id == id);
    if (idx != -1) {
      notificationPreferences[idx].isEnabled = value;
      notifyListeners();

      unawaited(
        _sendAuthenticatedRequest((client) async {
          await client.put(
            'module2/notifications',
            authenticated: true,
            body: {'communityReplies': value},
          );
        }),
      );
      return true;
    }
    return false;
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
            if (locationLabel != null) 'locationArea': locationLabel,
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
          'module2/security',
          authenticated: true,
          body: {'twoFactorEnabled': currentUser.twoFactorEnabled},
        );
      }),
    );
  }

  void updateSecurityPin(String newPin) {
    unawaited(
      _sendAuthenticatedRequest((client) async {
        await client.put(
          'module2/security',
          authenticated: true,
          body: {'pin': newPin},
        );
      }),
    );
  }

  void reportUserOrPost({
    required String targetHandle,
    required String reason,
    String? postId,
    String? category,
    String? details,
  }) {
    unawaited(
      _sendAuthenticatedRequest((client) async {
        await client.post(
          'module2/reports',
          authenticated: true,
          body: {
            if (postId != null &&
                RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(postId))
              'postId': postId,
            'category': category ?? 'inappropriate_content',
            'reason': reason,
            if (details != null && details.trim().isNotEmpty)
              'details': details.trim(),
          },
        );
      }),
    );
  }

  Future<bool> reportMember({
    String? accountId,
    String? reportedAccountId,
    String? postId,
    String? commentId,
    String? reason,
    String? reasonCode,
    String? details,
  }) async {
    reportUserOrPost(
      targetHandle: reportedAccountId ?? accountId ?? '',
      reason: reason ?? reasonCode ?? 'inappropriate_content',
      postId: postId,
      category: reasonCode ?? reason ?? 'inappropriate_content',
      details: details,
    );
    return true;
  }

  void toggleBlockedUser({
    required String username,
    required String displayName,
    String? accountId,
  }) {
    final idx = blockedUsers.indexWhere((b) => b.blockedUsername == username);
    if (idx != -1) {
      blockedUsers.removeAt(idx);
    } else {
      blockedUsers.add(
        BlockedUserModel(
          id: accountId ?? 'blk_${DateTime.now().millisecondsSinceEpoch}',
          blockedUsername: username,
          blockedDisplayName: displayName,
        ),
      );
      communityPosts.removeWhere(
        (p) => p.authorUsername == username || p.authorName == displayName,
      );
    }
    notifyListeners();

    unawaited(
      _sendAuthenticatedRequest((client) async {
        if (accountId != null &&
            RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(accountId)) {
          await client.post(
            'module2/members/$accountId/block',
            authenticated: true,
            body: {'reason': 'Blocked from Social Wall'},
          );
        }
      }),
    );
  }
}
