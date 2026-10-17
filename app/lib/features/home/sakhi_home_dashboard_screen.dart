import 'package:flutter/material.dart';

import '../../core/branding/app_brand.dart';
import '../../core/theme/sakhi_design_system.dart';
import '../auth/auth_service.dart';
import '../auth/backend_api_client.dart';
import '../auth/sakhi_login_screen.dart';

/// Authenticated Sakhi presentation shell, adapted from the supplied
/// 12-screen prototype. Sample content and preference edits stay in memory;
/// this widget does not pretend that missing social/settings services are live.
class SakhiHomeDashboardScreen extends StatefulWidget {
  const SakhiHomeDashboardScreen({
    super.key,
    required this.authService,
    this.loadDisplayName,
  });

  final AuthService authService;
  final Future<String?> Function()? loadDisplayName;

  @override
  State<SakhiHomeDashboardScreen> createState() =>
      _SakhiHomeDashboardScreenState();
}

enum _HomePage {
  home,
  explore,
  community,
  wellness,
  safety,
  profile,
  editProfile,
  privacy,
  notifications,
  followers,
  accountSecurity,
  moreOptions,
}

class _SakhiHomeDashboardScreenState extends State<SakhiHomeDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _editNameController = TextEditingController();
  final TextEditingController _editBioController = TextEditingController();
  late Future<String?> _displayNameFuture;

  _HomePage _page = _HomePage.home;
  int _selectedTab = 0;
  String _searchQuery = '';
  String? _localDisplayName;
  String _bio =
      'A passionate learner, exploring wellness, technology and meaningful connections.';
  bool _signingOut = false;
  bool _marketingNotifications = false;
  bool _communityNotifications = true;
  bool _groupNotifications = true;
  bool _wellnessNotifications = true;
  bool _safetyNotifications = true;
  bool _messagesNotifications = true;
  bool _businessNotifications = true;
  bool _postLiked = false;
  bool _postSaved = false;
  bool _showSavedPosts = false;
  bool _showGroups = false;
  final Set<String> _following = {'Meera Iyer', 'Priya Sharma'};
  final List<String> _localPosts = [];

  static const _topics = <String>[
    '#MentalWellness',
    '#CareerGrowth',
    '#SelfCare',
    '#SafetyTips',
    '#StudentLife',
    '#WomenInTech',
  ];

  static const _people = <({String name, String handle, String initials})>[
    (name: 'Ananya Rao', handle: '@ananya', initials: 'AR'),
    (name: 'Meera Iyer', handle: '@meera', initials: 'MI'),
    (name: 'Kavya Nair', handle: '@kavya', initials: 'KN'),
    (name: 'Ishita Reddy', handle: '@ishita', initials: 'IR'),
    (name: 'Priya Sharma', handle: '@priya', initials: 'PS'),
    (name: 'Sneha Verma', handle: '@sneha', initials: 'SV'),
  ];

  @override
  void initState() {
    super.initState();
    _displayNameFuture = _readDisplayName();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _editNameController.dispose();
    _editBioController.dispose();
    super.dispose();
  }

  Future<String?> _readDisplayName() async {
    try {
      if (widget.loadDisplayName != null) {
        return await widget.loadDisplayName!();
      }
      final payload = await BackendApiClient().get(
        'auth/me',
        authenticated: true,
      );
      final profile = payload['profile'];
      if (profile is Map<String, dynamic>) {
        final name = profile['displayName'];
        if (name is String && name.trim().isNotEmpty) return name.trim();
      }
    } catch (_) {
      // Preserve the authenticated shell and fall back to a neutral greeting.
    }
    return null;
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _name(String? apiName) =>
      _localDisplayName ?? (apiName?.trim().isNotEmpty == true ? apiName! : 'Sidhu');

  void _navigate(_HomePage page) {
    setState(() {
      _page = page;
      if (page == _HomePage.home) _selectedTab = 0;
      if (page == _HomePage.explore) _selectedTab = 1;
      if (page == _HomePage.community) _selectedTab = 2;
      if (page == _HomePage.profile) _selectedTab = 3;
    });
  }

  void _selectTab(int index) {
    switch (index) {
      case 0:
        _navigate(_HomePage.home);
        return;
      case 1:
        _navigate(_HomePage.explore);
        return;
      case 2:
        _navigate(_HomePage.community);
        return;
      case 3:
        _navigate(_HomePage.profile);
        return;
    }
  }

  void _openSearchResults() {
    _navigate(_HomePage.explore);
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    String? warning;
    try {
      await widget.authService.logout();
    } catch (_) {
      warning = 'The backend could not confirm session revocation.';
    }
    if (!mounted) return;
    final warningMessage = warning;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (loginContext) {
          if (warningMessage != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (loginContext.mounted) {
                ScaffoldMessenger.maybeOf(loginContext)?.showSnackBar(
                  SnackBar(content: Text(warningMessage)),
                );
              }
            });
          }
          return SakhiLoginScreen(authService: widget.authService);
        },
      ),
      (_) => false,
    );
  }

  Future<void> _showSafetyBoundary() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.shield_rounded, size: 38, color: Color(0xFFCC3F5A)),
        title: const Text('Safety & SOS preview'),
        content: const Text(
          'This screen is a visual prototype. It does not place calls, send SMS, '
          'read GPS location, or dispatch an emergency alert. You can still '
          'review the safety guidance and contact options shown in the preview.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _navigate(_HomePage.safety);
            },
            child: const Text('View safety guidance'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreatePost() async {
    final controller = TextEditingController();
    final post = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Create a post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Write a local preview post. It will appear in this prototype only.',
              style: TextStyle(color: SakhiColors.mutedPlum, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'What would you like to share?',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Add to preview'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || post == null || post.isEmpty) return;
    setState(() {
      _localPosts.insert(0, post);
      _page = _HomePage.community;
      _selectedTab = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _displayNameFuture,
      builder: (context, snapshot) {
        final name = _name(snapshot.data);
        return Scaffold(
          backgroundColor: SakhiColors.blush,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(name),
                Expanded(child: _buildCurrentPage(name)),
              ],
            ),
          ),
          bottomNavigationBar: _DashboardBottomBar(
            currentIndex: _selectedTab,
            onSelect: _selectTab,
            onCenterAddTap: _showCreatePost,
          ),
        );
      },
    );
  }

  Widget _buildHeader(String name) {
    if (_page == _HomePage.home) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 7, 12, 10),
        child: Row(
          children: [
            Image.asset(
              AppBrand.iconAsset,
              width: 31,
              height: 31,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.spa_rounded,
                size: 31,
                color: SakhiColors.purple,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              AppBrand.appName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: SakhiColors.plum,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            IconButton(
              key: const Key('home-notifications-button'),
              tooltip: 'Notifications',
              onPressed: () => _navigate(_HomePage.notifications),
              icon: const Icon(Icons.notifications_none_rounded, color: SakhiColors.purple),
            ),
            IconButton(
              key: const Key('home-profile-button'),
              tooltip: 'Profile',
              onPressed: () => _navigate(_HomePage.profile),
              icon: const Icon(Icons.person_outline_rounded, color: SakhiColors.purple),
            ),
            PopupMenuButton<String>(
              tooltip: 'More options',
              icon: const Icon(Icons.more_vert_rounded, color: SakhiColors.purple),
              onSelected: (value) {
                if (value == 'more') _navigate(_HomePage.moreOptions);
                if (value == 'signout') _signOut();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'more', child: Text('More options')),
                PopupMenuItem(value: 'signout', child: Text('Sign out')),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 3, 12, 8),
      child: Row(
        children: [
          IconButton(
            key: const Key('dashboard-back-button'),
            tooltip: 'Back to previous screen',
            onPressed: () => _navigate(_HomePage.home),
            icon: const Icon(Icons.arrow_back_rounded, color: SakhiColors.plum),
          ),
          Expanded(
            child: Text(
              _pageTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: SakhiColors.plum,
              ),
            ),
          ),
          if (_page == _HomePage.community)
            IconButton(
              tooltip: 'Create post',
              onPressed: _showCreatePost,
              icon: const Icon(Icons.add_circle_outline_rounded, color: SakhiColors.purple),
            ),
          if (_page == _HomePage.notifications)
            const Icon(Icons.notifications_none_rounded, color: SakhiColors.purple),
          if (_page == _HomePage.profile)
            IconButton(
              tooltip: 'Edit profile',
              onPressed: () => _navigate(_HomePage.editProfile),
              icon: const Icon(Icons.edit_outlined, color: SakhiColors.purple),
            ),
        ],
      ),
    );
  }

  String get _pageTitle {
    switch (_page) {
      case _HomePage.home:
        return 'Sakhi';
      case _HomePage.explore:
        return 'Explore';
      case _HomePage.community:
        return 'Community';
      case _HomePage.wellness:
        return 'Wellness';
      case _HomePage.safety:
        return 'Safety';
      case _HomePage.profile:
        return 'Profile';
      case _HomePage.editProfile:
        return 'Edit Profile';
      case _HomePage.privacy:
        return 'Privacy Settings';
      case _HomePage.notifications:
        return 'Notification Preferences';
      case _HomePage.followers:
        return 'Followers & Following';
      case _HomePage.accountSecurity:
        return 'Account & Security';
      case _HomePage.moreOptions:
        return 'More Options';
    }
  }

  Widget _buildCurrentPage(String name) {
    switch (_page) {
      case _HomePage.home:
        return _buildHome(name);
      case _HomePage.explore:
        return _buildExplore();
      case _HomePage.community:
        return _buildCommunity(name);
      case _HomePage.wellness:
        return _buildWellness();
      case _HomePage.safety:
        return _buildSafety();
      case _HomePage.profile:
        return _buildProfile(name);
      case _HomePage.editProfile:
        return _buildEditProfile(name);
      case _HomePage.privacy:
        return _buildPrivacy();
      case _HomePage.notifications:
        return _buildNotifications();
      case _HomePage.followers:
        return _buildFollowers();
      case _HomePage.accountSecurity:
        return _buildAccountSecurity();
      case _HomePage.moreOptions:
        return _buildMoreOptions();
    }
  }

  Widget _buildHome(String name) {
    return ListView(
      key: const Key('sakhi-home-dashboard-list'),
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
      children: [
        _searchField(),
        if (_searchQuery.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          _searchSuggestions(),
        ],
        const SizedBox(height: 14),
        _GreetingHero(
          greeting: _greeting(),
          displayName: name,
          onTap: () => _navigate(_HomePage.wellness),
        ),
        const SizedBox(height: 17),
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                key: const Key('home-action-explore'),
                label: 'Explore',
                icon: Icons.search_rounded,
                tint: const Color(0xFFF2E6FA),
                accent: SakhiColors.purple,
                onTap: () => _navigate(_HomePage.explore),
              ),
            ),
            Expanded(
              child: _QuickAction(
                key: const Key('home-action-community'),
                label: 'Community',
                icon: Icons.groups_rounded,
                tint: const Color(0xFFFDE8F1),
                accent: const Color(0xFFC02668),
                onTap: () => _navigate(_HomePage.community),
              ),
            ),
            Expanded(
              child: _QuickAction(
                key: const Key('home-action-wellness'),
                label: 'Wellness',
                icon: Icons.spa_rounded,
                tint: const Color(0xFFE6F7EF),
                accent: const Color(0xFF25855A),
                onTap: () => _navigate(_HomePage.wellness),
              ),
            ),
            Expanded(
              child: _QuickAction(
                key: const Key('home-action-sos'),
                label: 'SOS',
                icon: Icons.sos_rounded,
                tint: const Color(0xFFFDE8EC),
                accent: const Color(0xFFCC3F5A),
                onTap: _showSafetyBoundary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'For You Today',
                style: TextStyle(
                  color: SakhiColors.plum,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const _PreviewPill(),
            const SizedBox(width: 5),
            TextButton(
              onPressed: () => _navigate(_HomePage.community),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 7),
        _ForYouCard(
          icon: Icons.auto_awesome_rounded,
          iconColor: SakhiColors.purple,
          iconBackground: const Color(0xFFF2E6FA),
          title: '5 new posts',
          description: 'from your interests',
          onTap: () => _navigate(_HomePage.community),
        ),
        const SizedBox(height: 9),
        _ForYouCard(
          icon: Icons.groups_2_rounded,
          iconColor: const Color(0xFFB34F91),
          iconBackground: const Color(0xFFFDE8F1),
          title: '2 community updates',
          description: 'in your groups',
          onTap: () => _navigate(_HomePage.community),
        ),
        const SizedBox(height: 9),
        _ForYouCard(
          icon: Icons.health_and_safety_rounded,
          iconColor: const Color(0xFFDA7A22),
          iconBackground: const Color(0xFFFFF0E3),
          title: 'Featured resources',
          description: 'on women’s safety',
          onTap: () => _navigate(_HomePage.safety),
        ),
      ],
    );
  }

  Widget _searchField() {
    return TextField(
      key: const Key('home-dashboard-search'),
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      onSubmitted: (_) => _openSearchResults(),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search people, topics, groups...',
        prefixIcon: const Icon(Icons.search_rounded, color: SakhiColors.plum),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFEEDCEB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFEEDCEB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: SakhiColors.purple, width: 1.4),
        ),
      ),
    );
  }

  Widget _searchSuggestions() {
    final query = _searchQuery.toLowerCase().replaceAll('#', '');
    final matches = _topics.where((topic) => topic.toLowerCase().contains(query)).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6EDF8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Matching prototype topics',
            style: TextStyle(fontWeight: FontWeight.w800, color: SakhiColors.plum),
          ),
          const SizedBox(height: 7),
          if (matches.isEmpty)
            const Text(
              'No matching sample topics. Open Explore to browse all categories.',
              style: TextStyle(color: SakhiColors.mutedPlum, fontSize: 12),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: matches
                  .take(4)
                  .map((topic) => ActionChip(
                        label: Text(topic),
                        onPressed: () {
                          _searchController.text = topic;
                          _searchQuery = topic;
                          _navigate(_HomePage.explore);
                        },
                      ))
                  .toList(),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _openSearchResults,
              child: const Text('Browse Explore'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplore() {
    final filteredTopics = _topics.where((topic) {
      final query = _searchQuery.toLowerCase().replaceAll('#', '');
      return query.isEmpty || topic.toLowerCase().contains(query);
    }).toList();
    return ListView(
      key: const Key('sakhi-explore-list'),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
      children: [
        _searchField(),
        const SizedBox(height: 13),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['All', 'Posts', 'Groups', 'Experts', 'Events']
              .map((filter) => _FilterChip(
                    label: filter,
                    selected: _selectedExploreFilter == filter,
                    onTap: () => setState(() => _selectedExploreFilter = filter),
                  ))
              .toList(),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Trending Topics'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filteredTopics
              .map((topic) => ActionChip(
                    backgroundColor: const Color(0xFFF2E6FA),
                    side: BorderSide.none,
                    label: Text(topic, style: const TextStyle(color: SakhiColors.purple, fontSize: 12)),
                    onPressed: () {
                      _searchController.text = topic;
                      setState(() => _searchQuery = topic);
                    },
                  ))
              .toList(),
        ),
        if (filteredTopics.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 9),
            child: Text('No matching sample topics. Clear the search to browse all.', style: TextStyle(color: SakhiColors.mutedPlum)),
          ),
        const SizedBox(height: 20),
        _sectionTitle('Explore by category'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.35,
          children: [
            _CategoryTile(title: 'Health & Wellness', icon: Icons.health_and_safety_rounded, color: const Color(0xFFE8F2FF), onTap: () => _navigate(_HomePage.wellness)),
            _CategoryTile(title: 'Safety & Awareness', icon: Icons.shield_rounded, color: const Color(0xFFFFF0E3), onTap: () => _navigate(_HomePage.safety)),
            _CategoryTile(title: 'Education & Career', icon: Icons.school_rounded, color: const Color(0xFFE6F7EF), onTap: () => _openTopicMessage('Education & Career')),
            _CategoryTile(title: 'Lifestyle & Hobbies', icon: Icons.palette_rounded, color: const Color(0xFFF2E6FA), onTap: () => _openTopicMessage('Lifestyle & Hobbies')),
          ],
        ),
        const SizedBox(height: 20),
        _sectionTitle('Recommended for you'),
        const SizedBox(height: 10),
        _RecommendedCard(
          initials: 'AR',
          name: 'Ananya Rao',
          subtitle: '2 hours ago',
          body: 'Small steps every day make a big difference in your mental wellness. 💜',
          onTap: () => _navigate(_HomePage.community),
        ),
        const SizedBox(height: 9),
        _RecommendedCard(
          initials: 'MI',
          name: 'Meera Iyer',
          subtitle: 'Wellness community',
          body: 'Explore short breathing exercises and daily wellbeing prompts.',
          onTap: () => _navigate(_HomePage.wellness),
        ),
      ],
    );
  }

  String _selectedExploreFilter = 'All';

  void _openTopicMessage(String title) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: const Text('This category is available as a local UI preview. Choose a displayed card to continue exploring.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildCommunity(String name) {
    return ListView(
      key: const Key('sakhi-community-list'),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle('Community')),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _communityFeedFilter,
                borderRadius: BorderRadius.circular(14),
                items: const [
                  DropdownMenuItem(value: 'For You', child: Text('For You')),
                  DropdownMenuItem(value: 'Following', child: Text('Following')),
                  DropdownMenuItem(value: 'Wellness', child: Text('Wellness')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _communityFeedFilter = value);
                },
              ),
            ),
            IconButton(
              tooltip: 'Explore posts',
              onPressed: () => _navigate(_HomePage.explore),
              icon: const Icon(Icons.search_rounded, color: SakhiColors.purple),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_localPosts.isNotEmpty)
          ..._localPosts.map((post) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PostCard(
                  initials: 'YO',
                  author: name,
                  time: 'Just now · local preview',
                  body: post,
                  liked: false,
                  saved: false,
                  onLike: () => _showLocalInteraction('Your preview post'),
                  onComment: () => _showCommentPreview('Your preview post'),
                  onSave: () => _showLocalInteraction('Post saved to this preview'),
                ),
              )),
        _PostCard(
          initials: 'KN',
          author: 'Kavya Nair',
          time: '3 hours ago',
          body: _communityFeedFilter == 'Wellness'
              ? 'Taking a few minutes to reset can make a difference. What helps you unwind? 💜'
              : 'A peaceful evening walk 🌿 Taking time for myself always helps me reset. Stay kind, stay strong! 💜',
          liked: _postLiked,
          saved: _postSaved,
          onLike: () => setState(() => _postLiked = !_postLiked),
          onComment: () => _showCommentPreview('Kavya Nair'),
          onSave: () => setState(() => _postSaved = !_postSaved),
        ),
        const SizedBox(height: 11),
        _PostCard(
          initials: 'MI',
          author: 'Meera Iyer',
          time: '5 hours ago',
          body: 'Here are 5 simple breathing exercises that help me during stressful days. 🌸',
          liked: false,
          saved: false,
          onLike: () => _showLocalInteraction('Like preview toggled for Meera’s post'),
          onComment: () => _showCommentPreview('Meera Iyer'),
          onSave: () => _showLocalInteraction('Meera’s post saved to this preview'),
        ),
        const SizedBox(height: 10),
        _note('Sample community posts are shown for visual testing; likes, saves and drafts remain local to this screen.'),
      ],
    );
  }

  String _communityFeedFilter = 'For You';

  Future<void> _showCommentPreview(String author) async {
    final controller = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Comment on $author’s post'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Write a comment', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Add preview comment')),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || comment == null || comment.isEmpty) return;
    _showLocalInteraction('Comment added to the local preview');
  }

  void _showLocalInteraction(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: SakhiColors.plum,
        duration: const Duration(seconds: 2),
      ));
  }

  Widget _buildWellness() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 20),
      children: [
        Container(
          height: 154,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFBE6F2), Color(0xFFEFDDF8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFEEDCEB)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Your Wellbeing Matters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: SakhiColors.plum)),
                    SizedBox(height: 8),
                    Text('Explore tools and resources to feel better, every day.', style: TextStyle(fontSize: 12, color: SakhiColors.mutedPlum)),
                    SizedBox(height: 8),
                    _PreviewPill(),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.spa_rounded, size: 76, color: Color(0xFFB34F91)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.1,
          children: [
            _CategoryTile(title: 'Menstrual Health', icon: Icons.favorite_rounded, color: const Color(0xFFFDE8F1), onTap: () => _openTopicMessage('Menstrual Health')),
            _CategoryTile(title: 'Mental Wellness', icon: Icons.psychology_rounded, color: const Color(0xFFE8F2FF), onTap: () => _openTopicMessage('Mental Wellness')),
            _CategoryTile(title: 'Fitness & Nutrition', icon: Icons.fitness_center_rounded, color: const Color(0xFFE6F7EF), onTap: () => _openTopicMessage('Fitness & Nutrition')),
            _CategoryTile(title: 'Expert Articles', icon: Icons.article_rounded, color: const Color(0xFFFFF0E3), onTap: () => _openTopicMessage('Expert Articles')),
          ],
        ),
        const SizedBox(height: 20),
        _sectionTitle('Today’s Pick'),
        const SizedBox(height: 10),
        _ForYouCard(
          icon: Icons.self_improvement_rounded,
          iconColor: const Color(0xFFB34F91),
          iconBackground: const Color(0xFFFDE8F1),
          title: 'Guided Meditation',
          description: _meditationPlaying ? 'Preview selected · audio is not playing' : '10 min · audio preview',
          onTap: () => setState(() => _meditationPlaying = !_meditationPlaying),
        ),
        const SizedBox(height: 10),
        _ForYouCard(
          icon: Icons.air_rounded,
          iconColor: const Color(0xFF25855A),
          iconBackground: const Color(0xFFE6F7EF),
          title: 'Breathing Exercises',
          description: 'Simple exercises for a calm mind',
          onTap: () => _openTopicMessage('Breathing Exercises'),
        ),
        const SizedBox(height: 15),
        _note('Wellness cards are local prototype content. No medical advice or audio service is being represented as live.'),
      ],
    );
  }

  bool _meditationPlaying = false;

  Widget _buildSafety() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
      children: [
        Container(
          height: 238,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEFE4FA), Color(0xFFFDE8F1), Color(0xFFFFF4F7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEEDCEB)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 174,
                height: 174,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD8B8E4), width: 2),
                ),
              ),
              Container(
                width: 124,
                height: 124,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFDAB9E8).withValues(alpha: 0.45),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_rounded, size: 35, color: Color(0xFFD63E72)),
                  const SizedBox(height: 7),
                  const Text('Safety map preview', style: TextStyle(fontWeight: FontWeight.w800, color: SakhiColors.plum)),
                  const SizedBox(height: 3),
                  const Text('Location access is not started', style: TextStyle(fontSize: 11, color: SakhiColors.mutedPlum)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('safety-preview-sos-button'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF2415A), foregroundColor: Colors.white),
                    onPressed: _showSafetyBoundary,
                    icon: const Icon(Icons.sos_rounded),
                    label: const Text('SOS preview'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionTitle('Quick Safety Actions'),
        const SizedBox(height: 9),
        _ForYouCard(
          icon: Icons.people_alt_rounded,
          iconColor: const Color(0xFFD63E72),
          iconBackground: const Color(0xFFFDE8F1),
          title: 'Emergency Contacts',
          description: 'Review your trusted contact setup',
          onTap: () => _openTopicMessage('Emergency Contacts'),
        ),
        const SizedBox(height: 9),
        _ForYouCard(
          icon: Icons.location_searching_rounded,
          iconColor: const Color(0xFF25855A),
          iconBackground: const Color(0xFFE6F7EF),
          title: 'Nearby Help',
          description: 'Preview safety resources and guidance',
          onTap: () => _openTopicMessage('Nearby Help'),
        ),
        const SizedBox(height: 9),
        _ForYouCard(
          icon: Icons.health_and_safety_rounded,
          iconColor: const Color(0xFFDA7A22),
          iconBackground: const Color(0xFFFFF0E3),
          title: 'Safety Checklist',
          description: 'Before travelling or meeting someone',
          onTap: () => _openTopicMessage('Safety Checklist'),
        ),
        const SizedBox(height: 9),
        _ForYouCard(
          icon: Icons.call_rounded,
          iconColor: SakhiColors.purple,
          iconBackground: const Color(0xFFF2E6FA),
          title: 'Emergency Helplines',
          description: 'Review contacts available in the service region',
          onTap: () => _openTopicMessage('Emergency Helplines'),
        ),
        const SizedBox(height: 12),
        _note('The SOS control is deliberately a preview. No call, message, GPS request or emergency dispatch is triggered.'),
      ],
    );
  }

  Widget _buildProfile(String name) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
      children: [
        Container(
          height: 145,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFDE8F1), Color(0xFFF2E6FA)]),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Stack(
            children: [
              Positioned(left: 12, top: 12, child: Icon(Icons.local_florist_rounded, size: 38, color: Color(0xFFDDA5CA))),
              Positioned(right: 18, bottom: 10, child: Icon(Icons.spa_rounded, size: 48, color: Color(0xFFDDA5CA))),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -42),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 43,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 39,
                    backgroundColor: const Color(0xFFF2E6FA),
                    child: Text(
                      name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'S',
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: SakhiColors.purple),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: SakhiColors.plum)),
                const Text('@sakhi_member', style: TextStyle(fontSize: 12, color: SakhiColors.mutedPlum)),
                const SizedBox(height: 9),
                OutlinedButton.icon(
                  onPressed: () => _navigate(_HomePage.editProfile),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Edit Profile'),
                ),
              ],
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -22),
          child: Row(
            children: [
              _ProfileStat(value: '124', label: 'Posts', onTap: () => setState(() { _showGroups = false; _showSavedPosts = false; })),
              _ProfileStat(value: '560', label: 'Followers', onTap: () => _navigate(_HomePage.followers)),
              _ProfileStat(value: '312', label: 'Following', onTap: () => _navigate(_HomePage.followers)),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_bio, style: const TextStyle(fontSize: 13, height: 1.45, color: SakhiColors.plum)),
              const SizedBox(height: 9),
              const Row(
                children: [
                  Icon(Icons.location_on_outlined, color: SakhiColors.purple, size: 17),
                  SizedBox(width: 4),
                  Text('India', style: TextStyle(fontSize: 12, color: SakhiColors.plum)),
                ],
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: ['Mental Wellness', 'Travel', 'Reading', 'WomenInTech', 'Art', 'Fitness']
                    .map((tag) => _LabelChip(label: tag)).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _FilterChip(label: 'Posts', selected: !_showSavedPosts && !_showGroups, onTap: () => setState(() { _showSavedPosts = false; _showGroups = false; }))),
                  Expanded(child: _FilterChip(label: 'Saved', selected: _showSavedPosts, onTap: () => setState(() { _showSavedPosts = true; _showGroups = false; }))),
                  Expanded(child: _FilterChip(label: 'Groups', selected: _showGroups, onTap: () => setState(() { _showGroups = true; _showSavedPosts = false; }))),
                ],
              ),
              const SizedBox(height: 10),
              if (_showGroups)
                _ForYouCard(icon: Icons.groups_rounded, iconColor: SakhiColors.purple, iconBackground: const Color(0xFFF2E6FA), title: 'Women in Tech', description: 'Local group preview', onTap: () => _navigate(_HomePage.community))
              else if (_showSavedPosts && !_postSaved)
                _note('No locally saved preview posts yet. Save a community card to see it here.')
              else
                _ForYouCard(icon: _showSavedPosts ? Icons.bookmark_rounded : Icons.photo_library_outlined, iconColor: SakhiColors.purple, iconBackground: const Color(0xFFF2E6FA), title: _showSavedPosts ? 'Saved community post' : 'A little moment of gratitude', description: _showSavedPosts ? 'Saved in this session preview' : 'A sample profile post · 2 days ago', onTap: () => _navigate(_HomePage.community)),
            ],
          ),
        ),
        _note('Profile details are read from the authenticated profile for the greeting. Changes made in this UI preview are not saved to the backend.'),
      ],
    );
  }

  Widget _buildEditProfile(String name) {
    if (_editNameController.text.isEmpty) _editNameController.text = name;
    if (_editBioController.text.isEmpty) _editBioController.text = _bio;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 5, 18, 20),
      children: [
        const Center(child: CircleAvatar(radius: 43, backgroundColor: Color(0xFFF2E6FA), child: Icon(Icons.person_rounded, size: 48, color: SakhiColors.purple))),
        const SizedBox(height: 17),
        const Text('Display name', style: TextStyle(fontWeight: FontWeight.w700, color: SakhiColors.plum)),
        const SizedBox(height: 6),
        TextField(controller: _editNameController, decoration: const InputDecoration(hintText: 'Your display name', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        const Text('Bio', style: TextStyle(fontWeight: FontWeight.w700, color: SakhiColors.plum)),
        const SizedBox(height: 6),
        TextField(controller: _editBioController, maxLines: 4, decoration: const InputDecoration(border: OutlineInputBorder())),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () {
            final newName = _editNameController.text.trim();
            if (newName.isEmpty) {
              _showLocalInteraction('Enter a display name first.');
              return;
            }
            setState(() {
              _localDisplayName = newName;
              _bio = _editBioController.text.trim();
            });
            _navigate(_HomePage.profile);
          },
          child: const Text('Save preview changes'),
        ),
        const SizedBox(height: 9),
        _note('This edit form updates the on-screen preview only. It does not upload a photo or save profile changes to the server.'),
      ],
    );
  }

  Widget _buildPrivacy() {
    final settings = <({String title, String subtitle, bool value, ValueChanged<bool> onChanged})>[
      (title: 'Who can view my profile', subtitle: 'Verified members only', value: _privacyProfile, onChanged: (value) => setState(() => _privacyProfile = value)),
      (title: 'Who can message me', subtitle: 'Verified members only', value: _privacyMessages, onChanged: (value) => setState(() => _privacyMessages = value)),
      (title: 'Show in search results', subtitle: 'Allow member discovery in this preview', value: _privacySearch, onChanged: (value) => setState(() => _privacySearch = value)),
      (title: 'Allow business enquiries', subtitle: 'Show business contact option in this preview', value: _privacyBusiness, onChanged: (value) => setState(() => _privacyBusiness = value)),
      (title: 'Share location', subtitle: 'Location is not requested by this preview', value: _privacyLocation, onChanged: (value) => _confirmLocationPreview(value)),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      children: [
        _note('Preview preferences are temporary and are not saved to your account.'),
        const SizedBox(height: 10),
        ...settings.map((setting) => _SwitchSettingTile(title: setting.title, subtitle: setting.subtitle, value: setting.value, onChanged: setting.onChanged)),
        const SizedBox(height: 10),
        _ForYouCard(icon: Icons.policy_outlined, iconColor: SakhiColors.purple, iconBackground: const Color(0xFFF2E6FA), title: 'Privacy Policy', description: 'Review the privacy policy destination', onTap: () => _openTopicMessage('Privacy Policy')),
      ],
    );
  }

  bool _privacyProfile = true;
  bool _privacyMessages = true;
  bool _privacySearch = true;
  bool _privacyBusiness = false;
  bool _privacyLocation = false;

  void _confirmLocationPreview(bool value) {
    if (value) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Location sharing preview'),
          content: const Text('No GPS permission or location service will be requested by this UI preview.'),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
        ),
      );
    }
    setState(() => _privacyLocation = value);
  }

  Widget _buildNotifications() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      children: [
        _note('These switches are interactive preview preferences. They do not change push-notification delivery on the backend.'),
        const SizedBox(height: 10),
        _SwitchSettingTile(title: 'Community updates', subtitle: 'New posts, comments, likes', value: _communityNotifications, onChanged: (value) => setState(() => _communityNotifications = value)),
        _SwitchSettingTile(title: 'Group activity', subtitle: 'Updates from your groups', value: _groupNotifications, onChanged: (value) => setState(() => _groupNotifications = value)),
        _SwitchSettingTile(title: 'Wellness reminders', subtitle: 'Tips and suggestions', value: _wellnessNotifications, onChanged: (value) => setState(() => _wellnessNotifications = value)),
        _SwitchSettingTile(title: 'Safety alerts', subtitle: 'Important safety notifications', value: _safetyNotifications, onChanged: (value) => setState(() => _safetyNotifications = value)),
        _SwitchSettingTile(title: 'Messages', subtitle: 'Direct messages', value: _messagesNotifications, onChanged: (value) => setState(() => _messagesNotifications = value)),
        _SwitchSettingTile(title: 'Business enquiries', subtitle: 'Service or collaboration requests', value: _businessNotifications, onChanged: (value) => setState(() => _businessNotifications = value)),
        _SwitchSettingTile(title: 'Marketing updates', subtitle: 'Product updates and news', value: _marketingNotifications, onChanged: (value) => setState(() => _marketingNotifications = value)),
      ],
    );
  }

  Widget _buildFollowers() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Search followers...',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFEEDCEB))),
          ),
          onChanged: (value) => setState(() => _followerQuery = value),
        ),
        const SizedBox(height: 11),
        ..._people.where((person) => person.name.toLowerCase().contains(_followerQuery.toLowerCase())).map((person) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEFE3ED))),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: const Color(0xFFF2E6FA), child: Text(person.initials, style: const TextStyle(color: SakhiColors.purple, fontWeight: FontWeight.w800))),
                const SizedBox(width: 11),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(person.name, style: const TextStyle(fontWeight: FontWeight.w800, color: SakhiColors.plum)), Text(person.handle, style: const TextStyle(fontSize: 12, color: SakhiColors.mutedPlum))])),
                OutlinedButton(
                  onPressed: () => setState(() {
                    if (_following.contains(person.name)) {
                      _following.remove(person.name);
                    } else {
                      _following.add(person.name);
                    }
                  }),
                  child: Text(_following.contains(person.name) ? 'Following' : 'Follow'),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  String _followerQuery = '';

  Widget _buildAccountSecurity() {
    final items = <({IconData icon, String title, String subtitle, VoidCallback onTap})>[
      (icon: Icons.phone_rounded, title: 'Phone number', subtitle: 'Verified status comes from account services', onTap: () => _openTopicMessage('Phone number')),
      (icon: Icons.mail_outline_rounded, title: 'Email address', subtitle: 'Manage optional account contact details', onTap: () => _openTopicMessage('Email address')),
      (icon: Icons.devices_rounded, title: 'Login sessions', subtitle: 'Review active sessions', onTap: () => _openTopicMessage('Login sessions')),
      (icon: Icons.lock_outline_rounded, title: 'Change PIN / Password', subtitle: 'Update your security credentials', onTap: () => _openTopicMessage('Change PIN / Password')),
      (icon: Icons.security_rounded, title: 'Two-factor authentication', subtitle: 'Add an extra layer of security', onTap: () => _openTopicMessage('Two-factor authentication')),
      (icon: Icons.person_off_outlined, title: 'Account deactivation', subtitle: 'Temporarily deactivate your account', onTap: () => _openAccountSafetyDialog('Account deactivation')),
      (icon: Icons.delete_outline_rounded, title: 'Delete account', subtitle: 'Permanently delete your account', onTap: () => _openAccountSafetyDialog('Delete account')),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      children: [
        _note('Security controls are shown for navigation preview. No credential or account-changing operation is simulated as successful.'),
        const SizedBox(height: 10),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ForYouCard(
            icon: item.icon,
            iconColor: SakhiColors.purple,
            iconBackground: const Color(0xFFF2E6FA),
            title: item.title,
            description: item.subtitle,
            onTap: item.onTap,
          ),
        )),
      ],
    );
  }

  Future<void> _openAccountSafetyDialog(String action) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(action),
        content: const Text('This sensitive operation must be completed through an authenticated backend workflow. The preview has not changed your account.'),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel'))],
      ),
    );
  }

  Widget _buildMoreOptions() {
    final options = <({IconData icon, String title, String subtitle, VoidCallback onTap})>[
      (icon: Icons.groups_rounded, title: 'My Groups', subtitle: 'Browse your community groups', onTap: () => _navigate(_HomePage.community)),
      (icon: Icons.bookmark_border_rounded, title: 'My Saved Posts', subtitle: 'View saved community posts', onTap: () { setState(() { _showSavedPosts = true; _showGroups = false; }); _navigate(_HomePage.profile); }),
      (icon: Icons.business_center_outlined, title: 'Business Profile', subtitle: 'Manage your business profile', onTap: () => _openTopicMessage('Business Profile')),
      (icon: Icons.help_outline_rounded, title: 'Help & Support', subtitle: 'Find support options', onTap: () => _openTopicMessage('Help & Support')),
      (icon: Icons.flag_outlined, title: 'Report a User', subtitle: 'View reporting guidance', onTap: () => _openTopicMessage('Report a User')),
      (icon: Icons.block_rounded, title: 'Blocked Users', subtitle: 'Manage blocked accounts', onTap: () => _openTopicMessage('Blocked Users')),
      (icon: Icons.policy_outlined, title: 'Terms and Conditions', subtitle: 'Review Sakhi terms', onTap: () => _openTopicMessage('Terms and Conditions')),
      (icon: Icons.privacy_tip_outlined, title: 'Privacy Policy', subtitle: 'Review privacy information', onTap: () => _navigate(_HomePage.privacy)),
      (icon: Icons.info_outline_rounded, title: 'About Sakhi', subtitle: 'Version 1.0.0 · UI preview', onTap: () => _openTopicMessage('About Sakhi')),
      (icon: Icons.manage_accounts_outlined, title: 'Account & Security', subtitle: 'Account control centre', onTap: () => _navigate(_HomePage.accountSecurity)),
      (icon: Icons.notifications_none_rounded, title: 'Notification Preferences', subtitle: 'Manage notification preview choices', onTap: () => _navigate(_HomePage.notifications)),
      (icon: Icons.logout_rounded, title: 'Sign out', subtitle: 'End this authenticated session', onTap: _signOut),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      children: options.map((option) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _ForYouCard(
          icon: option.icon,
          iconColor: SakhiColors.purple,
          iconBackground: const Color(0xFFF2E6FA),
          title: option.title,
          description: option.subtitle,
          onTap: option.onTap,
        ),
      )).toList(),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          color: SakhiColors.plum,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.25,
        ),
      );

  Widget _note(String text) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF6EDF8),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: SakhiColors.mutedPlum,
            fontSize: 11.5,
            height: 1.4,
          ),
        ),
      );
}

