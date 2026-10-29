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

/// Module 3 Social Wall Post Card supporting 8 reaction types, comment CRUD with
/// ownership enforcement, post edit/delete for owners, and confidential report/block.
class FeedPostCard extends StatelessWidget {
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
    // Legacy compatibility keys
    'LIKE': {'emoji': '❤️', 'label': 'Love'},
    'INSPIRED': {'emoji': '✨', 'label': 'Inspired'},
    'HAPPY': {'emoji': '😊', 'label': 'Happy'},
    'STRONG': {'emoji': '💪', 'label': 'Strong'},
    'CARE': {'emoji': '🌸', 'label': 'Care'},
  };

  static const List<Map<String, String>> _wheelReactions = [
    {'key': 'LOVE', 'emoji': '❤️', 'label': 'Love', 'fx': 'Pulse Heart'},
    {'key': 'SUPPORT', 'emoji': '🌸', 'label': 'Support', 'fx': 'Lotus Bloom'},
    {'key': 'SOLIDARITY', 'emoji': '🤝', 'label': 'Solidarity', 'fx': 'Sisterhood'},
    {'key': 'HAHA', 'emoji': '😂', 'label': 'Haha', 'fx': 'Joy Burst'},
    {'key': 'CRYING', 'emoji': '😢', 'label': 'Crying', 'fx': 'Empathy Tear'},
    {'key': 'FIERCE', 'emoji': '🔥', 'label': 'Fierce', 'fx': 'Power Flame'},
    {'key': 'GRATEFUL', 'emoji': '🙏', 'label': 'Grateful', 'fx': 'Warmth'},
    {'key': 'APPLAUD', 'emoji': '👏', 'label': 'Applaud', 'fx': 'Ovation'},
  ];

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

  @override
  Widget build(BuildContext context) {
    final activeReaction = post.viewerReaction != null
        ? _reactions[post.viewerReaction!]
        : null;

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
                                if (showVerifiedCheck ||
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
                          ),
                          child: Text(
                            post.categoryBadge!,
                            style: AppTypography.subtitle.copyWith(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (!post.isOwnPost) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEAF2),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusPill,
                            ),
                            border: Border.all(color: const Color(0xFFE5BDD1)),
                          ),
                          child: Text(
                            '+ Follow',
                            style: AppTypography.subtitle.copyWith(
                              color: AppColors.primaryPurple,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
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

                  if (post.reactionBreakdown.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      children: post.reactionBreakdown.entries.map((e) {
                        final emoji = _reactions[e.key]?['emoji'] ?? '❤️';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.pastelLavender,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$emoji ${e.value}',
                            style: AppTypography.subtitle.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _handleLikeTap(context),
                        onLongPress: () => _showReactionPickerSheet(context),
                        borderRadius: BorderRadius.circular(8),
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
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _showReactionPickerSheet(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Text(
                            'React +',
                            style: AppTypography.subtitle.copyWith(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
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
                                  fontWeight: FontWeight.w600,
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
                  if (post.comments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.pastelLavender.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final c in post.comments.take(2))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
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
                                      text: '${c.authorName}: ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryPurple,
                                      ),
                                    ),
                                    TextSpan(text: c.body),
                                  ],
                                ),
                              ),
                            ),
                          if (post.comments.length > 2)
                            InkWell(
                              onTap: () => _showCommentsSheet(context),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'View all ${post.commentsCount} comments',
                                  style: AppTypography.subtitle.copyWith(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                              ),
                            ),
                        ],
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
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.borderSubtle),
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

    // 1. Resolve by exact authorAccountId or exact @username from local directory first
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

    // 2. Query backend search if not in local cache
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

    // 3. Fallback to direct profile model keyed by post.authorAccountId & post.authorUsername
    member ??= FollowerUserModel(
      id: post.authorAccountId,
      name: post.authorName,
      username: username.isNotEmpty
          ? (username.startsWith('@') ? username : '@$username')
          : '@sakhi_member',
      location: post.locationTag ?? 'India',
      avatarAsset: post.authorAvatar,
      isFollowing: false,
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
    final succeeded = await onLikeTap();
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
    final succeeded = await onSaveTap();
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

  void _showReactionPickerSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close reaction wheel',
      barrierColor: Colors.black.withValues(alpha: 0.38),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, anim1, anim2) {
        return _SakhiRadialReactionWheelDialog(
          post: post,
          reactions: _wheelReactions,
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
    );
  }

  void _showEditCommentDialog(
    BuildContext context,
    PostCommentItem comment,
    VoidCallback onUpdated,
  ) {
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
                post.id,
                comment.id,
                nextText,
              );
              if (!dialogCtx.mounted) return;
              Navigator.of(dialogCtx).pop();
              onUpdated();
              if (!context.mounted) return;
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

  void _showCommentsSheet(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    state.loadComments(post.id);
    final controller = TextEditingController();
    var isSubmittingComment = false;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AnimatedBuilder(
        animation: state,
        builder: (ctx, _) => StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 18,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comments on ${post.authorName}\'s post (${post.comments.length})',
                  style: AppTypography.sectionTitle,
                ),
                const SizedBox(height: 10),
                if (post.comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No comments yet. Share a supportive note!',
                      style: AppTypography.subtitle,
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: post.comments.length,
                      separatorBuilder: (_, _) => const Divider(height: 16),
                      itemBuilder: (context, idx) {
                        final comment = post.comments[idx];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SakhiAvatar(
                              imageAsset: comment.authorAvatar,
                              fallbackLabel: comment.authorName,
                              size: 34,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${comment.authorName} • ${comment.createdAt}',
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    comment.body,
                                    style: AppTypography.bodyRegular,
                                  ),
                                ],
                              ),
                            ),
                            if (comment.canEdit || comment.isOwnComment)
                              IconButton(
                                tooltip: 'Edit comment',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 17,
                                  color: AppColors.primaryPurple,
                                ),
                                onPressed: () => _showEditCommentDialog(
                                  ctx,
                                  comment,
                                  () => setModalState(() {}),
                                ),
                              ),
                            if (comment.canDelete ||
                                comment.isOwnComment ||
                                post.isOwnPost)
                              IconButton(
                                tooltip: 'Delete comment',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: AppColors.sosRed,
                                ),
                                onPressed: () async {
                                  final removed = await state.removeComment(
                                    post.id,
                                    comment.id,
                                  );
                                  if (!ctx.mounted) return;
                                  setModalState(() {});
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        removed
                                            ? 'Comment removed.'
                                            : 'Could not remove this comment. No change was made.',
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                if (!post.allowComments)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'Comments are turned off for this post.',
                      style: AppTypography.subtitle,
                    ),
                  ),
                if (post.allowComments) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Write an encouraging reply...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SakhiPillButton(
                      label: 'Post Comment',
                      onPressed: isSubmittingComment
                          ? null
                          : () async {
                              final text = controller.text.trim();
                              if (text.isEmpty) return;
                              setModalState(() => isSubmittingComment = true);
                              final submitted = await state.addPostComment(
                                post,
                                text,
                              );
                              if (!ctx.mounted) return;
                              setModalState(() {
                                isSubmittingComment = false;
                                if (submitted) controller.clear();
                              });
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    submitted
                                        ? 'Comment added!'
                                        : 'Comment could not be posted. Your text is still here; retry when connected.',
                                  ),
                                ),
                              );
                            },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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
                          deleted ? 'Your post was deleted.' : 'The post could not be deleted. No change was made.',
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
                  onSaveTap();
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
                  title: const Text('Report Discreetly (Anonymous / Confidential)'),
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
                          blocked ? '${post.authorName} was blocked.' : 'Member could not be blocked. No change was made.',
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

