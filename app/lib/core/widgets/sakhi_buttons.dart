import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Primary filled purple pill button and secondary outlined pill button.
/// Uses Flexible text wrapping to prevent overflow on narrow 320px viewports.
class SakhiPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isFilled;
  final Color? backgroundColor;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  const SakhiPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isFilled = true,
    this.backgroundColor,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final bg = isFilled
        ? (backgroundColor ?? AppColors.primaryPurple)
        : Colors.white;
    final fg = isFilled
        ? Colors.white
        : (backgroundColor ?? AppColors.primaryPurple);

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        side: BorderSide(
          color: isFilled
              ? Colors.transparent
              : AppColors.primaryPurple.withValues(alpha: 0.45),
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: AppTypography.chipLabel.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
