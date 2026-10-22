import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/community/screens/community_screen.dart';
import '../../features/community/screens/sakhi_post_creation_flow.dart';
import '../../features/explore/screens/explore_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/safety/screens/safety_screen.dart';
import '../../features/wellness/screens/wellness_screen.dart';
import '../constants/mock_data.dart';
import '../theme/app_colors.dart';
import '../widgets/sakhi_bottom_nav.dart';
import '../widgets/sakhi_create_hub_sheet.dart';
import 'app_routes.dart';

/// Main interactive shell with persistent navigation and the Sakhi Create Hub.
class AppNavigationShell extends StatefulWidget {
  final int initialTabIndex;

  const AppNavigationShell({super.key, this.initialTabIndex = 0});

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
          activeBody = ExploreScreen(onNavigateRoute: _handleRouteFromChild);
          break;
        case 2:
          activeBody = const CommunityScreen();
          break;
        case 3:
        default:
          activeBody = ProfileScreen(
            onNavigateRoute: _handleRouteFromChild,
            onNavigateTab: _handleTabSelected,
            onCreateTap: () => _showCenterActionModal(context),
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

  Future<void> _showCenterActionModal(BuildContext context) async {
    final action = await showSakhiCreateHub(context);
    if (!mounted || action == null) return;

    await openSakhiCreateAction(
      context,
      action,
      onPublished: _handlePostPublished,
    );
  }

  void _handlePostPublished() {
    if (!mounted) return;
    setState(() {
      _currentIndex = 2;
      _activeSubScreenRoute = null;
    });
    unawaited(SakhiPrototypeState.instance.syncFromBackend());
  }
}
