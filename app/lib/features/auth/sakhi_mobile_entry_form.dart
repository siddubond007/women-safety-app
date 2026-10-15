import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/sakhi_design_system.dart';
import 'auth_service.dart';
import 'sakhi_otp_screen.dart';
import 'widgets/auth_widgets.dart';

class SakhiMobileEntryForm extends StatefulWidget {
  const SakhiMobileEntryForm({
    super.key,
    required this.authService,
    required this.purpose,
    required this.onSwitchMethod,
  });

  final AuthService authService;
  final AuthPurpose purpose;
  final VoidCallback onSwitchMethod;

  @override
  State<SakhiMobileEntryForm> createState() => _SakhiMobileEntryFormState();
}

class _SakhiMobileEntryFormState extends State<SakhiMobileEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String _countryCode = '+91';
  bool _isSubmitting = false;
  String? _statusMessage;

  static const _countryCodes = <String, String>{
    '+91': 'India',
    '+1': 'US / Canada',
    '+44': 'United Kingdom',
    '+61': 'Australia',
  };

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false) || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    try {
      final session = await widget.authService.requestOtp(
        countryCode: _countryCode,
        phoneNumber: _phoneController.text.replaceAll(RegExp(r'\D'), ''),
        purpose: widget.purpose,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              SakhiOtpScreen(authService: widget.authService, session: session),
        ),
      );
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() => _statusMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _statusMessage = 'We could not continue. Please check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final registering = widget.purpose == AuthPurpose.registration;
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              registering ? 'Create your Sakhi account' : 'Welcome back',
              textAlign: TextAlign.center,
              style: SakhiTypography.onboardingTitle.copyWith(fontSize: 25),
            ),
            const SizedBox(height: SakhiSpacing.xs),
            Text(
              registering
                  ? "Start with your mobile number. We'll verify it with a one-time code."
                  : 'Sign in to continue your journey with Sakhi.',
              textAlign: TextAlign.center,
              style: SakhiTypography.body,
            ),
            const SizedBox(height: SakhiSpacing.lg),
            const Text('MOBILE NUMBER', style: SakhiTypography.categoryLabel),
            const SizedBox(height: SakhiSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 58,
                  padding: const EdgeInsets.symmetric(
                    horizontal: SakhiSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: SakhiColors.blush.withValues(alpha: 0.52),
                    borderRadius: BorderRadius.circular(SakhiRadii.control),
                    border: Border.all(color: SakhiColors.progressInactive),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const Key('auth-country-code-dropdown'),
                      value: _countryCode,
                      borderRadius: BorderRadius.circular(14),
                      iconEnabledColor: SakhiColors.purple,
                      style: const TextStyle(
                        color: SakhiColors.plum,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      items: _countryCodes.entries
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.key),
                            ),
                          )
                          .toList(),
                      onChanged: _isSubmitting
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  _countryCode = value;
                                  _statusMessage = null;
                                });
                              }
                            },
                    ),
                  ),
                ),
                const SizedBox(width: SakhiSpacing.xs),
                Expanded(
                  child: SakhiAuthTextField(
                    fieldKey: const Key('auth-mobile-number-field'),
                    controller: _phoneController,
                    label: 'Mobile number',
                    hint: _countryCode == '+91'
                        ? '10-digit number'
                        : 'Phone number',
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    maxLength: 15,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) =>
                        validatePhoneNumber(value, _countryCode),
                    onFieldSubmitted: (_) => _continue(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SakhiSpacing.xs),
            const Text(
              'Your number is used for account verification in line with our Privacy Policy.',
              style: TextStyle(
                color: SakhiColors.mutedPlum,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: SakhiSpacing.md),
              SakhiAuthStatusMessage(message: _statusMessage!),
            ],
            const SizedBox(height: SakhiSpacing.lg),
            SakhiAuthSubmitButton(
              key: const Key('auth-send-otp-button'),
              label: registering ? 'Continue' : 'Continue with mobile number',
              icon: Icons.sms_outlined,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _continue,
            ),
            const SizedBox(height: SakhiSpacing.sm),
            Center(
              child: TextButton(
                key: const Key('auth-switch-method-button'),
                onPressed: _isSubmitting ? null : widget.onSwitchMethod,
                child: Text(
                  registering
                      ? 'Already have an account? Sign in'
                      : 'New to Sakhi? Create account',
                ),
              ),
            ),
            const SizedBox(height: SakhiSpacing.xxs),
            const SakhiPolicyLinks(compact: true),
          ],
        ),
      ),
    );
  }
}
