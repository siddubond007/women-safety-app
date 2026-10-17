import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/branding/app_brand.dart';
import 'core/theme/sakhi_design_system.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/auth_service_factory.dart';
import 'features/auth/sakhi_auth_status_screen.dart';
import 'features/auth/sakhi_registration_screen.dart';
import 'features/auth/sakhi_login_screen.dart';
import 'features/onboarding/sakhi_onboarding_screen.dart';

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
          return const SakhiHomeScreen();
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

class SakhiHomeScreen extends StatelessWidget {
  const SakhiHomeScreen({super.key});

  static const List<_HomeFeature> _features = [
    _HomeFeature(
      title: 'Safety & support',
      description: 'Guidance and safety resources',
      icon: Icons.shield_outlined,
      accent: Color(0xFF8B4D9C),
    ),
    _HomeFeature(
      title: 'Trusted contacts',
      description: 'A place for your support network',
      icon: Icons.favorite_border_rounded,
      accent: Color(0xFFC64C91),
    ),
    _HomeFeature(
      title: 'Wellness',
      description: 'Ideas for everyday wellbeing',
      icon: Icons.spa_outlined,
      accent: Color(0xFF9A6CB3),
    ),
    _HomeFeature(
      title: 'Community',
      description: 'Connection and opportunities',
      icon: Icons.diversity_3_outlined,
      accent: Color(0xFFB25A96),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppBrand.appName,
          style: TextStyle(
            color: sakhiPlum,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900 ? 4 : 2;
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF0DDF7), Color(0xFFFFE8F0)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to ${AppBrand.appName}',
                      style: const TextStyle(
                        color: sakhiPlum,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppBrand.description,
                      style: const TextStyle(
                        color: sakhiMutedPlum,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Text(
                'Explore ${AppBrand.appName}',
                style: TextStyle(
                  color: sakhiPlum,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 13),
              GridView.builder(
                itemCount: _features.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 13,
                  mainAxisSpacing: 13,
                  childAspectRatio: constraints.maxWidth >= 900 ? 1.12 : 1.18,
                ),
                itemBuilder: (context, index) {
                  final feature = _features[index];
                  return _HomeFeatureCard(
                    feature: feature,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _SakhiFeaturePreviewScreen(
                            feature: feature,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6EDF8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Preview build: service integrations and the backend are not connected yet. Do not rely on this prototype for emergency assistance.',
                  style: TextStyle(
                    color: sakhiMutedPlum,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeFeature {
  const _HomeFeature({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accent;
}

class _HomeFeatureCard extends StatelessWidget {
  const _HomeFeatureCard({
    required this.feature,
    required this.onTap,
  });

  final _HomeFeature feature;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: feature.accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(feature.icon, color: feature.accent, size: 27),
              ),
              const Spacer(),
              Text(
                feature.title,
                style: const TextStyle(
                  color: sakhiPlum,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                feature.description,
                style: const TextStyle(
                  color: sakhiMutedPlum,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SakhiFeaturePreviewScreen extends StatelessWidget {
  const _SakhiFeaturePreviewScreen({required this.feature});

  final _HomeFeature feature;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(feature.title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    color: feature.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(feature.icon, size: 62, color: feature.accent),
                ),
                const SizedBox(height: 24),
                Text(
                  '${feature.title} preview',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: sakhiPlum,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  feature.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: sakhiMutedPlum,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'This is a UI preview only. The related service and backend integration have not been implemented yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: sakhiMutedPlum,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
