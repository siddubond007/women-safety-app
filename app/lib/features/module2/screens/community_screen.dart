import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_dialogs.dart';
import '../../../core/widgets/sakhi_search_field.dart';
import '../module2_scope.dart';
import '../widgets/module2_feature_widgets.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({
    super.key,
    this.onNavigateRoute,
    this.onOpenMember,
  });
  final ValueChanged<String>? onNavigateRoute;
  final ValueChanged<String>? onOpenMember;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'For You';
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

  Future<void> _search(String query) async {
    await SakhiPrototypeState.instance.loadFeed(query: query);
  }

  Future<void> _chooseFilter() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Choose your feed', style: AppTypography.sectionTitle),
            const SizedBox(height: 10),
            for (final filter in const ['For You', 'Following', 'Wellness'])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_filterIcon(filter), color: AppColors.primaryPurple),
                title: Text(filter),
                trailing: _filter == filter ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryPurple) : null,
                onTap: () => Navigator.of(context).pop(filter),
              ),
          ]),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _filter = selected);
    if (selected == 'Following') {
      await SakhiPrototypeState.instance.loadFollowers(showFollowing: true);
    } else {
      await _search(_searchController.text);
    }
  }

  IconData _filterIcon(String value) => switch (value) {
    'Following' => Icons.people_alt_outlined,
    'Wellness' => Icons.spa_outlined,
    _ => Icons.auto_awesome_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final followIds = (state.backend?.following ?? []).map((member) => member.accountId).toSet();
        var posts = state.communityPosts.where((post) {
          final query = _searchController.text.trim().toLowerCase();
          return query.isEmpty ||
              post.content.toLowerCase().contains(query) ||
              post.authorName.toLowerCase().contains(query);
        }).toList();
        if (_filter == 'Following') {
          posts = posts.where((post) => followIds.contains(post.authorAccountId) || post.isOwnPost).toList();
        } else if (_filter == 'Wellness') {
          posts = posts.where((post) {
            final text = post.content.toLowerCase();
            return text.contains('wellness') || text.contains('breath') || text.contains('meditat') || text.contains('self-care');
          }).toList();
        }
        return Module2PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: _chooseFilter,
                  child: Row(children: [
                    const Text('Community', style: AppTypography.appBarTitle),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryPurple),
                  ]),
                )),
                GestureDetector(
                  onTap: _chooseFilter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppSpacing.radiusPill), border: Border.all(color: AppColors.borderSubtle)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_filter, style: AppTypography.chipLabel.copyWith(fontSize: 12)),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.primaryPurple),
                    ]),
                  ),
                ),
                IconButton(
                  tooltip: _showSearch ? 'Close search' : 'Search community',
                  onPressed: () => setState(() => _showSearch = !_showSearch),
                  icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded, color: AppColors.primaryPurple),
                ),
              ]),
              if (_showSearch) ...[
                const SizedBox(height: 8),
                SakhiSearchField(
                  hintText: 'Search community posts...',
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: _search,
                  onClear: () {
                    _searchController.clear();
                    setState(() {});
                    _search('');
                  },
                ),
              ],
              const SizedBox(height: 13),
              if (state.backend?.isLoadingFeed == true)
                const Center(child: Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator())),
              if (posts.isEmpty && state.backend?.isLoadingFeed != true)
                Module2EmptyPanel(
                  icon: Icons.forum_outlined,
                  title: _filter == 'Following' ? 'No posts from followed members yet' : 'Your community feed is waiting',
                  message: _filter == 'Following'
                      ? 'Follow verified members from Explore to see their new posts here.'
                      : 'Posts written by active, verified Sakhi members will appear here. You can create your first post with the + button below.',
                  actionLabel: _filter == 'Following' ? 'Explore members' : 'Create post',
                  onAction: _filter == 'Following' ? () => _navigate(AppRoutes.explore) : _openCreatePost,
                ),
              for (var index = 0; index < posts.length; index++) ...[
                Module2FeedPostCard(
                  key: ValueKey(posts[index].id),
                  post: posts[index],
                  state: state,
                  onComment: () => _openComments(posts[index].id),
                  onAuthorTap: () => _openMember(posts[index].authorAccountId),
                  onMore: () => _showPostActions(posts[index].authorAccountId, posts[index].id),
                ),
                const SizedBox(height: 12),
                if (index == 0) ...[
                  _BreathingExerciseBanner(onTap: () => _navigate(AppRoutes.wellness)),
                  const SizedBox(height: 12),
                ],
              ],
              if (state.backend?.errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(state.backend!.errorMessage!, style: const TextStyle(color: AppColors.sosRed, fontSize: 12)),
              ],
            ],
          ),
        );
      },
    );
  }

  void _openCreatePost() {
    Module2Scope.of(context).onOpenCreatePost();
  }

  Future<void> _openComments(String postId) async {
    await SakhiPrototypeState.instance.loadComments(postId);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _PostCommentsSheet(postId: postId),
    );
  }

  Future<void> _showPostActions(String accountId, String postId) async {
    if (accountId.isEmpty) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(child: Wrap(children: [
        ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('Report this post'), onTap: () => Navigator.pop(context, 'report')),
        ListTile(leading: const Icon(Icons.block_rounded), title: const Text('Block this member'), onTap: () => Navigator.pop(context, 'block')),
      ])),
    );
    if (!mounted || action == null) return;
    final state = SakhiPrototypeState.instance;
    if (action == 'report') {
      final success = await state.reportMember(
        accountId: accountId,
        postId: postId,
        reason: 'UNSAFE_CONTENT',
      );
      if (!mounted) return;
      SakhiDialogs.showPrototypeSnackbar(
        context,
        success
            ? 'Report submitted for review.'
            : (state.backend?.errorMessage ?? 'Report could not be submitted.'),
      );
    } else {
      final members = state.backend?.discoveredMembers
              .where((member) => member.accountId == accountId)
              .toList() ??
          [];
      final success = await state.backend?.blockMemberByAccountId(
            accountId,
            displayName: members.isNotEmpty ? members.first.displayName : null,
          ) ??
          false;
      if (!mounted) return;
      SakhiDialogs.showPrototypeSnackbar(
        context,
        success
            ? (state.backend?.actionMessage ?? 'Member blocked.')
            : (state.backend?.errorMessage ?? 'Member could not be blocked.'),
      );
    }
  }
}

