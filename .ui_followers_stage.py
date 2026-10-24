from pathlib import Path
p=Path(r"D:\Development\Projects\women_safety_app\app\lib\features\followers\screens\followers_following_screen.dart")
s=p.read_text(encoding="utf-8")
def one(old,new,label):
 global s
 n=s.count(old)
 if n!=1: raise SystemExit(f"{label}: expected 1 match, got {n}")
 s=s.replace(old,new,1)
one("""class FollowersFollowingScreen extends StatefulWidget {
  const FollowersFollowingScreen({super.key});

  @override
  State<FollowersFollowingScreen> createState() =>
      _FollowersFollowingScreenState();
}""","""class FollowersFollowingScreen extends StatefulWidget {
  const FollowersFollowingScreen({super.key, this.initialFollowing = false});

  final bool initialFollowing;

  @override
  State<FollowersFollowingScreen> createState() =>
      _FollowersFollowingScreenState();
}""","constructor")
one("""  bool _showingFollowingOnly = false;

  @override
  void dispose() {""","""  bool _showingFollowingOnly = false;
  final Set<String> _mutedMemberIds = <String>{};

  @override
  void initState() {
    super.initState();
    _showingFollowingOnly = widget.initialFollowing;
  }

  @override
  void dispose() {""","init state")
one("""            final filtered = state.followers.where((u) {
              if (_showingFollowingOnly && !u.isFollowing) return false;""","""            final filtered = state.followers.where((u) {
              if (_mutedMemberIds.contains(u.id)) return false;
              if (_showingFollowingOnly && !u.isFollowing) return false;""","muted filtering")
one("""                                      SizedBox(
                                        width: 104,
                                        child: Center(
                                          child: SakhiPillButton(
                                            label: person.isFollowing
                                                ? 'Following'
                                                : 'Follow',
                                            isFilled: person.isFollowing,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 7,
                                            ),
                                            onPressed: () =>
                                                state.toggleFollow(person.id),
                                          ),
                                        ),
                                      ),""","""                                      IconButton(
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
                                      SizedBox(
                                        width: 92,
                                        child: Center(
                                          child: SakhiPillButton(
                                            label: person.isFollowing
                                                ? 'Following'
                                                : 'Follow Back',
                                            isFilled: person.isFollowing,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 7,
                                            ),
                                            onPressed: () =>
                                                state.toggleFollow(person.id),
                                          ),
                                        ),
                                      ),""","member action row")
one("""  @override
  Widget build(BuildContext context) {""","""  void _showMemberOptions(
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
              const SizedBox(height: 16),
              const Text('Member Options', style: AppTypography.sectionTitle),
              const SizedBox(height: 3),
              Text(
                '${member.name} (${member.username})',
                style: AppTypography.subtitle,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.mark_chat_unread_outlined),
                title: const Text('Manage Message Permission'),
                subtitle: const Text('Message permissions are not available in the current API.'),
                onTap: () => _showUnavailableAction(sheetContext, 'Message permissions'),
              ),
              ListTile(
                leading: const Icon(Icons.person_remove_alt_1_outlined),
                title: const Text('Remove from Followers'),
                subtitle: const Text('This action needs a follower-removal API.'),
                onTap: () => _showUnavailableAction(sheetContext, 'Remove from followers'),
              ),
              ListTile(
                leading: Icon(
                  _mutedMemberIds.contains(member.id)
                      ? Icons.volume_up_outlined
                      : Icons.volume_off_outlined,
                ),
                title: Text(
                  _mutedMemberIds.contains(member.id) ? 'Unmute Posts' : 'Mute Posts',
                ),
                onTap: () {
                  setState(() {
                    if (!_mutedMemberIds.add(member.id)) {
                      _mutedMemberIds.remove(member.id);
                    }
                  });
                  Navigator.of(sheetContext).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.block_rounded, color: AppColors.sosRed),
                title: Text(
                  'Block ${member.username}',
                  style: const TextStyle(color: AppColors.sosRed),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text('Block ${member.username}?'),
                      content: const Text(
                        'You can manage blocked members in Sakhi Settings. Blocking should only be considered successful when the connected API confirms it.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
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
                    state.toggleBlockedUser(
                      username: member.username,
                      displayName: member.name,
                      accountId: member.id,
                    );
                    setState(() {});
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: AppColors.sosRed),
                title: const Text(
                  'Report Inappropriate Behaviour or Harassment',
                  style: TextStyle(color: AppColors.sosRed),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showReportDialog(context, state, member);
                },
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Cancel'),
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
          '\$action needs a backend API that is not currently implemented. No change was made.',
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
                value: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: const [
                  DropdownMenuItem(value: 'Harassment', child: Text('Harassment')),
                  DropdownMenuItem(value: 'Impersonation / Fake Profile', child: Text('Impersonation / Fake Profile')),
                  DropdownMenuItem(value: 'Spam', child: Text('Spam')),
                  DropdownMenuItem(value: 'Unsafe Content', child: Text('Unsafe Content')),
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
      await state.reportMember(
        accountId: member.id,
        reportedAccountId: member.id,
        reason: reason,
        reasonCode: reason.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
        details: noteController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted to Sakhi for review.')),
        );
      }
    }
    noteController.dispose();
  }

  @override
  Widget build(BuildContext context) {""","build method")
p.write_text(s,encoding="utf-8",newline="")
print("Followers/following UI extended with options sheet")
