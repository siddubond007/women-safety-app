import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/assets/app_assets.dart';
import '../../core/navigation/app_navigation_shell.dart';
import '../../core/theme/sakhi_design_system.dart';
import 'auth_service.dart';
import 'sakhi_auth_status_screen.dart';
import 'sakhi_profile_screen.dart';
import 'widgets/auth_widgets.dart';

class SakhiOtpScreen extends StatefulWidget {
  const SakhiOtpScreen({
    super.key,
    required this.authService,
    required this.session,
  });

  final AuthService authService;
  final AuthOtpSession session;

  @override
  State<SakhiOtpScreen> createState() => _SakhiOtpScreenState();
}

class _SakhiOtpScreenState extends State<SakhiOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  late AuthOtpSession _session;
  Timer? _timer;
  int _secondsUntilResend = 0;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _startResendCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _timer?.cancel();
    void update() {
      if (!mounted) return;
      setState(() {
        _secondsUntilResend = _session.resendAvailableAt
            .difference(DateTime.now())
            .inSeconds;
        if (_secondsUntilResend < 0) _secondsUntilResend = 0;
      });
    }

    update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _session.resendAvailableAt
          .difference(DateTime.now())
          .inSeconds;
      setState(() => _secondsUntilResend = remaining > 0 ? remaining : 0);
      if (remaining <= 0) _timer?.cancel();
    });
  }

  String get _resendCountdownLabel {
    final minutes = _secondsUntilResend ~/ 60;
    final seconds = _secondsUntilResend % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false) || _isVerifying) return;
    setState(() {
      _isVerifying = true;
      _statusMessage = null;
    });

    try {
      final result = await widget.authService.verifyOtp(
        session: _session,
        code: _codeController.text.trim(),
      );
      if (!mounted) return;
      switch (result.status) {
        case OtpVerificationStatus.invalid:
          setState(() {
            _statusMessage =
                result.message ?? 'That code is not correct. Try again.';
          });
          break;
        case OtpVerificationStatus.expired:
          setState(() {
            _statusMessage =
                result.message ?? 'This code has expired. Request a new one.';
          });
          break;
        case OtpVerificationStatus.tooManyAttempts:
          setState(() {
            _statusMessage =
                result.message ??
                'Too many attempts. Please wait before trying again.';
          });
          break;
        case OtpVerificationStatus.verified:
          final accountState = result.accountState;
          if (accountState == AuthAccountState.newAccount) {
            await Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => SakhiProfileScreen(
                  authService: widget.authService,
                  countryCode: _session.countryCode,
                  phoneNumber: _session.phoneNumber,
                ),
              ),
            );
          } else if (accountState == AuthAccountState.existingAccount) {
            await Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(
                builder: (_) => const AppNavigationShell(),
              ),
              (_) => false,
            );
          } else {
            await Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(
                builder: (_) => SakhiAuthStatusScreen(
                  authService: widget.authService,
                  accountState:
                      accountState ?? AuthAccountState.pendingVerification,
                ),
              ),
              (_) => false,
            );
          }
      }
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() => _statusMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Verification could not be completed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsUntilResend > 0 || _isResending) return;
    setState(() {
      _isResending = true;
      _statusMessage = null;
    });
    try {
      final nextSession = await widget.authService.resendOtp(_session);
      if (!mounted) return;
      setState(() {
        _session = nextSession;
        _codeController.clear();
        _statusMessage = _session.isDemo
            ? 'Demo countdown restarted. No real SMS was sent.'
            : 'A new code was requested.';
      });
      _startResendCountdown();
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() => _statusMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'A new code could not be requested. Try again later.';
      });
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SakhiAuthScaffold(
      botanicalAsset: AppAssets.authBotanicalOtp,
      authIsDemo: widget.authService.isDemo,
      authIsDevelopmentBackend: widget.authService.isDevelopmentBackend,
      botanicalHeight: 58,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Verify your number',
              textAlign: TextAlign.center,
              style: SakhiTypography.onboardingTitle.copyWith(fontSize: 25),
            ),
            const SizedBox(height: SakhiSpacing.xs),
            const Text(
              'Enter the six-digit code to continue.',
              textAlign: TextAlign.center,
              style: SakhiTypography.body,
            ),
            const SizedBox(height: SakhiSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SakhiSpacing.sm,
                vertical: SakhiSpacing.md,
              ),
              decoration: BoxDecoration(
                color: SakhiColors.lavender.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.phone_iphone_rounded,
                    color: SakhiColors.purple,
                    size: 19,
                  ),
                  const SizedBox(width: SakhiSpacing.xs),
                  Flexible(
                    child: Text(
                      _session.maskedPhoneNumber,
                      key: const Key('auth-otp-masked-phone'),
                      style: const TextStyle(
                        color: SakhiColors.plum,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SakhiSpacing.lg),
            Semantics(
              label: 'Six-digit verification code',
              child: TextFormField(
                key: const Key('auth-otp-code-field'),
                controller: _codeController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: SakhiColors.plum,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 12,
                ),
                decoration: InputDecoration(
                  labelText: '6-digit code',
                  hintText: '• • • • • •',
                  filled: true,
                  fillColor: SakhiColors.blush.withValues(alpha: 0.52),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: SakhiSpacing.md,
                    vertical: 19,
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
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SakhiRadii.control),
                    borderSide: const BorderSide(
                      color: SakhiColors.purple,
                      width: 1.5,
                    ),
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').length != 6) {
                    return 'Enter all six digits.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _verify(),
              ),
            ),
            if (_session.developmentCode != null) ...[
              const SizedBox(height: SakhiSpacing.md),
              Container(
                key: const Key('auth-development-otp-panel'),
                padding: const EdgeInsets.all(SakhiSpacing.md),
                decoration: BoxDecoration(
                  color: SakhiColors.lavender,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SakhiColors.progressInactive),
                ),
                child: Column(
                  children: [
                    const Text(
                      'LOCAL DEVELOPMENT OTP',
                      style: SakhiTypography.categoryLabel,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: SakhiSpacing.xs),
                    SelectableText(
                      _session.developmentCode!,
                      key: const Key('auth-development-otp-code'),
                      style: const TextStyle(
                        color: SakhiColors.plum,
                        fontSize: 26,
                        letterSpacing: 7,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: SakhiSpacing.xs),
                    const Text(
                      'Enter this test code. It was generated by the local backend; no SMS was sent and no carrier verification occurred.',
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
            ] else if (_session.isDemo) ...[
              const SizedBox(height: SakhiSpacing.xs),
              const Text(
                'Demo only: enter any six digits to preview the next step. This is not real verification.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: SakhiColors.mutedPlum,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
            if (_statusMessage != null) ...[
              const SizedBox(height: SakhiSpacing.md),
              SakhiAuthStatusMessage(message: _statusMessage!),
            ],
            const SizedBox(height: SakhiSpacing.lg),
            SakhiAuthSubmitButton(
              key: const Key('auth-verify-otp-button'),
              label: 'Verify number',
              icon: Icons.verified_outlined,
              isLoading: _isVerifying,
              onPressed: _isVerifying ? null : _verify,
            ),
            const SizedBox(height: SakhiSpacing.sm),
            Center(
              child: TextButton(
                key: const Key('auth-resend-otp-button'),
                onPressed: _secondsUntilResend > 0 || _isResending
                    ? null
                    : _resend,
                child: Text(
                  _secondsUntilResend > 0
                      ? 'Resend code in $_resendCountdownLabel'
                      : _isResending
                      ? 'Requesting a new code…'
                      : 'Resend code',
                ),
              ),
            ),
            Center(
              child: TextButton.icon(
                key: const Key('auth-change-number-button'),
                onPressed: _isVerifying || _isResending
                    ? null
                    : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Change mobile number'),
              ),
            ),
            const SakhiPolicyLinks(compact: true),
          ],
        ),
      ),
    );
  }
}
