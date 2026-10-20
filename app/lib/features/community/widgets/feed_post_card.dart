import 'package:flutter/material.dart';

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
import 'breathing_exercise_banner.dart';

/// Module 3 Social Wall Post Card supporting 8 reaction types, comment CRUD with
/// ownership enforcement, post edit/delete for owners, and confidential report/block.
class FeedPostCard extends StatelessWidget {
  final FeedPostModel post;
  final VoidCallback onLikeTap;
  final VoidCallback onSaveTap;
  final bool showVerifiedCheck;

  const FeedPostCard({
    super.key,
    required this.post,
    required this.onLikeTap,
    required this.onSaveTap,
    this.showVerifiedCheck = false,
  });

  static const Map<String, Map<String, String>> _reactions = {
    'LIKE': {'emoji': '❤️', 'label': 'Like'},
    'LOVE': {'emoji': '🥰', 'label': 'Love'},
    'SUPPORT': {'emoji': '🤝', 'label': 'Support'},
    'INSPIRED': {'emoji': '✨', 'label': 'Inspired'},
    'HAPPY': {'emoji': '😊', 'label': 'Happy'},
    'GRATEFUL': {'emoji': '🙏', 'label': 'Grateful'},
    'STRONG': {'emoji': '💪', 'label': 'Strong'},
    'CARE': {'emoji': '🌸', 'label': 'Care'},
  };

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
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    post.authorName,
                                    style: AppTypography.cardTitle,
                                    overflow: TextOverflow.ellipsis,
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
                      children: post.hashtags
                          .map(
                            (tag) => Text(
                              tag.startsWith('#') ? tag : '#$tag',
                              style: AppTypography.subtitle.copyWith(
                                color: AppColors.primaryPurple,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],

                  if (post.imageAsset != null &&
                      post.imageAsset!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: AspectRatio(
                        aspectRatio: _aspectRatioForPreset(post.cropPreset),
                        child: _isRemoteUrl(post.imageAsset!)
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
                        onTap: onLikeTap,
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
                      const SizedBox(width: 14),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          post.isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: AppColors.primaryPurple,
                          size: 21,
                        ),
                        onPressed: onSaveTap,
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
                ],
              ),
            ),
          ],
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'React to ${post.authorName}\'s post',
                style: AppTypography.sectionTitle,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _reactions.entries.map((entry) {
                  final selected = post.viewerReaction == entry.key;
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.pop(ctx);
                      SakhiPrototypeState.instance.reactToPost(post, entry.key);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primaryPurple.withValues(alpha: 0.14)
                            : AppColors.pastelLavender,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppColors.primaryPurple
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.value['emoji']!,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            entry.value['label']!,
                            style: AppTypography.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCommentsSheet(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    state.loadComments(post.id);
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
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
                          if (comment.canDelete || post.isOwnPost)
                            IconButton(
                              tooltip: 'Delete comment',
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppColors.sosRed,
                              ),
                              onPressed: () async {
                                await state.removeComment(post.id, comment.id);
                                setModalState(() {});
                              },
                            ),
                        ],
                      );
                    },
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
                    onPressed: () {
                      final text = controller.text.trim();
                      if (text.isNotEmpty) {
                        state.addPostComment(post, text);
                        controller.clear();
                        setModalState(() {});
                        SakhiDialogs.showPrototypeSnackbar(
                          context,
                          'Comment added!',
                        );
                      }
                    },
                  ),
                ),
              ],
            ],
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
              await SakhiPrototypeState.instance.updatePost(
                post,
                content: controller.text,
              );
              if (!ctx.mounted) return;
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
                    groupValue: selected,
                    activeColor: AppColors.primaryPurple,
                    title: Text(r, style: AppTypography.bodyRegular),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selected = v);
                    },
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            SakhiPillButton(
              label: 'Submit Report',
              backgroundColor: AppColors.sosRed,
              onPressed: () {
                SakhiPrototypeState.instance.reportUserOrPost(
                  targetHandle: post.authorUsername,
                  postId: post.id,
                  category: selected.toLowerCase().replaceAll(' ', '_'),
                  reason: selected,
                  details: detailsCtrl.text,
                );
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
                  onTap: () {
                    Navigator.pop(ctx);
                    SakhiPrototypeState.instance.deletePost(post.id);
                    SakhiDialogs.showPrototypeSnackbar(
                      context,
                      'Your post was deleted.',
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
                title: const Text('Share within Sakhi'),
                onTap: () {
                  Navigator.pop(ctx);
                  SakhiDialogs.showPrototypeSnackbar(
                    context,
                    'Shared ${post.authorName}\'s post with your circle.',
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
                    Icons.block_rounded,
                    color: AppColors.sosRed,
                  ),
                  title: Text(
                    'Block ${post.authorName}',
                    style: const TextStyle(color: AppColors.sosRed),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    SakhiPrototypeState.instance.toggleBlockedUser(
                      username: post.authorUsername,
                      displayName: post.authorName,
                      accountId: post.authorAccountId,
                    );
                    SakhiDialogs.showPrototypeSnackbar(
                      context,
                      '${post.authorName} has been blocked.',
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
