import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_avatar.dart';
import '../../../core/widgets/sakhi_botanical_flower.dart';
import '../../../core/widgets/sakhi_buttons.dart';
import '../../../core/widgets/sakhi_card.dart';
import '../../../core/widgets/sakhi_dialogs.dart';
import '../../../core/widgets/sakhi_remote_media_image.dart';
import '../../../core/widgets/sakhi_remote_media_video.dart';
import '../../complaints/screens/discreet_complaint_hub_screen.dart';
import '../../explore/screens/explore_discovery_screens.dart';
import 'breathing_exercise_banner.dart';

/// Module 3 Social Wall Post Card supporting:
/// - Working "+ Follow" / "Following" toggle button
/// - Compact animated bouncing emoji reaction stack (scalable to 10,000+ reactions)
/// - Continuous hold-and-drag 360° Reaction Wheel (selects on finger slide & release without lifting first)
/// - Up to 5 inline preview comments + Instagram/Facebook-style Draggable Comments Sheet with @username replies
class FeedPostCard extends StatefulWidget {
  final FeedPostModel post;
  final Future<bool> Function() onLikeTap;
  final Future<bool> Function() onSaveTap;
  final bool showVerifiedCheck;

  const FeedPostCard({
    super.key,
    required this.post,
    required this.onLikeTap,
    required this.onSaveTap,
    this.showVerifiedCheck = false,
  });

  static const Map<String, Map<String, String>> _reactions = {
    'LOVE': {'emoji': '❤️', 'label': 'Love'},
    'SUPPORT': {'emoji': '🌸', 'label': 'Support'},
    'SOLIDARITY': {'emoji': '🤝', 'label': 'Solidarity'},
    'HAHA': {'emoji': '😂', 'label': 'Haha'},
    'CRYING': {'emoji': '😢', 'label': 'Crying'},
    'FIERCE': {'emoji': '🔥', 'label': 'Fierce'},
    'GRATEFUL': {'emoji': '🙏', 'label': 'Grateful'},
    'APPLAUD': {'emoji': '👏', 'label': 'Applaud'},
    'LIKE': {'emoji': '❤️', 'label': 'Love'},
    'INSPIRED': {'emoji': '✨', 'label': 'Inspired'},
    'HAPPY': {'emoji': '😊', 'label': 'Happy'},
    'STRONG': {'emoji': '💪', 'label': 'Strong'},
    'CARE': {'emoji': '🌸', 'label': 'Care'},
  };

  static const List<Map<String, String>> _wheelReactions = [
    {'key': 'LOVE', 'emoji': '❤️', 'label': 'Love', 'fx': 'Pulse Heart'},
    {'key': 'SUPPORT', 'emoji': '🌸', 'label': 'Support', 'fx': 'Lotus Bloom'},
    {
      'key': 'SOLIDARITY',
      'emoji': '🤝',
      'label': 'Solidarity',
      'fx': 'Sisterhood',
    },
    {'key': 'HAHA', 'emoji': '😂', 'label': 'Haha', 'fx': 'Joy Burst'},
    {'key': 'CRYING', 'emoji': '😢', 'label': 'Crying', 'fx': 'Empathy Tear'},
    {'key': 'FIERCE', 'emoji': '🔥', 'label': 'Fierce', 'fx': 'Power Flame'},
    {'key': 'GRATEFUL', 'emoji': '🙏', 'label': 'Grateful', 'fx': 'Warmth'},
    {'key': 'APPLAUD', 'emoji': '👏', 'label': 'Applaud', 'fx': 'Ovation'},
  ];

