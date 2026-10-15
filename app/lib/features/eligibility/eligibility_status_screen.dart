import 'package:flutter/material.dart';

import '../../core/assets/app_assets.dart';
import '../../core/theme/sakhi_design_system.dart';
import '../auth/widgets/auth_widgets.dart';
import 'eligibility_verification_models.dart';

class EligibilityStatusScreen extends StatelessWidget {
  const EligibilityStatusScreen({super.key, required this.result});

  final EligibilityStatusResult result;

  String get _heading => switch (result.status) {
    EligibilityStatus.notStarted => 'Verification not started',
    EligibilityStatus.consentRequired => 'Consent is required',
    EligibilityStatus.inProgress => 'Verification in progress',
    EligibilityStatus.pendingManualReview => 'Pending manual review',
    EligibilityStatus.verified =>
      result.isDemo ? 'Demo status: verified' : 'Eligibility verified',
    EligibilityStatus.verificationFailed => 'Unable to verify right now',
    EligibilityStatus.rejected =>
      result.isDemo
          ? 'Demo status: rejected'
          : 'Eligibility decision: rejected',
    EligibilityStatus.cancelled => 'Verification cancelled',
    EligibilityStatus.reverificationRequired => 'Further verification required',
    EligibilityStatus.providerUnavailable =>
      'Verification is not available yet',
    EligibilityStatus.consentNotGiven => 'Consent was not given',
  };

  String get _explanation => switch (result.status) {
    EligibilityStatus.notStarted =>
      'No eligibility-verification attempt has started.',
    EligibilityStatus.consentRequired =>
      'The required, informed consent step has not been completed.',
    EligibilityStatus.inProgress => 'A configured service reports that a verification process is underway. This state alone is not a final decision.',
    EligibilityStatus.pendingManualReview => 'The result is awaiting review. It is not a rejection or a verified decision.',
    EligibilityStatus.verified =>
      result.isDemo
          ? 'This is only a simulated status. It does not verify identity or eligibility and does not grant protected access.'
          : 'This status must be confirmed by the trusted backend. Protected APIs must still enforce access server-side.',
    EligibilityStatus.verificationFailed => 'A technical or provider problem prevented completion. A failure or timeout does not establish ineligibility.',
    EligibilityStatus.rejected =>
      result.isDemo
          ? 'A demo cannot make an eligibility decision. No rejection has occurred.'
          : 'Show this state only after a genuine, confirmed eligibility decision from the trusted backend.',
    EligibilityStatus.cancelled => 'The flow was cancelled before completion. This does not establish ineligibility.',
    EligibilityStatus.reverificationRequired => 'Further verification may be required only under an approved policy and confirmed backend status.',
    EligibilityStatus.providerUnavailable => 'The provider or its approved configuration is unavailable. No eligibility conclusion can be drawn.',
    EligibilityStatus.consentNotGiven =>
      'No verification session should be created without explicit consent.',
  };

  IconData get _icon => switch (result.status) {
    EligibilityStatus.verified => Icons.verified_user_outlined,
    EligibilityStatus.pendingManualReview => Icons.hourglass_empty_rounded,
    EligibilityStatus.inProgress => Icons.sync_rounded,
    EligibilityStatus.rejected => Icons.gpp_bad_outlined,
    EligibilityStatus.verificationFailed => Icons.cloud_off_outlined,
    EligibilityStatus.cancelled => Icons.cancel_outlined,
    EligibilityStatus.providerUnavailable => Icons.settings_outlined,
    EligibilityStatus.consentRequired ||
    EligibilityStatus.consentNotGiven => Icons.fact_check_outlined,
    EligibilityStatus.reverificationRequired => Icons.refresh_rounded,
    EligibilityStatus.notStarted => Icons.lock_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return SakhiAuthScaffold(
      botanicalAsset: AppAssets.authBotanicalConsent,
      authIsDemo: false,
      botanicalHeight: 56,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ELIGIBILITY STATUS',
            style: SakhiTypography.categoryLabel,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SakhiSpacing.md),
          Center(
            child: Container(
              width: 78,
              height: 78,
              decoration: const BoxDecoration(
                color: SakhiColors.lavender,
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, size: 40, color: SakhiColors.purple),
            ),
          ),
          const SizedBox(height: SakhiSpacing.md),
          Text(
            _heading,
            textAlign: TextAlign.center,
            style: SakhiTypography.onboardingTitle.copyWith(fontSize: 24),
          ),
          const SizedBox(height: SakhiSpacing.sm),
          Text(
            result.message,
            textAlign: TextAlign.center,
            style: SakhiTypography.body,
          ),
          const SizedBox(height: SakhiSpacing.md),
          if (result.isDemo)
            const SakhiAuthStatusMessage(
              message: 'DEMO RESULT — no real identity verification occurred. This status must not grant access to protected community features.',
            ),
          if (result.isDemo) const SizedBox(height: SakhiSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(SakhiSpacing.md),
            decoration: BoxDecoration(
              color: SakhiColors.ivory,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SakhiColors.progressInactive),
            ),
            child: Text(_explanation, style: SakhiTypography.body),
          ),
          const SizedBox(height: SakhiSpacing.lg),
          SakhiAuthSubmitButton(
            key: const Key('eligibility-status-back-button'),
            label: 'Back to eligibility consent',
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
