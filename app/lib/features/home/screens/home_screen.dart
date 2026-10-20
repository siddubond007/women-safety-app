import 'package:flutter/material.dart';

import '../../../core/constants/mock_data.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_botanical_flower.dart';
import '../../../core/widgets/sakhi_brand_header.dart';
import '../../../core/widgets/sakhi_dialogs.dart';
import '../../../core/widgets/sakhi_search_field.dart';
import '../../../core/widgets/sakhi_section_header.dart';
import '../../community/widgets/feed_post_card.dart';
import '../widgets/for_you_item_card.dart';
import '../widgets/greeting_banner_card.dart';
import '../widgets/quick_action_button.dart';

/// Screen 1 — Home Dashboard (Main)
class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;
  final ValueChanged<String>? onNavigateRoute;

  const HomeScreen({super.key, this.onNavigateTab, this.onNavigateRoute});

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

  void _openTab(int index, String fallbackRoute) {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(index);
    } else {
      Navigator.of(context).pushNamed(fallbackRoute);
    }
  }

  void _openRoute(String routeName) {
    if (widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(routeName);
    } else {
      Navigator.of(context).pushNamed(routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final userName = state.currentUser.displayName;
        final featuredPost =
            state.isBackendSynced && state.communityPosts.isNotEmpty
            ? state.communityPosts.first
            : null;
        return SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top App Branding & Actions
                SakhiBrandHeader(
                  title: 'Sakhi',
                  actions: [
                    IconButton(
                      tooltip: 'Notifications',
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: AppColors.primaryPurple,
                        size: 25,
                      ),
                      onPressed: () =>
                          _openRoute(AppRoutes.notificationPreferences),
                    ),
                    IconButton(
                      tooltip: 'Profile',
                      icon: const Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.primaryPurple,
                        size: 25,
                      ),
                      onPressed: () => _openTab(3, AppRoutes.profile),
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search Field
                      SakhiSearchField(
                        hintText: 'Search people, topics, groups...',
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        onClear: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                      if (_searchQuery.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.pastelLavender,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.travel_explore_rounded,
                                size: 18,
                                color: AppColors.primaryPurple,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Searching Sakhi for "$_searchQuery"... Tap Explore for full results.',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Live PostgreSQL Sync Status Pill
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (state.isBackendSynced
                                      ? AppColors.pastelMint
                                      : AppColors.pastelLavender)
                                  .withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                (state.isBackendSynced
                                        ? AppColors.wellnessGreen
                                        : AppColors.primaryPurple)
                                    .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              state.isBackendSynced
                                  ? Icons.cloud_done_rounded
                                  : (state.isBackendSyncing
                                        ? Icons.sync_rounded
                                        : Icons.cloud_off_rounded),
                              size: 16,
                              color: state.isBackendSynced
                                  ? AppColors.wellnessGreen
                                  : AppColors.primaryPurple,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                state.isBackendSynced
                                    ? 'LIVE POSTGRESQL DB • ${state.totalDatabasePosts} Posts • ${state.totalDatabaseMembers} Members'
                                    : (state.isBackendSyncing
                                          ? 'CONNECTING TO POSTGRESQL…'
                                          : (state.lastSyncError ??
                                                'LIVE DATA UNAVAILABLE')),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                await state.syncFromBackend();
                                if (!context.mounted) return;
                                SakhiDialogs.showPrototypeSnackbar(
                                  context,
                                  state.lastSyncError ?? 'Synced latest live records from PostgreSQL!',
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                  color: AppColors.primaryPurple,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Personalized Greeting Card with Crisp Hero & Reusable Flowers
                      GreetingBannerCard(
                        userName: userName,
                        onTap: () => SakhiDialogs.showPrototypeSnackbar(
                          context,
                          'Good morning, $userName! Explore your daily wellness & safety tools.',
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Four Quick-Access Actions: Explore, Community, Wellness, SOS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          QuickActionButton(
                            label: 'Explore',
                            icon: Icons.explore_outlined,
                            circleColor: AppColors.pastelLavender,
                            iconColor: AppColors.primaryPurple,
                            onTap: () => _openTab(1, AppRoutes.explore),
                          ),
                          QuickActionButton(
                            label: 'Community',
                            icon: Icons.groups_rounded,
                            circleColor: AppColors.pastelPink,
                            iconColor: const Color(0xFFD63E85),
                            onTap: () => _openTab(2, AppRoutes.community),
                          ),
                          QuickActionButton(
                            label: 'Wellness',
                            icon: Icons.spa_rounded,
                            circleColor: AppColors.pastelMint,
                            iconColor: AppColors.wellnessGreen,
                            onTap: () => _openRoute(AppRoutes.wellness),
                          ),
                          QuickActionButton(
                            label: 'SOS Safety',
                            icon: Icons.shield_rounded,
                            circleColor: AppColors.sosRedSoft,
                            iconColor: AppColors.sosRed,
                            onTap: () => _openRoute(AppRoutes.safety),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Personalized Content Section with Distinct Botanical Flowers
                      SakhiSectionHeader(
                        title: 'For You Today',
                        actionLabel: 'See all',
                        onActionTap: () => _openTab(2, AppRoutes.community),
                      ),
                      const SizedBox(height: 12),

                      ForYouItemCard(
                        icon: Icons.auto_awesome_rounded,
                        iconColor: AppColors.primaryPurple,
                        iconBgColor: AppColors.pastelLavender,
                        title: state.isBackendSynced
                            ? '${state.communityPosts.length} new posts'
                            : 'Live posts unavailable',
                        subtitle: state.isBackendSynced
                            ? 'Fresh stories from the live Sakhi community'
                            : 'Sign in to load real posts from PostgreSQL.',
                        badgeText: 'New',
                        flowerType: SakhiFlowerType.cherryBlossom,
                        onTap: () => _openTab(2, AppRoutes.community),
                      ),
                      const SizedBox(height: 10),

                      ForYouItemCard(
                        icon: Icons.groups_2_rounded,
                        iconColor: AppColors.wellnessGreen,
                        iconBgColor: AppColors.pastelMint,
                        title: state.isBackendSynced
                            ? '${state.groups.length} active circles'
                            : 'Live circles unavailable',
                        subtitle: state.isBackendSynced
                            ? 'Member circles loaded from the backend'
                            : 'Circle data appears after a live connection.',
                        badgeText: 'Active',
                        flowerType: SakhiFlowerType.eucalyptusSage,
                        onTap: () => _openTab(2, AppRoutes.community),
                      ),
                      const SizedBox(height: 10),

                      ForYouItemCard(
                        icon: Icons.verified_user_outlined,
                        iconColor: const Color(0xFFD63E85),
                        iconBgColor: AppColors.pastelPink,
                        title: 'Safety & Helpline Hub',
                        subtitle: 'Trusted contacts, live check-in & verified resources',
                        badgeText: '24/7',
                        flowerType: SakhiFlowerType.roseClassic,
                        onTap: () => _openRoute(AppRoutes.safety),
                      ),

                      const SizedBox(height: 24),
                      // Daily Wellness & Mindfulness Spotlight Card
                      GestureDetector(
                        onTap: () => _openRoute(AppRoutes.wellness),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFF5ECFB), Color(0xFFFDF2F7)],
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: AppColors.primaryPurple.withValues(
                                alpha: 0.14,
                              ),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              const Positioned(
                                right: -6,
                                top: -10,
                                child: SakhiBotanicalFlower(
                                  type: SakhiFlowerType.lilyBloom,
                                  width: 78,
                                  height: 96,
                                  opacity: 0.65,
                                  angle: -0.15,
                                ),
                              ),
                              const Positioned(
                                right: 54,
                                bottom: -18,
                                child: SakhiBotanicalFlower(
                                  type: SakhiFlowerType.cosmosViolet,
                                  width: 62,
                                  height: 78,
                                  opacity: 0.45,
                                  angle: 0.18,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 84),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'DAILY WELLNESS RITUAL',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.7,
                                        color: AppColors.primaryPurple,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '5-Minute Calm Breathing & Grounding',
                                      style: AppTypography.cardTitle.copyWith(
                                        fontSize: 16,
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Take a mindful pause with guided audio and cycle wellness guides.',
                                      style: AppTypography.subtitle.copyWith(
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (featuredPost != null) ...[
                        const SizedBox(height: 24),
                        SakhiSectionHeader(
                          title: 'Community Highlights',
                          actionLabel: 'Open feed',
                          onActionTap: () => _openTab(2, AppRoutes.community),
                        ),
                        const SizedBox(height: 12),
                        FeedPostCard(
                          post: featuredPost,
                          showVerifiedCheck: true,
                          onLikeTap: () => state.togglePostLike(featuredPost),
                          onSaveTap: () => state.togglePostSaved(featuredPost),
                        ),
                      ],
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
