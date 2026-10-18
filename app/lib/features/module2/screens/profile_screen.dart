import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_avatar.dart';
import '../../../core/widgets/sakhi_chip.dart';
import '../../../core/widgets/sakhi_section_header.dart';
import '../widgets/module2_feature_widgets.dart';
import '../module2_post_actions.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onNavigateRoute});
  final ValueChanged<String>? onNavigateRoute;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    if (SakhiPrototypeState.instance.showSavedPostsFirst) {
      _tabIndex = 1;
      SakhiPrototypeState.instance.showSavedPostsFirst = false;
      SakhiPrototypeState.instance.backend?.loadSavedPosts();
    }
  }

  void _navigate(String route) {
    final handler = widget.onNavigateRoute;
    if (handler != null) {
      handler(route);
    } else {
      Navigator.of(context).pushNamed(route);
    }
  }

  Future<void> _addInterest(SakhiPrototypeState state) async {
    final controller = TextEditingController();
    final interest = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add interest'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(hintText: 'e.g. Women in Tech'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || interest == null || interest.trim().isEmpty) return;
    final success = await state.addInterest(interest);
    if (mounted && !success && state.backend?.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.backend!.errorMessage!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final user = state.currentUser;
        final backendProfile = state.backend?.profile;
        final posts = _tabIndex == 0 ? state.profilePosts : _tabIndex == 1 ? state.savedPosts : <FeedPostModel>[];
        return Module2PageBody(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Row(children: [
                  Image.asset(AppAssets.sakhiShieldLogo, width: 29, height: 29, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.shield_rounded, color: AppColors.primaryPurple, size: 28)),
                  const SizedBox(width: 9),
                  const Text('Profile', style: AppTypography.appBarTitle),
                ])),
                IconButton(
                  tooltip: 'More options and settings',
                  onPressed: () => _navigate(AppRoutes.moreOptions),
                  icon: const Icon(Icons.settings_outlined, color: AppColors.primaryPurple),
                ),
              ]),
              const SizedBox(height: 9),
              Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  child: Image.asset(
                    AppAssets.profileHeaderBanner,
                    height: 112,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(height: 112, decoration: const BoxDecoration(gradient: AppColors.heroBannerGradient)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 23),
                  child: SakhiAvatar(
                    imageAsset: user.avatarAsset,
                    size: 102,
                    borderWidth: 3,
                    fallbackLabel: user.displayName,
                    showEditCameraBadge: true,
                    onCameraTap: () => _navigate(AppRoutes.editProfile),
                  ),
                ),
              ]),
              const SizedBox(height: 51),
              Center(
                child: Column(children: [
                  Text(user.displayName.isEmpty ? 'Sakhi Member' : user.displayName, style: AppTypography.heroTitle.copyWith(fontSize: 22)),
                  const SizedBox(height: 5),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Your Sakhi profile', style: AppTypography.subtitle),
                    const SizedBox(width: 8),
                    if (backendProfile != null) Module2ProfileBadge(status: backendProfile.verificationStatus),
                  ]),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _navigate(AppRoutes.editProfile),
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('Edit Profile'),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Row(children: [
                _ProfileStat(value: user.postsCount.toString(), label: 'Posts', onTap: () => setState(() => _tabIndex = 0)),
                _ProfileStat(value: user.followersCount.toString(), label: 'Followers', onTap: () => _navigate(AppRoutes.followers)),
                _ProfileStat(value: user.followingCount.toString(), label: 'Following', onTap: () => _navigate(AppRoutes.following)),
              ]),
              const SizedBox(height: 12),
              if (user.bio.isNotEmpty)
                Text(user.bio, style: AppTypography.bodyRegular.copyWith(color: AppColors.textPrimary))
              else
                const Text('Add a short bio to tell the community about yourself.', style: AppTypography.subtitle),
              if (user.location.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.location_on_outlined, color: AppColors.primaryPurple, size: 17),
                  const SizedBox(width: 4),
                  Text(user.location, style: AppTypography.subtitle.copyWith(color: AppColors.textPrimary)),
                ]),
              ],
              const SizedBox(height: 13),
              const SakhiSectionHeader(title: 'Interests'),
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  ...user.interests.map((interest) => SakhiChip(
                    label: interest,
                    onDelete: () => state.removeInterest(interest),
                  )),
                  SakhiChip(label: '+ Add', isOutlinedAction: true, onTap: () => _addInterest(state)),
                ],
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _ProfileTab(label: 'Posts', selected: _tabIndex == 0, onTap: () => setState(() => _tabIndex = 0))),
                Expanded(child: _ProfileTab(label: 'Saved', selected: _tabIndex == 1, onTap: () async {
                  setState(() => _tabIndex = 1);
                  await state.backend?.loadSavedPosts();
                })),
                Expanded(child: _ProfileTab(
                  label: 'Groups',
                  selected: _tabIndex == 2,
                  onTap: () async {
                    setState(() => _tabIndex = 2);
                    await state.backend?.loadGroups(mine: true);
                  },
                )),
              ]),
              const SizedBox(height: 11),
              if (_tabIndex == 2 && state.backend?.isLoadingGroups == true)
                const Center(child: Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator()))
              else if (_tabIndex == 2 && (state.backend?.myGroups ?? []).isEmpty)
                Module2EmptyPanel(
                  icon: Icons.groups_outlined,
                  title: 'Your groups',
                  message: 'Groups you own or have joined will appear here.',
                  actionLabel: 'Explore groups',
                  onAction: () => _navigate(AppRoutes.myGroups),
                )
              else if (_tabIndex == 2) ...[
                ...state.backend!.myGroups.map((group) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => _navigate(AppRoutes.myGroups),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: AppColors.pastelLavender,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.groups_rounded, color: AppColors.primaryPurple),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(group.name, style: AppTypography.cardTitle),
                            const SizedBox(height: 3),
                            Text(
                              '${group.memberCount} members · ${group.upcomingEventsCount} upcoming events',
                              style: AppTypography.subtitle,
                            ),
                          ],
                        )),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                      ]),
                    ),
                  ),
                )),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _navigate(AppRoutes.myGroups),
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Manage groups & events'),
                  ),
                ),
              ]
              else if (state.backend?.isLoadingFeed == true)
                const Center(child: Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator()))
              else if (posts.isEmpty)
                Module2EmptyPanel(
                  icon: _tabIndex == 0 ? Icons.photo_library_outlined : Icons.bookmark_border_rounded,
                  title: _tabIndex == 0 ? 'Your posts will appear here' : 'No saved posts yet',
                  message: _tabIndex == 0 ? 'Share a thought or update with verified members using the + button.' : 'Save a community post to find it quickly here.',
                  actionLabel: _tabIndex == 0 ? 'Create a post' : 'Explore Community',
                  onAction: () => _tabIndex == 0 ? _navigate(AppRoutes.community) : _navigate(AppRoutes.community),
                )
              else
                ...posts.map((post) => Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: Module2FeedPostCard(
                    post: post,
                    state: state,
                    onAuthorTap: () {},
                    onComment: () => _navigate(AppRoutes.community),
                    onMore: () => showModule2PostActions(context, post),
                  ),
                )),
              if (state.backend?.errorMessage != null) ...[
                const SizedBox(height: 9),
                Text(state.backend!.errorMessage!, style: const TextStyle(color: AppColors.sosRed, fontSize: 12)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label, required this.onTap});
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Column(children: [
          Text(value, style: AppTypography.cardTitle.copyWith(fontSize: 17)),
          Text(label, style: AppTypography.subtitle),
        ]),
      ),
    ),
  );
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? AppColors.primaryPurple : AppColors.borderSubtle, width: selected ? 2.5 : 1))),
      child: Text(label, style: TextStyle(color: selected ? AppColors.primaryPurple : AppColors.textMuted, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, fontSize: 12.5)),
    ),
  );
}
