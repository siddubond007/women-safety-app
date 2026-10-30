import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_card.dart';
import '../../../core/widgets/sakhi_chip.dart';
import '../../../core/widgets/sakhi_empty_state.dart';
import '../../../core/widgets/sakhi_search_field.dart';
import '../../../core/widgets/sakhi_section_header.dart';
import '../../business/screens/business_hub_screen.dart';
import '../../community/widgets/feed_post_card.dart';
import 'explore_discovery_screens.dart';

/// Explore and community discovery using live state supplied by the backend.
class ExploreScreen extends StatefulWidget {
  final ValueChanged<String>? onNavigateRoute;

  const ExploreScreen({super.key, this.onNavigateRoute});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  static const _filters = [
    'All',
    'Posts',
    'Groups',
    'Businesses',
    'Experts',
    'Events',
  ];
  static const _starterTopics = [
    '#SafeCommute',
    '#PCOSWellness',
    '#CareerMentorship',
    '#MentalWellness',
    '#WomenInTech',
    '#SafetyTips',
    '#WomenOwnedBusiness',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openSearch([String query = '']) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchResultsScreen(initialQuery: query),
      ),
    );
  }

  void _openCategory(String slug, String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CategoryDestinationScreen(categorySlug: slug, title: title),
      ),
    );
  }

  void _openBusinessMarketplace() {
    if (widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(AppRoutes.businessHub);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const WomenBusinessHubScreen(showBackButton: true),
        ),
      );
    }
  }

  Future<void> _showCreateCircleDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedCat = 'Community & Support';

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Create a Sakhi Circle',
            style: AppTypography.sectionTitle,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Circle Name *',
                    hintText: 'e.g., Hyderabad Women Entrepreneurs',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedCat,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Community & Support',
                      child: Text('Community & Support'),
                    ),
                    DropdownMenuItem(
                      value: 'Health & Wellness',
                      child: Text('Health & Wellness'),
                    ),
                    DropdownMenuItem(
                      value: 'Safety & Commute',
                      child: Text('Safety & Commute'),
                    ),
                    DropdownMenuItem(
                      value: 'Career & Business',
                      child: Text('Career & Business'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedCat = val);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Purpose / Description',
                    hintText: 'What will members discuss and share here?',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.length < 3) return;
                await SakhiPrototypeState.instance.joinOrCreateCommunityCircle(
                  name,
                  description: descCtrl.text.trim().isNotEmpty
                      ? descCtrl.text.trim()
                      : 'Verified Sakhi community circle for women.',
                  category: selectedCat,
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Create & Join'),
            ),
          ],
        ),
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Community Circle created and joined!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final liveTags = state.trendingHashtags;
        final topics = <String>{..._starterTopics, ...liveTags}.toList();
        final groups = state.groups;
        final posts = state.exploreRecommendedPosts.isNotEmpty
            ? state.exploreRecommendedPosts
            : state.communityPosts;

        return SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColors.primaryPurple,
            onRefresh: () => state.syncFromBackend(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingH,
                8,
                AppSpacing.screenPaddingH,
                132,
              ),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Explore Sakhi',
                      style: AppTypography.appBarTitle,
                    ),
                    Text(
                      'Explore topics',
                      style: AppTypography.subtitle.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SakhiSearchField(
                  hintText: 'Search people, topics, circles, businesses...',
                  controller: _searchController,
                  onTap: () => _openSearch(_searchController.text.trim()),
                  onSubmitted: _openSearch,
                  onChanged: (_) => setState(() {}),
                  onClear: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _filters.map((filter) {
                      final selected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SakhiChip(
                          label: filter,
                          isSelected: selected,
                          onTap: () {
                            if (filter == 'Businesses') {
                              _openBusinessMarketplace();
                              return;
                            }
                            setState(() => _selectedFilter = filter);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 18),

                // Module 6 Featured Women-Owned Business Marketplace Banner
                InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: _openBusinessMarketplace,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppColors.businessLuxuryGradient,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFE6C88A),
                        width: 1.3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x145D196A),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE6C88A)),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: Color(0xFFB45309),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'MODULE 6 • VERIFIED MARKETPLACE',
                                  style: AppTypography.businessCategoryPill
                                      .copyWith(fontSize: 9.5),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Women-Owned Business Pages',
                                style: AppTypography.businessCardTitle.copyWith(
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Explore ${state.businesses.isNotEmpty ? "${state.businesses.length} " : ""}verified women entrepreneurs, products, services & direct enquiries.',
                                style: AppTypography.subtitle.copyWith(
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: AppColors.primaryPurple,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Trending Topics',
                      style: AppTypography.sectionTitle,
                    ),
                    TextButton(
                      onPressed: () => _openSearch('#MentalWellness'),
                      child: const Text('See all ›'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: topics.map((tag) {
                    return SakhiChip(
                      label: tag,
                      onTap: () => _openSearch(tag),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),
                const SakhiSectionHeader(title: 'Browse by Category'),
                const SizedBox(height: 12),
                GridView.count(
                  padding: EdgeInsets.zero,
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.98,
                  children: [
                    _CategoryCard(
                      title: 'Health & Wellness',
                      subtitle: 'Mind, body & wellbeing',
                      icon: Icons.favorite_border_rounded,
                      assetPath: AppAssets.dailyRitualBreathingThumb,
                      color: const Color(0xFFF5EBF9),
                      onTap: () =>
                          _openCategory('health_wellness', 'Health & Wellness'),
                    ),
                    _CategoryCard(
                      title: 'Safety & Support',
                      subtitle: 'Tips & trusted resources',
                      icon: Icons.shield_outlined,
                      assetPath: AppAssets.emptySafetyShieldIllustration,
                      color: const Color(0xFFFDECEF),
                      onTap: () =>
                          _openCategory('safety_awareness', 'Safety & Support'),
                    ),
                    _CategoryCard(
                      title: 'Education & Career',
                      subtitle: 'Learning & mentorship',
                      icon: Icons.school_outlined,
                      assetPath: AppAssets.educationCareerHubBanner,
                      color: const Color(0xFFE8F5F2),
                      onTap: () => _openCategory(
                        'education_career',
                        'Education & Career',
                      ),
                    ),
                    _CategoryCard(
                      title: 'Community Stories',
                      subtitle: 'Interests & inspiration',
                      icon: Icons.spa_outlined,
                      assetPath: AppAssets.greetingHeroIllustration,
                      color: const Color(0xFFFFF1E8),
                      onTap: () => _openCategory(
                        'lifestyle_hobbies',
                        'Community Stories',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (_selectedFilter == 'All' ||
                    _selectedFilter == 'Groups') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Circles Near You (${groups.length})',
                        style: AppTypography.sectionTitle,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            onPressed: _showCreateCircleDialog,
                            icon: const Icon(Icons.add_circle_outline, size: 16),
                            label: const Text('Create'),
                          ),
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const NearbyCirclesScreen(),
                              ),
                            ),
                            icon: const Icon(
                              Icons.my_location_rounded,
                              size: 16,
                            ),
                            label: const Text('Near Me ›'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (groups.isEmpty)
                    SakhiEmptyState(
                      icon: Icons.groups_outlined,
                      title: 'No Community Circles Created Yet',
                      message:
                          'Start the first verified Sakhi circle in your neighbourhood or interest area so women near you can join.',
                      actionLabel: '+ Create a Community Circle',
                      onAction: _showCreateCircleDialog,
                    )
                  else
                    ...groups.take(6).map(
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          group.name,
                                          style: AppTypography.cardTitle,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${group.membersCount} member${group.membersCount == 1 ? '' : 's'} · ${group.description}',
                                          style: AppTypography.subtitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SakhiJoinCircleButton(circleName: group.name),
                                ],
                              ),
                            ),
                          ),
                        ),
                ],
                if (_selectedFilter == 'All' || _selectedFilter == 'Posts') ...[
                  const SizedBox(height: 12),
                  const SakhiSectionHeader(title: 'Recommended for you'),
                  const SizedBox(height: 10),
                  if (posts.isEmpty)
                    SakhiEmptyState(
                      icon: Icons.auto_awesome_outlined,
                      title: 'No recommendations yet',
                      message: state.isBackendSynced
                          ? 'We could not find community posts to recommend right now.'
                          : 'Connect to Sakhi to load recommendations from real community posts.',
                      actionLabel: state.isBackendSynced ? null : 'Retry',
                      onAction: state.isBackendSynced
                          ? null
                          : () => unawaited(state.syncFromBackend()),
                    )
                  else
                    ...posts.take(6).map(
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
                if (_selectedFilter == 'Experts') ...[
                  const SakhiEmptyState(
                    icon: Icons.verified_user_outlined,
                    title: 'Expert directory unavailable',
                    message:
                        'The connected API does not yet expose a dedicated verified-expert directory. Sakhi will not display invented expert profiles.',
                  ),
                ],
                if (_selectedFilter == 'Events') ...[
                  const SakhiEmptyState(
                    icon: Icons.event_outlined,
                    title: 'No events available',
                    message:
                        'Events will appear when an event feed is provided by the connected Sakhi API.',
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.assetPath,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String assetPath;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(assetPath, fit: BoxFit.cover),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            icon,
                            color: AppColors.primaryPurple,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
