import 'package:flutter/material.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/sakhi_crisp_art.dart';

class GreetingBannerCard extends StatelessWidget {
  final String userName;
  final VoidCallback? onTap;

  const GreetingBannerCard({super.key, required this.userName, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 162,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xEEFFEBF5),
              Color(0xDDF2DDFA),
              Color(0xECFFF5FB),
            ],
            stops: [0.0, 0.52, 1.0],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.95),
            width: 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryPurple.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.90),
              blurRadius: 2,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Top-left iOS 26 Liquid Glass specular light reflection
            Positioned(
              left: -24,
              top: -32,
              child: IgnorePointer(
                child: Container(
                  width: 160,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.72),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 154,
              child: ClipRect(
                child: Image.asset(
                  AppAssets.greetingHeroIllustration,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => const Align(
                    alignment: Alignment.centerRight,
                    child: SakhiCrispHeroArt(
                      variant: 'greeting',
                      width: 144,
                      height: 148,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 148, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryPurple.withValues(
                            alpha: 0.06,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.groups_rounded,
                          size: 13,
                          color: AppColors.primaryPurple,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'YOUR SAKHI COMMUNITY',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Good Morning, $userName!',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.heroTitle.copyWith(
                      fontSize: 20.5,
                      height: 1.18,
                      letterSpacing: -0.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'A safer, stronger, and more connected community for you.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.subtitle.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.94),
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
