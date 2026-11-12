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

    // 2. Hair backdrop (soft dark plum-ebony waves with subtle slow-breeze sway)
    final breezeSway = math.sin(phase * 2 * math.pi) * (w * 0.025);
    final hairPaint = Paint()
      ..color = const Color(0xFF2D1238)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(w * 0.5 + breezeSway * 0.4, h * 0.36 - breathOffset * 0.4),
      w * 0.22,
      hairPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.5 + breezeSway, h * 0.50),
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

/// Section 9.1 — Home Hero Woman Animation:
/// 1. Begins facing away (backside with flowing hair & floral gajra), then smoothly
///    turns toward the viewer (`0.0 -> 1.0` over 1.75 seconds, once per reveal).
/// 2. After turning to the front, maintains a subtle, continuous slow-breeze hair
///    and dupatta motion without restarting the turn.
/// 3. Respects `MediaQuery.maybeDisableAnimationsOf(context)` with a clean static
///    front-facing fallback.
class SakhiAnimatedHomeHeroWoman extends StatefulWidget {
  final double width;
  final double height;

  const SakhiAnimatedHomeHeroWoman({
    super.key,
    this.width = 148,
    this.height = 156,
  });

  @override
  State<SakhiAnimatedHomeHeroWoman> createState() =>
      _SakhiAnimatedHomeHeroWomanState();
}

