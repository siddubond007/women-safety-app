import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_botanical_flower.dart';
import '../../../shared/widgets/sakhi_crisp_art.dart';

class GreetingBannerCard extends StatelessWidget {
  final String userName;
  final VoidCallback? onTap;

  const GreetingBannerCard({
    super.key,
    required this.userName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 174,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFDF0F6),
              Color(0xFFF3E6FA),
              Color(0xFFFCE8F1),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primaryPurple.withValues(alpha: 0.14),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryPurple.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Standalone reusable botanical flower accents (never baked into hero image)
            const Positioned(
              left: -14,
              bottom: -18,
              child: SakhiBotanicalFlower(
                type: SakhiFlowerType.babysBreath,
                width: 86,
                height: 105,
                opacity: 0.38,
                angle: 0.25,
              ),
            ),
            const Positioned(
              right: 112,
              top: -10,
              child: SakhiBotanicalFlower(
                type: SakhiFlowerType.lavenderSprig,
                width: 72,
                height: 96,
                opacity: 0.65,
                angle: -0.18,
              ),
            ),
            const Positioned(
              right: -8,
              bottom: -12,
              child: SakhiBotanicalFlower(
                type: SakhiFlowerType.poppyBlush,
                width: 88,
                height: 108,
                opacity: 0.78,
                angle: -0.12,
                flipHorizontal: true,
              ),
            ),

            // Right-side infinite-DPI vector hero character illustration
            const Positioned(
              right: 4,
              top: 6,
              bottom: 0,
              width: 152,
              child: SakhiCrispHeroArt(
                variant: 'greeting',
                width: 152,
                height: 168,
              ),
            ),

            // Left-side crisp greeting content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 148, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primaryPurple.withValues(alpha: 0.16),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          size: 13,
                          color: AppColors.primaryPurple,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'VERIFIED SAFE SPACE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Good Morning,\n$userName',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.heroTitle.copyWith(
                      fontSize: 21,
                      height: 1.18,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'A safer, stronger, and more connected community for you.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.subtitle.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.90),
                      fontSize: 12.5,
                      height: 1.32,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
