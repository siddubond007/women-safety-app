import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/assets/app_assets.dart';

/// 12 distinct hand-drawn botanical flower styles matching the reference sheet:
/// fine espresso-plum ink outlines, delicate inner petal veins, translucent
/// blush/lavender watercolor washes, and veined sage-green leaves.
/// Each flower is a standalone reusable widget and never merged into card photos.
enum SakhiFlowerType {
  poppyBlush(AppAssets.flowerPoppyBlush),
  lavenderSprig(AppAssets.flowerLavenderSprig),
  lilyBloom(AppAssets.flowerLilyBloom),
  hibiscusRose(AppAssets.flowerHibiscusRose),
  peonySoft(AppAssets.flowerPeonySoft),
  cherryBlossom(AppAssets.flowerCherryBlossom),
  tulipDuo(AppAssets.flowerTulipDuo),
  cosmosViolet(AppAssets.flowerCosmosViolet),
  orchidBranch(AppAssets.flowerOrchidBranch),
  roseClassic(AppAssets.flowerRoseClassic),
  babysBreath(AppAssets.flowerBabysBreath),
  eucalyptusSage(AppAssets.flowerEucalyptusSage);

  const SakhiFlowerType(this.assetPath);
  final String assetPath;
}

/// Reusable hand-drawn botanical flower element.
/// Renders at native device vector resolution (infinite DPI, never blurry at
/// any size) using authentic botanical Bezier curves, watercolor washes, and
/// fine ink veining.
class SakhiBotanicalFlower extends StatelessWidget {
  final SakhiFlowerType type;
  final double width;
  final double height;
  final double opacity;
  final double angle;
  final bool flipHorizontal;

  const SakhiBotanicalFlower({
    super.key,
    required this.type,
    this.width = 76,
    this.height = 96,
    this.opacity = 0.92,
    this.angle = 0.0,
    this.flipHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        size: Size(width, height),
        painter: _HandDrawnBotanicalPainter(type: type),
      ),
    );

    if (flipHorizontal) {
      child = Transform.scale(scaleX: -1, child: child);
    }
    if (angle != 0.0) {
      child = Transform.rotate(angle: angle, child: child);
    }
    if (opacity < 1.0) {
      child = Opacity(opacity: opacity.clamp(0.0, 1.0), child: child);
    }

    return IgnorePointer(child: child);
  }
}

class _HandDrawnBotanicalPainter extends CustomPainter {
  final SakhiFlowerType type;
  const _HandDrawnBotanicalPainter({required this.type});

  static const Color _ink = Color(0xEB3B222E);
  static const Color _inkVein = Color(0x88523142);
  static const Color _blushLight = Color(0xDDFCE4EE);
  static const Color _blushDeep = Color(0xE0EE9BB9);
  static const Color _lavenderLight = Color(0xDDF0E4FA);
  static const Color _lavenderDeep = Color(0xE0C49CE8);
  static const Color _sageLight = Color(0xDDDCE6D8);
  static const Color _sageDeep = Color(0xE08BA388);

  void _drawStem(
    Canvas canvas,
    Offset p0,
    Offset c1,
    Offset c2,
    Offset p1, {
    double strokeWidth = 1.6,
  }) {
    final path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p1.dx, p1.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawLeaf(
    Canvas canvas, {
    required Offset origin,
    required double angle,
    required double length,
    required double width,
    bool blushTone = false,
  }) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle);

