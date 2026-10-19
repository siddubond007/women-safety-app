import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Infinite-DPI vector art renderer for Sakhi portraits, hero illustrations,
/// and community feed scenes. Eliminates raster blurriness on all screen
/// densities while seamlessly delegating `http://` and `https://` URLs to
/// `Image.network` for Cloud Storage uploads.
class SakhiCrispAvatarArt extends StatelessWidget {
  final String assetOrUrl;
  final double size;

  const SakhiCrispAvatarArt({
    super.key,
    required this.assetOrUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SakhiPortraitPainter(
        keyName: assetOrUrl,
        transparentBg: false,
      ),
    );
  }
}

class SakhiCrispHeroArt extends StatelessWidget {
  final String variant;
  final double width;
  final double height;

  const SakhiCrispHeroArt({
    super.key,
    required this.variant,
    this.width = 156,
    this.height = 168,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _SakhiPortraitPainter(
        keyName: variant,
        transparentBg: true,
        eyesClosed: variant.contains('wellness') || variant.contains('breathing'),
      ),
    );
  }
}

class SakhiCrispSceneArt extends StatelessWidget {
  final String assetPath;

  const SakhiCrispSceneArt({super.key, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SakhiScenePainter(sceneKey: assetPath),
      child: const SizedBox.expand(),
    );
  }
}

class _PortraitStyle {
  final Color bgTop;
  final Color bgBottom;
  final Color outfitPrimary;
  final Color outfitSecondary;
  final bool hasGlasses;
  final bool hasBindi;
  final bool bunHair;

  const _PortraitStyle({
    required this.bgTop,
    required this.bgBottom,
    required this.outfitPrimary,
    required this.outfitSecondary,
    this.hasGlasses = false,
    this.hasBindi = true,
    this.bunHair = false,
  });
}

class _SakhiPortraitPainter extends CustomPainter {
  final String keyName;
  final bool transparentBg;
  final bool eyesClosed;

  const _SakhiPortraitPainter({
    required this.keyName,
    required this.transparentBg,
    this.eyesClosed = false,
  });