class _SakhiAnimatedHomeHeroWomanState extends State<SakhiAnimatedHomeHeroWoman>
    with TickerProviderStateMixin {
  late final AnimationController _turnController;
  late final AnimationController _breezeController;

  @override
  void initState() {
    super.initState();
    _turnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1750),
    )..forward();

    _breezeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _turnController.dispose();
    _breezeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: Listenable.merge([_turnController, _breezeController]),
          builder: (context, _) {
            final turnProgress = reduceMotion
                ? 1.0
                : Curves.easeInOutCubic.transform(_turnController.value);
            final breezePhase = reduceMotion ? 0.35 : _breezeController.value;
            return CustomPaint(
              painter: _SakhiHeroTurnAndBreezePainter(
                turnProgress: turnProgress,
                breezePhase: breezePhase,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SakhiHeroTurnAndBreezePainter extends CustomPainter {
  final double turnProgress; // 0.0 = facing away (backside), 1.0 = facing viewer (front)
  final double breezePhase; // 0.0 .. 1.0 continuous slow-breeze cycle

  const _SakhiHeroTurnAndBreezePainter({
    required this.turnProgress,
    required this.breezePhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final breezeAngle = math.sin(breezePhase * 2 * math.pi);
    final hairSwayX = breezeAngle * (w * 0.045);
    final breathY = math.cos(breezePhase * math.pi) * (h * 0.012);

    // 3D horizontal turn factor: cos(pi * (1 - turnProgress))
    // -1.0 = full back view, 0.0 = side profile transition, +1.0 = full front view
    final cosTurn = math.cos(math.pi * (1.0 - turnProgress));
    final horizontalScale = cosTurn.abs().clamp(0.28, 1.0);
    final isFrontVisible = turnProgress >= 0.5;

    // 1. Soft sunlit pastel halo behind hero woman
    canvas.drawCircle(
      Offset(w * 0.52, h * 0.48),
      w * 0.44,
      Paint()..color = const Color(0xFFFFD6E8).withValues(alpha: 0.52),
    );

    // 2. Flowing long hair ribbon & slow-breeze strands behind shoulders
    final hairColor = const Color(0xFF280E32);
    final hairHighlightColor = const Color(0xFF4A1D5C);
    final hairBackPath = Path()
      ..moveTo(w * 0.32, h * 0.32 - breathY)
      ..cubicTo(
        w * 0.20 + hairSwayX * 0.6,
        h * 0.52,
        w * 0.22 + hairSwayX * 1.3,
        h * 0.76,
        w * 0.34 + hairSwayX * 1.5,
        h * 0.88,
      )
      ..quadraticBezierTo(
        w * 0.52 + hairSwayX,
        h * 0.94,
        w * 0.68 + hairSwayX * 1.4,
        h * 0.85,
      )
      ..cubicTo(
        w * 0.78 + hairSwayX * 1.1,
        h * 0.70,
        w * 0.76 + hairSwayX * 0.5,
        h * 0.48,
        w * 0.68,
        h * 0.32 - breathY,
      )
      ..close();
    canvas.drawPath(hairBackPath, Paint()..color = hairColor);

    // Breeze hair strand highlights
    final strandPaint = Paint()
      ..color = hairHighlightColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.64, h * 0.38 - breathY)
        ..quadraticBezierTo(
          w * 0.76 + hairSwayX * 1.6,
          h * 0.58,
          w * 0.72 + hairSwayX * 2.0,
          h * 0.80,
        ),
      strandPaint,
    );

    // 3. Shoulders & Draped Dupatta / Kurti
    final torsoPath = Path()
      ..moveTo(w * 0.22, h * 0.98)
      ..quadraticBezierTo(
        w * 0.27,
        h * 0.58 - breathY,
        w * 0.50,
        h * 0.57 - breathY,
      )
      ..quadraticBezierTo(
        w * 0.73,
        h * 0.58 - breathY,
        w * 0.78,
        h * 0.98,
      )
      ..close();
    canvas.drawPath(
      torsoPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD63E85), Color(0xFF7B228E)],
        ).createShader(Rect.fromLTWH(0, h * 0.55, w, h * 0.45)),
    );

    // Dupatta breeze drape
    final dupattaPath = Path()
      ..moveTo(w * 0.30, h * 0.60 - breathY)
      ..quadraticBezierTo(
        w * 0.52 + hairSwayX * 0.8,
        h * 0.74,
        w * 0.76 + hairSwayX * 1.2,
        h * 0.66,
      )
      ..lineTo(w * 0.78, h * 0.82)
      ..quadraticBezierTo(
        w * 0.50 + hairSwayX * 0.6,
        h * 0.88,
        w * 0.28,
        h * 0.74,
      )
      ..close();
    canvas.drawPath(
      dupattaPath,
      Paint()..color = const Color(0xFFFBCFE8).withValues(alpha: 0.72),
    );

    // 4. Head & Turn Perspective
    final headCenter = Offset(w * 0.50, h * 0.34 - breathY);
    final skinPaint = Paint()..color = const Color(0xFFE8A888);

    // Neck
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.51 - breathY * 0.6),
          width: w * 0.11,
          height: h * 0.12,
        ),
        Radius.circular(w * 0.04),
      ),
      skinPaint,
    );

    if (!isFrontVisible) {
      // Back-of-head view (0.0 .. 0.5): full dark crown hair + floral gajra garland on back bun
      canvas.drawOval(
        Rect.fromCenter(
          center: headCenter,
          width: w * 0.34,
          height: h * 0.33,
        ),
        Paint()..color = hairColor,
      );
      // Braided bun & jasmine gajra arc on the back of her hair
      final bunCenter = Offset(
        headCenter.dx - (turnProgress * w * 0.06),
        headCenter.dy + h * 0.05,
      );
      canvas.drawCircle(bunCenter, w * 0.10, Paint()..color = const Color(0xFF1E0926));
      for (var i = -2; i <= 2; i++) {
        final angle = (i * 0.38) + 0.5 * math.pi;
        final gx = bunCenter.dx + math.cos(angle) * (w * 0.105);
        final gy = bunCenter.dy + math.sin(angle) * (w * 0.085);
        canvas.drawCircle(
          Offset(gx, gy),
          w * 0.022,
          Paint()..color = const Color(0xFFFFF1F2),
        );
      }
    } else {
      // Front-facing reveal (0.5 .. 1.0): face smoothly widens to full frontal serenity
      final faceOpacity = ((turnProgress - 0.5) * 2.0).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: headCenter,
          width: w * 0.32,
          height: h * 0.32,
        ),
        skinPaint,
      );

      // Crown hair parting framing the face + breeze-swept side lock
      final crownPath = Path()
        ..moveTo(headCenter.dx - w * 0.16, headCenter.dy - h * 0.01)
        ..quadraticBezierTo(
          headCenter.dx,
          headCenter.dy - h * 0.21,
          headCenter.dx + w * 0.16,
          headCenter.dy - h * 0.01,
        )
        ..quadraticBezierTo(
          headCenter.dx + hairSwayX * 0.3,
          headCenter.dy - h * 0.11,
          headCenter.dx - w * 0.16,
          headCenter.dy - h * 0.01,
        )
        ..close();
      canvas.drawPath(crownPath, Paint()..color = hairColor);

      // Jasmine/lotus flower tucked behind right ear
      canvas.drawCircle(
        Offset(headCenter.dx + w * 0.15 + hairSwayX * 0.2, headCenter.dy - h * 0.02),
        w * 0.036,
        Paint()..color = const Color(0xFFFFB3D1).withValues(alpha: faceOpacity),
      );

      // Facial features shifted slightly during the turn for realistic 3D rotation
      final featureShiftX = (1.0 - horizontalScale) * (w * 0.06);
      final faceCenter = Offset(headCenter.dx + featureShiftX, headCenter.dy);

      // Bindi
      canvas.drawCircle(
        Offset(faceCenter.dx, faceCenter.dy - h * 0.048),
        w * 0.015,
        Paint()..color = const Color(0xFFBE185D).withValues(alpha: faceOpacity),
      );

      final eyePaint = Paint()
        ..color = const Color(0xFF3B1347).withValues(alpha: faceOpacity)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final eyeSpread = w * 0.056 * horizontalScale;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(faceCenter.dx - eyeSpread, faceCenter.dy - h * 0.01),
          width: w * 0.046 * horizontalScale,
          height: h * 0.022,
        ),
        0.1,
        math.pi - 0.2,
        false,
        eyePaint,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(faceCenter.dx + eyeSpread, faceCenter.dy - h * 0.01),
          width: w * 0.046 * horizontalScale,
          height: h * 0.022,
        ),
        0.1,
        math.pi - 0.2,
        false,
        eyePaint,
      );

      // Warm welcoming smile
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(faceCenter.dx, faceCenter.dy + h * 0.046),
          width: w * 0.072 * horizontalScale,
          height: h * 0.036,
        ),
        0.15,
        math.pi - 0.3,
        false,
        eyePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SakhiHeroTurnAndBreezePainter oldDelegate) {
    return (oldDelegate.turnProgress - turnProgress).abs() > 0.003 ||
        (oldDelegate.breezePhase - breezePhase).abs() > 0.003;
  }
}
