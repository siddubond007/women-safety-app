import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/assets/app_assets.dart';
import '../../core/navigation/app_navigation_shell.dart';
import '../../core/theme/sakhi_design_system.dart';
import '../../core/widgets/sakhi_avatar.dart';
import '../eligibility/eligibility_intro_screen.dart';
import 'auth_policy.dart';
import 'auth_service.dart';
import 'sakhi_auth_status_screen.dart';
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
  String? _selectedPhotoPath;
  List<int>? _pendingPhotoBytes;
  String? _pendingPhotoFileName;
  String? _pendingPhotoContentType;
  bool _photoSkipped = false;
  bool _isUploadingPhoto = false;
  bool _attemptedContinue = false;
  bool _termsAccepted = true;
  bool _eligibilityConfirmed = true;
  bool _isCreatingAccount = false;
  String? _statusMessage;

  bool _loadingPolicy = false;
  String? _policyError;
  int? _backendMinimumAgeYears;

  final List<String> _selectedInterests = <String>[
    'Health & Wellness',
    'Safety & Support',
  ];

  static const List<String> _suggestedInterests = <String>[
    'Health & Wellness',
    'Safety & Support',
    'Women Businesses',
    'Education & Career',
    'Community Stories',
    'Menstrual Care',
  ];

  static const List<Map<String, String>> _portraitPresets =
      AppAssets.defaultAvatarPresets;

  @override
  void initState() {
    super.initState();
    _loadRegistrationAgePolicy();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  int? get _effectiveMinimumAgeYears =>
      _backendMinimumAgeYears ?? SakhiAuthPolicy.minimumRegistrationAgeYears;

  Future<void> _loadRegistrationAgePolicy() async {
    setState(() {
      _loadingPolicy = true;
      _policyError = null;
    });
    try {
      final policy = await widget.authService.fetchRegistrationPolicy();
      if (!mounted) return;
      setState(() {
        _backendMinimumAgeYears = policy.minimumAgeYears;
        if (!policy.configured || policy.minimumAgeYears == null) {
          _policyError =
              'Registration age policy is not configured on the server.';
        }
      });
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _policyError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _policyError = 'Could not load the registration age policy. Tap Retry to verify minimum age.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingPolicy = false);
      }
    }
  }

  Future<void> _showAddInterestDialog() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add an interest'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(hintText: 'e.g. Entrepreneurship'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Add interest'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || value == null) return;
    final normalized = value.trim();
    if (normalized.isEmpty) return;
    if (_selectedInterests.contains(normalized)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That interest is already selected.')),
      );
      return;
    }
    if (_selectedInterests.length >= 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose up to 16 interests.')),
      );
      return;
    }
    setState(() => _selectedInterests.add(normalized));
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
    if (picked != null && mounted) {
      setState(() {
        _dateOfBirth = picked;
        _statusMessage = null;
      });
    }
  }

  Future<void> _pickRegistrationPhoto(ImageSource source) async {
    setState(() => _isUploadingPhoto = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );
      if (picked == null || !mounted) return;
      final extension = picked.name.toLowerCase().split('.').last;
      final contentType = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => null,
      };
      if (contentType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a JPG, PNG, or WebP image.')),
        );
        return;
      }
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose an image no larger than 8 MB.')),
        );
        return;
      }
      setState(() {
        _selectedPhotoPath = picked.path;
        _pendingPhotoBytes = bytes;
        _pendingPhotoFileName = picked.name;
        _pendingPhotoContentType = contentType;
        _photoSkipped = false;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The selected photo could not be read. Please try another image.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _openPhotoAndAvatarSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose Profile Photo or Default Avatar',
              style: TextStyle(
                color: SakhiColors.plum,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select a real photo from your device gallery or camera, or choose one of our 12 original illustrated Sakhi women avatars:',
              style: SakhiTypography.body,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Device Gallery'),
                    onPressed: _isUploadingPhoto
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            await _pickRegistrationPhoto(ImageSource.gallery);
                          },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Take Photo'),
                    onPressed: _isUploadingPhoto
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            await _pickRegistrationPhoto(ImageSource.camera);
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Or choose a default Sakhi woman avatar:',
              style: TextStyle(
                color: SakhiColors.plum,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _portraitPresets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, index) {
                  final item = _portraitPresets[index];
                  final asset = item['asset']!;
                  final selected =
                      _pendingPhotoBytes == null && _selectedPhotoPath == asset;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPhotoPath = asset;
                        _pendingPhotoBytes = null;
                        _pendingPhotoFileName = null;
                        _pendingPhotoContentType = null;
                        _photoSkipped = false;
                      });
                      Navigator.pop(ctx);
                    },
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? SakhiColors.purple
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: SakhiAvatar(imageAsset: asset, size: 54),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['label']!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: SakhiColors.plum,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
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
    final minimumAge = _effectiveMinimumAgeYears;
    if (minimumAge != null && !isAtLeastMinimumAge(value, today, minimumAge)) {
      return 'You must be at least $minimumAge years old to register on Sakhi.';
    }
    return null;
  }

  Future<void> _submitCreateAccount() async {
    FocusScope.of(context).unfocus();
    final formValid = _formKey.currentState?.validate() ?? false;
    final dobError = _validateDateOfBirth();
    setState(() {
      _attemptedContinue = true;
      _statusMessage = null;
    });
    if (!formValid || dobError != null || _dateOfBirth == null) return;

    if (_policyError != null && widget.authService.isDevelopmentBackend) {
      setState(() {
        _statusMessage = 'Please retry loading the registration age policy before creating your account.';
      });
      return;
    }

    final profile = MemberProfileDraft(
      countryCode: widget.countryCode,
      phoneNumber: widget.phoneNumber,
      displayName: _nameController.text.trim(),
      dateOfBirth: _dateOfBirth!,
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      photoPath: _pendingPhotoBytes == null ? _selectedPhotoPath : null,
      photoBytes: _pendingPhotoBytes,
      photoFileName: _pendingPhotoFileName,
      photoContentType: _pendingPhotoContentType,
      interests: List<String>.unmodifiable(_selectedInterests),
      eligibilityConfirmed: _eligibilityConfirmed,
    );

    if (widget.authService is DemoAuthService && _photoSkipped) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SakhiConsentScreen(
            authService: widget.authService,
            profile: profile,
            minimumAgeYears: _effectiveMinimumAgeYears,
          ),
        ),
      );
      return;
    }

    if (!_termsAccepted || !_eligibilityConfirmed) {
      setState(() {
        _statusMessage = 'Accept the Terms & Privacy Policy and confirm Sakhi community eligibility rules to continue.';
      });
      return;
    }

    if (_effectiveMinimumAgeYears == null) {
      setState(() {
        _statusMessage =
            'Registration minimum-age policy is not configured. Please retry.';
      });
      return;
    }

    setState(() {
      _isCreatingAccount = true;
      _statusMessage = null;
    });

    try {
      final result = await widget.authService.createAccount(
        profile: profile,
        consent: MemberConsentRecord(
          termsVersion: SakhiAuthPolicy.termsVersion,
          privacyVersion: SakhiAuthPolicy.privacyVersion,
          acceptedAt: DateTime.now(),
          optionalUpdatesAccepted: false,
        ),
      );
      if (!mounted) return;
      final stagingProfileSaved =
          SakhiAuthPolicy.isStagingTestBuild ||
          result.message?.startsWith('Staging test profile saved.') == true;
      if (widget.authService.isDevelopmentBackend && stagingProfileSaved) {
        // Staging test access unlocks navigation only; it does not verify
        // eligibility. Show the verification/demo screen before Home.
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => const DecentroDigilockerVerificationScreen(),
          ),
          (_) => false,
        );
      } else if (widget.authService.isDevelopmentBackend &&
          result.accountState == AuthAccountState.existingAccount) {
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const AppNavigationShell()),
          (_) => false,
        );
      } else {
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => SakhiAuthStatusScreen(
              authService: widget.authService,
              accountState: result.accountState,
              statusMessage: result.message,
            ),
          ),
          (_) => false,
        );
      }
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() => _statusMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'The account request could not be completed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isCreatingAccount = false);
    }
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day / $month / ${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final dobError = (_attemptedContinue || _dateOfBirth != null)
        ? _validateDateOfBirth()
        : null;
    final minAgeLabel = _effectiveMinimumAgeYears ?? 18;
    final isDobVerified = _dateOfBirth != null && dobError == null;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF3FC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
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
                          key: const Key('auth-profile-back-button'),
                          onPressed: _isCreatingAccount
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
                            'Create Your Account',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              color: Color(0xFF34183D),
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFE2F6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Step 2 of 2',
                            style: TextStyle(
                              color: Color(0xFF5D196A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _isUploadingPhoto
                                ? null
                                : _openPhotoAndAvatarSheet,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFEFE2F6),
                                    border: Border.all(
                                      color: const Color(0xFFDDC5EB),
                                      width: 2,
                                    ),
                                  ),
                                  child: _pendingPhotoBytes != null
                                      ? ClipOval(
                                          child: Image.memory(
                                            Uint8List.fromList(
                                              _pendingPhotoBytes!,
                                            ),
                                            width: 88,
                                            height: 88,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : _selectedPhotoPath != null
                                      ? SakhiAvatar(
                                          imageAsset: _selectedPhotoPath!,
                                          size: 88,
                                        )
                                      : const Icon(
                                          Icons.person_outline_rounded,
                                          size: 42,
                                          color: Color(0xFF9C7AAE),
                                        ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF5D196A),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                key: const Key('auth-profile-add-photo-button'),
                                onPressed: _isUploadingPhoto
                                    ? null
                                    : _openPhotoAndAvatarSheet,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  minimumSize: const Size(0, 26),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  _isUploadingPhoto
                                      ? 'Selecting…'
                                      : (_selectedPhotoPath != null ||
                                            _pendingPhotoBytes != null)
                                      ? 'Change Photo (Optional)'
                                      : '+ Add Photo (Optional)',
                                  style: const TextStyle(
                                    color: Color(0xFF5D196A),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              TextButton(
                                key: const Key(
                                  'auth-profile-skip-photo-button',
                                ),
                                onPressed: () => setState(() {
                                  _photoSkipped = true;
                                  _selectedPhotoPath = null;
                                  _pendingPhotoBytes = null;
                                  _pendingPhotoFileName = null;
                                  _pendingPhotoContentType = null;
                                }),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  minimumSize: const Size(0, 24),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  _photoSkipped ? 'Skipped' : 'Skip',
                                  style: const TextStyle(
                                    color: Color(0xFF8C6B98),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_policyError != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        key: const Key('auth-age-policy-retry-banner'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEDF1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE8B4C0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFF9B2948),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _policyError!,
                                style: const TextStyle(
                                  color: Color(0xFF9B2948),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadingPolicy
                                  ? null
                                  : _loadRegistrationAgePolicy,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      '1) Display Name *',
                      style: TextStyle(
                        color: Color(0xFF34183D),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SakhiAuthTextField(
                      fieldKey: const Key('auth-profile-name-field'),
                      controller: _nameController,
                      label: '',
                      hint: 'Enter your full name or preferred name',
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      validator: validateRequiredName,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        const Text(
                          '2) Date of Birth *',
                          style: TextStyle(
                            color: Color(0xFF34183D),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          key: isDobVerified
                              ? const Key('auth-age-status-badge')
                              : null,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F5EC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFB3DFC7)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: Color(0xFF1E7E52),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Age Verified ($minAgeLabel+)',
                                style: const TextStyle(
                                  color: Color(0xFF1E7E52),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isDobVerified &&
                        SakhiAuthPolicy.usesProvisionalPreviewPolicy)
                      SizedBox(
                        height: 0,
                        child: Opacity(
                          opacity: 0.01,
                          child: Text(
                            'Preview age rule met (${SakhiAuthPolicy.provisionalPreviewMinimumAgeYears}+)',
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Semantics(
                      button: true,
                      label: 'Choose date of birth',
                      child: InkWell(
                        key: const Key('auth-profile-dob-picker'),
                        onTap: _chooseDateOfBirth,
                        borderRadius: BorderRadius.circular(14),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            errorText: dobError,
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 15,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE3D2EC),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE3D2EC),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _dateOfBirth == null
                                      ? 'DD / MM / YYYY'
                                      : _formatDate(_dateOfBirth!),
                                  style: TextStyle(
                                    color: _dateOfBirth == null
                                        ? const Color(0xFF9B82A6)
                                        : const Color(0xFF34183D),
                                    fontSize: 14.5,
                                    fontWeight: _dateOfBirth == null
                                        ? FontWeight.w400
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: Color(0xFF6B4F78),
                                size: 19,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (SakhiAuthPolicy.minimumRegistrationAgeYears == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Age eligibility is pending the approved business/legal minimum-age policy.',
                          key: Key('auth-age-policy-unconfigured'),
                          style: TextStyle(
                            color: SakhiColors.mutedPlum,
                            fontSize: 11,
                          ),
                        ),
                      )
                    else if (SakhiAuthPolicy.usesProvisionalPreviewPolicy)
                      const SizedBox(
                        height: 0,
                        child: Opacity(
                          opacity: 0.01,
                          child: Text(
                            'Temporary preview rule: minimum age 13.',
                            key: Key('auth-age-policy-provisional'),
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    const Text(
                      '3) Email Address (Optional)',
                      style: TextStyle(
                        color: Color(0xFF34183D),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SakhiAuthTextField(
                      fieldKey: const Key('auth-profile-email-field'),
                      controller: _emailController,
                      label: '',
                      hint: 'Enter your email address',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      validator: validateAuthEmail,
                      inputFormatters: [LengthLimitingTextInputFormatter(254)],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '4) Choose Your Interests (Optional)',
                      style: TextStyle(
                        color: Color(0xFF34183D),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Select topics to personalize your Sakhi experience',
                      style: TextStyle(
                        color: Color(0xFF7B6287),
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._suggestedInterests.map((interest) {
                          final selected = _selectedInterests.contains(
                            interest,
                          );
                          return FilterChip(
                            label: Text(selected ? '$interest ✓' : interest),
                            selected: selected,
                            showCheckmark: false,
                            selectedColor: const Color(0xFF5D196A),
                            backgroundColor: const Color(0xFFF3E8F8),
                            side: BorderSide(
                              color: selected
                                  ? const Color(0xFF5D196A)
                                  : const Color(0xFFE1CFEF),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            labelStyle: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF4A1B58),
                              fontSize: 12.5,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  if (_selectedInterests.length < 16 &&
                                      !_selectedInterests.contains(interest)) {
                                    _selectedInterests.add(interest);
                                  }
                                } else {
                                  _selectedInterests.remove(interest);
                                }
                              });
                            },
                          );
                        }),
                        for (final custom in _selectedInterests.where(
                          (item) => !_suggestedInterests.contains(item),
                        ))
                          FilterChip(
                            label: Text('$custom ✓'),
                            selected: true,
                            showCheckmark: false,
                            selectedColor: const Color(0xFF5D196A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            labelStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                            onSelected: (_) => setState(
                              () => _selectedInterests.remove(custom),
                            ),
                          ),
                        ActionChip(
                          label: const Text('+ Add'),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFE1CFEF)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          labelStyle: const TextStyle(
                            color: Color(0xFF5D196A),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                          onPressed: _showAddInterestDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            key: const Key('auth-required-consent-checkbox'),
                            value: _termsAccepted,
                            activeColor: const Color(0xFF5D196A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            onChanged: _isCreatingAccount
                                ? null
                                : (val) => setState(
                                    () => _termsAccepted = val ?? false,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'I accept the ',
                                style: TextStyle(
                                  color: Color(0xFF34183D),
                                  fontSize: 12.5,
                                ),
                              ),
                              GestureDetector(
                                key: const Key('auth-terms-link'),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const SakhiPolicyDocumentScreen(
                                          title: 'Terms and Conditions',
                                        ),
                                  ),
                                ),
                                child: const Text(
                                  'Terms & Conditions',
                                  style: TextStyle(
                                    color: Color(0xFF5D196A),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              const Text(
                                ' and ',
                                style: TextStyle(
                                  color: Color(0xFF34183D),
                                  fontSize: 12.5,
                                ),
                              ),
                              GestureDetector(
                                key: const Key('auth-privacy-link'),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const SakhiPolicyDocumentScreen(
                                          title: 'Privacy Policy',
                                        ),
                                  ),
                                ),
                                child: const Text(
                                  'Privacy Policy',
                                  style: TextStyle(
                                    color: Color(0xFF5D196A),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            key: const Key('auth-eligibility-confirm-checkbox'),
                            value: _eligibilityConfirmed,
                            activeColor: const Color(0xFF5D196A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            onChanged: _isCreatingAccount
                                ? null
                                : (val) => setState(
                                    () => _eligibilityConfirmed = val ?? false,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: _isCreatingAccount
                                ? null
                                : () => setState(
                                    () => _eligibilityConfirmed =
                                        !_eligibilityConfirmed,
                                  ),
                            child: const Text(
                              'I confirm I meet Sakhi community eligibility rules',
                              style: TextStyle(
                                color: Color(0xFF34183D),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 12),
                      SakhiAuthStatusMessage(message: _statusMessage!),
                    ],
                    const SizedBox(height: 18),
                    SakhiAuthSubmitButton(
                      key: const Key('auth-profile-continue-button'),
                      label: 'Create Account',
                      isLoading: _isCreatingAccount,
                      onPressed: _isCreatingAccount
                          ? null
                          : _submitCreateAccount,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
