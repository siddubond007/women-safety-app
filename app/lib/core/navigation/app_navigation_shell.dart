import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/business/screens/business_hub_screen.dart';
import '../../features/community/screens/community_screen.dart';
import '../../features/community/screens/sakhi_post_creation_flow.dart';
import '../../features/explore/screens/explore_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/safety/models/safety_models.dart';
import '../../features/safety/screens/safety_screen.dart';
import '../../features/wellness/screens/wellness_screen.dart';
import '../constants/mock_data.dart';
import '../theme/app_colors.dart';
import '../widgets/sakhi_bottom_nav.dart';
import '../widgets/sakhi_create_hub_sheet.dart';
import '../widgets/sakhi_liquid_glass.dart';
import 'app_routes.dart';

/// Main interactive shell with persistent iOS 26 Liquid Glass navigation,
/// lazy-mounted IndexedStack across tabs so form & scroll state is never lost,
/// full lifecycle state retention across minimize/resume, Sakhi Create Hub,
/// global hardware SOS shortcut listener, and Android back-button protection.
class AppNavigationShell extends StatefulWidget {
  final int? initialTabIndex;

  const AppNavigationShell({super.key, this.initialTabIndex});

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell>
    with WidgetsBindingObserver {
  static const MethodChannel _nativeChannel = MethodChannel(
    'sakhi/native_actions',
  );
  final PageStorageBucket _storageBucket = PageStorageBucket();
  final Set<int> _mountedTabs = <int>{0};
  late int _currentIndex;
  String? _activeSubScreenRoute;
  DateTime? _lastBackPressedAt;
  bool _openingHardwareSosGuard = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final proto = SakhiPrototypeState.instance;
    if (widget.initialTabIndex != null) {
      _currentIndex = widget.initialTabIndex!;
      proto.activeShellTabIndex = _currentIndex;
    } else {
      _currentIndex = proto.activeShellTabIndex;
      _activeSubScreenRoute = proto.activeShellSubRoute;
    }
    _mountedTabs.add(_currentIndex.clamp(0, 3));
    unawaited(proto.syncFromBackend());

    // Register global 3x Volume / Power / Shake hardware SOS callback so it works
    // on EVERY screen of the application, not just when SafetyScreen is open.
    final safety = SakhiSafetyController.instance;
    safety.onDiscreetShortcutTriggered = _handleGlobalHardwareShortcutTrigger;
    unawaited(safety.initializeSafetyState(autoRequestGps: false));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final safety = SakhiSafetyController.instance;
    if (safety.onDiscreetShortcutTriggered ==
        _handleGlobalHardwareShortcutTrigger) {
      safety.onDiscreetShortcutTriggered = null;
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When returning from background/minimized state, keep current screen & tab intact
    // and silently refresh data in background without resetting navigation!
    if (state == AppLifecycleState.resumed) {
      final safety = SakhiSafetyController.instance;
      safety.onDiscreetShortcutTriggered = _handleGlobalHardwareShortcutTrigger;
      unawaited(SakhiPrototypeState.instance.syncFromBackend());
      unawaited(safety.syncSafetyOverview());
    }
  }

  void _handleGlobalHardwareShortcutTrigger(String source) {
    if (!mounted || _openingHardwareSosGuard) return;
    _openingHardwareSosGuard = true;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.sosRed,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Discreet SOS Shortcut detected ($source) • Opening 3s Confirmation Guard…',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => const SosWorkflowScreen(isTestMode: false),
          ),
        )
        .whenComplete(() {
          _openingHardwareSosGuard = false;
        });
  }

  void _handleTabSelected(int index) {
    final proto = SakhiPrototypeState.instance;
    setState(() {
      if (_currentIndex != index && _currentIndex >= 0 && _currentIndex <= 3) {
        proto.activeShellTabHistory.remove(index);
        proto.activeShellTabHistory.add(_currentIndex);
      }
      _currentIndex = index;
      _mountedTabs.add(index.clamp(0, 3));
      _activeSubScreenRoute = null;
      proto.activeShellTabIndex = index;
      proto.activeShellSubRoute = null;
    });
    if (index == 2) {
      proto.markCommunityPostsAsSeen();
    }
  }

  void _handleRouteFromChild(String routeName) {
    final proto = SakhiPrototypeState.instance;
    if (routeName == AppRoutes.safety ||
        routeName == AppRoutes.wellness ||
        routeName == AppRoutes.businessHub) {
      setState(() {
        _activeSubScreenRoute = routeName;
        proto.activeShellSubRoute = routeName;
      });
    } else {
      Navigator.of(context).pushNamed(routeName);
    }
  }

  void _returnFromSubScreen() {
    final proto = SakhiPrototypeState.instance;
    setState(() {
      _activeSubScreenRoute = null;
      proto.activeShellSubRoute = null;
      if (_currentIndex > 3) {
        _currentIndex = 0;
        proto.activeShellTabIndex = 0;
      }
    });
    SakhiSafetyController.instance.onDiscreetShortcutTriggered =
        _handleGlobalHardwareShortcutTrigger;
  }

  Future<void> _handleSystemBack(bool didPop) async {
    if (didPop) return;
    final proto = SakhiPrototypeState.instance;
    if (_activeSubScreenRoute != null || _currentIndex > 3) {
      _returnFromSubScreen();
      return;
    }
    if (_currentIndex != 0) {
      setState(() {
        if (proto.activeShellTabHistory.isNotEmpty) {
          _currentIndex = proto.activeShellTabHistory.removeLast();
        } else {
          _currentIndex = 0;
        }
        _mountedTabs.add(_currentIndex.clamp(0, 3));
        proto.activeShellTabIndex = _currentIndex;
      });
      return;
    }
    final now = DateTime.now();
    if (_lastBackPressedAt == null ||
        now.difference(_lastBackPressedAt!) > const Duration(seconds: 2)) {
      _lastBackPressedAt = now;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text(
              'Press back again to minimize Sakhi',
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
    try {
      final moved = await _nativeChannel.invokeMethod<bool>(
        'moveAppToBackground',
      );
      if (moved == true) return;
    } catch (_) {}
    await SystemNavigator.pop();
  }

  Widget _buildActiveScreen() {
    if (_activeSubScreenRoute == AppRoutes.wellness) {
      return WellnessScreen(
        showBackButton: true,
        onBackTap: _returnFromSubScreen,
      );
    }
    if (_activeSubScreenRoute == AppRoutes.businessHub) {
      return WomenBusinessHubScreen(
        showBackButton: true,
        onBackTap: _returnFromSubScreen,
      );
    }
    if (_activeSubScreenRoute == AppRoutes.safety || _currentIndex == 4) {
      return SafetyScreen(
        showBackButton: true,
        onBackTap: _returnFromSubScreen,
        onNavigateRoute: _handleRouteFromChild,
      );
    }

    final safeIndex = _currentIndex.clamp(0, 3);
    _mountedTabs.add(safeIndex);

    return IndexedStack(
      index: safeIndex,
      children: [
        _mountedTabs.contains(0)
            ? HomeScreen(
                key: const PageStorageKey<String>('sakhi_tab_home'),
                onNavigateTab: _handleTabSelected,
                onNavigateRoute: _handleRouteFromChild,
              )
            : const SizedBox.shrink(),
        _mountedTabs.contains(1)
            ? ExploreScreen(
                key: const PageStorageKey<String>('sakhi_tab_explore'),
                onNavigateRoute: _handleRouteFromChild,
              )
            : const SizedBox.shrink(),
        _mountedTabs.contains(2)
            ? const CommunityScreen(
                key: PageStorageKey<String>('sakhi_tab_community'),
              )
            : const SizedBox.shrink(),
        _mountedTabs.contains(3)
            ? ProfileScreen(
                key: const PageStorageKey<String>('sakhi_tab_profile'),
                onNavigateRoute: _handleRouteFromChild,
                onNavigateTab: _handleTabSelected,
                onCreateTap: () => _showCenterActionModal(),
              )
            : const SizedBox.shrink(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handleSystemBack(didPop),
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        extendBody: true,
        body: SakhiLiquidGlassAmbientMesh(
          child: PageStorage(
            bucket: _storageBucket,
            child: _buildActiveScreen(),
          ),
        ),
        bottomNavigationBar: SakhiBottomNav(
          currentIndex: _currentIndex.clamp(0, 3),
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
    final proto = SakhiPrototypeState.instance;
    setState(() {
      _currentIndex = 2;
      _mountedTabs.add(2);
      _activeSubScreenRoute = null;
      proto.activeShellTabIndex = 2;
      proto.activeShellSubRoute = null;
    });
    unawaited(proto.syncFromBackend());
  }
}
