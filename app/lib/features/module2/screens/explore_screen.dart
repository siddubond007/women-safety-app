import 'package:flutter/material.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_chip.dart';
import '../../../core/widgets/sakhi_search_field.dart';
import '../../../core/widgets/sakhi_section_header.dart';
import '../../../core/constants/mock_data.dart';
import '../widgets/module2_feature_widgets.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, this.onNavigateRoute});
  final ValueChanged<String>? onNavigateRoute;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'All';
  String? _topic;
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigate(String route) {
    final handler = widget.onNavigateRoute;
    if (handler != null) {
      handler(route);
    } else {
      Navigator.of(context).pushNamed(route);
    }
  }

  Future<void> _search(String value) async {
    final state = SakhiPrototypeState.instance;
    state.searchQuery = value.trim();
    await Future.wait([
      state.loadDiscover(query: value),
      state.loadFeed(query: value),
      state.backend?.loadGroups(query: value) ?? Future<bool>.value(false),
      state.backend?.loadEvents(query: value) ?? Future<bool>.value(false),
      state.backend?.loadExperts(query: value) ?? Future<bool>.value(false),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final query = _searchController.text.trim().toLowerCase();
        final posts = state.communityPosts.where((post) {
          final textMatches = query.isEmpty ||
              post.content.toLowerCase().contains(query) ||
              post.authorName.toLowerCase().contains(query);
          final topicMatches = _topic == null ||
              post.content.toLowerCase().contains(_topic!.replaceAll('#', '').toLowerCase());
          return textMatches && topicMatches;
        }).toList();
        final members = state.backend?.discoveredMembers ?? [];
        return Module2PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(child: Module2PageTitle('Explore', subtitle: 'Discover verified Sakhi members and community content')),
                IconButton(
                  tooltip: 'Search Explore',
                  onPressed: () => setState(() => _showSearch = !_showSearch),
                  icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded, color: AppColors.primaryPurple),
                ),
              ]),
              if (_showSearch) ...[
                const SizedBox(height: 8),
                SakhiSearchField(
                  hintText: 'Search people, topics and posts...',
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: _search,
                  onClear: () {
                    _searchController.clear();
                    setState(() => _topic = null);
                    _search('');
                  },
                ),
              ],
              const SizedBox(height: 13),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: state.exploreFilters.map((filter) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SakhiChip(
                      label: filter,
                      isSelected: _filter == filter,
                      onTap: () {
                        setState(() => _filter = filter);
                        if (filter == 'Posts') _search(_searchController.text);
                      },
                    ),
                  )).toList(),
                ),
              ),
              if (_filter == 'All' || _filter == 'Posts') ...[
                const SizedBox(height: 22),
                const SakhiSectionHeader(title: 'Trending Topics'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: state.trendingHashtags.map((tag) => SakhiChip(
                    label: tag,
                    isSelected: _topic == tag,
                    onTap: () {
                      setState(() => _topic = _topic == tag ? null : tag);
                      _search(_searchController.text);
                    },
                  )).toList(),
                ),
              ],
              if (_filter == 'All') ...[
                const SizedBox(height: 22),
                const SakhiSectionHeader(title: 'Explore by category'),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 11,
                  crossAxisSpacing: 11,
                  childAspectRatio: 2.0,
                  children: [
                    _ExploreCategory(label: 'Health & Wellness', icon: Icons.favorite_border_rounded, tint: AppColors.pastelBlue, onTap: () => _navigate(AppRoutes.wellness)),
                    _ExploreCategory(label: 'Safety & Awareness', icon: Icons.shield_outlined, tint: AppColors.pastelPeach, onTap: () => _navigate(AppRoutes.safety)),
                    _ExploreCategory(label: 'Education & Career', icon: Icons.school_outlined, tint: AppColors.pastelMint, onTap: () { setState(() { _filter = 'Experts'; _topic = '#CareerGrowth'; }); }),
                    _ExploreCategory(label: 'Lifestyle & Hobbies', icon: Icons.palette_outlined, tint: AppColors.pastelLavender, onTap: () { setState(() { _filter = 'Posts'; _topic = '#SelfCare'; }); }),
                  ],
                ),
              ],
              if (_filter == 'All') ...[
                const SizedBox(height: 22),
                SakhiSectionHeader(
                  title: _filter == 'Experts' ? 'Verified member profiles' : 'Recommended for you',
                  actionLabel: 'See all',
                  onActionTap: () => _navigate(AppRoutes.followers),
                ),
                const SizedBox(height: 10),
                if (state.backend?.isLoadingMembers == true)
                  const Center(child: Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator()))
                else if (members.isEmpty)
                  const Module2EmptyPanel(
                    icon: Icons.people_outline_rounded,
                    title: 'No member profiles to show yet',
                    message: 'Profiles from active, verified Sakhi members will appear here when they are discoverable.',
                  )
                else
                  ...members.take(4).map((member) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.borderSubtle), borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        CircleAvatar(
                          backgroundColor: AppColors.pastelLavender,
                          child: Text(member.displayName.isNotEmpty ? member.displayName.substring(0, 1).toUpperCase() : 'S', style: const TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(member.displayName, style: AppTypography.cardTitle.copyWith(fontSize: 13)),
                          Text(member.bio ?? 'Verified Sakhi member', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.subtitle),
                        ])),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => state.toggleFollow(member.accountId),
                          child: Text(member.isFollowing ? 'Following' : 'Follow'),
                        ),
                      ]),
                    ),
                  )),
              ],
              if (_filter == 'All' || _filter == 'Posts') ...[
                const SizedBox(height: 22),
                SakhiSectionHeader(title: _filter == 'Posts' ? 'Matching posts' : 'Recommended posts', actionLabel: 'See all', onActionTap: () => _navigate(AppRoutes.community)),
                const SizedBox(height: 10),
                if (state.backend?.isLoadingFeed == true)
                  const Center(child: Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator()))
                else if (posts.isEmpty)
                  Module2EmptyPanel(
                    icon: Icons.forum_outlined,
                    title: 'No posts to show',
                    message: query.isNotEmpty || _topic != null ? 'No visible posts match your current filters.' : 'Posts from active, verified members will appear here.',
                    actionLabel: 'Open Community',
                    onAction: () => _navigate(AppRoutes.community),
                  )
                else
                  ...posts.take(4).map((post) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Module2FeedPostCard(
                      post: post,
                      state: state,
                      onAuthorTap: () => _navigate(AppRoutes.profile),
                      onComment: () => _navigate(AppRoutes.community),
                      onMore: () => _reportPost(post.authorAccountId, post.id),
                    ),
                  )),
              ],
              if (_filter == 'Groups' || _filter == 'Events')
                const Module2EmptyPanel(
                  icon: Icons.groups_2_outlined,
                  title: 'Nothing published yet',
                  message: 'There are no published items in this category for your account yet.',
                ),
              if (_filter == 'Groups') ...[
                const SizedBox(height: 22),
                const SakhiSectionHeader(title: 'Discover groups'),
                const SizedBox(height: 10),
                if (state.backend?.isLoadingMembers == true)
                  const Center(child: Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator()))
                else if ((state.backend?.discoverGroups ?? []).isEmpty)
                  Module2EmptyPanel(
                    icon: Icons.groups_outlined,
                    title: 'No discoverable groups yet',
                    message: 'Verified members can create groups from My Groups. Public groups will appear here; private groups only appear for members with access.',
                    actionLabel: 'Open My Groups',
                    onAction: () => _navigate(AppRoutes.groups),
                  )
                else
                  ...state.backend!.discoverGroups.take(8).map((group) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderSubtle)),
                      child: Row(children: [
                        Container(width: 43, height: 43, decoration: const BoxDecoration(color: AppColors.pastelLavender, shape: BoxShape.circle), child: const Icon(Icons.groups_rounded, color: AppColors.primaryPurple)),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(group.name, style: AppTypography.cardTitle.copyWith(fontSize: 13)),
                          Text('${group.memberCount} members · ${group.visibility == 'PRIVATE' ? 'Private' : 'Verified members'}', style: AppTypography.subtitle),
                        ])),
                        OutlinedButton(
                          onPressed: () async {
                            final ok = group.membershipStatus == 'ACTIVE' || group.membershipStatus == 'PENDING'
                                ? await state.backend!.leaveGroup(group)
                                : await state.backend!.joinGroup(group);
                            if (mounted && !ok) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.backend?.errorMessage ?? 'Membership update failed.')));
                          },
                          child: Text(group.membershipStatus == 'PENDING' ? 'Pending' : (group.membershipStatus == 'ACTIVE' ? 'Joined' : 'Join')),
                        ),
                      ]),
                    ),
                  )),
              ],
              if (_filter == 'Events') ...[
                const SizedBox(height: 22),
                const SakhiSectionHeader(title: 'Upcoming events'),
                const SizedBox(height: 10),
                if ((state.backend?.upcomingEvents ?? []).isEmpty)
                  const Module2EmptyPanel(
                    icon: Icons.event_available_outlined,
                    title: 'No upcoming events',
                    message: 'Published events from active Sakhi groups will appear here.',
                  )
                else
                  ...state.backend!.upcomingEvents.map((event) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderSubtle)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(event.title, style: AppTypography.cardTitle),
                        const SizedBox(height: 4),
                        Text(event.groupName, style: AppTypography.subtitle),
                        if (event.startsAt != null) Text(event.startsAt!.toLocal().toString().split('.').first, style: AppTypography.subtitle),
                        const SizedBox(height: 8),
                        Text(event.description, style: AppTypography.bodyRegular.copyWith(fontSize: 13)),
                        Align(alignment: Alignment.centerRight, child: OutlinedButton(
                          onPressed: () => state.backend!.registerForEvent(event, register: !event.isRegistered),
                          child: Text(event.isRegistered ? 'Cancel registration' : 'Register'),
                        )),
                      ]),
                    ),
                  )),
              ],
              if (_filter == 'Experts') ...[
                const SizedBox(height: 22),
                const SakhiSectionHeader(title: 'Verified business profiles'),
                const SizedBox(height: 10),
                if ((state.backend?.verifiedExperts ?? []).isEmpty)
                  const Module2EmptyPanel(
                    icon: Icons.workspace_premium_outlined,
                    title: 'No verified expert profiles yet',
                    message: 'Only business profiles that have completed review will appear here.',
                  )
                else
                  ...state.backend!.verifiedExperts.map((expert) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderSubtle)),
                      child: Row(children: [
                        CircleAvatar(backgroundColor: AppColors.pastelMint, child: Text(expert.businessName.isNotEmpty ? expert.businessName.substring(0, 1).toUpperCase() : 'E', style: const TextStyle(color: AppColors.wellnessGreen, fontWeight: FontWeight.w800))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(expert.businessName, style: AppTypography.cardTitle.copyWith(fontSize: 13)),
                          Text(expert.description ?? expert.displayName, style: AppTypography.subtitle),
                        ])),
                      ]),
                    ),
                  )),
              ],
              if (state.backend?.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(state.backend!.errorMessage!, style: const TextStyle(color: AppColors.sosRed, fontSize: 12)),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _reportPost(String accountId, String postId) async {
    if (accountId.isEmpty) return;
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Report this post'),
            onTap: () => Navigator.pop(context, 'report'),
          ),
          ListTile(
            leading: const Icon(Icons.block_rounded),
            title: const Text('Block this member'),
            onTap: () => Navigator.pop(context, 'block'),
          ),
        ]),
      ),
    );
    if (!mounted || result == null) return;
    final state = SakhiPrototypeState.instance;
    if (result == 'report') {
      await state.reportMember(accountId: accountId, postId: postId, reason: 'UNSAFE_CONTENT');
    } else {
      final member = state.backend?.discoveredMembers.where((m) => m.accountId == accountId).toList();
      if (member != null && member.isNotEmpty) await state.backend?.blockMember(member.first);
    }
  }
}

class _ExploreCategory extends StatelessWidget {
  const _ExploreCategory({required this.label, required this.icon, required this.tint, required this.onTap});
  final String label;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: AppColors.primaryPurple, size: 21),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
        ]),
      ),
    ),
  );
}
