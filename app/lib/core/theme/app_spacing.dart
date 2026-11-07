import 'package:flutter/material.dart';

/// Consistent layout spacing, border radii, and shadow presets.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;

  static const double screenPaddingH = 18.0;
  static const double screenPaddingV = 12.0;

  static const double radiusSm = 10.0;
  static const double radiusMd = 14.0;
  static const double radiusLg = 18.0;
  static const double radiusXl = 24.0;
  static const double radiusPill = 999.0;

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF79318A).withValues(alpha: 0.05),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get navBarShadow => [
        BoxShadow(
          color: const Color(0xFF2D1441).withValues(alpha: 0.07),
          blurRadius: 20,
          offset: const Offset(0, -4),
        ),
      ];
}
