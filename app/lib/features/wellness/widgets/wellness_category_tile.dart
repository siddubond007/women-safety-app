import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_botanical_flower.dart';
import '../../../core/widgets/sakhi_card.dart';

/// Polished, vertically and horizontally centered Wellness Category Card (Section 9.2).
/// Ensures consistent icon badge geometry, line weight, and balanced vertical alignment
/// across all screen widths and accessibility text scales.
class WellnessCategoryTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final SakhiFlowerType flowerType;
  final VoidCallback onTap;

  const WellnessCategoryTile({
    super.key,
    required this.title,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    this.flowerType = SakhiFlowerType.roseClassic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SakhiCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Stack(
          alignment: Alignment.centerLeft,
          fit: StackFit.expand,
          children: [
            Positioned(
              right: -6,
              bottom: -10,
              child: IgnorePointer(
                child: SakhiBotanicalFlower(
                  type: flowerType,
                  width: 50,
                  height: 60,
                  opacity: 0.38,
                  angle: -0.14,
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.92),
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: iconColor.withValues(alpha: 0.14),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cardTitle.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
