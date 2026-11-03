import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/mock_data.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_avatar.dart';
import '../../../core/widgets/sakhi_chip.dart';
import '../../../core/widgets/sakhi_create_hub_sheet.dart';
import '../../../core/widgets/sakhi_dialogs.dart';
import '../../../core/widgets/sakhi_card.dart';

const Map<String, String> sakhiPostCategoryLabels = {
  'community': 'Community',
  'trending': 'Trending',
  'business_updates': 'Business Updates',
  'safety_awareness': 'Safety Awareness',
  'wellness_lifestyle': 'Wellness and Lifestyle',
};

const Map<String, String> sakhiPostAudiences = {
  'VERIFIED_MEMBERS': 'All Verified Members',
  'FOLLOWERS_ONLY': 'Followers Only',
  'PRIVATE_SELF': 'Only Me',
};

/// Inspects raw magic bytes first so camera/content URIs without file extensions
/// or uncropped JPEG bytes never get mislabeled as image/png.
String detectMediaContentType(Uint8List bytes, String fallbackFileName) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  if (bytes.length >= 6 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38) {
    return 'image/gif';
  }
  if (bytes.length >= 12 &&
      bytes[4] == 0x66 &&
      bytes[5] == 0x74 &&
      bytes[6] == 0x79 &&
      bytes[7] == 0x70) {
    return 'video/mp4';
  }
  final lower = fallbackFileName.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.webm')) return 'video/webm';
  return 'image/png';
}

String normalizeMediaFileName(String rawName, String contentType) {
  final expectedExt = switch (contentType) {
    'image/jpeg' => '.jpg',
    'image/webp' => '.webp',
    'image/gif' => '.gif',
    'video/mp4' => '.mp4',
    'video/webm' => '.webm',
    _ => '.png',
  };
  final cleaned = rawName.trim().isEmpty ? 'sakhi_media' : rawName.trim();
  final dotIdx = cleaned.lastIndexOf('.');
  final base = dotIdx > 0 ? cleaned.substring(0, dotIdx) : cleaned;
  return '$base$expectedExt';
}

/// Aesthetic "Lovely Girls" studio filter preset with 4x5 color matrix.
class SakhiStudioFilterPreset {
  final String id;
  final String label;
  final String emoji;
  final List<double> matrix;
  final List<Color> previewGradient;

  const SakhiStudioFilterPreset({
    required this.id,
    required this.label,
    required this.emoji,
    required this.matrix,
    required this.previewGradient,
  });
}

const List<SakhiStudioFilterPreset> sakhiStudioFilters = [
  SakhiStudioFilterPreset(
    id: 'original',
    label: 'Original',
    emoji: 'âœ¨',
    matrix: <double>[
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ],
    previewGradient: [Color(0xFF7B228E), Color(0xFFD63E85)],
  ),
  SakhiStudioFilterPreset(
    id: 'rose_glow',
    label: 'Rose Glow',
    emoji: 'ðŸŒ¸',
    matrix: <double>[
      1.12, 0.04, 0.04, 0, 10,
      0.02, 0.98, 0.02, 0, 2,
      0.04, 0.02, 1.04, 0, 8,
      0, 0, 0, 1, 0,
    ],
    previewGradient: [Color(0xFFE84A8A), Color(0xFFFFB3D1)],
  ),
  SakhiStudioFilterPreset(
    id: 'golden_hour',
    label: 'Golden Hour',
    emoji: 'â˜€ï¸',
    matrix: <double>[
      1.14, 0.06, 0.0, 0, 12,
      0.04, 1.05, 0.0, 0, 6,
      0.0, 0.0, 0.90, 0, -6,
      0, 0, 0, 1, 0,
    ],
    previewGradient: [Color(0xFFD97706), Color(0xFFF59E0B)],
  ),
  SakhiStudioFilterPreset(
    id: 'velvet_plum',
    label: 'Velvet Plum',
    emoji: 'ðŸ’œ',
    matrix: <double>[
      1.05, 0.02, 0.08, 0, 6,
      0.0, 0.95, 0.04, 0, 0,
      0.06, 0.04, 1.15, 0, 12,
      0, 0, 0, 1, 0,
    ],
    previewGradient: [Color(0xFF5A1868), Color(0xFF9D4EDD)],
  ),
  SakhiStudioFilterPreset(
    id: 'soft_pearl',
    label: 'Soft Pearl',
    emoji: 'ðŸ¤',
    matrix: <double>[
      1.04, 0.04, 0.04, 0, 14,
      0.04, 1.04, 0.04, 0, 14,
      0.04, 0.04, 1.06, 0, 16,
      0, 0, 0, 1, 0,
    ],
    previewGradient: [Color(0xFFA855F7), Color(0xFFF3E8FF)],
  ),
  SakhiStudioFilterPreset(
    id: 'warm_peach',
    label: 'Warm Peach',
    emoji: 'ðŸ‘',
    matrix: <double>[
      1.15, 0.05, 0.02, 0, 12,
      0.03, 1.02, 0.02, 0, 6,
      0.0, 0.02, 0.94, 0, 2,
      0, 0, 0, 1, 0,
    ],
    previewGradient: [Color(0xFFFB7185), Color(0xFFFDBA74)],
  ),
];

