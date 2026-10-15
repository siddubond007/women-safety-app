import 'package:flutter/material.dart';

/// Generated from branding/brand.json by tool/rebrand.ps1.
abstract final class AppBrand {
  static const String appName = 'Sakhi';
  static const String shortName = 'Sakhi';
  static const String tagline = 'Safer Women. Stronger Together.';
  static const String description =
      'Sakhi — women’s safety, community and wellness.';

  /// Keep these filenames stable; replace their contents when rebranding.
  static const String logoAsset = 'assets/brand/app_logo.png';
  static const String iconAsset = 'assets/brand/app_icon.png';
  static const String logoSemanticsLabel =
      '${AppBrand.appName} — ${AppBrand.tagline}';

  static const Color primaryColor = Color(0xFF79318A);
  static const Color darkTextColor = Color(0xFF321044);
  static const Color mutedTextColor = Color(0xFF8D6C9D);
  static const Color backgroundColor = Color(0xFFFFF4F7);
  static const Color ivoryColor = Color(0xFFFFF8F4);
  static const Color lavenderColor = Color(0xFFF5EAF9);
  static const Color pinkColor = Color(0xFFFFEAF2);
  static const Color progressInactiveColor = Color(0xFFE8CBE4);
}
