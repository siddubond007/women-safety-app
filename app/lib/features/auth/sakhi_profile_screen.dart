import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/assets/app_assets.dart';
import '../../core/theme/sakhi_design_system.dart';
import 'auth_policy.dart';
import 'auth_service.dart';
import 'sakhi_consent_screen.dart';
import 'widgets/auth_widgets.dart';

class SakhiProfileScreen extends StatefulWidget {
  const SakhiProfileScreen({
    super.key,
    required this.authService,
    required this.countryCode,
    required this.phoneNumber,
  });

  final AuthService authService;
  final String countryCode;
  final String phoneNumber;

  @override
  State<SakhiProfileScreen> createState() => _SakhiProfileScreenState();
}

class _SakhiProfileScreenState extends State<SakhiProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  DateTime? _dateOfBirth;
  bool _photoSkipped = false;
  bool _attemptedContinue = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _chooseDateOfBirth() async {
    FocusScope.of(context).unfocus();
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(today.year - 25, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Select your date of birth',
      cancelText: 'Cancel',
      confirmText: 'Confirm date',
    );
    if (picked != null && mounted) setState(() => _dateOfBirth = picked);
  }

  Future<void> _showPhotoUnavailable() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile photo'),
        content: const Text(
          'Photo selection and upload are not connected in this preview. A profile photo is optional, so you can safely continue without one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  String? _validateDateOfBirth() {
    final value = _dateOfBirth;
    if (value == null) return 'Select your date of birth.';
    final today = DateTime.now();
    if (value.isAfter(DateTime(today.year, today.month, today.day))) {
      return 'Date of birth cannot be in the future.';
    }
    final minimumAge = SakhiAuthPolicy.minimumRegistrationAgeYears;
    if (minimumAge != null && !isAtLeastMinimumAge(value, today, minimumAge)) {
      return 'You do not meet the configured minimum age for registration.';
    }
    return null;
  }

  void _continue() {
    FocusScope.of(context).unfocus();
    final formValid = _formKey.currentState?.validate() ?? false;
    final dobError = _validateDateOfBirth();
    setState(() => _attemptedContinue = true);
    if (!formValid || dobError != null || _dateOfBirth == null) return;

    final profile = MemberProfileDraft(
      countryCode: widget.countryCode,
      phoneNumber: widget.phoneNumber,
      displayName: _nameController.text.trim(),
      dateOfBirth: _dateOfBirth!,
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      photoPath: null,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SakhiConsentScreen(
          authService: widget.authService,
          profile: profile,
          minimumAgeYears: SakhiAuthPolicy.minimumRegistrationAgeYears,
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final dobError = (_attemptedContinue || _dateOfBirth != null)
        ? _validateDateOfBirth()
        : null;
    return SakhiAuthScaffold(
      botanicalAsset: AppAssets.authBotanicalProfile,
      authIsDemo: widget.authService.isDemo,
      botanicalHeight: 76,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tell us about yourself',
              textAlign: TextAlign.center,
              style: SakhiTypography.onboardingTitle.copyWith(fontSize: 25),
            ),
            const SizedBox(height: SakhiSpacing.xs),
            const Text(
              'Add the essential details for your Sakhi profile.',
              textAlign: TextAlign.center,
              style: SakhiTypography.body,
            ),
            const SizedBox(height: SakhiSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SakhiSpacing.sm,
                vertical: SakhiSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: SakhiColors.lavender.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    color: SakhiColors.purple,
                    size: 18,
                  ),
                  const SizedBox(width: SakhiSpacing.xs),
                  Expanded(
                    child: Text(
                      'Mobile number: ${maskPhone(widget.countryCode, widget.phoneNumber)}',
                      style: const TextStyle(
                        color: SakhiColors.plum,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SakhiSpacing.md),
            SakhiAuthTextField(
              fieldKey: const Key('auth-profile-name-field'),
              controller: _nameController,
              label: 'Full name / preferred display name',
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: validateRequiredName,
            ),
            const SizedBox(height: SakhiSpacing.md),
            Semantics(
              button: true,
              label: 'Choose date of birth',
              child: InkWell(
                key: const Key('auth-profile-dob-picker'),
                onTap: _chooseDateOfBirth,
                borderRadius: BorderRadius.circular(SakhiRadii.control),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date of birth',
                    hintText: 'Required',
                    errorText: dobError,
                    filled: true,
                    fillColor: SakhiColors.blush.withValues(alpha: 0.52),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: SakhiSpacing.md,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SakhiRadii.control),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SakhiRadii.control),
                      borderSide: const BorderSide(
                        color: SakhiColors.progressInactive,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dateOfBirth == null
                              ? 'Choose your date of birth'
                              : _formatDate(_dateOfBirth!),
                          style: TextStyle(
                            color: _dateOfBirth == null
                                ? SakhiColors.mutedPlum
                                : SakhiColors.plum,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.calendar_month_outlined,
                        color: SakhiColors.purple,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (SakhiAuthPolicy.minimumRegistrationAgeYears == null) ...[
              const SizedBox(height: SakhiSpacing.xs),
              const Text(
                'Age eligibility is pending the approved business/legal minimum-age policy. Production account creation remains unavailable until it is configured.',
                key: Key('auth-age-policy-unconfigured'),
                style: TextStyle(
                  color: SakhiColors.mutedPlum,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ] else if (SakhiAuthPolicy.usesProvisionalPreviewPolicy) ...[
              const SizedBox(height: SakhiSpacing.xs),
              const Text(
                'Temporary preview rule: minimum age 13. This is for development testing only and is not approved for production.',
                key: Key('auth-age-policy-provisional'),
                style: TextStyle(
                  color: SakhiColors.mutedPlum,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: SakhiSpacing.md),
            SakhiAuthTextField(
              fieldKey: const Key('auth-profile-email-field'),
              controller: _emailController,
              label: 'Email address (optional)',
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              validator: validateAuthEmail,
              inputFormatters: [LengthLimitingTextInputFormatter(254)],
            ),
            const SizedBox(height: SakhiSpacing.lg),
            const Text(
              'PROFILE PHOTO · OPTIONAL',
              style: SakhiTypography.categoryLabel,
            ),
            const SizedBox(height: SakhiSpacing.xs),
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: SakhiColors.pink,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: SakhiColors.purple,
                    size: 30,
                  ),
                ),
                const SizedBox(width: SakhiSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('auth-profile-add-photo-button'),
                    onPressed: _showPhotoUnavailable,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: const Text('Add photo'),
                  ),
                ),
                TextButton(
                  key: const Key('auth-profile-skip-photo-button'),
                  onPressed: () => setState(() => _photoSkipped = true),
                  child: Text(_photoSkipped ? 'Skipped' : 'Skip'),
                ),
              ],
            ),
            const SizedBox(height: SakhiSpacing.xs),
            const Text(
              'Email and profile photo are optional. You can continue without either.',
              style: TextStyle(
                color: SakhiColors.mutedPlum,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: SakhiSpacing.lg),
            SakhiAuthSubmitButton(
              key: const Key('auth-profile-continue-button'),
              label: 'Continue',
              icon: Icons.arrow_forward_rounded,
              onPressed: _continue,
            ),
            const SizedBox(height: SakhiSpacing.xs),
            Center(
              child: TextButton(
                key: const Key('auth-profile-back-button'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to mobile number'),
              ),
            ),
            const SakhiPolicyLinks(compact: true),
          ],
        ),
      ),
    );
  }
}
