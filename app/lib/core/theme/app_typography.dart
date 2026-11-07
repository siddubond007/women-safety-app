import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Four-tier feminine & boutique typography hierarchy for Sakhi (Android & iOS):
/// 1. Editorial Serif (`editorialSerifFamily` + fallbacks) for empathetic titles, greetings & quotes
/// 2. Boutique Display Serif (`boutiqueDisplayFamily`) for Module 6 Women-Owned Business Pages
/// 3. Clean Humanist Sans (`uiSansFamily` + fallbacks) for cards, buttons, forms & labels
/// 4. Cryptographic Monospace (`monoFamily` + fallbacks) for anonymous reference tokens & hashes
class AppTypography {
  AppTypography._();

  static const String editorialSerifFamily = 'Georgia';
  static const List<String> editorialSerifFallbacks = <String>[
    'Playfair Display',
    'Cormorant Garamond',
    'Noto Serif',
    'Baskerville',
    'Didot',
    'serif',
  ];

  static const String uiSansFamily = 'sans-serif';
  static const List<String> uiSansFallbacks = <String>[
    'Plus Jakarta Sans',
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
    letterSpacing: -0.35,
  );

  static const TextStyle heroTitle = TextStyle(
    fontFamily: editorialSerifFamily,
    fontFamilyFallback: editorialSerifFallbacks,
    fontSize: 21.5,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.22,
    letterSpacing: -0.35,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: editorialSerifFamily,
    fontFamilyFallback: editorialSerifFallbacks,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.25,
  );

  static const TextStyle editorialQuote = TextStyle(
    fontFamily: editorialSerifFamily,
    fontFamilyFallback: editorialSerifFallbacks,
    fontStyle: FontStyle.italic,
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryPurple,
    height: 1.44,
  );

  // Module 6 Boutique & Women-Owned Business Typography
  static const TextStyle businessDisplayTitle = TextStyle(
    fontFamily: editorialSerifFamily,
    fontFamilyFallback: editorialSerifFallbacks,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.businessPlum,
    letterSpacing: -0.3,
    height: 1.2,
  );

  static const TextStyle businessCardTitle = TextStyle(
    fontFamily: editorialSerifFamily,
    fontFamilyFallback: editorialSerifFallbacks,
    fontSize: 16.5,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.24,
  );

  static const TextStyle businessCategoryPill = TextStyle(
    fontFamily: uiSansFamily,
    fontFamilyFallback: uiSansFallbacks,
    fontSize: 10.5,
    fontWeight: FontWeight.w800,
    color: AppColors.primaryPurple,
    letterSpacing: 0.65,
  );

  static const TextStyle businessPriceBadge = TextStyle(
    fontFamily: uiSansFamily,
    fontFamilyFallback: uiSansFallbacks,
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: AppColors.businessPlum,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: uiSansFamily,
    fontFamilyFallback: uiSansFallbacks,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
    letterSpacing: -0.1,
  );

  static const TextStyle bodyRegular = TextStyle(
    fontFamily: uiSansFamily,
    fontFamilyFallback: uiSansFallbacks,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.44,
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
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    height: 1.34,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: uiSansFamily,
    fontFamilyFallback: uiSansFallbacks,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    height: 1.25,
  );

  static const TextStyle chipLabel = TextStyle(
    fontFamily: uiSansFamily,
    fontFamilyFallback: uiSansFallbacks,
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryPurple,
  );

  static const TextStyle navLabel = TextStyle(
    fontFamily: uiSansFamily,
    fontFamilyFallback: uiSansFallbacks,
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    color: AppColors.textMuted,
    letterSpacing: -0.1,
  );

  static const TextStyle monoToken = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallbacks,
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 0.4,
  );

  // Module 5 screen aliases retained for compatibility with the complaint UI.
  static const TextStyle editorialHeadline = heroTitle;
  static const TextStyle editorialSection = sectionTitle;
  static const TextStyle technicalToken = monoToken;
  static const TextStyle technicalHash = monoToken;
  static const TextStyle referenceToken = monoToken;
}
