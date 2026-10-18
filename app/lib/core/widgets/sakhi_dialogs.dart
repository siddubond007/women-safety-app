import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'sakhi_buttons.dart';

class SakhiDialogs {
  SakhiDialogs._();

  static void showPrototypeSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primaryPurpleDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
  }

  static Future<void> showSosPrototypeDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusXl)),
        title: const Row(children: [
          Icon(Icons.shield_rounded, color: AppColors.sosRed, size: 30),
          SizedBox(width: 10),
          Expanded(child: Text('Safety & SOS', style: AppTypography.sectionTitle)),
        ]),
        content: const Text(
          'Emergency dispatch is not enabled in this build. This action has not placed a call, sent a message, requested GPS, or contacted emergency services. Use the safety guidance on this screen to review your options.',
          style: AppTypography.bodyRegular,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Future<void> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String description,
    required String confirmLabel,
    bool isDestructive = false,
    Future<void> Function()? onConfirm,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusXl)),
        title: Text(title, style: AppTypography.sectionTitle),
        content: Text(description, style: AppTypography.bodyRegular),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          SakhiPillButton(
            label: confirmLabel,
            backgroundColor: isDestructive ? AppColors.sosRed : AppColors.primaryPurple,
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              if (onConfirm != null) await onConfirm();
            },
          ),
        ],
      ),
    );
  }
}
