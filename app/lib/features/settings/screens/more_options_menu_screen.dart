import 'package:flutter/material.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/sakhi_card.dart';
import '../../../core/widgets/sakhi_dialogs.dart';
import '../../../core/widgets/sakhi_settings_row.dart';
import '../../auth/auth_service_factory.dart';
import '../../auth/sakhi_login_screen.dart';
import 'privacy_settings_screen.dart';

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
                SakhiCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      SakhiSettingsRow(
                        useCardContainer: false,
                        icon: Icons.groups_outlined,
                        title: 'My Groups',
                        subtitle: state.groups.isEmpty
                            ? 'Explore and join community circles'
                            : '${state.groups.length} community circle(s) available',
                        onTap: () =>
                            Navigator.of(context).pushNamed(AppRoutes.groups),
                      ),
                      const Divider(indent: 68, endIndent: 14),
                      SakhiSettingsRow(
                        useCardContainer: false,
                        icon: Icons.bookmark_border_rounded,
                        title: 'My Saved Posts',
                        subtitle: '$savedCount saved post(s)',
                        onTap: () =>
                            Navigator.of(context).pushNamed(AppRoutes.profile),
                      ),
                      const Divider(indent: 68, endIndent: 14),
                      SakhiSettingsRow(
                        useCardContainer: false,
                        icon: Icons.storefront_outlined,
                        title: 'Business Profile',
                        subtitle: state.currentUser.businessProfileUrl ??
                            'Manage your Women-Owned Business Pages',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.businessHub),
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
                        subtitle:
                            'File an anonymous or confidential report & check report status',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.discreetComplaintHub),
                      ),
                      const Divider(indent: 68, endIndent: 14),
                      SakhiSettingsRow(
                        useCardContainer: false,
                        icon: Icons.warning_amber_rounded,
                        title: 'Report a User',
                        subtitle:
                            'Submit a confidential safety or community guideline report',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.discreetComplaintHub),
                      ),
                      const Divider(indent: 68, endIndent: 14),
                      SakhiSettingsRow(
                        useCardContainer: false,
                        icon: Icons.block_rounded,
                        title: 'Blocked Users',
                        subtitle: state.blockedUsers.isEmpty
                            ? 'No blocked members'
                            : '${state.blockedUsers.length} blocked member(s)',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const BlockedMembersScreen(),
                          ),
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
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.privacySettings),
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
              ],
            ),
          );
        },
      ),
    );
  }
}
