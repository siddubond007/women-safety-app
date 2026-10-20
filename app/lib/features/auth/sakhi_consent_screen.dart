import 'package:flutter/material.dart';

import '../../core/assets/app_assets.dart';
import '../../core/theme/sakhi_design_system.dart';
import '../eligibility/eligibility_intro_screen.dart';
import '../eligibility/eligibility_verification_service.dart';
import 'auth_policy.dart';
import 'auth_service.dart';
import 'sakhi_auth_status_screen.dart';
import 'widgets/auth_widgets.dart';

class SakhiConsentScreen extends StatefulWidget {
  const SakhiConsentScreen({
    super.key,
    required this.authService,
    required this.profile,
    required this.minimumAgeYears,
  });

  final AuthService authService;
  final MemberProfileDraft profile;
  final int? minimumAgeYears;

  @override
  State<SakhiConsentScreen> createState() => _SakhiConsentScreenState();
}

class _SakhiConsentScreenState extends State<SakhiConsentScreen> {
  bool _termsAccepted = false;
  bool _optionalUpdatesAccepted = false;
  bool _isCreatingAccount = false;
  String? _statusMessage;
  bool _isSuccess = false;
  AuthAccountState? _createdAccountState;

  bool get _agePolicyMissing => widget.minimumAgeYears == null;

  bool get _ageEligible {
    final minimumAge = widget.minimumAgeYears;
    if (minimumAge == null) return false;
    return isAtLeastMinimumAge(
      widget.profile.dateOfBirth,
      DateTime.now(),
      minimumAge,
    );
  }

  bool get _canCreateAccount =>
      _termsAccepted &&
      !_agePolicyMissing &&
      _ageEligible &&
      !_isCreatingAccount &&
      !_isSuccess;

