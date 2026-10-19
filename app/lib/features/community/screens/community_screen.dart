import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_avatar.dart';
import '../../../core/widgets/sakhi_buttons.dart';
import '../../../core/widgets/sakhi_dialogs.dart';
import '../../../core/widgets/sakhi_search_field.dart';
import '../widgets/feed_post_card.dart';

/// Screen 3 — Community Feed (Connected to Live PostgreSQL + Cloud Media Upload)
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String _selectedFeedFilter = 'For You';
  bool _showSearch = false;
  bool _showComposer = false;
  bool _isUploadingCloudMedia = false;
  bool _isRefreshing = false;
  String _selectedBadge = 'Wellness';
  String? _attachedMediaUrl;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _postController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _postController.dispose();
    super.dispose();
  }

  Future<void> _refreshLiveFeed() async {
    setState(() => _isRefreshing = true);
    await SakhiPrototypeState.instance.syncFromBackend();
    if (!mounted) return;
    setState(() => _isRefreshing = false);
    SakhiDialogs.showPrototypeSnackbar(
      context,
      'Synced live posts and members from PostgreSQL database!',
    );
  }

  Future<void> _handleUploadPostMedia(String presetTheme) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
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
        SakhiDialogs.showPrototypeSnackbar(
          context,
          'Choose a JPG, PNG, or WebP image.',
        );
        return;
      }

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
        SakhiDialogs.showPrototypeSnackbar(
          context,
          'Choose an image no larger than 10 MB.',
        );
        return;
      }

      setState(() => _isUploadingCloudMedia = true);

      final url = await SakhiPrototypeState.instance.uploadMediaToCloud(
        purpose: 'post',
        fileName:
            'community_${presetTheme}_${DateTime.now().millisecondsSinceEpoch}.$extension',
        fileBytes: bytes,
        contentType: contentType,
      );

      if (!mounted) return;

      setState(() {
        _isUploadingCloudMedia = false;
        _attachedMediaUrl = url;
      });

      SakhiDialogs.showPrototypeSnackbar(
        context,
        url == null
            ? 'Image upload failed. Please sign in and try again.'
            : 'Photo uploaded to Sakhi Media.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUploadingCloudMedia = false);
      SakhiDialogs.showPrototypeSnackbar(
        context,
        'Unable to upload this image. Please try again.',
      );
    }
  }

  void _publishPost() {
    final text = _postController.text.trim();
    if (text.isEmpty) return;
    SakhiPrototypeState.instance.createCommunityPost(
      text,
      categoryBadge: _selectedBadge,
      imageAsset: _attachedMediaUrl,
    );
    _postController.clear();
    setState(() {
      _attachedMediaUrl = null;
      _showComposer = false;
    });
    SakhiDialogs.showPrototypeSnackbar(
      context,
      'Post saved to PostgreSQL database & published live!',
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final query = _searchController.text.trim().toLowerCase();
        final posts = state.communityPosts.where((p) {
          if (query.isEmpty) return true;
          return p.authorName.toLowerCase().contains(query) ||
              p.content.toLowerCase().contains(query) ||
              (p.categoryBadge?.toLowerCase().contains(query) ?? false);
        }).toList();

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
                  // Top Bar: Community dropdown + For You pill selector + Search
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _showFeedFilterSheet(context),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Community', style: AppTypography.appBarTitle),
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
                      GestureDetector(
                        onTap: () => _showFeedFilterSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cardSurface,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusPill,
                            ),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedFeedFilter,
                                style: AppTypography.chipLabel.copyWith(
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: AppColors.primaryPurple,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
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
                        tooltip: 'Search Community',
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

                  // Live PostgreSQL + Create Post Action Row
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
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
                              size: 38,
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
                                    'Share a live post or upload a photo, ${state.currentUser.displayName}...',
                                    style: AppTypography.subtitle.copyWith(
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Create Post & Upload Photo',
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
                          TextField(
                            controller: _postController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Write your community post (saved directly to PostgreSQL)...',
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children:
                                [
                                  'Wellness',
                                  'WomenInTech',
                                  'Self-Care',
                                  'Safety Tips',
                                  'Book Club',
                                ].map((badge) {
                                  final selected = _selectedBadge == badge;
                                  return ChoiceChip(
                                    label: Text(
                                      badge,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: selected
                                            ? Colors.white
                                            : AppColors.primaryPurple,
                                      ),
                                    ),
                                    selected: selected,
                                    selectedColor: AppColors.primaryPurple,
                                    backgroundColor: AppColors.pastelLavender,
                                    onSelected: (_) =>
                                        setState(() => _selectedBadge = badge),
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                icon: _isUploadingCloudMedia
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.cloud_upload_outlined,
                                        size: 17,
                                      ),
                                label: Text(
                                  _attachedMediaUrl != null
                                      ? 'Cloud Photo Attached ✓'
                                      : 'Upload Photo to Cloud',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onPressed: _isUploadingCloudMedia
                                    ? null
                                    : () =>
                                          _handleUploadPostMedia('sunset_walk'),
                              ),
                              const Spacer(),
                              SakhiPillButton(
                                label: 'Publish Live',
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 9,
                                ),
                                onPressed: _publishPost,
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
                      hintText: 'Search live PostgreSQL posts...',
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      onClear: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    ),
                  ],

                  const SizedBox(height: 12),
                  // Feed Posts from PostgreSQL
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
    final options = ['For You', 'Following', 'My Groups', 'Wellness & Safety'];
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
                'Select Community Feed',
                style: AppTypography.sectionTitle,
              ),
              const SizedBox(height: 8),
              ...options.map(
                (opt) => ListTile(
                  title: Text(opt),
                  trailing: _selectedFeedFilter == opt
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primaryPurple,
                        )
                      : null,
                  onTap: () {
                    setState(() => _selectedFeedFilter = opt);
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
