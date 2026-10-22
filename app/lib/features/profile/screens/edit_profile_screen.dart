import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_avatar.dart';
import '../../../core/widgets/sakhi_buttons.dart';
import '../../../core/widgets/sakhi_dialogs.dart';

/// Screen 07 — Edit Profile
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  late List<String> _interests;
  late String _originalUsername;
  String _locationVisibility = 'Verified Members';
  Timer? _usernameDebounce;
  bool _checkingUsername = false;
  bool? _usernameAvailable = true;
  String? _usernameMessage = 'Username is available';
  late String _selectedAvatar;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _businessProfileEnabled = true;

  static const List<Map<String, String>> _avatarPresets =
      AppAssets.defaultAvatarPresets;

  @override
  void initState() {
    super.initState();
    final user = SakhiPrototypeState.instance.currentUser;
    _nameController = TextEditingController(text: user.displayName);
    _originalUsername = user.username.replaceFirst(RegExp(r'^@'), '');
    if (_originalUsername.isEmpty) _originalUsername = 'ananya_rao';
    _usernameController = TextEditingController(text: _originalUsername);
    _emailController = TextEditingController(text: user.email);
    _bioController = TextEditingController(
      text: user.bio.isNotEmpty
          ? user.bio
          : 'Mental wellness advocate, peer counselor & community builder 🌸 Helping women thrive together. 💜',
    );
    _locationController = TextEditingController(
      text: user.location.isNotEmpty ? user.location : 'Bangalore, India',
    );
    _interests = user.interests.isNotEmpty
        ? List<String>.from(user.interests)
        : <String>['Mental Wellness', 'Travel', 'Reading', 'WomenInTech', 'Art'];
    _selectedAvatar = user.avatarAsset;
    _businessProfileEnabled =
        (user.businessProfileUrl ?? '').trim().isNotEmpty || true;
    final locationSetting = SakhiPrototypeState.instance.privacySettings
        .where((setting) => setting.id == 'show_location')
        .firstOrNull;
    _locationVisibility = locationSetting?.selectedValue ?? 'Verified Members';
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String raw) {
    _usernameDebounce?.cancel();
    final username = raw.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();
    if (username == _originalUsername.toLowerCase()) {
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = true;
        _usernameMessage = 'Username is available';
      });
      return;
    }
    if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(username)) {
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = false;
        _usernameMessage =
            'Use 3–24 lowercase letters, numbers, or underscores';
      });
      return;
    }
    setState(() {
      _checkingUsername = true;
      _usernameAvailable = null;
      _usernameMessage = 'Checking availability…';
    });
    _usernameDebounce = Timer(const Duration(milliseconds: 300), () async {
      final result = await SakhiPrototypeState.instance
          .checkUsernameAvailability('@$username');
      if (!mounted ||
          _usernameController.text
                  .trim()
                  .replaceFirst(RegExp(r'^@'), '')
                  .toLowerCase() !=
              username) {
        return;
      }
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = result ?? true;
        _usernameMessage = result == false
            ? 'Username already taken or invalid'
            : 'Username is available';
      });
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    final rawUsername = _usernameController.text
        .trim()
        .replaceFirst(RegExp(r'^@'), '')
        .toLowerCase();
    final handle = '@$rawUsername';
    setState(() => _isSaving = true);

    if (rawUsername != _originalUsername.toLowerCase() &&
        SakhiPrototypeState.instance.isBackendSynced) {
      final available = await SakhiPrototypeState.instance
          .checkUsernameAvailability(handle);
      if (!mounted) return;
      if (available == false) {
        setState(() {
          _isSaving = false;
          _usernameAvailable = false;
          _usernameMessage = 'Username already taken or invalid';
        });
        SakhiDialogs.showPrototypeSnackbar(
          context,
          'Choose a different username before saving.',
        );
        return;
      }
    }

    final saved = await SakhiPrototypeState.instance.updateProfile(
      displayName: _nameController.text.trim(),
      username: handle,
      email: _emailController.text.trim(),
      businessProfileUrl: _businessProfileEnabled
          ? (SakhiPrototypeState.instance.currentUser.businessProfileUrl ??
                'https://sakhi.community/business')
          : '',
      bio: _bioController.text.trim(),
      location: _locationController.text.trim(),
      interests: _interests,
      avatarAsset: _selectedAvatar,
    );
    final mappedVisibility = _locationVisibility == 'Hidden'
        ? 'Hide Location'
        : _locationVisibility;
    final privacySaved = await SakhiPrototypeState.instance
        .updatePrivacySetting('show_location', mappedVisibility);
    if (!mounted) return;
    setState(() => _isSaving = false);
    final message = !saved
        ? 'Profile could not be saved. Your previous profile values were restored.'
        : !privacySaved
        ? 'Profile saved, but location visibility could not be saved.'
        : 'Profile updated.';
    SakhiDialogs.showPrototypeSnackbar(context, message);
    if (saved && privacySaved && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1440,
      maxHeight: 1440,
      imageQuality: 88,
    );
    if (!mounted || picked == null) return;
    final extension = picked.name.toLowerCase().split('.').last;
    final contentType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
    if (contentType == null) {
      SakhiDialogs.showPrototypeSnackbar(
        context,
        'Choose a JPG, PNG, or WebP image.',
      );
      return;
    }
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
      SakhiDialogs.showPrototypeSnackbar(
        context,
        'Choose an image under 8 MB.',
      );
      return;
    }

    setState(() => _isUploadingAvatar = true);
    String? uploadedUrl;
    try {
      uploadedUrl = await SakhiPrototypeState.instance.uploadMediaToCloud(
        purpose: 'profile_photo',
        fileName: picked.name.isEmpty ? 'profile_photo.jpg' : picked.name,
        fileBytes: bytes,
        contentType: contentType,
        cropAspectRatio: '1:1',
      );
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
    if (!mounted) return;
    if (uploadedUrl == null) {
      SakhiDialogs.showPrototypeSnackbar(
        context,
        'Upload failed—your previous profile photo was preserved. Check backend connection and retry.',
      );
      return;
    }
    setState(() => _selectedAvatar = uploadedUrl!);
    SakhiPrototypeState.instance.updateAvatar(uploadedUrl);
    SakhiDialogs.showPrototypeSnackbar(
      context,
      'Profile photo uploaded and saved.',
    );
  }

  void _openAvatarAndCloudPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
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
              'Update Profile Photo or Default Avatar',
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: 6),
            const Text(
              'Upload a photo from your device or choose one of our 12 original illustrated Sakhi women avatars:',
              style: AppTypography.subtitle,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Choose from Gallery'),
                    onPressed: _isUploadingAvatar
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _pickAndUploadPhoto(ImageSource.gallery);
                          },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Take Photo'),
                    onPressed: _isUploadingAvatar
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _pickAndUploadPhoto(ImageSource.camera);
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Or choose an illustrated Sakhi default avatar:',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _avatarPresets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, idx) {
                  final item = _avatarPresets[idx];
                  final asset = item['asset']!;
                  final isCurrent = _selectedAvatar == asset;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedAvatar = asset);
                      SakhiPrototypeState.instance.updateAvatar(asset);
                      Navigator.pop(ctx);
                    },
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isCurrent
                                  ? AppColors.primaryPurple
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: SakhiAvatar(imageAsset: asset, size: 56),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['label']!,
                          style: AppTypography.subtitle.copyWith(fontSize: 11),
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

  @override
  Widget build(BuildContext context) {
    final activeSeg = _locationVisibility == 'Hide Location'
        ? 'Hidden'
        : _locationVisibility;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingH,
            vertical: 10,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.primaryPurple,
                        size: 30,
                      ),
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'Edit Profile',
                        textAlign: TextAlign.center,
                        style: AppTypography.appBarTitle,
                      ),
                    ),
                    _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primaryPurple,
                            ),
                          )
                        : SakhiPillButton(
                            label: 'Save',
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            onPressed: _handleSave,
                          ),
                  ],
                ),

                const SizedBox(height: 10),
                // Cover Banner with "Change Cover" Pill + Overlapping Avatar + "Change Photo" (Reference 07)
                SizedBox(
                  height: 146,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: SizedBox(
                          height: 102,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                AppAssets.profileHeaderBanner,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                              ),
                              Positioned(
                                right: 10,
                                top: 10,
                                child: InkWell(
                                  onTap: _openAvatarAndCloudPicker,
                                  borderRadius: BorderRadius.circular(18),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.88,
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: AppColors.borderSubtle,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.photo_camera_outlined,
                                          size: 13,
                                          color: AppColors.primaryPurple,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Change Cover',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primaryPurple,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 44,
                        child: SakhiAvatar(
                          imageAsset: _selectedAvatar,
                          fallbackLabel: _nameController.text,
                          size: 98,
                          borderWidth: 3.5,
                          showEditCameraBadge: true,
                          onCameraTap: _openAvatarAndCloudPicker,
                        ),
                      ),
                    ],
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: _openAvatarAndCloudPicker,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      minimumSize: const Size(0, 26),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Change Photo',
                      style: TextStyle(
                        color: AppColors.primaryPurple,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (_isUploadingAvatar)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Center(
                      child: SizedBox(
                        width: 180,
                        child: LinearProgressIndicator(
                          color: AppColors.primaryPurple,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),
                Text(
                  'Display Name',
                  style: AppTypography.bodyMedium.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a display name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),
                Text(
                  'Username',
                  style: AppTypography.bodyMedium.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _usernameController,
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                  maxLength: 24,
                  decoration: InputDecoration(
                    prefixText: '@',
                    counterText: '',
                    suffixIcon: _checkingUsername
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Icon(
                            (_usernameAvailable ?? true)
                                ? Icons.check_circle_rounded
                                : Icons.error_outline_rounded,
                            color: (_usernameAvailable ?? true)
                                ? AppColors.wellnessGreen
                                : AppColors.sosRed,
                          ),
                  ),
                  onChanged: _onUsernameChanged,
                  validator: (value) {
                    final name = (value ?? '').trim().replaceFirst(
                      RegExp(r'^@'),
                      '',
                    );
                    if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(name)) {
                      return 'Use 3–24 lowercase letters, numbers, or underscores';
                    }
                    return null;
                  },
                ),
                if (_usernameMessage != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        (_usernameAvailable ?? true)
                            ? Icons.check_rounded
                            : Icons.info_outline_rounded,
                        size: 14,
                        color: (_usernameAvailable ?? true)
                            ? AppColors.wellnessGreen
                            : AppColors.sosRed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _usernameMessage!,
                        style: AppTypography.subtitle.copyWith(
                          color: (_usernameAvailable ?? true)
                              ? AppColors.wellnessGreen
                              : AppColors.sosRed,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),
                Text(
                  'Short Bio',
                  style: AppTypography.bodyMedium.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  maxLength: 150,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'A few words about you and your interests',
                    alignLabelWithHint: true,
                    counterText: '${_bioController.text.length} / 150',
                  ),
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 10),
                Text(
                  'City / General Location',
                  style: AppTypography.bodyMedium.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(
                      Icons.location_on_outlined,
                      size: 19,
                      color: AppColors.primaryPurple,
                    ),
                    hintText: 'City or general area only',
                  ),
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 14),
                Text(
                  'Location Visibility',
                  style: AppTypography.bodyMedium.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                // 3-Way Segmented Control matching Reference 07
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.pastelLavender,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      for (final option in const [
                        'Verified Members',
                        'Followers Only',
                        'Hidden',
                      ])
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(
                              () => _locationVisibility = option,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: activeSeg == option
                                    ? AppColors.primaryPurple
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                option,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: activeSeg == option
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: activeSeg == option
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Text(
                  'Interests',
                  style: AppTypography.bodyMedium.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._interests.map(
                      (interest) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.pastelLavender,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              interest,
                              style: const TextStyle(
                                color: AppColors.primaryPurple,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => setState(
                                () => _interests.remove(interest),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 15,
                                color: AppColors.primaryPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _showAddInterestDialog,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primaryPurple),
                        ),
                        child: const Text(
                          '+ Add Interest',
                          style: TextStyle(
                            color: AppColors.primaryPurple,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                // Link My Women-Owned Business Toggle Card (Reference 07)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.pastelLavender.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.storefront_outlined,
                          color: AppColors.primaryPurple,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Link My Women-Owned Business',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Showcase your verified business on profile',
                              style: AppTypography.subtitle,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _businessProfileEnabled,
                        activeColor: AppColors.primaryPurple,
                        onChanged: (enabled) =>
                            setState(() => _businessProfileEnabled = enabled),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: SakhiPillButton(
                    label: _isSaving ? 'Saving…' : 'Save Changes',
                    onPressed: _isSaving ? null : _handleSave,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddInterestDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: const Text('Add Interest', style: AppTypography.sectionTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter an interest tag'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          SakhiPillButton(
            label: 'Add',
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty && !_interests.contains(val)) {
                setState(() => _interests.add(val));
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}
