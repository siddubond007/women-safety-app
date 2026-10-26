import 'package:flutter/material.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_card.dart';
import '../../../core/widgets/sakhi_chip.dart';
import '../../../core/widgets/sakhi_dialogs.dart';
import '../../../core/widgets/sakhi_settings_row.dart';
import '../../auth/auth_service_factory.dart';
import '../../auth/sakhi_login_screen.dart';

/// Screen 12 — More Options / Menu
class MoreOptionsMenuScreen extends StatelessWidget {
  const MoreOptionsMenuScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final authService = authServiceForCurrentBuild();
    try {
      await authService.logout();
    } catch (_) {}
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => SakhiLoginScreen(authService: authService),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('More Options'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final savedCount =
              state.communityPosts.where((p) => p.isSaved).length +
                  state.exploreRecommendedPosts.where((p) => p.isSaved).length;
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingH,
              vertical: 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main 9 Reference Rows in a clean unified card container
                SakhiCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      SakhiSettingsRow(
                        useCardContainer: false,
                        icon: Icons.groups_outlined,
                        title: 'My Groups',
                        onTap: () => SakhiDialogs.showPrototypeSnackbar(
                          context,
                          'Joined groups: ${state.groups.map((g) => g.name).join(", ")}',
                        ),
                      ),
                      const Divider(indent: 68, endIndent: 14),
                      SakhiSettingsRow(
                        useCardContainer: false,
                        icon: Icons.bookmark_border_rounded,
                        title: 'My Saved Posts',
                        onTap: () => SakhiDialogs.showPrototypeSnackbar(
                          context,
                          'You have $savedCount saved post(s) in your collection.',
                        ),
                      ),
                      const Divider(indent: 68, endIndent: 14),
                      SakhiSettingsRow(
                        useCardContainer: false,
                        icon: Icons.storefront_outlined,
                        title: 'Business Profile',
                        subtitle: state.currentUser.businessProfileUrl ??
                            'Add or manage your business link',
                        onTap: () => SakhiDialogs.showConfirmationDialog(
                          context: context,
                          title: 'Business Profile',
                          description:
                              'Link your verified women-led business page to receive collaboration enquiries.',
                          confirmLabel: 'Save Business Link',
                          onConfirmed: () {
                            state.updateProfile(
                              displayName: state.currentUser.displayName,
                              bio: state.currentUser.bio,
                              location: state.currentUser.location,
                              interests: state.currentUser.interests,
                              businessProfileUrl: 'sakhi.app/biz/siddhu',
                            );
                            SakhiDialogs.showPrototypeSnackbar(
                              context,
                              'Business profile link saved!',
                            );
                          },
                        ),
                      ),
                      const Divider(indent: 68, endIndent: 14),
                      SakhiSettingsRow(
                        useCardContainer: false,
                        icon: Icons.help_outline_rounded,
                        title: 'Help & Support',
                        onTap: () => SakhiDialogs.showConfirmationDialog(
                          context: context,
                          title: 'Help & Support',
                          description:
                              'Browse FAQs or contact the Sakhi community support team.',
                          confirmLabel: 'Close',
                        ),
                      ),
                      const Divider(indent: 68, endIndent: 14),
                      SakhiSettingsRow(
                        useCardContainer: false,
                        icon: Icons.shield_moon_rounded,
                        title: 'Discreet & Anonymous Complaint Hub',
                        subtitle: 'File anonymous/confidential reports or track by #SKH token',
                        onTap: () => Navigator.of(context)
                            .pushNamed(AppRoutes.discreetComplaintHub),
                      ),
                      const Divider(indent: 68, endIndent: 14),
                      SakhiSettingsRow(
                        useCardContainer: false,
                        icon: Icons.warning_amber_rounded,
                        title: 'Report a User',
                        onTap: () => SakhiDialogs.showConfirmationDialog(
                          context: context,
                          title: 'Report a User',
                          description:
                              'Submit a confidential safety or community guideline report to Sakhi moderators.',
                          confirmLabel: 'Submit Report',
                          onConfirmed: () {
                            state.reportUserOrPost(
                              targetHandle: '@community_review',
                              reason:
                                  'Community safety check submitted from More Options.',
                            );
                            SakhiDialogs.showPrototypeSnackbar(
                              context,
                              'Confidential report submitted to Sakhi moderators.',
                            );
                          },
                        ),
                      ),
                      const Divider(indent: 68, endIndent: 14),
                      SakhiSettingsRow(
                        useCardContainer: false,
                        icon: Icons.block_rounded,
                        title: 'Blocked Users',
                        onTap: () => SakhiDialogs.showPrototypeSnackbar(
                          context,
                          state.blockedUsers.isEmpty
                              ? 'You have no blocked users.'
                              : 'Blocked accounts: ${state.blockedUsers.length}',
                        ),
                      ),
                      const Divider(indent: 68, endIndent: 14),
                      SakhiSettingsRow(
                        useCardContainer: false,
                        icon: Icons.description_outlined,
                        title: 'Terms and Conditions',
                        onTap: () => SakhiDialogs.showConfirmationDialog(
                          context: context,
                          title: 'Terms and Conditions',
                          description:
                              'Sakhi Community Guidelines & Terms of Service.',
                          confirmLabel: 'Close',
                        ),
                      ),
                      const Divider(indent: 68, endIndent: 14),
                      SakhiSettingsRow(
                        useCardContainer: false,
                        icon: Icons.lock_outline_rounded,
                        title: 'Privacy Policy',
                        onTap: () => Navigator.of(context)
                            .pushNamed(AppRoutes.privacySettings),
                      ),
                      const Divider(indent: 68, endIndent: 14),
                      SakhiSettingsRow(
                        useCardContainer: false,
                        icon: Icons.info_outline_rounded,
                        title: 'About Sakhi',
                        subtitle: 'Version 1.0.0',
                        onTap: () => SakhiDialogs.showConfirmationDialog(
                          context: context,
                          title: 'About Sakhi (v1.0.0)',
                          description:
                              'Sakhi — Women\'s Safety, Wellness & Community Application.',
                          confirmLabel: 'Close',
                        ),
                      ),
                      const Divider(indent: 68, endIndent: 14),
                      SakhiSettingsRow(
                        useCardContainer: false,
                        icon: Icons.logout_rounded,
                        iconColor: AppColors.sosRed,
                        iconBgColor: AppColors.sosRedSoft,
                        title: 'Sign Out',
                        subtitle: 'Log out and return to mobile login',
                        onTap: () => _signOut(context),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  'Related Settings Screens',
                  style: AppTypography.sectionTitle,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SakhiChip(
                      label: 'Privacy Settings (Screen 8)',
                      onTap: () => Navigator.of(context)
                          .pushNamed(AppRoutes.privacySettings),
                    ),
                    SakhiChip(
                      label: 'Notifications (Screen 9)',
                      onTap: () => Navigator.of(context).pushNamed(
                        AppRoutes.notificationPreferences,
                      ),
                    ),
                    SakhiChip(
                      label: 'Account & Security (Screen 11)',
                      onTap: () => Navigator.of(context)
                          .pushNamed(AppRoutes.accountSecurity),
                    ),
                    SakhiChip(
                      label: 'Edit Profile (Screen 7)',
                      onTap: () =>
                          Navigator.of(context).pushNamed(AppRoutes.editProfile),
                    ),
                    SakhiChip(
                      label: 'Followers (Screen 10)',
                      onTap: () =>
                          Navigator.of(context).pushNamed(AppRoutes.followers),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
