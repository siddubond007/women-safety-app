Map<String, dynamic> jsonMap(Object? value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};

List<Map<String, dynamic>> jsonMapList(Object? value) =>
    value is List ? value.whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];

int jsonInt(Object? value) => value is int ? value : value is num ? value.toInt() : 0;

class Module2Profile {
  const Module2Profile({
    required this.accountId,
    required this.displayName,
    required this.phoneMasked,
    required this.phoneVerified,
    required this.verificationStatus,
    required this.dateOfBirth,
    required this.email,
    required this.profilePhotoRef,
    required this.bio,
    required this.locationCity,
    required this.interests,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.savedCount,
  });

  final String accountId;
  final String displayName;
  final String phoneMasked;
  final bool phoneVerified;
  final String verificationStatus;
  final String? dateOfBirth;
  final String? email;
  final String? profilePhotoRef;
  final String bio;
  final String locationCity;
  final List<String> interests;
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final int savedCount;

  factory Module2Profile.fromPayload(Map<String, dynamic> json) {
    final p = jsonMap(json['profile']);
    final counts = jsonMap(json['counts']);
    return Module2Profile(
      accountId: json['accountId'] is String ? json['accountId'] as String : '',
      displayName: p['displayName'] is String ? p['displayName'] as String : '',
      phoneMasked: json['phone'] is String ? json['phone'] as String : '',
      phoneVerified: json['phoneVerified'] == true,
      verificationStatus: json['verificationStatus'] is String
          ? json['verificationStatus'] as String
          : 'UNVERIFIED',
      dateOfBirth: p['dateOfBirth'] is String ? p['dateOfBirth'] as String : null,
      email: p['email'] is String ? p['email'] as String : null,
      profilePhotoRef: p['profilePhotoRef'] is String ? p['profilePhotoRef'] as String : null,
      bio: p['bio'] is String ? p['bio'] as String : '',
      locationCity: p['locationCity'] is String ? p['locationCity'] as String : '',
      interests: p['interests'] is List
          ? (p['interests'] as List).whereType<String>().toList()
          : <String>[],
      postsCount: jsonInt(counts['posts']),
      followersCount: jsonInt(counts['followers']),
      followingCount: jsonInt(counts['following']),
      savedCount: jsonInt(counts['saved']),
    );
  }

  Module2Profile copyWith({
    String? displayName,
    String? bio,
    String? locationCity,
    List<String>? interests,
    int? postsCount,
    int? followersCount,
    int? followingCount,
    int? savedCount,
  }) => Module2Profile(
    accountId: accountId,
    displayName: displayName ?? this.displayName,
    phoneMasked: phoneMasked,
    phoneVerified: phoneVerified,
    verificationStatus: verificationStatus,
    dateOfBirth: dateOfBirth,
    email: email,
    profilePhotoRef: profilePhotoRef,
    bio: bio ?? this.bio,
    locationCity: locationCity ?? this.locationCity,
    interests: interests ?? this.interests,
    postsCount: postsCount ?? this.postsCount,
    followersCount: followersCount ?? this.followersCount,
    followingCount: followingCount ?? this.followingCount,
    savedCount: savedCount ?? this.savedCount,
  );
}

class Module2Post {
  const Module2Post({
    required this.id,
    required this.body,
    required this.mediaRef,
    required this.audience,
    required this.createdAt,
    required this.authorAccountId,
    required this.authorName,
    required this.authorPhotoRef,
    required this.authorCity,
    required this.likeCount,
    required this.commentCount,
    required this.isLiked,
    required this.isSaved,
    required this.isOwnPost,
  });

  final String id;
  final String body;
  final String? mediaRef;
  final String audience;
  final DateTime? createdAt;
  final String authorAccountId;
  final String authorName;
  final String? authorPhotoRef;
  final String? authorCity;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final bool isSaved;
  final bool isOwnPost;

  factory Module2Post.fromMap(Map<String, dynamic> json) {
    final author = jsonMap(json['author']);
    final createdAt = json['createdAt'] is String
        ? DateTime.tryParse(json['createdAt'] as String)
        : null;
    return Module2Post(
      id: json['id'] is String ? json['id'] as String : '',
      body: json['body'] is String ? json['body'] as String : '',
      mediaRef: json['mediaRef'] is String ? json['mediaRef'] as String : null,
      audience: json['audience'] is String ? json['audience'] as String : 'VERIFIED_MEMBERS',
      createdAt: createdAt,
      authorAccountId: author['accountId'] is String ? author['accountId'] as String : '',
      authorName: author['displayName'] is String ? author['displayName'] as String : 'Sakhi member',
      authorPhotoRef: author['profilePhotoRef'] is String ? author['profilePhotoRef'] as String : null,
      authorCity: author['locationCity'] is String ? author['locationCity'] as String : null,
      likeCount: jsonInt(json['likeCount']),
      commentCount: jsonInt(json['commentCount']),
      isLiked: json['isLikedByViewer'] == true,
      isSaved: json['isSavedByViewer'] == true,
      isOwnPost: json['isOwnPost'] == true,
    );
  }

