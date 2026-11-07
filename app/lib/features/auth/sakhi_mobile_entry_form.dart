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
    '+91': '🇮🇳 +91',
    '+1': '🇺🇸 +1',
    '+44': '🇬🇧 +44',
    '+61': '🇦🇺 +61',
  };

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _showGoogleSignInNotice() {
    setState(
      () => _statusMessage =
          'Google sign-in is not configured for this Sakhi staging build. No Google authentication was attempted; use Send OTP to continue.',
    );
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
        () => _statusMessage =
            'We could not continue. Please check your connection and try again.',
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
              style: const TextStyle(
                color: Color(0xFF4A1B58),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAF6FC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE3D2EC)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const Key('auth-country-code-dropdown'),
                      value: _countryCode,
                      isDense: true,
                      borderRadius: BorderRadius.circular(14),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: Color(0xFF6B4F78),
                      ),
                      style: const TextStyle(
                        color: Color(0xFF34183D),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                      items: _countryCodes.entries
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
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
                  Container(
                    height: 24,
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: const Color(0xFFDCC7E8),
                  ),
                  Expanded(
                    child: TextFormField(
                      key: const Key('auth-mobile-number-field'),
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      maxLength: 15,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) =>
                          validatePhoneNumber(value, _countryCode),
                      onFieldSubmitted: (_) => _continue(),
                      style: const TextStyle(
                        color: Color(0xFF34183D),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Enter mobile number',
                        hintStyle: TextStyle(
                          color: Color(0xFF9A82A6),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        counterText: '',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.phone_outlined,
                    color: Color(0xFF8C6B98),
                    size: 20,
                  ),
                ],
              ),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              SakhiAuthStatusMessage(message: _statusMessage!),
            ],
            const SizedBox(height: 14),
            SakhiAuthSubmitButton(
              key: const Key('auth-send-otp-button'),
              label: 'Send OTP',
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _continue,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Divider(color: Color(0xFFE6D6EF), height: 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'or',
                    style: SakhiTypography.body.copyWith(
                      color: const Color(0xFF8C6B98),
                      fontSize: 13,
                    ),
                  ),
                ),
                const Expanded(
                  child: Divider(color: Color(0xFFE6D6EF), height: 1),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                key: const Key('auth-google-sign-in-button'),
                onPressed: _isSubmitting ? null : _showGoogleSignInNotice,
                icon: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFF6F1FA),
                  ),
                  child: const Text(
                    'G',
                    style: TextStyle(
                      color: Color(0xFF4285F4),
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
                label: const Text('Continue with Google'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF34183D),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFE3D2EC)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                key: const Key('auth-switch-method-button'),
                onPressed: _isSubmitting ? null : widget.onSwitchMethod,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  registering
                      ? 'Already have an account? Sign in'
                      : 'New to Sakhi? Create an Account',
                  style: const TextStyle(
                    color: Color(0xFF5D196A),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const SakhiPolicyLinks(compact: true),
          ],
        ),
      ),
    );
  }
}
