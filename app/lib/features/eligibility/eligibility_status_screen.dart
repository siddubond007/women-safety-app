import 'package:flutter/material.dart';

import '../../core/assets/app_assets.dart';
import '../../core/theme/sakhi_design_system.dart';
import '../auth/widgets/auth_widgets.dart';
import 'eligibility_verification_models.dart';
import 'eligibility_widgets.dart';

class EligibilityStatusScreen extends StatelessWidget {
  const EligibilityStatusScreen({
    super.key,
    required this.result,
    this.isDevelopmentBackend = false,
    this.onOpenVerifiedHome,
  });

  final EligibilityStatusResult result;
  final bool isDevelopmentBackend;
  final ValueChanged<EligibilityStatusResult>? onOpenVerifiedHome;

  String get _heading => switch (result.status) {
    EligibilityStatus.notVerified => 'Not verified yet',
    EligibilityStatus.notStarted => 'Verification not started',
    EligibilityStatus.consentRequired => 'Consent is required',
    EligibilityStatus.inProgress => 'Verification in progress',
    EligibilityStatus.pendingManualReview => 'Pending manual review',
    EligibilityStatus.verified =>
      result.isDemo ? 'Demo status: verified' : 'Eligibility verified',
    EligibilityStatus.rejected => 'Eligibility review rejected',
    EligibilityStatus.verificationFailed => 'Unable to verify right now',
    EligibilityStatus.temporarilyRestricted => 'Access temporarily restricted',
    EligibilityStatus.reverificationRequired => 'Further verification required',
    EligibilityStatus.cancelled => 'Verification cancelled',
    EligibilityStatus.providerUnavailable =>
      'Verification is not available yet',
    EligibilityStatus.consentNotGiven => 'Consent was not given',
  };

  String get _explanation => switch (result.status) {
    EligibilityStatus.notVerified => 'No trusted provider result or authorized review has established eligibility yet.',
    EligibilityStatus.notStarted =>
      'No eligibility-verification attempt has started.',
    EligibilityStatus.consentRequired =>
      'The required informed-consent step has not been completed.',
    EligibilityStatus.inProgress => 'A configured service reports that verification is underway. This is not a final decision.',
    EligibilityStatus.pendingManualReview => 'The result is awaiting review. It is not a rejection or a verified decision.',
    EligibilityStatus.verified =>
      result.isDemo
          ? 'This is only a local dev/test status. It does not grant protected access.'
          : 'This status must be confirmed by the trusted backend. Protected APIs must still enforce access server-side.',
    EligibilityStatus.rejected => 'The backend reports that the manual eligibility review was rejected. This is distinct from a technical failure. Contact Sakhi support for any approved alternative or appeal process.',
    EligibilityStatus.verificationFailed => 'A technical or provider problem prevented completion. A failure or timeout does not establish ineligibility.',
    EligibilityStatus.temporarilyRestricted => 'A trusted backend has temporarily restricted access. The reason and any resolution steps must follow the approved policy.',
    EligibilityStatus.reverificationRequired => 'Further verification may be required only under an approved policy and confirmed backend status.',
    EligibilityStatus.cancelled => 'The flow was cancelled before completion. This does not establish ineligibility.',
    EligibilityStatus.providerUnavailable => 'The provider or its approved configuration is unavailable. No eligibility conclusion can be drawn.',
    EligibilityStatus.consentNotGiven =>
      'No verification session should be created without explicit consent.',
  };

  IconData get _icon => switch (result.status) {
    EligibilityStatus.notVerified ||
    EligibilityStatus.notStarted => Icons.shield_outlined,
    EligibilityStatus.consentRequired ||
    EligibilityStatus.consentNotGiven => Icons.fact_check_outlined,
    EligibilityStatus.inProgress => Icons.sync_rounded,
    EligibilityStatus.pendingManualReview => Icons.hourglass_top_rounded,
    EligibilityStatus.verified => Icons.verified_user_outlined,
    EligibilityStatus.rejected => Icons.gpp_bad_outlined,
    EligibilityStatus.verificationFailed => Icons.cloud_off_outlined,
    EligibilityStatus.temporarilyRestricted => Icons.lock_clock_outlined,
    EligibilityStatus.reverificationRequired => Icons.refresh_rounded,
    EligibilityStatus.cancelled => Icons.cancel_outlined,
    EligibilityStatus.providerUnavailable => Icons.settings_outlined,
  };

