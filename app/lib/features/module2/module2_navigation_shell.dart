import 'package:flutter/material.dart';

import '../../core/constants/mock_data.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sakhi_bottom_nav.dart';
import '../auth/auth_service.dart';
import '../auth/sakhi_login_screen.dart';
import '../home/screens/home_screen.dart';
import 'screens/account_security_screen.dart';
import 'screens/community_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/followers_following_screen.dart';
import 'screens/groups_screen.dart';
import 'screens/more_options_screen.dart';
import 'screens/member_profile_screen.dart';
import 'screens/notification_preferences_screen.dart';
import 'screens/privacy_settings_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/safety_screen.dart';
import 'screens/wellness_screen.dart';
import 'module2_scope.dart';
import 'module2_state.dart';

class Module2NavigationShell extends StatefulWidget {
  const Module2NavigationShell({super.key, required this.authService});

  final AuthService authService;

  @override
  State<Module2NavigationShell> createState() => _Module2NavigationShellState();
}

class _Module2NavigationShellState extends State<Module2NavigationShell> {
  late final Module2State _state;
  String _route = AppRoutes.home;
  String? _selectedMemberAccountId;
  final List<String> _history = <String>[AppRoutes.home];

  @override
  void initState() {
    super.initState();
    _state = Module2State(authService: widget.authService);
    SakhiPrototypeBinding.instance.bind(_state);
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  int get _tabIndex => switch (_route) {
    AppRoutes.home => 0,
    AppRoutes.explore => 1,
    AppRoutes.community => 2,
    AppRoutes.profile => 3,
    _ => 0,
  };

  void _selectTab(int index) {
    final route = switch (index) {
      0 => AppRoutes.home,
      1 => AppRoutes.explore,
      2 => AppRoutes.community,
      3 => AppRoutes.profile,
      _ => AppRoutes.home,
    };
    _navigate(route, replaceTop: true);
  }

  void _navigate(String route, {bool replaceTop = false}) {
    if (!mounted) return;
    setState(() {
      _route = route;
      if (replaceTop && _history.isNotEmpty) {
        _history[_history.length - 1] = route;
      } else {
        _history.add(route);
      }
    });
    SakhiPrototypeBinding.instance.loadRouteData(route);
  }

  void _openMemberProfile(String accountId) {
    final targetId = accountId.trim();
    if (!mounted || targetId.isEmpty) return;
    if (targetId == _state.profile?.accountId) {
      _navigate(AppRoutes.profile);
      return;
    }
    setState(() {
      _selectedMemberAccountId = targetId;
      _route = AppRoutes.memberProfile;
      _history.add(AppRoutes.memberProfile);
    });
    SakhiPrototypeBinding.instance.loadRouteData(AppRoutes.memberProfile);
  }

  void _back() {
    if (!mounted) return;
    if (_history.length > 1) {
      setState(() {
        _history.removeLast();
        _route = _history.last;
      });
      SakhiPrototypeBinding.instance.loadRouteData(_route);
    } else {
      _selectTab(0);
    }
  }

  Future<void> _signOut() async {
    try {
      await widget.authService.logout();
    } catch (_) {
      // Local credentials are cleared by the authentication adapter.
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => SakhiLoginScreen(authService: widget.authService),
      ),
      (_) => false,
    );
  }

