import 'package:flutter/material.dart';

import '../../../core/constants/mock_data.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_settings_row.dart';
import '../widgets/module2_feature_widgets.dart';

class MoreOptionsScreen extends StatelessWidget {
  const MoreOptionsScreen({super.key, this.onNavigateRoute, this.onSignOut});

  final ValueChanged<String>? onNavigateRoute;
  final VoidCallback? onSignOut;

  void _navigate(BuildContext context, String route) {
    if (onNavigateRoute != null) {
      onNavigateRoute!(route);
    } else {
      Navigator.of(context).pushNamed(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => Module2PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Module2PageTitle(
              'More Options',
              subtitle: 'Account tools, privacy and support',
            ),
            const SizedBox(height: 16),
            SakhiSettingsRow(
              icon: Icons.groups_rounded,
              title: 'My Groups',
              subtitle: 'View your community spaces',
              onTap: () => _navigate(context, AppRoutes.myGroups),
            ),
            const SizedBox(height: 9),
            SakhiSettingsRow(
              icon: Icons.bookmark_border_rounded,
              title: 'My Saved Posts',
              subtitle: 'Posts you have bookmarked',
              onTap: () {
                state.showSavedPostsFirst = true;
                _navigate(context, AppRoutes.profile);
              },
            ),
            const SizedBox(height: 9),
            SakhiSettingsRow(
              icon: Icons.business_center_outlined,
              title: 'Business Profile',
              subtitle: state.backend?.businessProfile == null
                  ? 'Create or manage your business listing'
                  : 'Manage your submitted business listing',
              onTap: () => _editBusinessProfile(context),
            ),
            const SizedBox(height: 9),
            SakhiSettingsRow(
              icon: Icons.help_outline_rounded,
              title: 'Help & Support',
              subtitle: 'Troubleshooting and help options',
              onTap: () => _showHelp(context),
            ),
            const SizedBox(height: 9),
            SakhiSettingsRow(
              icon: Icons.shield_moon_rounded,
              title: 'Discreet & Anonymous Complaint Hub',
              subtitle: 'File anonymous or confidential reports & track status',
              onTap: () => _navigate(context, AppRoutes.discreetComplaintHub),
            ),
            const SizedBox(height: 9),
            SakhiSettingsRow(
              icon: Icons.flag_outlined,
              title: 'Report a User',
              subtitle: 'Send a report for moderation review',
              onTap: () => _reportMember(context),
            ),
            const SizedBox(height: 9),
            SakhiSettingsRow(
              icon: Icons.block_rounded,
              title: 'Blocked Users',
              subtitle: 'Manage accounts you have blocked',
              onTap: () => _manageBlocked(context),
            ),
            const SizedBox(height: 9),
            SakhiSettingsRow(
              icon: Icons.policy_outlined,
              title: 'Terms and Conditions',
              subtitle: 'Current Terms version: draft',
              onTap: () => _showDraftPolicy(context, 'Terms and Conditions'),
            ),
            const SizedBox(height: 9),
            SakhiSettingsRow(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'Current Privacy version: draft',
              onTap: () => _showDraftPolicy(context, 'Privacy Policy'),
            ),
            const SizedBox(height: 9),
            SakhiSettingsRow(
              icon: Icons.info_outline_rounded,
              title: 'About Sakhi',
              subtitle: 'Version 1.2.0',
              onTap: () => _showAbout(context),
            ),
            const SizedBox(height: 19),
            const Text('Settings shortcuts', style: AppTypography.sectionTitle),
            const SizedBox(height: 10),
            SakhiSettingsRow(
              icon: Icons.person_outline_rounded,
              title: 'Edit Profile',
              subtitle: 'Name, email, bio, location and interests',
              onTap: () => _navigate(context, AppRoutes.editProfile),
            ),
            const SizedBox(height: 9),
            SakhiSettingsRow(
              icon: Icons.visibility_outlined,
              title: 'Privacy Settings',
              subtitle: 'Visibility, location and search controls',
              onTap: () => _navigate(context, AppRoutes.privacySettings),
            ),
            const SizedBox(height: 9),
            SakhiSettingsRow(
              icon: Icons.notifications_none_rounded,
              title: 'Notification Preferences',
              subtitle: 'Control update categories',
              onTap: () =>
                  _navigate(context, AppRoutes.notificationPreferences),
            ),
            const SizedBox(height: 9),
            SakhiSettingsRow(
              icon: Icons.security_rounded,
              title: 'Account & Security',
              subtitle: 'Sessions and account lifecycle',
              onTap: () => _navigate(context, AppRoutes.accountSecurity),
            ),
            const SizedBox(height: 9),
            SakhiSettingsRow(
              icon: Icons.people_outline_rounded,
              title: 'Followers & Following',
              subtitle: 'Manage your connections',
              onTap: () => _navigate(context, AppRoutes.followers),
            ),
            if (state.backend?.errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                state.backend!.errorMessage!,
                style: const TextStyle(color: AppColors.sosRed, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editBusinessProfile(BuildContext context) async {
    final state = SakhiPrototypeState.instance;
    await state.backend?.loadBusinessProfile();
    if (!context.mounted) return;
    final current = state.backend?.businessProfile ?? <String, dynamic>{};
    final name = TextEditingController(
      text: current['displayName'] is String
          ? current['displayName'] as String
          : '',
    );
    final description = TextEditingController(
      text: current['description'] is String
          ? current['description'] as String
          : '',
    );
    final website = TextEditingController(
      text: current['websiteUrl'] is String
          ? current['websiteUrl'] as String
          : '',
    );
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Business Profile', style: AppTypography.sectionTitle),
              const SizedBox(height: 7),
              const Text(
                'New or changed business listings are submitted for review. They do not become verified automatically.',
                style: AppTypography.subtitle,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: name,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Business name *'),
              ),
              const SizedBox(height: 9),
              TextField(
                controller: description,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              const SizedBox(height: 9),
              TextField(
                controller: website,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Website URL (HTTPS only)',
                ),
              ),
              if (current['status'] is String) ...[
                const SizedBox(height: 7),
                Text(
                  'Current review status: ${current['status']}',
                  style: AppTypography.subtitle,
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Submit for review'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (saved == true && name.text.trim().length >= 2) {
      final success =
          await state.backend?.saveBusinessProfile(
            displayName: name.text,
            description: description.text,
            websiteUrl: website.text,
          ) ??
          false;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Business profile submitted for review.'
                  : (state.backend?.errorMessage ??
                        'Business profile could not be saved.'),
            ),
          ),
        );
      }
    }
    name.dispose();
    description.dispose();
    website.dispose();
  }

  Future<void> _manageBlocked(BuildContext context) async {
    final backend = SakhiPrototypeState.instance.backend;
    if (backend == null) return;
    await backend.loadBlockedMembers();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AnimatedBuilder(
        animation: backend,
        builder: (context, _) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * .6,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Blocked Users',
                    style: AppTypography.sectionTitle,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: backend.blockedMembers.isEmpty
                        ? const Module2EmptyPanel(
                            icon: Icons.block_rounded,
                            title: 'No blocked members',
                            message: 'Members you block will appear here.',
                          )
                        : ListView.separated(
                            itemCount: backend.blockedMembers.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 14),
                            itemBuilder: (context, index) {
                              final member = backend.blockedMembers[index];
                              return Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      member.displayName,
                                      style: AppTypography.cardTitle,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        backend.unblockMember(member),
                                    child: const Text('Unblock'),
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

  Future<void> _reportMember(BuildContext context) async {
    final state = SakhiPrototypeState.instance;
    await state.loadDiscover();
    if (!context.mounted) return;
    final members = state.backend?.discoveredMembers ?? [];
    if (members.isEmpty) {
      _showInfo(
        context,
        'Report a User',
        'There are no currently discoverable verified member profiles to select. Open Explore to search available member profiles first.',
      );
      return;
    }
    String? selectedId;
    String reason = 'UNSAFE_CONTENT';
    final details = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Report a User', style: AppTypography.sectionTitle),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedId,
                  decoration: const InputDecoration(labelText: 'Member'),
                  items: members
                      .map(
                        (member) => DropdownMenuItem(
                          value: member.accountId,
                          child: Text(member.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setSheetState(() => selectedId = value),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: const [
                    DropdownMenuItem(
                      value: 'HARASSMENT',
                      child: Text('Harassment'),
                    ),
                    DropdownMenuItem(
                      value: 'IMPERSONATION',
                      child: Text('Impersonation'),
                    ),
                    DropdownMenuItem(value: 'SPAM', child: Text('Spam')),
                    DropdownMenuItem(
                      value: 'UNSAFE_CONTENT',
                      child: Text('Unsafe content'),
                    ),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (value) => setSheetState(() {
                    if (value != null) reason = value;
                  }),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: details,
                  maxLength: 1000,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Additional details (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: selectedId == null
                        ? null
                        : () => Navigator.pop(context, true),
                    child: const Text('Submit report'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == true && selectedId != null) {
      final success = await state.reportMember(
        accountId: selectedId!,
        reason: reason,
        details: details.text,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Report submitted for review.'
                  : (state.backend?.errorMessage ??
                        'Report could not be submitted.'),
            ),
          ),
        );
      }
    }
    details.dispose();
  }

  void _showDraftPolicy(BuildContext context, String title) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text(
          'The backend currently contains DRAFT policy-version metadata, not a published legal document. The final approved legal text must be supplied and published before this screen can display it as current policy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Sakhi',
      applicationVersion: '1.0.0',
      applicationLegalese: 'Women’s safety, community and wellness.',
      children: const [
        SizedBox(height: 12),
        Text(
          'Profile, privacy and community controls use the authenticated Module 2 API. Some infrastructure-backed features remain unconfigured and are not represented as active.',
        ),
      ],
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text(
          'For sign-in problems, confirm the Sakhi backend is ready and try signing in again. In this development build, OTPs are echoed by the local backend and no SMS is sent. Contact details for production support have not yet been configured.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showInfo(BuildContext context, String title, String detail) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(detail),
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
