import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_avatar.dart';
import '../../../core/widgets/sakhi_chip.dart';
import '../widgets/module2_feature_widgets.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final List<String> _interests = [];
  bool _dirty = false;
  bool _saving = false;
  String? _lastLoadedName;

  SakhiPrototypeState get _state => SakhiPrototypeState.instance;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onStateChanged);
    _hydrate();
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (!_dirty) _hydrate();
  }

  void _hydrate() {
    final user = _state.currentUser;
    if (user.displayName.isEmpty || user.displayName == _lastLoadedName) return;
    _lastLoadedName = user.displayName;
    _nameController.text = user.displayName;
    _emailController.text = user.email;
    _bioController.text = user.bio;
    _locationController.text = user.location;
    _interests
      ..clear()
      ..addAll(user.interests);
    if (mounted) setState(() {});
  }

  Future<void> _addInterest() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add an interest'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(hintText: 'e.g. Women in Tech'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || result == null || result.isEmpty) return;
    if (_interests.length >= 20) {
      _message('You can add up to 20 interests.');
      return;
    }
    if (_interests.any((value) => value.toLowerCase() == result.toLowerCase())) {
      _message('That interest is already on your profile.');
      return;
    }
    setState(() {
      _dirty = true;
      _interests.add(result);
    });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final success = await _state.updateProfile(
      displayName: _nameController.text.trim(),
      bio: _bioController.text.trim(),
      location: _locationController.text.trim(),
      interests: _interests,
      email: _emailController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) {
      _dirty = false;
      _lastLoadedName = _nameController.text.trim();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved to your Sakhi account.')));
      Navigator.of(context).maybePop();
    } else {
      _message(_state.backend?.errorMessage ?? 'Profile could not be saved.');
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _state,
      builder: (context, _) => Module2PageBody(
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Module2PageTitle('Edit Profile', subtitle: 'Keep your details accurate and up to date')),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save'),
              ),
            ]),
            const SizedBox(height: 13),
            Container(
              height: 126,
              width: double.infinity,
              decoration: BoxDecoration(gradient: AppColors.heroBannerGradient, borderRadius: BorderRadius.circular(AppSpacing.radiusXl)),
              child: Stack(children: [
                Positioned(left: 4, top: 7, bottom: 4, child: Image.asset(AppAssets.botanicalSprigLeft, fit: BoxFit.contain, width: 67, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
                Positioned(right: 4, top: 7, bottom: 4, child: Image.asset(AppAssets.botanicalSprigRight, fit: BoxFit.contain, width: 67, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
                Center(
                  child: SakhiAvatar(
                    imageAsset: _state.currentUser.avatarAsset,
                    size: 92,
                    fallbackLabel: _state.currentUser.displayName,
                    showEditCameraBadge: true,
                    onCameraTap: _showPhotoConfigurationNotice,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 19),
            const Text('Display name *', style: AppTypography.bodyMedium),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              maxLength: 100,
              decoration: const InputDecoration(hintText: 'Your display name'),
              onChanged: (_) => _dirty = true,
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) return 'Display name is required.';
                if (name.length > 100) return 'Use 100 characters or fewer.';
                if (!RegExp(r"^[\p{L}\p{M}\p{N}\s.'’_-]+$", unicode: true).hasMatch(name)) {
                  return 'Use letters, numbers, spaces, periods, apostrophes, hyphens or underscores.';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            const Text('Email (optional)', style: AppTypography.bodyMedium),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              maxLength: 254,
              decoration: const InputDecoration(hintText: 'name@example.com'),
              onChanged: (_) => _dirty = true,
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return null;
                if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) return 'Enter a valid email address.';
                return null;
              },
            ),
            const SizedBox(height: 8),
            const Text('Bio', style: AppTypography.bodyMedium),
            const SizedBox(height: 6),
            TextFormField(
              controller: _bioController,
              maxLength: 500,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(hintText: 'A short introduction about you'),
              onChanged: (_) => _dirty = true,
            ),
            const SizedBox(height: 8),
            const Text('Location (optional)', style: AppTypography.bodyMedium),
            const SizedBox(height: 6),
            TextFormField(
              controller: _locationController,
              maxLength: 100,
              decoration: const InputDecoration(
                hintText: 'City or general location',
                helperText: 'Do not enter your precise live location.',
              ),
              onChanged: (_) => _dirty = true,
            ),
            const SizedBox(height: 14),
            Row(children: [
              const Expanded(child: Text('Interests', style: AppTypography.bodyMedium)),
              TextButton.icon(onPressed: _addInterest, icon: const Icon(Icons.add_rounded), label: const Text('Add interest')),
            ]),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _interests.map((interest) => SakhiChip(
                label: interest,
                onDelete: () => setState(() {
                  _dirty = true;
                  _interests.remove(interest);
                }),
              )).toList(),
            ),
            const SizedBox(height: 14),
            const Text('Choose a JPG, PNG, or WebP photo. Uploaded images are stored in your private Google Drive and linked to your Sakhi profile.', style: AppTypography.subtitle),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save changes'),
              ),
            ),
            if (_state.backend?.errorMessage != null) ...[
              const SizedBox(height: 9),
              Text(_state.backend!.errorMessage!, style: const TextStyle(color: AppColors.sosRed, fontSize: 12)),
            ],
          ]),
        ),
      ),
    );
  }

  Future<void> _showPhotoConfigurationNotice() async {
    if (_saving) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
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
      _message('Choose a JPG, PNG, or WebP image.');
      return;
    }
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      _message('Choose an image between 1 byte and 10 MB.');
      return;
    }
    setState(() => _saving = true);
    _message('Uploading your photo to private Google Drive…');
    try {
      final uploadedUrl = await SakhiPrototypeState.instance.uploadMediaToCloud(
        purpose: 'avatar',
        fileName: picked.name,
        fileBytes: bytes,
        contentType: contentType,
      );
      if (!mounted) return;
      if (uploadedUrl == null) {
        _message('Upload failed. Ensure Google Drive is connected in the backend, then retry.');
        return;
      }
      SakhiPrototypeState.instance.updateAvatar(uploadedUrl);
      _message('Profile photo uploaded to Google Drive and saved to PostgreSQL.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
