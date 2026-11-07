import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Reusable Sakhi branding header supporting the lotus-heart logo or shield emblem.
class SakhiBrandHeader extends StatelessWidget {
  final String title;
  final bool useShieldEmblem;
  final bool showLogo;
  final List<Widget>? actions;
  final VoidCallback? onTitleTap;
  final bool showTitleDropdown;

  const SakhiBrandHeader({
    super.key,
    required this.title,
    this.useShieldEmblem = false,
    this.showLogo = true,
    this.actions,
    this.onTitleTap,
    this.showTitleDropdown = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          if (showLogo) ...[
            Image.asset(
              useShieldEmblem ? AppAssets.sakhiShieldLogo : AppAssets.sakhiLogo,
              width: 30,
              height: 30,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                useShieldEmblem ? Icons.shield_rounded : Icons.spa_rounded,
                color: AppColors.primaryPurple,
                size: 28,
              ),
            ),
            const SizedBox(width: 10),
          ],
          GestureDetector(
            onTap: onTitleTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTypography.appBarTitle),
                if (showTitleDropdown) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          ...?actions,
        ],
      ),
    );
  }
}
