import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_avatar.dart';
import '../../../core/widgets/sakhi_buttons.dart';
import '../../../core/widgets/sakhi_chip.dart';
import '../../../core/widgets/sakhi_dialogs.dart';
import '../../../core/widgets/sakhi_search_field.dart';
import '../widgets/feed_post_card.dart';

/// Screen 3 — Module 3 Social Media Wall & Community Feed
/// Implements the 6 SRS 5.3 categories (Following, Community, Trending,
/// Business Updates, Safety Awareness, Wellness and Lifestyle) and the
/// Instagram-style post composer with interactive cropping (1:1, 4:5, 16:9),
/// live preview, hashtags, visibility controls, and private Google Drive upload.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String _selectedCategorySlug = 'community';
  bool _showSearch = false;
  bool _showComposer = false;
  bool _isUploadingCloudMedia = false;
  bool _isRefreshing = false;
  String _composerCategorySlug = 'community';
  String _selectedVisibility = 'VERIFIED_MEMBERS';
  String _selectedCropPreset = '4:5';
  Uint8List? _selectedImageOriginalBytes;
  Uint8List? _selectedImageCroppedBytes;
  String? _selectedImageName;
  String? _attachedEditorialAsset;
  final Set<String> _selectedHashtags = {'#SakhiSisterhood'};
  bool _allowComments = true;
  bool _shareToBusinessProfile = false;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _postController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  static const Map<String, String> _categoryLabels = {
    'following': 'Following',
    'community': 'Community',
    'trending': 'Trending',
    'business_updates': 'Business Updates',
    'safety_awareness': 'Safety Awareness',
    'wellness_lifestyle': 'Wellness and Lifestyle',
  };

  @override
  void dispose() {
    _searchController.dispose();
    _postController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  double _aspectRatioForPreset(String preset) {
    switch (preset) {
      case '1:1':
        return 1.0;
      case '16:9':
        return 16 / 9;
      case '4:5':
      default:
        return 4 / 5;
    }
  }

  Future<Uint8List> _cropBytesToAspectRatio(
    Uint8List rawBytes,
    String preset,
  ) async {
    try {
      final codec = await ui.instantiateImageCodec(rawBytes);
      final frame = await codec.getNextFrame();
      final src = frame.image;
      final targetRatio = _aspectRatioForPreset(preset);
      final srcRatio = src.width / src.height;

      double cropW;
      double cropH;
      if (srcRatio > targetRatio) {
        cropH = src.height.toDouble();
        cropW = cropH * targetRatio;
      } else {
        cropW = src.width.toDouble();
        cropH = cropW / targetRatio;
      }
      final offsetX = (src.width - cropW) / 2.0;
      final offsetY = (src.height - cropH) / 2.0;

      const outW = 960;
      final outH = (outW / targetRatio).round();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        src,
        Rect.fromLTWH(offsetX, offsetY, cropW, cropH),
        Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(outW, outH);
      final byteData =
          await cropped.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (_) {}
    return rawBytes;
  }

  Future<void> _refreshLiveFeed() async {
    setState(() => _isRefreshing = true);
    await SakhiPrototypeState.instance.syncFromBackend();
    if (!mounted) return;
    setState(() => _isRefreshing = false);
    SakhiDialogs.showPrototypeSnackbar(
      context,
      'Synced live posts and categories from PostgreSQL database!',
    );
  }

  Future<void> _pickAndCropGalleryImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
        SakhiDialogs.showPrototypeSnackbar(
          context,
          'Choose a JPG, PNG, or WebP image under 8 MB.',
        );
        return;
      }
      final cropped = await _cropBytesToAspectRatio(bytes, _selectedCropPreset);
      if (!mounted) return;
      setState(() {
        _selectedImageOriginalBytes = bytes;
        _selectedImageCroppedBytes = cropped;
        _selectedImageName = picked.name.isEmpty ? 'post_photo.png' : picked.name;
        _attachedEditorialAsset = null;
      });
    } catch (_) {
      if (!mounted) return;
      SakhiDialogs.showPrototypeSnackbar(
        context,
        'Unable to read the selected image. Please try another photo.',
      );
    }
  }

  Future<void> _changeCropPreset(String preset) async {
    setState(() => _selectedCropPreset = preset);
    if (_selectedImageOriginalBytes != null) {
      final recropped = await _cropBytesToAspectRatio(
        _selectedImageOriginalBytes!,
        preset,
      );
      if (!mounted) return;
      setState(() => _selectedImageCroppedBytes = recropped);
    }
  }

  Future<void> _publishPost() async {
    if (_isUploadingCloudMedia) return;
    final text = _postController.text.trim();
    if (text.isEmpty &&
        _selectedImageCroppedBytes == null &&
        _attachedEditorialAsset == null) {
      SakhiDialogs.showPrototypeSnackbar(
        context,
        'Write a caption or select a photo before publishing.',
      );
      return;
    }

    setState(() => _isUploadingCloudMedia = true);
    String? uploadedMediaUrl = _attachedEditorialAsset;
    final mediaUploadIds = <String>[];

    try {
      if (_selectedImageCroppedBytes != null) {
        final uploadRes = await SakhiPrototypeState.instance.uploadMediaFile(
          purpose: 'community_post',
          fileName: _selectedImageName ?? 'community_post.png',
          fileBytes: _selectedImageCroppedBytes!,
          contentType: 'image/png',
          categorySlug: _composerCategorySlug,
          cropAspectRatio: _selectedCropPreset,
        );
        if (!mounted) return;
        if (uploadRes == null) {
          setState(() => _isUploadingCloudMedia = false);
          SakhiDialogs.showPrototypeSnackbar(
            context,
            'Photo upload failed—your draft was kept so you can retry safely.',
          );
          return;
        }
        uploadedMediaUrl = uploadRes['mediaUrl'];
        if (uploadRes['uploadId'] != null && uploadRes['uploadId']!.isNotEmpty) {
          mediaUploadIds.add(uploadRes['uploadId']!);
        }
      }

      final ok = await SakhiPrototypeState.instance.createCommunityPost(
        text,
        categoryBadge: _categoryLabels[_composerCategorySlug] ?? 'Community',
        categorySlug: _composerCategorySlug,
        visibility: _selectedVisibility,
        cropPreset: _selectedCropPreset,
        hashtags: _selectedHashtags.toList(),
        locationTag: _locationController.text.trim(),
        allowComments: _allowComments,
        shareToBusinessProfile: _shareToBusinessProfile,
        imageAsset: uploadedMediaUrl,
        mediaUploadIds: mediaUploadIds,
      );
      if (!mounted) return;
      setState(() => _isUploadingCloudMedia = false);
      if (!ok) {
        SakhiDialogs.showPrototypeSnackbar(
          context,
          'Post could not be published. Check your backend connection.',
        );
        return;
      }

      _postController.clear();
      _locationController.clear();
      setState(() {
        _selectedImageOriginalBytes = null;
        _selectedImageCroppedBytes = null;
        _selectedImageName = null;
        _attachedEditorialAsset = null;
        _showComposer = false;
      });
      SakhiDialogs.showPrototypeSnackbar(
        context,
        'Post published to the Sakhi Social Wall!',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUploadingCloudMedia = false);
      SakhiDialogs.showPrototypeSnackbar(
        context,
        'Publication failed. Your draft is still open so you can retry.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final query = _searchController.text.trim().toLowerCase();
        final followNames = state.following.map((f) => f.name).toSet();

        var posts = state.communityPosts.where((p) {
          if (_selectedCategorySlug == 'following') {
            if (!p.isOwnPost && !followNames.contains(p.authorName)) {
              return false;
            }
          } else if (_selectedCategorySlug != 'trending' &&
              _selectedCategorySlug != 'community') {
            if (p.categorySlug != _selectedCategorySlug) {
              return false;
            }
          }
          if (query.isEmpty) return true;
          return p.authorName.toLowerCase().contains(query) ||
              p.content.toLowerCase().contains(query) ||
              p.hashtags.any((h) => h.toLowerCase().contains(query)) ||
              (p.categoryBadge?.toLowerCase().contains(query) ?? false);
        }).toList();

        if (_selectedCategorySlug == 'trending') {
          posts = List<FeedPostModel>.from(posts)
            ..sort(
              (a, b) => (b.likesCount + b.commentsCount * 2 + b.savesCount)
                  .compareTo(a.likesCount + a.commentsCount * 2 + a.savesCount),
            );
        }

        return SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPaddingH,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _showFeedFilterSheet(context),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Social Wall', style: AppTypography.appBarTitle),
                            SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textPrimary,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Refresh Live PostgreSQL Feed',
                        icon: _isRefreshing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryPurple,
                                ),
                              )
                            : const Icon(
                                Icons.sync_rounded,
                                color: AppColors.primaryPurple,
                                size: 22,
                              ),
                        onPressed: _isRefreshing ? null : _refreshLiveFeed,
                      ),
                      IconButton(
                        tooltip: 'Search Social Wall',
                        icon: Icon(
                          _showSearch
                              ? Icons.close_rounded
                              : Icons.search_rounded,
                          color: AppColors.primaryPurple,
                          size: 24,
                        ),
                        onPressed: () {
                          setState(() {
                            _showSearch = !_showSearch;
                            if (!_showSearch) _searchController.clear();
                          });
                        },
                      ),
                    ],
                  ),

                  // SRS 5.3 Six Feed Categories Strip
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: state.feedCategories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = state.feedCategories[index];
                        final selected = _selectedCategorySlug == cat.slug;
                        return SakhiChip(
                          label: cat.name,
                          isSelected: selected,
                          onTap: () {
                            setState(() => _selectedCategorySlug = cat.slug);
                            state.loadFeed(categorySlug: cat.slug);
                          },
                        );
                      },
                    ),
                  ),

                  // Instagram-Style Post Composer Card
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SakhiAvatar(
                              imageAsset: state.currentUser.avatarAsset,
                              fallbackLabel: state.currentUser.displayName,
                              size: 40,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => _showComposer = !_showComposer,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.scaffoldBackground,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Create a post or crop & share a photo, ${state.currentUser.displayName}...',
                                    style: AppTypography.subtitle.copyWith(
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Open Post Composer',
                              icon: Icon(
                                _showComposer
                                    ? Icons.expand_less_rounded
                                    : Icons.add_photo_alternate_outlined,
                                color: AppColors.primaryPurple,
                              ),
                              onPressed: () => setState(
                                () => _showComposer = !_showComposer,
                              ),
                            ),
                          ],
                        ),
                        if (_showComposer) ...[
                          const SizedBox(height: 12),
                          // Aspect Ratio & Photo Selection Bar
                          Row(
                            children: [
                              const Text(
                                'Crop Preset:',
                                style: AppTypography.bodyMedium,
                              ),
                              const SizedBox(width: 8),
                              for (final preset in const ['1:1', '4:5', '16:9'])
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(
                                      preset,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: _selectedCropPreset == preset
                                            ? Colors.white
                                            : AppColors.primaryPurple,
                                      ),
                                    ),
                                    selected: _selectedCropPreset == preset,
                                    selectedColor: AppColors.primaryPurple,
                                    backgroundColor: AppColors.pastelLavender,
                                    onSelected: (_) => _changeCropPreset(preset),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_selectedImageCroppedBytes != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: AspectRatio(
                                aspectRatio:
                                    _aspectRatioForPreset(_selectedCropPreset),
                                child: InteractiveViewer(
                                  minScale: 1.0,
                                  maxScale: 3.0,
                                  child: Image.memory(
                                    _selectedImageCroppedBytes!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => setState(() {
                                  _selectedImageOriginalBytes = null;
                                  _selectedImageCroppedBytes = null;
                                  _selectedImageName = null;
                                }),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: AppColors.sosRed,
                                ),
                                label: const Text(
                                  'Remove selected photo',
                                  style: TextStyle(color: AppColors.sosRed),
                                ),
                              ),
                            ),
                          ] else if (_attachedEditorialAsset != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: AspectRatio(
                                aspectRatio:
                                    _aspectRatioForPreset(_selectedCropPreset),
                                child: Image.asset(
                                  _attachedEditorialAsset!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => setState(
                                  () => _attachedEditorialAsset = null,
                                ),
                                child: const Text('Clear illustration'),
                              ),
                            ),
                          ],
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.photo_library_outlined,
                                  size: 17,
                                ),
                                label: const Text('Gallery Photo'),
                                onPressed: _isUploadingCloudMedia
                                    ? null
                                    : () => _pickAndCropGalleryImage(
                                          ImageSource.gallery,
                                        ),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.photo_camera_outlined,
                                  size: 17,
                                ),
                                label: const Text('Camera'),
                                onPressed: _isUploadingCloudMedia
                                    ? null
                                    : () => _pickAndCropGalleryImage(
                                          ImageSource.camera,
                                        ),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.auto_awesome_outlined,
                                  size: 17,
                                ),
                                label: const Text('Editorial Artwork'),
                                onPressed: () => setState(() {
                                  _attachedEditorialAsset =
                                      AppAssets.communityCircleGathering;
                                  _selectedImageOriginalBytes = null;
                                  _selectedImageCroppedBytes = null;
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _postController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText:
                                  'Write your caption and #hashtags (saved to PostgreSQL)...',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: state.trendingHashtags.map((tag) {
                              final selected = _selectedHashtags.contains(tag);
                              return SakhiChip(
                                label: tag,
                                isSelected: selected,
                                onTap: () => setState(() {
                                  if (selected) {
                                    _selectedHashtags.remove(tag);
                                  } else {
                                    _selectedHashtags.add(tag);
                                  }
                                }),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _composerCategorySlug,
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                    isDense: true,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'community',
                                      child: Text('Community'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'business_updates',
                                      child: Text('Business Updates'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'safety_awareness',
                                      child: Text('Safety Awareness'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'wellness_lifestyle',
                                      child: Text('Wellness & Lifestyle'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _composerCategorySlug = v);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedVisibility,
                                  decoration: const InputDecoration(
                                    labelText: 'Visibility',
                                    isDense: true,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'VERIFIED_MEMBERS',
                                      child: Text('Verified Members'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'FOLLOWERS_ONLY',
                                      child: Text('Followers Only'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'PRIVATE_SELF',
                                      child: Text('Only Me'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _selectedVisibility = v);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _locationController,
                            decoration: const InputDecoration(
                              labelText: 'Location tag (optional)',
                              hintText: 'e.g., Jubilee Hills, Hyderabad',
                              prefixIcon: Icon(
                                Icons.location_on_outlined,
                                size: 18,
                              ),
                              isDense: true,
                            ),
                          ),
                          SwitchListTile.adaptive(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: _allowComments,
                            activeColor: AppColors.primaryPurple,
                            title: const Text(
                              'Allow member comments',
                              style: AppTypography.bodyMedium,
                            ),
                            onChanged: (v) =>
                                setState(() => _allowComments = v),
                          ),
                          SwitchListTile.adaptive(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: _shareToBusinessProfile,
                            activeColor: AppColors.primaryPurple,
                            title: const Text(
                              'Feature on my Women-Owned Business profile',
                              style: AppTypography.bodyMedium,
                            ),
                            onChanged: (v) =>
                                setState(() => _shareToBusinessProfile = v),
                          ),
                          if (_isUploadingCloudMedia) ...[
                            const SizedBox(height: 8),
                            const LinearProgressIndicator(
                              color: AppColors.primaryPurple,
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _isUploadingCloudMedia
                                    ? null
                                    : () => setState(() => _showComposer = false),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              SakhiPillButton(
                                label: _isUploadingCloudMedia
                                    ? 'Publishing...'
                                    : 'Publish to Social Wall',
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 9,
                                ),
                                onPressed:
                                    _isUploadingCloudMedia ? null : _publishPost,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (_showSearch) ...[
                    const SizedBox(height: 10),
                    SakhiSearchField(
                      hintText: 'Search posts, #hashtags, or @members...',
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      onClear: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    ),
                  ],

                  const SizedBox(height: 12),
                  if (posts.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.auto_awesome_outlined,
                            color: AppColors.primaryPurple,
                            size: 36,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'No posts in this category yet',
                            style: AppTypography.sectionTitle,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Share the first story or photo in this category!',
                            style: AppTypography.subtitle,
                          ),
                          const SizedBox(height: 12),
                          SakhiPillButton(
                            label: 'Create Post',
                            onPressed: () =>
                                setState(() => _showComposer = true),
                          ),
                        ],
                      ),
                    )
                  else
                    ...posts.map(
                      (post) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: FeedPostCard(
                          post: post,
                          onLikeTap: () => state.togglePostLike(post),
                          onSaveTap: () {
                            state.togglePostSaved(post);
                            SakhiDialogs.showPrototypeSnackbar(
                              context,
                              post.isSaved
                                  ? 'Saved post to PostgreSQL'
                                  : 'Removed from Saved Posts',
                            );
                          },
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
  }

  void _showFeedFilterSheet(BuildContext context) {
    final categories = SakhiPrototypeState.instance.feedCategories;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Social Wall Category',
                style: AppTypography.sectionTitle,
              ),
              const SizedBox(height: 8),
              ...categories.map(
                (cat) => ListTile(
                  title: Text(cat.name),
                  subtitle: Text(cat.description, style: AppTypography.subtitle),
                  trailing: _selectedCategorySlug == cat.slug
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primaryPurple,
                        )
                      : null,
                  onTap: () {
                    setState(() => _selectedCategorySlug = cat.slug);
                    SakhiPrototypeState.instance.loadFeed(
                      categorySlug: cat.slug,
                    );
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
