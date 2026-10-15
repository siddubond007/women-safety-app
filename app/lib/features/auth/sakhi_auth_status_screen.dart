import 'package:flutter/material.dart';

import '../../core/assets/app_assets.dart';
import '../../core/theme/sakhi_design_system.dart';
import 'auth_service.dart';
import 'sakhi_login_screen.dart';
import 'widgets/auth_widgets.dart';

class SakhiAuthStatusScreen extends StatelessWidget {
  const SakhiAuthStatusScreen({
    super.key,
    required this.authService,
    required this.accountState,
  });

  final AuthService authService;
  final AuthAccountState accountState;

  String get _heading => switch (accountState) {
    AuthAccountState.existingAccount => 'Welcome back',
    AuthAccountState.newAccount => 'Continue setting up Sakhi',
    AuthAccountState.pendingVerification => 'One more step',
    AuthAccountState.restricted => 'Account access needs attention',
  };

  String get _description => switch (accountState) {
    AuthAccountState.existingAccount => 'The login route has been previewed. A real account session has not been established.',
    AuthAccountState.newAccount => 'Continue through the registration steps to complete the profile and required consent.',
    AuthAccountState.pendingVerification => 'This account state requires follow-up from a configured authentication service before access can be granted.',
    AuthAccountState.restricted => 'This account state must be resolved by the configured account service. No protected app area is opened from this preview.',
  };

  @override
  Widget build(BuildContext context) {
    return SakhiAuthScaffold(
      botanicalAsset: AppAssets.authBotanicalProfile,
      authIsDemo: authService.isDemo,
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
          if (authService.isDemo) ...[
            const SizedBox(height: SakhiSpacing.md),
            const SakhiAuthStatusMessage(
              message: 'DEMO ONLY — no mobile number was verified by SMS, no account was created, and no authenticated session exists. The preview Home is not treated as a protected destination.',
            ),
          ],
          const SizedBox(height: SakhiSpacing.lg),
          SakhiAuthSubmitButton(
            key: const Key('auth-status-back-button'),
            label: 'Return to sign in',
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: SakhiSpacing.xs),
          Center(
            child: TextButton(
              key: const Key('auth-status-create-account-button'),
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => SakhiLoginScreen(authService: authService),
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
