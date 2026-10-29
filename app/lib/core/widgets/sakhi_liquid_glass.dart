import 'dart:ui';
import 'package:flutter/material.dart';

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

  const SakhiLiquidGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 24.0,
    this.blurSigma = 22.0,
    this.tintColor,
    this.borderColor,
    this.boxShadow,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final baseTint = tintColor ?? const Color(0xD9FFFFFF);
    final edgeColor = borderColor ?? const Color(0xB8FFFFFF);

    Widget content = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseTint.withValues(alpha: 0.90),
                const Color(0xCCFDF7FC),
                baseTint.withValues(alpha: 0.78),
              ],
              stops: const [0.0, 0.52, 1.0],
            ),
            border: Border.all(
              color: edgeColor,
              width: 1.35,
            ),
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null || onLongPress != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          onLongPress: onLongPress,
          child: content,
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
                color: const Color(0xFF5A1868).withValues(alpha: 0.07),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.65),
                blurRadius: 2,
                spreadRadius: 0.5,
                offset: const Offset(0, -1),
              ),
            ],
      ),
      child: content,
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
    final pill = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
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
              color: borderColor ?? Colors.white.withValues(alpha: 0.85),
              width: 1.2,
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
        ),
      ),
    );

    if (onTap == null) return pill;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: pill,
    );
  }
}

/// Curated official Sakhi community & application interests list (Flaw 6 Fix:
/// replaces free-text custom interest entry with structured application categories).
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
