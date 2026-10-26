import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Three-tier feminine typography hierarchy for Sakhi (Android & iOS):
/// 1. Editorial Serif (`editorialSerifFamily` + fallbacks) for empathetic titles, headers & quotes
/// 2. Clean Geometric Sans (`uiSansFamily` + fallbacks) for cards, buttons, forms & labels
/// 3. Cryptographic Monospace (`monoFamily` + fallbacks) for anonymous reference tokens & hashes
class AppTypography {
  AppTypography._();

  static const String editorialSerifFamily = 'Georgia';
  static const List<String> editorialSerifFallbacks = <String>[
    'Noto Serif',
    'Playfair Display',
    'Baskerville',
    'Didot',
    'serif',
  ];

  static const String uiSansFamily = 'sans-serif';
  static const List<String> uiSansFallbacks = <String>[
    'Inter',
    '.SF UI Text',
    '.SF Pro Text',
    'Roboto',
    'Helvetica Neue',
    'sans-serif',
  ];

  static const String monoFamily = 'monospace';
  static const List<String> monoFallbacks = <String>[
    'JetBrains Mono',
    'Roboto Mono',
    'Menlo',
    'Courier',
    'monospace',
  ];

  static const TextStyle appBarTitle = TextStyle(
    fontFamily: editorialSerifFamily,
    fontFamilyFallback: editorialSerifFallbacks,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle heroTitle = TextStyle(
    fontFamily: editorialSerifFamily,
    fontFamilyFallback: editorialSerifFallbacks,
    fontSize: 21,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.22,
    letterSpacing: -0.3,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: editorialSerifFamily,
    fontFamilyFallback: editorialSerifFallbacks,
    fontSize: 17.5,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle editorialQuote = TextStyle(
    fontFamily: editorialSerifFamily,
    fontFamilyFallback: editorialSerifFallbacks,
    fontStyle: FontStyle.italic,
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryPurple,
    height: 1.42,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: uiSansFamily,
    fontFamilyFallback: uiSansFallbacks,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  static const TextStyle bodyRegular = TextStyle(
    fontFamily: uiSansFamily,
    fontFamilyFallback: uiSansFallbacks,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.42,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: uiSansFamily,
    fontFamilyFallback: uiSansFallbacks,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: uiSansFamily,
    fontFamilyFallback: uiSansFallbacks,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.32,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: uiSansFamily,
    fontFamilyFallback: uiSansFallbacks,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    height: 1.25,
  );

  static const TextStyle chipLabel = TextStyle(
    fontFamily: uiSansFamily,
    fontFamilyFallback: uiSansFallbacks,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryPurple,
  );

  static const TextStyle navLabel = TextStyle(
    fontFamily: uiSansFamily,
    fontFamilyFallback: uiSansFallbacks,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
  );

  static const TextStyle monoToken = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallbacks,
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 0.4,
  );
}
