import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/mock_data.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_search_field.dart';
import '../widgets/module2_feature_widgets.dart';

class FollowersFollowingScreen extends StatefulWidget {
  const FollowersFollowingScreen({super.key, this.onOpenMember});

  final ValueChanged<String>? onOpenMember;

  @override
  State<FollowersFollowingScreen> createState() => _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _showFollowing = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _openMember(String accountId) {
    if (accountId.isEmpty) return;
    final handler = widget.onOpenMember;
    if (handler != null) {
      handler(accountId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member profile navigation is unavailable in this preview.')),
      );
    }
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      SakhiPrototypeState.instance.loadFollowers(
        showFollowing: _showFollowing,
        query: value,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final members = _showFollowing ? state.following : state.followers;
        return Module2PageBody(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Module2PageTitle('Followers & Following', subtitle: 'Manage your connections with verified members'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.pastelLavender, borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
              child: Row(children: [
                _FilterTab(label: 'Followers', selected: !_showFollowing, onTap: () async {
                  setState(() => _showFollowing = false);
                  await state.loadFollowers(showFollowing: false, query: _searchController.text);
                }),
                _FilterTab(label: 'Following', selected: _showFollowing, onTap: () async {
                  setState(() => _showFollowing = true);
                  await state.loadFollowers(showFollowing: true, query: _searchController.text);
                }),
              ]),
            ),
            const SizedBox(height: 12),
            SakhiSearchField(
              hintText: _showFollowing ? 'Search people you follow...' : 'Search followers...',
              controller: _searchController,
              onChanged: _search,
              onSubmitted: (value) => state.loadFollowers(showFollowing: _showFollowing, query: value),
              onClear: () {
                _searchController.clear();
                state.loadFollowers(showFollowing: _showFollowing);
              },
            ),
            const SizedBox(height: 12),
            if (state.backend?.isLoadingMembers == true)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (members.isEmpty)
              Module2EmptyPanel(
                icon: Icons.people_outline_rounded,
                title: _showFollowing ? 'You are not following anyone yet' : 'No followers match this view',
                message: _showFollowing
                    ? 'Discover verified members and follow people whose updates you want to see.'
                    : 'When verified members follow you, their profiles will appear here.',
                actionLabel: 'Explore members',
                onAction: () => Navigator.of(context).pushNamed(AppRoutes.explore),
              )
            else
              ...members.map((person) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderSubtle)),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.pastelLavender,
                      child: Text(person.name.isNotEmpty ? person.name.substring(0, 1).toUpperCase() : 'S', style: const TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 11),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(person.name, style: AppTypography.cardTitle.copyWith(fontSize: 13)),
                      if ((person.bio ?? '').isNotEmpty)
                        Text(person.bio!, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.subtitle),
                    ])),
                    const SizedBox(width: 8),
                    if (_showFollowing) ...[
                      IconButton(
                        tooltip: 'View member profile',
                        onPressed: () => _openMember(person.id),
                        icon: const Icon(Icons.person_outline_rounded),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final member = state.backend?.following.where((entry) => entry.accountId == person.id).toList();
                          if (member == null || member.isEmpty) return;
                          final ok = await state.backend!.setFollowing(member.first, false);
                          if (ok && mounted) await state.loadFollowers(showFollowing: true, query: _searchController.text);
                        },
                        child: const Text('Following'),
                      ),
                    ] else
                      OutlinedButton(
                        onPressed: () => _openMember(person.id),
                        child: const Text('View'),
                      ),
                  ]),
                ),
              )),
            if (state.backend?.errorMessage != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(state.backend!.errorMessage!, style: const TextStyle(color: AppColors.sosRed, fontSize: 12))),
          ]),
        );
      },
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: selected ? AppColors.primaryPurple : Colors.transparent, borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5)),
      ),
    ),
  );
}
