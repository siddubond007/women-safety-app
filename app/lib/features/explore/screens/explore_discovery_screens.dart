import '../../../core/widgets/sakhi_quote_loader.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_avatar.dart';
import '../../../core/widgets/sakhi_card.dart';
import '../../../core/widgets/sakhi_chip.dart';
import '../../../core/widgets/sakhi_empty_state.dart';
import '../../../core/widgets/sakhi_section_header.dart';
import '../../community/widgets/feed_post_card.dart';

Future<void> showCircleMembershipUnavailable(
  BuildContext context,
  String circleName,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Joining circles is not available yet'),
      content: Text(
        '$circleName is available to discover. The current backend does not persist circle memberships, so no join was recorded.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

class SakhiJoinCircleButton extends StatelessWidget {
  const SakhiJoinCircleButton({super.key, required this.circleName});

  final String circleName;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => showCircleMembershipUnavailable(context, circleName),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryPurple,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      child: const Text('Join'),
    );
  }
}

/// Category destination and privacy-aware search destinations used by Explore,
/// Home search, hashtag chips, and the Social Wall search action.
class CategoryDestinationScreen extends StatefulWidget {
  const CategoryDestinationScreen({
    super.key,
    required this.categorySlug,
    required this.title,
  });

  final String categorySlug;
  final String title;

  @override
  State<CategoryDestinationScreen> createState() =>
      _CategoryDestinationScreenState();
}

class _CategoryDestinationScreenState extends State<CategoryDestinationScreen> {
  List<FeedPostModel> _posts = const [];
  bool _loading = true;
  bool _failed = false;

  String get _description => switch (widget.categorySlug) {
    'health_wellness' =>
      'Wellbeing resources, mindful routines, and supportive conversations.',
    'safety_awareness' =>
      'Commute tips, helpline resources, and practical safety awareness.',
    'education_career' =>
      'Mentorship circles, career resources, and skill-sharing for women.',
    _ => 'Discover hobbies, everyday inspiration, and community stories.',
  };

  List<String> get _keywords => switch (widget.categorySlug) {
    'health_wellness' => ['wellness', 'health', 'mindful', 'mental', 'fitness'],
    'safety_awareness' => ['safety', 'commute', 'helpline', 'awareness'],
    'education_career' => [
      'education',
      'career',
      'job',
      'tech',
      'startup',
      'learn',
    ],
    _ => ['lifestyle', 'hobby', 'travel', 'reading', 'art', 'journal'],
  };

  @override
  void initState() {
    super.initState();
    unawaited(_loadCategory());
  }

