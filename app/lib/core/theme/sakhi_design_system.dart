import 'package:flutter/material.dart';

abstract final class SakhiColors {
  static const plum = Color(0xFF321044);
  static const purple = Color(0xFF79318A);
  static const mutedPlum = Color(0xFF8D6C9D);
  static const blush = Color(0xFFFFF4F7);
  static const ivory = Color(0xFFFFF8F4);
  static const lavender = Color(0xFFF5EAF9);
  static const pink = Color(0xFFFFEAF2);
  static const progressInactive = Color(0xFFE8CBE4);
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
