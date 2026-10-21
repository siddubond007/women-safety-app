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
  final String? initialComposerMode;
  final int createIntent;

  const CommunityScreen({
    super.key,
    this.initialComposerMode,
    this.createIntent = 0,
  });

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String _selectedCategorySlug = 'community';
  bool _showSearch = false;
  bool _showComposer = false;
  String _composerMode = 'media';
  int _composerStep = 0;
  bool _isUploadingCloudMedia = false;
  bool _isRefreshing = false;
  String _composerCategorySlug = 'community';
  String _selectedVisibility = 'VERIFIED_MEMBERS';
  String _selectedCropPreset = '4:5';
  double _cropZoom = 1.0;
  double _cropOffsetX = 0.0;
  double _cropOffsetY = 0.0;
  Uint8List? _selectedImageOriginalBytes;
  Uint8List? _selectedImageCroppedBytes;
  String? _selectedImageName;
  String? _attachedEditorialAsset;
  final Set<String> _selectedHashtags = <String>{};
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
  void initState() {
    super.initState();
    final mode = widget.initialComposerMode;
    if (mode != null) _prepareComposer(mode);
  }

  @override
  void didUpdateWidget(covariant CommunityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.createIntent != oldWidget.createIntent &&
        widget.initialComposerMode != null) {
      setState(() => _prepareComposer(widget.initialComposerMode!));
    }
  }

  void _prepareComposer(String mode) {
    _composerMode = mode;
    _composerStep = mode == 'media' ? 0 : 1;
    _composerCategorySlug = mode == 'resource'
        ? 'wellness_lifestyle'
        : 'community';
    _showComposer = true;
  }

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
    String preset, {
    double zoom = 1.0,
    double offsetX = 0.0,
    double offsetY = 0.0,
  }) async {
    final codec = await ui.instantiateImageCodec(rawBytes);
    try {
      final frame = await codec.getNextFrame();
      final src = frame.image;
      try {
        final targetRatio = _aspectRatioForPreset(preset);
        final srcRatio = src.width / src.height;

        double baseW;
        double baseH;
        if (srcRatio > targetRatio) {
          baseH = src.height.toDouble();
          baseW = baseH * targetRatio;
        } else {
          baseW = src.width.toDouble();
          baseH = baseW / targetRatio;
        }

        final safeZoom = zoom.clamp(1.0, 3.0);
        final cropW = baseW / safeZoom;
        final cropH = baseH / safeZoom;
        final maxLeft = (src.width - cropW).clamp(0.0, src.width.toDouble());
        final maxTop = (src.height - cropH).clamp(0.0, src.height.toDouble());
        final left = (maxLeft / 2 + offsetX.clamp(-1.0, 1.0) * maxLeft / 2)
            .clamp(0.0, maxLeft);
        final top = (maxTop / 2 + offsetY.clamp(-1.0, 1.0) * maxTop / 2).clamp(
          0.0,
          maxTop,
        );

        const outW = 960;
        final outH = (outW / targetRatio).round();
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawImageRect(
          src,
          Rect.fromLTWH(left, top, cropW, cropH),
          Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
          Paint()..filterQuality = FilterQuality.high,
        );
        final picture = recorder.endRecording();
        final cropped = await picture.toImage(outW, outH);
        try {
          final byteData = await cropped.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (byteData == null) {
            throw StateError('Unable to encode the selected crop.');
          }
          return byteData.buffer.asUint8List();
        } finally {
          cropped.dispose();
          picture.dispose();
        }
      } finally {
        src.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  Future<void> _applyCropSettings() async {
    final original = _selectedImageOriginalBytes;
    if (original == null) return;
    try {
      final cropped = await _cropBytesToAspectRatio(
        original,
        _selectedCropPreset,
        zoom: _cropZoom,
        offsetX: _cropOffsetX,
        offsetY: _cropOffsetY,
      );
      if (!mounted) return;
      setState(() => _selectedImageCroppedBytes = cropped);
    } catch (_) {
      if (!mounted) return;
      SakhiDialogs.showPrototypeSnackbar(
        context,
        'Crop could not be rendered. Your original photo remains selected.',
      );
    }
  }

  Future<void> _refreshLiveFeed() async {
    setState(() => _isRefreshing = true);
    await SakhiPrototypeState.instance.syncFromBackend();
    if (!mounted) return;
    setState(() => _isRefreshing = false);
    final state = SakhiPrototypeState.instance;
    SakhiDialogs.showPrototypeSnackbar(
      context,
      state.lastSyncError ?? 'Social Wall refreshed.',
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
      _cropZoom = 1.0;
      _cropOffsetX = 0.0;
      _cropOffsetY = 0.0;
      final cropped = await _cropBytesToAspectRatio(
        bytes,
        _selectedCropPreset,
        zoom: _cropZoom,
        offsetX: _cropOffsetX,
        offsetY: _cropOffsetY,
      );
      if (!mounted) return;
      setState(() {
        _selectedImageOriginalBytes = bytes;
        _selectedImageCroppedBytes = cropped;
        _selectedImageName = picked.name.isEmpty
            ? 'post_photo.png'
            : picked.name;
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
    await _applyCropSettings();
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
        if (uploadRes['uploadId'] != null &&
            uploadRes['uploadId']!.isNotEmpty) {
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
                            Text(
                              'Social Wall',
                              style: AppTypography.appBarTitle,
                            ),
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
                        tooltip: 'Refresh Social Wall',
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
                          Text(switch (_composerMode) {
                            'text' => 'Write a Text Post',
                            'question' => 'Create a Community Question',
                            'resource' => 'Share a Useful Resource',
                            _ => 'Post a Photo or Video',
                          }, style: AppTypography.sectionTitle),
                          const SizedBox(height: 10),
                          if (_composerMode == 'media') ...[
                            // Aspect ratio choices appear only after media is selected.
                            if (_selectedImageCroppedBytes != null ||
                                _attachedEditorialAsset != null) ...[
                              Row(
                                children: [
                                  const Text(
                                    'Crop Preset:',
                                    style: AppTypography.bodyMedium,
                                  ),
                                  const SizedBox(width: 8),
                                  for (final preset in const [
                                    '1:1',
                                    '4:5',
                                    '16:9',
                                  ])
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
                                        backgroundColor:
                                            AppColors.pastelLavender,
                                        onSelected: (_) =>
                                            _changeCropPreset(preset),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (_selectedImageCroppedBytes != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: AspectRatio(
                                  aspectRatio: _aspectRatioForPreset(
                                    _selectedCropPreset,
                                  ),
                                  child: Image.memory(
                                    _selectedImageCroppedBytes!,
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 58,
                                    child: Text('Zoom'),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: _cropZoom,
                                      min: 1.0,
                                      max: 3.0,
                                      divisions: 20,
                                      label: '${_cropZoom.toStringAsFixed(1)}×',
                                      activeColor: AppColors.primaryPurple,
                                      onChanged: (value) =>
                                          setState(() => _cropZoom = value),
                                      onChangeEnd: (_) => _applyCropSettings(),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 58,
                                    child: Text('Left / right'),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: _cropOffsetX,
                                      min: -1.0,
                                      max: 1.0,
                                      divisions: 20,
                                      activeColor: AppColors.primaryPurple,
                                      onChanged: (value) =>
                                          setState(() => _cropOffsetX = value),
                                      onChangeEnd: (_) => _applyCropSettings(),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 58,
                                    child: Text('Up / down'),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: _cropOffsetY,
                                      min: -1.0,
                                      max: 1.0,
                                      divisions: 20,
                                      activeColor: AppColors.primaryPurple,
                                      onChanged: (value) =>
                                          setState(() => _cropOffsetY = value),
                                      onChangeEnd: (_) => _applyCropSettings(),
                                    ),
                                  ),
                                ],
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => setState(() {
                                    _selectedImageOriginalBytes = null;
                                    _selectedImageCroppedBytes = null;
                                    _selectedImageName = null;
                                    _cropZoom = 1.0;
                                    _cropOffsetX = 0.0;
                                    _cropOffsetY = 0.0;
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
                                  aspectRatio: _aspectRatioForPreset(
                                    _selectedCropPreset,
                                  ),
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
                                  label: const Text('Create with Template'),
                                  onPressed: () => setState(() {
                                    _attachedEditorialAsset =
                                        AppAssets.communityCircleGathering;
                                    _selectedImageOriginalBytes = null;
                                    _selectedImageCroppedBytes = null;
                                  }),
                                ),
                              ],
                            ),
                          ],
                          if (_composerMode == 'media' &&
                              _composerStep == 0) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed:
                                    (_selectedImageCroppedBytes != null ||
                                        _attachedEditorialAsset != null)
                                    ? () => setState(() => _composerStep = 1)
                                    : null,
                                icon: const Icon(Icons.arrow_forward_rounded),
                                label: const Text('Next'),
                              ),
                            ),
                          ],
                          if (_composerMode != 'media' ||
                              _composerStep == 1) ...[
                            if (_composerMode == 'text' ||
                                _composerMode == 'question') ...[
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment<String>(
                                    value: 'text',
                                    icon: Icon(Icons.edit_note_rounded),
                                    label: Text('Text Post'),
                                  ),
                                  ButtonSegment<String>(
                                    value: 'question',
                                    icon: Icon(Icons.forum_outlined),
                                    label: Text('Community Question'),
                                  ),
                                ],
                                selected: {_composerMode},
                                onSelectionChanged: (selection) {
                                  if (selection.isNotEmpty) {
                                    setState(
                                      () => _composerMode = selection.first,
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextField(
                              controller: _postController,
                              maxLines: _composerMode == 'question' ? 5 : 3,
                              maxLength: 500,
                              decoration: InputDecoration(
                                hintText: switch (_composerMode) {
                                  'question' =>
                                    'Ask the community a question...',
                                  'resource' =>
                                    'Share a useful resource with the community...',
                                  'media' =>
                                    'Write a caption and add #hashtags...',
                                  _ =>
                                    'Share your thoughts with the community...',
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: state.trendingHashtags.map((tag) {
                                final selected = _selectedHashtags.contains(
                                  tag,
                                );
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
                                        setState(
                                          () => _composerCategorySlug = v,
                                        );
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
                            Material(
                              color: Colors.transparent,
                              child: SwitchListTile.adaptive(
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
                            ),
                            Material(
                              color: Colors.transparent,
                              child: SwitchListTile.adaptive(
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
                                      : () => setState(() {
                                          if (_composerMode == 'media' &&
                                              _composerStep == 1) {
                                            _composerStep = 0;
                                          } else {
                                            _showComposer = false;
                                          }
                                        }),
                                  child: Text(
                                    _composerMode == 'media' &&
                                            _composerStep == 1
                                        ? 'Back to media'
                                        : 'Cancel',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SakhiPillButton(
                                  label: _isUploadingCloudMedia
                                      ? 'Publishing...'
                                      : switch (_composerMode) {
                                          'text' => 'Share Post',
                                          'question' => 'Share Question',
                                          'resource' => 'Share Resource',
                                          _ => 'Publish to Social Wall',
                                        },
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 9,
                                  ),
                                  onPressed: _isUploadingCloudMedia
                                      ? null
                                      : _publishPost,
                                ),
                              ],
                            ),
                          ],
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
                  if (!state.isBackendSynced)
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
                          if (state.isBackendSyncing)
                            const CircularProgressIndicator(
                              color: AppColors.primaryPurple,
                            )
                          else
                            const Icon(
                              Icons.cloud_off_outlined,
                              color: AppColors.primaryPurple,
                              size: 36,
                            ),
                          const SizedBox(height: 8),
                          Text(
                            state.isBackendSyncing
                                ? 'Loading live Social Wall…'
                                : (state.lastSyncError ??
                                      'Live Social Wall data is unavailable.'),
                            textAlign: TextAlign.center,
                            style: AppTypography.subtitle,
                          ),
                          if (!state.isBackendSyncing) ...[
                            const SizedBox(height: 12),
                            SakhiPillButton(
                              label: 'Retry connection',
                              onPressed: _refreshLiveFeed,
                            ),
                          ],
                        ],
                      ),
                    )
                  else if (posts.isEmpty)
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
                                  ? 'Saved post'
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
                  subtitle: Text(
                    cat.description,
                    style: AppTypography.subtitle,
                  ),
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
