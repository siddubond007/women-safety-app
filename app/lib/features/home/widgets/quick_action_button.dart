import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.circleColor,
    required this.iconColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color circleColor;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle, border: Border.all(color: iconColor.withValues(alpha: .15))),
          child: Center(child: Icon(icon, color: iconColor, size: 27)),
        ),
        const SizedBox(height: 7),
        Text(label, style: AppTypography.subtitle.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 11.5)),
      ]),
    ),
  );
}
