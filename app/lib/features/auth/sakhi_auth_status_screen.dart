import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/assets/app_assets.dart';
import '../../core/navigation/app_navigation_shell.dart';
import '../../core/theme/sakhi_design_system.dart';
import '../eligibility/backend_eligibility_verification_service.dart';
import '../eligibility/eligibility_intro_screen.dart';
import '../eligibility/eligibility_verification_service.dart';
import 'auth_service.dart';
import 'backend_api_client.dart';
import 'sakhi_login_screen.dart';
import 'widgets/auth_widgets.dart';

class SakhiAuthStatusScreen extends StatefulWidget {
  const SakhiAuthStatusScreen({
    super.key,
    required this.authService,
    required this.accountState,
    this.isRestoredSession = false,
    this.statusMessage,
  });

  final AuthService authService;
  final AuthAccountState accountState;
  final String? statusMessage;

  /// True when this screen was restored from secure local storage on app start.
  final bool isRestoredSession;

  @override
  State<SakhiAuthStatusScreen> createState() => _SakhiAuthStatusScreenState();
}

class _SakhiAuthStatusScreenState extends State<SakhiAuthStatusScreen> {
  late AuthAccountState _accountState;
  bool _isSigningOut = false;
  bool _isCheckingState = false;
  String? _statusFeedback;
  Timer? _autoPollTimer;

