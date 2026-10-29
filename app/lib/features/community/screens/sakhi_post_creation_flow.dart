import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_avatar.dart';
import '../../../core/widgets/sakhi_buttons.dart';
import '../../../core/widgets/sakhi_card.dart';
import '../../../core/widgets/sakhi_chip.dart';
import '../../../core/widgets/sakhi_create_hub_sheet.dart';
import '../../business/screens/business_hub_screen.dart';
import '../../complaints/screens/discreet_complaint_hub_screen.dart';

const Map<String, String> sakhiPostCategories = {
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
      builder: (_) => SakhiTextPostComposerScreen(
        initialMode: SakhiTextPostMode.question,
        onPublished: onPublished,
        initialCategory: initialCategory,
      ),
    ),
    SakhiCreateAction.usefulResource => MaterialPageRoute<void>(
      builder: (_) => SakhiTextPostComposerScreen(
        initialMode: SakhiTextPostMode.resource,
        onPublished: onPublished,
        initialCategory: initialCategory ?? 'safety_awareness',
      ),
    ),
    SakhiCreateAction.womenBusinessPage => MaterialPageRoute<void>(
      builder: (_) => const WomenBusinessHubScreen(showBackButton: true),
    ),
    SakhiCreateAction.discreetComplaint => MaterialPageRoute<void>(
      builder: (_) => const DiscreetComplaintHubScreen(),
    ),
  };
  await Navigator.of(context).push(route);
}

class _SakhiRecentPhoto {
  const _SakhiRecentPhoto({
    required this.file,
    required this.bytes,
    required this.ratio,
  });

