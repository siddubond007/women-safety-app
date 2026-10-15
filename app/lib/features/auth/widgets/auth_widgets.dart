import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/sakhi_design_system.dart';
import '../../../shared/widgets/sakhi_brand_logo.dart';

class SakhiAuthScaffold extends StatelessWidget {
  const SakhiAuthScaffold({
    super.key,
    required this.child,
    required this.botanicalAsset,
    required this.authIsDemo,
    this.botanicalHeight = 82,
  });

  final Widget child;
  final String botanicalAsset;
  final bool authIsDemo;
  final double botanicalHeight;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SakhiColors.blush,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 700;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                SakhiSpacing.md,
                compact ? SakhiSpacing.xs : SakhiSpacing.md,
                SakhiSpacing.md,
                SakhiSpacing.xl,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: SakhiBrandLogo(
                          width: compact ? 104 : 118,
                          height: compact ? 78 : 90,
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(height: SakhiSpacing.xxs),
                        SakhiBotanicalAccent(
                          asset: botanicalAsset,
                          height: botanicalHeight,
                          alignment: Alignment.centerRight,
                        ),
                      ] else
                        const SizedBox(height: SakhiSpacing.xs),
                      if (authIsDemo) ...[
                        const SakhiDemoBanner(),
                        const SizedBox(height: SakhiSpacing.sm),
                      ],
                      Container(
                        padding: EdgeInsets.all(
                          compact ? SakhiSpacing.md : SakhiSpacing.lg,
                        ),
                        decoration: BoxDecoration(
                          color: SakhiColors.ivory.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: SakhiColors.plum.withValues(alpha: 0.055),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: child,
                      ),
                      const SizedBox(height: SakhiSpacing.md),
                      const Text(
                        'Your safety, wellbeing and community matter.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: SakhiColors.mutedPlum,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class SakhiBotanicalAccent extends StatelessWidget {
  const SakhiBotanicalAccent({
    super.key,
    required this.asset,
    this.height = 82,
    this.alignment = Alignment.centerRight,
  });

  final String asset;
  final double height;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Opacity(
            opacity: 0.62,
            child: Image.asset(
              asset,
              height: height,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class SakhiDemoBanner extends StatelessWidget {
  const SakhiDemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('auth-demo-banner'),
        padding: const EdgeInsets.symmetric(
          horizontal: SakhiSpacing.sm,
          vertical: SakhiSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: SakhiColors.lavender,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: SakhiColors.progressInactive),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.science_outlined, color: SakhiColors.purple, size: 18),
            SizedBox(width: SakhiSpacing.xs),
            Expanded(
              child: Text(
                'DEMO PREVIEW — no SMS is sent, no number is truly verified, and no account or session is created.',
                style: TextStyle(
                  color: SakhiColors.plum,
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SakhiAuthTextField extends StatelessWidget {
  const SakhiAuthTextField({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.validator,
    this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.autofillHints,
    this.maxLength,
    this.inputFormatters,
    this.onFieldSubmitted,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(SakhiRadii.control),
      borderSide: BorderSide(
        color: SakhiColors.progressInactive.withValues(alpha: 0.95),
      ),
    );

    return TextFormField(
      key: fieldKey,
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: SakhiColors.blush.withValues(alpha: 0.52),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SakhiSpacing.md,
          vertical: 16,
        ),
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: const BorderSide(color: SakhiColors.purple, width: 1.5),
        ),
        errorBorder: outline.copyWith(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        focusedErrorBorder: outline.copyWith(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class SakhiAuthSubmitButton extends StatelessWidget {
  const SakhiAuthSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon = Icons.arrow_forward_rounded,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: SakhiColors.purple,
          foregroundColor: Colors.white,
          disabledBackgroundColor: SakhiColors.purple.withValues(alpha: 0.48),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.9),
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(
            horizontal: SakhiSpacing.md,
            vertical: SakhiSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SakhiRadii.control),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: isLoading
            ? const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      softWrap: true,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: SakhiSpacing.xs),
                  Icon(icon, size: 19),
                ],
              ),
      ),
    );
  }
}

class SakhiAuthStatusMessage extends StatelessWidget {
  const SakhiAuthStatusMessage({
    super.key,
    required this.message,
    this.isSuccess = false,
  });

  final String message;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final foreground = isSuccess
        ? const Color(0xFF286749)
        : const Color(0xFF9B2948);
    final background = isSuccess
        ? const Color(0xFFEAF6EE)
        : const Color(0xFFFFEDF1);
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('auth-status-message'),
        width: double.infinity,
        padding: const EdgeInsets.all(SakhiSpacing.sm),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(SakhiRadii.control),
          border: Border.all(color: foreground.withValues(alpha: 0.16)),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: foreground,
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class SakhiPolicyLinks extends StatelessWidget {
  const SakhiPolicyLinks({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: compact ? 2 : SakhiSpacing.xs,
      children: [
        TextButton(
          key: const Key('auth-terms-link'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const SakhiPolicyDocumentScreen(
                title: 'Terms and Conditions',
              ),
            ),
          ),
          child: const Text('Terms and Conditions'),
        ),
        Text(
          '•',
          style: TextStyle(
            color: SakhiColors.mutedPlum.withValues(alpha: 0.85),
          ),
        ),
        TextButton(
          key: const Key('auth-privacy-link'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const SakhiPolicyDocumentScreen(title: 'Privacy Policy'),
            ),
          ),
          child: const Text('Privacy Policy'),
        ),
      ],
    );
  }
}

class SakhiPolicyDocumentScreen extends StatelessWidget {
  const SakhiPolicyDocumentScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final isTerms = title == 'Terms and Conditions';
    final sections = isTerms
        ? const <List<String>>[
            [
              '1. Draft status and purpose',
              'This is temporary placeholder copy for Sakhi development and usability testing. It has not been reviewed or approved by a legal adviser, is not the final agreement, and must not be published as production legal text.',
            ],
            [
              '2. Eligibility and age',
              'The current debug preview uses a provisional minimum age of 13 solely to test registration and date-of-birth validation. This is not an approved production eligibility policy. Production registration must remain blocked until the business/legal team approves the applicable age and eligibility rules. Additional safeguards for younger users must be reviewed before launch.',
            ],
            [
              '3. Demo status and service availability',
              'In demo mode, entering six digits only simulates the OTP screen. No SMS is sent, no phone number is verified, and no real account or authenticated session is created. Safety, identity-verification, messaging, notification and emergency integrations must not be assumed active unless the app explicitly confirms a configured service.',
            ],
            [
              '4. Respectful and safe use',
              'A future production service is intended for respectful community participation. Users must not harass, threaten, impersonate, stalk, expose private information about, or unlawfully harm other people. Final community rules, reporting procedures and enforcement processes require review before launch.',
            ],
            [
              '5. Safety limitations',
              'The app preview is not an emergency-response service and does not guarantee assistance or police notification. In an immediate emergency in India, contact 112 or the relevant local emergency service directly. Never rely on an unconfigured in-app feature as the sole source of help.',
            ],
            [
              '6. Accounts, content and future terms',
              'Account creation, user content, restrictions, account deletion, intellectual-property terms, liability, dispute handling and contact details need final product and legal review. Do not enter real identity documents or sensitive personal data into this demo.',
            ],
          ]
        : const <List<String>>[
            [
              '1. Draft status',
              'This is temporary privacy-policy placeholder copy for development testing only. It has not been legally reviewed or approved and does not replace the final Sakhi Privacy Policy.',
            ],
            [
              '2. Information in the current preview',
              'The demo authentication flow does not send SMS, verify a number, create an account, or establish a session. The screens temporarily display the phone number, display name and date of birth entered for the preview. Do not enter real identity documents, precise location, health details or other sensitive information for testing.',
            ],
            [
              '3. Information planned for a connected service',
              'A production service may need a mobile number, display name, date of birth, optional email address, optional profile photo, verification status and records of required Terms/Privacy acceptance. Additional features may process posts, messages, safety reports, location or wellness information only under a separately reviewed purpose and privacy design.',
            ],
            [
              '4. Purpose and sharing',
              'In a future connected service, data should be used only for disclosed account, security, safety and feature purposes. Third-party SMS, identity, storage, maps and notification providers have not been configured in this preview. Any future disclosure, role access and provider arrangement must be documented and approved before production.',
            ],
            [
              '5. Location and sensitive information',
              'Precise location must not be public by default. Sensitive identity, complaint and wellness data require strict access controls, appropriate protection, limited retention and clear consent where required. These controls and any identity-verification provider must be implemented and reviewed before those features launch.',
            ],
            [
              '6. Age and eligibility',
              'The minimum age of 13 applies only as a temporary debug-preview rule requested for testing. It is not an approved production policy. Production age, women-centric eligibility verification and any additional safeguards must be decided through business/legal review. The app must not infer gender from appearance or treat Aadhaar OTP alone as proof of eligibility.',
            ],
            [
              '7. Choices, retention and contact',
              'Terms/Privacy acceptance is required in the registration preview. Optional product updates are separate and start unchecked. Final consent withdrawal, data access, correction, deletion, retention periods, grievance/support contact details and other applicable rights must be defined in the approved policy before launch; no production contact or retention promise is made by this draft.',
            ],
          ];

    return Scaffold(
      backgroundColor: SakhiColors.blush,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SakhiSpacing.lg),
          child: Container(
            padding: const EdgeInsets.all(SakhiSpacing.lg),
            decoration: BoxDecoration(
              color: SakhiColors.ivory,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(SakhiSpacing.md),
                  decoration: BoxDecoration(
                    color: SakhiColors.pink.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: SakhiColors.progressInactive),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DRAFT — NOT APPROVED FOR PRODUCTION',
                        style: TextStyle(
                          color: SakhiColors.plum,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: SakhiSpacing.xxs),
                      Text(
                        'Temporary preview copy · Version: draft',
                        style: SakhiTypography.body,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SakhiSpacing.md),
                for (final section in sections) ...[
                  Text(
                    section[0],
                    style: const TextStyle(
                      color: SakhiColors.plum,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: SakhiSpacing.xs),
                  Text(section[1], style: SakhiTypography.body),
                  const SizedBox(height: SakhiSpacing.md),
                ],
                const Divider(color: SakhiColors.progressInactive),
                const SizedBox(height: SakhiSpacing.xs),
                const Text(
                  'Replace this draft with reviewed and formally approved copy before public release. This screen is not legal advice and does not certify compliance.',
                  style: TextStyle(
                    color: SakhiColors.mutedPlum,
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? validateAuthEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return null;
  final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  if (!emailPattern.hasMatch(email)) return 'Enter a valid email address.';
  return null;
}

String? validateRequiredName(String? value) {
  if (value == null || value.trim().isEmpty) return 'Enter your name.';
  if (value.trim().length < 2) return 'Enter at least 2 characters.';
  return null;
}

String? validatePhoneNumber(String? value, String countryCode) {
  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return 'Enter your mobile number.';
  if (countryCode == '+91' && digits.length != 10) {
    return 'Enter a 10-digit mobile number.';
  }
  if (digits.length < 7 || digits.length > 15) {
    return 'Enter a valid mobile number.';
  }
  return null;
}

String maskPhone(String countryCode, String phoneNumber) {
  final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
  final visible = digits.length > 4
      ? digits.substring(digits.length - 4)
      : digits;
  final hiddenLength = (digits.length - visible.length).clamp(0, 12);
  final concealed = List<String>.filled(hiddenLength, '•').join();
  return '$countryCode $concealed$visible';
}
