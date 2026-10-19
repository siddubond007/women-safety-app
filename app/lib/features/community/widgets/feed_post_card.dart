import 'package:flutter/material.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_avatar.dart';
import '../../../core/widgets/sakhi_botanical_flower.dart';
import '../../../shared/widgets/sakhi_crisp_art.dart';
import '../../../core/widgets/sakhi_buttons.dart';
import '../../../core/widgets/sakhi_card.dart';
import '../../../core/widgets/sakhi_dialogs.dart';
import 'breathing_exercise_banner.dart';

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

  bool _isRemoteUrl(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    return SakhiCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Stack(
          children: [
            // Subtle standalone botanical accent in top-right of post card
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
                  // Author Row
                  Row(
                    children: [
                      SakhiAvatar(imageAsset: post.authorAvatar, size: 44),
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
                                if (showVerifiedCheck || post.authorVerified) ...[
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
                            Text(post.timestamp, style: AppTypography.subtitle),
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
                            color: AppColors.pastelBlue,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusPill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.spa_outlined,
                                size: 14,
                                color: AppColors.infoBlue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                post.categoryBadge!,
                                style: AppTypography.subtitle.copyWith(
                                  color: AppColors.infoBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
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
                  // Post Body Text
                  Text(post.content, style: AppTypography.bodyRegular),

                  // Post Image if present (supports both local asset and Cloud URL)
                  if (post.imageAsset != null &&
                      post.imageAsset!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _isRemoteUrl(post.imageAsset!)
                            ? Image.network(
                                post.imageAsset!,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                                isAntiAlias: true,
                                errorBuilder: (_, _, _) =>
                                    _buildImageFallback(),
                              )
                            : SakhiCrispSceneArt(assetPath: post.imageAsset!),
                      ),
                    ),
                  ],

                  // Embedded Wellness Card if present
                  if (post.hasBreathingExerciseCard) ...[
                    const SizedBox(height: 12),
                    const BreathingExerciseBanner(),
                  ],

                  const SizedBox(height: 12),
                  // Like, Comment, Save, and More Actions
                  Row(
                    children: [
                      InkWell(
                        onTap: onLikeTap,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
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
                      const SizedBox(width: 22),
                      InkWell(
                        onTap: () => _showAddCommentSheet(context),
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
                      const SizedBox(width: 22),
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
        child: Icon(
          Icons.image_outlined,
          color: AppColors.primaryPurple,
          size: 36,
        ),
      ),
    );
  }

  void _showAddCommentSheet(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
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
              'Comments on ${post.authorName}\'s post (${post.commentsCount})',
              style: AppTypography.sectionTitle,
            ),
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
                    SakhiPrototypeState.instance.addPostComment(post, text);
                    Navigator.pop(ctx);
                    SakhiDialogs.showPrototypeSnackbar(
                      context,
                      'Comment added!',
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPostOptionsSheet(BuildContext context) {
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
              ListTile(
                leading: const Icon(
                  Icons.flag_outlined,
                  color: AppColors.sosRed,
                ),
                title: const Text('Report Post'),
                onTap: () {
                  Navigator.pop(ctx);
                  SakhiPrototypeState.instance.reportUserOrPost(
                    targetHandle: post.authorUsername,
                    reason: 'Reported community post ${post.id}',
                  );
                  SakhiDialogs.showPrototypeSnackbar(
                    context,
                    'Report submitted to Sakhi safety moderators.',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
