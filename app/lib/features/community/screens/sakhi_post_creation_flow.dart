import 'dart:math' as math;
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
import '../../../core/widgets/sakhi_card.dart';
import '../../../core/widgets/sakhi_chip.dart';
import '../../../core/widgets/sakhi_create_hub_sheet.dart';
import '../../../core/widgets/sakhi_dialogs.dart';

const Map<String, String> sakhiPostCategoryLabels = {
  'community': 'Community',
  'trending': 'Trending',
  'business_updates': 'Business Updates',
  'safety_awareness': 'Safety Awareness',
  'wellness_lifestyle': 'Wellness & Lifestyle',
};

const Map<String, String> sakhiPostTagBadges = {
  'Community': 'Community Update \u2022 Sisterhood Wall',
  'Community Question': 'Community Question \u2022 Advice Welcome',
  'Safety Awareness': 'Safety Awareness \u2022 Verified Alert',
  'Shared Resource': 'Verified Resource \u2022 Community Guide',
  'Business Updates': 'Business Updates \u2022 Women-Owned Spotlight',
  'Wellness & Lifestyle': 'Wellness & Lifestyle \u2022 Mindful Care',
  'Trending': 'Trending \u2022 Sisterhood Highlight',
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

/// Aesthetic studio filter preset with 4x5 color matrix and clean icon + Unicode.
class SakhiStudioFilterPreset {
  final String id;
  final String label;
  final IconData icon;
  final List<double> matrix;
  final List<Color> previewGradient;

  const SakhiStudioFilterPreset({
    required this.id,
    required this.label,
    required this.icon,
    required this.matrix,
    required this.previewGradient,
  });
}

const List<SakhiStudioFilterPreset> sakhiStudioFilters = [
  SakhiStudioFilterPreset(
    id: 'original',
    label: 'Original',
    icon: Icons.auto_awesome_rounded,
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
    icon: Icons.local_florist_rounded,
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
    icon: Icons.wb_sunny_rounded,
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
    icon: Icons.favorite_rounded,
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
    icon: Icons.flare_rounded,
    matrix: <double>[
      1.04, 0.04, 0.04, 0, 14,
      0.04, 1.04, 0.04, 0, 14,
      0.04, 0.04, 1.06, 0, 16,
      0, 0, 0, 1, 0,
    ],
    previewGradient: [Color(0xFFA855F7), Color(0xFFC084FC)],
  ),
  SakhiStudioFilterPreset(
    id: 'warm_peach',
    label: 'Warm Peach',
    icon: Icons.spa_rounded,
    matrix: <double>[
      1.15, 0.05, 0.02, 0, 12,
      0.03, 1.02, 0.02, 0, 6,
      0.0, 0.02, 0.94, 0, 2,
      0, 0, 0, 1, 0,
    ],
    previewGradient: [Color(0xFFFB7185), Color(0xFFFDBA74)],
  ),
];

/// Launches the dedicated composer route for the selected Create Hub action.
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
      builder: (_) => SakhiResourceComposerScreen(onPublished: onPublished),
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
    this.width = 1080,
    this.height = 1350,
  });

  final String name;
  final Uint8List bytes;
  final String contentType;
  final int width;
  final int height;

  double get aspectRatio => height > 0 ? width / height : 4 / 5;
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

/// Session-scoped cache of real user-selected device photos.
final List<_SelectedDevicePhoto> _sessionRecentDevicePhotos =
    <_SelectedDevicePhoto>[];