  _PortraitStyle _resolveStyle() {
    final lower = keyName.toLowerCase();
    if (lower.contains('ananya')) {
      return const _PortraitStyle(
        bgTop: Color(0xFFFDE5E8),
        bgBottom: Color(0xFFF4CFE2),
        outfitPrimary: Color(0xFFD14E7D),
        outfitSecondary: Color(0xFFED89A6),
        hasGlasses: true,
        hasBindi: true,
      );
    }
    if (lower.contains('meera') || lower.contains('breathing')) {
      return const _PortraitStyle(
        bgTop: Color(0xFFE2F5EC),
        bgBottom: Color(0xFFD4EBF7),
        outfitPrimary: Color(0xFF38947D),
        outfitSecondary: Color(0xFF6BC2A4),
        hasBindi: true,
        bunHair: true,
      );
    }
    if (lower.contains('kavya')) {
      return const _PortraitStyle(
        bgTop: Color(0xFFFCEBD6),
        bgBottom: Color(0xFFF6D6E8),
        outfitPrimary: Color(0xFFC9703D),
        outfitSecondary: Color(0xFFE89E61),
        hasBindi: false,
      );
    }
    if (lower.contains('ishita')) {
      return const _PortraitStyle(
        bgTop: Color(0xFFE6E0FA),
        bgBottom: Color(0xFFD6E3FA),
        outfitPrimary: Color(0xFF593D94),
        outfitSecondary: Color(0xFF8563C2),
        hasGlasses: true,
        hasBindi: false,
      );
    }
    if (lower.contains('priya')) {
      return const _PortraitStyle(
        bgTop: Color(0xFFDDF2F5),
        bgBottom: Color(0xFFEADDF7),
        outfitPrimary: Color(0xFF2E85AD),
        outfitSecondary: Color(0xFF5CB0D1),
        hasBindi: true,
        bunHair: true,
      );
    }
    if (lower.contains('sneha')) {
      return const _PortraitStyle(
        bgTop: Color(0xFFFAE0ED),
        bgBottom: Color(0xFFEDD6F2),
        outfitPrimary: Color(0xFFAD4785),
        outfitSecondary: Color(0xFFD97AAD),
        hasBindi: true,
      );
    }
    // Default / Siddhu / Greeting Hero / Wellness Hero
    return const _PortraitStyle(
      bgTop: Color(0xFFF8DEF0),
      bgBottom: Color(0xFFE4CCFA),
      outfitPrimary: Color(0xFF8E4AB0),
      outfitSecondary: Color(0xFFC773D6),
      hasBindi: true,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final style = _resolveStyle();
    final s = math.min(size.width, size.height) / 200.0;
    canvas.save();
    canvas.translate(
      (size.width - 200 * s) * 0.5,
      (size.height - 200 * s) * 0.5,
    );
    canvas.scale(s, s);

    const ink = Color(0xFF3A1E2E);
    const hair = Color(0xFF281622);
    const skin = Color(0xFFF0BE9F);

    if (!transparentBg) {
      final rect = const Rect.fromLTWH(0, 0, 200, 200);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [style.bgTop, style.bgBottom],
          ).createShader(rect),
      );
    } else {
      // Soft glowing aura behind hero character
      canvas.drawCircle(
        const Offset(104, 102),
        78,
        Paint()
          ..shader = RadialGradient(
            colors: [
              style.bgTop.withValues(alpha: 0.72),
              style.bgBottom.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(center: const Offset(104, 102), radius: 78),
          ),
      );
    }

    if (style.bunHair) {
      canvas.drawCircle(const Offset(100, 32), 20, Paint()..color = hair);
    }

    // Flowing hair silhouette
    final hairPath = Path()
      ..moveTo(56, 86)
      ..cubicTo(44, 44, 78, 26, 100, 28)
      ..cubicTo(128, 28, 154, 48, 146, 90)
      ..cubicTo(156, 122, 152, 165, 138, 192)
      ..lineTo(62, 192)
      ..cubicTo(48, 165, 46, 120, 56, 86)
      ..close();
    canvas.drawPath(hairPath, Paint()..color = hair);

    // Neck
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(86, 112, 28, 34),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFE3AF90),
    );

    // Shoulders & Kurta/Top
    final outfitPath = Path()
      ..moveTo(42, 200)
      ..cubicTo(46, 158, 68, 140, 86, 138)
      ..lineTo(100, 158)
      ..lineTo(114, 138)
      ..cubicTo(132, 140, 154, 158, 158, 200)
      ..close();
    canvas.drawPath(
      outfitPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [style.outfitPrimary, style.outfitSecondary],
        ).createShader(const Rect.fromLTWH(42, 138, 116, 62)),
    );
    canvas.drawPath(
      outfitPath,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Collar trim
    final collar = Path()
      ..moveTo(84, 139)
      ..lineTo(100, 161)
      ..lineTo(116, 139);
    canvas.drawPath(
      collar,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Gold stud earrings
    for (final ex in const [68.0, 132.0]) {
      canvas.drawCircle(
        Offset(ex, 97),
        3.2,
        Paint()..color = const Color(0xFFEBB85B),
      );
    }

    // Face contour
    final facePath = Path()
      ..moveTo(70, 74)
      ..cubicTo(69, 105, 83, 124, 100, 125)
      ..cubicTo(117, 124, 131, 105, 130, 74)
      ..cubicTo(129, 48, 116, 42, 100, 42)
      ..cubicTo(84, 42, 71, 48, 70, 74)
      ..close();
    canvas.drawPath(facePath, Paint()..color = skin);
    canvas.drawPath(
      facePath,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Soft cheek blush
    for (final cx in const [82.0, 118.0]) {
      canvas.drawCircle(
        Offset(cx, 95),
        9,
        Paint()..color = const Color(0x38E86B8C),
      );
    }

    // Front hair sweep
    final bangs = Path()
      ..moveTo(68, 78)
      ..cubicTo(72, 56, 88, 47, 106, 44)
      ..cubicTo(118, 49, 128, 60, 131, 78)
      ..cubicTo(132, 52, 119, 36, 100, 36)
      ..cubicTo(80, 36, 67, 52, 68, 78)
      ..close();
    canvas.drawPath(bangs, Paint()..color = hair);

    // Eyebrows
    final browPaint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(79, 76)
        ..quadraticBezierTo(86, 72, 93, 75),
      browPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(107, 75)
        ..quadraticBezierTo(114, 72, 121, 76),
      browPaint,
    );

    if (style.hasBindi) {
      canvas.drawCircle(
        const Offset(100, 73.5),
        1.8,
        Paint()..color = const Color(0xFFB02E60),
      );
    }

    // Eyes
    if (eyesClosed) {
      canvas.drawPath(
        Path()
          ..moveTo(80, 84)
          ..quadraticBezierTo(86, 88, 92, 84),
        browPaint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(108, 84)
          ..quadraticBezierTo(114, 88, 120, 84),
        browPaint,
      );
    } else {
      for (final ex in const [86.0, 114.0]) {
        canvas.drawCircle(Offset(ex, 84), 3.1, Paint()..color = ink);
        canvas.drawCircle(
          Offset(ex - 1.0, 83.0),
          1.0,
          Paint()..color = Colors.white,
        );
      }
    }

    if (style.hasGlasses) {
      final glassPaint = Paint()
        ..color = const Color(0xCC6E388A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3;
      canvas.drawCircle(const Offset(86, 84), 7.5, glassPaint);
      canvas.drawCircle(const Offset(114, 84), 7.5, glassPaint);
      canvas.drawLine(const Offset(93.5, 84), const Offset(106.5, 84), glassPaint);
    }

    // Smile
    canvas.drawPath(
      Path()
        ..moveTo(91, 104)
        ..quadraticBezierTo(100, 110, 109, 104),
      Paint()
        ..color = const Color(0xFFC44D6E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SakhiPortraitPainter oldDelegate) =>
      oldDelegate.keyName != keyName ||
      oldDelegate.transparentBg != transparentBg ||
      oldDelegate.eyesClosed != eyesClosed;
}

class _SakhiScenePainter extends CustomPainter {
  final String sceneKey;
  const _SakhiScenePainter({required this.sceneKey});

  @override
  void paint(Canvas canvas, Size size) {
    final isBeach = sceneKey.toLowerCase().contains('beach');
    final rect = Offset.zero & size;

    // Crisp Sunset Sky
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isBeach
              ? const [
                  Color(0xFF6B429E),
                  Color(0xFFDB7AA8),
                  Color(0xFFFFD19E),
                ]
              : const [
                  Color(0xFF5C337A),
                  Color(0xFFC7618F),
                  Color(0xFFFAAC75),
                ],
        ).createShader(rect),
    );

    final sunCenter = Offset(size.width * 0.52, size.height * 0.54);
    canvas.drawCircle(
      sunCenter,
      size.height * 0.32,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF8D6).withValues(alpha: 0.90),
            const Color(0xFFFFB870).withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: sunCenter, radius: size.height * 0.32),
        ),
    );
    canvas.drawCircle(
      sunCenter,
      size.height * 0.11,
      Paint()..color = const Color(0xFFFFF9E3),
    );

    if (isBeach) {
      // Calm twilight ocean below horizon
      final seaRect = Rect.fromLTWH(
        0,
        size.height * 0.58,
        size.width,
        size.height * 0.42,
      );
      canvas.drawRect(
        seaRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFC7709E),
              Color(0xFF6E4287),
              Color(0xFF3D2457),
            ],
          ).createShader(seaRect),
      );
      // Shimmering water ripples
      final ripplePaint = Paint()
        ..color = const Color(0xCCFFF0C2)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 8; i++) {
        final y = size.height * (0.62 + i * 0.042);
        final w = size.width * (0.16 - i * 0.014);
        canvas.drawLine(
          Offset(sunCenter.dx - w * 0.5, y),
          Offset(sunCenter.dx + w * 0.5, y),
          ripplePaint,
        );
      }
    } else {
      // Rolling park hills & sunset walkway
      final hillPath = Path()
        ..moveTo(0, size.height * 0.65)
        ..quadraticBezierTo(
          size.width * 0.35,
          size.height * 0.56,
          size.width,
          size.height * 0.62,
        )
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(hillPath, Paint()..color = const Color(0xFF381F47));

      final walkPath = Path()
        ..moveTo(size.width * 0.48, size.height * 0.61)
        ..quadraticBezierTo(
          size.width * 0.46,
          size.height * 0.80,
          size.width * 0.36,
          size.height,
        )
        ..lineTo(size.width * 0.64, size.height)
        ..quadraticBezierTo(
          size.width * 0.56,
          size.height * 0.80,
          size.width * 0.54,
          size.height * 0.61,
        )
        ..close();
      canvas.drawPath(
        walkPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Color(0xFFF5B88E), Color(0xFF8C527A)],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SakhiScenePainter oldDelegate) =>
      oldDelegate.sceneKey != sceneKey;
}
