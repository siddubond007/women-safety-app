import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_buttons.dart';
import '../../../core/widgets/sakhi_dialogs.dart';
import '../../../core/widgets/sakhi_settings_row.dart';

/// Screen 11 — Account & Security
class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({super.key});

  void _showChangePinDialog(BuildContext context, SakhiPrototypeState state) {
    final currentPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    String? errorMessage;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Change Security PIN',
            style: AppTypography.sectionTitle,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set a 4 to 6 digit security PIN for quick app lock and SOS verification.',
                  style: AppTypography.subtitle,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: currentPinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Current PIN (optional if first time)',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newPinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'New 4–6 Digit PIN',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmPinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Confirm New PIN',
                    counterText: '',
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: AppColors.sosRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            SakhiPillButton(
              label: 'Update PIN',
              onPressed: () {
                final nextPin = newPinCtrl.text.trim();
                final confirmPin = confirmPinCtrl.text.trim();
                if (!RegExp(r'^\d{4,6}$').hasMatch(nextPin)) {
                  setDialogState(() {
                    errorMessage = 'Please enter a 4 to 6 digit numeric PIN.';
                  });
                  return;
                }
                if (nextPin != confirmPin) {
                  setDialogState(() {
                    errorMessage = 'New PIN and confirmation do not match.';
                  });
                  return;
                }
                state.updateSecurityPin(
                  nextPin,
                  currentPin: currentPinCtrl.text.trim().isEmpty
                      ? null
                      : currentPinCtrl.text.trim(),
                );
                Navigator.of(ctx).pop();
                SakhiDialogs.showPrototypeSnackbar(
                  context,
                  'Security PIN updated.',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(
    BuildContext context,
    SakhiPrototypeState state,
  ) {
    final reasonCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorMessage;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Permanently Delete Account?',
            style: AppTypography.sectionTitle,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This permanently removes your profile, posts, and preferences. Tell us why you are leaving (optional) and type DELETE to confirm.',
                  style: AppTypography.subtitle,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason / feedback comment (optional)',
                    hintText: 'Share any feedback with the Sakhi team...',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Type DELETE to confirm',
                    hintText: 'DELETE',
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: AppColors.sosRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            SakhiPillButton(
              label: 'Request Deletion',
              backgroundColor: AppColors.sosRed,
              onPressed: () async {
                if (confirmCtrl.text.trim().toUpperCase() != 'DELETE') {
                  setDialogState(() {
                    errorMessage = 'Please type DELETE in capital letters to confirm.';
                  });
                  return;
                }
                await state.requestAccountDeletion(reason: reasonCtrl.text.trim());
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                if (!context.mounted) return;
                SakhiDialogs.showPrototypeSnackbar(
                  context,
                  'Account deletion request recorded.',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

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
                onTap: () => _showChangePinDialog(context, state),
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
                onTap: () => _showDeleteAccountDialog(context, state),
              ),
            ],
          );
        },
      ),
    );
  }
}