/// Flow 1 — Instagram-Style Photo & Video Studio Composer
/// Supports real-time 2-finger pinch-to-zoom, 1-finger drag-to-pan at ANY zoom
/// level (even 1.0x when framing a portrait photo inside a 1:1 square),
/// Fit-Full-Image vs Fill-Crop mode, and all 6 feed categories + tag badges.
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
  double _baseScaleZoom = 1.0;
  double _offsetX = 0.0;
  double _offsetY = 0.0;
  bool _fitEntireImage = false;
  bool _showGridOverlay = true;
  bool _isInteractingWithStage = false;
  int _activePointersOnStage = 0;
  bool _isRendering = false;
  bool _isPublishing = false;
  bool _isPickingMedia = false;

  _SelectedDevicePhoto? _selectedPhoto;
  Uint8List? _renderedPhotoBytes;
  _SelectedVideoDraft? _selectedVideo;
  int _selectedQuoteGradientIndex = 0;

  late String _categorySlug;
  late String _selectedTagBadge;
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
    'Tirupati, Andhra Pradesh',
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
    _selectedTagBadge = _defaultBadgeForSlug(_categorySlug);
    if (_sessionRecentDevicePhotos.isNotEmpty) {
      _selectedPhoto = _sessionRecentDevicePhotos.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _renderCroppedPreview();
      });
    }
  }

  String _defaultBadgeForSlug(String slug) {
    return switch (slug) {
      'safety_awareness' => 'Safety Awareness',
      'business_updates' => 'Business Updates',
      'wellness_lifestyle' => 'Wellness & Lifestyle',
      'trending' => 'Trending',
      _ => 'Community',
    };
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
    if (preset == 'Original') {
      return (_selectedPhoto?.aspectRatio ?? (4 / 5)).clamp(0.55, 1.95);
    }
    return switch (preset) {
      '1:1' => 1.0,
      '16:9' => 16 / 9,
      '4:5' => 4 / 5,
      _ => 4 / 5,
    };
  }

  Future<(int, int)> _decodeDimensions(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        final w = frame.image.width;
        final h = frame.image.height;
        frame.image.dispose();
        return (w, h);
      } finally {
        codec.dispose();
      }
    } catch (_) {
      return (1080, 1350);
    }
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
      final (w, h) = await _decodeDimensions(bytes);
      if (!mounted) return;
      final detectedMime = detectMediaContentType(bytes, file.name);
      final normalizedName = normalizeMediaFileName(
        file.name.isEmpty ? 'sakhi_camera_photo.jpg' : file.name,
        detectedMime,
      );
      final item = _SelectedDevicePhoto(
        name: normalizedName,
        bytes: bytes,
        contentType: detectedMime,
        width: w,
        height: h,
      );
      setState(() {
        _selectedVideo = null;
        _selectedPhoto = item;
        _zoom = 1.0;
        _offsetX = 0.0;
        _offsetY = 0.0;
        _fitEntireImage = false;
        _sessionRecentDevicePhotos.removeWhere((p) => p.name == item.name);
        _sessionRecentDevicePhotos.insert(0, item);
        if (_sessionRecentDevicePhotos.length > 12) {
          _sessionRecentDevicePhotos.removeLast();
        }
      });
      await _renderCroppedPreview();
    } catch (_) {
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
      _SelectedDevicePhoto? firstLoaded;
      for (final file in files.take(10)) {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) continue;
        final (w, h) = await _decodeDimensions(bytes);
        final mime = detectMediaContentType(bytes, file.name);
        final name = normalizeMediaFileName(file.name, mime);
        final item = _SelectedDevicePhoto(
          name: name,
          bytes: bytes,
          contentType: mime,
          width: w,
          height: h,
        );
        firstLoaded ??= item;
        _sessionRecentDevicePhotos.removeWhere((p) => p.name == item.name);
        _sessionRecentDevicePhotos.insert(0, item);
      }
      if (_sessionRecentDevicePhotos.length > 12) {
        _sessionRecentDevicePhotos.removeRange(
          12,
          _sessionRecentDevicePhotos.length,
        );
      }
      if (firstLoaded != null && mounted) {
        setState(() {
          _selectedVideo = null;
          _selectedPhoto = firstLoaded;
          _zoom = 1.0;
          _offsetX = 0.0;
          _offsetY = 0.0;
          _fitEntireImage = false;
        });
        await _renderCroppedPreview();
      }
    } catch (_) {
      if (!mounted) return;
      SakhiDialogs.showPrototypeSnackbar(
        context,
        'Could not load multiple photos from gallery.',
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
      final video = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 2),
      );
      if (video == null || !mounted) return;
      final bytes = await video.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty || bytes.length > 15 * 1024 * 1024) {
        SakhiDialogs.showPrototypeSnackbar(
          context,
          'Please select an MP4 or WebM video under 15 MB.',
        );
        return;
      }
      final mime = detectMediaContentType(bytes, video.name);
      final normalized = normalizeMediaFileName(
        video.name.isEmpty ? 'sakhi_video.mp4' : video.name,
        mime.startsWith('video/') ? mime : 'video/mp4',
      );
      setState(() {
        _selectedPhoto = null;
        _renderedPhotoBytes = null;
        _selectedVideo = _SelectedVideoDraft(
          name: normalized,
          bytes: bytes,
          contentType: mime.startsWith('video/') ? mime : 'video/mp4',
        );
      });
    } catch (_) {
      if (!mounted) return;
      SakhiDialogs.showPrototypeSnackbar(
        context,
        'Unable to read the selected video.',
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingMedia = false);
      }
    }
  }

  void _openQuoteCardCreatorSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                        Expanded(
                          child: Text(
                            'Create Sakhi Quote Card',
                            style: AppTypography.sectionTitle,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 190,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors:
                              _quoteCardGradients[_selectedQuoteGradientIndex],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _quoteCardController.text.trim().isEmpty
                            ? 'Type your affirmation, announcement, or sisterhood message below\u2026'
                            : _quoteCardController.text.trim(),
                        textAlign: TextAlign.center,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
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
                        final selected = i == _selectedQuoteGradientIndex;
                        return GestureDetector(
                          onTap: () => setSheetState(
                            () => _selectedQuoteGradientIndex = i,
                          ),
                          child: Container(
                            width: 36,
                            height: 36,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
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
                        hintText:
                            'Write your quote or message for the card\u2026',
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
          text: '\u201c$quoteText\u201d\n\n\u2014 Sakhi Sisterhood',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 52,
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
        width: width,
        height: height,
      );
      setState(() {
        _selectedVideo = null;
        _selectedPhoto = item;
        _renderedPhotoBytes = pngBytes;
        _cropPreset = '4:5';
        _zoom = 1.0;
        _offsetX = 0.0;
        _offsetY = 0.0;
        _fitEntireImage = false;
        _isRendering = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isRendering = false);
    }
  }

  /// Renders the cropped/framed/filtered output image at 1080px width.
  /// Supports:
  /// - Fit Entire Photo (`_fitEntireImage == true` or `_zoom < 1.0`): draws a
  ///   soft plum studio backdrop and fits 100% of the source photo inside the
  ///   target aspect ratio (`1:1`, `4:5`, `16:9`, or `Original`) with pan/zoom.
  /// - Fill Crop Frame (`_fitEntireImage == false` and `_zoom >= 1.0`): crops
  ///   with exact `_offsetX` / `_offsetY` pan and `_zoom` magnification.
  Future<void> _renderCroppedPreview() async {
    final photo = _selectedPhoto;
    if (photo == null) return;
    if (_cropPreset == 'Original' &&
        !_fitEntireImage &&
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
          final srcRatio = src.width / src.height;
          final targetRatio = _cropPreset == 'Original'
              ? srcRatio
              : _aspectRatioValue(_cropPreset);

          const outW = 1080;
          final outH = (outW / targetRatio).round().clamp(360, 1920);
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          final dstRect = Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble());

          // Studio dark plum canvas background (visible when Fit Full Photo or zoomed out < 1.0)
          final bgPaint = Paint()
            ..shader = ui.Gradient.linear(
              const Offset(0, 0),
              Offset(outW.toDouble(), outH.toDouble()),
              const [Color(0xFF280B33), Color(0xFF471254)],
            );
          canvas.drawRect(dstRect, bgPaint);

          final paint = Paint()..filterQuality = FilterQuality.high;
          if (_selectedFilterId != 'original') {
            paint.colorFilter = ColorFilter.matrix(_activeFilter.matrix);
          }

          if (_fitEntireImage || _zoom < 1.0) {
            // Fit entire source image inside outW x outH, scaled by _zoom and shifted by _offsetX/_offsetY
            double drawW;
            double drawH;
            if (srcRatio > targetRatio) {
              drawW = outW.toDouble();
              drawH = drawW / srcRatio;
            } else {
              drawH = outH.toDouble();
              drawW = drawH * srcRatio;
            }
            final scale = _fitEntireImage ? _zoom.clamp(0.5, 3.0) : _zoom;
            drawW *= scale;
            drawH *= scale;
            final centerX = outW / 2.0 - (_offsetX * outW * 0.35);
            final centerY = outH / 2.0 - (_offsetY * outH * 0.35);
            final targetRect = Rect.fromCenter(
              center: Offset(centerX, centerY),
              width: drawW,
              height: drawH,
            );
            canvas.drawImageRect(
              src,
              Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
              targetRect,
              paint,
            );
          } else {
            // Fill crop mode with full pan freedom across both axes
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
            final maxLeft = (src.width - cropW).clamp(
              0.0,
              src.width.toDouble(),
            );
            final maxTop = (src.height - cropH).clamp(
              0.0,
              src.height.toDouble(),
            );
            final left =
                (maxLeft / 2 + _offsetX.clamp(-1.0, 1.0) * (maxLeft / 2))
                    .clamp(0.0, maxLeft);
            final top =
                (maxTop / 2 + _offsetY.clamp(-1.0, 1.0) * (maxTop / 2))
                    .clamp(0.0, maxTop);

            canvas.drawImageRect(
              src,
              Rect.fromLTWH(left, top, cropW, cropH),
              dstRect,
              paint,
            );
          }

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

  void _toggleFitFillMode() {
    setState(() {
      _fitEntireImage = !_fitEntireImage;
      _zoom = 1.0;
      _offsetX = 0.0;
      _offsetY = 0.0;
    });
    _renderCroppedPreview();
  }

  void _nudgeOffset(double dx, double dy) {
    setState(() {
      _offsetX = (_offsetX + dx).clamp(-1.0, 1.0);
      _offsetY = (_offsetY + dy).clamp(-1.0, 1.0);
    });
    _renderCroppedPreview();
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
      if (_selectedPhoto != null && _renderedPhotoBytes == null) {
        await _renderCroppedPreview();
      }
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
        contentType = detectMediaContentType(uploadBytes, _selectedPhoto!.name);
        uploadName = normalizeMediaFileName(_selectedPhoto!.name, contentType);
      }

      final effectiveCropPreset = _cropPreset == 'Original'
          ? ((_selectedPhoto?.aspectRatio ?? 0.8) >= 1.25
                ? '16:9'
                : (_selectedPhoto?.aspectRatio ?? 0.8) >= 0.95
                ? '1:1'
                : '4:5')
          : _cropPreset;

      final uploadRes = await state.uploadMediaFile(
        purpose: 'community_post',
        fileName: uploadName,
        fileBytes: uploadBytes,
        contentType: contentType,
        categorySlug: _categorySlug,
        cropAspectRatio: effectiveCropPreset,
      );
      if (!mounted) return;
      if (uploadRes == null) {
        setState(() => _isPublishing = false);
        SakhiDialogs.showPrototypeSnackbar(
          context,
          'Media upload failed \u2014 your draft is preserved so you can retry.',
        );
        return;
      }

      var caption = _captionController.text.trim();
      if (caption.isEmpty) {
        caption = 'Shared a moment with the Sakhi community';
      }
      if (_selectedTagBadge == 'Community Question' &&
          !caption.toLowerCase().startsWith('community question')) {
        caption = 'Community Question: $caption';
      }

      final hashtags = <String>{..._selectedHashtags};
      if (_selectedTagBadge == 'Community Question') {
        hashtags.add('#Question');
      } else if (_selectedTagBadge == 'Shared Resource') {
        hashtags.add('#SakhiResource');
      }

      final uploadId = uploadRes['uploadId'] ?? '';
      final ok = await state.createCommunityPost(
        caption,
        categoryBadge: _selectedTagBadge,
        categorySlug: _categorySlug,
        visibility: _visibility,
        cropPreset: effectiveCropPreset,
        hashtags: hashtags.toList(),
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
        'Published to the Sakhi Social Wall!',
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

  /// Builds the live 60fps interactive photo viewport inside the stage.
  Widget _buildInteractivePhotoCanvas(_SelectedDevicePhoto photo) {
    final targetRatio = _aspectRatioValue(_cropPreset);
    final srcRatio = photo.aspectRatio;
    final align = Alignment(
      _offsetX.clamp(-1.0, 1.0),
      _offsetY.clamp(-1.0, 1.0),
    );

    // During active finger drag/pinch or when _renderedPhotoBytes hasn't finished,
    // render live transform on source bytes for instant 60fps response.
    final Widget imageWidget;
    if (_isInteractingWithStage || _renderedPhotoBytes == null) {
      final rawImage = ColorFiltered(
        colorFilter: ColorFilter.matrix(_activeFilter.matrix),
        child: Image.memory(
          photo.bytes,
          fit: (_fitEntireImage || _zoom < 1.0)
              ? BoxFit.contain
              : BoxFit.cover,
          alignment: align,
          width: double.infinity,
          height: double.infinity,
          filterQuality: FilterQuality.medium,
        ),
      );
      final effectiveScale = (_fitEntireImage || _zoom < 1.0)
          ? _zoom.clamp(0.5, 3.0)
          : _zoom.clamp(1.0, 3.0);
      final maxPanFactor = _fitEntireImage
          ? 90.0
          : (srcRatio != targetRatio || _zoom > 1.0)
          ? 85.0
          : 45.0;
      imageWidget = Transform.translate(
        offset: Offset(-_offsetX * maxPanFactor, -_offsetY * maxPanFactor),
        child: Transform.scale(
          scale: effectiveScale,
          child: rawImage,
        ),
      );
    } else {
      imageWidget = Image.memory(
        _renderedPhotoBytes!,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.high,
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: targetRatio,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: const Color(0xFF1F0828)),
              imageWidget,
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
    );
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
                _step == 0
                    ? (_selectedVideo != null
                          ? 'New Video Post'
                          : 'New Photo Post')
                    : 'New Post Details',
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
                    _isPublishing ? 'Sharing\u2026' : 'Share',
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
      physics: _isInteractingWithStage
          ? const NeverScrollableScrollPhysics()
          : const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        8,
        AppSpacing.screenPaddingH,
        36,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Interactive Pinch-to-Zoom & Drag-to-Move Studio Stage
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
                  height: 368,
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
                                '${(_selectedVideo!.bytes.length / (1024 * 1024)).toStringAsFixed(2)} MB \u2022 Ready to share',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_selectedPhoto != null)
                        Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (_) {
                            _activePointersOnStage++;
                            if (!_isInteractingWithStage) {
                              setState(() => _isInteractingWithStage = true);
                            }
                          },
                          onPointerUp: (_) {
                            _activePointersOnStage = math.max(
                              0,
                              _activePointersOnStage - 1,
                            );
                            if (_activePointersOnStage == 0 &&
                                _isInteractingWithStage) {
                              setState(() => _isInteractingWithStage = false);
                              _renderCroppedPreview();
                            }
                          },
                          onPointerCancel: (_) {
                            _activePointersOnStage = 0;
                            if (_isInteractingWithStage) {
                              setState(() => _isInteractingWithStage = false);
                              _renderCroppedPreview();
                            }
                          },
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onDoubleTap: _toggleFitFillMode,
                            onScaleStart: (details) {
                              _baseScaleZoom = _zoom;
                            },
                            onScaleUpdate: (details) {
                              setState(() {
                                if (details.pointerCount >= 2 ||
                                    (details.scale - 1.0).abs() > 0.015) {
                                  _zoom = (_baseScaleZoom * details.scale)
                                      .clamp(0.5, 3.0);
                                }
                                _offsetX =
                                    (_offsetX - details.focalPointDelta.dx / 135)
                                        .clamp(-1.0, 1.0);
                                _offsetY =
                                    (_offsetY - details.focalPointDelta.dy / 135)
                                        .clamp(-1.0, 1.0);
                              });
                            },
                            onScaleEnd: (_) {
                              _renderCroppedPreview();
                            },
                            child: _buildInteractivePhotoCanvas(
                              _selectedPhoto!,
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
                                'Share Your Moment',
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
                        IgnorePointer(
                          child: Container(
                            color: Colors.black26,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      if (_selectedPhoto != null) ...[
                        // Top-left Instagram-style Fit Full Photo vs Fill Frame button
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Material(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: _toggleFitFillMode,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _fitEntireImage
                                          ? Icons.fullscreen_rounded
                                          : Icons.fullscreen_exit_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _fitEntireImage
                                          ? 'Fit Full Photo'
                                          : 'Fill Frame',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Bottom helper pill showing pinch & drag instruction
                        Positioned(
                          bottom: 10,
                          left: 14,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Pinch to zoom \u2022 Drag with 1 finger to move',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Top-right Grid, Center & Delete actions
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Row(
                            children: [
                              IconButton.filledTonal(
                                tooltip: 'Center & reset framing',
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _zoom = 1.0;
                                    _offsetX = 0.0;
                                    _offsetY = 0.0;
                                    _fitEntireImage = false;
                                  });
                                  _renderCroppedPreview();
                                },
                                icon: const Icon(
                                  Icons.center_focus_strong_rounded,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 6),
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
                    ],
                  ),
                ),

                // Aspect Ratio, Zoom & Position Controls inside Stage
                if (_selectedPhoto != null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    color: Colors.black.withValues(alpha: 0.30),
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
                                          : 'Original Full',
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
                                      setState(() {
                                        _cropPreset = preset;
                                        _offsetX = 0.0;
                                        _offsetY = 0.0;
                                      });
                                      _renderCroppedPreview();
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.zoom_in_rounded,
                              color: Colors.white70,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 38,
                              child: Text(
                                '${_zoom.toStringAsFixed(1)}\u00D7',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: _zoom.clamp(0.5, 3.0),
                                min: 0.5,
                                max: 3.0,
                                divisions: 25,
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
                                  _fitEntireImage = false;
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
                        // Quick Pan / Position Nudge Bar for 1-Tap Framing
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Move Photo:',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StageNudgeButton(
                              icon: Icons.keyboard_arrow_up_rounded,
                              tooltip: 'Move photo up',
                              onTap: () => _nudgeOffset(0, 0.15),
                            ),
                            _StageNudgeButton(
                              icon: Icons.keyboard_arrow_down_rounded,
                              tooltip: 'Move photo down',
                              onTap: () => _nudgeOffset(0, -0.15),
                            ),
                            _StageNudgeButton(
                              icon: Icons.keyboard_arrow_left_rounded,
                              tooltip: 'Move photo left',
                              onTap: () => _nudgeOffset(0.15, 0),
                            ),
                            _StageNudgeButton(
                              icon: Icons.keyboard_arrow_right_rounded,
                              tooltip: 'Move photo right',
                              onTap: () => _nudgeOffset(-0.15, 0),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white38),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                minimumSize: const Size(0, 30),
                              ),
                              onPressed: _toggleFitFillMode,
                              icon: Icon(
                                _fitEntireImage
                                    ? Icons.crop_free_rounded
                                    : Icons.fit_screen_rounded,
                                size: 14,
                              ),
                              label: Text(
                                _fitEntireImage ? 'Fill Crop' : 'Fit Whole',
                                style: const TextStyle(
                                  fontSize: 11,
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

          // 2. Aesthetic Studio Filters Strip
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
                      width: 86,
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
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: filter.previewGradient,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              filter.icon,
                              color: Colors.white,
                              size: 18,
                            ),
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

          // 3. Studio Action Tiles (Camera, Gallery, Multi-Photo, Video, Create with Template)
          const SizedBox(height: 16),
          Text(
            'Choose your moment',
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
                  label: 'Create with Template',
                  subtitle: 'Quote & story card',
                  gradient: const [Color(0xFF0D9488), Color(0xFF115E59)],
                  onTap: _openQuoteCardCreatorSheet,
                ),
              ),
            ],
          ),

          // 4. Real Device Photos Selected in This Session
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
              padding: EdgeInsets.zero,
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
                      _fitEntireImage = false;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 88,
                        height: 88,
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
                                fit: BoxFit.contain,
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
                              'Write a warm caption, story, or #hashtags for your Sakhis\u2026',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.pastelLavender,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_outlined,
                        size: 14,
                        color: AppColors.primaryPurple,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Post Tag Preview: ${sakhiPostTagBadges[_selectedTagBadge] ?? _selectedTagBadge}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Choose Post Tag Badge (Displayed on Your Post)',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sakhiPostTagBadges.keys.map((badgeKey) {
              final selected = _selectedTagBadge == badgeKey;
              return SakhiChip(
                label: badgeKey,
                isSelected: selected,
                onTap: () => setState(() {
                  _selectedTagBadge = badgeKey;
                  if (badgeKey == 'Safety Awareness') {
                    _categorySlug = 'safety_awareness';
                  } else if (badgeKey == 'Business Updates') {
                    _categorySlug = 'business_updates';
                  } else if (badgeKey == 'Wellness & Lifestyle') {
                    _categorySlug = 'wellness_lifestyle';
                  } else if (badgeKey == 'Trending') {
                    _categorySlug = 'trending';
                  } else {
                    _categorySlug = 'community';
                  }
                }),
              );
            }).toList(),
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
              if (value != null) {
                setState(() {
                  _categorySlug = value;
                  _selectedTagBadge = _defaultBadgeForSlug(value);
                });
              }
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
                    ? 'Uploading & Publishing\u2026'
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

class _StageNudgeButton extends StatelessWidget {
  const _StageNudgeButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white24,
          foregroundColor: Colors.white,
          minimumSize: const Size(30, 30),
          padding: EdgeInsets.zero,
        ),
        icon: Icon(icon, size: 18),
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

/// Flow 2 — Write a Text Post
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
  late String _selectedTagBadge;
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
    _selectedTagBadge = sakhiPostCategoryLabels[_categorySlug] ?? 'Community';
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
    var body = _textController.text.trim();
    if (body.isEmpty || _isPublishing) return;
    setState(() => _isPublishing = true);
    if (_selectedTagBadge == 'Community Question' &&
        !body.toLowerCase().startsWith('community question')) {
      body = 'Community Question: $body';
    }
    final ok = await SakhiPrototypeState.instance.createCommunityPost(
      body,
      categoryBadge: _selectedTagBadge,
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
                child: Text(_isPublishing ? 'Posting\u2026' : 'Post'),
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
                        Text(_selectedTagBadge, style: AppTypography.caption),
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
                  hintText: 'Share a thought, experience, or update\u2026',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Post Tag Badge',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: sakhiPostTagBadges.keys.map((badgeKey) {
                  return SakhiChip(
                    label: badgeKey,
                    isSelected: _selectedTagBadge == badgeKey,
                    onTap: () => setState(() => _selectedTagBadge = badgeKey),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
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
                  if (v != null) {
                    setState(() {
                      _categorySlug = v;
                      _selectedTagBadge =
                          sakhiPostCategoryLabels[v] ?? 'Community';
                    });
                  }
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

/// Flow 3 — Create a Community Question
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
        ? 'Community Question: $title'
        : 'Community Question: $title\n\n$details';
    final ok = await SakhiPrototypeState.instance.createCommunityPost(
      content,
      categoryBadge: 'Community Question',
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
                child: Text(_isPublishing ? 'Posting\u2026' : 'Post'),
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
                      'Add helpful context so members can give relevant answers\u2026',
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

/// Flow 4 — Share a Useful Resource
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
      ..writeln('Resource ($_resourceType): $title')
      ..writeln(description);
    if (contact.isNotEmpty) {
      formatted.writeln('Contact / Link: $contact');
    }

    final ok = await SakhiPrototypeState.instance.createCommunityPost(
      formatted.toString().trim(),
      categoryBadge: '$_resourceType Resource',
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
                child: Text(_isPublishing ? 'Sharing\u2026' : 'Share'),
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
                  hintText: 'e.g., 24\u00D77 Women Legal Aid Helpline & Guide',
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
                      'Summarize key details so other members know how to use this resource\u2026',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _linkOrContactController,
                decoration: const InputDecoration(
                  labelText: 'Reference Link or Helpline Number (optional)',
                  hintText: 'https://\u2026 or phone number',
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
