import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'sakhi_buttons.dart';

class SakhiEmptyState extends StatelessWidget {
  const SakhiEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: AppColors.pastelLavender, shape: BoxShape.circle),
          child: Icon(icon, size: 32, color: AppColors.primaryPurple),
        ),
        const SizedBox(height: 14),
        Text(title, style: AppTypography.sectionTitle, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(message, style: AppTypography.subtitle, textAlign: TextAlign.center),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          SakhiPillButton(label: actionLabel!, onPressed: onAction),
        ],
      ]),
    ),
  );
}