  @override
  void initState() {
    super.initState();
    _accountState = widget.accountState;
    _statusFeedback = widget.statusMessage;
    if (widget.authService.isDevelopmentBackend &&
        _accountState != AuthAccountState.existingAccount) {
      _autoPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        _silentPollAccountState();
      });
    }
  }

  @override
  void dispose() {
    _autoPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _silentPollAccountState() async {
    if (!mounted || _isCheckingState || _isSigningOut) return;
    try {
      final refreshed = await widget.authService.restoreSession();
      if (!mounted || refreshed == null) return;
      if (refreshed == AuthAccountState.existingAccount) {
        _autoPollTimer?.cancel();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const AppNavigationShell()),
        );
      }
    } catch (_) {}
  }

  String get _heading {
    if (widget.statusMessage?.startsWith('Staging test') == true) {
      return 'Staging test access enabled';
    }
    if (widget.authService.isDemo &&
        _accountState == AuthAccountState.existingAccount) {
      return 'Welcome back';
    }
    return switch (_accountState) {
      AuthAccountState.existingAccount => 'Account verified & active',
      AuthAccountState.newAccount => 'Continue setting up Sakhi',
      AuthAccountState.pendingVerification => 'One more step',
      AuthAccountState.restricted => 'Account access needs attention',
    };
  }

  String get _description {
    if (widget.statusMessage?.startsWith('Staging test') == true) {
      return widget.statusMessage!;
    }
    if (widget.authService.isDevelopmentBackend) {
      final restoredPrefix = widget.isRestoredSession
          ? 'Your saved development session was checked with the local backend. '
          : '';
      return switch (_accountState) {
        AuthAccountState.existingAccount =>
          '${restoredPrefix}Your account is ACTIVE and VERIFIED in the backend. Tap below to open the Sakhi Home screen.',
        AuthAccountState.newAccount =>
          '${restoredPrefix}Your local development OTP was accepted. Complete the profile and policy acknowledgement to finish registration.',
        AuthAccountState.pendingVerification =>
          '${restoredPrefix}Home access is locked until verified. Your account is registered in PostgreSQL as Pending Verification. Open the Super Admin panel (http://127.0.0.1:5173), approve verification for your number, and then tap "Check account state again" below.',
        AuthAccountState.restricted =>
          '${restoredPrefix}The backend reports this account as restricted. Update its state in Super Admin to restore access.',
      };
    }
    return switch (_accountState) {
      AuthAccountState.existingAccount => 'The login route has been previewed, but no authenticated session exists. Protected Home remains locked until a configured authentication backend confirms the account.',
      AuthAccountState.newAccount => 'Continue through the registration steps to complete the profile and required consent.',
      AuthAccountState.pendingVerification => 'This account state requires follow-up from a configured authentication service before access can be granted.',
      AuthAccountState.restricted => 'This account state must be resolved by the configured account service.',
    };
  }

  Future<void> _recheckAccountState() async {
    if (_isCheckingState || _isSigningOut) return;
    setState(() {
      _isCheckingState = true;
      _statusFeedback = null;
    });
    try {
      final refreshed = await widget.authService.restoreSession();
      if (!mounted) return;
      if (refreshed == null) {
        setState(() {
          _statusFeedback = 'Session expired. Please sign in again.';
        });
        return;
      }
      setState(() {
        _accountState = refreshed;
      });
      if (refreshed == AuthAccountState.existingAccount) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const AppNavigationShell()),
        );
      } else {
        setState(() {
          _statusFeedback = 'Still pending verification in PostgreSQL. Verify this member in Super Admin (http://127.0.0.1:5173/verifications), then tap Check again.';
        });
      }
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() => _statusFeedback = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusFeedback =
            'Could not reach the backend. Check that the server is running.';
      });
    } finally {
      if (mounted) setState(() => _isCheckingState = false);
    }
  }

  EligibilityVerificationService _eligibilityServiceForCurrentSession() {
    if (widget.authService.isDevelopmentBackend) {
      return BackendEligibilityVerificationService(
        apiClient: BackendApiClient(),
      );
    }
    return const DemoEligibilityVerificationService();
  }

  void _openEligibilityVerification() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EligibilityIntroScreen(
          service: _eligibilityServiceForCurrentSession(),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    String? warning;

    try {
      await widget.authService.logout();
    } on AuthServiceException {
      warning = 'Signed out on this device, but the backend could not confirm server-session revocation.';
    } catch (_) {
      warning = 'Signed out on this device, but the backend could not confirm server-session revocation.';
    }

    if (!mounted) return;
    setState(() => _isSigningOut = false);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (loginContext) {
          if (warning != null) {
            final message = warning;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (loginContext.mounted) {
                ScaffoldMessenger.maybeOf(loginContext)
                    ?.showSnackBar(SnackBar(content: Text(message)));
              }
            });
          }
          return SakhiLoginScreen(authService: widget.authService);
        },
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = _accountState == AuthAccountState.existingAccount;
    return SakhiAuthScaffold(
      botanicalAsset: AppAssets.authBotanicalProfile,
      authIsDemo: widget.authService.isDemo,
      authIsDevelopmentBackend: widget.authService.isDevelopmentBackend,
      botanicalHeight: 76,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            isVerified
                ? Icons.verified_user_rounded
                : Icons.lock_outline_rounded,
            color: SakhiColors.purple,
            size: 54,
          ),
          const SizedBox(height: SakhiSpacing.md),
          Text(
            _heading,
            textAlign: TextAlign.center,
            style: SakhiTypography.onboardingTitle.copyWith(fontSize: 25),
          ),
          const SizedBox(height: SakhiSpacing.sm),
          Text(
            _description,
            textAlign: TextAlign.center,
            style: SakhiTypography.body,
          ),
          if (_statusFeedback != null) ...[
            const SizedBox(height: SakhiSpacing.md),
            SakhiAuthStatusMessage(message: _statusFeedback!),
          ],
          if (isVerified && widget.authService.isDevelopmentBackend) ...[
            const SizedBox(height: SakhiSpacing.lg),
            FilledButton.icon(
              key: const Key('auth-status-home-button'),
              onPressed: _isSigningOut
                  ? null
                  : () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => const AppNavigationShell(),
                      ),
                    ),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Open Sakhi Home Screen'),
              style: FilledButton.styleFrom(
                backgroundColor: SakhiColors.purple,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SakhiRadii.control),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: SakhiSpacing.lg),
            FilledButton.icon(
              key: const Key('auth-status-recheck-button'),
              onPressed: _isCheckingState || _isSigningOut
                  ? null
                  : _recheckAccountState,
              icon: _isCheckingState
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(
                _isCheckingState
                    ? 'Checking with backend…'
                    : 'Check account state again',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: SakhiColors.purple,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SakhiRadii.control),
                ),
              ),
            ),
          ],
          if (_accountState == AuthAccountState.existingAccount ||
              _accountState == AuthAccountState.pendingVerification) ...[
            const SizedBox(height: SakhiSpacing.sm),
            OutlinedButton.icon(
              key: const Key('auth-status-eligibility-button'),
              onPressed: _isSigningOut ? null : _openEligibilityVerification,
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Submit / review eligibility verification'),
              style: OutlinedButton.styleFrom(
                foregroundColor: SakhiColors.purple,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SakhiRadii.control),
                ),
              ),
            ),
          ],
          const SizedBox(height: SakhiSpacing.md),
          OutlinedButton.icon(
            key: const Key('auth-status-sign-out-button'),
            onPressed: _isSigningOut ? null : _signOut,
            icon: _isSigningOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
            label: Text(
              _isSigningOut
                  ? 'Signing out…'
                  : 'Sign out & return to mobile login',
            ),
          ),
        ],
      ),
    );
  }
}
