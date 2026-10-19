import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/auth/backend_api_client.dart';
import 'app_assets.dart';

class UserProfileModel {
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
    required this.displayName,
    required this.username,
    required this.bio,
    required this.location,
    required this.avatarAsset,
    this.email = 'siddhu@example.com',
    this.phoneMasked = '+91 ••••••2222',
    this.phoneVerified = true,
    this.verificationStatus = 'VERIFIED',
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.interests,
    this.businessProfileUrl,
    this.twoFactorEnabled = false,
    this.activeSessionsCount = 1,
  });
}

class FeedPostModel {
  final String id;
  final String authorName;
  final String authorUsername;
  final String authorAvatar;
  final bool authorVerified;
  final String timestamp;
  final String content;
  final String? imageAsset;
  final String? categoryBadge;
  final bool hasBreathingExerciseCard;
  int likesCount;
  int commentsCount;
  bool isLiked;
  bool isSaved;

  FeedPostModel({
    required this.id,
    required this.authorName,
    required this.authorUsername,
    required this.authorAvatar,
    this.authorVerified = false,
    required this.timestamp,
    required this.content,
    this.imageAsset,
    this.categoryBadge,
    this.hasBreathingExerciseCard = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
    this.isSaved = false,
  });

  factory FeedPostModel.fromJson(Map<String, dynamic> json) {
    return FeedPostModel(
      id: json['id']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? 'Sakhi Member',
      authorUsername: json['authorUsername']?.toString() ?? '@member',
      authorAvatar: json['authorAvatar']?.toString() ?? AppAssets.avatarSiddhu,
      authorVerified: json['authorVerified'] == true,
      timestamp: json['timestamp']?.toString() ?? 'Just now',
      content: json['content']?.toString() ?? '',
      imageAsset: json['imageAsset'] as String?,
      categoryBadge: json['categoryBadge'] as String?,
      hasBreathingExerciseCard: json['hasBreathingExerciseCard'] == true,
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
      isLiked: json['isLiked'] == true,
      isSaved: json['isSaved'] == true,
    );
  }
}

class FollowerUserModel {
  final String id;
  final String name;
  final String username;
  final String avatarAsset;
  bool isFollowing;

  FollowerUserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.avatarAsset,
    required this.isFollowing,
  });

  factory FollowerUserModel.fromJson(Map<String, dynamic> json) {
    return FollowerUserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      avatarAsset: json['avatarAsset']?.toString() ?? AppAssets.avatarAnanya,
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
      name: json['name']?.toString() ?? '',
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
      name: json['name']?.toString() ?? '',
      relationship: json['relationship']?.toString() ?? '',
      phoneE164: json['phoneE164']?.toString() ?? '',
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
      id: json['id']?.toString() ?? '',
      blockedUsername: json['blockedUsername']?.toString() ?? '',
      blockedDisplayName: json['blockedDisplayName']?.toString() ?? '',
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

/// Unified domain state and backend repository store for all 12 Module 2 screens.
/// Connects to `/api/v1/module2/*` when an authenticated session is available,
/// while preserving deterministic defaults for widget tests and offline preview.
class SakhiPrototypeState extends ChangeNotifier {
  static final SakhiPrototypeState instance = SakhiPrototypeState._internal();
  SakhiPrototypeState._internal();

  BackendApiClient? _apiClient;
  bool _isBackendSynced = false;
  int totalDatabaseMembers = 8;
  int totalDatabasePosts = 11;
  String lastSyncSource = 'PostgreSQL Live DB';

  bool get isBackendSynced => _isBackendSynced;

  BackendApiClient get _client => _apiClient ??= BackendApiClient();

  void configureApiClient(BackendApiClient client) {
    _apiClient = client;
  }

  final UserProfileModel currentUser = UserProfileModel(
    displayName: 'Siddhu',
    username: '@siddhu',
    bio: 'A passionate learner, exploring wellness, technology and meaningful connections. 💜',
    location: 'Bangalore, India',
    avatarAsset: AppAssets.avatarSiddhu,
    email: 'siddhu@example.com',
    phoneMasked: '+91 ••••••2222',
    phoneVerified: true,
    verificationStatus: 'VERIFIED',
    postsCount: 124,
    followersCount: 560,
    followingCount: 312,
    interests: [
      'Mental Wellness',
      'Travel',
      'Reading',
      'WomenInTech',
      'Art',
      'Fitness',
    ],
  );

  final List<String> exploreFilters = const [
    'All',
    'Posts',
    'Groups',
    'Experts',
    'Events',
  ];

  final List<String> trendingHashtags = const [
    '#MentalWellness',
    '#CareerGrowth',
    '#SelfCare',
    '#SafetyTips',
    '#StudentLife',
    '#WomenInTech',
  ];

  final List<FeedPostModel> communityPosts = [
    FeedPostModel(
      id: '11111111-1111-4111-8111-111111111101',
      authorName: 'Kavya Nair',
      authorUsername: '@kavya',
      authorAvatar: AppAssets.avatarKavya,
      timestamp: '3 hours ago',
      content:
          'A peaceful evening walk 🌸\nTaking time for myself always helps me reset. Stay kind, stay strong! 💜',
      imageAsset: AppAssets.eveningWalkSunset,
      likesCount: 124,
      commentsCount: 18,
      isLiked: true,
      isSaved: false,
    ),
    FeedPostModel(
      id: '11111111-1111-4111-8111-111111111102',
      authorName: 'Meera Iyer',
      authorUsername: '@meera',
      authorAvatar: AppAssets.avatarMeera,
      authorVerified: true,
      timestamp: '5 hours ago',
      content:
          'Here are 5 simple breathing exercises that help me during stressful days.',
      categoryBadge: 'Wellness',
      hasBreathingExerciseCard: true,
      likesCount: 89,
      commentsCount: 12,
      isLiked: false,
      isSaved: true,
    ),
  ];

  final List<FeedPostModel> exploreRecommendedPosts = [
    FeedPostModel(
      id: '11111111-1111-4111-8111-111111111103',
      authorName: 'Ananya R',
      authorUsername: '@ananya',
      authorAvatar: AppAssets.avatarAnanya,
      authorVerified: true,
      timestamp: '2 hours ago',
      content:
          'Small steps every day make a big difference in your mental wellness. 💜',
      imageAsset: AppAssets.beachSunset,
      likesCount: 96,
      commentsCount: 14,
      isLiked: false,
      isSaved: false,
    ),
  ];

  final List<FeedPostModel> profilePosts = [
    FeedPostModel(
      id: '11111111-1111-4111-8111-111111111104',
      authorName: 'Siddhu',
      authorUsername: '@siddhu',
      authorAvatar: AppAssets.avatarSiddhu,
      authorVerified: true,
      timestamp: '2 days ago',
      content: 'Grateful for the little moments that bring peace. 🌸',
      likesCount: 64,
      commentsCount: 9,
      isLiked: true,
      isSaved: false,
    ),
  ];

  final List<CommunityGroupModel> groups = [
    const CommunityGroupModel(
      id: 'group_1',
      name: 'Women in Tech Bangalore',
      description: '1.4k members • 2 new posts today',
      category: 'Education & Career',
      membersCount: 1420,
      newPostsToday: 2,
    ),
    const CommunityGroupModel(
      id: 'group_2',
      name: 'Mindful Mornings Circle',
      description: '820 members • Daily wellness check-ins',
      category: 'Health & Wellness',
      membersCount: 820,
      newPostsToday: 3,
    ),
  ];

  final List<FollowerUserModel> followers = [
    FollowerUserModel(
      id: 'f1',
      name: 'Ananya Rao',
      username: '@ananya',
      avatarAsset: AppAssets.avatarAnanya,
      isFollowing: false,
    ),
    FollowerUserModel(
      id: 'f2',
      name: 'Meera Iyer',
      username: '@meera',
      avatarAsset: AppAssets.avatarMeera,
      isFollowing: true,
    ),
    FollowerUserModel(
      id: 'f3',
      name: 'Kavya Nair',
      username: '@kavya',
      avatarAsset: AppAssets.avatarKavya,
      isFollowing: false,
    ),
    FollowerUserModel(
      id: 'f4',
      name: 'Ishita Reddy',
      username: '@ishita',
      avatarAsset: AppAssets.avatarIshita,
      isFollowing: false,
    ),
    FollowerUserModel(
      id: 'f5',
      name: 'Priya Sharma',
      username: '@priya',
      avatarAsset: AppAssets.avatarPriya,
      isFollowing: true,
    ),
    FollowerUserModel(
      id: 'f6',
      name: 'Sneha Verma',
      username: '@sneha',
      avatarAsset: AppAssets.avatarSneha,
      isFollowing: false,
    ),
  ];

  final List<EmergencyContactModel> emergencyContacts = [
    const EmergencyContactModel(
      id: 'ec_1',
      name: 'Lakshmi Devi',
      relationship: 'Mother',
      phoneE164: '+919845011223',
    ),
    const EmergencyContactModel(
      id: 'ec_2',
      name: 'Meera Iyer',
      relationship: 'Trusted Friend',
      phoneE164: '+919880044556',
    ),
  ];

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
      options: [
        'General location only',
        'City only',
        'Hidden',
      ],
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

  /// Loads live PostgreSQL data from `/api/v1/module2/bootstrap` when an
  /// authenticated backend token is available.
  Future<void> syncFromBackend() async {
    try {
      final token = await _client.readAccessToken();
      Map<String, dynamic> data;
      if (token != null && token.isNotEmpty) {
        try {
          data = await _client.get('module2/bootstrap', authenticated: true);
        } catch (_) {
          data = await _client.get('module2/public-feed');
        }
      } else {
        data = await _client.get('module2/public-feed');
      }
      totalDatabaseMembers =
          (data['totalDatabaseMembers'] as num?)?.toInt() ?? totalDatabaseMembers;
      totalDatabasePosts =
          (data['totalDatabasePosts'] as num?)?.toInt() ?? totalDatabasePosts;
      final userMap = data['user'];
      if (userMap is Map<String, dynamic>) {
        currentUser.displayName =
            userMap['displayName']?.toString() ?? currentUser.displayName;
        currentUser.username =
            userMap['username']?.toString() ?? currentUser.username;
        currentUser.bio = userMap['bio']?.toString() ?? currentUser.bio;
        currentUser.location =
            userMap['location']?.toString() ?? currentUser.location;
        currentUser.avatarAsset =
            userMap['avatarAsset']?.toString() ?? currentUser.avatarAsset;
        currentUser.email = userMap['email']?.toString() ?? currentUser.email;
        currentUser.phoneMasked =
            userMap['phoneMasked']?.toString() ?? currentUser.phoneMasked;
        currentUser.phoneVerified = userMap['phoneVerified'] != false;
        currentUser.verificationStatus =
            userMap['verificationStatus']?.toString() ?? 'VERIFIED';
        currentUser.postsCount =
            (userMap['postsCount'] as num?)?.toInt() ?? currentUser.postsCount;
        currentUser.followersCount =
            (userMap['followersCount'] as num?)?.toInt() ??
                currentUser.followersCount;
        currentUser.followingCount =
            (userMap['followingCount'] as num?)?.toInt() ??
                currentUser.followingCount;
        currentUser.businessProfileUrl =
            userMap['businessProfileUrl'] as String?;
        currentUser.twoFactorEnabled = userMap['twoFactorEnabled'] == true;
        currentUser.activeSessionsCount =
            (userMap['activeSessionsCount'] as num?)?.toInt() ?? 1;

        final rawInterests = userMap['interests'];
        if (rawInterests is List) {
          currentUser.interests =
              rawInterests.map((e) => e.toString()).toList();
        }
      }

      final rawCommunity = data['communityPosts'];
      if (rawCommunity is List && rawCommunity.isNotEmpty) {
        communityPosts
          ..clear()
          ..addAll(
            rawCommunity
                .whereType<Map<String, dynamic>>()
                .map(FeedPostModel.fromJson),
          );
      }

      final rawExplore = data['exploreRecommendedPosts'];
      if (rawExplore is List && rawExplore.isNotEmpty) {
        exploreRecommendedPosts
          ..clear()
          ..addAll(
            rawExplore
                .whereType<Map<String, dynamic>>()
                .map(FeedPostModel.fromJson),
          );
      }

      final rawProfilePosts = data['profilePosts'];
      if (rawProfilePosts is List && rawProfilePosts.isNotEmpty) {
        profilePosts
          ..clear()
          ..addAll(
            rawProfilePosts
                .whereType<Map<String, dynamic>>()
                .map(FeedPostModel.fromJson),
          );
      }

      final rawGroups = data['groups'];
      if (rawGroups is List && rawGroups.isNotEmpty) {
        groups
          ..clear()
          ..addAll(
            rawGroups
                .whereType<Map<String, dynamic>>()
                .map(CommunityGroupModel.fromJson),
          );
      }

      final rawFollowers = data['followers'];
      if (rawFollowers is List && rawFollowers.isNotEmpty) {
        followers
          ..clear()
          ..addAll(
            rawFollowers
                .whereType<Map<String, dynamic>>()
                .map(FollowerUserModel.fromJson),
          );
      }

      final rawPrivacy = data['privacySettings'];
      if (rawPrivacy is Map<String, dynamic>) {
        for (final item in privacySettings) {
          final val = rawPrivacy[item.id];
          if (val is String && val.isNotEmpty) {
            item.selectedValue = val;
          }
        }
      }

      final rawNotifications = data['notificationPreferences'];
      if (rawNotifications is Map<String, dynamic>) {
        for (final pref in notificationPreferences) {
          final val = rawNotifications[pref.id];
          if (val is bool) {
            pref.isEnabled = val;
          }
        }
      }

      final rawContacts = data['emergencyContacts'];
      if (rawContacts is List && rawContacts.isNotEmpty) {
        emergencyContacts
          ..clear()
          ..addAll(
            rawContacts
                .whereType<Map<String, dynamic>>()
                .map(EmergencyContactModel.fromJson),
          );
      }

      final rawBlocked = data['blockedUsers'];
      if (rawBlocked is List) {
        blockedUsers
          ..clear()
          ..addAll(
            rawBlocked
                .whereType<Map<String, dynamic>>()
                .map(BlockedUserModel.fromJson),
          );
      }

      _isBackendSynced = true;
      notifyListeners();
    } catch (_) {
      // Keep local defaults when offline or during widget tests.
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

  void updateProfile({
    required String displayName,
    required String bio,
    required String location,
    required List<String> interests,
    String? email,
    String? businessProfileUrl,
    String? avatarAsset,
  }) {
    currentUser.displayName = displayName;
    currentUser.bio = bio;
    currentUser.location = location;
    currentUser.interests = List<String>.from(interests);
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
            'location': location,
            'interests': interests,
            if (email != null) 'email': email,
            if (businessProfileUrl != null)
              'businessProfileUrl': businessProfileUrl,
            if (avatarAsset != null && avatarAsset.trim().isNotEmpty)
              'avatarAsset': avatarAsset.trim(),
          },
        );
      }),
    );
  }

  Future<String?> uploadMediaToCloud({
    required String purpose,
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
  }) async {
    try {
      final token = await _client.readAccessToken();
      if (token == null || token.isEmpty) return null;
      final response = await _client.postMultipart(
        'module2/media/binary-upload',
        authenticated: true,
        fields: {'purpose': purpose},
        fileBytes: fileBytes,
        fileName: fileName,
        contentType: contentType,
      );
      final publicUrl = response['publicUrl']?.toString();
      if (publicUrl != null && publicUrl.isNotEmpty) {
        if (purpose == 'avatar') {
          currentUser.avatarAsset = publicUrl;
          notifyListeners();
        }
        return publicUrl;
      }
    } catch (_) {
      // The caller shows a generic connection/provider error; never log file bytes or tokens.
    }
    return null;
  }

  void updateAvatar(String avatarAssetOrUrl) {
    final trimmed = avatarAssetOrUrl.trim();
    if (trimmed.isEmpty) return;
    currentUser.avatarAsset = trimmed;
    notifyListeners();

    unawaited(
      _sendAuthenticatedRequest((client) async {
        await client.put(
          'module2/profile/avatar',
          authenticated: true,
          body: {'avatarAsset': trimmed},
        );
      }),
    );
  }

  void addInterest(String interest) {
    final trimmed = interest.trim();
    if (trimmed.isNotEmpty && !currentUser.interests.contains(trimmed)) {
      currentUser.interests.add(trimmed);
      notifyListeners();
      updateProfile(
        displayName: currentUser.displayName,
        bio: currentUser.bio,
        location: currentUser.location,
        interests: currentUser.interests,
      );
    }
  }

  void removeInterest(String interest) {
    currentUser.interests.remove(interest);
    notifyListeners();
    updateProfile(
      displayName: currentUser.displayName,
      bio: currentUser.bio,
      location: currentUser.location,
      interests: currentUser.interests,
    );
  }

  void createCommunityPost(
    String content, {
    String? categoryBadge,
    String? imageAsset,
  }) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    final newPost = FeedPostModel(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      authorName: currentUser.displayName,
      authorUsername: currentUser.username,
      authorAvatar: currentUser.avatarAsset,
      authorVerified: currentUser.verificationStatus == 'VERIFIED',
      timestamp: 'Just now',
      content: trimmed,
      categoryBadge: categoryBadge,
      imageAsset: imageAsset,
    );
    communityPosts.insert(0, newPost);
    profilePosts.insert(0, newPost);
    currentUser.postsCount += 1;
    notifyListeners();

    unawaited(
      _sendAuthenticatedRequest((client) async {
        final created = await client.post(
          'module2/posts',
          authenticated: true,
          body: {
            'content': trimmed,
            if (categoryBadge != null) 'categoryBadge': categoryBadge,
            if (imageAsset != null && imageAsset.trim().isNotEmpty)
              'imageAsset': imageAsset.trim(),
          },
        );
        final serverId = created['id'];
        if (serverId is String && serverId.isNotEmpty) {
          final parsed = FeedPostModel.fromJson(created);
          communityPosts[0] = parsed;
          profilePosts[0] = parsed;
          notifyListeners();
        }
      }),
    );
  }

  void toggleFollow(String followerId) {
    final idx = followers.indexWhere((f) => f.id == followerId);
    if (idx != -1) {
      followers[idx].isFollowing = !followers[idx].isFollowing;
      currentUser.followingCount += followers[idx].isFollowing ? 1 : -1;
      notifyListeners();

      unawaited(
        _sendAuthenticatedRequest((client) async {
          if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(followerId)) {
            await client.post(
              'module2/followers/$followerId/toggle',
              authenticated: true,
            );
          }
        }),
      );
    }
  }

  void togglePostLike(FeedPostModel post) {
    post.isLiked = !post.isLiked;
    post.likesCount += post.isLiked ? 1 : -1;
    notifyListeners();

    unawaited(
      _sendAuthenticatedRequest((client) async {
        if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(post.id)) {
          await client.post(
            'module2/posts/${post.id}/like',
            authenticated: true,
          );
        }
      }),
    );
  }

  void togglePostSaved(FeedPostModel post) {
    post.isSaved = !post.isSaved;
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
    if (trimmed.isEmpty) return;
    post.commentsCount += 1;
    notifyListeners();

    unawaited(
      _sendAuthenticatedRequest((client) async {
        if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(post.id)) {
          await client.post(
            'module2/posts/${post.id}/comments',
            authenticated: true,
            body: {'content': trimmed},
          );
        }
      }),
    );
  }

  void updatePrivacySetting(String id, String newValue) {
    final idx = privacySettings.indexWhere((s) => s.id == id);
    if (idx != -1) {
      privacySettings[idx].selectedValue = newValue;
      notifyListeners();

      unawaited(
        _sendAuthenticatedRequest((client) async {
          await client.put(
            'module2/privacy',
            authenticated: true,
            body: {'settingId': id, 'selectedValue': newValue},
          );
        }),
      );
    }
  }

  void toggleNotificationPref(String id, bool value) {
    final idx = notificationPreferences.indexWhere((n) => n.id == id);
    if (idx != -1) {
      notificationPreferences[idx].isEnabled = value;
      notifyListeners();

      unawaited(
        _sendAuthenticatedRequest((client) async {
          await client.put(
            'module2/notifications',
            authenticated: true,
            body: {'prefId': id, 'isEnabled': value},
          );
        }),
      );
    }
  }

  void recordSafetyEvent(
    String eventType, {
    String? locationLabel,
  }) {
    unawaited(
      _sendAuthenticatedRequest((client) async {
        await client.post(
          'module2/safety/events',
          authenticated: true,
          body: {
            'eventType': eventType,
            if (locationLabel != null) 'locationLabel': locationLabel,
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
            'name': name,
            'relationship': relationship,
            'phoneE164': phoneE164,
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
        await client.post(
          'module2/security/two-factor',
          authenticated: true,
          body: {'enabled': currentUser.twoFactorEnabled},
        );
      }),
    );
  }

  void updateSecurityPin(String newPin) {
    unawaited(
      _sendAuthenticatedRequest((client) async {
        await client.post(
          'module2/security/pin',
          authenticated: true,
          body: {'newPin': newPin},
        );
      }),
    );
  }

  void reportUserOrPost({
    required String targetHandle,
    required String reason,
  }) {
    unawaited(
      _sendAuthenticatedRequest((client) async {
        await client.post(
          'module2/moderation/report',
          authenticated: true,
          body: {'targetHandle': targetHandle, 'reason': reason},
        );
      }),
    );
  }

  void toggleBlockedUser({
    required String username,
    required String displayName,
  }) {
    final idx = blockedUsers.indexWhere((b) => b.blockedUsername == username);
    if (idx != -1) {
      blockedUsers.removeAt(idx);
    } else {
      blockedUsers.add(
        BlockedUserModel(
          id: 'blk_${DateTime.now().millisecondsSinceEpoch}',
          blockedUsername: username,
          blockedDisplayName: displayName,
        ),
      );
    }
    notifyListeners();

    unawaited(
      _sendAuthenticatedRequest((client) async {
        await client.post(
          'module2/moderation/block',
          authenticated: true,
          body: {
            'blockedUsername': username,
            'blockedDisplayName': displayName,
          },
        );
      }),
    );
  }
}

