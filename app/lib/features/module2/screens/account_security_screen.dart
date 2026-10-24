import 'package:flutter/material.dart';

import '../../../core/constants/mock_data.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_settings_row.dart';
import '../widgets/module2_feature_widgets.dart';

class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({
    super.key,
    this.onSignOut,
    this.onNavigateRoute,
  });

  final VoidCallback? onSignOut;
  final ValueChanged<String>? onNavigateRoute;

  void _navigate(BuildContext context, String route) {
    final handler = onNavigateRoute;
    if (handler != null) {
      handler(route);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Navigation is unavailable in this preview.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = SakhiPrototypeState.instance;
    return AnimatedBuilder(
      animation: ui,
      builder: (context, _) {
        final state = ui.backend;
        final profile = state?.profile;
        return Module2PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Module2PageTitle(
                'Account & Security',
                subtitle: 'Manage your account access and security actions',
              ),
              const SizedBox(height: 9),
              const Text(
                'Session and account changes are validated by the backend. Sensitive operations require explicit confirmation.',
                style: AppTypography.subtitle,
              ),
              const SizedBox(height: 16),
              SakhiSettingsRow(
                icon: Icons.phone_rounded,
                title: 'Phone number',
                subtitle: profile?.phoneMasked.isNotEmpty == true
                    ? profile!.phoneMasked
                    : 'No phone number available',
                trailing: Module2ProfileBadge(
                  status: profile?.verificationStatus ?? 'UNVERIFIED',
                ),
                onTap: () => _showInfo(
                  context,
                  'Phone number',
                  profile?.phoneVerified == true
                      ? 'The development account has completed its OTP flow. This environment does not verify the phone with a mobile carrier.'
                      : 'Your phone number has not completed OTP verification.',
                ),
              ),
              const SizedBox(height: 9),
              SakhiSettingsRow(
                icon: Icons.email_outlined,
                title: 'Email address',
                subtitle: profile?.email?.isNotEmpty == true
                    ? profile!.email!
                    : 'Optional email is not set',
                onTap: () => _navigate(context, AppRoutes.editProfile),
              ),
              const SizedBox(height: 9),
              SakhiSettingsRow(
                icon: Icons.devices_rounded,
                title: 'Login sessions',
                subtitle: state?.sessions.isNotEmpty == true
                    ? '${state!.sessions.where((item) => item['isActive'] == true).length} active session(s)'
                    : 'View and revoke sessions',
                onTap: () => _showSessions(context),
              ),
              const SizedBox(height: 9),
              SakhiSettingsRow(
                icon: Icons.lock_outline_rounded,
                title: 'Change PIN / Password',
                subtitle: 'This account currently signs in with phone OTP',
                onTap: () => _showInfo(
                  context,
                  'PIN / Password',
                  'No password or PIN credential is stored by the current OTP-only authentication service. A separate credential mechanism must be designed before a PIN or password can be changed.',
                ),
              ),
              const SizedBox(height: 9),
              SakhiSettingsRow(
                icon: Icons.phonelink_lock_rounded,
                title: 'Two-factor authentication',
                subtitle: 'Additional authentication provider required',
                onTap: () => _showInfo(
                  context,
                  'Two-factor authentication',
                  'TOTP, passkey or another second-factor provider has not been configured. This screen will not claim to enable a security control that is not active.',
                ),
              ),
              const SizedBox(height: 9),
              SakhiSettingsRow(
                icon: Icons.pause_circle_outline_rounded,
                title: 'Account deactivation',
                subtitle: 'Suspend account access and revoke sessions',
                iconColor: AppColors.amberAccent,
                iconBgColor: AppColors.pastelPeach,
                onTap: () => _confirmDeactivate(context),
              ),
              const SizedBox(height: 9),
              SakhiSettingsRow(
                icon: Icons.delete_outline_rounded,
                title: 'Delete account',
                subtitle: 'Disable access and submit the deletion workflow',
                iconColor: AppColors.sosRed,
                iconBgColor: AppColors.sosRedSoft,
                onTap: () => _confirmDelete(context),
              ),
              if (state?.errorMessage != null) ...[
                const SizedBox(height: 9),
                Text(
                  state!.errorMessage!,
                  style: const TextStyle(color: AppColors.sosRed, fontSize: 12),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSessions(BuildContext context) async {
    final backend = SakhiPrototypeState.instance.backend;
    if (backend == null) return;
    await backend.loadSessions();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AnimatedBuilder(
        animation: backend,
        builder: (context, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * .65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Login sessions',
                    style: AppTypography.sectionTitle,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Revoke access on a device you no longer use.',
                    style: AppTypography.subtitle,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: backend.sessions.isEmpty
                        ? const Module2EmptyPanel(
                            icon: Icons.devices_outlined,
                            title: 'No active sessions found',
                            message: 'The backend returned no login sessions for this account.',
                          )
                        : ListView.separated(
                            itemCount: backend.sessions.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 18),
                            itemBuilder: (context, index) {
                              final session = backend.sessions[index];
                              final active = session['isActive'] == true;
                              final current = session['isCurrent'] == true;
                              final created = session['createdAt'] is String
                                  ? DateTime.tryParse(
                                      session['createdAt'] as String,
                                    )?.toLocal().toString().split('.').first
                                  : null;
                              final expires = session['expiresAt'] is String
                                  ? DateTime.tryParse(
                                      session['expiresAt'] as String,
                                    )?.toLocal().toString().split('.').first
                                  : null;
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
                                          current
                                              ? 'This device'
                                              : 'Login session',
                                          style: AppTypography.cardTitle
                                              .copyWith(fontSize: 13),
                                        ),
                                        if (created != null)
                                          Text(
                                            'Created: $created',
                                            style: AppTypography.subtitle,
                                          ),
                                        if (expires != null)
                                          Text(
                                            'Expires: $expires',
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
                                  if (active)
                                    TextButton(
                                      onPressed: () => _revokeSession(
                                        context,
                                        backend,
                                        session,
                                      ),
                                      child: const Text('Revoke'),
                                    ),
                                ],
                              );
                            },
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

  Future<void> _revokeSession(
    BuildContext context,
    dynamic backend,
    Map<String, dynamic> session,
  ) async {
    final id = session['id'];
    if (id is! String) return;
    final current = session['isCurrent'] == true;
    final success = await backend.revokeSession(id);
    if (!context.mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            backend.errorMessage ?? 'Session could not be revoked.',
          ),
        ),
      );
      return;
    }
    if (current) {
      Navigator.of(context).pop();
      onSignOut?.call();
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Login session revoked.')));
  }

  Future<void> _confirmDeactivate(BuildContext context) async {
    final confirmed = await _showTypedConfirmation(
      context,
      title: 'Deactivate your account?',
      description: 'Your account will be suspended, active sessions revoked, and your published posts hidden. Enter DEACTIVATE to confirm.',
      expected: 'DEACTIVATE',
    );
    if (!context.mounted || !confirmed) return;
    final backend = SakhiPrototypeState.instance.backend;
    final success = await backend?.deactivateAccount() ?? false;
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Account deactivated.')));
      onSignOut?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            backend?.errorMessage ?? 'Account deactivation failed.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await _showTypedConfirmation(
      context,
      title: 'Request account deletion?',
      description: 'This disables account access and immediately scrubs profile/post content. Retained records are handled under Sakhi’s approved retention process. Enter DELETE to continue.',
      expected: 'DELETE',
    );
    if (!context.mounted || !confirmed) return;
    final backend = SakhiPrototypeState.instance.backend;
    final success = await backend?.requestAccountDeletion() ?? false;
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deletion request submitted.')),
      );
      onSignOut?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            backend?.errorMessage ?? 'Account deletion could not be submitted.',
          ),
        ),
      );
    }
  }

  Future<bool> _showTypedConfirmation(
    BuildContext context, {
    required String title,
    required String description,
    required String expected,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(labelText: 'Type $expected'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.sosRed),
            onPressed: () =>
                Navigator.pop(context, controller.text.trim() == expected),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result == true;
  }

  void _showInfo(BuildContext context, String title, String description) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
