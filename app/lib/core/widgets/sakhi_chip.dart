import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class SakhiChip extends StatelessWidget {
  const SakhiChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.isOutlinedAction = false,
    this.onTap,
    this.onDelete,
  });

  final String label;
  final bool isSelected;
  final bool isOutlinedAction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final background = isSelected ? AppColors.primaryPurple : (isOutlinedAction ? Colors.white : AppColors.pastelLavender);
    final foreground = isSelected ? Colors.white : AppColors.primaryPurple;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(color: isSelected ? AppColors.primaryPurple : (isOutlinedAction ? AppColors.primaryPurple.withValues(alpha: .35) : AppColors.borderSubtle)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: AppTypography.chipLabel.copyWith(color: foreground)),
          if (onDelete != null) ...[
            const SizedBox(width: 6),
            GestureDetector(onTap: onDelete, child: Icon(Icons.close_rounded, size: 14, color: foreground.withValues(alpha: .8))),
          ],
        ]),
      ),
    );
  }
}
