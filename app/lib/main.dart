import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/branding/app_brand.dart';
import 'core/theme/sakhi_design_system.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/auth_service_factory.dart';
import 'features/auth/sakhi_auth_status_screen.dart';
import 'features/auth/sakhi_login_screen.dart';
import 'features/auth/sakhi_registration_screen.dart';
import 'features/home/sakhi_home_dashboard_screen.dart';
import 'features/onboarding/sakhi_onboarding_screen.dart';

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

class SakhiApp extends StatelessWidget {
  const SakhiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = authServiceForCurrentBuild();
    return MaterialApp(
      title: AppBrand.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: SakhiColors.blush,
        colorScheme: ColorScheme.fromSeed(
          seedColor: SakhiColors.purple,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: SakhiColors.blush,
          foregroundColor: SakhiColors.plum,
          centerTitle: false,
          elevation: 0,
        ),
      ),
      routes: {
        '/home': (_) => SakhiProtectedHomeGate(authService: authService),
      },
      home: SakhiStartupRouter(authService: authService),
    );
  }
}

/// Restores a locally persisted development session before showing the
/// existing onboarding flow. A failed restore is fail-closed and offers retry.
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
            body: Center(
              child: CircularProgressIndicator(color: SakhiColors.purple),
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

/// Named home route that rechecks the authoritative backend session.
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

  void _returnToLogin() {
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
            body: Center(child: CircularProgressIndicator(color: SakhiColors.purple)),
          );
        }
        if (snapshot.data == AuthAccountState.existingAccount && !snapshot.hasError) {
          return SakhiHomeDashboardScreen(authService: widget.authService);
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
                      const Icon(Icons.lock_outline_rounded, size: 44, color: SakhiColors.purple),
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
                            : 'The backend has not confirmed that this account is active and verified. Update the development account state in Super Admin, then check again.',
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
