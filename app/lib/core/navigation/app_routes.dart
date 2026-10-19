import 'package:flutter/material.dart';
import '../../features/account_security/screens/account_security_screen.dart';
import '../../features/community/screens/community_screen.dart';
import '../../features/explore/screens/explore_screen.dart';
import '../../features/followers/screens/followers_following_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/notifications/screens/notification_preferences_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/safety/screens/safety_screen.dart';
import '../../features/settings/screens/more_options_menu_screen.dart';
import '../../features/settings/screens/privacy_settings_screen.dart';
import '../../features/wellness/screens/wellness_screen.dart';
import 'app_navigation_shell.dart';

/// Centralized route definitions for all 12 Sakhi UI screens.
class AppRoutes {
  AppRoutes._();

  static const String root = '/';
  static const String home = '/home'; // Screen 1
  static const String explore = '/explore'; // Screen 2
  static const String community = '/community'; // Screen 3
  static const String wellness = '/wellness'; // Screen 4
  static const String safety = '/safety'; // Screen 5
  static const String profile = '/profile'; // Screen 6
  static const String editProfile = '/edit-profile'; // Screen 7
  static const String privacySettings = '/privacy-settings'; // Screen 8
  static const String notificationPreferences =
      '/notification-preferences'; // Screen 9
  static const String followers = '/followers'; // Screen 10
  static const String accountSecurity = '/account-security'; // Screen 11
  static const String moreOptions = '/more-options'; // Screen 12

  static Map<String, WidgetBuilder> get routes => {
        root: (_) => const AppNavigationShell(),
        home: (_) => const Scaffold(body: HomeScreen()),
        explore: (_) => const Scaffold(body: ExploreScreen()),
        community: (_) => const Scaffold(body: CommunityScreen()),
        wellness: (_) => const WellnessScreen(showBackButton: true),
        safety: (_) => const SafetyScreen(showBackButton: true),
        profile: (_) => const Scaffold(body: ProfileScreen()),
        editProfile: (_) => const EditProfileScreen(),
        privacySettings: (_) => const PrivacySettingsScreen(),
        notificationPreferences: (_) => const NotificationPreferencesScreen(),
        followers: (_) => const FollowersFollowingScreen(),
        accountSecurity: (_) => const AccountSecurityScreen(),
        moreOptions: (_) => const MoreOptionsMenuScreen(),
      };
}
