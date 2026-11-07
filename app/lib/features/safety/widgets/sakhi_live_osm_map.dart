import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/safety_models.dart';

/// OpenStreetMap tile map centred only on a validated device GPS fix.
/// Includes non-overlapping full-screen controls and iOS 26 Liquid Glass action pills.
class SakhiLiveOsmMap extends StatefulWidget {
  final double height;
  final double initialZoom;
  final double latitude;
  final double longitude;
  final bool hasLiveGps;
  final String locationLabel;
  final double? accuracyMeters;
  final List<NearbyPoliceStationModel> policeStations;
  final VoidCallback onRequestGpsTap;
  final ValueChanged<NearbyPoliceStationModel>? onStationTap;
  final Widget? centerOverlay;
  final bool isFullScreenModal;

  const SakhiLiveOsmMap({
    super.key,
    required this.height,
    this.initialZoom = 15,
    required this.latitude,
    required this.longitude,
    required this.hasLiveGps,
    required this.locationLabel,
    this.accuracyMeters,
    this.policeStations = const [],
    required this.onRequestGpsTap,
    this.onStationTap,
    this.centerOverlay,
    this.isFullScreenModal = false,
  });

  @override
  State<SakhiLiveOsmMap> createState() => _SakhiLiveOsmMapState();
}

class _SakhiLiveOsmMapState extends State<SakhiLiveOsmMap> {
  static const double _tileSize = 256;
  static const int _tileRadius = 2;

  final TransformationController _transformController =
      TransformationController();
  int _zoomAdjustment = 0;
  bool _needsCentering = true;
  bool _isExpandedHalfScreen = false;

  double get _effectiveHeight => _isExpandedHalfScreen
      ? math.max(widget.height + 190, 420.0)
      : widget.height;

  void _adjustZoom(int delta) {
    final nextZoom = (widget.initialZoom.round() + _zoomAdjustment + delta)
        .clamp(3, 18);
    if (nextZoom == _zoom) return;
    setState(() {
      _zoomAdjustment += delta;
      _transformController.value = Matrix4.identity();
      _needsCentering = true;
    });
  }

  void _recenterMap() {
    setState(() {
      _transformController.value = Matrix4.identity();
      _needsCentering = true;
    });
    widget.onRequestGpsTap();
  }

  void _toggleExpandHalfScreen() {
    setState(() {
      _isExpandedHalfScreen = !_isExpandedHalfScreen;
      _needsCentering = true;
    });
  }

