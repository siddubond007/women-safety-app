import 'package:flutter/material.dart';

import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_card.dart';
import '../../../core/widgets/sakhi_section_header.dart';
import '../../account_security/screens/account_security_screen.dart';
import '../../notifications/screens/notification_preferences_screen.dart';

/// Screen 09 — Privacy & Account Settings
class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  Future<void> _savePrivacyControl(
    BuildContext context,
    SakhiPrototypeState state,
    String id,
    String value,
  ) async {
    final saved = await state.updatePrivacySetting(id, value);
    if (!context.mounted || saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value == 'Circle Members Only'
              ? 'Circle-only privacy is not yet enforceable by the connected backend. Choose another audience.'
              : 'That privacy setting could not be saved. No change was kept.',
        ),
      ),
    );
  }

  Widget _buildAudienceDropdownRow({
    required BuildContext context,
    required SakhiPrototypeState state,
    required PrivacySettingItem item,
    required String title,
    required String subtitle,
  }) {
    final shortValue = item.selectedValue
        .replaceAll(' only', '')
        .replaceAll('Verified members', 'Verified Members')
        .replaceAll('Followers', 'Followers Only')
        .replaceAll('Only Only', 'Only');
    return InkWell(
      onTap: () => _showPrivacySelectionSheet(context, state, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.pastelLavender,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: AppColors.primaryPurple, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.subtitle),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.pastelLavender,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    shortValue,
                    style: const TextStyle(
                      color: AppColors.primaryPurple,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 15,
                    color: AppColors.primaryPurple,
                  ),
                ],
              ),
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
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Privacy & Account Settings',
          style: AppTypography.appBarTitle,
        ),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                tooltip: 'Back to Profile',
                icon: const Icon(Icons.chevron_left_rounded, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final viewProfile = state.privacySettings.firstWhere(
            (setting) => setting.id == 'view_profile',
          );
          final messageMe = state.privacySettings.firstWhere(
            (setting) => setting.id == 'message_me',
          );
          final seePosts = state.privacySettings.firstWhere(
            (setting) => setting.id == 'see_posts',
          );
          final location = state.privacySettings.firstWhere(
            (setting) => setting.id == 'show_location',
          );
          final locationEnabled = location.selectedValue != 'Hide Location';
          final business = state.privacySettings.firstWhere(
            (setting) => setting.id == 'business_enquiries',
          );
          final search = state.privacySettings.firstWhere(
            (setting) => setting.id == 'search_results',
          );

          final commNotif = state.notificationPreferences
              .where((p) => p.id == 'community_updates')
              .firstOrNull;
          final groupNotif = state.notificationPreferences
              .where((p) => p.id == 'group_activity')
              .firstOrNull;
          final wellnessNotif = state.notificationPreferences
              .where((p) => p.id == 'wellness_reminders')
              .firstOrNull;
          final safetyNotif = state.notificationPreferences
              .where((p) => p.id == 'safety_alerts')
              .firstOrNull;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPaddingH,
              4,
              AppSpacing.screenPaddingH,
              48,
            ),
            children: [
              const SakhiSectionHeader(title: 'Privacy Controls'),
              const SizedBox(height: 8),
              SakhiCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    _buildAudienceDropdownRow(
                      context: context,
                      state: state,
                      item: viewProfile,
                      title: 'Who can view my profile',
                      subtitle: 'Control profile visibility',
                    ),
                    const Divider(height: 1, color: AppColors.dividerColor),
                    _buildAudienceDropdownRow(
                      context: context,
                      state: state,
                      item: messageMe,
                      title: 'Who can message me',
                      subtitle: 'Direct message permissions',
                    ),
                    const Divider(height: 1, color: AppColors.dividerColor),
                    _buildAudienceDropdownRow(
                      context: context,
                      state: state,
                      item: seePosts,
                      title: 'Who can see my posts',
                      subtitle: 'Default audience for new posts',
                    ),
                    const Divider(height: 1, color: AppColors.dividerColor),
                    SwitchListTile(
                      value: locationEnabled,
                      activeThumbColor: AppColors.primaryPurple,
                      title: const Text(
                        'Show my general location',
                        style: AppTypography.bodyMedium,
                      ),
                      subtitle: const Text(
                        'City level only (never live GPS)',
                        style: AppTypography.subtitle,
                      ),
                      onChanged: (enabled) => _savePrivacyControl(
                        context,
                        state,
                        'show_location',
                        enabled ? 'Verified Members' : 'Hide Location',
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.dividerColor),
                    SwitchListTile(
                      value: search.selectedValue == 'Yes',
                      activeThumbColor: AppColors.primaryPurple,
                      title: const Text(
                        'Appear in search results',
                        style: AppTypography.bodyMedium,
                      ),
                      subtitle: const Text(
                        'Allow members to find you by name',
                        style: AppTypography.subtitle,
                      ),
                      onChanged: (enabled) => _savePrivacyControl(
                        context,
                        state,
                        'search_results',
                        enabled ? 'Yes' : 'No',
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.dividerColor),
                    SwitchListTile(
                      value: business.selectedValue == 'Yes',
                      activeThumbColor: AppColors.primaryPurple,
                      title: const Text(
                        'Allow business enquiries',
                        style: AppTypography.bodyMedium,
                      ),
                      subtitle: const Text(
                        'For linked women-owned businesses',
                        style: AppTypography.subtitle,
                      ),
                      onChanged: (enabled) => _savePrivacyControl(
                        context,
                        state,
                        'business_enquiries',
                        enabled ? 'Yes' : 'No',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SakhiSectionHeader(
                title: 'Notifications',
                actionLabel: 'All settings >',
                onActionTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationPreferencesScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SakhiCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: commNotif?.isEnabled ?? true,
                      activeThumbColor: AppColors.primaryPurple,
                      title: const Text(
                        'Community updates & replies',
                        style: AppTypography.bodyMedium,
                      ),
                      onChanged: (val) => state.toggleNotificationPref(
                        'community_updates',
                        val,
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.dividerColor),
                    SwitchListTile(
                      value: groupNotif?.isEnabled ?? true,
                      activeThumbColor: AppColors.primaryPurple,
                      title: const Text(
                        'Circle & group activity',
                        style: AppTypography.bodyMedium,
                      ),
                      onChanged: (val) =>
                          state.toggleNotificationPref('group_activity', val),
                    ),
                    const Divider(height: 1, color: AppColors.dividerColor),
                    SwitchListTile(
                      value: wellnessNotif?.isEnabled ?? true,
                      activeThumbColor: AppColors.primaryPurple,
                      title: const Text(
                        'Wellness & cycle reminders',
                        style: AppTypography.bodyMedium,
                      ),
                      onChanged: (val) => state.toggleNotificationPref(
                        'wellness_reminders',
                        val,
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.dividerColor),
                    SwitchListTile(
                      value: safetyNotif?.isEnabled ?? true,
                      activeThumbColor: AppColors.primaryPurple,
                      title: const Text(
                        'Safety alerts & check-ins',
                        style: AppTypography.bodyMedium,
                      ),
                      onChanged: (val) =>
                          state.toggleNotificationPref('safety_alerts', val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SakhiSectionHeader(title: 'Account & Security'),
              const SizedBox(height: 8),
              SakhiCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.pastelLavender,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.block_outlined,
                          color: AppColors.primaryPurple,
                          size: 19,
                        ),
                      ),
                      title: const Text(
                        'Blocked & Reported Users',
                        style: AppTypography.bodyMedium,
                      ),
                      subtitle: const Text(
                        'Manage blocked accounts',
                        style: AppTypography.subtitle,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${state.blockedUsers.length} blocked',
                            style: AppTypography.subtitle,
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const BlockedMembersScreen(),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.dividerColor),
                    ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.pastelLavender,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.verified_user_outlined,
                          color: AppColors.primaryPurple,
                          size: 19,
                        ),
                      ),
                      title: const Text(
                        'Two-Factor Authentication',
                        style: AppTypography.bodyMedium,
                      ),
                      subtitle: const Text(
                        'Extra security for your account',
                        style: AppTypography.subtitle,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F5EC),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              state.currentUser.twoFactorEnabled
                                  ? 'Enabled'
                                  : 'Configure',
                              style: const TextStyle(
                                color: Color(0xFF1E7E52),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AccountSecurityScreen(),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.dividerColor),
                    ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.pastelLavender,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.devices_other_outlined,
                          color: AppColors.primaryPurple,
                          size: 19,
                        ),
                      ),
                      title: const Text(
                        'Active Login Sessions',
                        style: AppTypography.bodyMedium,
                      ),
                      subtitle: Text(
                        '${state.currentUser.activeSessionsCount} active device(s) • Bangalore (Current)',
                        style: AppTypography.subtitle,
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AccountSecurityScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: () => _showDeactivationInfo(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryPurple,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.borderSubtle),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Deactivate Account Temporarily',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => _showDeleteAccountNotice(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFEDF1),
                  foregroundColor: AppColors.sosRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                    side: const BorderSide(color: Color(0xFFF3C6CE)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text(
                  'Delete Account Permanently',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPrivacySelectionSheet(
    BuildContext context,
    SakhiPrototypeState state,
    PrivacySettingItem item,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
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
              const SizedBox(height: 16),
              Text(item.title, style: AppTypography.sectionTitle),
              const SizedBox(height: 10),
              ...item.options.map(
                (option) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(option, style: AppTypography.bodyMedium),
                  trailing: item.selectedValue == option
                      ? const Icon(
                          Icons.radio_button_checked_rounded,
                          color: AppColors.primaryPurple,
                        )
                      : const Icon(
                          Icons.radio_button_off_rounded,
                          color: AppColors.textMuted,
                        ),
                  onTap: () async {
                    final saved = await state.updatePrivacySetting(
                      item.id,
                      option,
                    );
                    if (!sheetContext.mounted) return;
                    if (!saved) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            option == 'Circle Members Only'
                                ? 'Circle-only privacy is not yet enforceable by the connected backend. Choose All Verified Members or Followers Only.'
                                : 'That privacy setting could not be saved. No change was kept.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(sheetContext);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeactivationInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Temporarily deactivate account',
                style: AppTypography.sectionTitle,
              ),
              const SizedBox(height: 8),
              const Text(
                'Deactivation is not exposed by the current backend. Nothing has been changed. This action must hide your profile and posts until you sign in again.',
                style: AppTypography.bodyRegular,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountNotice(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account and personal data?'),
        content: const Text(
          'This is a destructive action. The currently connected API can submit deletion directly but does not expose the separate fresh-OTP challenge required by the Sakhi specification. No deletion request has been sent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class BlockedMembersScreen extends StatelessWidget {
  const BlockedMembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        title: const Text('Blocked & Reported Users'),
      ),
      body: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          if (state.blockedUsers.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'You have not blocked any members.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyRegular,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.blockedUsers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final blocked = state.blockedUsers[index];
              return SakhiCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.pastelLavender,
                    child: Icon(
                      Icons.block_rounded,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                  title: Text(
                    blocked.blockedDisplayName,
                    style: AppTypography.bodyMedium,
                  ),
                  subtitle: Text(
                    blocked.blockedUsername,
                    style: AppTypography.subtitle,
                  ),
                  trailing: TextButton(
                    onPressed: () => state.toggleBlockedUser(
                      username: blocked.blockedUsername,
                      displayName: blocked.blockedDisplayName,
                      accountId: blocked.id,
                    ),
                    child: const Text('Unblock'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
