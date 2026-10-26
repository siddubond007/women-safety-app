import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/assets/app_assets.dart';
import '../../core/navigation/app_navigation_shell.dart';
import '../../core/theme/sakhi_design_system.dart';
import '../auth/backend_api_client.dart';
import '../auth/widgets/auth_widgets.dart';
import 'eligibility_information_screen.dart';
import 'eligibility_verification_models.dart';
import 'eligibility_verification_service.dart';
import 'eligibility_widgets.dart';

class EligibilityIntroScreen extends StatefulWidget {
  const EligibilityIntroScreen({super.key, required this.service});

  final EligibilityVerificationService service;

  @override
  State<EligibilityIntroScreen> createState() => _EligibilityIntroScreenState();
}

class _EligibilityIntroScreenState extends State<EligibilityIntroScreen> {
  bool _configurationLoading = true;
  EligibilityConfiguration _configuration =
      const EligibilityConfiguration.previewUnavailable();
  bool _configurationLoadFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadConfiguration());
  }

  Future<void> _loadConfiguration() async {
    try {
      final configuration = await widget.service.loadConfiguration();
      if (!mounted) return;
      setState(() {
        _configuration = configuration;
        _configurationLoading = false;
        _configurationLoadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _configuration = const EligibilityConfiguration.previewUnavailable();
        _configurationLoading = false;
        _configurationLoadFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final readinessMessage = !widget.service.isDevelopmentBackend
        ? 'DEMO PREVIEW — no approved verification provider is configured for this build. This screen does not verify identity or eligibility, and no provider request will be sent.'
        : _configurationLoading
        ? 'Checking staging identity-verification readiness. No provider request starts automatically.'
        : _configurationLoadFailed
        ? 'Could not load provider readiness. Try refreshing this screen or check the connection; no provider request was sent.'
        : _configuration.providerConfigured && _configuration.policyApproved
        ? '${_configuration.providerDisplayName ?? 'The staging identity provider'} is configured. Review the disclosures and give explicit consent before starting verification.'
        : _configuration.policyApproved
        ? 'STAGING TEST — the verification gate is enabled, but the provider runtime configuration is incomplete. No identity request can start until the required credentials and callback settings are available.'
        : 'DEVELOPMENT PREVIEW — no approved verification provider and policy are configured. This screen does not verify identity or eligibility.';

    return SakhiAuthScaffold(
      botanicalAsset: AppAssets.authBotanicalConsent,
      authIsDemo: !widget.service.isDevelopmentBackend,
      authIsDevelopmentBackend: widget.service.isDevelopmentBackend,
      botanicalHeight: 68,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EligibilityStepIndicator(
            step: 1,
            totalSteps: 3,
            label: 'A transparent process',
          ),
          const SizedBox(height: SakhiSpacing.md),
          const EligibilityVectorHero(
            icon: Icons.shield_outlined,
            caption: 'Private by design. Clear by choice.',
          ),
          const SizedBox(height: SakhiSpacing.md),
          const Text(
            'ELIGIBILITY VERIFICATION',
            style: SakhiTypography.categoryLabel,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SakhiSpacing.xs),
          Text(
            'Help us keep Sakhi a trusted space',
            textAlign: TextAlign.center,
            style: SakhiTypography.onboardingTitle.copyWith(fontSize: 25),
          ),
          const SizedBox(height: SakhiSpacing.sm),
          const Text(
            'Sakhi uses a separate eligibility check for community features reserved for verified members. It is different from confirming control of a mobile number.',
            textAlign: TextAlign.center,
            style: SakhiTypography.body,
          ),
          const SizedBox(height: SakhiSpacing.md),
          SakhiAuthStatusMessage(message: readinessMessage),
          const SizedBox(height: SakhiSpacing.md),
          const EligibilityPrincipleCard(
            icon: Icons.menu_book_outlined,
            title: 'Understand before you decide',
            description: 'The approved method, information used and consequences must be explained before consent.',
          ),
          const SizedBox(height: SakhiSpacing.xs),
          const EligibilityPrincipleCard(
            icon: Icons.lock_outline_rounded,
            title: 'Your information deserves care',
            description: 'Only the minimum permitted result should be received, with access and retention controls.',
          ),
          const SizedBox(height: SakhiSpacing.xs),
          const EligibilityPrincipleCard(
            icon: Icons.visibility_off_outlined,
            title: 'No assumptions about appearance',
            description:
                'Sakhi must never infer gender from a face, name or voice.',
            iconColor: SakhiColors.pinkAccent,
          ),
          const SizedBox(height: SakhiSpacing.md),
          const EligibilityBullet(
            icon: Icons.fact_check_outlined,
            text: 'A phone OTP or Aadhaar OTP alone does not establish eligibility.',
          ),
          const SizedBox(height: SakhiSpacing.md),
          if (widget.service.isDevelopmentBackend) ...[
            FilledButton.icon(
              key: const Key('eligibility-intro-decentro-button'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E7E55),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SakhiRadii.control),
                ),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DecentroDigilockerVerificationScreen(),
                ),
              ),
              icon: const Icon(Icons.verified_user_rounded),
              label: const Text('Continue to Decentro DigiLocker KYC'),
            ),
            const SizedBox(height: SakhiSpacing.xs),
          ],
          SakhiAuthSubmitButton(
            key: const Key('eligibility-review-details-button'),
            label: 'Review verification details',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    EligibilityInformationScreen(service: widget.service),
              ),
            ),
          ),
          const SizedBox(height: SakhiSpacing.xs),
          TextButton(
            key: const Key('eligibility-intro-privacy-button'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const SakhiPolicyDocumentScreen(title: 'Privacy Policy'),
              ),
            ),
            child: const Text('Read the current draft Privacy Policy'),
          ),
          if (widget.service.isDevelopmentBackend) ...[
            const SizedBox(height: SakhiSpacing.xs),
            OutlinedButton.icon(
              key: const Key('eligibility-home-access-button'),
              onPressed: () => Navigator.of(context).pushNamed('/home'),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Check development home access'),
            ),
          ],
          Center(
            child: TextButton(
              key: const Key('eligibility-intro-back-button'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not now · Back'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Complete Module 1 Female Eligibility & Decentro Staging DigiLocker KYC Flow
/// implementing SRS Sections 3.1, 3.2, 3.3, 3.4, and 3.5.
class DecentroDigilockerVerificationScreen extends StatefulWidget {
  final BackendApiClient? apiClient;

  const DecentroDigilockerVerificationScreen({super.key, this.apiClient});

  @override
  State<DecentroDigilockerVerificationScreen> createState() =>
      _DecentroDigilockerVerificationScreenState();
}

class _DecentroDigilockerVerificationScreenState
    extends State<DecentroDigilockerVerificationScreen> {
  static const MethodChannel _nativeChannel = MethodChannel(
    'sakhi/native_actions',
  );

  late final BackendApiClient _client = widget.apiClient ?? BackendApiClient();

  bool _identityConsentAccepted = false;
  bool _livenessConsentAccepted = false;
  bool _isInitiatingSession = false;
  bool _isVerifyingResult = false;

  String _currentStatus = 'NOT_VERIFIED';
  String? _referenceId;
  String? _authorizationUrl;
  String? _externalDecentroUrl;
  String? _statusMessage;
  bool _isVerifiedSuccess = false;
  bool _isDemoResult = false;
  bool _providerConfigured = false;
  bool _localSimulatorEnabled = false;
  bool _manualReviewEnabled = false;
  bool _manualReviewConsentAccepted = false;
  bool _testAccessApproved = false;
  String _manualReviewConsentVersion = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadCurrentEligibilityStatus());
  }

  Future<void> _loadCurrentEligibilityStatus() async {
    Map<String, dynamic> configuration = <String, dynamic>{};
    try {
      configuration = await _client.get('eligibility/configuration');
    } catch (_) {
      // Keep capabilities disabled when configuration cannot be loaded.
    }

    try {
      final res = await _client.get(
        'eligibility/decentro/status',
        authenticated: true,
      );
      if (!mounted) return;
      final verificationStatus =
          (res['verificationStatus'] ??
                  res['eligibilityStatus'] ??
                  'UNVERIFIED')
              .toString()
              .toUpperCase();
      final testAccess = res['testAccessApproved'] == true;
      setState(() {
        _providerConfigured = configuration['providerConfigured'] == true;
        _localSimulatorEnabled = configuration['localSimulatorEnabled'] == true;
        _manualReviewEnabled = configuration['manualReviewEnabled'] == true;
        _manualReviewConsentVersion =
            (configuration['manualReviewConsentVersion'] ?? '').toString();
        _testAccessApproved = testAccess;
        _currentStatus = testAccess && verificationStatus != 'VERIFIED'
            ? 'STAGING_TEST_ACCESS_APPROVED'
            : verificationStatus;
        _isVerifiedSuccess = verificationStatus == 'VERIFIED';
        _isDemoResult = false;
        if (res['message'] is String) {
          _statusMessage = res['message'] as String;
        }
      });
    } on BackendApiException {
      if (!mounted) return;
      try {
        final fallback = await _client.get(
          'eligibility/status',
          authenticated: true,
        );
        if (!mounted) return;
        final status = (fallback['eligibilityStatus'] ?? 'UNVERIFIED')
            .toString()
            .toUpperCase();
        setState(() {
          _providerConfigured = configuration['providerConfigured'] == true;
          _localSimulatorEnabled =
              configuration['localSimulatorEnabled'] == true;
          _manualReviewEnabled = configuration['manualReviewEnabled'] == true;
          _manualReviewConsentVersion =
              (configuration['manualReviewConsentVersion'] ?? '').toString();
          _testAccessApproved = fallback['testAccessApproved'] == true;
          _currentStatus = _testAccessApproved && status != 'VERIFIED'
              ? 'STAGING_TEST_ACCESS_APPROVED'
              : status;
          _isVerifiedSuccess = status == 'VERIFIED';
          _isDemoResult = false;
          if (fallback['message'] is String) {
            _statusMessage = fallback['message'] as String;
          }
        });
      } catch (_) {
        // Keep the current state if the status endpoint is unavailable.
      }
    } catch (_) {
      // Keep the current state if the status endpoint is unavailable.
    }
  }

  Future<void> _initiateDecentroSession() async {
    if (!_identityConsentAccepted) {
      setState(() {
        _statusMessage =
            'Please accept the explicit identity verification consent first.';
      });
      return;
    }
    if (!_providerConfigured) {
      setState(() {
        _statusMessage = 'Decentro is not configured for this backend. No provider request was sent.';
      });
      return;
    }

    setState(() {
      _isInitiatingSession = true;
      _statusMessage = null;
    });

    try {
      final res = await _client.post(
        'eligibility/decentro/initiate',
        authenticated: true,
        body: {
          'consent': true,
          'consentAccepted': true,
          'consentVersion': 'sakhi-decentro-kyc-v1',
          'biometricProcessingConsented': _livenessConsentAccepted,
          'consentPurpose': 'Verifying female eligibility and minimum age for Sakhi membership',
        },
      );
      if (!mounted) return;
      final rawAuthUrl = res['authorizationUrl']?.toString() ?? '';
      final parsedUrl = Uri.tryParse(rawAuthUrl);
      if (parsedUrl == null ||
          parsedUrl.scheme != 'https' ||
          parsedUrl.host.isEmpty) {
        setState(() {
          _statusMessage = 'The backend did not return a safe HTTPS provider authorization URL.';
        });
        return;
      }
      setState(() {
        _referenceId = res['referenceId']?.toString();
        _authorizationUrl = parsedUrl.toString();
        _externalDecentroUrl = parsedUrl.toString();
        _currentStatus = 'VERIFICATION_IN_PROGRESS';
        _isDemoResult = false;
        _statusMessage = res['message']?.toString() ?? 'DigiLocker session initiated. Complete the provider flow, then refresh status.';
      });
    } on BackendApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Could not start the Decentro session. No verification status was changed.';
      });
    } finally {
      if (mounted) {
        setState(() => _isInitiatingSession = false);
      }
    }
  }

  Future<void> _openDecentroPortalInBrowser() async {
    final urlToOpen = _externalDecentroUrl?.isNotEmpty == true
        ? _externalDecentroUrl!
        : (_authorizationUrl ?? '');
    if (urlToOpen.isEmpty) {
      await _initiateDecentroSession();
    }
    final finalUrl = _externalDecentroUrl?.isNotEmpty == true
        ? _externalDecentroUrl!
        : (_authorizationUrl ?? '');
    if (finalUrl.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: finalUrl));
    try {
      await _nativeChannel.invokeMethod<bool>('openExternalUrl', {
        'url': finalUrl,
      });
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: SakhiColors.purple,
        behavior: SnackBarBehavior.floating,
        content: Text('Opening Decentro Staging DigiLocker Portal in browser…'),
      ),
    );
  }

  Future<void> _completeStep2DemographicCheck({
    required String gender,
    required String dob,
    required String outcomeOverride,
  }) async {
    if (outcomeOverride == 'PENDING_MANUAL_REVIEW') {
      if (!_manualReviewEnabled) {
        setState(() {
          _statusMessage =
              'The backend has not enabled an approved manual-review policy.';
        });
        return;
      }
      if (!_manualReviewConsentAccepted) {
        setState(() {
          _statusMessage = 'Accept the separate manual-review consent before submitting your profile.';
        });
        return;
      }
    } else if (!_localSimulatorEnabled) {
      setState(() {
        _statusMessage = 'Synthetic demographics cannot verify a real account. The local simulator is disabled; complete the provider flow or ask an authorized administrator to grant staging test access.';
      });
      return;
    }

    setState(() {
      _isVerifyingResult = true;
      _statusMessage = null;
    });

    try {
      final Map<String, dynamic> res;
      if (outcomeOverride == 'PENDING_MANUAL_REVIEW') {
        res = await _client.post(
          'eligibility/start',
          authenticated: true,
          body: {
            'consentAccepted': true,
            'consentVersion': _manualReviewConsentVersion,
            'biometricProcessingConsented': false,
          },
        );
      } else {
        res = await _client.post(
          'eligibility/decentro/local-simulator',
          authenticated: true,
          body: {'gender': gender, 'dob': dob},
        );
      }

      if (!mounted) return;
      final isDemo = res['isDemo'] == true;
      final status = (res['eligibilityStatus'] ?? 'PENDING_MANUAL_REVIEW')
          .toString()
          .toUpperCase();
      setState(() {
        _currentStatus = status;
        _isDemoResult = isDemo && outcomeOverride != 'PENDING_MANUAL_REVIEW';
        _isVerifiedSuccess = !isDemo && status == 'VERIFIED';
        _statusMessage =
            res['message']?.toString() ??
            'The backend returned status $status.';
      });
      if (outcomeOverride == 'PENDING_MANUAL_REVIEW') {
        setState(() => _manualReviewConsentAccepted = false);
      }
    } on BackendApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Could not complete the selected action. No provider verification was inferred.';
      });
    } finally {
      if (mounted) {
        setState(() => _isVerifyingResult = false);
      }
    }
  }

  Color _badgeColorForStatus(String status) {
    switch (status.toUpperCase()) {
      case 'VERIFIED':
      case 'APPROVED':
        return const Color(0xFF1E7E55);
      case 'STAGING_TEST_ACCESS_APPROVED':
        return const Color(0xFF245B8F);
      case 'SIMULATION_PASSED':
      case 'SIMULATION_REJECTED':
        return SakhiColors.purple;
      case 'VERIFICATION_IN_PROGRESS':
      case 'PENDING_MANUAL_REVIEW':
      case 'REVERIFICATION_REQUIRED':
        return const Color(0xFF8B5A17);
      case 'REJECTED':
      case 'VERIFICATION_FAILED':
      case 'TEMPORARILY_RESTRICTED':
        return const Color(0xFFC92A49);
      default:
        return SakhiColors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = _badgeColorForStatus(_currentStatus);

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF8FB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: SakhiColors.plum,
          ),
          onPressed: () => Navigator.of(context).pop(_isVerifiedSuccess),
        ),
        title: const Text(
          'Female Eligibility Verification',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: SakhiColors.plum,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Status',
            onPressed: _loadCurrentEligibilityStatus,
            icon: const Icon(Icons.refresh_rounded, color: SakhiColors.purple),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: badgeColor.withValues(alpha: 0.4),
                  width: 1.4,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: badgeColor.withValues(alpha: 0.12),
                    child: Icon(
                      _isVerifiedSuccess
                          ? Icons.verified_user_rounded
                          : Icons.shield_outlined,
                      color: badgeColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CURRENT VERIFICATION STATUS (SRS 3.3)',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: SakhiColors.mutedPlum,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _currentStatus.replaceAll('_', ' '),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: badgeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (_isDemoResult) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4EFFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: SakhiColors.purple.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.science_outlined,
                      color: SakhiColors.purple,
                      size: 30,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'LOCAL SIMULATION ONLY — NOT VERIFIED',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: SakhiColors.plum,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusMessage ??
                          'Synthetic test only. No account status was changed.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: SakhiColors.mutedPlum,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_isVerifiedSuccess || _testAccessApproved) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F6EC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF1E7E55)),
                ),
                child: Column(
                  children: [
                    Icon(
                      _testAccessApproved && !_isVerifiedSuccess
                          ? Icons.science_outlined
                          : Icons.check_circle_rounded,
                      color: _testAccessApproved && !_isVerifiedSuccess
                          ? const Color(0xFF245B8F)
                          : const Color(0xFF1E7E55),
                      size: 44,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _testAccessApproved && !_isVerifiedSuccess
                          ? 'Staging Test Access Approved'
                          : 'Eligibility Confirmed - Welcome to Sakhi!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF134E34),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusMessage ??
                          (_testAccessApproved && !_isVerifiedSuccess
                              ? 'Test-only access was approved by an authorized administrator. Identity eligibility remains UNVERIFIED.'
                              : 'Your eligibility was confirmed by the configured verification process.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1E7E55),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      key: const Key('decentro-open-home-button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E7E55),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute<void>(
                            builder: (_) => const AppNavigationShell(),
                          ),
                          (_) => false,
                        );
                      },
                      icon: const Icon(Icons.home_rounded),
                      label: Text(
                        _testAccessApproved && !_isVerifiedSuccess
                            ? 'Enter Sakhi (staging testing only)'
                            : 'Enter Sakhi Community Home',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEADDE8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.lock_person_rounded,
                        color: SakhiColors.purple,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '1. Purpose, Consent & Privacy Guarantee (SRS 3.2 & 3.5)',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: SakhiColors.plum,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Why we verify: Sakhi restricts community access to verified female members aged 18+ to protect member safety and trust.\n'
                    '• How it works: Our authorised KYC partner Decentro DigiLocker checks only the gender ("F") and Date of Birth attributes.\n'
                    '• Zero Raw ID Storage (SRS 3.5): Sakhi NEVER stores your Aadhaar number, OTP, or raw identity documents—only the verification status token.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: SakhiColors.mutedPlum,
                    ),
                  ),
                  const Divider(height: 18),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: SakhiColors.purple,
                    value: _identityConsentAccepted,
                    onChanged: (val) =>
                        setState(() => _identityConsentAccepted = val ?? false),
                    title: const Text(
                      'I explicitly consent to female eligibility & age verification via Decentro DigiLocker KYC.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: SakhiColors.plum,
                      ),
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: SakhiColors.purple,
                    value: _livenessConsentAccepted,
                    onChanged: (val) =>
                        setState(() => _livenessConsentAccepted = val ?? false),
                    title: const Text(
                      'Optional: I consent to liveness checks only if enabled by the provider. This screen does not upload a selfie.',
                      style: TextStyle(
                        fontSize: 12,
                        color: SakhiColors.mutedPlum,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: SakhiColors.purple.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Step 1 — Initiate Decentro DigiLocker Session',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: SakhiColors.plum,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sends a session request from Sakhi backend to Decentro. Provider credentials stay on the server and are never embedded in the app.',
                    style: TextStyle(
                      fontSize: 12,
                      color: SakhiColors.mutedPlum,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('decentro-initiate-session-button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: SakhiColors.purple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: _isInitiatingSession
                        ? null
                        : _initiateDecentroSession,
                    icon: _isInitiatingSession
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.verified_user_rounded, size: 18),
                    label: Text(
                      _isInitiatingSession
                          ? 'Connecting to Decentro Staging…'
                          : _referenceId != null
                          ? 'Refresh Decentro DigiLocker Session'
                          : 'Start Decentro DigiLocker Verification',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (_referenceId != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session Reference: $_referenceId',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: SakhiColors.plum,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Provider transaction details remain on the server.',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: SakhiColors.mutedPlum,
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _openDecentroPortalInBrowser,
                            icon: const Icon(
                              Icons.open_in_browser_rounded,
                              size: 17,
                            ),
                            label: const Text(
                              'Open Decentro DigiLocker Session in Browser',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEADDE8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Step 2 — Complete Demographic Validation (gender: "F" & age >= 18)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: SakhiColors.plum,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'A real account can be marked verified only from a confirmed provider result. Synthetic values below are available only in the loopback development simulator and never update verification status.',
                    style: TextStyle(
                      fontSize: 12,
                      color: SakhiColors.mutedPlum,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_localSimulatorEnabled) ...[
                    FilledButton.icon(
                      key: const Key('decentro-verify-female-18-button'),
                      onPressed: _isVerifyingResult
                          ? null
                          : () => _completeStep2DemographicCheck(
                              gender: 'F',
                              dob: '1999-05-15',
                              outcomeOverride: 'VERIFIED',
                            ),
                      icon: const Icon(Icons.science_outlined),
                      label: const Text(
                        'Run Local Eligible-Demographic Simulation',
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: _isVerifyingResult
                          ? null
                          : () => _completeStep2DemographicCheck(
                              gender: 'M',
                              dob: '2012-01-01',
                              outcomeOverride: 'REJECTED',
                            ),
                      icon: const Icon(Icons.science_outlined),
                      label: const Text(
                        'Run Local Ineligible-Demographic Simulation',
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Local simulation is disabled on this backend. For friend testing, complete the real provider flow when configured or ask an authorized administrator for staging test access. Staging test access does not change verificationStatus.',
                      style: TextStyle(
                        fontSize: 12,
                        color: SakhiColors.mutedPlum,
                      ),
                    ),
                  ],
                  if (_manualReviewEnabled) ...[
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _manualReviewConsentAccepted,
                      onChanged: (value) => setState(
                        () => _manualReviewConsentAccepted = value ?? false,
                      ),
                      title: const Text(
                        'I separately consent to submit my profile for manual eligibility review under the displayed policy.',
                        style: TextStyle(fontSize: 12, color: SakhiColors.plum),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('decentro-submit-manual-review-button'),
                      onPressed:
                          _isVerifyingResult || !_manualReviewConsentAccepted
                          ? null
                          : () => _completeStep2DemographicCheck(
                              gender: '',
                              dob: '',
                              outcomeOverride: 'PENDING_MANUAL_REVIEW',
                            ),
                      icon: const Icon(Icons.support_agent_rounded, size: 18),
                      label: const Text('Request Manual Review'),
                    ),
                  ],
                ],
              ),
            ),

            if (_statusMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: SakhiColors.purple.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _statusMessage!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: SakhiColors.plum,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).pop(_isVerifiedSuccess),
                icon: const Icon(Icons.arrow_back_rounded, size: 17),
                label: const Text('Back to Account Status'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
