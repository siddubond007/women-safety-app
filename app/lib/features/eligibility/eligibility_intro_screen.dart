import 'package:flutter/material.dart';

import '../../core/assets/app_assets.dart';
import '../../core/theme/sakhi_design_system.dart';
import '../auth/widgets/auth_widgets.dart';
import 'eligibility_information_screen.dart';
import 'eligibility_verification_models.dart';
import 'eligibility_verification_service.dart';
import 'eligibility_widgets.dart';

class EligibilityIntroScreen extends StatelessWidget {
  const EligibilityIntroScreen({
    super.key,
    required this.service,
    this.onVerified,
  });

  final EligibilityVerificationService service;
  final ValueChanged<EligibilityStatusResult>? onVerified;

  @override
  Widget build(BuildContext context) {
    return SakhiAuthScaffold(
      botanicalAsset: AppAssets.authBotanicalConsent,
      authIsDemo: false,
      authIsDevelopmentBackend: service.isDevelopmentBackend,
      botanicalHeight: 68,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EligibilityStepIndicator(
            step: 1,
            totalSteps: 3,
            label: 'A transparent process',
          ),
          const SizedBox(height: SakhiSpacing.md),
          const EligibilityVectorHero(
            icon: Icons.shield_outlined,
            caption: 'Private by design. Clear by choice.',
          ),
          const SizedBox(height: SakhiSpacing.md),
          const Text(
            'ELIGIBILITY VERIFICATION',
            style: SakhiTypography.categoryLabel,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SakhiSpacing.xs),
          Text(
            'Help us keep Sakhi a trusted space',
            textAlign: TextAlign.center,
            style: SakhiTypography.onboardingTitle.copyWith(fontSize: 25),
          ),
          const SizedBox(height: SakhiSpacing.sm),
          const Text(
            'Sakhi plans a separate eligibility check for community features reserved for verified members. It is different from confirming control of a mobile number.',
            textAlign: TextAlign.center,
            style: SakhiTypography.body,
          ),
          const SizedBox(height: SakhiSpacing.md),
          const SakhiAuthStatusMessage(
            message: 'DEVELOPMENT PREVIEW — no approved verification provider or production eligibility policy is configured. This screen does not verify identity or eligibility.',
          ),
          const SizedBox(height: SakhiSpacing.md),
          const EligibilityPrincipleCard(
            icon: Icons.menu_book_outlined,
            title: 'Understand before you decide',
            description: 'The approved method, information used and consequences must be explained before consent.',
          ),
          const SizedBox(height: SakhiSpacing.xs),
          const EligibilityPrincipleCard(
            icon: Icons.lock_outline_rounded,
            title: 'Your information deserves care',
            description: 'Only the minimum permitted result should be received, with access and retention controls.',
          ),
          const SizedBox(height: SakhiSpacing.xs),
          const EligibilityPrincipleCard(
            icon: Icons.visibility_off_outlined,
            title: 'No assumptions about appearance',
            description:
                'Sakhi must never infer gender from a face, name or voice.',
            iconColor: SakhiColors.pinkAccent,
          ),
          const SizedBox(height: SakhiSpacing.md),
          const EligibilityBullet(
            icon: Icons.fact_check_outlined,
            text: 'A phone OTP or Aadhaar OTP alone does not establish eligibility.',
          ),
          const SizedBox(height: SakhiSpacing.md),
          SakhiAuthSubmitButton(
            key: const Key('eligibility-review-details-button'),
            label: 'Review verification details',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EligibilityInformationScreen(service: service, onVerified: onVerified),
              ),
            ),
          ),
          const SizedBox(height: SakhiSpacing.xs),
          TextButton(
            key: const Key('eligibility-intro-privacy-button'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const SakhiPolicyDocumentScreen(title: 'Privacy Policy'),
              ),
            ),
            child: const Text('Read the current draft Privacy Policy'),
          ),
          Center(
            child: TextButton(
              key: const Key('eligibility-intro-back-button'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not now · Back'),
            ),
          ),
        ],
      ),
    );
  }
}
