import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum SakhiWomanPose {
  greetingWave,
  meditationLotus,
  breathingCalm,
  cycleCareWarmth,
}

/// Custom 60fps vector illustration of a gentle Indian woman with warm expression,
/// bindi, floral hair accent, and pose-specific gentle breathing/aura motion.
/// Respects system accessibility reduced-motion settings automatically.
class SakhiGentleWomanIllustration extends StatefulWidget {
  final SakhiWomanPose pose;
  final double size;

  const SakhiGentleWomanIllustration({
    super.key,
    required this.pose,
    this.size = 76,
  });

  @override
  State<SakhiGentleWomanIllustration> createState() =>
      _SakhiGentleWomanIllustrationState();
}

class _SakhiGentleWomanIllustrationState
    extends State<SakhiGentleWomanIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final phase = reduceMotion ? 0.5 : _controller.value;
            return CustomPaint(
              painter: _SakhiGentleWomanPainter(
                pose: widget.pose,
                phase: phase,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SakhiGentleWomanPainter extends CustomPainter {
  final SakhiWomanPose pose;
  final double phase;

  const _SakhiGentleWomanPainter({
    required this.pose,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.5);
    final breathOffset = math.sin(phase * math.pi) * (h * 0.018);

    // 1. Soft concentric aura glow
    final outerAuraColor = switch (pose) {
      SakhiWomanPose.greetingWave => const Color(0xFFFCE7F3),
      SakhiWomanPose.meditationLotus => const Color(0xFFF3E8FF),
      SakhiWomanPose.breathingCalm => const Color(0xFFE0E7FF),
      SakhiWomanPose.cycleCareWarmth => const Color(0xFFFFE4E6),
    };
    final innerAuraColor = switch (pose) {
      SakhiWomanPose.greetingWave => const Color(0xFFF9A8D4),
      SakhiWomanPose.meditationLotus => const Color(0xFFC084FC),
      SakhiWomanPose.breathingCalm => const Color(0xFF818CF8),
      SakhiWomanPose.cycleCareWarmth => const Color(0xFFF472B6),
    };

    final auraRadius = (w * 0.46) + (phase * w * 0.035);
    canvas.drawCircle(
      center,
      auraRadius,
      Paint()..color = outerAuraColor.withValues(alpha: 0.72),
    );
    canvas.drawCircle(
      center,
      auraRadius * 0.80,
      Paint()..color = innerAuraColor.withValues(alpha: 0.22),
    );

    // 2. Hair backdrop (soft dark plum-ebony waves)
    final hairPaint = Paint()
      ..color = const Color(0xFF2D1238)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.36 - breathOffset * 0.4),
      w * 0.22,
      hairPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.50),
          width: w * 0.40,
          height: h * 0.34,
        ),
        Radius.circular(w * 0.16),
      ),
      hairPaint,
    );

    // 3. Torso / Kurti silhouette
    final garmentColor = switch (pose) {
      SakhiWomanPose.greetingWave => const Color(0xFFD63E85),
      SakhiWomanPose.meditationLotus => AppColors.primaryPurple,
      SakhiWomanPose.breathingCalm => const Color(0xFF6D28D9),
      SakhiWomanPose.cycleCareWarmth => const Color(0xFFBE185D),
    };
    final torsoPath = Path()
      ..moveTo(w * 0.26, h * 0.86)
      ..quadraticBezierTo(w * 0.30, h * 0.54 - breathOffset, w * 0.50, h * 0.54 - breathOffset)
      ..quadraticBezierTo(w * 0.70, h * 0.54 - breathOffset, w * 0.74, h * 0.86)
      ..close();
    canvas.drawPath(torsoPath, Paint()..color = garmentColor);

    // 4. Neck & Head (warm skin tone)
    final skinPaint = Paint()..color = const Color(0xFFE8A888);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.49 - breathOffset * 0.5),
          width: w * 0.10,
          height: h * 0.10,
        ),
        Radius.circular(w * 0.04),
      ),
      skinPaint,
    );
    final headCenter = Offset(w * 0.5, h * 0.35 - breathOffset * 0.5);
    canvas.drawCircle(headCenter, w * 0.155, skinPaint);

    // 5. Forehead hair parting + floral accent
    final hairFrontPath = Path()
      ..moveTo(headCenter.dx - w * 0.155, headCenter.dy - h * 0.02)
      ..quadraticBezierTo(
        headCenter.dx,
        headCenter.dy - h * 0.19,
        headCenter.dx + w * 0.155,
        headCenter.dy - h * 0.02,
      )
      ..quadraticBezierTo(
        headCenter.dx,
        headCenter.dy - h * 0.10,
        headCenter.dx - w * 0.155,
        headCenter.dy - h * 0.02,
      )
      ..close();
    canvas.drawPath(hairFrontPath, hairPaint);

    // Small lotus/jasmine blossom tucked by ear
    canvas.drawCircle(
      Offset(headCenter.dx + w * 0.145, headCenter.dy - h * 0.03),
      w * 0.038,
      Paint()..color = const Color(0xFFFFB3D1),
    );

    // 6. Bindi, serene eyes & gentle smile
    canvas.drawCircle(
      Offset(headCenter.dx, headCenter.dy - h * 0.045),
      w * 0.016,
      Paint()..color = const Color(0xFFBE185D),
    );

    final featurePaint = Paint()
      ..color = const Color(0xFF3B1347)
      ..strokeWidth = (w * 0.018).clamp(1.2, 2.4)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Closed serene eyes for meditation/breathing, warm curved eyes for greeting
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(headCenter.dx - w * 0.055, headCenter.dy - h * 0.01),
        width: w * 0.05,
        height: h * 0.025,
      ),
      0.1,
      math.pi - 0.2,
      false,
      featurePaint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(headCenter.dx + w * 0.055, headCenter.dy - h * 0.01),
        width: w * 0.05,
        height: h * 0.025,
      ),
      0.1,
      math.pi - 0.2,
      false,
      featurePaint,
    );

    // Gentle smile
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(headCenter.dx, headCenter.dy + h * 0.045),
        width: w * 0.075,
        height: h * 0.038,
      ),
      0.15,
      math.pi - 0.3,
      false,
      featurePaint,
    );

    // 7. Pose-specific hands / lotus petals / warmth heart
    if (pose == SakhiWomanPose.meditationLotus) {
      // Lotus petals at base
      final petalPaint = Paint()
        ..color = const Color(0xFFF472B6).withValues(alpha: 0.85);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.83),
          width: w * 0.38,
          height: h * 0.10,
        ),
        petalPaint,
      );
    } else if (pose == SakhiWomanPose.cycleCareWarmth ||
        pose == SakhiWomanPose.breathingCalm) {
      // Gentle glowing heart/warmth emblem over chest
      canvas.drawCircle(
        Offset(w * 0.5, h * 0.69 - breathOffset),
        w * 0.065 + (phase * w * 0.012),
        Paint()..color = const Color(0xFFFFD6E7).withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SakhiGentleWomanPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        (oldDelegate.phase - phase).abs() > 0.004;
  }
}
