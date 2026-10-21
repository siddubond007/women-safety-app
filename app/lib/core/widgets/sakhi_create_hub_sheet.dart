import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum SakhiCreateAction {
  photoVideo,
  textPost,
  communityQuestion,
  usefulResource,
}

Future<SakhiCreateAction?> showSakhiCreateHub(BuildContext context) {
  return showModalBottomSheet<SakhiCreateAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.cardSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        12,
        AppSpacing.screenPaddingH,
        MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD3BFE0),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.pastelLavender,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.primaryPurple,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sakhi Create Hub', style: AppTypography.sectionTitle),
                    SizedBox(height: 3),
                    Text(
                      'Choose what you would like to share',
                      style: AppTypography.subtitle,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close Create Hub',
                onPressed: () => Navigator.of(sheetContext).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CreateHubOption(
            icon: Icons.photo_library_outlined,
            title: 'Post a Photo',
            description: 'Share a moment with the community',
            onTap: () =>
                Navigator.of(sheetContext).pop(SakhiCreateAction.photoVideo),
          ),
          _CreateHubOption(
            icon: Icons.edit_note_rounded,
            title: 'Write a Text Post',
            description: 'Share a thought, experience, or update',
            onTap: () =>
                Navigator.of(sheetContext).pop(SakhiCreateAction.textPost),
          ),
          _CreateHubOption(
            icon: Icons.forum_outlined,
            title: 'Create a Community Question',
            description: 'Ask Sakhis for ideas and support',
            onTap: () =>
                Navigator.of(sheetContext)
                    .pop(SakhiCreateAction.communityQuestion),
          ),
          _CreateHubOption(
            icon: Icons.menu_book_outlined,
            title: 'Share a Useful Resource',
            description: 'Share information that may help others',
            onTap: () =>
                Navigator.of(sheetContext)
                    .pop(SakhiCreateAction.usefulResource),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _CreateHubOption extends StatelessWidget {
  const _CreateHubOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderSubtle),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: AppColors.pastelLavender,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppColors.primaryPurple, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.bodyMedium),
                      const SizedBox(height: 3),
                      Text(description, style: AppTypography.subtitle),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