  void _openFullScreenMap(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final screenH = MediaQuery.of(ctx).size.height;
        return Container(
          height: screenH * 0.90,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: SakhiLiveOsmMap(
                  height: screenH * 0.90,
                  initialZoom: _zoom.toDouble(),
                  latitude: widget.latitude,
                  longitude: widget.longitude,
                  hasLiveGps: widget.hasLiveGps,
                  locationLabel: widget.locationLabel,
                  accuracyMeters: widget.accuracyMeters,
                  policeStations: widget.policeStations,
                  onRequestGpsTap: widget.onRequestGpsTap,
                  onStationTap: widget.onStationTap,
                  isFullScreenModal: true,
                ),
              ),
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: SafeArea(
                  top: false,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF5A1868,
                          ).withValues(alpha: 0.92),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.65),
                              width: 1.3,
                            ),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.fullscreen_exit_rounded),
                        label: const Text(
                          'Close Full-Screen Map',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool get _hasValidGps =>
      widget.hasLiveGps &&
      widget.latitude.isFinite &&
      widget.longitude.isFinite &&
      widget.latitude >= -90 &&
      widget.latitude <= 90 &&
      widget.longitude >= -180 &&
      widget.longitude <= 180 &&
      !(widget.latitude == 0 && widget.longitude == 0);

  int get _zoom =>
      (widget.initialZoom.round() + _zoomAdjustment).clamp(3, 18).toInt();

  @override
  void didUpdateWidget(covariant SakhiLiveOsmMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasLiveGps != widget.hasLiveGps ||
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.initialZoom != widget.initialZoom) {
      _needsCentering = true;
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  double _worldX(double longitude, int zoom) {
    final count = math.pow(2, zoom).toDouble();
    return ((longitude + 180) / 360) * count;
  }

  double _worldY(double latitude, int zoom) {
    final clampedLatitude = latitude
        .clamp(-85.05112878, 85.05112878)
        .toDouble();
    final radians = clampedLatitude * math.pi / 180;
    final count = math.pow(2, zoom).toDouble();
    return (1 - math.log(math.tan(radians) + 1 / math.cos(radians)) / math.pi) /
        2 *
        count;
  }

  String _tileUrl(int zoom, int x, int y) {
    final count = math.pow(2, zoom).toInt();
    final wrappedX = ((x % count) + count) % count;
    return 'https://tile.openstreetmap.org/$zoom/$wrappedX/$y.png';
  }

  Widget _tile(int zoom, int x, int y) {
    final count = math.pow(2, zoom).toInt();
    if (y < 0 || y >= count) {
      return const ColoredBox(color: Color(0xFFE8E9EC));
    }
    return Image.network(
      _tileUrl(zoom, x, y),
      fit: BoxFit.cover,
      headers: const {'User-Agent': 'SakhiWomenSafetyApp/2.0 (Live OSM map)'},
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return const ColoredBox(color: Color(0xFFE8E9EC));
      },
      errorBuilder: (context, error, stackTrace) =>
          const ColoredBox(color: Color(0xFFE8E9EC)),
    );
  }

  void _handleInteractionEnd(ScaleEndDetails details) {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if (scale >= 1.45 && _zoom < 18) {
      setState(() => _zoomAdjustment += 1);
      _transformController.value = Matrix4.identity();
      _needsCentering = true;
    } else if (scale <= 0.80 && _zoom > 3) {
      setState(() => _zoomAdjustment -= 1);
      _transformController.value = Matrix4.identity();
      _needsCentering = true;
    }
  }

  Widget _buildMap(double viewportWidth) {
    final zoom = _zoom;
    final worldX = _worldX(widget.longitude, zoom);
    final worldY = _worldY(widget.latitude, zoom);
    final centerX = (_tileRadius * 2 + 1) * _tileSize / 2;
    final centerY = centerX;
    final canvasSize = (_tileRadius * 2 + 1) * _tileSize;
    final baseX = worldX.floor();
    final baseY = worldY.floor();
    final children = <Widget>[];

    for (var dx = -_tileRadius; dx <= _tileRadius; dx++) {
      for (var dy = -_tileRadius; dy <= _tileRadius; dy++) {
        final tileX = baseX + dx;
        final tileY = baseY + dy;
        final left = centerX + (tileX - worldX) * _tileSize;
        final top = centerY + (tileY - worldY) * _tileSize;
        children.add(
          Positioned(
            left: left,
            top: top,
            width: _tileSize,
            height: _tileSize,
            child: _tile(zoom, tileX, tileY),
          ),
        );
      }
    }

    for (final station in widget.policeStations) {
      final latitude = station.latitude;
      final longitude = station.longitude;
      if (latitude == null ||
          longitude == null ||
          !latitude.isFinite ||
          !longitude.isFinite ||
          latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180) {
        continue;
      }
      var deltaX = _worldX(longitude, zoom) - worldX;
      final worldTileCount = math.pow(2, zoom).toDouble();
      if (deltaX > worldTileCount / 2) deltaX -= worldTileCount;
      if (deltaX < -worldTileCount / 2) deltaX += worldTileCount;
      final deltaY = _worldY(latitude, zoom) - worldY;
      final x = centerX + deltaX * _tileSize;
      final y = centerY + deltaY * _tileSize;
      if (x < 20 || x > canvasSize - 20 || y < 20 || y > canvasSize - 20) {
        continue;
      }
      children.add(
        Positioned(
          left: x - 17,
          top: y - 30,
          child: Tooltip(
            message: '${station.name} (OpenStreetMap listing; unverified)',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onStationTap == null
                    ? null
                    : () => widget.onStationTap!(station),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7A244D),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_police_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final accuracy = widget.accuracyMeters;
    final metersPerPixel =
        math.cos(widget.latitude * math.pi / 180) *
        2 *
        math.pi *
        6378137 /
        (256 * math.pow(2, zoom));
    final accuracyRadius = accuracy != null && accuracy.isFinite && accuracy > 0
        ? (accuracy / metersPerPixel).clamp(8.0, 55.0).toDouble()
        : 14.0;
    children.add(
      Positioned(
        left: centerX - accuracyRadius,
        top: centerY - accuracyRadius,
        child: Container(
          width: accuracyRadius * 2,
          height: accuracyRadius * 2,
          decoration: BoxDecoration(
            color: const Color(0x332196F3),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x772196F3), width: 1.4),
          ),
        ),
      ),
    );
    children.add(
      Positioned(
        left: centerX - 9,
        top: centerY - 9,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF1479E8),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x551479E8),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );

    if (_needsCentering) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_needsCentering) return;
        _transformController.value = Matrix4.identity()
          ..translateByDouble(
            viewportWidth / 2 - canvasSize / 2,
            _effectiveHeight / 2 - canvasSize / 2,
            0.0,
            1.0,
          );
        _needsCentering = false;
      });
    }

    return InteractiveViewer(
      transformationController: _transformController,
      constrained: false,
      panEnabled: true,
      scaleEnabled: true,
      minScale: 0.65,
      maxScale: 3.0,
      boundaryMargin: EdgeInsets.zero,
      onInteractionEnd: _handleInteractionEnd,
      child: SizedBox(
        width: canvasSize,
        height: canvasSize,
        child: Stack(clipBehavior: Clip.hardEdge, children: children),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // When rendered inside the full-screen modal sheet, lift the right-hand
    // zoom & GPS recenter buttons to bottom: 96 so they NEVER overlap the
    // bottom 'Close Full-Screen Map' pill!
    final double rightControlsBottom = widget.isFullScreenModal ? 96.0 : 28.0;
    final double attributionBottom = widget.isFullScreenModal ? 6.0 : 4.0;
    final double btnSize = widget.isFullScreenModal ? 42.0 : 34.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      height: _effectiveHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 360.0;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: _hasValidGps
                      ? ColoredBox(
                          color: const Color(0xFFE8E9EC),
                          child: _buildMap(width),
                        )
                      : const _NoGpsMapSurface(),
                ),
                if (widget.centerOverlay != null)
                  Positioned.fill(child: Center(child: widget.centerOverlay!)),
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: const Color(0xF7FFFFFF),
                          borderRadius: BorderRadius.circular(14),
                          elevation: 2,
                          child: InkWell(
                            onTap: widget.onRequestGpsTap,
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _hasValidGps
                                        ? Icons.my_location_rounded
                                        : Icons.location_searching_rounded,
                                    color: const Color(0xFF1769AA),
                                    size: 17,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      widget.locationLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF292333),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (!_hasValidGps)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 5),
                                      child: Text(
                                        'Enable GPS',
                                        style: TextStyle(
                                          color: Color(0xFF1769AA),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_hasValidGps) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 7.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xF7FFFFFF),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1E7E55),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                widget.accuracyMeters != null &&
                                        widget.accuracyMeters!.isFinite &&
                                        widget.accuracyMeters! > 0
                                    ? 'GPS accuracy ${widget.accuracyMeters!.toStringAsFixed(0)} m'
                                    : 'GPS active',
                                style: const TextStyle(
                                  color: Color(0xFF1769AA),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_hasValidGps &&
                    (_isExpandedHalfScreen || widget.isFullScreenModal))
                  Positioned(
                    top: 50,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xEE22112B),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'LIVE GPS • ${widget.latitude.toStringAsFixed(5)}, ${widget.longitude.toStringAsFixed(5)} • Zoom $_zoom',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (_hasValidGps)
                  Positioned(
                    right: 12,
                    bottom: rightControlsBottom,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: const Color(0xF8FFFFFF),
                          borderRadius: BorderRadius.circular(12),
                          elevation: 3,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _adjustZoom(1),
                            child: SizedBox(
                              width: btnSize,
                              height: btnSize,
                              child: const Icon(
                                Icons.add_rounded,
                                size: 22,
                                color: Color(0xFF5A1868),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Material(
                          color: const Color(0xF8FFFFFF),
                          borderRadius: BorderRadius.circular(12),
                          elevation: 3,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _adjustZoom(-1),
                            child: SizedBox(
                              width: btnSize,
                              height: btnSize,
                              child: const Icon(
                                Icons.remove_rounded,
                                size: 22,
                                color: Color(0xFF5A1868),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Material(
                          color: const Color(0xFF1479E8),
                          borderRadius: BorderRadius.circular(12),
                          elevation: 4,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _recenterMap,
                            child: SizedBox(
                              width: btnSize,
                              height: btnSize,
                              child: const Icon(
                                Icons.my_location_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Only show inline Expand/Full-Screen buttons when NOT already inside the full-screen modal
                if (_hasValidGps && !widget.isFullScreenModal)
                  Positioned(
                    left: 8,
                    bottom: 22,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: const Color(0xF5FFFFFF),
                          borderRadius: BorderRadius.circular(999),
                          elevation: 2,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: _toggleExpandHalfScreen,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isExpandedHalfScreen
                                        ? Icons.unfold_less_rounded
                                        : Icons.unfold_more_rounded,
                                    size: 15,
                                    color: const Color(0xFF5A1868),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isExpandedHalfScreen
                                        ? 'Compact'
                                        : 'Expand Map',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF5A1868),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Material(
                          color: const Color(0xF5FFFFFF),
                          borderRadius: BorderRadius.circular(999),
                          elevation: 2,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => _openFullScreenMap(context),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.open_in_full_rounded,
                                size: 14,
                                color: Color(0xFF5A1868),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  right: 8,
                  bottom: attributionBottom,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xD8FFFFFF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(
                        color: Color(0xFF433A4B),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NoGpsMapSurface extends StatelessWidget {
  const _NoGpsMapSurface();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6ECF8), Color(0xFFEDE2F3), Color(0xFFFDF7FA)],
        ),
      ),
      child: CustomPaint(
        painter: _MapGridPlaceholderPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MapGridPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x185A1868)
      ..strokeWidth = 1;
    const step = 34.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
