import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Filter chip, hashtag chip, or interest chip matching Screens 2, 6, and 7.
class SakhiChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isOutlinedAction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const SakhiChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.isOutlinedAction = false,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? AppColors.primaryPurple
        : isOutlinedAction
            ? AppColors.cardSurface
            : AppColors.pastelLavender;
    final textColor = isSelected
        ? Colors.white
        : AppColors.primaryPurple;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryPurple
                : isOutlinedAction
                    ? AppColors.primaryPurple.withValues(alpha: 0.35)
                    : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.chipLabel.copyWith(color: textColor),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDelete,
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: textColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
