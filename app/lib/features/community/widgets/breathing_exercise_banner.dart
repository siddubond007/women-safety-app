import 'package:flutter/material.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_botanical_flower.dart';
import '../../../shared/widgets/sakhi_crisp_art.dart';
import '../../../core/widgets/sakhi_dialogs.dart';

class BreathingExerciseBanner extends StatelessWidget {
  const BreathingExerciseBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => SakhiDialogs.showPrototypeSnackbar(
        context,
        'Starting 5-minute Calm Mind breathing guide.',
      ),
      child: Container(
        height: 122,
        decoration: BoxDecoration(
          gradient: AppColors.wellnessBannerGradient,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const Positioned(
              right: -6,
              bottom: -10,
              child: SakhiBotanicalFlower(
                type: SakhiFlowerType.lavenderSprig,
                width: 68,
                height: 86,
                opacity: 0.55,
                angle: -0.15,
              ),
            ),
            Row(
              children: [
                const SizedBox(
                  width: 118,
                  height: 122,
                  child: SakhiCrispAvatarArt(
                    assetOrUrl: 'breathing_meera',
                    size: 118,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Breathing Exercises\nfor a Calm Mind',
                          style: AppTypography.cardTitle.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Row(
                          children: [
                            _MiniWellnessIcon(icon: Icons.air_rounded),
                            SizedBox(width: 10),
                            _MiniWellnessIcon(
                              icon: Icons.self_improvement_rounded,
                            ),
                            SizedBox(width: 10),
                            _MiniWellnessIcon(icon: Icons.timer_outlined),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniWellnessIcon extends StatelessWidget {
  final IconData icon;
  const _MiniWellnessIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 15, color: AppColors.primaryPurple),
    );
  }
}