  Future<void> _createAccount() async {
    if (!_canCreateAccount) return;
    setState(() {
      _isCreatingAccount = true;
      _statusMessage = null;
    });

    try {
      final result = await widget.authService.createAccount(
        profile: widget.profile,
        consent: MemberConsentRecord(
          termsVersion: SakhiAuthPolicy.termsVersion,
          privacyVersion: SakhiAuthPolicy.privacyVersion,
          acceptedAt: DateTime.now(),
          optionalUpdatesAccepted: _optionalUpdatesAccepted,
        ),
      );
      if (!mounted) return;
      if (widget.authService.isDevelopmentBackend) {
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => SakhiAuthStatusScreen(
              authService: widget.authService,
              accountState: result.accountState,
              statusMessage: result.message != null &&
                      result.message!
                          .startsWith('Profile saved. The optional photo')
                  ? result.message
                  : null,
            ),
          ),
          (_) => false,
        );
      } else {
        setState(() {
          _isSuccess = true;
          _createdAccountState = result.accountState;
          _statusMessage = result.message ?? 'Account request accepted.';
        });
      }
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSuccess = false;
        _statusMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSuccess = false;
        _statusMessage =
            'The account request could not be completed. No success was confirmed; please try again.';
      });
    } finally {
      if (mounted) setState(() => _isCreatingAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dob = widget.profile.dateOfBirth;
    final day = dob.day.toString().padLeft(2, '0');
    final month = dob.month.toString().padLeft(2, '0');
    final dobString = '$day/$month/${dob.year}';

    return SakhiAuthScaffold(
      botanicalAsset: AppAssets.authBotanicalConsent,
      authIsDemo: widget.authService.isDemo,
      authIsDevelopmentBackend: widget.authService.isDevelopmentBackend,
      botanicalHeight: 66,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Privacy and consent',
            textAlign: TextAlign.center,
            style: SakhiTypography.onboardingTitle.copyWith(fontSize: 25),
          ),
          const SizedBox(height: SakhiSpacing.xs),
          const Text(
            'Review the policies before creating your Sakhi account.',
            textAlign: TextAlign.center,
            style: SakhiTypography.body,
          ),
          const SizedBox(height: SakhiSpacing.md),
          Container(
            padding: const EdgeInsets.all(SakhiSpacing.md),
            decoration: BoxDecoration(
              color: SakhiColors.lavender.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.profile.displayName,
                  style: const TextStyle(
                    color: SakhiColors.plum,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: SakhiSpacing.xxs),
                Text(
                  'Mobile: ${maskPhone(widget.profile.countryCode, widget.profile.phoneNumber)}',
                  style: SakhiTypography.body,
                ),
                Text('Date of birth: $dobString', style: SakhiTypography.body),
                if (widget.profile.email != null)
                  Text(
                    'Email: ${widget.profile.email!}',
                    style: SakhiTypography.body,
                  ),
              ],
            ),
          ),
          const SizedBox(height: SakhiSpacing.md),
          if (_agePolicyMissing)
            const SakhiAuthStatusMessage(
              message:
                  'Production registration is blocked because the approved minimum age is not configured. The temporary age-13 rule is available only in debug preview builds.',
            )
          else if (SakhiAuthPolicy.usesProvisionalPreviewPolicy)
            const SakhiAuthStatusMessage(
              message:
                  'DEVELOPMENT PREVIEW — minimum age 13 is a temporary testing rule, not an approved production policy. Legal documents below are drafts.',
            ),
          if (_agePolicyMissing || SakhiAuthPolicy.usesProvisionalPreviewPolicy)
            const SizedBox(height: SakhiSpacing.sm),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              key: const Key('auth-required-consent-checkbox'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _termsAccepted,
              activeColor: SakhiColors.purple,
              onChanged: _isCreatingAccount || _isSuccess
                  ? null
                  : (value) => setState(() => _termsAccepted = value ?? false),
              title: const Text(
                'I acknowledge the draft Terms and Conditions and Privacy Policy for this preview.',
                style: TextStyle(
                  color: SakhiColors.plum,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SakhiPolicyLinks(compact: true),
          const Divider(color: SakhiColors.progressInactive),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              key: const Key('auth-optional-updates-checkbox'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _optionalUpdatesAccepted,
              activeColor: SakhiColors.purple,
              onChanged: _isCreatingAccount || _isSuccess
                  ? null
                  : (value) => setState(
                      () => _optionalUpdatesAccepted = value ?? false,
                    ),
              title: const Text(
                "I'd like to receive occasional Sakhi updates (optional).",
                style: TextStyle(
                  color: SakhiColors.mutedPlum,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ),
          ),
          const SizedBox(height: SakhiSpacing.sm),
          if (_agePolicyMissing)
            const SakhiAuthStatusMessage(
              message:
                  'Account creation is disabled: the business/legal team has not supplied the minimum registration age yet. No age threshold has been assumed.',
            )
          else if (!_ageEligible)
            const SakhiAuthStatusMessage(
              message:
                  'The selected date of birth does not meet the configured minimum registration age.',
            ),
          if (_statusMessage != null) ...[
            const SizedBox(height: SakhiSpacing.sm),
            SakhiAuthStatusMessage(
              message: _statusMessage!,
              isSuccess: _isSuccess,
            ),
          ],
          const SizedBox(height: SakhiSpacing.md),
          SakhiAuthSubmitButton(
            key: const Key('auth-create-account-button'),
            label: _isSuccess ? 'Account request completed' : 'Create account',
            icon: _isSuccess
                ? Icons.check_circle_outline_rounded
                : Icons.favorite_border_rounded,
            isLoading: _isCreatingAccount,
            onPressed: _canCreateAccount ? _createAccount : null,
          ),
          const SizedBox(height: SakhiSpacing.xs),
          Center(
            child: TextButton(
              key: const Key('auth-consent-back-button'),
              onPressed: _isCreatingAccount
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Back to profile'),
            ),
          ),
          if (widget.authService.isDemo) ...[
            const SizedBox(height: SakhiSpacing.xxs),
            Center(
              child: TextButton.icon(
                key: const Key('eligibility-preview-entry-button'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EligibilityIntroScreen(
                      service: DemoEligibilityVerificationService(),
                    ),
                  ),
                ),
                icon: const Icon(Icons.verified_user_outlined, size: 18),
                label: const Text('Preview eligibility verification'),
              ),
            ),
          ],
          if (_isSuccess) ...[
            const SizedBox(height: SakhiSpacing.xs),
            Center(
              child: TextButton(
                key: const Key('auth-consent-next-button'),
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => SakhiAuthStatusScreen(
                      authService: widget.authService,
                      accountState:
                          _createdAccountState ??
                          AuthAccountState.pendingVerification,
                    ),
                  ),
                ),
                child: const Text('Continue to account status'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
