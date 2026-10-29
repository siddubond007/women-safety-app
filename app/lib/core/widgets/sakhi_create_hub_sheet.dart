import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum SakhiCreateAction {
  photoVideo,
  textPost,
  communityQuestion,
  usefulResource,
  womenBusinessPage,
  discreetComplaint,
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD3BFE0),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF6D5E6), Color(0xFFE7D4F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primaryPurple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create on Sakhi',
                        style: AppTypography.sectionTitle,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'What would you like to share?',
                        style: AppTypography.subtitle,
                      ),
                      Text(
                        'Sakhi Create Hub',
                        style: AppTypography.caption.copyWith(
                          fontSize: 10.5,
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.w700,
                        ),
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
              icon: Icons.photo_camera_back_rounded,
              title: 'Post a Photo or Video',
              description: 'Choose media, crop and share',
              gradientColors: const [Color(0xFFFFF2F7), Color(0xFFFCE4EE)],
              iconBg: const Color(0xFFF4CCE0),
              onTap: () =>
                  Navigator.of(sheetContext).pop(SakhiCreateAction.photoVideo),
            ),
            _CreateHubOption(
              icon: Icons.edit_note_rounded,
              title: 'Write a Text Post',
              description: 'Share a thought, experience, or update',
              gradientColors: const [Color(0xFFF7F1FF), Color(0xFFEDE1FB)],
              iconBg: const Color(0xFFDDCBF5),
              onTap: () =>
                  Navigator.of(sheetContext).pop(SakhiCreateAction.textPost),
            ),
            _CreateHubOption(
              icon: Icons.forum_outlined,
              title: 'Create a Community Question',
              description: 'Ask Sakhis for ideas and support',
              gradientColors: const [Color(0xFFFFF7EE), Color(0xFFFCEAD7)],
              iconBg: const Color(0xFFF5D6B8),
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(SakhiCreateAction.communityQuestion),
            ),
            _CreateHubOption(
              icon: Icons.menu_book_outlined,
              title: 'Share a Useful Resource',
              description: 'Share information that may help others',
              gradientColors: const [Color(0xFFF1FAF5), Color(0xFFE1F3EA)],
              iconBg: const Color(0xFFC5E6D6),
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(SakhiCreateAction.usefulResource),
            ),
            _CreateHubOption(
              icon: Icons.storefront_rounded,
              title: 'Promote a Women-Owned Business',
              description:
                  'Create or manage your business page, products & enquiries',
              gradientColors: const [Color(0xFFFFF7EE), Color(0xFFF9E6F5)],
              iconBg: const Color(0xFFF3D1E8),
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(SakhiCreateAction.womenBusinessPage),
            ),
            _CreateHubOption(
              icon: Icons.shield_moon_rounded,
              title: 'File a Discreet Complaint',
              description:
                  'Report harassment, stalking, or safety concerns privately',
              gradientColors: const [Color(0xFFFCEEF5), Color(0xFFF2E2F8)],
              iconBg: const Color(0xFFE5C5F0),
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(SakhiCreateAction.discreetComplaint),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 46,
              child: TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.pastelLavender,
                  foregroundColor: AppColors.primaryPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CreateHubOption extends StatelessWidget {
  const _CreateHubOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradientColors,
    required this.iconBg,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradientColors;
  final Color iconBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppColors.borderSubtle),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
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
                  color: AppColors.primaryPurple,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
