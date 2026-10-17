import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double screenPaddingH = 18;
  static const double screenPaddingV = 12;
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusXl = 24;
  static const double radiusPill = 999;

  static List<BoxShadow> get cardShadow => const [
    BoxShadow(color: Color(0x0D79318A), blurRadius: 14, offset: Offset(0, 4)),
  ];

  static List<BoxShadow> get navBarShadow => const [
    BoxShadow(color: Color(0x122D1441), blurRadius: 20, offset: Offset(0, -4)),
  ];
}
