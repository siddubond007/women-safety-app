import 'package:flutter/material.dart';
import '../constants/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'sakhi_buttons.dart';

/// Helper dialogs and bottom sheets for Sakhi actions and backend persistence.
class SakhiDialogs {
  SakhiDialogs._();

  static void showPrototypeSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.primaryPurpleDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  static Future<void> showSosPrototypeDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.sosRedSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sos_rounded, color: AppColors.sosRed),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'SOS Emergency Alert',
                style: AppTypography.sectionTitle,
              ),
            ),
          ],
        ),
        content: const Text(
          'Triggering SOS records an emergency event in the Sakhi database and notifies your trusted contacts list.\n\n(Development environment note: no external carrier SMS or 112 call is placed automatically).',
          style: AppTypography.bodyRegular,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          SakhiPillButton(
            label: 'Trigger SOS Alert',
            backgroundColor: AppColors.sosRed,
            onPressed: () {
              SakhiPrototypeState.instance.recordSafetyEvent(
                'SOS_TRIGGER',
                locationLabel: SakhiPrototypeState.instance.currentUser.location,
              );
              Navigator.of(ctx).pop();
              showPrototypeSnackbar(
                context,
                'SOS alert recorded and dispatched to trusted contacts.',
              );
            },
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
    VoidCallback? onConfirmed,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        title: Text(title, style: AppTypography.sectionTitle),
        content: Text(
          description,
          style: AppTypography.bodyRegular,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          SakhiPillButton(
            label: confirmLabel,
            backgroundColor:
                isDestructive ? AppColors.sosRed : AppColors.primaryPurple,
            onPressed: () {
              Navigator.of(ctx).pop();
              if (onConfirmed != null) {
                onConfirmed();
              } else {
                showPrototypeSnackbar(
                  context,
                  '$title completed.',
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