/// The central Create Hub launches one dedicated composer route while leaving
/// the originating tab underneath it on the navigation stack.
Future<void> openSakhiCreateAction(
  BuildContext context,
  SakhiCreateAction action, {
  VoidCallback? onPublished,
  String? initialCategory,
}) async {
  final route = switch (action) {
    SakhiCreateAction.photoVideo => MaterialPageRoute<void>(
      builder: (_) => SakhiMediaPostFlowScreen(
        onPublished: onPublished,
        initialCategory: initialCategory,
      ),
    ),
    SakhiCreateAction.textPost => MaterialPageRoute<void>(
      builder: (_) => SakhiTextPostComposerScreen(
        onPublished: onPublished,
        initialCategory: initialCategory,
      ),
    ),
    SakhiCreateAction.communityQuestion => MaterialPageRoute<void>(
      builder: (_) => SakhiQuestionComposerScreen(
        onPublished: onPublished,
        initialCategory: initialCategory,
      ),
    ),
    SakhiCreateAction.usefulResource => MaterialPageRoute<void>(
      builder: (_) =>
          SakhiResourceComposerScreen(onPublished: onPublished),
    ),
    SakhiCreateAction.womenBusinessPage => null,
    SakhiCreateAction.discreetComplaint => null,
  };

  if (action == SakhiCreateAction.womenBusinessPage) {
    await Navigator.of(context).pushNamed(AppRoutes.businessHub);
    return;
  }
  if (action == SakhiCreateAction.discreetComplaint) {
    await Navigator.of(context).pushNamed(AppRoutes.discreetComplaintHub);
    return;
  }
  if (route != null) {
    await Navigator.of(context).push(route);
  }
}

class _SelectedDevicePhoto {
  const _SelectedDevicePhoto({
    required this.name,
    required this.bytes,
    required this.contentType,
  });

  final String name;
  final Uint8List bytes;
  final String contentType;
}

class _SelectedVideoDraft {
  const _SelectedVideoDraft({
    required this.name,
    required this.bytes,
    required this.contentType,
  });

  final String name;
  final Uint8List bytes;
  final String contentType;
}

/// Session-scoped cache of real user-selected device photos so switching tabs
/// or reopening the composer preserves the user's real camera/gallery picks
/// without ever showing fake stock illustrations.
final List<_SelectedDevicePhoto> _sessionRecentDevicePhotos =
    <_SelectedDevicePhoto>[];

/// Flow 1 â€” Instagram-Style "Lovely Girls" Photo & Video Studio Composer
class SakhiMediaPostFlowScreen extends StatefulWidget {
  const SakhiMediaPostFlowScreen({
    super.key,
    this.onPublished,
    this.initialCategory,
  });

  final VoidCallback? onPublished;
  final String? initialCategory;

  @override
  State<SakhiMediaPostFlowScreen> createState() =>
      _SakhiMediaPostFlowScreenState();
}