  @override
  State<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<FeedPostCard> {
  final ValueNotifier<Offset?> _dragGlobalPosition = ValueNotifier<Offset?>(
    null,
  );
  final ValueNotifier<int> _dragReleaseSignal = ValueNotifier<int>(0);
  bool _wheelDialogOpen = false;
  bool _togglingFollow = false;

  FeedPostModel get post => widget.post;

  @override
  void dispose() {
    _dragGlobalPosition.dispose();
    _dragReleaseSignal.dispose();
    super.dispose();
  }

  bool _isRemoteUrl(String path) =>
      path.startsWith('http://') ||
      path.startsWith('https://') ||
      path.startsWith('/api/v1/');

  double _aspectRatioForPreset(String preset) {
    switch (preset) {
      case '1:1':
        return 1.0;
      case '16:9':
        return 16 / 9;
      case '4:5':
      default:
        return 4 / 3;
    }
  }

  Future<void> _handleFollowToggle() async {
    if (_togglingFollow) return;
    setState(() => _togglingFollow = true);
    HapticFeedback.lightImpact();
    final state = SakhiPrototypeState.instance;
    final wasFollowing = state.isFollowingAuthor(post);
    await state.toggleFollowPostAuthor(post);
    if (!mounted) return;
    setState(() => _togglingFollow = false);
    final nowFollowing = state.isFollowingAuthor(post);
    if (wasFollowing != nowFollowing) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1400),
            content: Text(
              nowFollowing
                  ? 'Following ${post.authorName}'
                  : 'Unfollowed ${post.authorName}',
            ),
          ),
        );
    }
  }

  void _startContinuousReactionWheel(
    BuildContext context,
    Offset initialGlobalPosition,
  ) {
    if (_wheelDialogOpen) return;
    _dragGlobalPosition.value = initialGlobalPosition;
    _showReactionPickerSheet(context, startedFromHold: true);
  }

  void _updateContinuousReactionWheel(Offset globalPosition) {
    if (_wheelDialogOpen) {
      _dragGlobalPosition.value = globalPosition;
    }
  }

  void _endContinuousReactionWheel() {
    if (_wheelDialogOpen) {
      _dragReleaseSignal.value++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    final activeReaction = post.viewerReaction != null
        ? FeedPostCard._reactions[post.viewerReaction!]
        : null;
    final isOwn =
        post.isOwnPost ||
        (post.authorAccountId.isNotEmpty &&
            post.authorAccountId == state.currentUser.accountId) ||
        (post.authorUsername.isNotEmpty &&
            post.authorUsername.toLowerCase() ==
                state.currentUser.username.toLowerCase());
    final isFollowing = !isOwn && state.isFollowingAuthor(post);

    // Top 4 active reaction emojis sorted by count for compact bouncing stack
    final sortedReactionEntries = post.reactionBreakdown.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEmojis = <String>[];
    for (final entry in sortedReactionEntries) {
      final emoji = FeedPostCard._reactions[entry.key]?['emoji'] ?? '❤️';
      if (!topEmojis.contains(emoji)) {
        topEmojis.add(emoji);
      }
      if (topEmojis.length >= 4) break;
    }
    if (topEmojis.isEmpty && post.likesCount > 0) {
      topEmojis.add(activeReaction?['emoji'] ?? '❤️');
    }

    return SakhiCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Stack(
          children: [
            const Positioned(
              right: -12,
              top: -14,
              child: SakhiBotanicalFlower(
                type: SakhiFlowerType.babysBreath,
                width: 62,
                height: 76,
                opacity: 0.25,
                angle: -0.25,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SakhiAvatar(
                        imageAsset: post.authorAvatar,
                        fallbackLabel: post.authorName,
                        size: 44,
                        onAvatarTap: () => _openAuthorProfile(context),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(4),
                                    onTap: () => _openAuthorProfile(context),
                                    child: Text(
                                      post.authorName,
                                      style: AppTypography.cardTitle.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                if (widget.showVerifiedCheck ||
                                    post.authorVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 16,
                                    color: AppColors.primaryPurple,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                post.timestamp,
                                if (post.locationTag != null &&
                                    post.locationTag!.isNotEmpty)
                                  post.locationTag!,
                                if (post.visibility == 'FOLLOWERS_ONLY')
                                  'Followers Only',
                                if (post.visibility == 'PRIVATE_SELF')
                                  'Only Me',
                              ].join(' • '),
                              style: AppTypography.subtitle,
                            ),
                          ],
                        ),
                      ),
                      if (post.categoryBadge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.pastelLavender,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusPill,
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          child: Text(
                            post.categoryBadge!,
                            style: AppTypography.subtitle.copyWith(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      if (!isOwn) ...[
                        const SizedBox(width: 6),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusPill,
                            ),
                            onTap: _handleFollowToggle,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4.5,
                              ),
                              decoration: BoxDecoration(
                                color: isFollowing
                                    ? AppColors.primaryPurple.withValues(
                                        alpha: 0.12,
                                      )
                                    : const Color(0xFFFFEAF2),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusPill,
                                ),
                                border: Border.all(
                                  color: isFollowing
                                      ? AppColors.primaryPurple.withValues(
                                          alpha: 0.35,
                                        )
                                      : const Color(0xFFE5BDD1),
                                ),
                              ),
                              child: Text(
                                isFollowing ? 'Following' : '+ Follow',
                                style: AppTypography.subtitle.copyWith(
                                  color: AppColors.primaryPurple,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      IconButton(
                        icon: const Icon(
                          Icons.more_horiz_rounded,
                          color: AppColors.textMuted,
                        ),
                        onPressed: () => _showPostOptionsSheet(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 11),
                  Text(post.content, style: AppTypography.bodyRegular),

                  if (post.hashtags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: post.hashtags.map((tag) {
                        final normalized = tag.startsWith('#') ? tag : '#$tag';
                        return InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  SearchResultsScreen(initialQuery: normalized),
                            ),
                          ),
                          child: Text(
                            normalized,
                            style: AppTypography.subtitle.copyWith(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  if (post.imageAsset != null &&
                      post.imageAsset!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _showMediaViewer(context),
                      onDoubleTap: () => _handleLikeTap(context),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                        child: AspectRatio(
                          aspectRatio: post.mediaContentType == 'video/mp4'
                              ? 16 / 9
                              : _aspectRatioForPreset(post.cropPreset),
                          child: post.mediaContentType == 'video/mp4'
                              ? SakhiRemoteMediaVideo(
                                  source: post.imageAsset!,
                                  fit: BoxFit.cover,
                                )
                              : _isRemoteUrl(post.imageAsset!)
                              ? SakhiRemoteMediaImage(
                                  source: post.imageAsset!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      _buildImageFallback(),
                                )
                              : Image.asset(
                                  post.imageAsset!,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.high,
                                  isAntiAlias: true,
                                  errorBuilder: (_, _, _) =>
                                      _buildImageFallback(),
                                ),
                        ),
                      ),
                    ),
                  ],

                  if (post.hasBreathingExerciseCard) ...[
                    const SizedBox(height: 12),
                    const BreathingExerciseBanner(),
                  ],

                  // Compact Animated Bouncing Emoji Stack (never overflows even with 1,000+ reactions)
                  if (topEmojis.isNotEmpty && post.likesCount > 0) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () =>
                          _showReactionPickerSheet(context, startedFromHold: false),
                      child: _SakhiBouncingReactionBadges(
                        emojis: topEmojis,
                        totalReactions: post.likesCount,
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  Row(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _handleLikeTap(context),
                        onLongPressStart: (details) =>
                            _startContinuousReactionWheel(
                              context,
                              details.globalPosition,
                            ),
                        onLongPressMoveUpdate: (details) =>
                            _updateContinuousReactionWheel(
                              details.globalPosition,
                            ),
                        onLongPressEnd: (_) => _endContinuousReactionWheel(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              if (activeReaction != null)
                                Text(
                                  activeReaction['emoji']!,
                                  style: const TextStyle(fontSize: 18),
                                )
                              else
                                Icon(
                                  post.isLiked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: post.isLiked
                                      ? AppColors.heartPink
                                      : AppColors.primaryPurple,
                                  size: 21,
                                ),
                              const SizedBox(width: 5),
                              Text(
                                '${post.likesCount}',
                                style: AppTypography.subtitle.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showReactionPickerSheet(
                          context,
                          startedFromHold: false,
                        ),
                        onLongPressStart: (details) =>
                            _startContinuousReactionWheel(
                              context,
                              details.globalPosition,
                            ),
                        onLongPressMoveUpdate: (details) =>
                            _updateContinuousReactionWheel(
                              details.globalPosition,
                            ),
                        onLongPressEnd: (_) => _endContinuousReactionWheel(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.pastelLavender.withValues(
                              alpha: 0.72,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          child: Text(
                            'React +',
                            style: AppTypography.subtitle.copyWith(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () => _showCommentsSheet(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: AppColors.primaryPurple,
                                size: 20,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${post.commentsCount}',
                                style: AppTypography.subtitle.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Share post',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.share_outlined,
                          color: AppColors.primaryPurple,
                          size: 20,
                        ),
                        onPressed: () => _sharePost(context),
                      ),
                      IconButton(
                        tooltip: post.isSaved
                            ? 'Remove saved post'
                            : 'Save post',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          post.isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: AppColors.primaryPurple,
                          size: 21,
                        ),
                        onPressed: () => _handleSaveTap(context),
                      ),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.more_horiz_rounded,
                          color: AppColors.primaryPurple,
                          size: 20,
                        ),
                        onPressed: () => _showPostOptionsSheet(context),
                      ),
                    ],
                  ),

                  // Inline Preview: Up to 5 Recent Comments (Instagram / Facebook style)
                  if (post.comments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _showCommentsSheet(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.pastelLavender.withValues(
                            alpha: 0.48,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final c in post.comments.reversed.take(5).toList().reversed)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: RichText(
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                    style: AppTypography.bodyRegular.copyWith(
                                      fontSize: 12.5,
                                      color: AppColors.textPrimary,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '${c.authorName} ',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryPurple,
                                        ),
                                      ),
                                      if (c.replyToHandle != null &&
                                          c.replyToHandle!.isNotEmpty)
                                        TextSpan(
                                          text: '${c.replyToHandle} ',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF8B2E9D),
                                          ),
                                        ),
                                      TextSpan(text: c.body),
                                    ],
                                  ),
                                ),
                              ),
                            if (post.commentsCount > 5 ||
                                post.comments.length > 5)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  'View all ${math.max(post.commentsCount, post.comments.length)} comments',
                                  style: AppTypography.subtitle.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (post.allowComments) ...[
                    const SizedBox(height: 9),
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => _showCommentsSheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.84),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.95),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.add_comment_outlined,
                              size: 16,
                              color: AppColors.primaryPurple,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Write a supportive comment…',
                                style: AppTypography.subtitle.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            const Text(
                              'Reply',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAuthorProfile(BuildContext context) async {
    final state = SakhiPrototypeState.instance;
    final username = post.authorUsername.trim();
    final normalized = username.replaceFirst(RegExp(r'^@'), '').toLowerCase();
    FollowerUserModel? member;

    for (final candidate in state.followers) {
      if (post.authorAccountId.isNotEmpty &&
          candidate.id == post.authorAccountId) {
        member = candidate;
        break;
      }
      if (normalized.isNotEmpty &&
          candidate.username.replaceFirst(RegExp(r'^@'), '').toLowerCase() ==
              normalized) {
        member = candidate;
        break;
      }
    }

    if (member == null && username.isNotEmpty) {
      final members = await state.searchVisibleMembers(username);
      if (!context.mounted) return;
      if (members != null) {
        for (final candidate in members) {
          if (post.authorAccountId.isNotEmpty &&
              candidate.id == post.authorAccountId) {
            member = candidate;
            break;
          }
          if (candidate.username
                  .replaceFirst(RegExp(r'^@'), '')
                  .toLowerCase() ==
              normalized) {
            member = candidate;
            break;
          }
        }
      }
    }

    member ??= FollowerUserModel(
      id: post.authorAccountId,
      name: post.authorName,
      username: username.isNotEmpty
          ? (username.startsWith('@') ? username : '@$username')
          : '@sakhi_member',
      location: post.locationTag ?? 'India',
      avatarAsset: post.authorAvatar,
      isFollowing: state.isFollowingAuthor(post),
      isVerified: post.authorVerified,
      canFollow: post.authorAccountId.isNotEmpty &&
          post.authorAccountId != state.currentUser.accountId,
    );

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchResultMemberProfileScreen(member: member!),
      ),
    );
  }

  Future<void> _handleLikeTap(BuildContext context) async {
    final succeeded = await widget.onLikeTap();
    if (!context.mounted || succeeded) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Your reaction was not saved. Check your connection and retry.',
        ),
      ),
    );
  }

  Future<void> _handleSaveTap(BuildContext context) async {
    final succeeded = await widget.onSaveTap();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded
              ? (post.isSaved
                    ? 'Added to Saved Posts.'
                    : 'Removed from Saved Posts.')
              : 'Saved posts could not be updated. No change was kept.',
        ),
      ),
    );
  }

  Future<void> _sharePost(BuildContext context) async {
    final hashtags = post.hashtags
        .map((tag) => tag.startsWith('#') ? tag : '#$tag')
        .join(' ');
    final text = [
      post.content.trim(),
      if (hashtags.isNotEmpty) hashtags,
      '— ${post.authorName} (${post.authorUsername}) on Sakhi',
    ].where((part) => part.isNotEmpty).join('\n\n');
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'Sakhi community post'),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post text copied. A share sheet was not available.'),
          ),
        );
      }
    }
  }

  void _showMediaViewer(BuildContext context) {
    final source = post.imageAsset?.trim() ?? '';
    if (source.isEmpty) return;
    final size = MediaQuery.sizeOf(context);
    final isVideo = post.mediaContentType == 'video/mp4';
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: SizedBox(
          width: size.width,
          height: size.height * 0.94,
          child: Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: SizedBox(
                      width: size.width,
                      height: size.height * 0.78,
                      child: isVideo
                          ? SakhiRemoteMediaVideo(
                              source: source,
                              fit: BoxFit.contain,
                            )
                          : _isRemoteUrl(source)
                          ? SakhiRemoteMediaImage(
                              source: source,
                              width: size.width,
                              height: size.height * 0.78,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Center(
                                child: Text(
                                  'Media could not be loaded.',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            )
                          : Image.asset(
                              source,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Center(
                                child: Text(
                                  'Media could not be loaded.',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: SafeArea(
                  child: IconButton(
                    tooltip: 'Close media viewer',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
              if (!isVideo)
                Positioned(
                  bottom: 18,
                  left: 16,
                  right: 16,
                  child: SafeArea(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _handleLikeTap(context);
                      },
                      icon: const Icon(Icons.favorite_border_rounded),
                      label: const Text('Like this post'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      color: AppColors.pastelPink,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: AppColors.primaryPurple,
              size: 32,
            ),
            SizedBox(height: 4),
            Text('Media unavailable right now', style: AppTypography.subtitle),
          ],
        ),
      ),
    );
  }

  void _showReactionPickerSheet(
    BuildContext context, {
    required bool startedFromHold,
  }) {
    if (_wheelDialogOpen) return;
    _wheelDialogOpen = true;
    HapticFeedback.mediumImpact();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close reaction wheel',
      barrierColor: Colors.black.withValues(alpha: 0.36),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, anim1, anim2) {
        return _SakhiRadialReactionWheelDialog(
          post: post,
          reactions: FeedPostCard._wheelReactions,
          externalDragGlobalPosition: _dragGlobalPosition,
          externalDragReleaseSignal: _dragReleaseSignal,
          startedFromHold: startedFromHold,
          onSelectReaction: (reactionKey, emoji, label) async {
            HapticFeedback.lightImpact();
            await SakhiPrototypeState.instance.reactToPost(post, reactionKey);
          },
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    ).whenComplete(() {
      _wheelDialogOpen = false;
      _dragGlobalPosition.value = null;
    });
  }

  void _showCommentsSheet(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    unawaited(state.loadComments(post.id));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SakhiInstagramCommentsSheet(post: post),
    );
  }

  void _showEditPostDialog(BuildContext context) {
    final controller = TextEditingController(text: post.content);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: const Text('Edit Your Post', style: AppTypography.sectionTitle),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Update your post...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          SakhiPillButton(
            label: 'Save Changes',
            onPressed: () async {
              final updated = await SakhiPrototypeState.instance.updatePost(
                post,
                content: controller.text,
              );
              if (!ctx.mounted) return;
              if (!updated) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Post could not be updated. No change was made.',
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              SakhiDialogs.showPrototypeSnackbar(
                context,
                'Your post was updated.',
              );
            },
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    const reasons = [
      'Harassment or bullying',
      'Fake account or impersonation',
      'Inappropriate or unsafe content',
      'Spam or scam',
      'Hate speech or discrimination',
      'Other safety concern',
    ];
    var selected = reasons.first;
    final detailsCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardSurface,
          title: const Text('Report Post', style: AppTypography.sectionTitle),
          content: SingleChildScrollView(
            child: RadioGroup<String>(
              groupValue: selected,
              onChanged: (value) {
                if (value != null) {
                  setDialogState(() => selected = value);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Confidential: Your identity is never disclosed to the reported member.',
                    style: AppTypography.subtitle,
                  ),
                  const SizedBox(height: 8),
                  ...reasons.map(
                    (r) => RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: r,
                      activeColor: AppColors.primaryPurple,
                      title: Text(r, style: AppTypography.bodyRegular),
                    ),
                  ),
                  TextField(
                    controller: detailsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Additional details (optional)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            SakhiPillButton(
              label: 'Submit Report',
              backgroundColor: AppColors.sosRed,
              onPressed: () async {
                final submitted = await SakhiPrototypeState.instance
                    .reportUserOrPost(
                      targetHandle: post.authorUsername,
                      postId: post.id,
                      category: selected.toLowerCase().replaceAll(' ', '_'),
                      reason: selected,
                      details: detailsCtrl.text,
                    );
                if (!ctx.mounted) return;
                if (!submitted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'The report was not submitted. Check your connection and retry.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                SakhiDialogs.showPrototypeSnackbar(
                  context,
                  'Report submitted confidentially to Sakhi safety moderators.',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPostOptionsSheet(BuildContext context) {
    final isOwn =
        post.isOwnPost ||
        post.authorUsername ==
            SakhiPrototypeState.instance.currentUser.username;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOwn) ...[
                ListTile(
                  leading: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.primaryPurple,
                  ),
                  title: const Text('Edit Post'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditPostDialog(context);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.sosRed,
                  ),
                  title: const Text(
                    'Delete Post',
                    style: TextStyle(color: AppColors.sosRed),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Delete this post?'),
                        content: const Text(
                          'This removes the post from the Social Wall. This action cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.sosRed,
                            ),
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Delete Post'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    final deleted = await SakhiPrototypeState.instance
                        .deletePost(post.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          deleted
                              ? 'Your post was deleted.'
                              : 'The post could not be deleted. No change was made.',
                        ),
                      ),
                    );
                  },
                ),
              ],
              ListTile(
                leading: const Icon(
                  Icons.bookmark_border_rounded,
                  color: AppColors.primaryPurple,
                ),
                title: Text(
                  post.isSaved ? 'Remove from Saved Posts' : 'Save Post',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onSaveTap();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.share_outlined,
                  color: AppColors.primaryPurple,
                ),
                title: const Text('Share Post'),
                subtitle: const Text(
                  'Open the device share sheet or copy the post text.',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _sharePost(context);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.visibility_off_outlined,
                  color: AppColors.primaryPurple,
                ),
                title: const Text('Hide or Mute Post'),
                onTap: () {
                  Navigator.pop(ctx);
                  SakhiDialogs.showPrototypeSnackbar(
                    context,
                    'Post hidden from your Social Wall view.',
                  );
                },
              ),
              if (!isOwn) ...[
                ListTile(
                  leading: const Icon(
                    Icons.flag_outlined,
                    color: AppColors.sosRed,
                  ),
                  title: const Text('Report Post'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showReportDialog(context);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.shield_moon_rounded,
                    color: AppColors.primaryPurple,
                  ),
                  title: const Text(
                    'Report Discreetly (Anonymous / Confidential)',
                  ),
                  subtitle: const Text(
                    'File an anonymous or confidential safety report with photo privacy protection',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DiscreetComplaintHubScreen(
                          initialLinkedPostId: post.id,
                          initialLinkedProfileHandle: post.authorUsername,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.block_rounded,
                    color: AppColors.sosRed,
                  ),
                  title: Text(
                    'Block ${post.authorName}',
                    style: const TextStyle(color: AppColors.sosRed),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: Text('Block ${post.authorUsername}?'),
                        content: const Text(
                          'Blocked members are removed from your Social Wall view. You can manage blocked members in Settings.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.sosRed,
                            ),
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Block Member'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    final blocked = await SakhiPrototypeState.instance
                        .toggleBlockedUser(
                          username: post.authorUsername,
                          displayName: post.authorName,
                          accountId: post.authorAccountId,
                        );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          blocked
                              ? '${post.authorName} was blocked.'
                              : 'Member could not be blocked. No change was made.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact Animated Bouncing Emoji Reaction Stack.
/// Displays at most the top 3–4 active emojis with a subtle floating bounce animation
/// plus a compact total count so even 10,000+ reactions never clutter the post card.
class _SakhiBouncingReactionBadges extends StatefulWidget {
  final List<String> emojis;
  final int totalReactions;

  const _SakhiBouncingReactionBadges({
    required this.emojis,
    required this.totalReactions,
  });

  @override
  State<_SakhiBouncingReactionBadges> createState() =>
      _SakhiBouncingReactionBadgesState();
}

class _SakhiBouncingReactionBadgesState
    extends State<_SakhiBouncingReactionBadges>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.88),
                AppColors.pastelLavender.withValues(alpha: 0.72),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.94),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < widget.emojis.length; i++)
                Transform.translate(
                  offset: Offset(
                    0,
                    math.sin((_controller.value * math.pi) + (i * 0.9)) * -2.2,
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(right: i == widget.emojis.length - 1 ? 6 : 3),
                    child: Text(
                      widget.emojis[i],
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                ),
              Text(
                '${_formatCount(widget.totalReactions)} ${widget.totalReactions == 1 ? 'reaction' : 'reactions'}',
                style: AppTypography.subtitle.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryPurple,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Instagram / Facebook-Style Draggable Comments Bottom Sheet with @username Threaded Replies.
class _SakhiInstagramCommentsSheet extends StatefulWidget {
  final FeedPostModel post;

  const _SakhiInstagramCommentsSheet({required this.post});

  @override
  State<_SakhiInstagramCommentsSheet> createState() =>
      _SakhiInstagramCommentsSheetState();
}

class _SakhiInstagramCommentsSheetState
    extends State<_SakhiInstagramCommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  PostCommentItem? _replyingTo;
  bool _isSubmitting = false;

  static const List<String> _quickEmojis = [
    '❤️',
    '🙌',
    '🔥',
    '🌸',
    '💜',
    '👏',
    '✨',
    '🙏',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _startReply(PostCommentItem comment) {
    final handle = comment.authorUsername.trim().isNotEmpty &&
            comment.authorUsername != '@member'
        ? (comment.authorUsername.startsWith('@')
              ? comment.authorUsername
              : '@${comment.authorUsername}')
        : '@${comment.authorName.toLowerCase().replaceAll(' ', '_')}';
    setState(() {
      _replyingTo = comment;
    });
    if (!_controller.text.startsWith('$handle ')) {
      _controller.text = '$handle ';
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
    _inputFocusNode.requestFocus();
  }

  void _insertEmoji(String emoji) {
    final text = _controller.text;
    final next = '$text$emoji';
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _inputFocusNode.requestFocus();
  }

  Future<void> _submitComment() async {
    final rawText = _controller.text.trim();
    if (rawText.isEmpty || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    final replyTarget = _replyingTo;
    final replyHandle = replyTarget != null
        ? (replyTarget.authorUsername.isNotEmpty &&
                  replyTarget.authorUsername != '@member'
              ? replyTarget.authorUsername
              : '@${replyTarget.authorName.toLowerCase().replaceAll(' ', '_')}')
        : null;

    final submitted = await SakhiPrototypeState.instance.addPostComment(
      widget.post,
      rawText,
      parentCommentId: replyTarget?.id,
      replyToHandle: replyHandle,
    );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      if (submitted) {
        _controller.clear();
        _replyingTo = null;
      }
    });
    if (!submitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Comment could not be posted. Check your connection and retry.',
          ),
        ),
      );
    }
  }

  void _showEditCommentDialog(PostCommentItem comment) {
    final editCtrl = TextEditingController(text: comment.body);
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: const Text('Edit Comment', style: AppTypography.sectionTitle),
        content: TextField(
          controller: editCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Update your comment...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          SakhiPillButton(
            label: 'Save',
            onPressed: () async {
              final nextText = editCtrl.text.trim();
              if (nextText.isEmpty) return;
              final ok = await SakhiPrototypeState.instance.editComment(
                widget.post.id,
                comment.id,
                nextText,
              );
              if (!dialogCtx.mounted) return;
              Navigator.of(dialogCtx).pop();
              if (!mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok ? 'Comment updated.' : 'Could not update comment.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    final mq = MediaQuery.of(context);
    final maxAllowedHeight = (mq.size.height - mq.viewInsets.bottom - mq.padding.top - 24).clamp(240.0, 740.0);
    final sheetHeight = (mq.size.height * 0.78).clamp(240.0, maxAllowedHeight);

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final comments = widget.post.comments;
        return Padding(
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                height: sheetHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.94),
                      const Color(0xFFFDF4FA).withValues(alpha: 0.96),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.95),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Comments (${comments.length})',
                              textAlign: TextAlign.center,
                              style: AppTypography.sectionTitle.copyWith(
                                fontSize: 16.5,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: comments.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 40,
                                      color: AppColors.primaryPurple.withValues(
                                        alpha: 0.45,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'No comments yet',
                                      style: AppTypography.cardTitle,
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Start the conversation with a supportive reply.',
                                      style: AppTypography.subtitle,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                18,
                              ),
                              itemCount: comments.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, idx) {
                                final comment = comments[idx];
                                final isReply =
                                    (comment.parentCommentId != null &&
                                        comment.parentCommentId!.isNotEmpty) ||
                                    (comment.replyToHandle != null &&
                                        comment.replyToHandle!.isNotEmpty) ||
                                    comment.body.trim().startsWith('@');
                                return Padding(
                                  padding: EdgeInsets.only(
                                    left: isReply ? 28.0 : 0.0,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SakhiAvatar(
                                        imageAsset: comment.authorAvatar,
                                        fallbackLabel: comment.authorName,
                                        size: isReply ? 28 : 34,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    comment.authorName,
                                                    style: AppTypography
                                                        .bodyMedium
                                                        .copyWith(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  comment.createdAt,
                                                  style: AppTypography.caption
                                                      .copyWith(fontSize: 11),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              comment.body,
                                              style: AppTypography.bodyRegular
                                                  .copyWith(
                                                    fontSize: 13.5,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                            ),
                                            const SizedBox(height: 5),
                                            Row(
                                              children: [
                                                InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  onTap: () =>
                                                      _startReply(comment),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 2,
                                                          horizontal: 4,
                                                        ),
                                                    child: Text(
                                                      'Reply',
                                                      style: AppTypography
                                                          .caption
                                                          .copyWith(
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: AppColors
                                                                .primaryPurple,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                if (comment.canEdit ||
                                                    comment.isOwnComment ||
                                                    (comment.authorAccountId.isNotEmpty &&
                                                        comment.authorAccountId ==
                                                            state.currentUser.accountId) ||
                                                    comment.authorName.trim().toLowerCase() ==
                                                        state.currentUser.displayName.trim().toLowerCase()) ...[
                                                  const SizedBox(width: 12),
                                                  InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    onTap: () =>
                                                        _showEditCommentDialog(
                                                          comment,
                                                        ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 2,
                                                            horizontal: 4,
                                                          ),
                                                      child: Text(
                                                        'Edit',
                                                        style: AppTypography
                                                            .caption
                                                            .copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                if (comment.canDelete ||
                                                    comment.isOwnComment ||
                                                    (comment.authorAccountId.isNotEmpty &&
                                                        comment.authorAccountId ==
                                                            state.currentUser.accountId) ||
                                                    comment.authorName.trim().toLowerCase() ==
                                                        state.currentUser.displayName.trim().toLowerCase() ||
                                                    widget.post.isOwnPost) ...[
                                                  const SizedBox(width: 12),
                                                  InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    onTap: () async {
                                                      await state.removeComment(
                                                        widget.post.id,
                                                        comment.id,
                                                      );
                                                      if (mounted) {
                                                        setState(() {});
                                                      }
                                                    },
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 2,
                                                            horizontal: 4,
                                                          ),
                                                      child: Text(
                                                        'Delete',
                                                        style: AppTypography
                                                            .caption
                                                            .copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: AppColors
                                                                  .sosRed,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    if (_replyingTo != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        color: AppColors.pastelLavender,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Replying to ${_replyingTo!.authorName}',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primaryPurple,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _replyingTo = null),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppColors.primaryPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (widget.post.allowComments) ...[
                      const Divider(height: 1),
                      // Instagram Quick Supportive Emoji Strip
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: _quickEmojis
                              .map(
                                (emoji) => GestureDetector(
                                  onTap: () => _insertEmoji(emoji),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                          child: Row(
                            children: [
                              SakhiAvatar(
                                imageAsset: state.currentUser.avatarAsset,
                                fallbackLabel: state.currentUser.displayName,
                                size: 32,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _inputFocusNode,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _submitComment(),
                                  decoration: InputDecoration(
                                    hintText: _replyingTo != null
                                        ? 'Reply to ${_replyingTo!.authorName}...'
                                        : 'Add a supportive comment...',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(999),
                                      borderSide: const BorderSide(
                                        color: AppColors.borderSubtle,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(999),
                                      borderSide: const BorderSide(
                                        color: AppColors.borderSubtle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SakhiPillButton(
                                label: _isSubmitting ? '...' : 'Post Comment',
                                onPressed: _isSubmitting
                                    ? null
                                    : _submitComment,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SakhiRadialReactionWheelDialog extends StatefulWidget {
  final FeedPostModel post;
  final List<Map<String, String>> reactions;
  final ValueNotifier<Offset?> externalDragGlobalPosition;
  final ValueNotifier<int> externalDragReleaseSignal;
  final bool startedFromHold;
  final Future<void> Function(String key, String emoji, String label)
  onSelectReaction;

  const _SakhiRadialReactionWheelDialog({
    required this.post,
    required this.reactions,
    required this.externalDragGlobalPosition,
    required this.externalDragReleaseSignal,
    required this.startedFromHold,
    required this.onSelectReaction,
  });

  @override
  State<_SakhiRadialReactionWheelDialog> createState() =>
      _SakhiRadialReactionWheelDialogState();
}

class _SakhiRadialReactionWheelDialogState
    extends State<_SakhiRadialReactionWheelDialog>
    with SingleTickerProviderStateMixin {
  final GlobalKey _wheelKey = GlobalKey();
  int? _hoveredIndex;
  String? _burstEmoji;
  String? _burstLabel;
  bool _hasDraggedOntoSector = false;
  bool _isSelecting = false;
  late final AnimationController _burstController;

  @override
  void initState() {
    super.initState();
    final currentKey = widget.post.viewerReaction;
    if (currentKey != null) {
      final idx = widget.reactions.indexWhere((r) => r['key'] == currentKey);
      if (idx != -1) _hoveredIndex = idx;
    }
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    widget.externalDragGlobalPosition.addListener(_onExternalFingerMove);
    widget.externalDragReleaseSignal.addListener(_onExternalFingerRelease);
  }

  @override
  void dispose() {
    widget.externalDragGlobalPosition.removeListener(_onExternalFingerMove);
    widget.externalDragReleaseSignal.removeListener(_onExternalFingerRelease);
    _burstController.dispose();
    super.dispose();
  }

  void _onExternalFingerMove() {
    final globalPos = widget.externalDragGlobalPosition.value;
    if (globalPos == null || !mounted) return;
    final box = _wheelKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final localPos = box.globalToLocal(globalPos);
    _updateHoverFromOffset(localPos, box.size);
  }

  void _onExternalFingerRelease() {
    if (!mounted || _isSelecting) return;
    if (_hasDraggedOntoSector && _hoveredIndex != null) {
      _triggerSelection(_hoveredIndex!);
    }
  }

  void _updateHoverFromOffset(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 24 || dist > 200) return;

    var angle = math.atan2(dy, dx);
    if (angle < 0) angle += 2 * math.pi;
    final sectorAngle = (2 * math.pi) / widget.reactions.length;
    final normalized = (angle + math.pi / 2 + sectorAngle / 2) % (2 * math.pi);
    final index = (normalized / sectorAngle).floor() % widget.reactions.length;
    _hasDraggedOntoSector = true;
    if (_hoveredIndex != index) {
      HapticFeedback.selectionClick();
      setState(() => _hoveredIndex = index);
    }
  }

  Future<void> _triggerSelection(int index) async {
    if (_isSelecting) return;
    _isSelecting = true;
    final item = widget.reactions[index];
    setState(() {
      _hoveredIndex = index;
      _burstEmoji = item['emoji'];
      _burstLabel = item['label'];
    });
    _burstController.forward(from: 0);
    await widget.onSelectReaction(
      item['key']!,
      item['emoji']!,
      item['label']!,
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    const double wheelSize = 320;
    const double orbitRadius = 112;
    final hovered = _hoveredIndex != null
        ? widget.reactions[_hoveredIndex!]
        : null;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerMove: (event) {
        final box = _wheelKey.currentContext?.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          _updateHoverFromOffset(box.globalToLocal(event.position), box.size);
        }
      },
      onPointerUp: (_) {
        if (_hasDraggedOntoSector && _hoveredIndex != null) {
          _triggerSelection(_hoveredIndex!);
        }
      },
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onPanStart: (details) => _updateHoverFromOffset(
              details.localPosition,
              const Size(wheelSize, wheelSize),
            ),
            onPanUpdate: (details) => _updateHoverFromOffset(
              details.localPosition,
              const Size(wheelSize, wheelSize),
            ),
            onPanEnd: (_) {
              if (_hoveredIndex != null) {
                _triggerSelection(_hoveredIndex!);
              }
            },
            child: SizedBox(
              width: wheelSize,
              height: wheelSize + 58,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                        child: Text(
                          hovered != null
                              ? '${hovered['emoji']} ${hovered['label']} • Release or Tap to React'
                              : 'Slide Finger or Tap Any Emoji • Sisterhood Wheel',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    key: _wheelKey,
                    width: wheelSize,
                    height: wheelSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                            child: Container(
                              width: wheelSize,
                              height: wheelSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(
                                      0xFFFDF4FA,
                                    ).withValues(alpha: 0.58),
                                    const Color(
                                      0xFFF3E2FA,
                                    ).withValues(alpha: 0.90),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.94),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryPurple.withValues(
                                      alpha: 0.24,
                                    ),
                                    blurRadius: 32,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _burstController,
                          builder: (context, _) {
                            final burstScale =
                                1.0 +
                                math.sin(_burstController.value * math.pi) *
                                    0.45;
                            return Transform.scale(
                              scale: _burstEmoji != null ? burstScale : 1.0,
                              child: Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF88299F),
                                      Color(0xFF5A1868),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x445A1868),
                                      blurRadius: 16,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _burstEmoji ?? hovered?['emoji'] ?? '🌸',
                                      style: const TextStyle(fontSize: 30),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _burstLabel ??
                                          hovered?['label'] ??
                                          'React',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        for (int i = 0; i < widget.reactions.length; i++)
                          Builder(
                            builder: (context) {
                              final item = widget.reactions[i];
                              final angle =
                                  -math.pi / 2 +
                                  (i * 2 * math.pi / widget.reactions.length);
                              final dx = orbitRadius * math.cos(angle);
                              final dy = orbitRadius * math.sin(angle);
                              final isSelected =
                                  _hoveredIndex == i ||
                                  widget.post.viewerReaction == item['key'];

                              return Transform.translate(
                                offset: Offset(dx, dy),
                                child: GestureDetector(
                                  onTap: () => _triggerSelection(i),
                                  child: AnimatedScale(
                                    duration: const Duration(milliseconds: 140),
                                    scale: isSelected ? 1.28 : 1.0,
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? AppColors.primaryPurple
                                            : Colors.white.withValues(
                                                alpha: 0.94,
                                              ),
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.borderSubtle,
                                          width: isSelected ? 2.2 : 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primaryPurple
                                                .withValues(
                                                  alpha: isSelected
                                                      ? 0.34
                                                      : 0.08,
                                                ),
                                            blurRadius: isSelected ? 14 : 6,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            item['emoji']!,
                                            style: const TextStyle(
                                              fontSize: 22,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            item['label']!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                              color: isSelected
                                                  ? Colors.white
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