  Module2Post copyWith({
    int? likeCount,
    int? commentCount,
    bool? isLiked,
    bool? isSaved,
  }) => Module2Post(
    id: id,
    body: body,
    mediaRef: mediaRef,
    audience: audience,
    createdAt: createdAt,
    authorAccountId: authorAccountId,
    authorName: authorName,
    authorPhotoRef: authorPhotoRef,
    authorCity: authorCity,
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount ?? this.commentCount,
    isLiked: isLiked ?? this.isLiked,
    isSaved: isSaved ?? this.isSaved,
    isOwnPost: isOwnPost,
  );
}

class Module2Member {
  const Module2Member({
    required this.accountId,
    required this.displayName,
    required this.profilePhotoRef,
    required this.bio,
    required this.locationCity,
    required this.interests,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.isFollowing,
    required this.blockedAt,
  });

  final String accountId;
  final String displayName;
  final String? profilePhotoRef;
  final String? bio;
  final String? locationCity;
  final List<String> interests;
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final DateTime? blockedAt;

  factory Module2Member.fromMap(Map<String, dynamic> json) {
    final counts = jsonMap(json['counts']);
    final blockedAt = json['blockedAt'] is String
        ? DateTime.tryParse(json['blockedAt'] as String)
        : null;
    return Module2Member(
      accountId: json['accountId'] is String ? json['accountId'] as String : '',
      displayName: json['displayName'] is String ? json['displayName'] as String : 'Sakhi member',
      profilePhotoRef: json['profilePhotoRef'] is String ? json['profilePhotoRef'] as String : null,
      bio: json['bio'] is String ? json['bio'] as String : null,
      locationCity: json['locationCity'] is String ? json['locationCity'] as String : null,
      interests: json['interests'] is List
          ? (json['interests'] as List).whereType<String>().toList()
          : <String>[],
      postsCount: jsonInt(counts['posts']),
      followersCount: jsonInt(counts['followers']),
      followingCount: jsonInt(counts['following']),
      isFollowing: json['isFollowing'] == true,
      blockedAt: blockedAt,
    );
  }
}


class Module2MemberProfile {
  const Module2MemberProfile({
    required this.accountId,
    required this.displayName,
    required this.profilePhotoRef,
    required this.bio,
    required this.locationCity,
    required this.interests,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.isFollowing,
    required this.profileVisibility,
    required this.locationSharing,
  });

  final String accountId;
  final String displayName;
  final String? profilePhotoRef;
  final String? bio;
  final String? locationCity;
  final List<String> interests;
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final String profileVisibility;
  final String locationSharing;

  factory Module2MemberProfile.fromPayload(Map<String, dynamic> json) {
    final profile = jsonMap(json['profile']);
    final counts = jsonMap(json['counts']);
    final privacy = jsonMap(json['privacy']);
    return Module2MemberProfile(
      accountId: json['accountId'] is String ? json['accountId'] as String : '',
      displayName: profile['displayName'] is String
          ? profile['displayName'] as String
          : 'Sakhi member',
      profilePhotoRef: profile['profilePhotoRef'] is String
          ? profile['profilePhotoRef'] as String
          : null,
      bio: profile['bio'] is String ? profile['bio'] as String : null,
      locationCity: profile['locationCity'] is String
          ? profile['locationCity'] as String
          : null,
      interests: profile['interests'] is List
          ? (profile['interests'] as List).whereType<String>().toList()
          : <String>[],
      postsCount: jsonInt(counts['posts']),
      followersCount: jsonInt(counts['followers']),
      followingCount: jsonInt(counts['following']),
      isFollowing: json['isFollowing'] == true,
      profileVisibility: privacy['profileVisibility'] is String
          ? privacy['profileVisibility'] as String
          : 'VERIFIED_MEMBERS',
      locationSharing: privacy['locationSharing'] is String
          ? privacy['locationSharing'] as String
          : 'HIDDEN',
    );
  }
}


class Module2Comment {
  const Module2Comment({
    required this.id,
    required this.body,
    required this.authorAccountId,
    required this.authorName,
    required this.authorPhotoRef,
    required this.createdAt,
    required this.isOwnComment,
  });

  final String id;
  final String body;
  final String authorAccountId;
  final String authorName;
  final String? authorPhotoRef;
  final DateTime? createdAt;
  final bool isOwnComment;

