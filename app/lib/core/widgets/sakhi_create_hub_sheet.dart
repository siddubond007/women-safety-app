import 'dart:ui';

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
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x661E0926),
    builder: (sheetContext) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.90),
                const Color(0xFFFDF2F9).withValues(alpha: 0.86),
                const Color(0xFFF3E6FA).withValues(alpha: 0.88),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.95),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x334A1259),
                blurRadius: 36,
                offset: Offset(0, -8),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenPaddingH,
            12,
            AppSpacing.screenPaddingH,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 22,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7B228E), Color(0xFFD63E85)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.92),
                          width: 1.4,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x285D196A),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
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
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close Create Hub',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.78),
                      ),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _CreateHubLiquidGlassOption(
                  icon: Icons.photo_camera_back_rounded,
                  title: 'Post a Photo or Video',
                  description: 'Choose media, crop and share',
                  badgeLabel: 'MEDIA',
                  tintColors: [
                    Colors.white.withValues(alpha: 0.82),
                    const Color(0xFFFFEBF4).withValues(alpha: 0.72),
                  ],
                  iconGradient: const [Color(0xFFE03E7A), Color(0xFFA82368)],
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(SakhiCreateAction.photoVideo),
                ),
                _CreateHubLiquidGlassOption(
                  icon: Icons.edit_note_rounded,
                  title: 'Write a Text Post',
                  description: 'Share a thought, experience, or update',
                  badgeLabel: 'STORY',
                  tintColors: [
                    Colors.white.withValues(alpha: 0.82),
                    const Color(0xFFF3E8FF).withValues(alpha: 0.74),
                  ],
                  iconGradient: const [Color(0xFF7B2CBF), Color(0xFF5A1868)],
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(SakhiCreateAction.textPost),
                ),
                _CreateHubLiquidGlassOption(
                  icon: Icons.forum_outlined,
                  title: 'Create a Community Question',
                  description: 'Ask Sakhis for ideas and support',
                  badgeLabel: 'Q&A',
                  tintColors: [
                    Colors.white.withValues(alpha: 0.82),
                    const Color(0xFFFFF2E2).withValues(alpha: 0.76),
                  ],
                  iconGradient: const [Color(0xFFD97706), Color(0xFFB45309)],
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(SakhiCreateAction.communityQuestion),
                ),
                _CreateHubLiquidGlassOption(
                  icon: Icons.menu_book_outlined,
                  title: 'Share a Useful Resource',
                  description: 'Share information that may help others',
                  badgeLabel: 'GUIDE',
                  tintColors: [
                    Colors.white.withValues(alpha: 0.82),
                    const Color(0xFFE6F7EF).withValues(alpha: 0.76),
                  ],
                  iconGradient: const [Color(0xFF1E8E62), Color(0xFF146C48)],
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(SakhiCreateAction.usefulResource),
                ),
                _CreateHubLiquidGlassOption(
                  icon: Icons.storefront_rounded,
                  title: 'Promote a Women-Owned Business',
                  description:
                      'Create or manage your business page, products & enquiries',
                  badgeLabel: 'MODULE 6',
                  tintColors: [
                    Colors.white.withValues(alpha: 0.84),
                    const Color(0xFFFFF5E4).withValues(alpha: 0.80),
                  ],
                  iconGradient: const [Color(0xFFC27803), Color(0xFF78350F)],
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(SakhiCreateAction.womenBusinessPage),
                ),
                _CreateHubLiquidGlassOption(
                  icon: Icons.shield_moon_rounded,
                  title: 'File a Discreet Complaint',
                  description:
                      'Report harassment, stalking, or safety concerns privately',
                  badgeLabel: 'SAFE VOICE',
                  tintColors: [
                    Colors.white.withValues(alpha: 0.84),
                    const Color(0xFFFDE8F1).withValues(alpha: 0.78),
                  ],
                  iconGradient: const [Color(0xFFC92A49), Color(0xFF7B1633)],
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(SakhiCreateAction.discreetComplaint),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.75),
                      foregroundColor: AppColors.primaryPurple,
                      side: BorderSide(
                        color: AppColors.primaryPurple.withValues(alpha: 0.28),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CreateHubLiquidGlassOption extends StatelessWidget {
  const _CreateHubLiquidGlassOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.badgeLabel,
    required this.tintColors,
    required this.iconGradient,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String badgeLabel;
  final List<Color> tintColors;
  final List<Color> iconGradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: tintColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.96),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x145D196A),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: iconGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 1.3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: iconGradient.first.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.borderSubtle,
                              ),
                            ),
                            child: Text(
                              badgeLabel,
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: iconGradient.last,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: AppTypography.subtitle.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primaryPurple,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
