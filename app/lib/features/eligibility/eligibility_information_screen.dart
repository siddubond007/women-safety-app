import 'package:flutter/material.dart';

import '../../core/assets/app_assets.dart';
import '../../core/theme/sakhi_design_system.dart';
import '../auth/widgets/auth_widgets.dart';
import 'eligibility_consent_screen.dart';
import 'eligibility_verification_models.dart';
import 'eligibility_verification_service.dart';

class EligibilityInformationScreen extends StatelessWidget {
  const EligibilityInformationScreen({super.key, required this.service});

  final EligibilityVerificationService service;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'BEFORE YOU DECIDE',
                style: SakhiTypography.categoryLabel,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SakhiSpacing.sm),
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
                  message: 'The approved verification configuration could not be loaded. Treat verification as unavailable; no session will be created.',
                )
              else if (!config.canStartVerification)
                const SakhiAuthStatusMessage(
                  message: 'DEVELOPMENT PREVIEW — the provider, approved method, policy and complete disclosures are not configured. No real verification can start.',
                ),
              const SizedBox(height: SakhiSpacing.md),
              _DisclosureRow(
                title: 'Provider',
                value: config.providerConfigured
                    ? _disclosure(config.providerDisplayName)
                    : 'No authorised provider is configured.',
              ),
              _DisclosureRow(
                title: 'Verification method',
                value: _disclosure(config.methodDescription),
              ),
              _DisclosureRow(
                title: 'Information checked',
                value: _disclosure(config.attributesCheckedDescription),
              ),
              _DisclosureRow(
                title: 'Selfie or liveness checks',
                value: _disclosure(config.selfieOrLivenessDescription),
              ),
              _DisclosureRow(
                title: 'Information received, stored or shared',
                value: _disclosure(config.dataHandlingDescription),
              ),
              _DisclosureRow(
                title: 'Retention and deletion',
                value: _disclosure(config.retentionAndDeletionDescription),
              ),
              _DisclosureRow(
                title: 'If you decline or cannot complete verification',
                value: _disclosure(config.declineOrFailureDescription),
              ),
              _DisclosureRow(
                title: 'Approved alternative or manual review',
                value: _disclosure(config.manualReviewDescription),
              ),
              const SizedBox(height: SakhiSpacing.md),
              const Text(
                'This preview does not request government identity documents, selfie photographs, or biometric samples. A technical error or provider timeout must not be treated as an eligibility rejection.',
                style: SakhiTypography.body,
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
  const _DisclosureRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SakhiSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SakhiSpacing.md),
        decoration: BoxDecoration(
          color: SakhiColors.ivory,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SakhiColors.progressInactive),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: SakhiColors.plum,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: SakhiSpacing.xxs),
            Text(value, style: SakhiTypography.body),
          ],
        ),
      ),
    );
  }
}
