import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class SakhiSectionHeader extends StatelessWidget {
  const SakhiSectionHeader({super.key, required this.title, this.actionLabel, this.onActionTap});
  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: AppTypography.sectionTitle),
      if (actionLabel != null)
        TextButton(
          onPressed: onActionTap,
          style: TextButton.styleFrom(foregroundColor: AppColors.primaryPurple, visualDensity: VisualDensity.compact),
          child: Text(actionLabel!),
        ),
    ],
  );
}