class _SakhiMediaPostFlowScreenState extends State<SakhiMediaPostFlowScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _quoteCardController = TextEditingController();

  int _step = 0; // 0 = Studio Select/Frame/Filter, 1 = Share Details
  String _cropPreset = '4:5';
  String _selectedFilterId = 'original';
  double _zoom = 1.0;
  double _offsetX = 0.0;
  double _offsetY = 0.0;
  bool _showGridOverlay = true;
  bool _isRendering = false;
  bool _isPublishing = false;
  bool _isPickingMedia = false;

  _SelectedDevicePhoto? _selectedPhoto;
  Uint8List? _renderedPhotoBytes;
  _SelectedVideoDraft? _selectedVideo;
  int _selectedQuoteGradientIndex = 0;

  late String _categorySlug;
  String _visibility = 'VERIFIED_MEMBERS';
  final Set<String> _selectedHashtags = <String>{};
  bool _allowComments = true;

  static const List<List<Color>> _quoteCardGradients = [
    [Color(0xFF7B228E), Color(0xFFD63E85), Color(0xFFFF8DA1)],
    [Color(0xFF4A1259), Color(0xFF832B96), Color(0xFFC85A93)],
    [Color(0xFFB83280), Color(0xFFE53E3E), Color(0xFFF6AD55)],
    [Color(0xFF1E6F5C), Color(0xFF289672), Color(0xFF8FD9A8)],
  ];

  static const List<String> _quickLocations = [
    'Jubilee Hills, Hyderabad',
    'Banjara Hills, Hyderabad',
    'HITEC City, Hyderabad',
    'Gachibowli, Hyderabad',
    'Visakhapatnam, AP',
    'Vijayawada, AP',
    'Indiranagar, Bengaluru',
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCategory;
    _categorySlug =
        (initial != null && sakhiPostCategoryLabels.containsKey(initial))
        ? initial
        : 'community';
    if (_sessionRecentDevicePhotos.isNotEmpty) {
      _selectedPhoto = _sessionRecentDevicePhotos.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _renderCroppedPreview();
      });
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    _quoteCardController.dispose();
    super.dispose();
  }

  bool get _hasMedia =>
      _renderedPhotoBytes != null ||
      _selectedPhoto != null ||
      _selectedVideo != null;

  bool get _hasUnsavedWork =>
      _hasMedia ||
      _captionController.text.trim().isNotEmpty ||
      _locationController.text.trim().isNotEmpty ||
      _selectedHashtags.isNotEmpty;

  SakhiStudioFilterPreset get _activeFilter => sakhiStudioFilters.firstWhere(
    (f) => f.id == _selectedFilterId,
    orElse: () => sakhiStudioFilters.first,
  );

  double _aspectRatioValue(String preset) {
    return switch (preset) {
      '1:1' => 1.0,
      '16:9' => 16 / 9,
      '4:5' => 4 / 5,
      _ => 1.0,
    };
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_isPickingMedia) return;
    setState(() => _isPickingMedia = true);
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
        SakhiDialogs.showPrototypeSnackbar(
          context,
          'Please choose a photo under 10 MB.',
        );
        return;
      }
      final detectedMime = detectMediaContentType(bytes, file.name);
      final normalizedName = normalizeMediaFileName(
        file.name.isEmpty ? 'sakhi_camera_photo.jpg' : file.name,
        detectedMime,
      );
      final item = _SelectedDevicePhoto(
        name: normalizedName,
        bytes: bytes,
        contentType: detectedMime,
      );
      setState(() {
        _selectedVideo = null;
        _selectedPhoto = item;
        _zoom = 1.0;
        _offsetX = 0.0;
        _offsetY = 0.0;
        _sessionRecentDevicePhotos.removeWhere((p) => p.name == item.name);
        _sessionRecentDevicePhotos.insert(0, item);
        if (_sessionRecentDevicePhotos.length > 12) {
          _sessionRecentDevicePhotos.removeLast();
        }
      });
      await _renderCroppedPreview();
    } catch (err) {
      if (!mounted) return;
      SakhiDialogs.showPrototypeSnackbar(
        context,
        source == ImageSource.camera
            ? 'Camera could not be opened. Please grant Camera permission in Settings or pick from Gallery.'
            : 'Could not read the selected photo. Please try another image.',
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingMedia = false);
      }
    }
  }

  Future<void> _pickMultiplePhotos() async {
    if (_isPickingMedia) return;
    setState(() => _isPickingMedia = true);
    try {
      final files = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (files.isEmpty || !mounted) return;
      _SelectedDevicePhoto? firstAdded;
      for (final file in files.take(8)) {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) continue;
        final detectedMime = detectMediaContentType(bytes, file.name);
        final normalizedName = normalizeMediaFileName(
          file.name.isEmpty ? 'sakhi_gallery_photo.jpg' : file.name,
          detectedMime,
        );
        final item = _SelectedDevicePhoto(
          name: normalizedName,
          bytes: bytes,
          contentType: detectedMime,
        );
        firstAdded ??= item;
        _sessionRecentDevicePhotos.removeWhere((p) => p.name == item.name);
        _sessionRecentDevicePhotos.insert(0, item);
      }
      while (_sessionRecentDevicePhotos.length > 12) {
        _sessionRecentDevicePhotos.removeLast();
      }
      if (firstAdded != null && mounted) {
        setState(() {
          _selectedVideo = null;
          _selectedPhoto = firstAdded;
          _zoom = 1.0;
          _offsetX = 0.0;
          _offsetY = 0.0;
        });
        await _renderCroppedPreview();
      }
    } catch (_) {
      if (!mounted) return;
      SakhiDialogs.showPrototypeSnackbar(
        context,
        'Unable to load multiple gallery photos. Please try picking a single photo.',
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingMedia = false);
      }
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    if (_isPickingMedia) return;
    setState(() => _isPickingMedia = true);
    try {
      final file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 2),
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
        SakhiDialogs.showPrototypeSnackbar(
          context,
          'Choose an MP4 or WebM video under 20 MB.',
        );
        return;
      }
      final lower = file.name.toLowerCase();
      final contentType = lower.endsWith('.webm') ? 'video/webm' : 'video/mp4';
      final normalizedName = normalizeMediaFileName(
        file.name.isEmpty ? 'sakhi_video.mp4' : file.name,
        contentType,
      );
      setState(() {
        _selectedPhoto = null;
        _renderedPhotoBytes = null;
        _selectedVideo = _SelectedVideoDraft(
          name: normalizedName,
          bytes: bytes,
          contentType: contentType,
        );
      });
    } catch (_) {
      if (!mounted) return;
      SakhiDialogs.showPrototypeSnackbar(
        context,
        'Unable to read the selected video. Please choose an MP4 or WebM clip.',
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingMedia = false);
      }
    }
  }

  Future<void> _openQuoteCardCreatorSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final grad = _quoteCardGradients[_selectedQuoteGradientIndex];
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.primaryPurple,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Create Sakhi Quote Card',
                          style: AppTypography.sectionTitle,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 200,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: grad,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _quoteCardController.text.trim().isEmpty
                            ? 'Type your affirmation, announcement, or sisterhood message belowâ€¦'
                            : _quoteCardController.text.trim(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_quoteCardGradients.length, (i) {
                        final selected = _selectedQuoteGradientIndex == i;
                        return GestureDetector(
                          onTap: () => setSheetState(
                            () => _selectedQuoteGradientIndex = i,
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _quoteCardGradients[i],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? AppColors.primaryPurple
                                    : Colors.white,
                                width: selected ? 3 : 1.5,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _quoteCardController,
                      maxLines: 3,
                      maxLength: 180,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Write your quote or message for the cardâ€¦',
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () async {
                        final text = _quoteCardController.text.trim();
                        if (text.isEmpty) return;
                        Navigator.pop(ctx);
                        await _renderQuoteCardToPhoto(
                          text,
                          _quoteCardGradients[_selectedQuoteGradientIndex],
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Use This Studio Card'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _renderQuoteCardToPhoto(
    String quoteText,
    List<Color> colors,
  ) async {
    setState(() => _isRendering = true);
    try {
      const width = 1080;
      const height = 1350;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final rect = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(width.toDouble(), height.toDouble()),
          colors,
          const [0.0, 0.55, 1.0],
        );
      canvas.drawRect(rect, paint);

      // Subtle decorative glow circles
      canvas.drawCircle(
        const Offset(180, 220),
        220,
        Paint()..color = Colors.white.withValues(alpha: 0.08),
      );
      canvas.drawCircle(
        const Offset(900, 1120),
        260,
        Paint()..color = Colors.white.withValues(alpha: 0.08),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: 'â€œ$quoteTextâ€\n\nâ€” Sakhi Sisterhood âœ¨',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 54,
            fontWeight: FontWeight.w800,
            height: 1.38,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width - 180);

      tp.paint(
        canvas,
        Offset((width - tp.width) / 2, (height - tp.height) / 2),
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      if (byteData == null || !mounted) return;
      final pngBytes = byteData.buffer.asUint8List();
      final item = _SelectedDevicePhoto(
        name: 'sakhi_quote_card_${DateTime.now().millisecondsSinceEpoch}.png',
        bytes: pngBytes,
        contentType: 'image/png',
      );
      setState(() {
        _selectedVideo = null;
        _selectedPhoto = item;
        _renderedPhotoBytes = pngBytes;
        _cropPreset = '4:5';
        _zoom = 1.0;
        _offsetX = 0.0;
        _offsetY = 0.0;
        _isRendering = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isRendering = false);
    }
  }

  Future<void> _renderCroppedPreview() async {
    final photo = _selectedPhoto;
    if (photo == null) return;
    if (_cropPreset == 'Original' &&
        _zoom == 1.0 &&
        _offsetX == 0.0 &&
        _offsetY == 0.0 &&
        _selectedFilterId == 'original') {
      setState(() => _renderedPhotoBytes = photo.bytes);
      return;
    }
    setState(() => _isRendering = true);
    try {
      final codec = await ui.instantiateImageCodec(photo.bytes);
      try {
        final frame = await codec.getNextFrame();
        final src = frame.image;
        try {
          final targetRatio = _cropPreset == 'Original'
              ? (src.width / src.height)
              : _aspectRatioValue(_cropPreset);
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

          final safeZoom = _zoom.clamp(1.0, 3.0);
          final cropW = baseW / safeZoom;
          final cropH = baseH / safeZoom;
          final maxLeft = (src.width - cropW).clamp(0.0, src.width.toDouble());
          final maxTop = (src.height - cropH).clamp(0.0, src.height.toDouble());
          final left = (maxLeft / 2 + _offsetX.clamp(-1.0, 1.0) * maxLeft / 2)
              .clamp(0.0, maxLeft);
          final top = (maxTop / 2 + _offsetY.clamp(-1.0, 1.0) * maxTop / 2)
              .clamp(0.0, maxTop);

          const outW = 1080;
          final outH = (outW / targetRatio).round().clamp(360, 1920);
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          final paint = Paint()..filterQuality = FilterQuality.high;
          if (_selectedFilterId != 'original') {
            paint.colorFilter = ColorFilter.matrix(_activeFilter.matrix);
          }
          canvas.drawImageRect(
            src,
            Rect.fromLTWH(left, top, cropW, cropH),
            Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
            paint,
          );
          final picture = recorder.endRecording();
          final cropped = await picture.toImage(outW, outH);
          try {
            final byteData = await cropped.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (!mounted) return;
            setState(() {
              _renderedPhotoBytes =
                  byteData?.buffer.asUint8List() ?? photo.bytes;
              _isRendering = false;
            });
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _renderedPhotoBytes = photo.bytes;
        _isRendering = false;
      });
    }
  }

  Future<bool> _confirmClose() async {
    if (!_hasUnsavedWork || _isPublishing) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Discard draft?',
          style: AppTypography.sectionTitle,
        ),
        content: const Text(
          'Leaving now will discard your current photo or video post draft.',
          style: AppTypography.bodyRegular,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.sosRed),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _publishMediaPost() async {
    if (_isPublishing) return;
    if (!_hasMedia) {
      SakhiDialogs.showPrototypeSnackbar(
        context,
        'Select or capture a photo or video before sharing.',
      );
      return;
    }

    setState(() => _isPublishing = true);
    try {
      final state = SakhiPrototypeState.instance;
      late final Uint8List uploadBytes;
      late final String uploadName;
      late final String contentType;

      if (_selectedVideo != null) {
        uploadBytes = _selectedVideo!.bytes;
        contentType = detectMediaContentType(uploadBytes, _selectedVideo!.name);
        uploadName = normalizeMediaFileName(_selectedVideo!.name, contentType);
      } else {
        uploadBytes = _renderedPhotoBytes ?? _selectedPhoto!.bytes;
        // Always inspect actual magic bytes of uploadBytes so raw JPEGs and rendered PNGs
        // both pass backend signature verification cleanly!
        contentType = detectMediaContentType(uploadBytes, _selectedPhoto!.name);
        uploadName = normalizeMediaFileName(_selectedPhoto!.name, contentType);
      }

      final uploadRes = await state.uploadMediaFile(
        purpose: 'community_post',
        fileName: uploadName,
        fileBytes: uploadBytes,
        contentType: contentType,
        categorySlug: _categorySlug,
        cropAspectRatio: _cropPreset == 'Original' ? '4:5' : _cropPreset,
      );
      if (!mounted) return;
      if (uploadRes == null) {
        setState(() => _isPublishing = false);
        SakhiDialogs.showPrototypeSnackbar(
          context,
          'Media upload failed â€” your draft is preserved so you can retry.',
        );
        return;
      }

      final caption = _captionController.text.trim();
      final uploadId = uploadRes['uploadId'] ?? '';
      final ok = await state.createCommunityPost(
        caption.isEmpty ? 'Shared a moment with the Sakhi community âœ¨' : caption,
        categoryBadge: sakhiPostCategoryLabels[_categorySlug] ?? 'Community',
        categorySlug: _categorySlug,
        visibility: _visibility,
        cropPreset: _cropPreset == 'Original' ? '4:5' : _cropPreset,
        hashtags: _selectedHashtags.toList(),
        locationTag: _locationController.text.trim(),
        allowComments: _allowComments,
        imageAsset: uploadRes['mediaUrl'],
        mediaUploadIds: uploadId.isNotEmpty ? <String>[uploadId] : const [],
      );
      if (!mounted) return;
      setState(() => _isPublishing = false);
      if (!ok) {
        SakhiDialogs.showPrototypeSnackbar(
          context,
          'Post could not be published. Your draft is still here so you can retry.',
        );
        return;
      }

      SakhiDialogs.showPrototypeSnackbar(
        context,
        'Published to the Sakhi Social Wall! ðŸŒ¸',
      );
      widget.onPublished?.call();
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPublishing = false);
      SakhiDialogs.showPrototypeSnackbar(
        context,
        'Publication failed. Your draft remains open.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_step == 1) {
          setState(() => _step = 0);
          return;
        }
        final navigator = Navigator.of(context);
        if (await _confirmClose() && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFDF7FA),
        appBar: AppBar(
          backgroundColor: Colors.white.withValues(alpha: 0.94),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            tooltip: _step == 1 ? 'Back to Studio' : 'Close',
            icon: Icon(
              _step == 1 ? Icons.arrow_back_rounded : Icons.close_rounded,
              color: AppColors.primaryPurple,
            ),
            onPressed: () async {
              if (_step == 1) {
                setState(() => _step = 0);
                return;
              }
              final navigator = Navigator.of(context);
              if (await _confirmClose() && mounted) {
                navigator.pop();
              }
            },
          ),
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B228E), Color(0xFFD63E85)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _step == 0 ? 'Sakhi Studio' : 'New Post Details',
                style: AppTypography.appBarTitle.copyWith(fontSize: 17.5),
              ),
            ],
          ),
          actions: [
            if (_step == 0)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                  onPressed: _hasMedia && !_isRendering
                      ? () => setState(() => _step = 1)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD63E85),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text(
                    'Next',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                  onPressed: _isPublishing ? null : _publishMediaPost,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  icon: _isPublishing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 15),
                  label: Text(
                    _isPublishing ? 'Sharingâ€¦' : 'Share',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
        body: _step == 0 ? _buildStepZeroStudio() : _buildStepOneDetails(),
      ),
    );
  }

  Widget _buildStepZeroStudio() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        8,
        AppSpacing.screenPaddingH,
        36,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Instagram-Style Interactive Stage Preview
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF280B33), Color(0xFF471254)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x294A1259),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SizedBox(
                  height: 360,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_selectedVideo != null)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFE03E7A),
                                      Color(0xFF7B228E),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.videocam_rounded,
                                  size: 38,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _selectedVideo!.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${(_selectedVideo!.bytes.length / (1024 * 1024)).toStringAsFixed(2)} MB â€¢ Ready to share',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_renderedPhotoBytes != null ||
                          _selectedPhoto != null)
                        GestureDetector(
                          onPanUpdate: (details) {
                            if (_zoom <= 1.0) return;
                            setState(() {
                              _offsetX = (_offsetX - details.delta.dx / 120)
                                  .clamp(-1.0, 1.0);
                              _offsetY = (_offsetY - details.delta.dy / 120)
                                  .clamp(-1.0, 1.0);
                            });
                          },
                          onPanEnd: (_) => _renderCroppedPreview(),
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: _cropPreset == 'Original'
                                  ? 4 / 5
                                  : _aspectRatioValue(_cropPreset),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(
                                    _renderedPhotoBytes ??
                                        _selectedPhoto!.bytes,
                                    fit: _cropPreset == 'Original'
                                        ? BoxFit.contain
                                        : BoxFit.cover,
                                    filterQuality: FilterQuality.high,
                                  ),
                                  if (_showGridOverlay)
                                    IgnorePointer(
                                      child: CustomPaint(
                                        painter: _RuleOfThirdsGridPainter(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 78,
                                height: 78,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFE03E7A),
                                      Color(0xFF7B228E),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_enhance_rounded,
                                  size: 36,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Share Your Moment âœ¨',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Snap a live camera photo, choose from your phone gallery, or design a Sakhi quote card below.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.80),
                                  fontSize: 12.8,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                alignment: WrapAlignment.center,
                                children: [
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFE03E7A),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () =>
                                        _pickPhoto(ImageSource.camera),
                                    icon: const Icon(
                                      Icons.photo_camera_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Open Camera'),
                                  ),
                                  FilledButton.tonalIcon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.16,
                                      ),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () =>
                                        _pickPhoto(ImageSource.gallery),
                                    icon: const Icon(
                                      Icons.photo_library_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Pick from Gallery'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      if (_isRendering || _isPickingMedia)
                        Container(
                          color: Colors.black38,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (_selectedPhoto != null)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Row(
                            children: [
                              IconButton.filledTonal(
                                tooltip: 'Toggle composition grid',
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => setState(
                                  () => _showGridOverlay = !_showGridOverlay,
                                ),
                                icon: Icon(
                                  _showGridOverlay
                                      ? Icons.grid_on_rounded
                                      : Icons.grid_off_rounded,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton.filledTonal(
                                tooltip: 'Remove selected photo',
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => setState(() {
                                  _selectedPhoto = null;
                                  _renderedPhotoBytes = null;
                                }),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Aspect Ratio & Zoom Strip inside Stage
                if (_selectedPhoto != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    color: Colors.black.withValues(alpha: 0.28),
                    child: Column(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.crop_rounded,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              for (final preset in const [
                                '4:5',
                                '1:1',
                                '16:9',
                                'Original',
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(
                                      preset == '4:5'
                                          ? '4:5 Portrait'
                                          : preset == '1:1'
                                          ? '1:1 Square'
                                          : preset == '16:9'
                                          ? '16:9 Wide'
                                          : 'Original',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: _cropPreset == preset
                                            ? Colors.white
                                            : AppColors.primaryPurple,
                                      ),
                                    ),
                                    selected: _cropPreset == preset,
                                    selectedColor: const Color(0xFFD63E85),
                                    backgroundColor: Colors.white,
                                    onSelected: (_) {
                                      setState(() => _cropPreset = preset);
                                      _renderCroppedPreview();
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.zoom_in_rounded,
                              color: Colors.white70,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_zoom.toStringAsFixed(1)}Ã—',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: _zoom,
                                min: 1.0,
                                max: 3.0,
                                divisions: 20,
                                activeColor: const Color(0xFFFF7EB3),
                                inactiveColor: Colors.white24,
                                onChanged: (value) =>
                                    setState(() => _zoom = value),
                                onChangeEnd: (_) => _renderCroppedPreview(),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _zoom = 1.0;
                                  _offsetX = 0.0;
                                  _offsetY = 0.0;
                                  _selectedFilterId = 'original';
                                });
                                _renderCroppedPreview();
                              },
                              child: const Text(
                                'Reset',
                                style: TextStyle(
                                  color: Color(0xFFFFB3D1),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // 2. Aesthetic "Lovely Girls" Studio Filters Strip
          if (_selectedPhoto != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.palette_outlined,
                  size: 18,
                  color: AppColors.primaryPurple,
                ),
                const SizedBox(width: 6),
                Text(
                  'Sakhi Aesthetic Filters',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  _activeFilter.label,
                  style: AppTypography.caption.copyWith(
                    color: const Color(0xFFD63E85),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sakhiStudioFilters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final filter = sakhiStudioFilters[index];
                  final selected = filter.id == _selectedFilterId;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedFilterId = filter.id);
                      _renderCroppedPreview();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 82,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: selected
                            ? LinearGradient(colors: filter.previewGradient)
                            : null,
                        color: selected ? null : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFD63E85)
                              : AppColors.borderSubtle,
                          width: selected ? 2 : 1,
                        ),
                        boxShadow: selected
                            ? const [
                                BoxShadow(
                                  color: Color(0x26D63E85),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            filter.emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            filter.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // 3. Studio Action Tiles (Camera, Gallery, Multi-Photo, Video, Quote Card)
          const SizedBox(height: 16),
          Text(
            'Choose Media Source',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StudioActionTile(
                  icon: Icons.photo_camera_rounded,
                  label: 'Camera',
                  subtitle: 'Snap live photo',
                  gradient: const [Color(0xFFE03E7A), Color(0xFFA82368)],
                  onTap: () => _pickPhoto(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StudioActionTile(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  subtitle: 'Pick from phone',
                  gradient: const [Color(0xFF7B228E), Color(0xFF5A1868)],
                  onTap: () => _pickPhoto(ImageSource.gallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StudioActionTile(
                  icon: Icons.collections_rounded,
                  label: 'Multi-Photo',
                  subtitle: 'Load batch to tray',
                  gradient: const [Color(0xFF9333EA), Color(0xFF6B21A8)],
                  onTap: _pickMultiplePhotos,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StudioActionTile(
                  icon: Icons.videocam_rounded,
                  label: 'Video Clip',
                  subtitle: 'MP4 / WebM',
                  gradient: const [Color(0xFFD97706), Color(0xFFB45309)],
                  onTap: () => _pickVideo(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StudioActionTile(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Quote Card',
                  subtitle: 'Design card',
                  gradient: const [Color(0xFF0D9488), Color(0xFF115E59)],
                  onTap: _openQuoteCardCreatorSheet,
                ),
              ),
            ],
          ),

          // 4. Real Device Photos Selected in This Session (ZERO Fake/Static Thumbnails!)
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 18,
                color: AppColors.primaryPurple,
              ),
              const SizedBox(width: 6),
              Text(
                'Your Selected Device Photos (${_sessionRecentDevicePhotos.length})',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (_sessionRecentDevicePhotos.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() {
                    _sessionRecentDevicePhotos.clear();
                  }),
                  child: const Text('Clear tray'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_sessionRecentDevicePhotos.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.pastelPink,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.add_a_photo_outlined,
                      color: Color(0xFFD63E85),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No device photos selected yet. Tap Camera or Gallery above to capture or choose real photos from your phone.',
                      style: AppTypography.subtitle.copyWith(
                        fontSize: 12.2,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _sessionRecentDevicePhotos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final item = _sessionRecentDevicePhotos[index];
                final isCurrent = _selectedPhoto?.name == item.name;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedVideo = null;
                      _selectedPhoto = item;
                      _zoom = 1.0;
                      _offsetX = 0.0;
                      _offsetY = 0.0;
                    });
                    _renderCroppedPreview();
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(item.bytes, fit: BoxFit.cover),
                        if (isCurrent)
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFD63E85),
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.all(6),
                            child: const CircleAvatar(
                              radius: 11,
                              backgroundColor: Color(0xFFD63E85),
                              child: Icon(
                                Icons.check,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStepOneDetails() {
    final state = SakhiPrototypeState.instance;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        12,
        AppSpacing.screenPaddingH,
        36,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SakhiCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: _selectedVideo != null
                        ? Container(
                            color: AppColors.pastelLavender,
                            child: const Icon(
                              Icons.videocam_rounded,
                              color: AppColors.primaryPurple,
                              size: 34,
                            ),
                          )
                        : Image.memory(
                            _renderedPhotoBytes ?? _selectedPhoto!.bytes,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _captionController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      hintText:
                          'Write a warm caption, story, or #hashtags for your Sakhisâ€¦',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Popular Sisterhood Hashtags',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w800,
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
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _categorySlug,
            decoration: const InputDecoration(
              labelText: 'Feed Category',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: sakhiPostCategoryLabels.entries
                .map(
                  (e) => DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(e.value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _categorySlug = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Add Location (optional)',
              hintText: 'e.g., Jubilee Hills, Hyderabad',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickLocations.map((loc) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    avatar: const Icon(
                      Icons.place_outlined,
                      size: 15,
                      color: AppColors.primaryPurple,
                    ),
                    label: Text(loc, style: const TextStyle(fontSize: 11.5)),
                    onPressed: () =>
                        setState(() => _locationController.text = loc),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _visibility,
            decoration: const InputDecoration(
              labelText: 'Who can view this post?',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
            items: sakhiPostAudiences.entries
                .map(
                  (e) => DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(e.value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _visibility = value);
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _allowComments,
            activeThumbColor: AppColors.primaryPurple,
            title: const Text(
              'Allow member comments',
              style: AppTypography.bodyMedium,
            ),
            subtitle: const Text(
              'Verified Sakhi members can reply with supportive comments',
              style: AppTypography.caption,
            ),
            onChanged: (value) => setState(() => _allowComments = value),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _isPublishing ? null : _publishMediaPost,
              icon: _isPublishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _isPublishing
                    ? 'Uploading & Publishingâ€¦'
                    : 'Publish to Sakhi Social Wall',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioActionTile extends StatelessWidget {
  const _StudioActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.8,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleOfThirdsGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.32)
      ..strokeWidth = 1.0;
    final thirdW = size.width / 3;
    final thirdH = size.height / 3;
    for (int i = 1; i <= 2; i++) {
      canvas.drawLine(
        Offset(thirdW * i, 0),
        Offset(thirdW * i, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(0, thirdH * i),
        Offset(size.width, thirdH * i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Flow 2 â€” Write a Text Post
class SakhiTextPostComposerScreen extends StatefulWidget {
  const SakhiTextPostComposerScreen({
    super.key,
    this.onPublished,
    this.initialCategory,
  });

  final VoidCallback? onPublished;
  final String? initialCategory;

  @override
  State<SakhiTextPostComposerScreen> createState() =>
      _SakhiTextPostComposerScreenState();
}

class _SakhiTextPostComposerScreenState
    extends State<SakhiTextPostComposerScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  late String _categorySlug;
  String _visibility = 'VERIFIED_MEMBERS';
  final Set<String> _hashtags = <String>{};
  bool _allowComments = true;
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCategory;
    _categorySlug =
        (initial != null && sakhiPostCategoryLabels.containsKey(initial))
        ? initial
        : 'community';
  }

  @override
  void dispose() {
    _textController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  bool get _hasDraft =>
      _textController.text.trim().isNotEmpty ||
      _locationController.text.trim().isNotEmpty ||
      _hashtags.isNotEmpty;

  Future<bool> _confirmDiscard() async {
    if (!_hasDraft || _isPublishing) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard text post?'),
        content: const Text('Your current text post draft will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.sosRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _publish() async {
    final body = _textController.text.trim();
    if (body.isEmpty || _isPublishing) return;
    setState(() => _isPublishing = true);
    final ok = await SakhiPrototypeState.instance.createCommunityPost(
      body,
      categoryBadge: sakhiPostCategoryLabels[_categorySlug] ?? 'Community',
      categorySlug: _categorySlug,
      visibility: _visibility,
      hashtags: _hashtags.toList(),
      locationTag: _locationController.text.trim(),
      allowComments: _allowComments,
    );
    if (!mounted) return;
    setState(() => _isPublishing = false);
    if (!ok) {
      SakhiDialogs.showPrototypeSnackbar(
        context,
        'Post could not be published. Check your connection and retry.',
      );
      return;
    }
    SakhiDialogs.showPrototypeSnackbar(context, 'Text post published!');
    widget.onPublished?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final user = SakhiPrototypeState.instance.currentUser;
    final canPost = _textController.text.trim().isNotEmpty && !_isPublishing;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard() && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (await _confirmDiscard() && mounted) {
                navigator.pop();
              }
            },
          ),
          title: const Text('Write a Post'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: canPost ? _publish : null,
                child: Text(_isPublishing ? 'Postingâ€¦' : 'Post'),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SakhiAvatar(
                    imageAsset: user.avatarAsset,
                    fallbackLabel: user.displayName,
                    size: 44,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.displayName, style: AppTypography.cardTitle),
                        Text(
                          sakhiPostCategoryLabels[_categorySlug] ?? 'Community',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _textController,
                autofocus: true,
                maxLines: 7,
                maxLength: 500,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Share a thought, experience, or updateâ€¦',
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: SakhiPrototypeState.instance.trendingHashtags.map((
                  tag,
                ) {
                  final selected = _hashtags.contains(tag);
                  return SakhiChip(
                    label: tag,
                    isSelected: selected,
                    onTap: () => setState(() {
                      if (selected) {
                        _hashtags.remove(tag);
                      } else {
                        _hashtags.add(tag);
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _categorySlug,
                decoration: const InputDecoration(labelText: 'Category'),
                items: sakhiPostCategoryLabels.entries
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _categorySlug = v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _visibility,
                decoration: const InputDecoration(labelText: 'Audience'),
                items: sakhiPostAudiences.entries
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _visibility = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Add Location (optional)',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _allowComments,
                activeThumbColor: AppColors.primaryPurple,
                title: const Text('Allow member comments'),
                onChanged: (v) => setState(() => _allowComments = v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Flow 3 â€” Create a Community Question
class SakhiQuestionComposerScreen extends StatefulWidget {
  const SakhiQuestionComposerScreen({
    super.key,
    this.onPublished,
    this.initialCategory,
  });

  final VoidCallback? onPublished;
  final String? initialCategory;

  @override
  State<SakhiQuestionComposerScreen> createState() =>
      _SakhiQuestionComposerScreenState();
}

class _SakhiQuestionComposerScreenState
    extends State<SakhiQuestionComposerScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  late String _categorySlug;
  String _visibility = 'VERIFIED_MEMBERS';
  final Set<String> _topicTags = <String>{'#Question'};
  bool _allowComments = true;
  bool _isPublishing = false;

  static const List<String> _questionTopics = [
    '#Question',
    '#SafetyAdvice',
    '#CareerSupport',
    '#HealthAndWellness',
    '#LocalRecommendations',
    '#WomenEntrepreneurs',
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCategory;
    _categorySlug =
        (initial != null && sakhiPostCategoryLabels.containsKey(initial))
        ? initial
        : 'community';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  bool get _hasDraft =>
      _titleController.text.trim().isNotEmpty ||
      _detailsController.text.trim().isNotEmpty;

  Future<bool> _confirmDiscard() async {
    if (!_hasDraft || _isPublishing) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard question?'),
        content: const Text('Your community question draft will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.sosRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _publish() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _isPublishing) return;
    setState(() => _isPublishing = true);
    final details = _detailsController.text.trim();
    final content = details.isEmpty
        ? 'â“ Question: $title'
        : 'â“ Question: $title\n\n$details';
    final ok = await SakhiPrototypeState.instance.createCommunityPost(
      content,
      categoryBadge: sakhiPostCategoryLabels[_categorySlug] ?? 'Community',
      categorySlug: _categorySlug,
      visibility: _visibility,
      hashtags: _topicTags.toList(),
      allowComments: _allowComments,
    );
    if (!mounted) return;
    setState(() => _isPublishing = false);
    if (!ok) {
      SakhiDialogs.showPrototypeSnackbar(
        context,
        'Question could not be published. Check your connection and retry.',
      );
      return;
    }
    SakhiDialogs.showPrototypeSnackbar(
      context,
      'Community question posted to the Social Wall!',
    );
    widget.onPublished?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canPost = _titleController.text.trim().isNotEmpty && !_isPublishing;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard() && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (await _confirmDiscard() && mounted) {
                navigator.pop();
              }
            },
          ),
          title: const Text('Ask a Question'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: canPost ? _publish : null,
                child: Text(_isPublishing ? 'Postingâ€¦' : 'Post'),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                maxLength: 140,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Question Title *',
                  hintText: 'What would you like to ask the community?',
                  prefixIcon: Icon(Icons.help_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _detailsController,
                maxLines: 5,
                maxLength: 400,
                decoration: const InputDecoration(
                  labelText: 'Details / Context (optional)',
                  hintText:
                      'Add helpful context so members can give relevant answersâ€¦',
                ),
              ),
              const SizedBox(height: 12),
              Text('Topic Tags', style: AppTypography.bodyMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _questionTopics.map((tag) {
                  final selected = _topicTags.contains(tag);
                  return SakhiChip(
                    label: tag,
                    isSelected: selected,
                    onTap: () => setState(() {
                      if (selected && _topicTags.length > 1) {
                        _topicTags.remove(tag);
                      } else {
                        _topicTags.add(tag);
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _categorySlug,
                decoration: const InputDecoration(labelText: 'Category'),
                items: sakhiPostCategoryLabels.entries
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _categorySlug = v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _visibility,
                decoration: const InputDecoration(labelText: 'Audience'),
                items: sakhiPostAudiences.entries
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _visibility = v);
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _allowComments,
                activeThumbColor: AppColors.primaryPurple,
                title: const Text('Allow member answers & comments'),
                onChanged: (v) => setState(() => _allowComments = v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Flow 4 â€” Share a Useful Resource
class SakhiResourceComposerScreen extends StatefulWidget {
  const SakhiResourceComposerScreen({super.key, this.onPublished});

  final VoidCallback? onPublished;

  @override
  State<SakhiResourceComposerScreen> createState() =>
      _SakhiResourceComposerScreenState();
}

class _SakhiResourceComposerScreenState
    extends State<SakhiResourceComposerScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _linkOrContactController =
      TextEditingController();
  String _resourceType = 'Safety';
  String _visibility = 'VERIFIED_MEMBERS';
  bool _isPublishing = false;

  static const Map<String, String> _resourceCategoryToSlug = {
    'Safety': 'safety_awareness',
    'Health': 'wellness_lifestyle',
    'Legal': 'safety_awareness',
    'Emergency': 'safety_awareness',
    'Support': 'community',
    'Community': 'community',
  };

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _linkOrContactController.dispose();
    super.dispose();
  }

  bool get _hasDraft =>
      _titleController.text.trim().isNotEmpty ||
      _descriptionController.text.trim().isNotEmpty ||
      _linkOrContactController.text.trim().isNotEmpty;

  Future<bool> _confirmDiscard() async {
    if (!_hasDraft || _isPublishing) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard resource?'),
        content: const Text('Your resource draft will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.sosRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _publish() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty || description.isEmpty || _isPublishing) return;

    setState(() => _isPublishing = true);
    final contact = _linkOrContactController.text.trim();
    final categorySlug = _resourceCategoryToSlug[_resourceType] ?? 'community';
    final formatted = StringBuffer()
      ..writeln('ðŸ“˜ Resource ($_resourceType): $title')
      ..writeln(description);
    if (contact.isNotEmpty) {
      formatted.writeln('ðŸ”— Contact / Link: $contact');
    }

    final ok = await SakhiPrototypeState.instance.createCommunityPost(
      formatted.toString().trim(),
      categoryBadge: sakhiPostCategoryLabels[categorySlug] ?? 'Community',
      categorySlug: categorySlug,
      visibility: _visibility,
      hashtags: <String>['#${_resourceType}Resource', '#SakhiSupport'],
    );
    if (!mounted) return;
    setState(() => _isPublishing = false);
    if (!ok) {
      SakhiDialogs.showPrototypeSnackbar(
        context,
        'Resource could not be shared. Check your connection and retry.',
      );
      return;
    }
    SakhiDialogs.showPrototypeSnackbar(
      context,
      'Resource shared with the Sakhi community!',
    );
    widget.onPublished?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canShare =
        _titleController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().isNotEmpty &&
        !_isPublishing;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard() && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (await _confirmDiscard() && mounted) {
                navigator.pop();
              }
            },
          ),
          title: const Text('Share Resource'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: canShare ? _publish : null,
                child: Text(_isPublishing ? 'Sharingâ€¦' : 'Share'),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                maxLength: 120,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Resource Title *',
                  hintText: 'e.g., 24Ã—7 Women Legal Aid Helpline & Guide',
                  prefixIcon: Icon(Icons.menu_book_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _resourceType,
                decoration: const InputDecoration(
                  labelText: 'Resource Category',
                ),
                items: _resourceCategoryToSlug.keys
                    .map(
                      (k) => DropdownMenuItem<String>(value: k, child: Text(k)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _resourceType = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 5,
                maxLength: 400,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Description / How it helps *',
                  hintText:
                      'Summarize key details so other members know how to use this resourceâ€¦',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _linkOrContactController,
                decoration: const InputDecoration(
                  labelText: 'Reference Link or Helpline Number (optional)',
                  hintText: 'https://â€¦ or phone number',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _visibility,
                decoration: const InputDecoration(labelText: 'Audience'),
                items: sakhiPostAudiences.entries
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _visibility = v);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

