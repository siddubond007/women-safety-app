import 'package:flutter/material.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_dialogs.dart';
import '../../../core/widgets/sakhi_settings_row.dart';

/// Screen 11 — Account & Security
class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Account & Security'),
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
          final user = state.currentUser;
          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingH,
              vertical: 14,
            ),
            children: [
              SakhiSettingsRow(
                icon: Icons.phone_outlined,
                title: 'Phone number',
                subtitle: user.phoneMasked,
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.verifiedGreenBg,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  child: Text(
                    user.phoneVerified ? 'Verified' : 'Pending',
                    style: AppTypography.subtitle.copyWith(
                      color: AppColors.verifiedGreenText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                onTap: () => SakhiDialogs.showPrototypeSnackbar(
                  context,
                  'Phone number ${user.phoneMasked} is verified.',
                ),
              ),
              const SizedBox(height: 10),

              SakhiSettingsRow(
                icon: Icons.email_outlined,
                title: 'Email address',
                subtitle: user.email,
                onTap: () => SakhiDialogs.showConfirmationDialog(
                  context: context,
                  title: 'Email Address',
                  description:
                      'Current account email: ${user.email}. You can also update profile details on the Edit Profile screen.',
                  confirmLabel: 'OK',
                ),
              ),
              const SizedBox(height: 10),

              SakhiSettingsRow(
                icon: Icons.verified_user_outlined,
                title: 'Login sessions',
                subtitle: 'Manage your active sessions',
                onTap: () => SakhiDialogs.showConfirmationDialog(
                  context: context,
                  title: 'Active Login Sessions (${user.activeSessionsCount})',
                  description:
                      'Current device: Sakhi Mobile • ${user.location} (Active now).',
                  confirmLabel: 'Done',
                ),
              ),
              const SizedBox(height: 10),

              SakhiSettingsRow(
                icon: Icons.lock_outline_rounded,
                title: 'Change PIN / Password',
                subtitle: 'Update your security credentials',
                onTap: () => SakhiDialogs.showConfirmationDialog(
                  context: context,
                  title: 'Change PIN / Password',
                  description:
                      'Refresh your 4-digit security PIN for quick app lock and SOS verification.',
                  confirmLabel: 'Update PIN',
                  onConfirmed: () {
                    state.updateSecurityPin('2468');
                    SakhiDialogs.showPrototypeSnackbar(
                      context,
                      'Security PIN updated.',
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              SakhiSettingsRow(
                icon: Icons.phonelink_lock_rounded,
                title: 'Two-factor authentication',
                subtitle: user.twoFactorEnabled
                    ? 'Enabled • Extra security active'
                    : 'Add an extra layer of security',
                onTap: () => SakhiDialogs.showConfirmationDialog(
                  context: context,
                  title: 'Two-Factor Authentication',
                  description: user.twoFactorEnabled
                      ? 'Disable two-factor authentication for this account?'
                      : 'Enable two-factor authentication for extra login protection?',
                  confirmLabel: user.twoFactorEnabled ? 'Disable' : 'Enable',
                  onConfirmed: () {
                    state.toggleTwoFactor();
                    SakhiDialogs.showPrototypeSnackbar(
                      context,
                      user.twoFactorEnabled
                          ? 'Two-factor authentication enabled.'
                          : 'Two-factor authentication disabled.',
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              SakhiSettingsRow(
                icon: Icons.person_off_outlined,
                iconColor: AppColors.sosRed,
                iconBgColor: AppColors.sosRedSoft,
                title: 'Account deactivation',
                subtitle: 'Temporarily deactivate your account',
                onTap: () => SakhiDialogs.showConfirmationDialog(
                  context: context,
                  title: 'Temporarily Deactivate Account?',
                  description:
                      'Your profile and posts will be hidden until you sign back in.',
                  confirmLabel: 'Deactivate',
                  isDestructive: true,
                ),
              ),
              const SizedBox(height: 10),

              SakhiSettingsRow(
                icon: Icons.delete_outline_rounded,
                iconColor: AppColors.sosRed,
                iconBgColor: AppColors.sosRedSoft,
                title: 'Delete account',
                subtitle: 'Permanently delete your account',
                onTap: () => SakhiDialogs.showConfirmationDialog(
                  context: context,
                  title: 'Permanently Delete Account?',
                  description:
                      'This permanently removes your profile, posts, and preferences.',
                  confirmLabel: 'Request Deletion',
                  isDestructive: true,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
