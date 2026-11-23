import 'dart:async';

import '../../auth/sakhi_login_screen.dart';

import '../../auth/auth_service_factory.dart';

import 'package:flutter/material.dart';

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
                    errorMessage =
                        'Please type DELETE in capital letters to confirm.';
                  });
                  return;
                }
                final deleted = await state.requestAccountDeletion(
                  reason: reasonCtrl.text.trim(),
                );
                if (!deleted) {
                  if (dialogContext.mounted) {
                    setDialogState(() {
                      errorMessage =
                          'Account deletion could not be completed. No change was confirmed by the server.';
                    });
                  }
                  return;
                }
                try {
                  await authServiceForCurrentBuild().logout();
                } catch (_) {}
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                if (!context.mounted) return;
                SakhiDialogs.showPrototypeSnackbar(
                  context,
                  'Account deletion request recorded. Signing out…',
                );
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                    builder: (_) => SakhiLoginScreen(
                      authService: authServiceForCurrentBuild(),
                    ),
                  ),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUnavailableInfo(BuildContext context, String title, String detail) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatSessionDate(dynamic value) {
    if (value is! String) return 'Not recorded';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return 'Not recorded';
    return parsed.toLocal().toString().split('.').first;
  }

  Future<void> _showSessions(
    BuildContext context,
    SakhiPrototypeState state,
  ) async {
    final initialEpoch = state.accountStateEpoch;
    unawaited(state.loadLoginSessions());
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final sessionChanged = state.accountStateEpoch != initialEpoch;
          return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * .7,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Login devices & sessions',
                    style: AppTypography.sectionTitle,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Platform labels are reported by the Sakhi app. Precise location and exact hardware details are not collected. Older sessions may not have a platform label.',
                    style: AppTypography.subtitle,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: sessionChanged
                        ? const Center(
                            child: Text(
                              'Login sessions were cleared because your Sakhi session changed. Sign in again to view active devices.',
                              style: AppTypography.subtitle,
                              textAlign: TextAlign.center,
                            ),
                          )
                        : state.isLoadingLoginSessions &&
                              state.loginSessions.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : state.loginSessionsError != null &&
                              state.loginSessions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  state.loginSessionsError!,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.subtitle,
                                ),
                                const SizedBox(height: 10),
                                TextButton.icon(
                                  onPressed: state.isLoadingLoginSessions
                                      ? null
                                      : () => unawaited(
                                          state.loadLoginSessions(),
                                        ),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : state.loginSessions.isEmpty
                        ? const Center(
                            child: Text(
                              'No login sessions were returned for this account.',
                              style: AppTypography.subtitle,
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            itemCount: state.loginSessions.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 18),
                            itemBuilder: (context, index) {
                              final session = state.loginSessions[index];
                              final active = session['isActive'] == true;
                              final current = session['isCurrent'] == true;
                              final deviceName =
                                  session['deviceName']?.toString().trim() ??
                                  '';
                              final sessionLabel = current
                                  ? 'This device • Current session'
                                  : deviceName.isNotEmpty
                                  ? '$deviceName • Other session'
                                  : 'Other signed-in session';
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    current
                                        ? Icons.smartphone_rounded
                                        : Icons.devices_other_rounded,
                                    color: AppColors.primaryPurple,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sessionLabel,
                                          style: AppTypography.cardTitle
                                              .copyWith(fontSize: 13),
                                        ),
                                        Text(
                                          'Started: ${_formatSessionDate(session['createdAt'])}',
                                          style: AppTypography.subtitle,
                                        ),
                                        Text(
                                          'Expires: ${_formatSessionDate(session['expiresAt'])}',
                                          style: AppTypography.subtitle,
                                        ),
                                        Text(
                                          active
                                              ? 'Active'
                                              : 'Revoked or expired',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: active
                                                ? AppColors.verifiedGreenText
                                                : AppColors.textMuted,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (active && !current)
                                    TextButton(
                                      onPressed: () => _confirmRevokeSession(
                                        context,
                                        state,
                                        session,
                                      ),
                                      child: const Text('Revoke'),
                                    ),
                                ],
                              );
                            },
                          ),
                  ),
                  if (state.loginSessionsError != null &&
                      state.loginSessions.isNotEmpty)
                    Text(
                      state.loginSessionsError!,
                      style: const TextStyle(
                        color: AppColors.sosRed,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
          );
        },
      ),
    );
  }

  Future<void> _confirmRevokeSession(
    BuildContext context,
    SakhiPrototypeState state,
    Map<String, dynamic> session,
  ) async {
    final sessionId = session['id'];
    if (sessionId is! String) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke this login session?'),
        content: const Text(
          'The selected session will no longer be able to access this Sakhi account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Revoke session'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    final initialEpoch = state.accountStateEpoch;
    final success = await state.revokeLoginSession(sessionId);
    if (!context.mounted || state.accountStateEpoch != initialEpoch) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Login session revoked.'
              : (state.loginSessionsError ??
                    'Login session could not be revoked.'),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
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
                icon: Icons.devices_rounded,
                title: 'Login devices & sessions',
                subtitle: 'Review and revoke other signed-in sessions',
                onTap: () => _showSessions(context, state),
              ),
              const SizedBox(height: 10),

              SakhiSettingsRow(
                icon: Icons.lock_outline_rounded,
                title: 'Change PIN / Password',
                subtitle: 'Unavailable • no verifiable PIN/password credential is stored',
                onTap: () => _showUnavailableInfo(
                  context,
                  'PIN / Password',
                  'Sakhi currently signs in with phone OTP and does not store a verifiable PIN or password credential. No PIN or password can be changed from this screen yet.',
                ),
              ),
              const SizedBox(height: 10),

              SakhiSettingsRow(
                icon: Icons.phonelink_lock_rounded,
                title: 'Two-factor authentication',
                subtitle:
                    'Unavailable • no second-factor provider is configured',
                onTap: () => _showUnavailableInfo(
                  context,
                  'Two-factor authentication',
                  'Sakhi does not currently have an enrolled TOTP, passkey, or other second-factor provider. This setting cannot be enabled yet and no two-factor protection is active.',
                ),
              ),
              const SizedBox(height: 10),

              SakhiSettingsRow(
                icon: Icons.person_off_outlined,
                iconColor: AppColors.sosRed,
                iconBgColor: AppColors.sosRedSoft,
                title: 'Account deactivation',
                subtitle:
                    'Unavailable • account deactivation is not exposed by the current backend',
                onTap: () => _showUnavailableInfo(
                  context,
                  'Temporarily deactivate account',
                  'Deactivation is not exposed by the current backend. Nothing has been changed. This action must hide your profile and posts until you sign in again.',
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
