import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/assets/app_assets.dart';
import '../../core/theme/sakhi_design_system.dart';
import '../../core/widgets/sakhi_avatar.dart';
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
  String? _selectedPhotoPath;
  List<int>? _pendingPhotoBytes;
  String? _pendingPhotoFileName;
  String? _pendingPhotoContentType;
  bool _photoSkipped = false;
  bool _isUploadingPhoto = false;
  bool _attemptedContinue = false;

  static const List<Map<String, String>> _portraitPresets =
      AppAssets.defaultAvatarPresets;

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
          const SnackBar(
            content: Text('Choose an image no larger than 8 MB.'),
          ),
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
      photoPath: _pendingPhotoBytes == null ? _selectedPhotoPath : null,
      photoBytes: _pendingPhotoBytes,
      photoFileName: _pendingPhotoFileName,
      photoContentType: _pendingPhotoContentType,
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
      authIsDevelopmentBackend: widget.authService.isDevelopmentBackend,
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
              'PROFILE PHOTO · DEVICE GALLERY OR ILLUSTRATED AVATAR',
              style: SakhiTypography.categoryLabel,
            ),
            const SizedBox(height: SakhiSpacing.xs),
            Row(
              children: [
                if (_pendingPhotoBytes != null)
                  ClipOval(
                    child: Image.memory(
                      Uint8List.fromList(_pendingPhotoBytes!),
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                    ),
                  )
                else if (_selectedPhotoPath != null)
                  SakhiAvatar(imageAsset: _selectedPhotoPath!, size: 54)
                else
                  SakhiAvatar(
                    imageAsset: AppAssets.forKey(_nameController.text),
                    size: 54,
                  ),
                const SizedBox(width: SakhiSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('auth-profile-add-photo-button'),
                    onPressed: _isUploadingPhoto
                        ? null
                        : _openPhotoAndAvatarSheet,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: Text(
                      _isUploadingPhoto
                          ? 'Selecting…'
                          : (_selectedPhotoPath != null ||
                                  _pendingPhotoBytes != null)
                              ? 'Change photo'
                              : 'Add photo',
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('auth-profile-skip-photo-button'),
                  onPressed: () => setState(() {
                    _photoSkipped = true;
                    _selectedPhotoPath = null;
                    _pendingPhotoBytes = null;
                    _pendingPhotoFileName = null;
                    _pendingPhotoContentType = null;
                  }),
                  child: Text(_photoSkipped ? 'Skipped' : 'Skip'),
                ),
              ],
            ),
            const SizedBox(height: SakhiSpacing.xs),
            Text(
              _pendingPhotoBytes != null
                  ? 'Your photo will upload to your private Google Drive folder after account creation.'
                  : _selectedPhotoPath != null
                      ? 'The selected Sakhi women\'s avatar will be saved with your profile.'
                      : 'Email and profile photo are optional. You can continue with a default Sakhi avatar.',
              style: const TextStyle(
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