  factory Module2Comment.fromMap(Map<String, dynamic> json) {
    final author = jsonMap(json['author']);
    final createdAt = json['createdAt'] is String
        ? DateTime.tryParse(json['createdAt'] as String)
        : null;
    return Module2Comment(
      id: json['id'] is String ? json['id'] as String : '',
      body: json['body'] is String ? json['body'] as String : '',
      authorAccountId: author['accountId'] is String ? author['accountId'] as String : '',
      authorName: author['displayName'] is String ? author['displayName'] as String : 'Sakhi member',
      authorPhotoRef: author['profilePhotoRef'] is String ? author['profilePhotoRef'] as String : null,
      createdAt: createdAt,
      isOwnComment: json['isOwnComment'] == true,
    );
  }
}


class Module2Group {
  const Module2Group({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.visibility,
    required this.createdAt,
    required this.creatorName,
    required this.memberCount,
    required this.upcomingEventsCount,
    required this.membershipStatus,
    required this.membershipRole,
    required this.isOwner,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String visibility;
  final DateTime? createdAt;
  final String creatorName;
  final int memberCount;
  final int upcomingEventsCount;
  final String? membershipStatus;
  final String? membershipRole;
  final bool isOwner;

  factory Module2Group.fromMap(Map<String, dynamic> json) {
    final creator = jsonMap(json['creator']);
    return Module2Group(
      id: json['id'] is String ? json['id'] as String : '',
      name: json['name'] is String ? json['name'] as String : 'Sakhi group',
      slug: json['slug'] is String ? json['slug'] as String : '',
      description: json['description'] is String ? json['description'] as String : null,
      visibility: json['visibility'] is String ? json['visibility'] as String : 'VERIFIED_MEMBERS',
      createdAt: json['createdAt'] is String ? DateTime.tryParse(json['createdAt'] as String) : null,
      creatorName: creator['displayName'] is String ? creator['displayName'] as String : 'Sakhi member',
      memberCount: jsonInt(json['memberCount']),
      upcomingEventsCount: jsonInt(json['upcomingEventsCount']),
      membershipStatus: json['membershipStatus'] is String ? json['membershipStatus'] as String : null,
      membershipRole: json['membershipRole'] is String ? json['membershipRole'] as String : null,
      isOwner: json['isOwner'] == true,
    );
  }
}

class Module2Event {
  const Module2Event({
    required this.id,
    required this.title,
    required this.description,
    required this.locationCity,
    required this.startsAt,
    required this.endsAt,
    required this.groupId,
    required this.groupName,
    required this.isRegistered,
    required this.registrationCount,
  });

  final String id;
  final String title;
  final String description;
  final String? locationCity;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String groupId;
  final String groupName;
  final bool isRegistered;
  final int registrationCount;

  factory Module2Event.fromMap(Map<String, dynamic> json) {
    final group = jsonMap(json['group']);
    return Module2Event(
      id: json['id'] is String ? json['id'] as String : '',
      title: json['title'] is String ? json['title'] as String : 'Sakhi community event',
      description: json['description'] is String ? json['description'] as String : '',
      locationCity: json['locationCity'] is String ? json['locationCity'] as String : null,
      startsAt: json['startsAt'] is String ? DateTime.tryParse(json['startsAt'] as String) : null,
      endsAt: json['endsAt'] is String ? DateTime.tryParse(json['endsAt'] as String) : null,
      groupId: group['id'] is String ? group['id'] as String : '',
      groupName: group['name'] is String ? group['name'] as String : '',
      isRegistered: json['isRegistered'] == true,
      registrationCount: jsonInt(json['registrationCount']),
    );
  }
}

class Module2Expert {
  const Module2Expert({
    required this.accountId,
    required this.businessName,
    required this.description,
    required this.websiteUrl,
    required this.displayName,
    required this.profilePhotoRef,
  });

  final String accountId;
  final String businessName;
  final String? description;
  final String? websiteUrl;
  final String displayName;
  final String? profilePhotoRef;

  factory Module2Expert.fromMap(Map<String, dynamic> json) => Module2Expert(
    accountId: json['accountId'] is String ? json['accountId'] as String : '',
    businessName: json['businessName'] is String ? json['businessName'] as String : 'Verified business',
    description: json['description'] is String ? json['description'] as String : null,
    websiteUrl: json['websiteUrl'] is String ? json['websiteUrl'] as String : null,
    displayName: json['displayName'] is String ? json['displayName'] as String : 'Verified member',
    profilePhotoRef: json['profilePhotoRef'] is String ? json['profilePhotoRef'] as String : null,
  );
}
