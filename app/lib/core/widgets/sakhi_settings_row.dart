import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'sakhi_card.dart';

class SakhiSettingsRow extends StatelessWidget {
  const SakhiSettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.iconBgColor,
    this.useCardContainer = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? iconBgColor;
  final bool useCardContainer;

  @override
  Widget build(BuildContext context) {
    final row = Row(children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: iconBgColor ?? AppColors.pastelLavender, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        child: Icon(icon, color: iconColor ?? AppColors.primaryPurple, size: 21),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AppTypography.cardTitle.copyWith(fontSize: 14.5)),
        if (subtitle != null && subtitle!.isNotEmpty) ...[const SizedBox(height: 2), Text(subtitle!, style: AppTypography.subtitle)],
      ])),
      const SizedBox(width: 8),
      trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 22),
    ]);
    if (!useCardContainer) {
      return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AppSpacing.radiusMd), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: row));
    }
    return SakhiCard(onTap: onTap, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: row);
  }
}
