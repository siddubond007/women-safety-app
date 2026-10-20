import 'package:flutter/material.dart';

import '../../../core/constants/mock_data.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_botanical_flower.dart';
import '../../../core/widgets/sakhi_chip.dart';
import '../../../core/widgets/sakhi_dialogs.dart';
import '../../../core/widgets/sakhi_search_field.dart';
import '../../../core/widgets/sakhi_section_header.dart';
import '../../community/widgets/feed_post_card.dart';
import '../widgets/explore_category_card.dart';

/// Screen 2 — Explore & Community Discovery
class ExploreScreen extends StatefulWidget {
  final ValueChanged<String>? onNavigateRoute;

  const ExploreScreen({super.key, this.onNavigateRoute});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _selectedFilter = 'All';
  String? _selectedHashtag;
  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final topicTags = state.isBackendSynced
            ? state.communityPosts
                  .expand((post) => post.hashtags)
                  .map((tag) => tag.startsWith('#') ? tag : '#$tag')
                  .toSet()
                  .toList()
            : <String>[];

        return SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPaddingH,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Explore', style: AppTypography.appBarTitle),
                      IconButton(
                        tooltip: 'Search Explore',
                        icon: Icon(
                          _showSearchBar
                              ? Icons.close_rounded
                              : Icons.search_rounded,
                          color: AppColors.primaryPurple,
                          size: 25,
                        ),
                        onPressed: () {
                          setState(() {
                            _showSearchBar = !_showSearchBar;
                            if (!_showSearchBar) _searchController.clear();
                          });
                        },
                      ),
                    ],
                  ),

                  if (_showSearchBar) ...[
                    const SizedBox(height: 6),
                    SakhiSearchField(
                      hintText: 'Search topics, groups, experts...',
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      onClear: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: state.exploreFilters.map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: SakhiChip(
                            label: filter,
                            isSelected: isSelected,
                            onTap: () =>
                                setState(() => _selectedFilter = filter),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 20),
                  SakhiSectionHeader(
                    title: state.isBackendSynced
                        ? 'Topics from live posts'
                        : 'Explore topics',
                  ),
                  const SizedBox(height: 10),

                  if (topicTags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: topicTags.map((tag) {
                        final selected = _selectedHashtag == tag;
                        return SakhiChip(
                          label: tag,
                          isSelected: selected,
                          onTap: () {
                            setState(() {
                              _selectedHashtag = selected ? null : tag;
                            });
                            SakhiDialogs.showPrototypeSnackbar(
                              context,
                              selected
                                  ? 'Cleared topic filter'
                                  : 'Filtering by $tag',
                            );
                          },
                        );
                      }).toList(),
                    )
                  else
                    Text(
                      state.isBackendSynced
                          ? 'Hashtags will appear here as members publish posts.'
                          : 'Sign in to discover topics from real community posts.',
                      style: AppTypography.subtitle,
                    ),

                  const SizedBox(height: 18),
                  // 2x2 Category Cards with distinct reusable botanical flowers
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.0,
                    children: [
                      ExploreCategoryCard(
                        title: 'Health &\nWellness',
                        icon: Icons.favorite_border_rounded,
                        backgroundColor: const Color(0xFFEEEBFA),
                        iconColor: AppColors.infoBlue,
                        flowerType: SakhiFlowerType.lilyBloom,
                        onTap: () {
                          if (widget.onNavigateRoute != null) {
                            widget.onNavigateRoute!(AppRoutes.wellness);
                          } else {
                            Navigator.of(context).pushNamed(AppRoutes.wellness);
                          }
                        },
                      ),
                      ExploreCategoryCard(
                        title: 'Safety &\nAwareness',
                        icon: Icons.shield_outlined,
                        backgroundColor: const Color(0xFFFDECEB),
                        iconColor: const Color(0xFFE0533C),
                        flowerType: SakhiFlowerType.hibiscusRose,
                        onTap: () {
                          if (widget.onNavigateRoute != null) {
                            widget.onNavigateRoute!(AppRoutes.safety);
                          } else {
                            Navigator.of(context).pushNamed(AppRoutes.safety);
                          }
                        },
                      ),
                      ExploreCategoryCard(
                        title: 'Education\n& Career',
                        icon: Icons.school_outlined,
                        backgroundColor: const Color(0xFFE6F6F4),
                        iconColor: const Color(0xFF1F7AE0),
                        flowerType: SakhiFlowerType.tulipDuo,
                        onTap: () => SakhiDialogs.showPrototypeSnackbar(
                          context,
                          'Opening Education & Career community resources...',
                        ),
                      ),
                      ExploreCategoryCard(
                        title: 'Lifestyle\n& Hobbies',
                        icon: Icons.self_improvement_rounded,
                        backgroundColor: const Color(0xFFF3EAFC),
                        iconColor: AppColors.primaryPurple,
                        flowerType: SakhiFlowerType.cosmosViolet,
                        onTap: () => SakhiDialogs.showPrototypeSnackbar(
                          context,
                          'Opening Lifestyle & Hobbies circles...',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),
                  SakhiSectionHeader(
                    title: 'Recommended for you',
                    actionLabel: 'See all',
                    onActionTap: () => SakhiDialogs.showPrototypeSnackbar(
                      context,
                      'Showing all recommended posts for $_selectedFilter.',
                    ),
                  ),
                  const SizedBox(height: 12),

                  ...state.exploreRecommendedPosts.map(
                    (post) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: FeedPostCard(
                        post: post,
                        onLikeTap: () => state.togglePostLike(post),
                        onSaveTap: () => state.togglePostSaved(post),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
