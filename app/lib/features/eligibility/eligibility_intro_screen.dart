import 'package:flutter/material.dart';

import '../../core/assets/app_assets.dart';
import '../../core/theme/sakhi_design_system.dart';
import '../auth/widgets/auth_widgets.dart';
import 'eligibility_information_screen.dart';
import 'eligibility_verification_service.dart';

class EligibilityIntroScreen extends StatelessWidget {
  const EligibilityIntroScreen({super.key, required this.service});

  final EligibilityVerificationService service;

  @override
  Widget build(BuildContext context) {
    return SakhiAuthScaffold(
      botanicalAsset: AppAssets.authBotanicalConsent,
      authIsDemo: false,
      botanicalHeight: 68,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ELIGIBILITY VERIFICATION',
            style: SakhiTypography.categoryLabel,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SakhiSpacing.sm),
          Text(
            'Help us keep Sakhi a trusted space',
            textAlign: TextAlign.center,
            style: SakhiTypography.onboardingTitle.copyWith(fontSize: 25),
          ),
          const SizedBox(height: SakhiSpacing.sm),
          const Text(
            'Sakhi plans to use a separate eligibility check for community features reserved for verified members. This is different from confirming control of a mobile number.',
            textAlign: TextAlign.center,
            style: SakhiTypography.body,
          ),
          const SizedBox(height: SakhiSpacing.md),
          const SakhiAuthStatusMessage(
            message: 'DEVELOPMENT PREVIEW — no approved verification provider or production eligibility policy is configured. This screen does not verify identity or eligibility.',
          ),
          const SizedBox(height: SakhiSpacing.md),
          const _PrincipleRow(
            icon: Icons.privacy_tip_outlined,
            title: 'Clear information before consent',
            description: 'The method and data use must be explained before any real verification begins.',
          ),
          const SizedBox(height: SakhiSpacing.sm),
          const _PrincipleRow(
            icon: Icons.lock_outline_rounded,
            title: 'Only the minimum permitted result',
            description: 'A future integration must limit identity data and protect verification records.',
          ),
          const SizedBox(height: SakhiSpacing.sm),
          const _PrincipleRow(
            icon: Icons.visibility_off_outlined,
            title: 'No guessing from appearance',
            description: 'Sakhi must never infer gender from a person’s face or appearance.',
          ),
          const SizedBox(height: SakhiSpacing.lg),
          SakhiAuthSubmitButton(
            key: const Key('eligibility-review-details-button'),
            label: 'Review verification details',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EligibilityInformationScreen(service: service),
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

class _PrincipleRow extends StatelessWidget {
  const _PrincipleRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: SakhiColors.lavender,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: SakhiColors.purple, size: 21),
        ),
        const SizedBox(width: SakhiSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: SakhiColors.plum,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(description, style: SakhiTypography.body),
            ],
          ),
        ),
      ],
    );
  }
}