class _GreetingHero extends StatelessWidget {
  const _GreetingHero({
    required this.greeting,
    required this.displayName,
    required this.onTap,
  });

  final String greeting;
  final String displayName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 166,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFCE4F0), Color(0xFFF3DCF8)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFEEDCEB)),
            boxShadow: const [
              BoxShadow(color: Color(0x0D79318A), blurRadius: 13, offset: Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Positioned(
                  right: -3,
                  bottom: -12,
                  width: 176,
                  height: 174,
                  child: IgnorePointer(
                    child: Image.asset(
                      'assets/images/home/greeting_hero_illustration.webp',
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.local_florist_rounded,
                        size: 120,
                        color: Color(0xFFD7AFE4),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(17, 14, 130, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(greeting, style: const TextStyle(color: SakhiColors.plum, fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: SakhiColors.plum, fontSize: 23, height: 1.1, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'A safer, stronger and more connected you.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: SakhiColors.mutedPlum, fontSize: 11.5, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    super.key,
    required this.label,
    required this.icon,
    required this.tint,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color tint;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                child: Icon(icon, color: accent, size: 27),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: SakhiColors.plum, fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForYouCard extends StatelessWidget {
  const _ForYouCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: iconBackground, borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: SakhiColors.plum, fontSize: 12.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(description, style: const TextStyle(color: SakhiColors.mutedPlum, fontSize: 11, height: 1.25)),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.chevron_right_rounded, color: SakhiColors.mutedPlum, size: 21),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardBottomBar extends StatelessWidget {
  const _DashboardBottomBar({
    required this.currentIndex,
    required this.onSelect,
    required this.onCenterAddTap,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onCenterAddTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEFE3ED))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 5, 6, 4),
          child: Row(
            children: [
              _NavItem(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home_rounded, selected: currentIndex == 0, onTap: () => onSelect(0)),
              _NavItem(label: 'Explore', icon: Icons.search_rounded, activeIcon: Icons.search_rounded, selected: currentIndex == 1, onTap: () => onSelect(1)),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    key: const Key('home-create-post-button'),
                    onTap: onCenterAddTap,
                    child: Container(
                      width: 47,
                      height: 47,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF9C4FB0), SakhiColors.purple]),
                        shape: BoxShape.circle,
                        boxShadow: const [BoxShadow(color: Color(0x3379318A), blurRadius: 10, offset: Offset(0, 3))],
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
              _NavItem(label: 'Community', icon: Icons.groups_outlined, activeIcon: Icons.groups_rounded, selected: currentIndex == 2, onTap: () => onSelect(2)),
              _NavItem(label: 'Profile', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, selected: currentIndex == 3, onTap: () => onSelect(3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? SakhiColors.purple : SakhiColors.mutedPlum;
    return Expanded(
      child: InkWell(
        key: Key('home-bottom-nav-$label'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? activeIcon : icon, size: 23, color: color),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 10.5, color: color, fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewPill extends StatelessWidget {
  const _PreviewPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF2E6FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text('Preview', style: TextStyle(fontSize: 9.5, color: SakhiColors.purple, fontWeight: FontWeight.w700)),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? SakhiColors.purple : const Color(0xFFF7EDF8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: selected ? Colors.white : SakhiColors.plum, fontSize: 11.5, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.title, required this.icon, required this.color, required this.onTap});

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: SakhiColors.purple, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(color: SakhiColors.plum, fontSize: 11.2, fontWeight: FontWeight.w700))),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendedCard extends StatelessWidget {
  const _RecommendedCard({required this.initials, required this.name, required this.subtitle, required this.body, required this.onTap});

  final String initials;
  final String name;
  final String subtitle;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFEFE3ED))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(backgroundColor: const Color(0xFFF2E6FA), child: Text(initials, style: const TextStyle(color: SakhiColors.purple, fontWeight: FontWeight.w800))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w800, color: SakhiColors.plum)),
                  Text(subtitle, style: const TextStyle(fontSize: 10.5, color: SakhiColors.mutedPlum)),
                  const SizedBox(height: 7),
                  Text(body, style: const TextStyle(fontSize: 12, height: 1.35, color: SakhiColors.plum)),
                  const SizedBox(height: 8),
                  const Text('Open preview  ›', style: TextStyle(color: SakhiColors.purple, fontWeight: FontWeight.w700, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.initials,
    required this.author,
    required this.time,
    required this.body,
    required this.liked,
    required this.saved,
    required this.onLike,
    required this.onComment,
    required this.onSave,
  });

  final String initials;
  final String author;
  final String time;
  final String body;
  final bool liked;
  final bool saved;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEFE3ED))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: const Color(0xFFF2E6FA), child: Text(initials, style: const TextStyle(color: SakhiColors.purple, fontWeight: FontWeight.w800))),
              const SizedBox(width: 9),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(author, style: const TextStyle(fontWeight: FontWeight.w800, color: SakhiColors.plum)), Text(time, style: const TextStyle(fontSize: 10.5, color: SakhiColors.mutedPlum))])),
              const Icon(Icons.more_horiz_rounded, color: SakhiColors.mutedPlum),
            ],
          ),
          const SizedBox(height: 12),
          Text(body, style: const TextStyle(fontSize: 13, color: SakhiColors.plum, height: 1.45)),
          const SizedBox(height: 11),
          Container(
            height: 155,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF8E3EF), Color(0xFFE8D8F4), Color(0xFFFFEAD9)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.landscape_rounded, size: 44, color: Color(0xFFAD79B9)),
                SizedBox(height: 4),
                Text('Community photo preview', style: TextStyle(fontSize: 11, color: SakhiColors.mutedPlum)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(onPressed: onLike, icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: liked ? const Color(0xFFE84C88) : SakhiColors.mutedPlum, size: 19), label: Text(liked ? '125' : '124')),
              TextButton.icon(onPressed: onComment, icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19), label: const Text('18')),
              const Spacer(),
              IconButton(tooltip: saved ? 'Remove bookmark' : 'Save post', onPressed: onSave, icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: saved ? SakhiColors.purple : SakhiColors.mutedPlum)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label, required this.onTap});

  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Column(children: [
            Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: SakhiColors.plum)),
            Text(label, style: const TextStyle(fontSize: 11, color: SakhiColors.mutedPlum)),
          ]),
        ),
      ),
    );
  }
}

class _SwitchSettingTile extends StatelessWidget {
  const _SwitchSettingTile({required this.title, required this.subtitle, required this.value, required this.onChanged});

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEFE3ED))),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: SakhiColors.purple,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: SakhiColors.plum)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: SakhiColors.mutedPlum)),
        secondary: const Icon(Icons.tune_rounded, color: SakhiColors.purple),
      ),
    );
  }
}


class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2E6FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          color: SakhiColors.purple,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
