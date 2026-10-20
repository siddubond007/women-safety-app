import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_avatar.dart';
import '../../../core/widgets/sakhi_botanical_flower.dart';
import '../../../core/widgets/sakhi_buttons.dart';
import '../../../core/widgets/sakhi_chip.dart';
import '../../../core/widgets/sakhi_dialogs.dart';

/// Screen 7 — Edit Profile (connected to PostgreSQL + Google Drive Upload + 12 Default Women Avatars).
/// Never asks the user to paste a Cloud Storage URL.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  late List<String> _interests;
  late String _selectedAvatar;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  static const List<Map<String, String>> _avatarPresets =
      AppAssets.defaultAvatarPresets;

  @override
  void initState() {
    super.initState();
    final user = SakhiPrototypeState.instance.currentUser;
    _nameController = TextEditingController(text: user.displayName);
    _bioController = TextEditingController(text: user.bio);
    _locationController = TextEditingController(text: user.location);
    _interests = List<String>.from(user.interests);
    _selectedAvatar = user.avatarAsset;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    await SakhiPrototypeState.instance.updateProfile(
      displayName: _nameController.text.trim(),
      bio: _bioController.text.trim(),
      location: _locationController.text.trim(),
      interests: _interests,
      avatarAsset: _selectedAvatar,
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _isSaving = false);
    SakhiDialogs.showPrototypeSnackbar(
      context,
      'Profile and avatar saved to PostgreSQL!',
    );
    if (Navigator.of(context).canPop()) {
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
    SakhiDialogs.showPrototypeSnackbar(
      context,
      'Uploading your photo to private Google Drive folder…',
    );
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
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
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
      'Profile photo uploaded to Google Drive and saved to PostgreSQL.',
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
              'Upload a real photo from your device (stored privately in Google Drive under users/{id}/profile) or choose one of our 12 original illustrated Sakhi women avatars:',
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
                        Icons.arrow_back_rounded,
                        color: AppColors.primaryPurple,
                      ),
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Edit Profile',
                      style: AppTypography.appBarTitle,
                    ),
                    const Spacer(),
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
                              horizontal: 22,
                              vertical: 9,
                            ),
                            onPressed: _handleSave,
                          ),
                  ],
                ),

                const SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SakhiBotanicalFlower(
                        type: SakhiFlowerType.cherryBlossom,
                        width: 68,
                        height: 96,
                        opacity: 0.85,
                      ),
                      const SizedBox(width: 6),
                      SakhiAvatar(
                        imageAsset: _selectedAvatar,
                        size: 112,
                        borderWidth: 3.5,
                        showEditCameraBadge: true,
                        onCameraTap: _openAvatarAndCloudPicker,
                      ),
                      const SizedBox(width: 6),
                      const SakhiBotanicalFlower(
                        type: SakhiFlowerType.orchidBranch,
                        width: 68,
                        height: 96,
                        opacity: 0.85,
                        flipHorizontal: true,
                      ),
                    ],
                  ),
                ),
                if (_isUploadingAvatar) ...[
                  const SizedBox(height: 10),
                  const Center(
                    child: SizedBox(
                      width: 180,
                      child: LinearProgressIndicator(
                        color: AppColors.primaryPurple,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 22),
                Text(
                  'Display name',
                  style: AppTypography.bodyMedium.copyWith(fontSize: 13.5),
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

                const SizedBox(height: 16),
                Text(
                  'Bio',
                  style: AppTypography.bodyMedium.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  validator: (value) {
                    if (value != null && value.length > 200) {
                      return 'Bio must be 200 characters or fewer';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),
                Text(
                  'Location (optional)',
                  style: AppTypography.bodyMedium.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _locationController,
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 18),
                Text(
                  'Interests',
                  style: AppTypography.bodyMedium.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _interests
                      .map(
                        (interest) => SakhiChip(
                          label: interest,
                          onDelete: () {
                            setState(() => _interests.remove(interest));
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _showAddInterestDialog,
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: AppColors.primaryPurple,
                    ),
                    label: Text(
                      'Add interest',
                      style: AppTypography.chipLabel.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
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
          decoration: const InputDecoration(
            hintText: 'Enter an interest tag',
          ),
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
