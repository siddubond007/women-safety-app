import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Main interactive shell with persistent iOS 26 Liquid Glass navigation,
/// Sakhi Create Hub, and full Android back-button / gesture protection.
class AppNavigationShell extends StatefulWidget {
  final int initialTabIndex;

  const AppNavigationShell({super.key, this.initialTabIndex = 0});

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  late int _currentIndex;
  final List<int> _tabHistory = <int>[];
  String? _activeSubScreenRoute;
  DateTime? _lastBackPressedAt;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    unawaited(SakhiPrototypeState.instance.syncFromBackend());
  }

  void _handleTabSelected(int index) {
    setState(() {
      if (_currentIndex != index && _currentIndex >= 0 && _currentIndex <= 3) {
        _tabHistory.remove(index);
        _tabHistory.add(_currentIndex);
      }
      _currentIndex = index;
      _activeSubScreenRoute = null;
    });
  }

  void _handleRouteFromChild(String routeName) {
    if (routeName == AppRoutes.safety || routeName == AppRoutes.wellness) {
      setState(() {
        _activeSubScreenRoute = routeName;
      });
    } else {
      Navigator.of(context).pushNamed(routeName);
    }
  }

  void _returnFromSubScreen() {
    setState(() {
      _activeSubScreenRoute = null;
      if (_currentIndex > 3) {
        _currentIndex = 0;
      }
    });
  }

  void _handleSystemBack(bool didPop) {
    if (didPop) return;
    // 1. If viewing an embedded sub-screen (Wellness or Safety), return to current tab
    if (_activeSubScreenRoute != null || _currentIndex > 3) {
      _returnFromSubScreen();
      return;
    }
    // 2. If on Explore, Community, or Profile tab, navigate back to previous tab or Home
    if (_currentIndex != 0) {
      setState(() {
        if (_tabHistory.isNotEmpty) {
          _currentIndex = _tabHistory.removeLast();
        } else {
          _currentIndex = 0;
        }
      });
      return;
    }
    // 3. Already on Home tab: require double-back within 2 seconds to exit app
    final now = DateTime.now();
    if (_lastBackPressedAt == null ||
        now.difference(_lastBackPressedAt!) > const Duration(seconds: 2)) {
      _lastBackPressedAt = now;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text(
              'Press back again to exit Sakhi',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primaryPurple,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    Widget activeBody;
    if (_activeSubScreenRoute == AppRoutes.wellness) {
      activeBody = WellnessScreen(
        showBackButton: true,
        onBackTap: _returnFromSubScreen,
      );
    } else if (_activeSubScreenRoute == AppRoutes.safety ||
        _currentIndex == 4) {
      activeBody = SafetyScreen(
        showBackButton: true,
        onBackTap: _returnFromSubScreen,
        onNavigateRoute: _handleRouteFromChild,
      );
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
            onCreateTap: () => _showCenterActionModal(),
          );
          break;
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handleSystemBack(didPop),
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: activeBody,
        bottomNavigationBar: SakhiBottomNav(
          currentIndex: _activeSubScreenRoute != null ? 0 : _currentIndex,
          onTabSelected: _handleTabSelected,
          onCenterAddTap: () => _showCenterActionModal(),
        ),
      ),
    );
  }

  Future<void> _showCenterActionModal() async {
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
