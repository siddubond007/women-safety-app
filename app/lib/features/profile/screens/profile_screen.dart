import 'package:flutter/material.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_avatar.dart';
import '../../../core/widgets/sakhi_botanical_flower.dart';
import '../../../core/widgets/sakhi_brand_header.dart';
import '../../../core/widgets/sakhi_buttons.dart';
import '../../../core/widgets/sakhi_chip.dart';
import '../../../core/widgets/sakhi_dialogs.dart';
import '../../../core/widgets/sakhi_empty_state.dart';
import '../../community/widgets/feed_post_card.dart';

/// Screen 6 — Profile Overview
class ProfileScreen extends StatefulWidget {
  final ValueChanged<String>? onNavigateRoute;

  const ProfileScreen({super.key, this.onNavigateRoute});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedTabIndex = 0; // 0: Posts, 1: Saved, 2: Groups

  void _navigateTo(BuildContext context, String routeName) {
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
        final user = state.currentUser;
        return SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header with Shield Logo & Settings Gear Action
                SakhiBrandHeader(
                  title: 'Profile',
                  useShieldEmblem: true,
                  actions: [
                    IconButton(
                      tooltip: 'More Options & Settings',
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: AppColors.primaryPurple,
                        size: 24,
                      ),
                      onPressed: () =>
                          _navigateTo(context, AppRoutes.moreOptions),
                    ),
                  ],
                ),

