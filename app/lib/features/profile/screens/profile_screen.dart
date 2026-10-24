import '../../../core/widgets/sakhi_quote_loader.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_avatar.dart';
import '../../../core/widgets/sakhi_brand_header.dart';
import '../../../core/widgets/sakhi_buttons.dart';
import '../../../core/widgets/sakhi_chip.dart';
import '../../../core/widgets/sakhi_empty_state.dart';
import '../../../core/widgets/sakhi_remote_media_image.dart';
import '../../community/widgets/feed_post_card.dart';
import '../../explore/screens/explore_discovery_screens.dart';

/// Screens 05 & 06 — Populated User Profile & Profile Tabs Empty States
class ProfileScreen extends StatefulWidget {
  final ValueChanged<String>? onNavigateRoute;
  final ValueChanged<int>? onNavigateTab;
  final VoidCallback? onCreateTap;

  const ProfileScreen({
    super.key,
    this.onNavigateRoute,
    this.onNavigateTab,
    this.onCreateTap,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedTabIndex = 0; // 0: Posts, 1: Saved, 2: Groups
  bool _profilePhotoUploading = false;
  bool _loadingSavedPosts = false;
  bool _savedPostsLoaded = false;
  bool _savedPostsUnavailable = false;
  List<FeedPostModel> _savedPosts = const <FeedPostModel>[];
  final ImagePicker _imagePicker = ImagePicker();

  void _selectProfileTab(int index) {
    setState(() => _selectedTabIndex = index);
    if (index == 1 && !_savedPostsLoaded && !_loadingSavedPosts) {
      _loadSavedPosts();
    }
  }

  Future<void> _loadSavedPosts({bool retryConnection = false}) async {
    if (_loadingSavedPosts) return;
    final state = SakhiPrototypeState.instance;
    setState(() {
      _loadingSavedPosts = true;
      _savedPostsUnavailable = false;
    });

    if (!state.isBackendSynced && retryConnection) {
      await state.syncFromBackend();
    }
    if (!mounted) return;
    if (!state.isBackendSynced) {
      setState(() {
        _loadingSavedPosts = false;
        _savedPostsUnavailable = false;
        _savedPosts = const <FeedPostModel>[];
      });
      return;
    }

    final result = await state.fetchPosts(savedOnly: true, limit: 60);
    if (!mounted) return;
    setState(() {
      _loadingSavedPosts = false;
      _savedPostsLoaded = result != null;
      _savedPostsUnavailable = result == null;
      _savedPosts = (result ?? const <FeedPostModel>[])
          .map((post) {
            post.isSaved = true;
            return post;
          })
          .toList(growable: false);
    });
  }

  void _navigateTo(BuildContext context, String routeName) {
    if (widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(routeName);
    } else {
      Navigator.of(context).pushNamed(routeName);
    }
  }

  void _showProfilePhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Update Profile Photo',
                style: AppTypography.sectionTitle,
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndUploadProfilePhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndUploadProfilePhoto(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.face_retouching_natural_outlined),
                title: const Text('Use an Illustrated Sakhi Avatar'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _navigateTo(context, AppRoutes.editProfile);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('Use Default Avatar'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  SakhiPrototypeState.instance.updateAvatar(
                    AppAssets.allDefaultWomenAvatars.first,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Default profile avatar selected.'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadProfilePhoto(ImageSource source) async {
    if (_profilePhotoUploading) return;
    try {
      final file = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 86,
      );
      if (file == null || !mounted) return;

      final extension = file.name.toLowerCase().split('.').last;
      final contentType = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => null,
      };
      if (contentType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose a JPG, PNG, or WebP profile photo.'),
          ),
        );
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photos must be 8 MB or smaller.'),
          ),
        );
        return;
      }

