import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/core/constants/mock_data.dart';
import 'package:women_safety_app/core/navigation/app_navigation_shell.dart';
import 'package:women_safety_app/features/account_security/screens/account_security_screen.dart';
import 'package:women_safety_app/features/followers/screens/followers_following_screen.dart';
import 'package:women_safety_app/features/notifications/screens/notification_preferences_screen.dart';
import 'package:women_safety_app/features/profile/screens/edit_profile_screen.dart';
import 'package:women_safety_app/features/safety/screens/safety_screen.dart';
import 'package:women_safety_app/features/settings/screens/more_options_menu_screen.dart';
import 'package:women_safety_app/features/settings/screens/privacy_settings_screen.dart';
import 'package:women_safety_app/features/wellness/screens/wellness_screen.dart';

void main() {
  testWidgets(
    'AppNavigationShell switches across Home, Explore, Community, and Profile (Screens 1, 2, 3, 6)',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: AppNavigationShell()));
      await tester.pumpAndSettle();

      // Screen 1: Home Dashboard
      expect(find.text('Sakhi'), findsOneWidget);
      expect(find.textContaining('Good Morning'), findsOneWidget);
      expect(find.text('For You Today'), findsOneWidget);
      expect(find.text('5 new posts'), findsOneWidget);

      // Tap Explore tab (Screen 2)
      await tester.tap(find.text('Explore').last);
      await tester.pumpAndSettle();
      expect(find.text('Trending Topics'), findsOneWidget);

      // Tap Community tab (Screen 3)
      await tester.tap(find.text('Community').last);
      await tester.pumpAndSettle();
      expect(find.text('Kavya Nair'), findsOneWidget);

      // Tap Profile tab (Screen 6)
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      expect(find.text('@siddhu'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Screens 4, 5, 7, 8, 9, 10, 11, and 12 render and interact with SakhiPrototypeState',
    (WidgetTester tester) async {
      // Screen 4: Wellness Hub
      await tester.pumpWidget(const MaterialApp(home: WellnessScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Your Wellbeing'), findsOneWidget);
      expect(find.text('Guided Meditation'), findsOneWidget);

      // Screen 5: Safety & SOS
      await tester.pumpWidget(const MaterialApp(home: SafetyScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Tap SOS'), findsOneWidget);
      expect(find.text('Quick Safety Actions'), findsOneWidget);

      // Screen 7: Edit Profile
      await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Screen 8: Privacy Settings
      await tester.pumpWidget(const MaterialApp(home: PrivacySettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Who can view my profile'), findsOneWidget);

      // Screen 9: Notification Preferences
      await tester.pumpWidget(
        const MaterialApp(home: NotificationPreferencesScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Community updates'), findsOneWidget);
      expect(find.text('Marketing updates'), findsOneWidget);

      // Screen 10: Followers & Following
      await tester.pumpWidget(
        const MaterialApp(home: FollowersFollowingScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ananya Rao'), findsOneWidget);
      final beforeFollowing =
          SakhiPrototypeState.instance.currentUser.followingCount;
      await tester.tap(find.text('Follow').first);
      await tester.pumpAndSettle();
      expect(
        SakhiPrototypeState.instance.currentUser.followingCount,
        beforeFollowing + 1,
      );

      // Screen 11: Account & Security
      await tester.pumpWidget(const MaterialApp(home: AccountSecurityScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Two-factor authentication'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);

      // Screen 12: More Options / Menu
      await tester.pumpWidget(const MaterialApp(home: MoreOptionsMenuScreen()));
      await tester.pumpAndSettle();
      expect(find.text('My Groups'), findsOneWidget);
      expect(find.text('About Sakhi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
