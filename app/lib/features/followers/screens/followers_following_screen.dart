import '../../../core/widgets/sakhi_quote_loader.dart';

import 'package:flutter/material.dart';

import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_avatar.dart';
import '../../../core/widgets/sakhi_buttons.dart';
import '../../../core/widgets/sakhi_card.dart';
import '../../../core/widgets/sakhi_empty_state.dart';
import '../../../core/widgets/sakhi_search_field.dart';
import '../../explore/screens/explore_discovery_screens.dart';

/// Screen 08 — Followers & Following + Member Options Modal
class FollowersFollowingScreen extends StatefulWidget {
  const FollowersFollowingScreen({super.key, this.initialFollowing = false});

  final bool initialFollowing;

  @override
  State<FollowersFollowingScreen> createState() =>
      _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showingFollowingOnly = false;
  bool _loadingConnections = false;
  bool _connectionsUnavailable = false;
  List<FollowerUserModel> _members = const <FollowerUserModel>[];

  @override
  void initState() {
    super.initState();
    _showingFollowingOnly = widget.initialFollowing;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadConnections();
    });
  }

  Future<void> _loadConnections() async {
    final requestedFollowing = _showingFollowingOnly;
    setState(() {
      _loadingConnections = true;
      _connectionsUnavailable = false;
    });
    final items = await SakhiPrototypeState.instance.fetchMemberConnections(
      following: requestedFollowing,
    );
    if (!mounted || requestedFollowing != _showingFollowingOnly) return;
    setState(() {
      _members = items ?? const <FollowerUserModel>[];
      _connectionsUnavailable = items == null;
      _loadingConnections = false;
    });
  }

  Future<void> _setConnectionTab(bool followingTab) async {
    if (_showingFollowingOnly == followingTab) return;
    setState(() {
      _showingFollowingOnly = followingTab;
      _members = const <FollowerUserModel>[];
      _connectionsUnavailable = false;
    });
    await _loadConnections();
  }

  Future<void> _toggleMemberFollow(
    SakhiPrototypeState state,
    FollowerUserModel member,
  ) async {
    final succeeded = await state.toggleFollowSearchMember(member);
    if (!mounted) return;
    setState(() {});
    if (!succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Follow could not be updated. No change was kept.'),
        ),
      );
    }
  }

  void _openMemberProfile(FollowerUserModel member) {
    if (!member.canFollow) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This profile is not available in the verified directory.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchResultMemberProfileScreen(member: member),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMemberOptions(
    BuildContext context,
    SakhiPrototypeState state,
    FollowerUserModel member,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
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
              const SizedBox(height: 14),
              Row(
                children: [
                  SakhiAvatar(
                    imageAsset: member.avatarAsset,
                    fallbackLabel: member.name,
                    size: 46,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(member.name, style: AppTypography.cardTitle),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.primaryPurple,
                              size: 16,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${member.username} • Member Options',
                          style: AppTypography.subtitle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.dividerColor),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.pastelLavender,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.primaryPurple,
                    size: 19,
                  ),
                ),
                title: const Text(
                  'Manage Message Permission',
                  style: AppTypography.bodyMedium,
                ),
                trailing: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Allowed', style: AppTypography.subtitle),
                    SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
                onTap: () =>
                    _showUnavailableAction(sheetContext, 'Message permissions'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.pastelLavender,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_remove_alt_1_outlined,
                    color: AppColors.primaryPurple,
                    size: 19,
                  ),
                ),
                title: const Text(
                  'Remove from Followers',
                  style: AppTypography.bodyMedium,
                ),
                subtitle: Text(
                  'Remove ${member.username} from your followers list',
                  style: AppTypography.subtitle,
                ),
                onTap: () => _showUnavailableAction(
                  sheetContext,
                  'Remove from followers',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.pastelLavender,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.volume_off_outlined,
                    color: AppColors.primaryPurple,
                    size: 19,
                  ),
                ),
                title: const Text(
                  'Mute Posts',
                  style: AppTypography.bodyMedium,
                ),
                subtitle: const Text(
                  'Hide posts from feed without unfollowing',
                  style: AppTypography.subtitle,
                ),
                onTap: () => _showUnavailableAction(sheetContext, 'Mute posts'),
              ),
              const SizedBox(height: 8),
              // Red Block Action Card matching Reference 08
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F3),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF3C6CE)),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.block_rounded,
                    color: AppColors.sosRed,
                  ),
                  title: Text(
                    'Block ${member.username}',
                    style: const TextStyle(
                      color: AppColors.sosRed,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: const Text(
                    "They won't be able to see your profile or message you",
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF9C3346)),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: Text('Block ${member.username}?'),
                        content: const Text(
                          'You can manage blocked members in Sakhi Settings.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Block'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && mounted) {
                      final blocked = await state.toggleBlockedUser(
                        username: member.username,
                        displayName: member.name,
                        accountId: member.id,
                      );
                      if (!mounted || !context.mounted) return;
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            blocked
                                ? '${member.username} was blocked.'
                                : 'Blocking failed. No change was made.',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
              // Red Report Action Card matching Reference 08
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F3),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF3C6CE)),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.flag_outlined,
                    color: AppColors.sosRed,
                  ),
                  title: const Text(
                    'Report Inappropriate Behaviour',
                    style: TextStyle(
                      color: AppColors.sosRed,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: const Text(
                    'Confidentially report harassment, spam, or fake profile',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF9C3346)),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showReportDialog(context, state, member);
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.pastelLavender,
                    foregroundColor: AppColors.primaryPurple,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnavailableAction(BuildContext sheetContext, String action) {
    Navigator.of(sheetContext).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$action needs a backend API that is not currently implemented. No change was made.',
        ),
      ),
    );
  }

  Future<void> _showReportDialog(
    BuildContext context,
    SakhiPrototypeState state,
    FollowerUserModel member,
  ) async {
    String reason = 'Harassment';
    final noteController = TextEditingController();
    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => AlertDialog(
          title: const Text('Report Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: const [
                  DropdownMenuItem(
                    value: 'Harassment',
                    child: Text('Harassment'),
                  ),
                  DropdownMenuItem(
                    value: 'Impersonation / Fake Profile',
                    child: Text('Impersonation / Fake Profile'),
                  ),
                  DropdownMenuItem(value: 'Spam', child: Text('Spam')),
                  DropdownMenuItem(
                    value: 'Unsafe Content',
                    child: Text('Unsafe Content'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) updateDialog(() => reason = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Additional details (optional)',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
    if (shouldSubmit == true) {
      final submitted = await state.reportMember(
        accountId: member.id,
        reportedAccountId: member.id,
        targetHandle: member.username,
        reason: reason,
        reasonCode: reason.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
        details: noteController.text.trim(),
      );
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              submitted ? 'Report submitted to Sakhi for review.' : 'Report could not be submitted. Check your connection and retry.',
            ),
          ),
        );
      }
    }
    noteController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: state,
          builder: (context, _) {
            final user = state.currentUser;
            final handle = user.username.isEmpty
                ? '@ananya_rao'
                : user.username;
            final query = _searchController.text.trim().toLowerCase();
            final filtered = _members.where((u) {
              if (query.isEmpty) return true;
              return u.name.toLowerCase().contains(query) ||
                  u.username.toLowerCase().contains(query);
            }).toList();

            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPaddingH,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.chevron_left_rounded,
                          color: AppColors.primaryPurple,
                          size: 30,
                        ),
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                      Expanded(
                        child: Text(
                          '${user.displayName} ($handle)',
                          textAlign: TextAlign.center,
                          style: AppTypography.sectionTitle.copyWith(
                            fontSize: 16.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  // 2-Tab Bar: Followers (count) | Following (count) matching Reference 08
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.dividerColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _loadingConnections
                                ? null
                                : () => _setConnectionTab(false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: !_showingFollowingOnly
                                        ? AppColors.primaryPurple
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Followers (${user.followersCount})',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: !_showingFollowingOnly
                                      ? AppColors.primaryPurple
                                      : AppColors.textMuted,
                                  fontWeight: !_showingFollowingOnly
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: _loadingConnections
                                ? null
                                : () => _setConnectionTab(true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: _showingFollowingOnly
                                        ? AppColors.primaryPurple
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Following (${user.followingCount})',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _showingFollowingOnly
                                      ? AppColors.primaryPurple
                                      : AppColors.textMuted,
                                  fontWeight: _showingFollowingOnly
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  SakhiSearchField(
                    hintText: 'Search followers...',
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    onClear: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  ),

                  const SizedBox(height: 14),
                  Expanded(
                    child: _loadingConnections
                        ? const SakhiQuoteLoader.inline(
                            statusLabel: 'Loading your Sakhi connections…',
                          )
                        : _connectionsUnavailable
                        ? SakhiEmptyState(
                            icon: Icons.cloud_off_outlined,
                            title: 'Live profiles unavailable',
                            message: state.lastSyncError ?? 'Sakhi could not load current follower and following records.',
                            actionLabel: 'Retry',
                            onAction: _loadConnections,
                          )
                        : filtered.isEmpty
                        ? SakhiEmptyState(
                            icon: Icons.person_search_rounded,
                            title: query.isNotEmpty
                                ? 'No matching profiles'
                                : _showingFollowingOnly
                                ? 'You are not following anyone yet'
                                : 'You do not have any followers yet',
                            message: query.isNotEmpty
                                ? 'No verified connections matched "${_searchController.text}".'
                                : _showingFollowingOnly
                                ? 'Follow a verified member from Search to see them here.'
                                : 'When verified members follow you, their profiles will appear here.',
                            actionLabel: query.isNotEmpty
                                ? 'Clear Search'
                                : 'Refresh',
                            onAction: query.isNotEmpty
                                ? () {
                                    _searchController.clear();
                                    setState(() {});
                                  }
                                : _loadConnections,
                          )
                        : SakhiCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const Divider(
                                height: 1,
                                color: AppColors.dividerColor,
                              ),
                              itemBuilder: (context, index) {
                                final person = filtered[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      SakhiAvatar(
                                        imageAsset: person.avatarAsset,
                                        fallbackLabel: person.name,
                                        size: 46,
                                        onAvatarTap: () =>
                                            _openMemberProfile(person),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () =>
                                              _openMemberProfile(person),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      person.name,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: AppTypography
                                                          .cardTitle,
                                                    ),
                                                  ),
                                                  if (person.isVerified) ...[
                                                    const SizedBox(width: 4),
                                                    const Icon(
                                                      Icons.verified_rounded,
                                                      color: AppColors
                                                          .primaryPurple,
                                                      size: 15,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                person.bio?.isNotEmpty == true
                                                    ? '${person.username} • ${person.bio}'
                                                    : person.username,
                                                style: AppTypography.subtitle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 96,
                                        child: Center(
                                          child: person.canFollow
                                              ? SakhiPillButton(
                                                  label: person.isFollowing
                                                      ? 'Following'
                                                      : 'Follow Back',
                                                  isFilled: !person.isFollowing,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 7,
                                                      ),
                                                  onPressed: () =>
                                                      _toggleMemberFollow(
                                                        state,
                                                        person,
                                                      ),
                                                )
                                              : const Text(
                                                  'Unavailable',
                                                  style: AppTypography.subtitle,
                                                ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Member options',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _showMemberOptions(
                                          context,
                                          state,
                                          person,
                                        ),
                                        icon: const Icon(
                                          Icons.more_horiz_rounded,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
