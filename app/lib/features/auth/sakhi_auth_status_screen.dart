import 'package:flutter/material.dart';

import '../../core/assets/app_assets.dart';
import '../../core/theme/sakhi_design_system.dart';
import '../eligibility/backend_eligibility_verification_service.dart';
import '../eligibility/eligibility_intro_screen.dart';
import '../eligibility/eligibility_verification_service.dart';
import 'auth_service.dart';
import 'backend_api_client.dart';
import 'sakhi_login_screen.dart';
import '../home/sakhi_home_screen.dart';
import 'widgets/auth_widgets.dart';

class SakhiAuthStatusScreen extends StatefulWidget {
  const SakhiAuthStatusScreen({
    super.key,
    required this.authService,
    required this.accountState,
    this.isRestoredSession = false,
  });

  final AuthService authService;
  final AuthAccountState accountState;

  /// True when this screen was restored from secure local storage on app start.
  final bool isRestoredSession;

  @override
  State<SakhiAuthStatusScreen> createState() => _SakhiAuthStatusScreenState();
}

class _SakhiAuthStatusScreenState extends State<SakhiAuthStatusScreen> {
  bool _isSigningOut = false;

  String get _heading => switch (widget.accountState) {
    AuthAccountState.existingAccount => 'Welcome back',
    AuthAccountState.newAccount => 'Continue setting up Sakhi',
    AuthAccountState.pendingVerification => 'One more step',
    AuthAccountState.restricted => 'Account access needs attention',
  };

  String get _description {
    if (widget.authService.isDevelopmentBackend) {
      return switch (widget.accountState) {
        AuthAccountState.existingAccount => 'You signed in to the local development backend. This is not a production session and does not establish eligibility verification.',
        AuthAccountState.newAccount => 'Your local development OTP was accepted. Complete the profile and draft-policy acknowledgement to save the test profile. No SMS was sent.',
        AuthAccountState.pendingVerification => 'Your development account is pending setup or review. No protected app access or eligibility status is granted by this test flow.',
        AuthAccountState.restricted => 'The backend reports this account as restricted. No protected app area is opened from this development flow.',
      };
    }
    return switch (widget.accountState) {
      AuthAccountState.existingAccount => 'The login route has been previewed. A real account session has not been established.',
      AuthAccountState.newAccount => 'Continue through the registration steps to complete the profile and required consent.',
      AuthAccountState.pendingVerification => 'This account state requires follow-up from a configured authentication service before access can be granted.',
      AuthAccountState.restricted => 'This account state must be resolved by the configured account service. No protected app area is opened from this preview.',
    };
  }

  void _returnToSignIn() {
    final navigator = Navigator.of(context);
    if (!widget.isRestoredSession && navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SakhiLoginScreen(authService: widget.authService),
      ),
    );
  }

  EligibilityVerificationService _eligibilityServiceForCurrentSession() {
    if (widget.authService.isDevelopmentBackend) {
      return BackendEligibilityVerificationService(
        // Uses the same secure token key and build-time API URL as
        // BackendAuthService; no bearer token is copied into widget state.
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
          onVerified: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(
                builder: (_) => SakhiHomeScreen(authService: widget.authService),
              ),
              (_) => false,
            );
          },
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
    return SakhiAuthScaffold(
      botanicalAsset: AppAssets.authBotanicalProfile,
      authIsDemo: widget.authService.isDemo,
      authIsDevelopmentBackend: widget.authService.isDevelopmentBackend,
      botanicalHeight: 76,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.volunteer_activism_outlined,
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
          if (widget.isRestoredSession) ...[
            const SizedBox(height: SakhiSpacing.md),
            const SakhiAuthStatusMessage(
              message: 'Your saved development session was checked with the backend. This is local test access only.',
            ),
          ],
          if (widget.authService.isDemo) ...[
            const SizedBox(height: SakhiSpacing.md),
            const SakhiAuthStatusMessage(
              message: 'DEMO ONLY — no mobile number was verified by SMS, no account was created, and no authenticated session exists. The preview Home is not treated as a protected destination.',
            ),
          ],
          if (widget.accountState == AuthAccountState.existingAccount ||
              widget.accountState == AuthAccountState.pendingVerification) ...[
            const SizedBox(height: SakhiSpacing.md),
            OutlinedButton.icon(
              key: const Key('auth-status-eligibility-button'),
              onPressed: _isSigningOut ? null : _openEligibilityVerification,
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(
                widget.authService.isDevelopmentBackend
                    ? 'Review eligibility verification'
                    : 'Preview eligibility verification',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: SakhiColors.purple,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SakhiRadii.control),
                ),
              ),
            ),
          ],
          const SizedBox(height: SakhiSpacing.lg),
          SakhiAuthSubmitButton(
            key: const Key('auth-status-back-button'),
            label: 'Return to sign in',
            icon: Icons.arrow_back_rounded,
            isLoading: _isSigningOut,
            onPressed: _isSigningOut ? null : _returnToSignIn,
          ),
          if (widget.authService.isDevelopmentBackend) ...[
            const SizedBox(height: SakhiSpacing.xs),
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
                _isSigningOut ? 'Signing out…' : 'Sign out of this session',
              ),
            ),
          ],
          const SizedBox(height: SakhiSpacing.xs),
          Center(
            child: TextButton(
              key: const Key('auth-status-create-account-button'),
              onPressed: _isSigningOut
                  ? null
                  : () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            SakhiLoginScreen(authService: widget.authService),
                      ),
                    ),
              child: const Text('Go to mobile sign in'),
            ),
          ),
        ],
      ),
    );
  }
}