  final XFile file;
  final Uint8List bytes;
  final double ratio;
}

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
  final _picker = ImagePicker();
  final _captionController = TextEditingController();
  final _locationController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  final List<_SakhiRecentPhoto> _recentPhotos = <_SakhiRecentPhoto>[];

  int _step = 0;
  XFile? _pickedFile;
  Uint8List? _sourceBytes;
  Uint8List? _previewBytes;
  String? _fileName;
  String _contentType = '';
  double _originalRatio = 4 / 5;
  String _cropPreset = '4:5';
  String _category = 'wellness_lifestyle';
  String _audience = 'VERIFIED_MEMBERS';
  bool _isVideo = false;
  bool _isTemplate = false;
  bool _tagLocation = false;
  bool _allowComments = true;
  bool _shareBusiness = false;
  bool _businessExpanded = false;
  bool _uploading = false;
  int _progress = 0;
  String? _error;

  SakhiPrototypeState get _state => SakhiPrototypeState.instance;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCategory;
    if (initial != null && sakhiPostCategories.containsKey(initial)) {
      _category = initial;
    }
    unawaited(_restoreDraft());
  }

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  double _aspect(String preset) => switch (preset) {
    'Original' => _originalRatio,
    '1:1' => 1,
    '16:9' => 16 / 9,
    _ => 4 / 5,
  };

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 88,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
        _message(
          'Images must be 10 MB or smaller. Choose a JPG, PNG, or WebP image.',
        );
        return;
      }
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final ratio = frame.image.width / frame.image.height;
      frame.image.dispose();
      codec.dispose();
      if (!mounted) return;
      setState(() {
        _pickedFile = file;
        _sourceBytes = bytes;
        _recentPhotos.removeWhere((item) => item.file.path == file.path);
        _recentPhotos.insert(
          0,
          _SakhiRecentPhoto(file: file, bytes: bytes, ratio: ratio),
        );
        if (_recentPhotos.length > 6) _recentPhotos.removeLast();
        _previewBytes = bytes;
        _fileName = file.name;
        _contentType = _imageType(file.name);
        _originalRatio = ratio;
        _isVideo = false;
        _isTemplate = false;
        _cropPreset = '4:5';
        _error = null;
      });
      await _applyCrop();
    } catch (_) {
      if (mounted) {
        _message('The selected photo could not be opened. Try another image.');
      }
    }
  }

  Future<void> _selectRecentPhoto(_SakhiRecentPhoto photo) async {
    setState(() {
      _pickedFile = photo.file;
      _sourceBytes = photo.bytes;
      _previewBytes = photo.bytes;
      _fileName = photo.file.name;
      _contentType = _imageType(photo.file.name);
      _originalRatio = photo.ratio;
      _cropPreset = '4:5';
      _isVideo = false;
      _isTemplate = false;
      _error = null;
    });
    await _applyCrop();
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 60),
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 50 * 1024 * 1024) {
        _message('Video must be under 60 seconds and 50 MB.');
        return;
      }
      if (!file.name.toLowerCase().endsWith('.mp4') ||
          bytes.length < 12 ||
          String.fromCharCodes(bytes.sublist(4, 8)) != 'ftyp') {
        _message(
          'Select a valid MP4 video. Other video formats are not supported.',
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _pickedFile = file;
        _sourceBytes = bytes;
        _previewBytes = null;
        _fileName = file.name;
        _contentType = 'video/mp4';
        _isVideo = true;
        _isTemplate = false;
        _originalRatio = 16 / 9;
        _cropPreset = '16:9';
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        _message('Unable to read that video. Select an MP4 under 50 MB.');
      }
    }
  }

  String _imageType(String name) {
    return switch (name.toLowerCase().split('.').last) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'image/png',
    };
  }

  Future<void> _applyCrop() async {
    final source = _sourceBytes;
    if (source == null || _isVideo || _isTemplate) return;
    if (_cropPreset == 'Original') {
      setState(() {
        _previewBytes = source;
        _contentType = _imageType(_fileName ?? 'photo.png');
      });
      return;
    }
    try {
      final codec = await ui.instantiateImageCodec(source);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final targetRatio = _aspect(_cropPreset);
      final sourceRatio = image.width / image.height;
      double cropWidth = image.width.toDouble();
      double cropHeight = image.height.toDouble();
      if (sourceRatio > targetRatio) {
        cropWidth = cropHeight * targetRatio;
      } else {
        cropHeight = cropWidth / targetRatio;
      }
      final left = (image.width - cropWidth) / 2;
      final top = (image.height - cropHeight) / 2;
      const outputWidth = 1080;
      final outputHeight = (outputWidth / targetRatio).round();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(left, top, cropWidth, cropHeight),
        Rect.fromLTWH(0, 0, outputWidth.toDouble(), outputHeight.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(outputWidth, outputHeight);
      final encoded = await cropped.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      cropped.dispose();
      picture.dispose();
      codec.dispose();
      if (!mounted || encoded == null) return;
      setState(() {
        _previewBytes = encoded.buffer.asUint8List();
        _contentType = 'image/png';
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        _message('Crop preview failed. Your original photo is preserved.');
      }
    }
  }

  Future<void> _showMediaPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose media', style: AppTypography.sectionTitle),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Photo from Gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Video from Gallery (MP4)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickVideo(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Record a Video'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickVideo(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTemplatePicker() async {
    const templates = <(String, Color)>[
      ('Soft Pink', Color(0xFFFDF4F7)),
      ('Lavender', Color(0xFFF5EBF9)),
      ('Cream', Color(0xFFFFF8F0)),
      ('Floral Plum', Color(0xFF5D196A)),
    ];
    final chosen = await showModalBottomSheet<(String, Color)>(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: templates.map((template) {
              final light = template.$1 != 'Floral Plum';
              return SizedBox(
                width: 145,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.pop(sheetContext, template),
                  child: Container(
                    height: 100,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: template.$2,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Center(
                      child: Text(
                        template.$1,
                        style: TextStyle(
                          color: light ? AppColors.textPrimary : Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
    if (chosen == null) return;
    final bytes = await _renderQuoteTemplate(chosen.$2);
    if (!mounted) return;
    setState(() {
      _sourceBytes = bytes;
      _previewBytes = bytes;
      _pickedFile = null;
      _fileName = 'sakhi_quote_template.png';
      _contentType = 'image/png';
      _isVideo = false;
      _isTemplate = true;
      _originalRatio = 4 / 5;
      _cropPreset = '4:5';
      if (_captionController.text.trim().isEmpty) {
        _captionController.text = 'A gentle reminder: you deserve kindness, rest, and support. #SakhiCommunity';
      }
      _error = null;
    });
  }

  Future<Uint8List> _renderQuoteTemplate(Color background) async {
    const width = 1080;
    const height = 1350;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(background, BlendMode.src);
    final isDark = background == const Color(0xFF5D196A);
    final foreground = isDark ? Colors.white : const Color(0xFF2A1130);
    final petalPaint = Paint()
      ..color = const Color(0xFFD88FB1).withValues(alpha: 0.38);
    for (var i = 0; i < 9; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(830 + (i % 3) * 48, 160 + (i % 5) * 48),
          width: 42,
          height: 78,
        ),
        petalPaint,
      );
    }
    final heading = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 48,
        fontWeight: FontWeight.w700,
        fontFamily: 'serif',
      ),
    )..pushStyle(ui.TextStyle(color: foreground));
    heading.addText('A little reminder');
    final headingParagraph = heading.build()
      ..layout(const ui.ParagraphConstraints(width: 820));
    canvas.drawParagraph(headingParagraph, const Offset(130, 470));
    final quote = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 62, height: 1.3),
    )..pushStyle(ui.TextStyle(color: foreground));
    quote.addText('You deserve kindness, rest, and support.');
    final quoteParagraph = quote.build()
      ..layout(const ui.ParagraphConstraints(width: 820));
    canvas.drawParagraph(quoteParagraph, const Offset(130, 570));
    final brand = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 30,
        fontWeight: FontWeight.w700,
      ),
    )..pushStyle(ui.TextStyle(color: foreground.withValues(alpha: .86)));
    brand.addText('Sakhi  •  A safe space for every woman');
    final brandParagraph = brand.build()
      ..layout(const ui.ParagraphConstraints(width: 920));
    canvas.drawParagraph(brandParagraph, const Offset(80, 1180));
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Template export failed.');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }

  Future<bool> _confirmDiscard() async {
    if (_sourceBytes == null && _captionController.text.trim().isEmpty) {
      return true;
    }
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard this draft?'),
        content: const Text('Your media and caption have not been shared.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  Future<void> _back() async {
    if (_uploading) return;
    if (_step == 1) {
      setState(() => _step = 0);
      return;
    }
    if (await _confirmDiscard() && mounted) Navigator.pop(context);
  }

  Future<void> _publish() async {
    if (_uploading) return;
    final bytes = _previewBytes ?? _sourceBytes;
    if (bytes == null || _fileName == null) {
      _message('Select a photo, video, or Sakhi template before continuing.');
      setState(() => _step = 0);
      return;
    }
    final caption = _captionController.text.trim();
    if (caption.length > 500) {
      _message('Captions must be 500 characters or fewer.');
      return;
    }
    if (caption.isEmpty && !_isTemplate) {
      _message('Add a caption before sharing your media.');
      return;
    }
    if (_tagLocation && _locationController.text.trim().isEmpty) {
      _message(
        'Enter a general city or neighbourhood, or turn off location tagging.',
      );
      return;
    }
    setState(() {
      _step = 2;
      _uploading = true;
      _progress = 8;
      _error = null;
    });
    try {
      final uploaded = await _state.uploadMediaFile(
        purpose: 'community_post',
        fileName: _fileName!,
        fileBytes: bytes,
        contentType: _contentType,
        categorySlug: _category,
        cropAspectRatio: _cropPreset == 'Original' ? '4:5' : _cropPreset,
      );
      if (!mounted) return;
      final uploadId = uploaded?['uploadId'];
      if (uploadId == null || uploadId.isEmpty) {
        throw StateError('The media API did not confirm the upload.');
      }
      setState(() => _progress = 65);
      final published = await _state.createCommunityPost(
        caption,
        categoryBadge: sakhiPostCategories[_category],
        categorySlug: _category,
        visibility: _audience,
        cropPreset: _cropPreset == 'Original' ? '4:5' : _cropPreset,
        hashtags: _extractHashtags(caption),
        locationTag: _tagLocation ? _locationController.text.trim() : '',
        allowComments: _allowComments,
        shareToBusinessProfile: _shareBusiness,
        mediaUploadIds: [uploadId],
      );
      if (!mounted) return;
      if (!published) {
        throw StateError('The post record was not confirmed by Sakhi.');
      }
      await _storage.delete(key: 'sakhi_media_post_draft');
      if (!mounted) return;
      setState(() {
        _progress = 100;
        _uploading = false;
        _step = 3;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _step = 1;
        _error = 'Upload interrupted. Your media and caption are still here. Check your connection and retry.';
      });
    }
  }

  List<String> _extractHashtags(String value) =>
      RegExp(r'#[A-Za-z0-9_]+')
          .allMatches(value)
          .map((match) => match.group(0)!)
          .toSet()
          .toList(growable: false);

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final linkedBusiness = (_state.currentUser.businessProfileUrl ?? '')
        .trim()
        .isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leadingWidth: 100,
        leading: TextButton(
          onPressed: _uploading ? null : _back,
          child: Text(_step == 1 ? '‹ Back' : '‹ Discard'),
        ),
        title: Text(
          _step == 0
              ? 'New Photo Post'
              : _step == 1
              ? 'Post Settings'
              : _step == 2
              ? 'Uploading Post'
              : 'Post Published',
          style: AppTypography.appBarTitle,
        ),
        actions: [
          if (_step == 0)
            TextButton(
              onPressed: _sourceBytes == null || _uploading
                  ? null
                  : () async {
                      await _saveDraft();
                      if (mounted) {
                        setState(() {
                          _step = 1;
                          _error = null;
                        });
                      }
                    },
              child: const Text('Next ›'),
            ),
          if (_step == 1)
            TextButton(
              onPressed: _uploading ? null : _publish,
              child: const Text('Share Post'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: _step == 3
            ? _buildSuccess()
            : _step == 2
            ? _buildProgress()
            : _step == 0
            ? _buildMediaStep()
            : _buildDetailsStep(linkedBusiness),
      ),
    );
  }

  Future<void> _saveDraft() async {
    try {
      await _storage.write(
        key: 'sakhi_media_post_draft',
        value: jsonEncode({
          'caption': _captionController.text,
          'category': _category,
          'audience': _audience,
          'cropPreset': _cropPreset,
          'location': _locationController.text,
          'tagLocation': _tagLocation,
          'allowComments': _allowComments,
          'shareBusiness': _shareBusiness,
          'filePath': _pickedFile?.path,
          'fileName': _fileName,
          'contentType': _contentType,
          'isVideo': _isVideo,
        }),
      );
    } catch (_) {
      // Draft remains available in memory for the current route.
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final raw = await _storage.read(key: 'sakhi_media_post_draft');
      if (raw == null || raw.isEmpty || !mounted) return;
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return;
      _captionController.text = data['caption']?.toString() ?? '';
      _category = sakhiPostCategories.containsKey(data['category'])
          ? data['category'] as String
          : _category;
      _audience = sakhiPostAudiences.containsKey(data['audience'])
          ? data['audience'] as String
          : _audience;
      _cropPreset = data['cropPreset']?.toString() ?? _cropPreset;
      _locationController.text = data['location']?.toString() ?? '';
      _tagLocation = data['tagLocation'] == true;
      _allowComments = data['allowComments'] != false;
      _shareBusiness = data['shareBusiness'] == true;
      final path = data['filePath']?.toString();
      final name = data['fileName']?.toString();
      if (path != null && name != null && path.isNotEmpty) {
        final file = XFile(path);
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty && mounted) {
          setState(() {
            _pickedFile = file;
            _sourceBytes = bytes;
            _previewBytes = bytes;
            _fileName = name;
            _contentType = data['contentType']?.toString() ?? '';
            _isVideo = data['isVideo'] == true;
            _originalRatio = _isVideo ? 16 / 9 : _originalRatio;
            _step = 1;
          });
          return;
        }
      }
      if (mounted) setState(() {});
    } catch (_) {
      // An expired temporary gallery URI is not a reason to block composing.
    }
  }

  Widget _buildMediaStep() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 96),
    children: [
      const Text('Choose your moment', style: AppTypography.sectionTitle),
      const SizedBox(height: 12),
      if (_sourceBytes == null)
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _showMediaPicker,
          child: Container(
            height: 370,
            decoration: BoxDecoration(
              color: AppColors.pastelLavender,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 46,
                  color: AppColors.primaryPurple,
                ),
                SizedBox(height: 12),
                Text(
                  'Select a photo or video',
                  style: AppTypography.sectionTitle,
                ),
                SizedBox(height: 6),
                Text('Your preview appears here before you share.'),
              ],
            ),
          ),
        )
      else
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: _aspect(_cropPreset).clamp(.56, 1.9),
            child: _isVideo
                ? Container(
                    color: AppColors.textPrimary,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.play_circle_outline_rounded,
                          size: 62,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _fileName ?? 'MP4 selected',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const Text(
                          'MP4 • max 60 seconds • 50 MB',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  )
                : Image.memory(
                    _previewBytes ?? _sourceBytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
          ),
        ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _showMediaPicker,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Gallery'),
          ),
          OutlinedButton.icon(
            onPressed: () => _pickPhoto(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Camera'),
          ),
          OutlinedButton.icon(
            onPressed: _showTemplatePicker,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Create with Template'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text('Recent Photos', style: AppTypography.bodyMedium),
          Text('All Albums ›', style: AppTypography.subtitle),
        ],
      ),
      const SizedBox(height: 8),
      if (_recentPhotos.isEmpty)
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
          children:
              const [
                AppAssets.breathingExerciseIllustration,
                AppAssets.greetingHeroIllustration,
                AppAssets.educationCareerHubBanner,
                AppAssets.dailyRitualBreathingThumb,
                AppAssets.emptySafetyShieldIllustration,
                AppAssets.profileHeaderBanner,
              ].map((assetPath) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(assetPath, fit: BoxFit.cover),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(
                          Icons.radio_button_unchecked_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
      if (_recentPhotos.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text('Recent selections', style: AppTypography.bodyMedium),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
          children: _recentPhotos.map((photo) {
            final selected = photo.file.path == _pickedFile?.path;
            return Material(
              color: AppColors.pastelLavender,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _selectRecentPhoto(photo),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(photo.bytes, fit: BoxFit.cover),
                    if (selected)
                      Container(
                        color: AppColors.primaryPurple.withValues(alpha: .16),
                      ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected
                            ? AppColors.primaryPurple
                            : Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black45, blurRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
      if (_sourceBytes != null && !_isVideo && !_isTemplate) ...[
        const SizedBox(height: 16),
        const Text('Crop Preview', style: AppTypography.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['Original', '1:1', '4:5', '16:9'].map((preset) {
            return SakhiChip(
              label: preset,
              isSelected: _cropPreset == preset,
              onTap: () async {
                setState(() => _cropPreset = preset);
                await _applyCrop();
                await _saveDraft();
              },
            );
          }).toList(),
        ),
      ],
      if (_fileName != null) ...[
        const SizedBox(height: 10),
        Text(
          _fileName!,
          style: AppTypography.subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        child: SakhiPillButton(
          label: 'Next',
          onPressed: _sourceBytes == null
              ? null
              : () async {
                  await _saveDraft();
                  if (mounted) setState(() => _step = 1);
                },
        ),
      ),
    ],
  );

  Widget _buildDetailsStep(bool linkedBusiness) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 96),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 76,
              height: 94,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.pastelLavender,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _isVideo
                  ? const Icon(Icons.play_circle_outline_rounded, size: 36)
                  : Image.memory(
                      _previewBytes ?? _sourceBytes!,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _captionController,
                maxLength: 500,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Write a caption and #hashtags...',
                  alignLabelWithHint: true,
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_captionController.text.length}/500',
            style: AppTypography.subtitle,
          ),
        ),
        const SizedBox(height: 10),
        SakhiCard(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              ListTile(
                title: const Text('Category', style: AppTypography.bodyMedium),
                subtitle: Text(sakhiPostCategories[_category] ?? 'Community'),
                trailing: const Icon(Icons.keyboard_arrow_down_rounded),
                onTap: () => _chooseValue(
                  title: 'Choose a category',
                  values: sakhiPostCategories.entries
                      .map((e) => MapEntry(e.key, e.value))
                      .toList(),
                  selected: _category,
                  onSelect: (value) => setState(() => _category = value),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text(
                  'Visibility',
                  style: AppTypography.bodyMedium,
                ),
                subtitle: Text(sakhiPostAudiences[_audience]!),
                trailing: const Icon(Icons.keyboard_arrow_down_rounded),
                onTap: () => _chooseValue(
                  title: 'Who can see this post?',
                  values: const [
                    MapEntry('VERIFIED_MEMBERS', 'All Verified Members'),
                    MapEntry('FOLLOWERS_ONLY', 'Followers Only'),
                    MapEntry('PRIVATE_SELF', 'Only Me'),
                  ],
                  selected: _audience,
                  onSelect: (value) => setState(() => _audience = value),
                ),
              ),
            ],
          ),
        ),
        Material(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          child: SwitchListTile(
            value: _tagLocation,
            activeThumbColor: AppColors.primaryPurple,
            title: const Text('Add Location Tag (Optional)'),
            subtitle: const Text(
              'Off by default; city or neighbourhood only.',
              style: AppTypography.subtitle,
            ),
            onChanged: (value) => setState(() => _tagLocation = value),
          ),
        ),
        if (_tagLocation)
          TextField(
            controller: _locationController,
            maxLength: 120,
            decoration: const InputDecoration(
              hintText: 'City / neighbourhood (no live GPS)',
            ),
          ),
        Material(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          child: SwitchListTile(
            value: _allowComments,
            activeThumbColor: AppColors.primaryPurple,
            title: const Text('Allow member comments'),
            subtitle: const Text(
              'Turn off to disable comments on this post.',
              style: AppTypography.subtitle,
            ),
            onChanged: (value) => setState(() => _allowComments = value),
          ),
        ),
        SakhiCard(
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            initiallyExpanded: _businessExpanded,
            onExpansionChanged: (value) =>
                setState(() => _businessExpanded = value),
            title: const Text(
              'Additional Settings (Business Profile)',
              style: AppTypography.bodyMedium,
            ),
            children: [
              if (linkedBusiness)
                SwitchListTile(
                  value: _shareBusiness,
                  activeThumbColor: AppColors.primaryPurple,
                  title: const Text(
                    'Feature on my Women-Owned Business profile',
                  ),
                  onChanged: (value) => setState(() => _shareBusiness = value),
                )
              else
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    'Available after an eligible business page is linked.',
                    style: AppTypography.subtitle,
                  ),
                ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          _InlineError(message: _error!),
          OutlinedButton(
            onPressed: _uploading ? null : _publish,
            child: const Text('Retry Upload'),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: SakhiPillButton(
            label: 'Share Post',
            onPressed: _uploading ? null : _publish,
          ),
        ),
      ],
    );
  }

  Widget _buildProgress() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_upload_outlined,
            color: AppColors.primaryPurple,
            size: 52,
          ),
          const SizedBox(height: 12),
          const Text('Uploading post...', style: AppTypography.sectionTitle),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: _progress / 100,
            color: AppColors.primaryPurple,
            minHeight: 5,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 8),
          Text('$_progress%', style: AppTypography.subtitle),
          const SizedBox(height: 8),
          const Text(
            'Sakhi saves your media first, then creates the post record.',
            textAlign: TextAlign.center,
            style: AppTypography.subtitle,
          ),
        ],
      ),
    ),
  );

  Widget _buildSuccess() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: Color(0xFFE6F6EE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF1E7E52),
              size: 44,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Post shared successfully',
            style: AppTypography.sectionTitle,
          ),
          const SizedBox(height: 8),
          Text(
            'Post shared to ${sakhiPostCategories[_category] ?? 'Community'}!',
            textAlign: TextAlign.center,
            style: AppTypography.bodyRegular,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: SakhiPillButton(
              label: 'View in Social Wall',
              onPressed: () {
                widget.onPublished?.call();
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _chooseValue({
    required String title,
    required List<MapEntry<String, String>> values,
    required String selected,
    required ValueChanged<String> onSelect,
  }) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Text(title, style: AppTypography.sectionTitle),
              const SizedBox(height: 8),
              ...values.map(
                (entry) => ListTile(
                  title: Text(entry.value),
                  trailing: selected == entry.key
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primaryPurple,
                        )
                      : null,
                  onTap: () => Navigator.pop(sheetContext, entry.key),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) onSelect(result);
  }
}

enum SakhiTextPostMode { text, question, resource }

class SakhiTextPostComposerScreen extends StatefulWidget {
  const SakhiTextPostComposerScreen({
    super.key,
    this.initialMode = SakhiTextPostMode.text,
    this.onPublished,
    this.initialCategory,
  });

  final SakhiTextPostMode initialMode;
  final VoidCallback? onPublished;
  final String? initialCategory;

  @override
  State<SakhiTextPostComposerScreen> createState() =>
      _SakhiTextPostComposerScreenState();
}

class _SakhiTextPostComposerScreenState
    extends State<SakhiTextPostComposerScreen> {
  static const _draftKey = 'sakhi_text_post_draft';
  final _storage = const FlutterSecureStorage();
  final _bodyController = TextEditingController();
  final _sourceController = TextEditingController();
  late SakhiTextPostMode _mode;
  String _category = 'community';
  String _audience = 'VERIFIED_MEMBERS';
  String _cardStyle = 'Lavender';
  bool _allowComments = true;
  bool _submitting = false;
  bool _draftSaved = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    final initial = widget.initialCategory;
    if (initial != null && sakhiPostCategories.containsKey(initial)) {
      _category = initial;
    }
    unawaited(_restoreDraft());
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    try {
      final raw = await _storage.read(key: _draftKey);
      if (raw == null || raw.isEmpty || !mounted) return;
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return;
      setState(() {
        _bodyController.text = data['body']?.toString() ?? '';
        _sourceController.text = data['source']?.toString() ?? '';
        final mode = data['mode']?.toString();
        _mode = SakhiTextPostMode.values.firstWhere(
          (item) => item.name == mode,
          orElse: () => widget.initialMode,
        );
        final category = data['category']?.toString();
        if (sakhiPostCategories.containsKey(category)) {
          _category = category!;
        }
        final audience = data['audience']?.toString();
        if (sakhiPostAudiences.containsKey(audience)) {
          _audience = audience!;
        }
        _cardStyle = data['cardStyle']?.toString() ?? 'Lavender';
        _allowComments = data['allowComments'] != false;
        _draftSaved = true;
      });
    } catch (_) {
      // A corrupt/stale local draft must not block the composer.
    }
  }

  Future<void> _saveDraft() async {
    try {
      await _storage.write(
        key: _draftKey,
        value: jsonEncode({
          'body': _bodyController.text,
          'source': _sourceController.text,
          'mode': _mode.name,
          'category': _category,
          'audience': _audience,
          'cardStyle': _cardStyle,
          'allowComments': _allowComments,
        }),
      );
      if (!mounted) return;
      setState(() => _draftSaved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft saved securely on this device.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Draft could not be saved. Keep editing this screen.',
            ),
          ),
        );
      }
    }
  }

  Future<bool> _discardOrSave() async {
    if (_bodyController.text.trim().isEmpty &&
        _sourceController.text.trim().isEmpty) {
      return true;
    }
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave this composer?'),
        content: const Text('Save your draft before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'cancel'),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'save'),
            child: const Text('Save Draft'),
          ),
        ],
      ),
    );
    if (result == 'save') {
      await _saveDraft();
      return true;
    }
    if (result == 'discard') {
      await _storage.delete(key: _draftKey);
      return true;
    }
    return false;
  }

  Future<void> _back() async {
    if (_submitting) return;
    if (await _discardOrSave() && mounted) Navigator.of(context).pop();
  }

  Future<void> _chooseValue({
    required String title,
    required List<MapEntry<String, String>> values,
    required String selected,
    required ValueChanged<String> onSelect,
  }) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Text(title, style: AppTypography.sectionTitle),
              const SizedBox(height: 8),
              ...values.map(
                (entry) => ListTile(
                  title: Text(entry.value),
                  trailing: selected == entry.key
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primaryPurple,
                        )
                      : null,
                  onTap: () => Navigator.pop(sheetContext, entry.key),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null && mounted) onSelect(result);
  }

  Future<void> _publish() async {
    final rawBody = _bodyController.text.trim();
    if (rawBody.length < 5) {
      _message('Write at least 5 characters before sharing.');
      return;
    }
    if (rawBody.length > 1000) {
      _message('Posts must be 1,000 characters or fewer.');
      return;
    }

    var body = rawBody;
    if (_mode == SakhiTextPostMode.resource) {
      final url = _sourceController.text.trim();
      if (url.isNotEmpty && !RegExp(r'^https?://').hasMatch(url)) {
        _message('Enter a source link beginning with https:// or http://.');
        return;
      }
      if (url.isNotEmpty) body = '$body\n\nResource: $url';
    } else if (_mode == SakhiTextPostMode.question) {
      body = 'Community Question\n$body';
    }

    setState(() => _submitting = true);
    final published = await SakhiPrototypeState.instance.createCommunityPost(
      body,
      categoryBadge: sakhiPostCategories[_category],
      categorySlug: _category,
      visibility: _audience,
      hashtags: RegExp(r'#[A-Za-z0-9_]+')
          .allMatches(body)
          .map((match) => match.group(0)!)
          .toSet()
          .toList(),
      allowComments: _allowComments,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!published) {
      _message(
        'Could not share your post. Your draft remains available to retry.',
      );
      return;
    }
    await _storage.delete(key: _draftKey);
    if (!mounted) return;
    SakhiPrototypeState.instance.loadFeed(categorySlug: 'all');
    widget.onPublished?.call();
    final success = _mode == SakhiTextPostMode.question
        ? 'Question shared to ${sakhiPostCategories[_category]!}!'
        : _mode == SakhiTextPostMode.resource
        ? 'Resource shared to ${sakhiPostCategories[_category]!}!'
        : 'Post shared to ${sakhiPostCategories[_category]!}!';
    _message(success);
    Navigator.of(context).pop();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final question = _mode == SakhiTextPostMode.question;
    final resource = _mode == SakhiTextPostMode.resource;
    final user = SakhiPrototypeState.instance.currentUser;
    final background = switch (_cardStyle) {
      'Soft Pink' => const Color(0xFFFDF4F7),
      'Lavender' => const Color(0xFFF5EBF9),
      'Cream' => const Color(0xFFFFF8F0),
      _ => AppColors.primaryPurple,
    };
    final foreground = _cardStyle == 'Floral Plum'
        ? Colors.white
        : AppColors.textPrimary;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leadingWidth: 100,
        leading: TextButton(
          onPressed: _submitting ? null : _back,
          child: const Text('‹ Discard'),
        ),
        title: Text(
          question
              ? 'Community Question'
              : resource
              ? 'Share a Resource'
              : 'Text Post',
          style: AppTypography.appBarTitle,
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _saveDraft,
            child: const Text('Save Draft'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 96),
          children: [
            SegmentedButton<SakhiTextPostMode>(
              segments: const [
                ButtonSegment(
                  value: SakhiTextPostMode.text,
                  label: Text('Text Post'),
                  icon: Icon(Icons.edit_note_rounded),
                ),
                ButtonSegment(
                  value: SakhiTextPostMode.question,
                  label: Text('Community Question'),
                  icon: Icon(Icons.forum_outlined),
                ),
              ],
              selected: {resource ? SakhiTextPostMode.text : _mode},
              showSelectedIcon: false,
              onSelectionChanged: _submitting
                  ? null
                  : (values) => setState(() => _mode = values.first),
            ),
            const SizedBox(height: 12),
            SakhiCard(
              child: Row(
                children: [
                  SakhiAvatar(
                    imageAsset: user.avatarAsset,
                    fallbackLabel: user.displayName,
                    size: 42,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.displayName, style: AppTypography.cardTitle),
                        Text(user.username, style: AppTypography.subtitle),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _chooseValue(
                      title: 'Post audience',
                      values: const [
                        MapEntry('VERIFIED_MEMBERS', 'All Verified Members'),
                        MapEntry('FOLLOWERS_ONLY', 'Followers Only'),
                        MapEntry('PRIVATE_SELF', 'Only Me'),
                      ],
                      selected: _audience,
                      onSelect: (value) => setState(() => _audience = value),
                    ),
                    child: Text(sakhiPostAudiences[_audience]!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SakhiCard(
              padding: const EdgeInsets.all(0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (question || resource) ...[
                      Text(
                        question
                            ? 'SAKHI COMMUNITY QUESTION'
                            : 'USEFUL COMMUNITY RESOURCE',
                        style: TextStyle(
                          color: foreground,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .6,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: _bodyController,
                      maxLength: 1000,
                      maxLines: 7,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: question
                            ? 'Ask the Sakhi Community...'
                            : 'Share a thought, experience, or update...',
                        hintStyle: TextStyle(
                          color: foreground.withValues(alpha: .72),
                        ),
                        border: InputBorder.none,
                        counterText: '',
                      ),
                      style: TextStyle(
                        color: foreground,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_bodyController.text.length}/1000',
                        style: AppTypography.subtitle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (resource) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _sourceController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Source link (optional)',
                  hintText: 'https://example.com/resource',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Text('Category', style: AppTypography.bodyMedium),
            const SizedBox(height: 6),
            SakhiCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                title: Text(sakhiPostCategories[_category]!),
                trailing: const Icon(Icons.keyboard_arrow_down_rounded),
                onTap: () => _chooseValue(
                  title: 'Choose a category',
                  values: sakhiPostCategories.entries
                      .map((entry) => MapEntry(entry.key, entry.value))
                      .toList(),
                  selected: _category,
                  onSelect: (value) => setState(() => _category = value),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Card Background Style',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children:
                  [
                    ('Soft Pink', const Color(0xFFFDF4F7)),
                    ('Lavender', const Color(0xFFF5EBF9)),
                    ('Cream', const Color(0xFFFFF8F0)),
                    ('Floral Plum', AppColors.primaryPurple),
                  ].map((choice) {
                    return InkWell(
                      onTap: () => setState(() => _cardStyle = choice.$1),
                      borderRadius: BorderRadius.circular(20),
                      child: Tooltip(
                        message: choice.$1,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                color: choice.$2,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _cardStyle == choice.$1
                                      ? AppColors.primaryPurple
                                      : AppColors.borderSubtle,
                                  width: _cardStyle == choice.$1 ? 3 : 1,
                                ),
                              ),
                              child: _cardStyle == choice.$1
                                  ? Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: choice.$1 == 'Floral Plum'
                                          ? Colors.white
                                          : AppColors.primaryPurple,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              choice.$1,
                              style: AppTypography.caption.copyWith(
                                fontWeight: _cardStyle == choice.$1
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 14),
            const Text('Suggested hashtags', style: AppTypography.bodyMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  [
                    '#SafetyAwareness',
                    '#AskSakhi',
                    '#CareerSupport',
                    '+ Add Tag',
                  ].map((tag) {
                    return SakhiChip(
                      label: tag,
                      onTap: () {
                        final body = _bodyController.text.trimRight();
                        _bodyController.text = body.isEmpty
                            ? tag
                            : '$body $tag';
                        _bodyController.selection = TextSelection.collapsed(
                          offset: _bodyController.text.length,
                        );
                        setState(() {});
                      },
                    );
                  }).toList(),
            ),
            const SizedBox(height: 12),
            Material(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              child: SwitchListTile(
                value: _allowComments,
                activeThumbColor: AppColors.primaryPurple,
                title: const Text('Allow member comments'),
                onChanged: (value) => setState(() => _allowComments = value),
              ),
            ),
            if (_draftSaved) ...[
              const SizedBox(height: 8),
              const Text(
                'Draft saved on this device.',
                style: AppTypography.subtitle,
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: SakhiPillButton(
                label: _submitting
                    ? 'Sharing...'
                    : question
                    ? 'Share Question to Social Wall'
                    : resource
                    ? 'Share Resource to Social Wall'
                    : 'Share Post',
                onPressed: _submitting ? null : _publish,
              ),
            ),
            if (_submitting) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(
                color: AppColors.primaryPurple,
                minHeight: 4,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sosRed.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.sosRed),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: AppTypography.bodyRegular)),
        ],
      ),
    );
  }
}
