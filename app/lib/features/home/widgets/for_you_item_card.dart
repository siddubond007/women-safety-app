import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_card.dart';

class ForYouItemCard extends StatelessWidget {
  const ForYouItemCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SakhiCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AppTypography.cardTitle),
        const SizedBox(height: 2),
        Text(subtitle, style: AppTypography.subtitle),
      ])),
      const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
    ]),
  );
}