      setState(() => _profilePhotoUploading = true);
      final result = await SakhiPrototypeState.instance.uploadMediaFile(
        purpose: 'avatar',
        fileName: file.name,
        fileBytes: bytes,
        contentType: contentType,
      );
      if (!mounted) return;
      if (result == null || (result['mediaUrl'] ?? '').isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The profile photo was not uploaded. Check your connection and retry.',
            ),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not access or upload that photo. Check app permissions and retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _profilePhotoUploading = false);
    }
  }

  void _showAvatarLightbox() {
    final source = SakhiPrototypeState.instance.currentUser.avatarAsset.trim();
    if (source.isEmpty) return;
    final isRemote =
        source.startsWith('http://') ||
        source.startsWith('https://') ||
        source.startsWith('/api/v1/');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.cardSurface,
        insetPadding: const EdgeInsets.all(18),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: isRemote
                  ? SakhiRemoteMediaImage(
                      source: source,
                      fit: BoxFit.contain,
                      width: MediaQuery.sizeOf(dialogContext).width - 56,
                      height: MediaQuery.sizeOf(dialogContext).height * 0.66,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 240,
                        child: Center(
                          child: Text('Profile photo is unavailable.'),
                        ),
                      ),
                    )
                  : Image.asset(
                      AppAssets.forKey(source),
                      fit: BoxFit.contain,
                      width: MediaQuery.sizeOf(dialogContext).width - 56,
                      height: MediaQuery.sizeOf(dialogContext).height * 0.66,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 240,
                        child: Center(
                          child: Text('Profile photo is unavailable.'),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLocationVisibilityPicker(
    BuildContext context,
    SakhiPrototypeState state,
  ) async {
    final current = state.privacySettings.firstWhere(
      (setting) => setting.id == 'show_location',
    );
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD3BFE0),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Location Visibility',
                style: AppTypography.sectionTitle,
              ),
              const SizedBox(height: 5),
              const Text(
                'Sakhi only shares a general city label, never your live GPS location.',
                textAlign: TextAlign.center,
                style: AppTypography.subtitle,
              ),
              const SizedBox(height: 12),
              ...current.options.map((option) {
                final isSelected = current.selectedValue == option;
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  tileColor: isSelected
                      ? AppColors.pastelLavender
                      : Colors.transparent,
                  leading: Icon(
                    option == 'Hide Location'
                        ? Icons.location_off_outlined
                        : option == 'Followers Only'
                        ? Icons.people_alt_outlined
                        : Icons.verified_user_outlined,
                    color: AppColors.primaryPurple,
                  ),
                  title: Text(option, style: AppTypography.bodyMedium),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primaryPurple,
                        )
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(option),
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    if (selected == current.selectedValue) return;
    final saved = await state.updatePrivacySetting('show_location', selected);
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved ? 'Location visibility updated.' : 'Location visibility could not be saved. Your previous setting was kept.',
        ),
      ),
    );
  }

  Future<void> _shareProfile() async {
    final user = SakhiPrototypeState.instance.currentUser;
    final handle = user.username.isEmpty ? '@sakhi_member' : user.username;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'Connect with me on Sakhi, a community for women. My handle is $handle.',
          subject: 'My Sakhi profile',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await Clipboard.setData(
        ClipboardData(text: 'Connect with me on Sakhi. My handle is $handle.'),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profile handle copied because the share sheet was unavailable.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final user = state.currentUser;
        final locationVisibility = state.privacySettings
            .firstWhere((setting) => setting.id == 'show_location')
            .selectedValue;
        final bioText = user.bio.trim().isNotEmpty
            ? user.bio.trim()
            : 'Mental wellness advocate, peer counselor & community builder 🌸 Helping women thrive together. 💜';
        final cityText = user.location.trim().isNotEmpty
            ? user.location.trim()
            : 'Bangalore, India';
        final interestsList = user.interests.isNotEmpty
            ? user.interests
            : const <String>[
                'Mental Wellness',
                'Travel',
                'Reading',
                'WomenInTech',
                'Art',
              ];

        return SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SakhiBrandHeader(
                  title: 'Profile',
                  useShieldEmblem: true,
                  actions: [
                    IconButton(
                      tooltip: 'Privacy & Account Settings',
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: AppColors.primaryPurple,
                        size: 24,
                      ),
                      onPressed: () =>
                          _navigateTo(context, AppRoutes.privacySettings),
                    ),
                  ],
                ),

                if (_profilePhotoUploading)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPaddingH,
                    ),
                    child: LinearProgressIndicator(
                      color: AppColors.primaryPurple,
                      minHeight: 3,
                    ),
                  ),

                // Compact Floral Banner + Overlapping Avatar + Right Share Icon Button (Reference 05)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH,
                  ),
                  child: SizedBox(
                    height: 152,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: SizedBox(
                            height: 104,
                            width: double.infinity,
                            child: Image.asset(
                              AppAssets.profileHeaderBanner,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, _, _) =>
                                  Container(color: AppColors.pastelPink),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 42,
                          child: SakhiAvatar(
                            imageAsset: user.avatarAsset,
                            fallbackLabel: user.displayName,
                            size: 104,
                            borderWidth: 3.5,
                            showEditCameraBadge: true,
                            onAvatarTap: _showAvatarLightbox,
                            onCameraTap: _showProfilePhotoOptions,
                          ),
                        ),
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Material(
                            color: AppColors.pastelLavender,
                            shape: const CircleBorder(
                              side: BorderSide(color: AppColors.borderSubtle),
                            ),
                            child: IconButton(
                              tooltip: 'Share Profile',
                              constraints: const BoxConstraints.tightFor(
                                width: 38,
                                height: 38,
                              ),
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.share_outlined,
                                size: 18,
                                color: AppColors.primaryPurple,
                              ),
                              onPressed: _shareProfile,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              user.displayName,
                              textAlign: TextAlign.center,
                              style: AppTypography.appBarTitle.copyWith(
                                fontSize: 21,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.verified_rounded,
                            color: AppColors.primaryPurple,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.username.isEmpty ? '@ananya_rao' : user.username,
                        style: AppTypography.subtitle,
                      ),
                      const SizedBox(height: 10),
                      SakhiPillButton(
                        label: 'Edit Profile',
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 9,
                        ),
                        onPressed: () =>
                            _navigateTo(context, AppRoutes.editProfile),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                // Posts | Followers | Following Card (Reference 05)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderSubtle),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryPurple.withValues(
                            alpha: 0.04,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ProfileStatColumn(
                          count: '${user.postsCount}',
                          label: 'Posts',
                          onTap: () => _selectProfileTab(0),
                        ),
                        Container(
                          height: 28,
                          width: 1,
                          color: AppColors.dividerColor,
                        ),
                        _ProfileStatColumn(
                          count: '${user.followersCount}',
                          label: 'Followers',
                          onTap: () =>
                              _navigateTo(context, AppRoutes.followers),
                        ),
                        Container(
                          height: 28,
                          width: 1,
                          color: AppColors.dividerColor,
                        ),
                        _ProfileStatColumn(
                          count: '${user.followingCount}',
                          label: 'Following',
                          onTap: () =>
                              _navigateTo(context, AppRoutes.following),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),
                // Bio, Location + Lock Privacy Pill, and Interest Chips
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bioText, style: AppTypography.bodyRegular),
                      if (locationVisibility != 'Hide Location') ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 17,
                              color: AppColors.primaryPurple,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                cityText,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              borderRadius: BorderRadius.circular(99),
                              onTap: () =>
                                  _showLocationVisibilityPicker(context, state),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.pastelLavender,
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: AppColors.borderSubtle,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.lock_outline_rounded,
                                      size: 13,
                                      color: AppColors.primaryPurple,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      locationVisibility,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryPurple,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...interestsList.map(
                            (interest) => SakhiChip(
                              label: interest,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => SearchResultsScreen(
                                    initialQuery: '#$interest',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SakhiChip(
                            label: '+ Add',
                            isOutlinedAction: true,
                            onTap: () =>
                                _navigateTo(context, AppRoutes.editProfile),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                // 3-Tab Bar: Posts | Saved | Groups (Reference 05 & 06)
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.dividerColor),
                    ),
                  ),
                  child: Row(
                    children: [
                      _ProfileTabButton(
                        icon: Icons.grid_on_rounded,
                        label: 'Posts',
                        isSelected: _selectedTabIndex == 0,
                        onTap: () => _selectProfileTab(0),
                      ),
                      _ProfileTabButton(
                        icon: Icons.bookmark_border_rounded,
                        label: 'Saved',
                        isSelected: _selectedTabIndex == 1,
                        onTap: () => _selectProfileTab(1),
                      ),
                      _ProfileTabButton(
                        icon: Icons.groups_outlined,
                        label: 'Groups',
                        isSelected: _selectedTabIndex == 2,
                        onTap: () => _selectProfileTab(2),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH,
                  ),
                  child: _buildTabContent(context, state),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabContent(BuildContext context, SakhiPrototypeState state) {
    if (_selectedTabIndex == 0) {
      final ownPosts = state.profilePosts
          .where(
            (post) =>
                post.id.isNotEmpty &&
                post.authorAccountId == state.currentUser.accountId,
          )
          .toList(growable: false);
      if (ownPosts.isEmpty) {
        return SakhiEmptyState(
          icon: Icons.grid_on_outlined,
          illustrationAsset: AppAssets.emptyPostsIllustration,
          title: 'No Posts Yet',
          message: 'Share your first photo, thought, or question with the Sakhi community.',
          actionLabel: '+ Create First Post',
          onAction:
              widget.onCreateTap ??
              () => _navigateTo(context, AppRoutes.community),
        );
      }
      return _buildPostGrid(context, state, ownPosts, isSavedGrid: false);
    } else if (_selectedTabIndex == 1) {
      if (_loadingSavedPosts) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: SakhiQuoteLoader.inline(
            statusLabel: 'Loading your saved posts…',
          ),
        );
      }
      if (_savedPostsUnavailable) {
        return SakhiEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Saved posts could not be loaded',
          message: 'Sakhi could not retrieve your saved posts. They have not been cleared.',
          actionLabel: 'Retry',
          onAction: () => _loadSavedPosts(retryConnection: true),
        );
      }
      final saved = _savedPosts
          .where((post) => post.isSaved)
          .toList(growable: false);
      if (saved.isEmpty) {
        return SakhiEmptyState(
          icon: Icons.bookmark_border_rounded,
          illustrationAsset: AppAssets.emptySavedIllustration,
          title: 'No Saved Posts',
          message: 'Bookmark inspiring stories, safety guides, and wellness tips to revisit anytime.',
          actionLabel: 'Explore Community',
          onAction: widget.onNavigateTab != null
              ? () => widget.onNavigateTab!(2)
              : () => _navigateTo(context, AppRoutes.community),
        );
      }
      return _buildPostGrid(context, state, saved, isSavedGrid: true);
    } else {
      return SakhiEmptyState(
        icon: Icons.groups_outlined,
        illustrationAsset: AppAssets.emptyGroupsIllustration,
        title: 'Not in Any Groups Yet',
        message: 'Join circles that match your career, wellness, and local community interests.',
        actionLabel: 'Browse Circles',
        onAction: widget.onNavigateTab != null
            ? () => widget.onNavigateTab!(1)
            : () => _navigateTo(context, AppRoutes.explore),
      );
    }
  }

  Widget _buildPostGrid(
    BuildContext context,
    SakhiPrototypeState state,
    List<FeedPostModel> posts, {
    required bool isSavedGrid,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 4 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: posts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final post = posts[index];
            final source = post.imageAsset?.trim() ?? '';
            final isVideo = (post.mediaContentType ?? '').contains('video');
            Widget thumbnail;
            if (source.isEmpty) {
              thumbnail = Container(
                color: AppColors.pastelLavender,
                alignment: Alignment.center,
                child: Icon(
                  isSavedGrid ? Icons.bookmark_rounded : Icons.notes_rounded,
                  color: AppColors.primaryPurple,
                  size: 30,
                ),
              );
            } else if (source.startsWith('http://') ||
                source.startsWith('https://') ||
                source.startsWith('/api/v1/')) {
              thumbnail = SakhiRemoteMediaImage(source: source);
            } else {
              thumbnail = Image.asset(
                source,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.pastelPink,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              );
            }
            return Semantics(
              button: true,
              label: 'Open post by ${post.authorName}',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => Dialog(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(8),
                      child: FeedPostCard(
                        post: post,
                        showVerifiedCheck: true,
                        onLikeTap: () => state.togglePostLike(post),
                        onSaveTap: () => state.togglePostSaved(post),
                      ),
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      thumbnail,
                      if (isVideo)
                        Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      if (source.isNotEmpty)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                isSavedGrid
                                    ? Icons.bookmark_rounded
                                    : Icons.collections_outlined,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ProfileStatColumn extends StatelessWidget {
  final String count;
  final String label;
  final VoidCallback onTap;

  const _ProfileStatColumn({
    required this.count,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            Text(
              count,
              style: AppTypography.sectionTitle.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 2),
            Text(label, style: AppTypography.subtitle),
          ],
        ),
      ),
    );
  }
}

class _ProfileTabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProfileTabButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primaryPurple : AppColors.textMuted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? AppColors.primaryPurple
                    : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: color,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
