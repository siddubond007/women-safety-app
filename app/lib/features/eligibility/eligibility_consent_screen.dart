import 'package:flutter/material.dart';

import '../../core/assets/app_assets.dart';
import '../../core/theme/sakhi_design_system.dart';
import '../auth/widgets/auth_widgets.dart';
import 'eligibility_status_screen.dart';
import 'eligibility_verification_models.dart';
import 'eligibility_verification_service.dart';
import 'eligibility_widgets.dart';

class EligibilityConsentScreen extends StatefulWidget {
  const EligibilityConsentScreen({
    super.key,
    required this.service,
    required this.configuration,
  });

  final EligibilityVerificationService service;
  final EligibilityConfiguration configuration;

  @override
  State<EligibilityConsentScreen> createState() =>
      _EligibilityConsentScreenState();
}

class _EligibilityConsentScreenState extends State<EligibilityConsentScreen> {
  bool _consentSelected = false;
  bool _biometricConsentSelected = false;
  bool _isWorking = false;
  DateTime? _consentSelectedAt;

  Future<void> _startVerification() async {
    if (!_consentSelected ||
        !widget.configuration.canStartVerification ||
        (widget.configuration.biometricProcessingRequired &&
            !_biometricConsentSelected) ||
        _isWorking) {
      return;
    }

    final version = widget.configuration.consentVersion;
    if (version == null || version.trim().isEmpty) return;

    setState(() => _isWorking = true);
    try {
      final result = await widget.service.startVerification(
        consent: EligibilityConsentRecord(
          consentVersion: version,
          acceptedAt: _consentSelectedAt ?? DateTime.now(),
          biometricProcessingConsented: _biometricConsentSelected,
        ),
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EligibilityStatusScreen(
            result: result,
            isDevelopmentBackend: widget.service.isDevelopmentBackend,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EligibilityStatusScreen(
            isDevelopmentBackend: widget.service.isDevelopmentBackend,
            result: const EligibilityStatusResult(
              status: EligibilityStatus.verificationFailed,
              message: 'The status could not be confirmed. This technical problem is not an eligibility decision.',
              isDemo: true,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _submitManualReview() async {
    if (!_consentSelected ||
        !widget.configuration.canRequestManualReview ||
        _isWorking) {
      return;
    }
    final version = widget.configuration.manualReviewConsentVersion;
    if (version == null || version.trim().isEmpty) return;
    setState(() => _isWorking = true);
    try {
      final result = await widget.service.submitManualReview(
        consent: EligibilityConsentRecord(
          consentVersion: version,
          acceptedAt: _consentSelectedAt ?? DateTime.now(),
        ),
      );
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => EligibilityStatusScreen(
          result: result,
          isDevelopmentBackend: widget.service.isDevelopmentBackend,
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => EligibilityStatusScreen(
          isDevelopmentBackend: widget.service.isDevelopmentBackend,
          result: const EligibilityStatusResult(
            status: EligibilityStatus.verificationFailed,
            message: 'The manual-review request could not be confirmed. No eligibility conclusion can be drawn; check the connection and current status.',
            isDemo: true,
          ),
        ),
      ));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _viewStatus() async {
    if (_isWorking) return;
    setState(() => _isWorking = true);
    try {
      final result = await widget.service.readStatus();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EligibilityStatusScreen(
            result: result,
            isDevelopmentBackend: widget.service.isDevelopmentBackend,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EligibilityStatusScreen(
            isDevelopmentBackend: widget.service.isDevelopmentBackend,
            result: const EligibilityStatusResult(
              status: EligibilityStatus.providerUnavailable,
              message: 'A trusted eligibility status is unavailable. No conclusion about eligibility can be drawn.',
              isDemo: true,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerConfigurationReady = widget.configuration.hasApprovedConfiguration;
    final canStart = widget.configuration.canStartVerification;
    final canRequestManualReview = widget.configuration.canRequestManualReview;
    final manualReviewFlow = canRequestManualReview && !canStart;
    final configurationReady = providerConfigurationReady || canRequestManualReview;
    final biometricConsentRequired =
        widget.configuration.biometricProcessingRequired;
    final showBiometricConsent =
        canStart && widget.configuration.biometricProcessingSupported;

    return SakhiAuthScaffold(
      botanicalAsset: AppAssets.authBotanicalConsent,
      authIsDemo: false,
      authIsDevelopmentBackend: widget.service.isDevelopmentBackend,
      botanicalHeight: 58,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EligibilityStepIndicator(
            step: 3,
            totalSteps: 3,
            label: 'Your decision',
          ),
          const SizedBox(height: SakhiSpacing.md),
          const EligibilityVectorHero(
            icon: Icons.lock_outline_rounded,
            caption: 'Consent is a choice—not a shortcut.',
          ),
          const SizedBox(height: SakhiSpacing.md),
          const Text(
            'YOUR CHOICE',
            style: SakhiTypography.categoryLabel,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SakhiSpacing.xs),
          Text(
            'Eligibility consent',
            textAlign: TextAlign.center,
            style: SakhiTypography.onboardingTitle.copyWith(fontSize: 25),
          ),
          const SizedBox(height: SakhiSpacing.sm),
          Text(
            manualReviewFlow
                ? 'This request sends your consent and a manual-review request to the Sakhi development/test backend. This app does not capture or upload identity evidence.'
                : 'In production, Sakhi must identify the approved method, explain what it checks, and disclose how the relevant information is handled before asking for valid consent.',
            textAlign: TextAlign.center,
            style: SakhiTypography.body,
          ),
          const SizedBox(height: SakhiSpacing.md),
          if (manualReviewFlow)
            const SakhiAuthStatusMessage(
              message: 'Manual review is enabled by the backend for this local dev/test deployment. Only request and consent metadata are sent; no selfie, identity document or evidence file is uploaded from this app.',
            )
          else if (!configurationReady)
            const SakhiAuthStatusMessage(
              message: 'DEMO CONSENT PREVIEW — no approved provider or manual-review process is configured. Your selection is not recorded as valid production consent.',
            )
          else if (!canStart)
            const SakhiAuthStatusMessage(
              message: 'The provider configuration is available, but this app cannot yet complete the secure provider handoff and return flow. No provider session will be started.',
            )
          else
            const SakhiAuthStatusMessage(
              message: 'Review the approved details above before consenting. A trusted backend response—not a redirect or client action—must determine eligibility.',
            ),
          const SizedBox(height: SakhiSpacing.md),
          Container(
            padding: const EdgeInsets.all(SakhiSpacing.md),
            decoration: BoxDecoration(
              color: SakhiColors.lavender.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: SakhiColors.progressInactive.withValues(alpha: 0.8),
              ),
            ),
            child: manualReviewFlow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Before you submit', style: TextStyle(
                        color: SakhiColors.plum,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      )),
                      const SizedBox(height: SakhiSpacing.sm),
                      EligibilityBullet(text: widget.configuration.manualReviewDescription!),
                      EligibilityBullet(text: widget.configuration.manualReviewDataHandlingDescription!),
                      EligibilityBullet(text: widget.configuration.manualReviewRetentionDescription!),
                      const EligibilityBullet(text: 'This app does not capture or upload identity evidence. Reviewers use only the separately approved evidence procedure outside this portal.'),
                    ],
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Before you continue', style: TextStyle(
                        color: SakhiColors.plum,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      )),
                      SizedBox(height: SakhiSpacing.sm),
                      EligibilityBullet(text: 'You can read the verification method and data-use details before deciding.'),
                      EligibilityBullet(text: 'A future provider must return a trusted result; a redirect or OTP alone is not proof of eligibility.'),
                      EligibilityBullet(text: 'A failure or timeout is not an eligibility decision.'),
                    ],
                  ),
          ),
          const SizedBox(height: SakhiSpacing.md),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: BoxDecoration(
                color: SakhiColors.ivory,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _consentSelected
                      ? SakhiColors.purple.withValues(alpha: 0.65)
                      : SakhiColors.progressInactive,
                  width: _consentSelected ? 1.4 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SakhiSpacing.xs,
                  vertical: SakhiSpacing.xs,
                ),
                child: CheckboxListTile(
                  key: const Key('eligibility-consent-checkbox'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: SakhiSpacing.xs,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _consentSelected,
                  activeColor: SakhiColors.purple,
                  onChanged: _isWorking
                      ? null
                      : (value) => setState(() {
                          _consentSelected = value ?? false;
                          _consentSelectedAt = _consentSelected
                              ? DateTime.now()
                              : null;
                        }),
                  title: Text(
                    manualReviewFlow
                        ? widget.configuration.manualReviewConsentText!
                        : canStart
                        ? 'I have read the approved verification details above and explicitly consent to this eligibility-verification process.'
                        : 'I select this control for the demo preview and understand that no real verification will occur.',
                    style: const TextStyle(
                      color: SakhiColors.plum,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showBiometricConsent) ...[
            const SizedBox(height: SakhiSpacing.sm),
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: BoxDecoration(
                  color: SakhiColors.ivory,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _biometricConsentSelected
                        ? SakhiColors.purple.withValues(alpha: 0.65)
                        : SakhiColors.progressInactive,
                  ),
                ),
                child: CheckboxListTile(
                  key: const Key('eligibility-biometric-consent-checkbox'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: SakhiSpacing.sm,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _biometricConsentSelected,
                  activeColor: SakhiColors.purple,
                  onChanged: _isWorking
                      ? null
                      : (value) => setState(
                          () => _biometricConsentSelected = value ?? false,
                        ),
                  title: Text(
                    biometricConsentRequired
                        ? 'I separately consent to the biometric processing described in the approved verification details.'
                        : 'I optionally consent to the biometric processing described in the approved verification details.',
                    style: const TextStyle(
                      color: SakhiColors.plum,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: SakhiSpacing.xs),
          if (!configurationReady)
            const SakhiAuthStatusMessage(message: 'Neither a provider flow nor an approved manual-review request is configured. No request can be sent.')
          else if (manualReviewFlow)
            const SakhiAuthStatusMessage(message: 'Manual-review requests contain consent and account metadata only. No identity evidence is uploaded in this mobile flow.')
          else if (!canStart)
            const SakhiAuthStatusMessage(message: 'The provider flow stays disabled until secure handoff and return handling are implemented and tested.')
          else if (biometricConsentRequired && !_biometricConsentSelected)
            const SakhiAuthStatusMessage(message: 'Separate explicit biometric consent is required before the verification session can start.'),
          const SizedBox(height: SakhiSpacing.md),
          if (manualReviewFlow)
            SakhiAuthSubmitButton(
              key: const Key('eligibility-submit-manual-review-button'),
              label: 'Submit manual-review request',
              icon: Icons.support_agent_outlined,
              isLoading: _isWorking,
              onPressed: _consentSelected && !_isWorking ? _submitManualReview : null,
            )
          else
            SakhiAuthSubmitButton(
              key: const Key('eligibility-start-verification-button'),
              label: !canStart
                  ? 'Start verification · Not configured'
                  : biometricConsentRequired && !_biometricConsentSelected
                  ? 'Separate biometric consent required'
                  : 'Start verification',
              icon: Icons.verified_user_outlined,
              isLoading: _isWorking,
              onPressed:
                  _consentSelected &&
                      canStart &&
                      (!biometricConsentRequired || _biometricConsentSelected) &&
                      !_isWorking
                  ? _startVerification
                  : null,
            ),
          const SizedBox(height: SakhiSpacing.xs),
          OutlinedButton(
            key: const Key('eligibility-preview-status-button'),
            onPressed: _isWorking ? null : _viewStatus,
            style: OutlinedButton.styleFrom(
              foregroundColor: SakhiColors.purple,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SakhiRadii.control),
              ),
            ),
            child: Text(
              manualReviewFlow || canStart
                  ? 'View current eligibility status'
                  : 'View provider-unavailable preview',
            ),
          ),
          const SizedBox(height: SakhiSpacing.xs),
          Center(
            child: TextButton(
              key: const Key('eligibility-consent-policy-button'),
              onPressed: _isWorking
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SakhiPolicyDocumentScreen(
                          title: 'Privacy Policy',
                        ),
                      ),
                    ),
              child: const Text('Review the Privacy Policy'),
            ),
          ),
          Center(
            child: TextButton(
              key: const Key('eligibility-consent-back-button'),
              onPressed: _isWorking ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel · Back'),
            ),
          ),
        ],
      ),
    );
  }
}