  Future<void> _loadCategory() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final state = SakhiPrototypeState.instance;
    await state.syncFromBackend();
    final categorySlug = switch (widget.categorySlug) {
      'health_wellness' || 'lifestyle_hobbies' => 'wellness_lifestyle',
      'safety_awareness' => 'safety_awareness',
      _ => 'all',
    };
    final result = await state.fetchPosts(
      categorySlug: categorySlug,
      limit: 30,
    );
    if (!mounted) return;
    final keywordSet = _keywords;
    setState(() {
      _failed = result == null;
      final candidates = result ?? const <FeedPostModel>[];
      _posts =
          widget.categorySlug == 'education_career' ||
              widget.categorySlug == 'lifestyle_hobbies'
          ? candidates
                .where((post) {
                  final searchable =
                      '${post.content} ${post.categoryBadge ?? ''} ${post.categorySlug} ${post.hashtags.join(' ')}'
                          .toLowerCase();
                  return keywordSet.any(searchable.contains);
                })
                .toList(growable: false)
          : candidates;
      _loading = false;
    });
  }

  List<CommunityGroupModel> _matchingGroups(SakhiPrototypeState state) {
    return state.groups
        .where((group) {
          final value = '${group.name} ${group.description} ${group.category}'
              .toLowerCase();
          return _keywords.any(value.contains);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back to Explore',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('${widget.title} Hub', style: AppTypography.appBarTitle),
      ),
      body: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final groups = _matchingGroups(state);
          return RefreshIndicator(
            onRefresh: _loadCategory,
            color: AppColors.primaryPurple,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingH,
                4,
                AppSpacing.screenPaddingH,
                96,
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.heroBannerGradient,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.title} Hub',
                              style: AppTypography.sectionTitle.copyWith(
                                fontSize: 19,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              _description,
                              style: AppTypography.bodyRegular,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 88,
                          height: 88,
                          child: Image.asset(
                            AppAssets.educationCareerHubBanner,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const SakhiSectionHeader(title: 'Featured Circles'),
                const SizedBox(height: 10),
                if (_loading && state.groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SakhiQuoteLoader.inline(
                      statusLabel: 'Discovering active circles near you…',
                    ),
                  )
                else if (groups.isEmpty)
                  SakhiEmptyState(
                    icon: Icons.groups_outlined,
                    title: 'No circles in this category yet',
                    message: state.isBackendSynced
                        ? 'Circles will appear here when the community has relevant groups.'
                        : 'Connect to Sakhi to load real circles from your account.',
                    actionLabel: state.isBackendSynced ? null : 'Retry',
                    onAction: state.isBackendSynced
                        ? null
                        : () => unawaited(state.syncFromBackend()),
                  )
                else
                  ...groups.map(
                    (group) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SakhiCard(
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: AppColors.pastelLavender,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(
                                Icons.groups_rounded,
                                color: AppColors.primaryPurple,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.name,
                                    style: AppTypography.cardTitle,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${group.membersCount} members • ${group.description}',
                                    style: AppTypography.subtitle,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            SakhiJoinCircleButton(circleName: group.name),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                const SakhiSectionHeader(
                  title: 'Top Community Posts & Resources',
                ),
                const SizedBox(height: 10),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(22),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_failed)
                  SakhiEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't refresh latest posts",
                    message:
                        'Your posts could not be loaded from the Sakhi API.',
                    actionLabel: 'Retry',
                    onAction: () => unawaited(_loadCategory()),
                  )
                else if (_posts.isEmpty)
                  SakhiEmptyState(
                    icon: Icons.auto_awesome_outlined,
                    title: 'No posts in ${widget.title} yet',
                    message: 'Be among the first members to share a useful story or resource in this category.',
                  )
                else
                  ..._posts.map(
                    (post) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: FeedPostCard(
                        post: post,
                        onLikeTap: () => state.togglePostLike(post),
                        onSaveTap: () => state.togglePostSaved(post),
                        showVerifiedCheck: true,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late final TextEditingController _controller;
  Timer? _debounce;
  String _activeFilter = 'All';
  List<FeedPostModel> _posts = const [];
  List<FollowerUserModel> _members = const [];
  bool _loading = false;
  bool _failed = false;
  bool _postsUnavailable = false;
  bool _membersUnavailable = false;
  String _requestedQuery = '';

  static const _filters = ['All', 'Posts', 'Members', 'Circles', 'Businesses'];
  static const _starterTopics = [
    '#MentalWellness',
    '#WomenInTech',
    '#SafetyTips',
    '#SmallBusiness',
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    unawaited(SakhiPrototypeState.instance.syncFromBackend());
    if (_controller.text.trim().isNotEmpty) {
      _scheduleSearch(_controller.text, immediate: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSearch(String raw, {bool immediate = false}) {
    _debounce?.cancel();
    final query = raw.trim();
    if (query.isEmpty) {
      setState(() {
        _requestedQuery = '';
        _posts = const [];
        _members = const [];
        _loading = false;
        _failed = false;
        _postsUnavailable = false;
        _membersUnavailable = false;
      });
      return;
    }
    _debounce = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 300),
      () => unawaited(_runSearch(query)),
    );
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _requestedQuery = query;
      _loading = true;
      _failed = false;
      _postsUnavailable = false;
      _membersUnavailable = false;
    });

    final state = SakhiPrototypeState.instance;
    final postsFuture = state.fetchPosts(
      search: query,
      categorySlug: 'all',
      limit: 30,
    );
    final membersFuture = state.searchVisibleMembers(query);
    final postsResult = await postsFuture;
    final membersResult = await membersFuture;

    if (!mounted || query != _controller.text.trim()) return;
    setState(() {
      _posts = postsResult ?? const [];
      _members = membersResult ?? const [];
      _postsUnavailable = postsResult == null;
      _membersUnavailable = membersResult == null;
      _failed = postsResult == null && membersResult == null;
      _loading = false;
    });
  }

  void _openTopic(String topic) {
    _controller.text = topic;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    setState(() => _activeFilter = 'All');
    _scheduleSearch(topic, immediate: true);
  }

  List<FollowerUserModel> _matchingMembers(SakhiPrototypeState state) {
    final query = _requestedQuery.toLowerCase().replaceFirst('#', '');
    if (query.isEmpty) return const [];
    return _members
        .where((member) {
          final searchable = [
            member.name,
            member.username,
            member.bio ?? '',
            ...member.interests,
          ].join(' ').toLowerCase();
          return searchable.contains(query);
        })
        .toList(growable: false);
  }

  List<CommunityGroupModel> _matchingGroups(SakhiPrototypeState state) {
    final query = _requestedQuery.toLowerCase().replaceFirst('#', '');
    if (query.isEmpty) return const [];
    return state.groups
        .where((group) {
          return '${group.name} ${group.description} ${group.category}'
              .toLowerCase()
              .contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    final query = _requestedQuery.toLowerCase().replaceFirst('#', '');
    final posts = _posts
        .where((post) {
          if (query.isEmpty) return false;
          final searchable =
              '${post.content} ${post.authorName} ${post.authorUsername} ${post.categoryBadge ?? ''} ${post.hashtags.join(' ')}'
                  .toLowerCase();
          return searchable.contains(query);
        })
        .toList(growable: false);
    final members = _matchingMembers(state);
    final businessMembers = members
        .where((member) => (member.businessProfileUrl ?? '').trim().isNotEmpty)
        .toList(growable: false);
    final groups = _matchingGroups(state);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Search Sakhi', style: AppTypography.appBarTitle),
      ),
      body: AnimatedBuilder(
        animation: state,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingH,
                4,
                AppSpacing.screenPaddingH,
                12,
              ),
              child: TextField(
                controller: _controller,
                autofocus: widget.initialQuery.isEmpty,
                onChanged: (value) {
                  setState(() {});
                  _scheduleSearch(value);
                },
                textInputAction: TextInputAction.search,
                onSubmitted: (value) => _scheduleSearch(value, immediate: true),
                decoration: InputDecoration(
                  hintText: 'Search people, topics, circles...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _controller.clear();
                            _scheduleSearch('');
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPaddingH,
                ),
                children: _filters.map((filter) {
                  final selected = _activeFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SakhiChip(
                      label: filter,
                      isSelected: selected,
                      onTap: () => setState(() => _activeFilter = filter),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPaddingH,
                  8,
                  AppSpacing.screenPaddingH,
                  96,
                ),
                children: [
                  if (_controller.text.trim().isEmpty) ...[
                    const Text(
                      'Explore topics',
                      style: AppTypography.sectionTitle,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _starterTopics
                          .map(
                            (topic) => SakhiChip(
                              label: topic,
                              onTap: () => _openTopic(topic),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 22),
                    const SakhiEmptyState(
                      icon: Icons.search_rounded,
                      title: 'Find your Sakhi community',
                      message: 'Search visible member profiles and community posts. Results depend on current privacy settings and available community data.',
                    ),
                  ] else if (_loading) ...[
                    const SizedBox(height: 44),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 14),
                    const Center(child: Text('Searching Sakhi...')),
                  ] else if (_failed) ...[
                    SakhiEmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Search is unavailable',
                      message: 'Sakhi could not retrieve results from the connected API. Please try again.',
                      actionLabel: 'Retry',
                      onAction: () =>
                          _scheduleSearch(_controller.text, immediate: true),
                    ),
                  ] else ...[
                    if (_activeFilter == 'All' || _activeFilter == 'Posts') ...[
                      const SakhiSectionHeader(title: 'Posts'),
                      const SizedBox(height: 10),
                      if (_postsUnavailable)
                        SakhiEmptyState(
                          icon: Icons.cloud_off_outlined,
                          title: 'Posts could not be loaded',
                          message: 'Sakhi could not retrieve posts for this search. Your member results may still be available.',
                          actionLabel: 'Retry',
                          onAction: () => _scheduleSearch(
                            _controller.text,
                            immediate: true,
                          ),
                        )
                      else if (posts.isEmpty)
                        const _InlineEmptyResult(
                          text: 'No matching posts were found.',
                        )
                      else
                        ...posts.map(
                          (post) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: FeedPostCard(
                              post: post,
                              onLikeTap: () => state.togglePostLike(post),
                              onSaveTap: () => state.togglePostSaved(post),
                              showVerifiedCheck: true,
                            ),
                          ),
                        ),
                    ],
                    if (_activeFilter == 'All' ||
                        _activeFilter == 'Members') ...[
                      const SakhiSectionHeader(title: 'Visible Members'),
                      const SizedBox(height: 10),
                      if (_membersUnavailable)
                        const _InlineEmptyResult(
                          text: 'Verified member search is unavailable. Retry to load current privacy-filtered results.',
                        )
                      else if (members.isEmpty)
                        const _InlineEmptyResult(
                          text: 'No visible, verified member profiles matched this search.',
                        )
                      else
                        ...members.map(
                          (member) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(
                                    color: AppColors.borderSubtle,
                                  ),
                                ),
                                leading: SakhiAvatar(
                                  imageAsset: member.avatarAsset,
                                  fallbackLabel: member.name,
                                  size: 46,
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        member.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.cardTitle,
                                      ),
                                    ),
                                    if (member.isVerified) ...[
                                      const SizedBox(width: 5),
                                      const Icon(
                                        Icons.verified_rounded,
                                        size: 16,
                                        color: AppColors.primaryPurple,
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  [
                                    member.username,
                                    if (member.bio?.trim().isNotEmpty == true)
                                      member.bio!.trim(),
                                  ].join(' • '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        SearchResultMemberProfileScreen(
                                          member: member,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                    if (_activeFilter == 'All' ||
                        _activeFilter == 'Circles') ...[
                      const SizedBox(height: 12),
                      const SakhiSectionHeader(title: 'Circles'),
                      const SizedBox(height: 10),
                      if (groups.isEmpty)
                        const _InlineEmptyResult(
                          text: 'No matching circles were found.',
                        )
                      else
                        ...groups.map(
                          (group) => SakhiCard(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.pastelLavender,
                                child: Icon(
                                  Icons.groups_rounded,
                                  color: AppColors.primaryPurple,
                                ),
                              ),
                              title: Text(group.name),
                              subtitle: Text(
                                '${group.membersCount} members • ${group.description}',
                              ),
                            ),
                          ),
                        ),
                    ],
                    if (_activeFilter == 'Businesses') ...[
                      const SakhiSectionHeader(
                        title: 'Linked Women-Owned Businesses',
                      ),
                      const SizedBox(height: 10),
                      if (_membersUnavailable)
                        const _InlineEmptyResult(
                          text: 'Business search is unavailable. Retry to load privacy-filtered profiles.',
                        )
                      else if (businessMembers.isEmpty)
                        const _InlineEmptyResult(
                          text: 'No verified member with a linked business profile matched this search.',
                        )
                      else
                        ...businessMembers.map(
                          (member) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SakhiCard(
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: AppColors.pastelLavender,
                                  child: Icon(
                                    Icons.storefront_outlined,
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                                title: Text(
                                  (member.businessProfileName ?? '')
                                          .trim()
                                          .isNotEmpty
                                      ? member.businessProfileName!
                                      : 'Linked business profile',
                                  style: AppTypography.cardTitle,
                                ),
                                subtitle: Text(
                                  '${member.businessCategory ?? 'Women-owned business'} • ${member.name}',
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        SearchResultMemberProfileScreen(
                                          member: member,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchResultMemberProfileScreen extends StatefulWidget {
  const SearchResultMemberProfileScreen({super.key, required this.member});

  final FollowerUserModel member;

  @override
  State<SearchResultMemberProfileScreen> createState() =>
      _SearchResultMemberProfileScreenState();
}

class _SearchResultMemberProfileScreenState
    extends State<SearchResultMemberProfileScreen> {
  bool _updatingFollow = false;

  Future<void> _toggleFollow() async {
    if (_updatingFollow || !widget.member.canFollow) return;
    setState(() => _updatingFollow = true);
    final succeeded = await SakhiPrototypeState.instance
        .toggleFollowSearchMember(widget.member);
    if (!mounted) return;
    setState(() => _updatingFollow = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded
              ? (widget.member.isFollowing
                    ? 'You are now following ${widget.member.name}.'
                    : 'You unfollowed ${widget.member.name}.')
              : 'Follow could not be updated. No change was kept.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final businessUrl = (member.businessProfileUrl ?? '').trim();
    final interests = member.interests;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        title: const Text('Member Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPaddingH,
          16,
          AppSpacing.screenPaddingH,
          96,
        ),
        children: [
          SakhiCard(
            child: Column(
              children: [
                const SizedBox(height: 12),
                SakhiAvatar(
                  imageAsset: member.avatarAsset,
                  fallbackLabel: member.name,
                  size: 104,
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        textAlign: TextAlign.center,
                        style: AppTypography.sectionTitle,
                      ),
                    ),
                    if (member.isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        color: AppColors.primaryPurple,
                        size: 20,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  member.username,
                  style: AppTypography.subtitle,
                  textAlign: TextAlign.center,
                ),
                if (member.isVerified) ...[
                  const SizedBox(height: 8),
                  const Chip(
                    avatar: Icon(
                      Icons.shield_rounded,
                      size: 16,
                      color: Color(0xFF1E7E52),
                    ),
                    label: Text('Verified member'),
                    backgroundColor: Color(0xFFE6F6EE),
                    side: BorderSide.none,
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: member.canFollow
                      ? FilledButton(
                          onPressed: _updatingFollow ? null : _toggleFollow,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            foregroundColor: Colors.white,
                          ),
                          child: _updatingFollow
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  member.isFollowing ? 'Following' : '+ Follow',
                                ),
                        )
                      : const OutlinedButton(
                          onPressed: null,
                          child: Text('Follow unavailable'),
                        ),
                ),
                if (!member.canFollow) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'This member does not yet have a followable community-directory profile.',
                    textAlign: TextAlign.center,
                    style: AppTypography.subtitle,
                  ),
                ],
              ],
            ),
          ),
          if ((member.bio ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            SakhiCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('About', style: AppTypography.sectionTitle),
                  const SizedBox(height: 8),
                  Text(member.bio!.trim(), style: AppTypography.bodyRegular),
                ],
              ),
            ),
          ],
          if (interests.isNotEmpty) ...[
            const SizedBox(height: 14),
            SakhiCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Interests', style: AppTypography.sectionTitle),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: interests
                        .map((interest) => SakhiChip(label: interest))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
          if (businessUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            SakhiCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Linked Business Profile',
                    style: AppTypography.sectionTitle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (member.businessProfileName ?? '').trim().isNotEmpty
                        ? member.businessProfileName!
                        : 'Women-owned business',
                    style: AppTypography.cardTitle,
                  ),
                  if ((member.businessCategory ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      member.businessCategory!,
                      style: AppTypography.subtitle,
                    ),
                  ],
                  const SizedBox(height: 6),
                  const Text(
                    'A business link is recorded on this member profile. External business navigation is not part of this mobile flow.',
                    style: AppTypography.subtitle,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineEmptyResult extends StatelessWidget {
  const _InlineEmptyResult({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(text, style: AppTypography.subtitle),
    );
  }
}