  Future<void> _openCreatePost() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => _CreatePostSheet(
        state: _state,
        onPublished: () {
          Navigator.of(context).pop();
          _navigate(AppRoutes.community, replaceTop: true);
        },
      ),
    );
  }

  Widget _screenForRoute() {
    switch (_route) {
      case AppRoutes.home:
        return HomeScreen(onNavigateTab: _selectTab, onNavigateRoute: _navigate);
      case AppRoutes.explore:
        return ExploreScreen(onNavigateRoute: _navigate, onOpenMember: _openMemberProfile);
      case AppRoutes.community:
        return CommunityScreen(onNavigateRoute: _navigate, onOpenMember: _openMemberProfile);
      case AppRoutes.wellness:
        return WellnessScreen(onNavigateRoute: _navigate);
      case AppRoutes.safety:
        return SafetyScreen(onNavigateRoute: _navigate);
      case AppRoutes.profile:
        return ProfileScreen(onNavigateRoute: _navigate);
      case AppRoutes.memberProfile:
        final accountId = _selectedMemberAccountId;
        return accountId == null || accountId.isEmpty
            ? ProfileScreen(onNavigateRoute: _navigate)
            : MemberProfileScreen(
                key: ValueKey<String>(accountId),
                accountId: accountId,
              );
      case AppRoutes.editProfile:
        return const EditProfileScreen();
      case AppRoutes.privacySettings:
        return const PrivacySettingsScreen();
      case AppRoutes.notificationPreferences:
        return const NotificationPreferencesScreen();
      case AppRoutes.followers:
        return FollowersFollowingScreen(onOpenMember: _openMemberProfile);
      case AppRoutes.following:
        return FollowersFollowingScreen(
          onOpenMember: _openMemberProfile,
          initialFollowing: true,
        );
      case AppRoutes.groups:
        return const GroupsScreen();
      case AppRoutes.myGroups:
        return const GroupsScreen(initialTab: 1);
      case AppRoutes.accountSecurity:
        return AccountSecurityScreen(onSignOut: _signOut);
      case AppRoutes.moreOptions:
        return MoreOptionsScreen(onSignOut: _signOut, onNavigateRoute: _navigate);
      default:
        return HomeScreen(onNavigateTab: _selectTab, onNavigateRoute: _navigate);
    }
  }

  bool get _isMainTab => _route == AppRoutes.home ||
      _route == AppRoutes.explore ||
      _route == AppRoutes.community ||
      _route == AppRoutes.profile;

  String _titleForRoute(String route) => switch (route) {
    AppRoutes.wellness => 'Wellness',
    AppRoutes.safety => 'Safety & SOS',
    AppRoutes.editProfile => 'Edit Profile',
    AppRoutes.privacySettings => 'Privacy Settings',
    AppRoutes.notificationPreferences => 'Notification Preferences',
    AppRoutes.followers => 'Followers & Following',
    AppRoutes.following => 'Following',
    AppRoutes.memberProfile => 'Member Profile',
    AppRoutes.groups || AppRoutes.myGroups => 'Groups & Events',
    AppRoutes.accountSecurity => 'Account & Security',
    AppRoutes.moreOptions => 'More Options',
    _ => 'Sakhi',
  };

  Widget _scopedScreen() => Module2Scope(
    state: _state,
    route: _route,
    onNavigate: (route) => _navigate(route),
    onOpenCreatePost: _openCreatePost,
    child: _screenForRoute(),
  );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: SafeArea(
          bottom: false,
          child: _isMainTab
              ? _scopedScreen()
              : Column(
                  children: [
                    Material(
                      color: AppColors.scaffoldBackground,
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Back',
                            onPressed: _back,
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          Expanded(
                            child: Text(
                              _titleForRoute(_route),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (_route == AppRoutes.moreOptions)
                            IconButton(
                              tooltip: 'Sign out',
                              onPressed: _signOut,
                              icon: const Icon(Icons.logout_rounded),
                            ),
                        ],
                      ),
                    ),
                    Expanded(child: _scopedScreen()),
                  ],
                ),
        ),
        bottomNavigationBar: SakhiBottomNav(
          currentIndex: _tabIndex,
          onTabSelected: _selectTab,
          onCenterAddTap: _openCreatePost,
        ),
      ),
    );
  }
}

class SakhiPrototypeBinding {
  SakhiPrototypeBinding._();

  static final SakhiPrototypeBinding instance = SakhiPrototypeBinding._();

  Future<void> bind(Module2State state) async {
    await SakhiPrototypeState.instance.bind(state);
  }

  Future<void> loadRouteData(String route) =>
      SakhiPrototypeState.instance.loadRouteData(route);
}

class _CreatePostSheet extends StatefulWidget {
  const _CreatePostSheet({required this.state, required this.onPublished});

  final Module2State state;
  final VoidCallback onPublished;

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final TextEditingController _controller = TextEditingController();
  String _audience = 'VERIFIED_MEMBERS';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final success = await widget.state.createPost(
      _controller.text,
      audience: _audience,
    );
    if (!mounted) return;
    if (success) {
      widget.onPublished();
    } else {
      setState(() {
        _saving = false;
        _error = widget.state.errorMessage ?? 'Post could not be published.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 18, bottom: bottomInset + 22),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create a post', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            const Text('Your post will be saved to your Sakhi account using the selected audience.', style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4)),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              maxLength: 5000,
              decoration: const InputDecoration(hintText: 'Share a thought, wellness tip, or question...'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _audience,
              decoration: const InputDecoration(labelText: 'Who can see this post'),
              items: const [
                DropdownMenuItem(value: 'VERIFIED_MEMBERS', child: Text('Verified members')),
                DropdownMenuItem(value: 'FOLLOWERS', child: Text('My followers')),
                DropdownMenuItem(value: 'ONLY_ME', child: Text('Only me')),
              ],
              onChanged: _saving ? null : (value) {
                if (value != null) setState(() => _audience = value);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.sosRed, fontSize: 12.5)),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _publish,
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Publish post'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
