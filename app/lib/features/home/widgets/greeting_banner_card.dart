import 'package:flutter/material.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class GreetingBannerCard extends StatelessWidget {
  const GreetingBannerCard({
    super.key,
    required this.userName,
    this.greeting = 'Good Morning',
    this.onTap,
  });

  final String userName;
  final String greeting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 152,
      decoration: BoxDecoration(
        gradient: AppColors.heroBannerGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: AppSpacing.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 175,
          child: Image.asset(
            AppAssets.greetingHeroIllustration,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 142, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(greeting, style: AppTypography.bodyMedium),
              const SizedBox(height: 3),
              Text(
                userName.isEmpty ? 'Your Sakhi journey' : userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.heroTitle.copyWith(fontSize: 23),
              ),
              const SizedBox(height: 8),
              Text(
                'A safer, stronger and more connected you.',
                maxLines: 2,
                style: AppTypography.subtitle.copyWith(color: AppColors.textSecondary.withValues(alpha: .85), height: 1.35),
              ),
            ],
          ),
        ),
      ]),
    ),
  );
}
