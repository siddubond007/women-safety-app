import 'dart:async';

import 'package:flutter/material.dart';
import '../../features/community/screens/community_screen.dart';
import '../../features/explore/screens/explore_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/safety/screens/safety_screen.dart';
import '../../features/wellness/screens/wellness_screen.dart';
import '../constants/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/sakhi_bottom_nav.dart';
import '../widgets/sakhi_buttons.dart';
import '../widgets/sakhi_dialogs.dart';
import 'app_routes.dart';

/// Main interactive shell with persistent SakhiBottomNav and a Create Post /
/// Quick Screen Switcher modal triggered by the center '+' button.
class AppNavigationShell extends StatefulWidget {
  final int initialTabIndex;

  const AppNavigationShell({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  late int _currentIndex;
  // Optional sub-tab override for Wellness (4) or Safety (5) inside the bottom-nav shell
  String? _activeSubScreenRoute;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    unawaited(SakhiPrototypeState.instance.syncFromBackend());
  }

  void _handleTabSelected(int index) {
    setState(() {
      _currentIndex = index;
      _activeSubScreenRoute = null;
    });
  }

  void _handleRouteFromChild(String routeName) {
    if (routeName == AppRoutes.wellness || routeName == AppRoutes.safety) {
      setState(() {
        _activeSubScreenRoute = routeName;
      });
    } else {
      Navigator.of(context).pushNamed(routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget activeBody;
    if (_activeSubScreenRoute == AppRoutes.wellness) {
      activeBody = const WellnessScreen(showBackButton: false);
    } else if (_activeSubScreenRoute == AppRoutes.safety) {
      activeBody = const SafetyScreen(showBackButton: false);
    } else {
      switch (_currentIndex) {
        case 0:
          activeBody = HomeScreen(
            onNavigateTab: _handleTabSelected,
            onNavigateRoute: _handleRouteFromChild,
          );
          break;
        case 1:
          activeBody = ExploreScreen(
            onNavigateRoute: _handleRouteFromChild,
          );
          break;
        case 2:
          activeBody = const CommunityScreen();
          break;
        case 3:
        default:
          activeBody = ProfileScreen(
            onNavigateRoute: _handleRouteFromChild,
          );
          break;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: activeBody,
      bottomNavigationBar: SakhiBottomNav(
        currentIndex: _currentIndex,
        onTabSelected: _handleTabSelected,
        onCenterAddTap: () => _showCenterActionModal(context),
      ),
    );
  }

  void _showCenterActionModal(BuildContext context) {
    final postController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Create Post & Screen Switcher',
                    style: AppTypography.sectionTitle,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: postController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Share a thought, wellness tip, or question...',
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: SakhiPillButton(
                  label: 'Post to Community',
                  onPressed: () {
                    final text = postController.text.trim();
                    if (text.isNotEmpty) {
                      SakhiPrototypeState.instance.createCommunityPost(text);
                      Navigator.pop(ctx);
                      _handleTabSelected(2);
                      SakhiDialogs.showPrototypeSnackbar(
                        context,
                        'Post published to Community Feed!',
                      );
                    }
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(),
              ),
              const Text(
                'Quick Jump: All 12 Reference Screens',
                style: AppTypography.cardTitle,
              ),
              const SizedBox(height: 4),
              const Text(
                'Jump directly to any of the 12 Sakhi screens:',
                style: AppTypography.subtitle,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ScreenJumpChip('1. Home', () {
                    Navigator.pop(ctx);
                    _handleTabSelected(0);
                  }),
                  _ScreenJumpChip('2. Explore', () {
                    Navigator.pop(ctx);
                    _handleTabSelected(1);
                  }),
                  _ScreenJumpChip('3. Community', () {
                    Navigator.pop(ctx);
                    _handleTabSelected(2);
                  }),
                  _ScreenJumpChip('4. Wellness Hub', () {
                    Navigator.pop(ctx);
                    setState(() => _activeSubScreenRoute = AppRoutes.wellness);
                  }),
                  _ScreenJumpChip('5. Safety & SOS', () {
                    Navigator.pop(ctx);
                    setState(() => _activeSubScreenRoute = AppRoutes.safety);
                  }),
                  _ScreenJumpChip('6. Profile', () {
                    Navigator.pop(ctx);
                    _handleTabSelected(3);
                  }),
                  _ScreenJumpChip('7. Edit Profile', () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pushNamed(AppRoutes.editProfile);
                  }),
                  _ScreenJumpChip('8. Privacy Settings', () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pushNamed(AppRoutes.privacySettings);
                  }),
                  _ScreenJumpChip('9. Notifications', () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pushNamed(
                      AppRoutes.notificationPreferences,
                    );
                  }),
                  _ScreenJumpChip('10. Followers', () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pushNamed(AppRoutes.followers);
                  }),
                  _ScreenJumpChip('11. Account & Security', () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pushNamed(AppRoutes.accountSecurity);
                  }),
                  _ScreenJumpChip('12. More Options', () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pushNamed(AppRoutes.moreOptions);
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScreenJumpChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ScreenJumpChip(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: AppTypography.chipLabel),
      backgroundColor: AppColors.pastelLavender,
      side: const BorderSide(color: AppColors.borderSubtle),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      onPressed: onTap,
    );
  }
}