    final path = Path()
      ..moveTo(0, 0)
      ..cubicTo(
        length * 0.35,
        -width * 0.65,
        length * 0.75,
        -width * 0.45,
        length,
        0,
      )
      ..cubicTo(
        length * 0.75,
        width * 0.45,
        length * 0.35,
        width * 0.65,
        0,
        0,
      )
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: blushTone
            ? [_lavenderDeep, _blushLight]
            : [_sageDeep, _sageLight],
      ).createShader(Rect.fromLTWH(0, -width, length, width * 2));
    canvas.drawPath(path, fillPaint);

    canvas.drawPath(
      path,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15,
    );

    // Midrib + side veins
    final veinPaint = Paint()
      ..color = _inkVein
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset.zero, Offset(length * 0.9, 0), veinPaint);
    for (final t in const [0.3, 0.55, 0.75]) {
      final vx = length * t;
      final vw = width * 0.28 * (1 - (t - 0.5).abs());
      canvas.drawLine(
        Offset(vx, 0),
        Offset(vx + length * 0.11, -vw),
        veinPaint,
      );
      canvas.drawLine(
        Offset(vx, 0),
        Offset(vx + length * 0.11, vw),
        veinPaint,
      );
    }
    canvas.restore();
  }

  void _drawBotanicalPetal(
    Canvas canvas, {
    required Offset center,
    required double angle,
    required double length,
    required double width,
    Color innerColor = _blushDeep,
    Color outerColor = _blushLight,
    int veins = 5,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final path = Path()
      ..moveTo(0, 0)
      ..cubicTo(
        length * 0.24,
        -width * 0.55,
        length * 0.74,
        -width * 0.85,
        length * 0.95,
        -width * 0.20,
      )
      ..cubicTo(
        length * 1.03,
        -width * 0.07,
        length * 1.03,
        width * 0.07,
        length * 0.95,
        width * 0.20,
      )
      ..cubicTo(
        length * 0.74,
        width * 0.85,
        length * 0.24,
        width * 0.55,
        0,
        0,
      )
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [innerColor, outerColor],
      ).createShader(Rect.fromLTWH(0, -width, length, width * 2));
    canvas.drawPath(path, fillPaint);

    canvas.drawPath(
      path,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15
        ..strokeJoin = StrokeJoin.round,
    );

    final veinPaint = Paint()
      ..color = _inkVein
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.65
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < veins; i++) {
      final frac = (veins <= 1) ? 0.0 : (i / (veins - 1)) - 0.5;
      final vyEnd = frac * width * 0.62;
      final vLen = length * (0.78 - 0.16 * frac.abs());
      final vPath = Path()
        ..moveTo(length * 0.07, frac * 2.0)
        ..cubicTo(
          length * 0.35,
          vyEnd * 0.38,
          length * 0.62,
          vyEnd * 0.84,
          vLen,
          vyEnd,
        );
      canvas.drawPath(vPath, veinPaint);
    }

    canvas.restore();
  }

  void _drawStamenCluster(
    Canvas canvas,
    Offset center, {
    int count = 14,
    double radius = 10,
  }) {
    final linePaint = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85;
    final dotPaint = Paint()
      ..color = _ink
      ..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final ang = (2 * math.pi * i) / count;
      final r = radius * (0.76 + 0.24 * ((i * 5) % 3) / 2.0);
      final tip = Offset(
        center.dx + math.cos(ang) * r,
        center.dy + math.sin(ang) * r,
      );
      canvas.drawLine(center, tip, linePaint);
      canvas.drawCircle(tip, 1.4, dotPaint);
    }
    canvas.drawCircle(center, radius * 0.28, dotPaint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 100.0;
    final sy = size.height / 125.0;
    final s = math.min(sx, sy);
    canvas.save();
    canvas.translate(
      (size.width - 100 * s) * 0.5,
      (size.height - 125 * s) * 0.5,
    );
    canvas.scale(s, s);

    switch (type) {
      case SakhiFlowerType.poppyBlush:
        _drawStem(
          canvas,
          const Offset(50, 118),
          const Offset(47, 90),
          const Offset(53, 64),
          const Offset(50, 42),
        );
        _drawLeaf(
          canvas,
          origin: const Offset(50, 88),
          angle: -0.65,
          length: 24,
          width: 7,
        );
        _drawLeaf(
          canvas,
          origin: const Offset(50, 96),
          angle: -2.45,
          length: 20,
          width: 6,
        );
        for (final ang in const [-2.45, -1.85, -1.25, -0.65, -2.80, -0.30]) {
          _drawBotanicalPetal(
            canvas,
            center: const Offset(50, 43),
            angle: ang,
            length: 29,
            width: 20,
          );
        }
        _drawStamenCluster(canvas, const Offset(50, 41), count: 16, radius: 7);
        break;

      case SakhiFlowerType.lavenderSprig:
        _drawStem(
          canvas,
          const Offset(50, 118),
          const Offset(48, 86),
          const Offset(52, 54),
          const Offset(49, 18),
        );
        _drawLeaf(
          canvas,
          origin: const Offset(49, 102),
          angle: -0.95,
          length: 28,
          width: 5.5,
        );
        _drawLeaf(
          canvas,
          origin: const Offset(50, 105),
          angle: -2.20,
          length: 27,
          width: 5.5,
        );
        _drawLeaf(
          canvas,
          origin: const Offset(50, 86),
          angle: -0.82,
          length: 22,
          width: 4.5,
        );
        _drawLeaf(
          canvas,
          origin: const Offset(50, 89),
          angle: -2.32,
          length: 21,
          width: 4.5,
        );
        for (var y = 22.0; y <= 74.0; y += 7.5) {
          final sc = 0.58 + 0.42 * ((y - 20.0) / 56.0);
          _drawBotanicalPetal(
            canvas,
            center: Offset(50, y),
            angle: -0.88,
            length: 10.5 * sc,
            width: 5.8 * sc,
            innerColor: _lavenderDeep,
            outerColor: _lavenderLight,
            veins: 2,
          );
          _drawBotanicalPetal(
            canvas,
            center: Offset(50, y),
            angle: -2.26,
            length: 10.5 * sc,
            width: 5.8 * sc,
            innerColor: _lavenderDeep,
            outerColor: _lavenderLight,
            veins: 2,
          );
          _drawBotanicalPetal(
            canvas,
            center: Offset(50, y - 1.5),
            angle: -1.57,
            length: 9.0 * sc,
            width: 4.8 * sc,
            innerColor: _lavenderDeep,
            outerColor: _lavenderLight,
            veins: 2,
          );
        }
        break;

      case SakhiFlowerType.lilyBloom:
        _drawStem(
          canvas,
          const Offset(49, 118),
          const Offset(47, 88),
          const Offset(52, 66),
          const Offset(50, 44),
        );
        _drawLeaf(
          canvas,
          origin: const Offset(50, 90),
          angle: -0.60,
          length: 26,
          width: 7,
        );
        _drawLeaf(
          canvas,
          origin: const Offset(50, 79),
          angle: -2.50,
          length: 24,
          width: 6.5,
        );
        for (final ang in const [-2.55, -2.02, -1.57, -1.12, -0.58, 0.38, 2.76]) {
          _drawBotanicalPetal(
            canvas,
            center: const Offset(50, 45),
            angle: ang,
            length: 30,
            width: 12,
          );
        }
        _drawStamenCluster(canvas, const Offset(50, 43), count: 7, radius: 11);
        break;

      case SakhiFlowerType.hibiscusRose:
        _drawStem(
          canvas,
          const Offset(52, 118),
          const Offset(49, 92),
          const Offset(50, 68),
          const Offset(50, 47),
        );
        _drawLeaf(
          canvas,
          origin: const Offset(50, 84),
          angle: -0.55,
          length: 22,
          width: 9,
        );
        _drawLeaf(
          canvas,
          origin: const Offset(49, 93),
          angle: -2.50,
          length: 21,
          width: 8.5,
        );
        for (var i = 0; i < 5; i++) {
          final ang = -math.pi / 2 + (2 * math.pi * i) / 5.0;
          _drawBotanicalPetal(
            canvas,
            center: const Offset(50, 47),
            angle: ang,
            length: 27,
            width: 20,
          );
        }
        _drawStem(
          canvas,
          const Offset(50, 47),
          const Offset(54, 39),
          const Offset(58, 33),
          const Offset(61, 27),
          strokeWidth: 1.3,
        );
        _drawStamenCluster(canvas, const Offset(61, 27), count: 10, radius: 4);
        break;

      case SakhiFlowerType.peonySoft:
        _drawStem(
          canvas,
          const Offset(50, 118),
          const Offset(50, 94),
          const Offset(49, 72),
          const Offset(50, 52),
        );
        _drawLeaf(
          canvas,
          origin: const Offset(50, 86),
          angle: -0.52,
          length: 25,
          width: 8.5,
        );
        _drawLeaf(
          canvas,
          origin: const Offset(50, 90),
          angle: -2.62,
          length: 25,
          width: 8.5,
        );
        for (var ring = 0; ring < 3; ring++) {
          final cnt = 7 - ring;
          final len = 28.0 - ring * 5.0;
          final wid = 19.0 - ring * 3.0;
          for (var i = 0; i < cnt; i++) {
            final ang = -math.pi + (math.pi * i) / math.max(1, cnt - 1);
            _drawBotanicalPetal(
              canvas,
              center: Offset(50, 52.0 - ring * 1.5),
              angle: ang,
              length: len,
              width: wid,
            );
          }
        }
        _drawStamenCluster(canvas, const Offset(50, 48), count: 12, radius: 5);
        break;

      case SakhiFlowerType.cherryBlossom:
        _drawStem(
          canvas,
          const Offset(55, 118),
          const Offset(46, 86),
          const Offset(52, 54),
          const Offset(46, 20),
        );
        _drawStem(
          canvas,
          const Offset(50, 77),
          const Offset(58, 68),
          const Offset(64, 60),
          const Offset(70, 52),
          strokeWidth: 1.2,
        );
        _drawStem(
          canvas,
          const Offset(49, 55),
          const Offset(41, 47),
          const Offset(35, 40),
          const Offset(31, 33),
          strokeWidth: 1.2,
        );
        for (final node in const [
          [49.0, 72.0, 0.95],
          [68.0, 52.0, 0.80],
          [34.0, 36.0, 0.84],
          [46.0, 24.0, 0.74],
        ]) {
          final bx = node[0];
          final by = node[1];
          final sc = node[2];
          for (var i = 0; i < 5; i++) {
            final ang = (2 * math.pi * i) / 5.0 - 0.3;
            _drawBotanicalPetal(
              canvas,
              center: Offset(bx, by),
              angle: ang,
              length: 13.0 * sc,
              width: 9.0 * sc,
              veins: 3,
            );
          }
          _drawStamenCluster(
            canvas,
            Offset(bx, by),
            count: 8,
            radius: 3.2 * sc,
          );
        }
        _drawLeaf(
          canvas,
          origin: const Offset(52, 94),
          angle: -0.5,
          length: 16,
          width: 5.5,
        );
        _drawLeaf(
          canvas,
          origin: const Offset(48, 86),
          angle: -2.5,
          length: 15,
          width: 5,
        );
        break;

      case SakhiFlowerType.tulipDuo:
        _drawStem(
          canvas,
          const Offset(45, 118),
          const Offset(42, 86),
          const Offset(40, 60),
          const Offset(39, 40),
        );
        _drawStem(
          canvas,
          const Offset(46, 118),
          const Offset(52, 90),
          const Offset(58, 70),
          const Offset(62, 55),
        );
        _drawLeaf(
          canvas,
          origin: const Offset(45, 110),
          angle: -1.10,
          length: 44,
          width: 8,
        );
        _drawLeaf(
          canvas,
          origin: const Offset(47, 112),
          angle: -0.58,
          length: 38,
          width: 7.5,
        );
        for (final t in const [
          [39.0, 42.0, 1.0],
          [62.0, 56.0, 0.84],
        ]) {
          for (final ang in const [-1.92, -1.22, -1.57]) {
            _drawBotanicalPetal(
              canvas,
              center: Offset(t[0], t[1]),
              angle: ang,
              length: 22 * t[2],
              width: 12.5 * t[2],
              innerColor: _lavenderDeep,
              outerColor: _blushLight,
              veins: 4,
            );
          }
        }
        break;

      case SakhiFlowerType.cosmosViolet:
        _drawStem(
          canvas,
          const Offset(49, 118),
          const Offset(46, 88),
          const Offset(50, 65),
          const Offset(50, 44),
        );
        _drawLeaf(
          canvas,
          origin: const Offset(48, 86),
          angle: -0.65,
          length: 20,
          width: 5,
        );
        _drawLeaf(
          canvas,
          origin: const Offset(48, 95),
          angle: -2.45,
          length: 18,
          width: 4.5,
        );
        for (var i = 0; i < 8; i++) {
          final ang = (2 * math.pi * i) / 8.0;
          _drawBotanicalPetal(
            canvas,
            center: const Offset(50, 44),
            angle: ang,
            length: 23,
            width: 11,
            innerColor: _lavenderDeep,
            outerColor: _lavenderLight,
            veins: 4,
          );
        }
        _drawStamenCluster(canvas, const Offset(50, 44), count: 14, radius: 4.5);
        break;

      case SakhiFlowerType.orchidBranch:
        _drawStem(
          canvas,
          const Offset(43, 118),
          const Offset(36, 84),
          const Offset(42, 46),
          const Offset(62, 22),
        );
        for (final node in const [
          [40.0, 70.0, 0.95],
          [46.0, 44.0, 0.88],
          [58.0, 27.0, 0.66],
        ]) {
          for (final ang in const [-2.4, -0.7, -1.57, 0.6, 2.5]) {
            _drawBotanicalPetal(
              canvas,
              center: Offset(node[0], node[1]),
              angle: ang,
              length: 14 * node[2],
              width: 9.5 * node[2],
              innerColor: _blushDeep,
              outerColor: _lavenderLight,
              veins: 3,
            );
          }
          _drawStamenCluster(
            canvas,
            Offset(node[0], node[1]),
            count: 6,
            radius: 2.5 * node[2],
          );
        }
        _drawLeaf(
          canvas,
          origin: const Offset(42, 108),
          angle: -0.6,
          length: 22,
          width: 7.5,
        );
        _drawLeaf(
          canvas,
          origin: const Offset(42, 111),
          angle: -2.4,
          length: 20,
          width: 7,
        );
        break;

      case SakhiFlowerType.roseClassic:
        _drawStem(
          canvas,
          const Offset(50, 118),
          const Offset(49, 90),
          const Offset(51, 66),
          const Offset(50, 46),
        );
        _drawLeaf(
          canvas,
          origin: const Offset(50, 78),
          angle: -0.55,
          length: 21,
          width: 8,
        );
        _drawLeaf(
          canvas,
          origin: const Offset(50, 86),
          angle: -2.55,
          length: 21,
          width: 8,
        );
        for (var ring = 0; ring < 3; ring++) {
          final cnt = 7 - ring;
          final len = 24.0 - ring * 4.5;
          final wid = 16.5 - ring * 2.5;
          for (var i = 0; i < cnt; i++) {
            final ang = (2 * math.pi * i) / cnt + ring * 0.35;
            _drawBotanicalPetal(
              canvas,
              center: const Offset(50, 45),
              angle: ang,
              length: len,
              width: wid,
              veins: 4,
            );
          }
        }
        _drawStamenCluster(canvas, const Offset(50, 45), count: 10, radius: 3.5);
        break;

      case SakhiFlowerType.babysBreath:
        _drawStem(
          canvas,
          const Offset(50, 118),
          const Offset(49, 86),
          const Offset(51, 56),
          const Offset(49, 24),
          strokeWidth: 1.3,
        );
        const branches = [
          [50.0, 90.0, 31.0, 60.0],
          [50.0, 83.0, 69.0, 55.0],
          [50.0, 70.0, 30.0, 38.0],
          [50.0, 63.0, 70.0, 35.0],
          [50.0, 48.0, 36.0, 22.0],
          [50.0, 43.0, 64.0, 20.0],
        ];
        for (final b in branches) {
          _drawStem(
            canvas,
            Offset(b[0], b[1]),
            Offset((b[0] + b[2]) * 0.5, b[1] - 10),
            Offset((b[0] + b[2]) * 0.5, b[3] + 6),
            Offset(b[2], b[3]),
            strokeWidth: 0.9,
          );
          for (final t in const [0.55, 1.0]) {
            final bx = b[0] + (b[2] - b[0]) * t;
            final by = b[1] + (b[3] - b[1]) * t;
            for (var a = 0; a < 5; a++) {
              _drawBotanicalPetal(
                canvas,
                center: Offset(bx, by),
                angle: a * 1.25,
                length: 4.8,
                width: 3.2,
                veins: 1,
              );
            }
          }
        }
        break;

      case SakhiFlowerType.eucalyptusSage:
        _drawStem(
          canvas,
          const Offset(48, 118),
          const Offset(46, 85),
          const Offset(52, 52),
          const Offset(50, 18),
        );
        for (var idx = 0; idx < 7; idx++) {
          final y = 26.0 + idx * 12.0;
          final sc = 0.65 + 0.38 * (idx / 6.0);
          final blush = idx.isEven;
          _drawLeaf(
            canvas,
            origin: Offset(50, y),
            angle: -0.62,
            length: 21 * sc,
            width: 8 * sc,
            blushTone: blush,
          );
          _drawLeaf(
            canvas,
            origin: Offset(49, y + 3.5),
            angle: -2.52,
            length: 21 * sc,
            width: 8 * sc,
            blushTone: blush,
          );
        }
        _drawLeaf(
          canvas,
          origin: const Offset(50, 20),
          angle: -1.57,
          length: 15,
          width: 6,
          blushTone: true,
        );
        break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HandDrawnBotanicalPainter oldDelegate) =>
      oldDelegate.type != type;
}
