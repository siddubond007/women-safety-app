import 'package:flutter/material.dart';

import '../../core/theme/sakhi_design_system.dart';
import 'profile_service.dart';

class SakhiMyProfileScreen extends StatefulWidget {
  const SakhiMyProfileScreen({
    super.key,
    ProfileService? profileService,
  }) : profileService = profileService ?? const _MissingProfileService();

  final ProfileService profileService;

  @override
  State<SakhiMyProfileScreen> createState() => _SakhiMyProfileScreenState();
}

class _SakhiMyProfileScreenState extends State<SakhiMyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  String? _saveError;
  String? _saveSuccess;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final profile = await widget.profileService.getMyProfile();
      if (!mounted) return;
      _populate(profile);
      setState(() {
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = _friendlyMessage(error);
      });
    }
  }

  void _populate(SakhiMemberProfile profile) {
    _nameController.text = profile.displayName;
    _emailController.text = profile.email ?? '';
    _bioController.text = profile.bio ?? '';
    _cityController.text = profile.city ?? '';
  }

  String _friendlyMessage(Object error) {
    if (error is ProfileServiceException) return error.message;
    return 'Your profile could not be loaded. Check the connection and try again.';
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Enter your display name.';
    if (name.length > 100) return 'Your display name must be 100 characters or fewer.';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    if (!valid) return 'Enter a valid email address.';
    if (email.length > 254) return 'Email must be 254 characters or fewer.';
    return null;
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false) || _isSaving) return;

    setState(() {
      _isSaving = true;
      _saveError = null;
      _saveSuccess = null;
    });

    try {
      final profile = await widget.profileService.updateMyProfile(
        displayName: _nameController.text.trim(),
        email: _emailController.text,
        bio: _bioController.text,
        city: _cityController.text,
      );
      if (!mounted) return;
      _populate(profile);
      setState(() {
        _isSaving = false;
        _saveSuccess = 'Profile changes saved.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = _friendlyMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SakhiColors.blush,
      appBar: AppBar(
        title: const Text('My profile'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  key: Key('profile-loading-indicator'),
                  color: SakhiColors.purple,
                ),
              )
            : _loadError != null
            ? _buildLoadError()
            : _buildProfileForm(),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_off_outlined,
                size: 48,
                color: SakhiColors.purple,
              ),
              const SizedBox(height: 16),
              const Text(
                'Your profile is unavailable',
                textAlign: TextAlign.center,
                style: SakhiTypography.onboardingTitle,
              ),
              const SizedBox(height: 10),
              Text(
                _loadError!,
                key: const Key('profile-load-error'),
                textAlign: TextAlign.center,
                style: SakhiTypography.body,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('profile-retry-button'),
                onPressed: () => _loadProfile(showLoading: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileForm() {
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: SakhiColors.lavender.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          color: SakhiColors.purple,
                          size: 34,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Sakhi profile',
                              style: SakhiTypography.onboardingTitle.copyWith(fontSize: 18),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Profile photo upload will be added in a later step.',
                              style: SakhiTypography.body.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Personal details',
                  style: SakhiTypography.onboardingTitle.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Keep your profile details up to date. Only edit information you are comfortable sharing.',
                  style: SakhiTypography.body,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const Key('profile-name-field'),
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 100,
                  validator: _validateName,
                  decoration: _decoration(
                    label: 'Display name',
                    hint: 'Enter your name',
                  ).copyWith(counterText: ''),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('profile-email-field'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  decoration: _decoration(
                    label: 'Email (optional)',
                    hint: 'you@example.com',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('profile-bio-field'),
                  controller: _bioController,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoration(
                    label: 'Short bio (optional)',
                    hint: 'A few words about yourself',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('profile-city-field'),
                  controller: _cityController,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 100,
                  decoration: _decoration(
                    label: 'City or general area (optional)',
                    hint: 'Your city',
                    helper: 'Use a general area only — never enter a live address.',
                  ).copyWith(counterText: ''),
                ),
                const SizedBox(height: 18),
                if (_saveError != null) ...[
                  _message(
                    _saveError!,
                    key: const Key('profile-save-error'),
                    color: const Color(0xFFB42318),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_saveSuccess != null) ...[
                  _message(
                    _saveSuccess!,
                    key: const Key('profile-save-success'),
                    color: const Color(0xFF237A57),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  key: const Key('profile-save-button'),
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_isSaving ? 'Saving…' : 'Save changes'),
                ),
                const SizedBox(height: 10),
                Text(
                  'This screen edits your own profile only. Privacy settings for profile visibility, messaging and search will be introduced separately.',
                  textAlign: TextAlign.center,
                  style: SakhiTypography.body.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required String hint,
    String? helper,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE9DDED)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: SakhiColors.purple, width: 1.5),
      ),
    );
  }

  Widget _message(
    String message, {
    required Key key,
    required Color color,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: SakhiTypography.body.copyWith(color: color)),
    );
  }
}

/// Prevents accidental use of this screen without explicitly wiring a backend
/// profile service. The normal navigation path supplies one.
class _MissingProfileService implements ProfileService {
  const _MissingProfileService();

  @override
  Future<SakhiMemberProfile> getMyProfile() async {
    throw const ProfileServiceException(
      'Profile service is not configured for this build.',
    );
  }

  @override
  Future<SakhiMemberProfile> updateMyProfile({
    required String displayName,
    required String? email,
    required String? bio,
    required String? city,
  }) async {
    throw const ProfileServiceException(
      'Profile service is not configured for this build.',
    );
  }
}
