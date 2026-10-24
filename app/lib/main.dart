import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/branding/app_brand.dart';
import 'core/navigation/app_navigation_shell.dart';
import 'core/navigation/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/sakhi_design_system.dart';
import 'core/widgets/sakhi_quote_loader.dart';
import 'features/account_security/screens/account_security_screen.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/auth_service_factory.dart';
import 'features/auth/sakhi_auth_status_screen.dart';
import 'features/auth/sakhi_login_screen.dart';
import 'features/auth/sakhi_registration_screen.dart';
import 'features/community/screens/community_screen.dart';
import 'features/explore/screens/explore_screen.dart';
import 'features/followers/screens/followers_following_screen.dart';
import 'features/notifications/screens/notification_preferences_screen.dart';
import 'features/onboarding/sakhi_onboarding_screen.dart';
import 'features/profile/screens/edit_profile_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/safety/screens/safety_screen.dart';
import 'features/settings/screens/more_options_menu_screen.dart';
import 'features/settings/screens/privacy_settings_screen.dart';
import 'features/wellness/screens/wellness_screen.dart';

const Color sakhiPlum = SakhiColors.plum;
const Color sakhiPurple = SakhiColors.purple;
const Color sakhiMutedPlum = SakhiColors.mutedPlum;
const Color sakhiBlush = SakhiColors.blush;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const SakhiApp());
}

/// Shared preview home screen widget preserved for existing widget tests.
class SakhiHomeScreen extends StatelessWidget {
  const SakhiHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SakhiColors.blush,
      appBar: AppBar(title: const Text('Sakhi Home')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            leading: const Icon(Icons.shield_outlined, color: SakhiColors.purple),
            title: const Text('Safety & support'),
            subtitle: const Text('SOS check-ins, helplines & trusted contacts'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Safety & support preview')),
                    body: const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Safety & support preview — connected to Sakhi service and backend integration.',
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class SakhiApp extends StatelessWidget {
  const SakhiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = authServiceForCurrentBuild();
    return MaterialApp(
      title: AppBrand.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routes: {
        '/home': (_) => SakhiProtectedHomeGate(authService: authService),
        '/dashboard': (_) => const AppNavigationShell(),
        AppRoutes.explore: (_) => const Scaffold(body: ExploreScreen()),
        AppRoutes.community: (_) => const Scaffold(body: CommunityScreen()),
        AppRoutes.wellness: (_) => const WellnessScreen(showBackButton: true),
        AppRoutes.safety: (_) => const SafetyScreen(showBackButton: true),
        AppRoutes.profile: (_) => const Scaffold(body: ProfileScreen()),
        AppRoutes.editProfile: (_) => const EditProfileScreen(),
        AppRoutes.privacySettings: (_) => const PrivacySettingsScreen(),
        AppRoutes.notificationPreferences: (_) =>
            const NotificationPreferencesScreen(),
        AppRoutes.followers: (_) => const FollowersFollowingScreen(),
        AppRoutes.accountSecurity: (_) => const AccountSecurityScreen(),
        AppRoutes.moreOptions: (_) => const MoreOptionsMenuScreen(),
      },
      home: SakhiStartupRouter(authService: authService),
    );
  }
}

class SakhiStartupRouter extends StatefulWidget {
  const SakhiStartupRouter({super.key, required this.authService});

  final AuthService authService;

  @override
  State<SakhiStartupRouter> createState() => _SakhiStartupRouterState();
}

class _SakhiStartupRouterState extends State<SakhiStartupRouter> {
  late Future<AuthAccountState?> _restoreFuture;
  bool _continueWithoutRestore = false;

  @override
  void initState() {
    super.initState();
    _restoreFuture = widget.authService.restoreSession();
  }

  void _retryRestore() {
    setState(() {
      _continueWithoutRestore = false;
      _restoreFuture = widget.authService.restoreSession();
    });
  }

  Widget _onboarding(BuildContext context) {
    return SakhiOnboardingScreen(
      onGetStarted: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => SakhiRegistrationScreen(
              authService: widget.authService,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_continueWithoutRestore) return _onboarding(context);

    return FutureBuilder<AuthAccountState?>(
      future: _restoreFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: SakhiColors.blush,
            body: SakhiQuoteLoader.fullScreen(
              statusLabel: 'Restoring your verified Sakhi session...',
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: SakhiColors.blush,
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppBrand.appName,
                          style: const TextStyle(
                            color: SakhiColors.plum,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Could not check your saved session',
                          textAlign: TextAlign.center,
                          style: SakhiTypography.onboardingTitle,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Sakhi could not confirm the local session. Retry the connection, or continue to the welcome screen without treating the saved session as signed in.',
                          textAlign: TextAlign.center,
                          style: SakhiTypography.body,
                        ),
                        const SizedBox(height: 22),
                        FilledButton(
                          key: const Key('auth-session-retry-button'),
                          onPressed: _retryRestore,
                          child: const Text('Retry session check'),
                        ),
                        TextButton(
                          key: const Key('auth-session-continue-button'),
                          onPressed: () => setState(
                            () => _continueWithoutRestore = true,
                          ),
                          child: const Text('Continue to welcome screen'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final restoredState = snapshot.data;
        if (restoredState == AuthAccountState.existingAccount) {
          return const AppNavigationShell();
        }
        if (restoredState != null) {
          return SakhiAuthStatusScreen(
            authService: widget.authService,
            accountState: restoredState,
            isRestoredSession: true,
          );
        }

        return _onboarding(context);
      },
    );
  }
}

class SakhiProtectedHomeGate extends StatefulWidget {
  const SakhiProtectedHomeGate({super.key, required this.authService});

  final AuthService authService;

  @override
  State<SakhiProtectedHomeGate> createState() => _SakhiProtectedHomeGateState();
}

class _SakhiProtectedHomeGateState extends State<SakhiProtectedHomeGate> {
  late Future<AuthAccountState?> _state;

  @override
  void initState() {
    super.initState();
    _state = widget.authService.restoreSession();
  }

  void _recheck() {
    setState(() => _state = widget.authService.restoreSession());
  }

  Future<void> _returnToLogin() async {
    try {
      await widget.authService.logout();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => SakhiLoginScreen(authService: widget.authService),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthAccountState?>(
      future: _state,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: SakhiColors.blush,
            body: SakhiQuoteLoader.fullScreen(
              statusLabel: 'Verifying your Sakhi community access...',
            ),
          );
        }
        if (snapshot.data == AuthAccountState.existingAccount &&
            !snapshot.hasError) {
          return const AppNavigationShell();
        }
        return Scaffold(
          backgroundColor: SakhiColors.blush,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 44,
                        color: SakhiColors.purple,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Home access is still locked',
                        textAlign: TextAlign.center,
                        style: SakhiTypography.onboardingTitle,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        snapshot.hasError
                            ? 'Sakhi could not confirm the current account state with the backend.'
                            : 'The backend has not confirmed that this account is active and verified. Open Super Admin (http://127.0.0.1:5173/verifications), approve your number, then tap "Check account state again" below.',
                        textAlign: TextAlign.center,
                        style: SakhiTypography.body,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _recheck,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Check account state again'),
                      ),
                      TextButton(
                        onPressed: _returnToLogin,
                        child: const Text('Return to mobile login'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
