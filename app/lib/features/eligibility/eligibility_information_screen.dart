import 'package:flutter/material.dart';

import '../../core/assets/app_assets.dart';
import '../../core/theme/sakhi_design_system.dart';
import '../auth/widgets/auth_widgets.dart';
import 'eligibility_consent_screen.dart';
import 'eligibility_verification_models.dart';
import 'eligibility_verification_service.dart';
import 'eligibility_widgets.dart';

class EligibilityInformationScreen extends StatelessWidget {
  const EligibilityInformationScreen({
    super.key,
    required this.service,
    this.onVerified,
  });

  final EligibilityVerificationService service;
  final VoidCallback? onVerified;

  String _disclosure(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Not configured or approved for this preview.';
    }
    return value.trim();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EligibilityConfiguration>(
      future: service.loadConfiguration(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SakhiAuthScaffold(
            botanicalAsset: AppAssets.authBotanicalConsent,
            authIsDemo: false,
            authIsDevelopmentBackend: service.isDevelopmentBackend,
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(SakhiSpacing.lg),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final config =
            snapshot.data ??
            const EligibilityConfiguration.previewUnavailable();

        return SakhiAuthScaffold(
          botanicalAsset: AppAssets.authBotanicalConsent,
          authIsDemo: false,
          authIsDevelopmentBackend: service.isDevelopmentBackend,
          botanicalHeight: 64,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const EligibilityStepIndicator(
                step: 2,
                totalSteps: 3,
                label: 'Review the details',
              ),
              const SizedBox(height: SakhiSpacing.md),
              const EligibilityVectorHero(
                icon: Icons.policy_outlined,
                caption: 'Nothing important should be a surprise.',
              ),
              const SizedBox(height: SakhiSpacing.md),
              const Text(
                'BEFORE YOU DECIDE',
                style: SakhiTypography.categoryLabel,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SakhiSpacing.xs),
              Text(
                'Verification information',
                textAlign: TextAlign.center,
                style: SakhiTypography.onboardingTitle.copyWith(fontSize: 25),
              ),
              const SizedBox(height: SakhiSpacing.sm),
              const Text(
                'You should know the method, what it checks, and how information is handled before you consent. Unknown details must not be guessed or treated as approved.',
                textAlign: TextAlign.center,
                style: SakhiTypography.body,
              ),
              const SizedBox(height: SakhiSpacing.md),
              if (snapshot.hasError)
                const SakhiAuthStatusMessage(
                  message: 'The eligibility configuration could not be loaded. No review request can be submitted until the backend policy is available.',
                )
              else if (config.canRequestManualReview)
                const SakhiAuthStatusMessage(
                  message: 'A separately configured manual-review request is available for this local dev/test backend. The app submits account and consent metadata only; it does not upload evidence.',
                )
              else if (!config.hasApprovedConfiguration)
                const SakhiAuthStatusMessage(
                  message: 'DEVELOPMENT PREVIEW — no approved provider flow or enabled manual-review request is configured. No request can be created.',
                )
              else if (!config.mobileHandoffSupported)
                const SakhiAuthStatusMessage(
                  message: 'The approved provider configuration was received, but this mobile build does not yet support the secure provider handoff and return flow. No provider session will be started.',
                ),
              const SizedBox(height: SakhiSpacing.md),
              if (!config.canRequestManualReview || config.canStartVerification) ...[
              _DisclosureRow(
                icon: Icons.verified_user_outlined,
                title: 'Provider',
                value: config.providerConfigured
                    ? _disclosure(config.providerDisplayName)
                    : 'No authorised provider is configured.',
              ),
              _DisclosureRow(
                icon: Icons.fact_check_outlined,
                title: 'Verification method',
                value: _disclosure(config.methodDescription),
              ),
              _DisclosureRow(
                icon: Icons.manage_search_outlined,
                title: 'Information checked',
                value: _disclosure(config.attributesCheckedDescription),
              ),
              _DisclosureRow(
                icon: Icons.face_retouching_natural_outlined,
                title: 'Selfie or liveness checks',
                value: _disclosure(config.selfieOrLivenessDescription),
              ),
              _DisclosureRow(
                icon: Icons.shield_outlined,
                title: 'Information received, stored or shared',
                value: _disclosure(config.dataHandlingDescription),
              ),
              _DisclosureRow(
                icon: Icons.delete_sweep_outlined,
                title: 'Retention and deletion',
                value: _disclosure(config.retentionAndDeletionDescription),
              ),
              _DisclosureRow(
                icon: Icons.support_agent_outlined,
                title: 'If you decline or cannot complete verification',
                value: _disclosure(config.declineOrFailureDescription),
              ),
              _DisclosureRow(
                icon: Icons.volunteer_activism_outlined,
                title: 'Approved alternative or manual review',
                value: _disclosure(config.manualReviewDescription),
              ),
              ],
              if (config.canRequestManualReview) ...[
                _DisclosureRow(icon: Icons.fact_check_outlined, title: 'Manual-review consent', value: _disclosure(config.manualReviewConsentText)),
                _DisclosureRow(icon: Icons.shield_outlined, title: 'Manual-review data handling', value: _disclosure(config.manualReviewDataHandlingDescription)),
                _DisclosureRow(icon: Icons.delete_sweep_outlined, title: 'Manual-review retention', value: _disclosure(config.manualReviewRetentionDescription)),
              ],
              const SizedBox(height: SakhiSpacing.sm),
              Container(
                padding: const EdgeInsets.all(SakhiSpacing.md),
                decoration: BoxDecoration(
                  color: SakhiColors.lavender.withValues(alpha: 0.52),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy commitments',
                      style: TextStyle(
                        color: SakhiColors.plum,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: SakhiSpacing.sm),
                    EligibilityBullet(
                      icon: Icons.do_not_disturb_on_outlined,
                      text: 'This preview does not request government identity documents, selfie photographs or biometric samples.',
                    ),
                    EligibilityBullet(
                      icon: Icons.lock_clock_outlined,
                      text: 'Sensitive records must have restricted access and defined retention and deletion periods.',
                    ),
                    EligibilityBullet(
                      icon: Icons.support_agent_outlined,
                      text: 'A technical error or provider timeout is not an eligibility rejection.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SakhiSpacing.lg),
              SakhiAuthSubmitButton(
                key: const Key('eligibility-information-continue-button'),
                label: 'Continue to consent',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EligibilityConsentScreen(
                      service: service,
                      configuration: config,
                      onVerified: onVerified,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: SakhiSpacing.xs),
              Center(
                child: TextButton(
                  key: const Key('eligibility-information-back-button'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DisclosureRow extends StatelessWidget {
  const _DisclosureRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return EligibilityDisclosureTile(icon: icon, title: title, value: value);
  }
}
