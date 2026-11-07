import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Ambient pastel aurora mesh background that makes iOS 26 Liquid Glass cards
/// refract soft rose-quartz, orchid-lavender, champagne-pearl, and mint-mist light.
/// Wrapped in a RepaintBoundary so scrolling over it runs at 60–120 FPS with zero GPU repaint cost.
class SakhiLiquidGlassAmbientMesh extends StatelessWidget {
  final Widget child;

  const SakhiLiquidGlassAmbientMesh({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFDF2F8),
                    Color(0xFFF5E8FC),
                    Color(0xFFFEF6F0),
                    Color(0xFFF2F9F6),
                  ],
                  stops: [0.0, 0.36, 0.72, 1.0],
                ),
              ),
              child: CustomPaint(
                painter: _AuroraGlassOrbsPainter(),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _AuroraGlassOrbsPainter extends CustomPainter {
  const _AuroraGlassOrbsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.auroraOrchidOrb.withValues(alpha: 0.55),
          AppColors.auroraOrchidOrb.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.88, size.height * 0.12),
          radius: size.width * 0.62,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.12),
      size.width * 0.62,
      p1,
    );

    final p2 = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.auroraRoseOrb.withValues(alpha: 0.52),
          AppColors.auroraRoseOrb.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.12, size.height * 0.38),
          radius: size.width * 0.58,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.38),
      size.width * 0.58,
      p2,
    );

    final p3 = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.auroraMintOrb.withValues(alpha: 0.42),
          AppColors.auroraMintOrb.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.82, size.height * 0.68),
          radius: size.width * 0.55,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.68),
      size.width * 0.55,
      p3,
    );

    final p4 = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.auroraChampagneOrb.withValues(alpha: 0.46),
          AppColors.auroraChampagneOrb.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.22, size.height * 0.86),
          radius: size.width * 0.52,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.22, size.height * 0.86),
      size.width * 0.52,
      p4,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// iOS 26 Liquid Glass UI Design System for Sakhi (works identically on iOS & Android).
/// Provides frosted optical blur, specular top-edge highlights, soft inner luminance,
/// and subtle lavender-rose glass refraction.
class SakhiLiquidGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurSigma;
  final Color? tintColor;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enableBackdropBlur;

  const SakhiLiquidGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 24.0,
    this.blurSigma = 20.0,
    this.tintColor,
    this.borderColor,
    this.boxShadow,
    this.onTap,
    this.onLongPress,
    this.enableBackdropBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final baseTint = tintColor ?? const Color(0xD6FFFFFF);
    final edgeColor = borderColor ?? const Color(0xF2FFFFFF);

    Widget glassSurface = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: const Alignment(-0.9, -1.0),
          end: const Alignment(0.9, 1.0),
          colors: [
            baseTint.withValues(alpha: 0.88),
            const Color(0xB8FDF2FA),
            const Color(0xCCEFE2FA),
            baseTint.withValues(alpha: 0.82),
          ],
          stops: const [0.0, 0.42, 0.78, 1.0],
        ),
        border: Border.all(
          color: edgeColor,
          width: 1.5,
        ),
      ),
      child: child,
    );

    if (enableBackdropBlur && blurSigma > 0) {
      glassSurface = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: glassSurface,
        ),
      );
    } else {
      glassSurface = ClipRRect(
        borderRadius: radius,
        child: glassSurface,
      );
    }

    if (onTap != null || onLongPress != null) {
      glassSurface = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          onLongPress: onLongPress,
          child: glassSurface,
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: const Color(0xFF5A1868).withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.80),
                blurRadius: 2,
                spreadRadius: 0.6,
                offset: const Offset(0, -1),
              ),
            ],
      ),
      child: glassSurface,
    );
  }
}

/// Floating iOS 26 Liquid Glass Pill Badge or Chip.
class SakhiLiquidGlassPill extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  const SakhiLiquidGlassPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    this.backgroundColor,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (backgroundColor ?? Colors.white).withValues(alpha: 0.88),
            (backgroundColor ?? const Color(0xFFF9EEF8))
                .withValues(alpha: 0.72),
          ],
        ),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.92),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5A1868).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return pill;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: pill,
    );
  }
}

/// Curated official Sakhi community & application interests list.
const List<String> kSakhiCuratedInterests = <String>[
  'Mental Wellness',
  'Safety & Support',
  'WomenInTech',
  'Health & Wellness',
  'Women Businesses',
  'Education & Career',
  'Menstrual Care',
  'Fitness & Nutrition',
  'Mindfulness & Yoga',
  'Travel',
  'Reading',
  'Art & Creativity',
  'Legal Rights',
  'Motherhood & Family',
  'Financial Independence',
  'Sustainable Living',
];
