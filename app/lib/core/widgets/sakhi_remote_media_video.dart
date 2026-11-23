import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../assets/app_assets.dart';
import '../theme/app_colors.dart';
import '../../features/auth/backend_api_client.dart';

/// Authenticated playback for private Google Drive-backed Sakhi media.
///
/// Playback and progress controls are real video_player controls. The overlay
/// fades after a short idle period while playing and remains available while
/// paused, buffering, or after playback completes.
class SakhiRemoteMediaVideo extends StatefulWidget {
  const SakhiRemoteMediaVideo({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
  });

  final String source;
  final BoxFit fit;

  @override
  State<SakhiRemoteMediaVideo> createState() => _SakhiRemoteMediaVideoState();
}

class _SakhiRemoteMediaVideoState extends State<SakhiRemoteMediaVideo> {
  static const Duration _controlsIdleDuration = Duration(seconds: 3);
  static const Duration _controlsFadeDuration = Duration(milliseconds: 220);

  VideoPlayerController? _controller;
  Timer? _controlsTimer;
  bool _loading = true;
  bool _controlsVisible = true;
  String? _error;
  int _initializationGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void didUpdateWidget(covariant SakhiRemoteMediaVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      unawaited(_disposeAndInitialize());
    }
  }

  Future<void> _disposeAndInitialize() async {
    _initializationGeneration++;
    _controlsTimer?.cancel();
    final previous = _controller;
    previous?.removeListener(_handleControllerUpdate);
    _controller = null;
    await previous?.dispose();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _controlsVisible = true;
    });
    await _initialize();
  }

  Future<void> _initialize() async {
    final generation = _initializationGeneration;
    VideoPlayerController? controller;
    try {
      final headers = await BackendApiClient.imageRequestHeaders();
      if (headers.isEmpty) {
        throw StateError('Sign in to play this video.');
      }
      controller = VideoPlayerController.networkUrl(
        Uri.parse(AppAssets.resolveRemoteMediaUrl(widget.source)),
        httpHeaders: headers,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      _controller = controller;
      controller.addListener(_handleControllerUpdate);
      await controller.initialize();
      await controller.setLooping(false);
      if (!mounted || generation != _initializationGeneration) {
        controller.removeListener(_handleControllerUpdate);
        await controller.dispose();
        return;
      }
      setState(() {
        _loading = false;
        _error = null;
        _controlsVisible = true;
      });
    } catch (_) {
      if (controller != null) {
        controller.removeListener(_handleControllerUpdate);
        if (identical(_controller, controller)) _controller = null;
        await controller.dispose();
      }
      if (mounted && generation == _initializationGeneration) {
        setState(() {
          _loading = false;
          _error =
              'Video could not be loaded. Check your connection and try again.';
          _controlsVisible = true;
        });
      }
    }
  }

  void _handleControllerUpdate() {
    final controller = _controller;
    if (!mounted || controller == null) return;
    if (controller.value.isCompleted) {
      _controlsTimer?.cancel();
      if (!_controlsVisible) {
        setState(() => _controlsVisible = true);
      } else {
        setState(() {});
      }
      return;
    }
    setState(() {});
    if (!controller.value.isPlaying) {
      _controlsTimer?.cancel();
      if (!_controlsVisible) setState(() => _controlsVisible = true);
    }
  }

  void _showControls({bool scheduleHide = true}) {
    _controlsTimer?.cancel();
    if (!_controlsVisible && mounted) {
      setState(() => _controlsVisible = true);
    }
    final controller = _controller;
    if (scheduleHide && controller?.value.isPlaying == true) {
      _controlsTimer = Timer(_controlsIdleDuration, () {
        if (!mounted || _controller?.value.isPlaying != true) return;
        setState(() => _controlsVisible = false);
      });
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    _showControls(scheduleHide: false);
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (controller.value.isCompleted) {
        await controller.seekTo(Duration.zero);
      }
      await controller.play();
      _showControls();
    }
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    await controller.setVolume(controller.value.volume > 0 ? 0 : 1);
    _showControls();
  }

  @override
  void dispose() {
    _initializationGeneration++;
    _controlsTimer?.cancel();
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_handleControllerUpdate);
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  Widget _buildError() {
    return Container(
      color: AppColors.textPrimary,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.video_library_outlined,
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Video is unavailable.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => unawaited(_disposeAndInitialize()),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_loading) {
      return Container(
        color: AppColors.textPrimary,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_error != null ||
        controller == null ||
        !controller.value.isInitialized) {
      return _buildError();
    }

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        FittedBox(
          fit: widget.fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => unawaited(_togglePlayback()),
            child: const SizedBox.expand(),
          ),
        ),
        if (!controller.value.isPlaying)
          IgnorePointer(
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .48),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white70, width: 1),
                ),
                padding: const EdgeInsets.all(14),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: !_controlsVisible,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: _controlsFadeDuration,
              curve: Curves.easeOut,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 24, 8, 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: controller.value.isPlaying ? 'Pause' : 'Play',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => unawaited(_togglePlayback()),
                        icon: Icon(
                          controller.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: AppColors.primaryPurple,
                            bufferedColor: Colors.white70,
                            backgroundColor: Colors.white38,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: controller.value.volume > 0 ? 'Mute' : 'Unmute',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => unawaited(_toggleMute()),
                        icon: Icon(
                          controller.value.volume > 0
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _showControls(),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}
