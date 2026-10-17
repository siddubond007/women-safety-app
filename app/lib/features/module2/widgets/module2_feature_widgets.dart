import 'package:flutter/material.dart';

import '../../../core/constants/mock_data.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_avatar.dart';
import '../../../core/widgets/sakhi_card.dart';
import '../../../core/widgets/sakhi_empty_state.dart';
import '../../../core/widgets/sakhi_section_header.dart';

class Module2PageBody extends StatelessWidget {
  const Module2PageBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 8, 18, 24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: SingleChildScrollView(
      padding: padding,
      child: child,
    ),
  );
}

class Module2LoadingOrError extends StatelessWidget {
  const Module2LoadingOrError({
    super.key,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return SakhiCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Could not load Sakhi data', style: AppTypography.cardTitle),
            const SizedBox(height: 6),
            Text(error!, style: AppTypography.subtitle),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class Module2ProfileBadge extends StatelessWidget {
  const Module2ProfileBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final verified = status == 'VERIFIED';
    final color = verified ? AppColors.verifiedGreenText : AppColors.amberAccent;
    final bg = verified ? AppColors.verifiedGreenBg : AppColors.pastelPeach;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
      child: Text(
        verified ? 'Verified' : status.replaceAll('_', ' ').toLowerCase(),
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class Module2FeedPostCard extends StatelessWidget {
  const Module2FeedPostCard({
    super.key,
    required this.post,
    required this.state,
    required this.onComment,
    required this.onAuthorTap,
    required this.onMore,
  });

  final FeedPostModel post;
  final SakhiPrototypeState state;
  final VoidCallback onComment;
  final VoidCallback onAuthorTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return SakhiCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GestureDetector(
              onTap: onAuthorTap,
              child: SakhiAvatar(
                imageAsset: post.authorAvatar,
                size: 42,
                fallbackLabel: post.authorName,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: onAuthorTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.authorName, style: AppTypography.cardTitle.copyWith(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(post.timestamp.isEmpty ? 'Sakhi member' : post.timestamp, style: AppTypography.subtitle),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Post options',
              onPressed: onMore,
              icon: const Icon(Icons.more_horiz_rounded, color: AppColors.textMuted),
            ),
          ]),
          const SizedBox(height: 11),
          Text(post.content, style: AppTypography.bodyRegular.copyWith(color: AppColors.textPrimary)),
          if (post.imageAsset != null && post.imageAsset!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                post.imageAsset!,
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(children: [
            TextButton.icon(
              onPressed: () => state.togglePostLike(post),
              icon: Icon(
                post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: post.isLiked ? AppColors.heartPink : AppColors.textMuted,
                size: 19,
              ),
              label: Text(post.likesCount.toString(), style: AppTypography.subtitle),
            ),
            TextButton.icon(
              onPressed: onComment,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19, color: AppColors.textMuted),
              label: Text(post.commentsCount.toString(), style: AppTypography.subtitle),
            ),
            const Spacer(),
            IconButton(
              tooltip: post.isSaved ? 'Remove saved post' : 'Save post',
              onPressed: () => state.togglePostSaved(post),
              icon: Icon(
                post.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: post.isSaved ? AppColors.primaryPurple : AppColors.textMuted,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class Module2PageTitle extends StatelessWidget {
  const Module2PageTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: AppTypography.appBarTitle.copyWith(fontSize: 23)),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(subtitle!, style: AppTypography.subtitle),
      ],
    ],
  );
}

class Module2EmptyPanel extends StatelessWidget {
  const Module2EmptyPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: SakhiEmptyState(
      icon: icon,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    ),
  );
}

class Module2DecoratedBanner extends StatelessWidget {
  const Module2DecoratedBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.asset,
    this.height = 145,
  });

  final String title;
  final String subtitle;
  final String asset;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      gradient: AppColors.heroBannerGradient,
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      border: Border.all(color: AppColors.borderSubtle),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(children: [
      Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        width: height * 1.1,
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(16, 16, height * .88, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: AppTypography.heroTitle.copyWith(fontSize: 19)),
            const SizedBox(height: 7),
            Text(subtitle, style: AppTypography.subtitle),
          ],
        ),
      ),
    ]),
  );
}

class Module2Section extends StatelessWidget {
  const Module2Section({super.key, required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => SakhiSectionHeader(
    title: title,
    actionLabel: action,
    onActionTap: onAction,
  );
}