class _BreathingExerciseBanner extends StatelessWidget {
  const _BreathingExerciseBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.pastelLavender,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              AppAssets.breathingExerciseIllustration,
              width: 86,
              height: 76,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(width: 86, height: 76, child: Icon(Icons.spa_rounded, color: AppColors.primaryPurple, size: 40)),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Breathing Exercises', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryPurple, fontSize: 13)),
            SizedBox(height: 4),
            Text('Short guided routines to help you pause and reset.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.3)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: AppColors.primaryPurple),
        ]),
      ),
    ),
  );
}

class _PostCommentsSheet extends StatefulWidget {
  const _PostCommentsSheet({required this.postId});
  final String postId;

  @override
  State<_PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends State<_PostCommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    final success = await SakhiPrototypeState.instance.addComment(widget.postId, _controller.text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (success) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final comments = state.backend?.commentsByPost[widget.postId] ?? [];
        return Padding(
          padding: EdgeInsets.only(left: 18, right: 18, top: 18, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * .68,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Comments', style: AppTypography.sectionTitle),
              const SizedBox(height: 12),
              Expanded(
                child: comments.isEmpty
                    ? const Module2EmptyPanel(icon: Icons.chat_bubble_outline_rounded, title: 'No comments yet', message: 'Be the first to add a helpful or supportive comment.')
                    : ListView.separated(
                        itemCount: comments.length,
                        separatorBuilder: (_, __) => const Divider(height: 14),
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            CircleAvatar(radius: 16, backgroundColor: AppColors.pastelLavender, child: Text(comment.authorName.isNotEmpty ? comment.authorName.substring(0, 1).toUpperCase() : 'S', style: const TextStyle(fontSize: 11, color: AppColors.primaryPurple))),
                            const SizedBox(width: 9),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(comment.authorName, style: AppTypography.cardTitle.copyWith(fontSize: 12)),
                              const SizedBox(height: 3),
                              Text(comment.body, style: AppTypography.bodyRegular.copyWith(fontSize: 13)),
                            ])),
                            if (comment.isOwnComment)
                              IconButton(
                                tooltip: 'Delete comment',
                                onPressed: () => state.removeComment(widget.postId, comment.id),
                                icon: const Icon(Icons.delete_outline_rounded, size: 19),
                              ),
                          ]);
                        },
                      ),
              ),
              Row(children: [
                Expanded(child: TextField(controller: _controller, minLines: 1, maxLines: 3, decoration: const InputDecoration(hintText: 'Add a comment...'))),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _sending ? null : _send, icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded)),
              ]),
              if (state.backend?.errorMessage != null)
                Padding(padding: const EdgeInsets.only(top: 6), child: Text(state.backend!.errorMessage!, style: const TextStyle(color: AppColors.sosRed, fontSize: 12))),
            ]),
          ),
        );
      },
    );
  }
}
