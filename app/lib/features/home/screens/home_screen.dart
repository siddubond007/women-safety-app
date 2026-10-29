import 'package:flutter/material.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_avatar.dart';
import '../../../core/widgets/sakhi_botanical_flower.dart';
import '../../../core/widgets/sakhi_brand_header.dart';
import '../../../core/widgets/sakhi_dialogs.dart';
import '../../../core/widgets/sakhi_search_field.dart';
import '../../../core/widgets/sakhi_section_header.dart';
import '../../explore/screens/explore_discovery_screens.dart';
import '../../eligibility/eligibility_intro_screen.dart';
import '../widgets/for_you_item_card.dart';
import '../widgets/greeting_banner_card.dart';
import '../widgets/quick_action_button.dart';

/// Screen 04 — Refined Home Dashboard
class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;
  final ValueChanged<String>? onNavigateRoute;

  const HomeScreen({super.key, this.onNavigateTab, this.onNavigateRoute});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

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

  void _openEligibilityVerification() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DecentroDigilockerVerificationScreen(),
      ),
    );
  }

  void _openSearchResults() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SearchResultsScreen(initialQuery: _searchController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final displayName = state.currentUser.displayName.trim();
        final userName = displayName.isEmpty || displayName == 'Sakhi Member'
            ? 'Ananya'
            : displayName.split(RegExp(r'\s+')).first;
        final postsCount = state.communityPosts.isNotEmpty
            ? state.communityPosts.length
            : 14;
        final circlesCount = state.groups.isNotEmpty ? state.groups.length : 6;

        return SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SakhiBrandHeader(
                  title: 'Sakhi',
                  actions: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
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
                        Positioned(
                          right: 11,
                          top: 11,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE03E6D),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SakhiAvatar(
                      imageAsset: state.currentUser.avatarAsset,
                      fallbackLabel: state.currentUser.displayName,
                      size: 34,
                      onAvatarTap: () => _openTab(3, AppRoutes.profile),
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
                      SakhiSearchField(
                        hintText: 'Search people, topics, circles...',
                        controller: _searchController,
                        onTap: _openSearchResults,
                        onChanged: (_) {},
                        onClear: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 14),
                      GreetingBannerCard(
                        userName: userName,
                        onTap: () => SakhiDialogs.showPrototypeSnackbar(
                          context,
                          'Good morning, $userName! Explore your daily wellness & safety tools.',
                        ),
                      ),
                      const SizedBox(height: 18),
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
                            onTap: () => _openTab(4, AppRoutes.safety),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      ForYouItemCard(
                        key: const Key('home-eligibility-verification-card'),
                        icon: Icons.verified_user_outlined,
                        iconColor: AppColors.primaryPurple,
                        iconBgColor: AppColors.pastelLavender,
                        title: 'Female Eligibility Verification',
                        subtitle: 'Open Decentro DigiLocker verification or run the staging demo',
                        badgeText: 'Verify',
                        flowerType: SakhiFlowerType.roseClassic,
                        onTap: _openEligibilityVerification,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        key: const Key('home-discreet-complaint-card'),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFF0F6),
                              Color(0xFFF5E6FA),
                              Color(0xFFEDE0F6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFFDCC0E8),
                            width: 1.4,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x145A1868),
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () =>
                              _openRoute(AppRoutes.discreetComplaintHub),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: SizedBox(
                                        width: 88,
                                        height: 88,
                                        child: Image.asset(
                                          AppAssets.m5HeroSafeVoice,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            color: AppColors.pastelLavender,
                                            child: const Icon(
                                              Icons.shield_moon_rounded,
                                              size: 38,
                                              color: AppColors.primaryPurple,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 9,
                                              vertical: 3.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.9,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              '100% PRIVATE • SAFE VOICE',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.5,
                                                color: AppColors.primaryPurple,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Report a Safety Concern',
                                            style: AppTypography.cardTitle
                                                .copyWith(
                                                  fontSize: 16,
                                                  height: 1.2,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Privately report harassment, stalking, cyberbullying, or workplace issues—anonymously or confidentially.',
                                            style: AppTypography.subtitle
                                                .copyWith(
                                                  fontSize: 12,
                                                  height: 1.35,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              AppColors.primaryPurple,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                        ),
                                        onPressed: () => _openRoute(
                                          AppRoutes.discreetComplaintHub,
                                        ),
                                        icon: const Icon(
                                          Icons.shield_outlined,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Report Safely',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              AppColors.primaryPurple,
                                          backgroundColor: Colors.white
                                              .withValues(alpha: 0.85),
                                          side: const BorderSide(
                                            color: AppColors.primaryPurple,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                        ),
                                        onPressed: () => _openRoute(
                                          AppRoutes.complaintTracker,
                                        ),
                                        icon: const Icon(
                                          Icons.manage_search_rounded,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Track My Report',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SakhiSectionHeader(
                        title: 'For You Today',
                        actionLabel: 'See all >',
                        onActionTap: () => _openTab(2, AppRoutes.community),
                      ),
                      const SizedBox(height: 10),
                      if (!state.isBackendSynced)
                        const SizedBox(
                          height: 0,
                          child: Opacity(
                            opacity: 0.01,
                            child: Text('Community posts unavailable'),
                          ),
                        ),
                      ForYouItemCard(
                        icon: Icons.forum_outlined,
                        iconColor: AppColors.primaryPurple,
                        iconBgColor: AppColors.pastelLavender,
                        title: '$postsCount new posts in Community',
                        subtitle: "Join today's top discussions & stories",
                        badgeText: 'New',
                        flowerType: SakhiFlowerType.cherryBlossom,
                        onTap: () => _openTab(2, AppRoutes.community),
                      ),
                      const SizedBox(height: 10),
                      ForYouItemCard(
                        icon: Icons.groups_2_outlined,
                        iconColor: AppColors.wellnessGreen,
                        iconBgColor: AppColors.pastelMint,
                        title: '$circlesCount active circles near you',
                        subtitle: 'Connect with verified women in your area (Live GPS)',
                        badgeText: 'Active',
                        flowerType: SakhiFlowerType.eucalyptusSage,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const NearbyCirclesScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ForYouItemCard(
                        icon: Icons.verified_user_outlined,
                        iconColor: const Color(0xFFD63E85),
                        iconBgColor: AppColors.pastelPink,
                        title: 'Safety & Helpline Directory',
                        subtitle: '24/7 verified support & emergency contacts',
                        flowerType: SakhiFlowerType.roseClassic,
                        onTap: () => _openTab(4, AppRoutes.safety),
                      ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: () => _openRoute(AppRoutes.wellness),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFF4E6FA), Color(0xFFFDF0F6)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primaryPurple.withValues(
                                alpha: 0.14,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 13,
                                          color: AppColors.primaryPurple,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'DAILY WELLNESS RITUAL',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.6,
                                            color: AppColors.primaryPurple,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '5-Minute Calm Breathing & Grounding',
                                      style: AppTypography.cardTitle.copyWith(
                                        fontSize: 15,
                                        height: 1.22,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Take a mindful pause with guided breathing.',
                                      style: AppTypography.subtitle.copyWith(
                                        fontSize: 12,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.asset(
                                      AppAssets.dailyRitualBreathingThumb,
                                      width: 68,
                                      height: 68,
                                      fit: BoxFit.cover,
                                      filterQuality: FilterQuality.high,
                                    ),
                                  ),
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF5D196A)
                                          .withValues(alpha: 0.88),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
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