class _SakhiRadialReactionWheelDialog extends StatefulWidget {
  final FeedPostModel post;
  final List<Map<String, String>> reactions;
  final Future<void> Function(String key, String emoji, String label)
  onSelectReaction;

  const _SakhiRadialReactionWheelDialog({
    required this.post,
    required this.reactions,
    required this.onSelectReaction,
  });

  @override
  State<_SakhiRadialReactionWheelDialog> createState() =>
      _SakhiRadialReactionWheelDialogState();
}

class _SakhiRadialReactionWheelDialogState
    extends State<_SakhiRadialReactionWheelDialog>
    with SingleTickerProviderStateMixin {
  int? _hoveredIndex;
  String? _burstEmoji;
  String? _burstLabel;
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
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void dispose() {
    _burstController.dispose();
    super.dispose();
  }

  void _updateHoverFromOffset(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 34 || dist > 165) return;

    var angle = math.atan2(dy, dx);
    if (angle < 0) angle += 2 * math.pi;
    final sectorAngle = (2 * math.pi) / widget.reactions.length;
    final normalized = (angle + math.pi / 2 + sectorAngle / 2) % (2 * math.pi);
    final index = (normalized / sectorAngle).floor() % widget.reactions.length;
    if (_hoveredIndex != index) {
      HapticFeedback.selectionClick();
      setState(() => _hoveredIndex = index);
    }
  }

  Future<void> _triggerSelection(int index) async {
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
    await Future<void>.delayed(const Duration(milliseconds: 380));
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

    return Center(
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
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
            height: wheelSize + 54,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top iOS 26 Liquid Glass Pill Header
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
                        color: Colors.white.withValues(alpha: 0.84),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      child: Text(
                        hovered != null
                            ? '${hovered['emoji']} ${hovered['label']} • ${hovered['fx']}'
                            : 'Slide or Tap to React • Sakhi Sisterhood Wheel',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: wheelSize,
                  height: wheelSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Frosted iOS 26 Liquid Glass Outer Radial Ring
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
                                  const Color(0xFFFDF4FA).withValues(alpha: 0.55),
                                  const Color(0xFFF3E2FA).withValues(alpha: 0.88),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.9),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryPurple.withValues(
                                    alpha: 0.22,
                                  ),
                                  blurRadius: 32,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Center Hub showing active / hovered reaction or animated emoji burst
                      AnimatedBuilder(
                        animation: _burstController,
                        builder: (context, _) {
                          final burstScale =
                              1.0 + math.sin(_burstController.value * math.pi) * 0.45;
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
                                    _burstEmoji ??
                                        hovered?['emoji'] ??
                                        '🌸',
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
                      // 8 Radial Reaction Nodes around the 360° wheel
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
                                  duration: const Duration(milliseconds: 150),
                                  scale: isSelected ? 1.24 : 1.0,
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? AppColors.primaryPurple
                                          : Colors.white.withValues(alpha: 0.92),
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
                                                alpha: isSelected ? 0.32 : 0.08,
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
                                          style: const TextStyle(fontSize: 22),
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
    );
  }
}
