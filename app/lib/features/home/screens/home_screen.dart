import 'package:flutter/material.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/sakhi_brand_header.dart';
import '../../../core/widgets/sakhi_search_field.dart';
import '../../../core/widgets/sakhi_section_header.dart';
import '../widgets/for_you_item_card.dart';
import '../widgets/greeting_banner_card.dart';
import '../widgets/quick_action_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onNavigateTab, this.onNavigateRoute});
  final ValueChanged<int>? onNavigateTab;
  final ValueChanged<String>? onNavigateRoute;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _goRoute(String route) {
    SakhiPrototypeState.instance.searchQuery = _searchQuery.trim();
    final handler = widget.onNavigateRoute;
    if (handler != null) {
      handler(route);
    } else {
      Navigator.of(context).pushNamed(route);
    }
  }

  void _goTab(int tab) {
    SakhiPrototypeState.instance.searchQuery = _searchQuery.trim();
    final handler = widget.onNavigateTab;
    if (handler != null) {
      handler(tab);
    } else {
      final route = tab == 1 ? AppRoutes.explore : tab == 2 ? AppRoutes.community : AppRoutes.profile;
      Navigator.of(context).pushNamed(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final name = state.currentUser.displayName.trim();
        final firstLine = name.isEmpty ? 'Welcome to Sakhi' : 'Good Morning';
        final postsCount = state.currentUser.postsCount;
        final feedCount = state.communityPosts.length;
        return SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SakhiBrandHeader(
                  title: 'Sakhi',
                  actions: [
                    IconButton(
                      tooltip: 'Notification preferences',
                      icon: const Icon(Icons.notifications_none_rounded, color: AppColors.primaryPurple, size: 25),
                      onPressed: () => _goRoute(AppRoutes.notificationPreferences),
                    ),
                    IconButton(
                      tooltip: 'Profile',
                      icon: const Icon(Icons.person_outline_rounded, color: AppColors.primaryPurple, size: 25),
                      onPressed: () => _goTab(3),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Account options',
                      onSelected: (value) {
                        if (value == 'more') _goRoute(AppRoutes.moreOptions);
                        if (value == 'security') _goRoute(AppRoutes.accountSecurity);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'more', child: Text('More options')),
                        PopupMenuItem(value: 'security', child: Text('Account & security')),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SakhiSearchField(
                        hintText: 'Search people, topics, groups...',
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                          state.searchQuery = value;
                        },
                        onSubmitted: (value) {
                          state.searchQuery = value;
                          _goTab(1);
                        },
                        onClear: () {
                          _searchController.clear();
                          state.searchQuery = '';
                          setState(() => _searchQuery = '');
                        },
                      ),
                      if (_searchQuery.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Material(
                          color: AppColors.pastelLavender,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _goTab(1),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(children: [
                                const Icon(Icons.travel_explore_rounded, size: 18, color: AppColors.primaryPurple),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Search for "' + _searchQuery.trim() + '" across member profiles and posts.', style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary))),
                                const Icon(Icons.arrow_forward_rounded, color: AppColors.primaryPurple, size: 18),
                              ]),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      GreetingBannerCard(
                        userName: name,
                        greeting: firstLine,
                        onTap: () => _goRoute(AppRoutes.wellness),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          QuickActionButton(
                            label: 'Explore',
                            icon: Icons.search_rounded,
                            circleColor: AppColors.pastelLavender,
                            iconColor: AppColors.primaryPurple,
                            onTap: () => _goTab(1),
                          ),
                          QuickActionButton(
                            label: 'Community',
                            icon: Icons.groups_rounded,
                            circleColor: AppColors.pastelPink,
                            iconColor: const Color(0xFFD63E85),
                            onTap: () => _goTab(2),
                          ),
                          QuickActionButton(
                            label: 'Wellness',
                            icon: Icons.spa_rounded,
                            circleColor: AppColors.pastelMint,
                            iconColor: AppColors.wellnessGreen,
                            onTap: () => _goRoute(AppRoutes.wellness),
                          ),
                          QuickActionButton(
                            label: 'SOS',
                            icon: Icons.sos_rounded,
                            circleColor: AppColors.sosRedSoft,
                            iconColor: AppColors.sosRed,
                            onTap: () => _goRoute(AppRoutes.safety),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      SakhiSectionHeader(
                        title: 'For You Today',
                        actionLabel: 'See all',
                        onActionTap: () => _goTab(2),
                      ),
                      const SizedBox(height: 12),
                      ForYouItemCard(
                        icon: Icons.person_pin_circle_outlined,
                        iconColor: AppColors.primaryPurple,
                        iconBgColor: AppColors.pastelLavender,
                        title: postsCount.toString() + ' posts on your profile',
                        subtitle: postsCount == 0 ? 'Share your first update with verified members' : 'Open your profile and manage your posts',
                        onTap: () => _goTab(3),
                      ),
                      const SizedBox(height: 10),
                      ForYouItemCard(
                        icon: Icons.groups_2_rounded,
                        iconColor: AppColors.wellnessGreen,
                        iconBgColor: AppColors.pastelMint,
                        title: feedCount.toString() + ' community posts available',
                        subtitle: feedCount == 0 ? 'Your verified community feed is ready for its first post' : 'Read posts from verified Sakhi members',
                        onTap: () => _goTab(2),
                      ),
                      const SizedBox(height: 10),
                      ForYouItemCard(
                        icon: Icons.health_and_safety_outlined,
                        iconColor: AppColors.amberAccent,
                        iconBgColor: AppColors.pastelPeach,
                        title: 'Safety and wellness resources',
                        subtitle: 'Review practical guidance and wellbeing tools',
                        onTap: () => _goRoute(AppRoutes.safety),
                      ),
                      if (state.isLoading) ...[
                        const SizedBox(height: 16),
                        const Center(child: CircularProgressIndicator()),
                      ],
                      const SizedBox(height: 12),
                      if (state.backend?.errorMessage != null)
                        Text(state.backend!.errorMessage!, style: const TextStyle(color: AppColors.sosRed, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