                // Decorative Botanical Header + Standalone Flowers + Overlapping Circular Avatar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH,
                  ),
                  child: Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: SizedBox(
                          height: 118,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                AppAssets.profileHeaderBanner,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (_, _, _) => Container(
                                  color: AppColors.pastelPink,
                                ),
                              ),
                              const Positioned(
                                left: 10,
                                top: -6,
                                child: SakhiBotanicalFlower(
                                  type: SakhiFlowerType.cherryBlossom,
                                  width: 82,
                                  height: 106,
                                  opacity: 0.78,
                                  angle: 0.16,
                                ),
                              ),
                              const Positioned(
                                right: 10,
                                top: -6,
                                child: SakhiBotanicalFlower(
                                  type: SakhiFlowerType.orchidBranch,
                                  width: 82,
                                  height: 106,
                                  opacity: 0.78,
                                  angle: -0.16,
                                  flipHorizontal: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 26),
                        child: SakhiAvatar(
                          imageAsset: user.avatarAsset,
                          size: 108,
                          borderWidth: 3.5,
                          showEditCameraBadge: true,
                          onCameraTap: () =>
                              _navigateTo(context, AppRoutes.editProfile),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                // Display Name, Verification Badge, Username & Edit Profile
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user.displayName,
                                style: AppTypography.appBarTitle.copyWith(
                                  fontSize: 21,
                                ),
                              ),
                              if (user.verificationStatus == 'VERIFIED') ...[
                                const SizedBox(width: 5),
                                GestureDetector(
                                  onTap: () =>
                                      SakhiDialogs.showPrototypeSnackbar(
                                    context,
                                    'Account verified by Sakhi Super Admin.',
                                  ),
                                  child: const Icon(
                                    Icons.verified_rounded,
                                    color: AppColors.primaryPurple,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(user.username, style: AppTypography.subtitle),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: SakhiPillButton(
                          label: 'Edit Profile',
                          isFilled: false,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          onPressed: () =>
                              _navigateTo(context, AppRoutes.editProfile),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                // Post, Follower, and Following Counts
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ProfileStatColumn(
                        count: '${user.postsCount}',
                        label: 'Posts',
                        onTap: () => setState(() => _selectedTabIndex = 0),
                      ),
                      Container(
                        height: 28,
                        width: 1,
                        color: AppColors.dividerColor,
                      ),
                      _ProfileStatColumn(
                        count: '${user.followersCount}',
                        label: 'Followers',
                        onTap: () => _navigateTo(context, AppRoutes.followers),
                      ),
                      Container(
                        height: 28,
                        width: 1,
                        color: AppColors.dividerColor,
                      ),
                      _ProfileStatColumn(
                        count: '${user.followingCount}',
                        label: 'Following',
                        onTap: () => _navigateTo(context, AppRoutes.followers),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                // Biography & Location
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.bio, style: AppTypography.bodyRegular),
                      if (user.location.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 17,
                              color: AppColors.primaryPurple,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              user.location,
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Interest Chips + "+ Add" chip
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...user.interests.map(
                            (interest) => SakhiChip(
                              label: interest,
                              onTap: () =>
                                  _navigateTo(context, AppRoutes.editProfile),
                            ),
                          ),
                          SakhiChip(
                            label: '+ Add',
                            isOutlinedAction: true,
                            onTap: () => _showAddInterestDialog(context, state),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                // Tabs for Posts, Saved, and Groups
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.dividerColor),
                    ),
                  ),
                  child: Row(
                    children: [
                      _ProfileTabButton(
                        label: 'Posts',
                        isSelected: _selectedTabIndex == 0,
                        onTap: () => setState(() => _selectedTabIndex = 0),
                      ),
                      _ProfileTabButton(
                        label: 'Saved',
                        isSelected: _selectedTabIndex == 1,
                        onTap: () => setState(() => _selectedTabIndex = 1),
                      ),
                      _ProfileTabButton(
                        label: 'Groups',
                        isSelected: _selectedTabIndex == 2,
                        onTap: () => setState(() => _selectedTabIndex = 2),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                // Tab Content
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH,
                  ),
                  child: _buildTabContent(context, state),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabContent(BuildContext context, SakhiPrototypeState state) {
    if (_selectedTabIndex == 0) {
      return Column(
        children: state.profilePosts
            .map(
              (post) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FeedPostCard(
                  post: post,
                  showVerifiedCheck: true,
                  onLikeTap: () => state.togglePostLike(post),
                  onSaveTap: () => state.togglePostSaved(post),
                ),
              ),
            )
            .toList(),
      );
    } else if (_selectedTabIndex == 1) {
      final saved = [
        ...state.communityPosts.where((p) => p.isSaved),
        ...state.exploreRecommendedPosts.where((p) => p.isSaved),
      ];
      if (saved.isEmpty) {
        return const SakhiEmptyState(
          icon: Icons.bookmark_border_rounded,
          title: 'No Saved Posts Yet',
          message: 'Bookmark posts from the Community feed to find them here.',
        );
      }
      return Column(
        children: saved
            .map(
              (post) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FeedPostCard(
                  post: post,
                  onLikeTap: () => state.togglePostLike(post),
                  onSaveTap: () => state.togglePostSaved(post),
                ),
              ),
            )
            .toList(),
      );
    } else {
      return Column(
        children: state.groups
            .map(
              (g) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.borderSubtle),
                  ),
                  tileColor: AppColors.cardSurface,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.pastelLavender,
                    child: Icon(
                      Icons.groups_rounded,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                  title: Text(g.name, style: AppTypography.cardTitle),
                  subtitle: Text(g.description, style: AppTypography.subtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => SakhiDialogs.showPrototypeSnackbar(
                    context,
                    'Opening ${g.name} circle.',
                  ),
                ),
              ),
            )
            .toList(),
      );
    }
  }

  void _showAddInterestDialog(BuildContext context, SakhiPrototypeState state) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: const Text('Add Interest', style: AppTypography.sectionTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Yoga, Photography, Coding',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          SakhiPillButton(
            label: 'Add',
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                state.addInterest(controller.text);
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileStatColumn extends StatelessWidget {
  final String count;
  final String label;
  final VoidCallback onTap;

  const _ProfileStatColumn({
    required this.count,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          children: [
            Text(
              count,
              style: AppTypography.sectionTitle.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 2),
            Text(label, style: AppTypography.subtitle),
          ],
        ),
      ),
    );
  }
}

class _ProfileTabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProfileTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color:
                    isSelected ? AppColors.primaryPurple : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: isSelected ? AppColors.primaryPurple : AppColors.textMuted,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
