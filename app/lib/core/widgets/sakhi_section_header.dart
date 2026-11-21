import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class SakhiSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const SakhiSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTypography.sectionTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              actionLabel!,
              style: AppTypography.subtitle.copyWith(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
