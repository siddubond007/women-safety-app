import 'package:flutter/material.dart';

import '../branding/app_brand.dart';

abstract final class SakhiColors {
  static const plum = AppBrand.darkTextColor;
  static const purple = AppBrand.primaryColor;
  static const mutedPlum = AppBrand.mutedTextColor;
  static const blush = AppBrand.backgroundColor;
  static const ivory = AppBrand.ivoryColor;
  static const lavender = AppBrand.lavenderColor;
  static const pink = AppBrand.pinkColor;

  /// Saturated foreground pink for icons and controls on pale surfaces.
  static const pinkAccent = Color(0xFFC02668);
  static const progressInactive = AppBrand.progressInactiveColor;
}

abstract final class SakhiSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
}

abstract final class SakhiRadii {
  static const double control = 18;
  static const double pill = 40;
}

abstract final class SakhiTypography {
  static const onboardingTitle = TextStyle(
    color: SakhiColors.plum,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.12,
    letterSpacing: -0.55,
  );

  static const body = TextStyle(
    color: SakhiColors.mutedPlum,
    fontSize: 14.5,
    fontWeight: FontWeight.w500,
    height: 1.42,
  );

  static const categoryLabel = TextStyle(
    color: SakhiColors.plum,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.0,
  );
}
