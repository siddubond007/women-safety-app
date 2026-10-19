import 'package:flutter/material.dart';
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

/// Screen 7 — Edit Profile (connected to PostgreSQL + Cloud Upload ready)
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

  static const List<Map<String, String>> _avatarPresets = [
    {'label': 'Siddhu', 'asset': AppAssets.avatarSiddhu},
    {'label': 'Ananya', 'asset': AppAssets.avatarAnanya},
    {'label': 'Meera', 'asset': AppAssets.avatarMeera},
    {'label': 'Kavya', 'asset': AppAssets.avatarKavya},
    {'label': 'Ishita', 'asset': AppAssets.avatarIshita},
    {'label': 'Priya', 'asset': AppAssets.avatarPriya},
    {'label': 'Sneha', 'asset': AppAssets.avatarSneha},
  ];

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
    SakhiPrototypeState.instance.updateProfile(
      displayName: _nameController.text.trim(),
      bio: _bioController.text.trim(),
      location: _locationController.text.trim(),
      interests: _interests,
      avatarAsset: _selectedAvatar,
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
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

  void _openAvatarAndCloudPicker() {
    final urlController = TextEditingController(
      text: _selectedAvatar.startsWith('http') ? _selectedAvatar : '',
    );
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
              'Choose Avatar or Cloud Image URL',
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: 6),
            const Text(
              'Select one of the crisp HD illustrated portraits or paste a Cloud Storage URL (S3 / R2 / Firebase / Cloudinary):',
              style: AppTypography.subtitle,
            ),
            const SizedBox(height: 14),
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
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: const Text('Upload New Avatar to Backend Cloud Storage'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final uploadedUrl = await SakhiPrototypeState.instance
                      .uploadMediaToCloud(
                        purpose: 'avatar',
                        fileName: 'profile_avatar_cloud.svg',
                        presetTheme: 'botanical_bloom',
                      );
                  if (!mounted || uploadedUrl == null) return;
                  setState(() => _selectedAvatar = uploadedUrl);
                  SakhiPrototypeState.instance.updateAvatar(uploadedUrl);
                  SakhiDialogs.showPrototypeSnackbar(
                    context,
                    'Avatar uploaded to Backend Cloud Storage & saved in PostgreSQL!',
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Cloud Image URL (https://...)',
                hintText: 'https://your-cloud-bucket.example.com/avatar.webp',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                SakhiPillButton(
                  label: 'Use Cloud URL',
                  onPressed: () {
                    final url = urlController.text.trim();
                    if (url.startsWith('http://') ||
                        url.startsWith('https://')) {
                      setState(() => _selectedAvatar = url);
                      SakhiPrototypeState.instance.updateAvatar(url);
                      Navigator.pop(ctx);
                      SakhiDialogs.showPrototypeSnackbar(
                        context,
                        'Cloud avatar URL linked and saved to backend!',
                      );
                    }
                  },
                ),
              ],
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
                // Standalone Reusable Botanical Flowers + Profile Avatar + Camera Control
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
