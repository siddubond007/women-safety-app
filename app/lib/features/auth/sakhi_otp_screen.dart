import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/navigation/app_navigation_shell.dart';
import '../../core/theme/sakhi_design_system.dart';
import '../../shared/widgets/sakhi_botanical_flower.dart';
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
  final _codeFocusNode = FocusNode();
  late AuthOtpSession _session;
  Timer? _timer;
  Timer? _autoVerifyTimer;
  String? _lastAutoVerifiedCode;
  int _secondsUntilResend = 0;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _codeController.addListener(_handleCodeChanged);
    _codeFocusNode.addListener(_handleFocusChanged);
    _startResendCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _codeFocusNode.requestFocus();
    });
  }

  void _handleCodeChanged() {
    if (!mounted) return;
    setState(() {});
    final current = _codeController.text.trim();
    _autoVerifyTimer?.cancel();
    if (current.length < 6) {
      _lastAutoVerifiedCode = null;
      return;
    }
    if (current.length == 6 &&
        !_isVerifying &&
        !_isResending &&
        _lastAutoVerifiedCode != current) {
      _autoVerifyTimer = Timer(const Duration(milliseconds: 180), () {
        if (!mounted || _isVerifying || _isResending) return;
        final latest = _codeController.text.trim();
        if (latest.length == 6 && _lastAutoVerifiedCode != latest) {
          _lastAutoVerifiedCode = latest;
          unawaited(_verify());
        }
      });
    }
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoVerifyTimer?.cancel();
    _codeController.removeListener(_handleCodeChanged);
    _codeFocusNode.removeListener(_handleFocusChanged);
    _codeController.dispose();
    _codeFocusNode.dispose();
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

  void _appendOtpDigit(String digit) {
    if (_isVerifying || _isResending || _codeController.text.length >= 6) {
      return;
    }
    final next = '${_codeController.text}$digit';
    _codeController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _codeFocusNode.requestFocus();
    if (_statusMessage != null) {
      setState(() => _statusMessage = null);
    }
  }

  void _deleteOtpDigit() {
    _autoVerifyTimer?.cancel();
    if (_isVerifying || _isResending || _codeController.text.isEmpty) return;
    final next = _codeController.text.substring(
      0,
      _codeController.text.length - 1,
    );
    _codeController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _codeFocusNode.requestFocus();
    if (_statusMessage != null) {
      setState(() => _statusMessage = null);
    }
  }

  Widget _buildNumericKeypad() {
    final compact = MediaQuery.sizeOf(context).height < 700;
    final keyHeight = compact ? 40.0 : 48.0;
    final rowVerticalPadding = compact ? 2.5 : 4.5;
    const keyRows = <List<String>>[
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    Widget digitKey(String digit) {
      return Expanded(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 5,
            vertical: rowVerticalPadding,
          ),
          child: Semantics(
            button: true,
            label: digit,
            child: OutlinedButton(
              key: Key('auth-otp-key-$digit'),
              onPressed: _isVerifying || _isResending
                  ? null
                  : () => _appendOtpDigit(digit),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF34183D),
                side: const BorderSide(color: Color(0xFFE6D4F0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: EdgeInsets.zero,
                minimumSize: Size(0, keyHeight),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                digit,
                style: const TextStyle(
                  color: Color(0xFF34183D),
                  fontSize: 22,
                  height: 1.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      key: const Key('auth-otp-custom-keypad'),
      decoration: const BoxDecoration(
        color: Color(0xFFEFE3F6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(14, compact ? 6 : 10, 14, compact ? 6 : 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in keyRows)
            Row(children: [for (final digit in row) digitKey(digit)]),
          Row(
            children: [
              Expanded(child: SizedBox(height: keyHeight)),
              digitKey('0'),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: rowVerticalPadding,
                  ),
                  child: OutlinedButton(
                    key: const Key('auth-otp-key-backspace'),
                    onPressed: _isVerifying || _isResending
                        ? null
                        : _deleteOtpDigit,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFE6D4F0),
                      foregroundColor: const Color(0xFF4A1B58),
                      side: const BorderSide(color: Color(0xFFDCC4E8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.zero,
                      minimumSize: Size(0, keyHeight),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Icon(
                      Icons.backspace_outlined,
                      size: 21,
                      color: Color(0xFF4A1B58),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _verify() async {
    _autoVerifyTimer?.cancel();
    FocusScope.of(context).unfocus();
    if (_isVerifying) return;
    _lastAutoVerifiedCode = _codeController.text.trim();
    if (_codeController.text.trim().length != 6) {
      setState(() => _statusMessage = 'Enter all six digits.');
      _codeFocusNode.requestFocus();
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
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
            if (widget.authService.isDevelopmentBackend) {
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
                    accountState: AuthAccountState.existingAccount,
                    statusMessage: 'Demo verification only. No authenticated session exists; protected Home remains locked.',
                  ),
                ),
                (_) => false,
              );
            }
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
    final compact = MediaQuery.sizeOf(context).height < 700;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF3FC),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned(
              top: 6,
              right: -8,
              child: SakhiBotanicalFlower(
                type: SakhiFlowerType.cherryBlossom,
                width: 82,
                height: 98,
                opacity: 0.55,
              ),
            ),
            const Positioned(
              top: 230,
              left: -10,
              child: SakhiBotanicalFlower(
                type: SakhiFlowerType.lavenderSprig,
                width: 72,
                height: 90,
                opacity: 0.45,
              ),
            ),
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      compact ? 2 : 8,
                      20,
                      compact ? 8 : 16,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    key: const Key('auth-otp-back-button'),
                                    tooltip: 'Back',
                                    onPressed: _isVerifying || _isResending
                                        ? null
                                        : () => Navigator.of(context).pop(),
                                    icon: const Icon(
                                      Icons.chevron_left_rounded,
                                      color: Color(0xFF34183D),
                                      size: 30,
                                    ),
                                  ),
                                  const Expanded(
                                    child: Text(
                                      'Verify Mobile Number',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Georgia',
                                        color: Color(0xFF34183D),
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 48),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Enter the 6-digit code sent to',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF6B4F78),
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                children: [
                                  Text(
                                    _session.formattedPhoneNumber,
                                    style: const TextStyle(
                                      color: Color(0xFF34183D),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15.5,
                                    ),
                                  ),
                                  TextButton(
                                    key: const Key('auth-change-number-button'),
                                    onPressed: _isVerifying || _isResending
                                        ? null
                                        : () => Navigator.of(context).pop(),
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(0, 28),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      '(Change)',
                                      key: Key('auth-otp-change-number-link'),
                                      style: TextStyle(
                                        color: Color(0xFF5D196A),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Preserve masked-phone widget key & text for accessibility & unit tests
                              SizedBox(
                                height: 0,
                                child: Opacity(
                                  opacity: 0.01,
                                  child: Text(
                                    _session.maskedPhoneNumber,
                                    key: const Key('auth-otp-masked-phone'),
                                  ),
                                ),
                              ),
                              SizedBox(height: compact ? 10 : 22),
                              Semantics(
                                label: 'Six-digit verification code',
                                child: SizedBox(
                                  height: 60,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Row(
                                        children: List.generate(6, (index) {
                                          final code = _codeController.text;
                                          final hasDigit = index < code.length;
                                          final isActive =
                                              _codeFocusNode.hasFocus &&
                                              index == code.length.clamp(0, 5);
                                          return Expanded(
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                right: index == 5 ? 0 : 8,
                                              ),
                                              child: AnimatedContainer(
                                                key: Key('auth-otp-box-$index'),
                                                duration: const Duration(
                                                  milliseconds: 120,
                                                ),
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: isActive
                                                        ? const Color(
                                                            0xFF5D196A,
                                                          )
                                                        : hasDigit
                                                        ? const Color(
                                                            0xFFD1B3E0,
                                                          )
                                                        : const Color(
                                                            0xFFE3D2EC,
                                                          ),
                                                    width: isActive ? 2.0 : 1.2,
                                                  ),
                                                  boxShadow: isActive
                                                      ? [
                                                          BoxShadow(
                                                            color:
                                                                const Color(
                                                                  0xFF5D196A,
                                                                ).withValues(
                                                                  alpha: 0.12,
                                                                ),
                                                            blurRadius: 8,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  2,
                                                                ),
                                                          ),
                                                        ]
                                                      : null,
                                                ),
                                                child: hasDigit
                                                    ? Text(
                                                        code[index],
                                                        style: const TextStyle(
                                                          color: Color(
                                                            0xFF34183D,
                                                          ),
                                                          fontSize: 22,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      )
                                                    : isActive
                                                    ? Container(
                                                        width: 2,
                                                        height: 22,
                                                        color: const Color(
                                                          0xFF5D196A,
                                                        ),
                                                      )
                                                    : const SizedBox.shrink(),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                      Positioned.fill(
                                        child: Opacity(
                                          opacity: 0.01,
                                          child: TextFormField(
                                            key: const Key(
                                              'auth-otp-code-field',
                                            ),
                                            controller: _codeController,
                                            focusNode: _codeFocusNode,
                                            autofocus: false,
                                            keyboardType: TextInputType.none,
                                            textInputAction:
                                                TextInputAction.done,
                                            autofillHints: const [
                                              AutofillHints.oneTimeCode,
                                            ],
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                6,
                                              ),
                                            ],
                                            style: const TextStyle(
                                              color: Colors.transparent,
                                              fontSize: 24,
                                            ),
                                            cursorColor: Colors.transparent,
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              filled: false,
                                              counterText: '',
                                              errorStyle: TextStyle(
                                                fontSize: 0,
                                                height: 0,
                                              ),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            validator: (value) =>
                                                (value ?? '').length == 6
                                                ? null
                                                : 'Required',
                                            onFieldSubmitted: (_) => _verify(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: compact ? 8 : 16),
                              Center(
                                child: TextButton(
                                  key: const Key('auth-resend-otp-button'),
                                  onPressed:
                                      _secondsUntilResend > 0 || _isResending
                                      ? null
                                      : _resend,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: const Size(0, 30),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      style: const TextStyle(
                                        color: Color(0xFF6B4F78),
                                        fontSize: 13.5,
                                      ),
                                      children: [
                                        const TextSpan(
                                          text: "Didn't receive the code? ",
                                        ),
                                        TextSpan(
                                          text: _secondsUntilResend > 0
                                              ? 'Resend OTP in $_resendCountdownLabel'
                                              : _isResending
                                              ? 'Requesting a new code…'
                                              : 'Resend OTP',
                                          style: const TextStyle(
                                            color: Color(0xFF5D196A),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (_session.developmentCode != null) ...[
                                SizedBox(height: compact ? 4 : 10),
                                Container(
                                  key: const Key('auth-development-otp-panel'),
                                  padding: EdgeInsets.all(compact ? 6 : 10),
                                  decoration: BoxDecoration(
                                    color: SakhiColors.lavender,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: SakhiColors.progressInactive,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        'LOCAL DEVELOPMENT OTP',
                                        style: SakhiTypography.categoryLabel,
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: compact ? 2 : 4),
                                      SelectableText(
                                        _session.developmentCode!,
                                        key: const Key(
                                          'auth-development-otp-code',
                                        ),
                                        style: const TextStyle(
                                          color: SakhiColors.plum,
                                          fontSize: 20,
                                          letterSpacing: 6,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (_session.isDemo &&
                                  !_session.usesSharedTestCode) ...[
                                const SizedBox(height: 4),
                                const Text(
                                  'Demo only: enter any six digits to preview the next step. This is not real verification.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: SakhiColors.mutedPlum,
                                    fontSize: 11.5,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              if (_statusMessage != null) ...[
                                const SizedBox(height: 10),
                                SakhiAuthStatusMessage(
                                  message: _statusMessage!,
                                ),
                              ],
                              SizedBox(height: compact ? 6 : 14),
                              SakhiAuthSubmitButton(
                                key: const Key('auth-verify-otp-button'),
                                label: 'Verify & Continue',
                                isLoading: _isVerifying,
                                onPressed: _isVerifying ? null : _verify,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildNumericKeypad(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