  Color get _statusColor {
    if (result.isDemo) return SakhiColors.purple;
    return switch (result.status) {
      EligibilityStatus.verified => const Color(0xFF286749),
      EligibilityStatus.pendingManualReview ||
      EligibilityStatus.inProgress ||
      EligibilityStatus.reverificationRequired => const Color(0xFF8B5A17),
      EligibilityStatus.rejected ||
      EligibilityStatus.verificationFailed ||
      EligibilityStatus.temporarilyRestricted ||
      EligibilityStatus.cancelled => const Color(0xFF9B2948),
      EligibilityStatus.notVerified ||
      EligibilityStatus.notStarted ||
      EligibilityStatus.consentRequired ||
      EligibilityStatus.providerUnavailable ||
      EligibilityStatus.consentNotGiven => SakhiColors.purple,
    };
  }

  String get _statusLabel => switch (result.status) {
    EligibilityStatus.notVerified => 'Not Verified',
    EligibilityStatus.notStarted => 'Not started',
    EligibilityStatus.consentRequired => 'Consent required',
    EligibilityStatus.inProgress => 'Verification In Progress',
    EligibilityStatus.pendingManualReview => 'Pending Manual Review',
    EligibilityStatus.verified => 'Verified',
    EligibilityStatus.rejected => 'Rejected',
    EligibilityStatus.verificationFailed => 'Verification Failed',
    EligibilityStatus.temporarilyRestricted => 'Temporarily Restricted',
    EligibilityStatus.reverificationRequired => 'Reverification Required',
    EligibilityStatus.cancelled => 'Cancelled',
    EligibilityStatus.providerUnavailable => 'Provider unavailable',
    EligibilityStatus.consentNotGiven => 'Consent not given',
  };

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor;
    final canOpenVerifiedHome =
        result.status == EligibilityStatus.verified &&
        !result.isDemo &&
        onOpenVerifiedHome != null;

    return SakhiAuthScaffold(
      botanicalAsset: AppAssets.authBotanicalConsent,
      authIsDemo: false,
      authIsDevelopmentBackend: isDevelopmentBackend,
      botanicalHeight: 56,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EligibilityStepIndicator(
            step: 3,
            totalSteps: 3,
            label: 'Status and next steps',
          ),
          const SizedBox(height: SakhiSpacing.md),
          const EligibilityVectorHero(
            icon: Icons.verified_user_outlined,
            caption: 'A status is only as trustworthy as its source.',
          ),
          const SizedBox(height: SakhiSpacing.md),
          const Text(
            'ELIGIBILITY STATUS',
            style: SakhiTypography.categoryLabel,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SakhiSpacing.md),
          Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.11),
                shape: BoxShape.circle,
                border: Border.all(color: statusColor.withValues(alpha: 0.18)),
              ),
              child: Icon(_icon, size: 30, color: statusColor),
            ),
          ),
          const SizedBox(height: SakhiSpacing.md),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SakhiSpacing.md,
                vertical: SakhiSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(SakhiRadii.pill),
                border: Border.all(color: statusColor.withValues(alpha: 0.2)),
              ),
              child: Text(
                _statusLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
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
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: SakhiColors.progressInactive.withValues(alpha: 0.85),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What this means',
                  style: TextStyle(
                    color: SakhiColors.plum,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: SakhiSpacing.xs),
                Text(_explanation, style: SakhiTypography.body),
              ],
            ),
          ),
          const SizedBox(height: SakhiSpacing.sm),
          const EligibilityPrincipleCard(
            icon: Icons.lock_outline_rounded,
            title: 'Protected features stay protected',
            description: 'Only a trusted backend-confirmed Verified status may allow access. A demo or a hidden UI control never grants access.',
          ),
          const SizedBox(height: SakhiSpacing.lg),
          if (canOpenVerifiedHome) ...[
            SakhiAuthSubmitButton(
              key: const Key('eligibility-open-verified-home-button'),
              label: 'Continue to Sakhi Home',
              icon: Icons.home_rounded,
              onPressed: () => onOpenVerifiedHome?.call(result),
            ),
            const SizedBox(height: SakhiSpacing.xs),
          ],
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
