import 'package:flutter/material.dart';

/// Centralized iOS 26 Liquid Glass color palette for Sakhi (Modules 1–6).
class AppColors {
  AppColors._();

  // Primary brand colors
  static const Color primaryPurple = Color(0xFF5D196A);
  static const Color primaryPurpleDark = Color(0xFF420E4E);
  static const Color primaryPurpleLight = Color(0xFF8E44AD);

  // iOS 26 Liquid Glass Tokens & Aurora Mesh Orbs
  static const Color scaffoldBackground = Color(0xFFFAF0F6);
  static const Color cardSurface = Color(0xE8FFFFFF);
  static const Color cardTintPink = Color(0xFFFDF3F8);
  static const Color searchFieldFill = Color(0xD8F6ECFA);
  static const Color borderSubtle = Color(0xFFE7D2F0);
  static const Color dividerColor = Color(0xFFEAD8F0);
  static const Color glassSpecularBorder = Color(0xF2FFFFFF);
  static const Color glassInnerRim = Color(0xB8F5DDFB);
  static const Color auroraRoseOrb = Color(0xFFFFD6E8);
  static const Color auroraOrchidOrb = Color(0xFFE6CCFF);
  static const Color auroraMintOrb = Color(0xFFD4F7EA);
  static const Color auroraChampagneOrb = Color(0xFFFFECD6);

  // Module 6 Women-Owned Business Luxury Accents
  static const Color businessPlum = Color(0xFF4A1259);
  static const Color businessRoseGold = Color(0xFFC66B8A);
  static const Color businessAmberGold = Color(0xFFD4882A);
  static const Color businessChampagneBg = Color(0xFFFFF7EE);

  // Typography colors
  static const Color textPrimary = Color(0xFF260E2C);
  static const Color textSecondary = Color(0xFF5C4262);
  static const Color textMuted = Color(0xFF78657D);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Pastel accents & category backgrounds
  static const Color pastelLavender = Color(0xFFF3E6FA);
  static const Color pastelPink = Color(0xFFFDECF3);
  static const Color pastelBlue = Color(0xFFE8F2FF);
  static const Color pastelMint = Color(0xFFE4F8EF);
  static const Color pastelPeach = Color(0xFFFFEFE2);
  static const Color pastelQuoteBg = Color(0xFFF5EFFB);

  // Semantic & Icon accents
  static const Color sosRed = Color(0xFFC92A42);
  static const Color sosRedSoft = Color(0xFFFDE8EC);
  static const Color wellnessGreen = Color(0xFF239465);
  static const Color infoBlue = Color(0xFF2B7CE9);
  static const Color amberAccent = Color(0xFFE67E22);
  static const Color verifiedGreenBg = Color(0xFFE6F6EE);
  static const Color verifiedGreenText = Color(0xFF1E7E52);
  static const Color heartPink = Color(0xFFE84C88);

  // Gradients
  static const LinearGradient heroBannerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xD8FFE4F2), Color(0xCCF1D8FA), Color(0xE6FFFFFF)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient wellnessBannerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xD8FDE6F2), Color(0xCCEDD9FA), Color(0xE6F3FBF8)],
  );

  static const LinearGradient liquidGlassCardGradient = LinearGradient(
    begin: Alignment(-0.9, -1.0),
    end: Alignment(0.9, 1.0),
    colors: [
      Color(0xECFFFFFF),
      Color(0xCCFDF4FA),
      Color(0xE0FAF0FC),
      Color(0xF0FFFFFF),
    ],
    stops: [0.0, 0.38, 0.72, 1.0],
  );

  static const LinearGradient businessHeroGlassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xEEFFF5FA), Color(0xDCF5E2FC), Color(0xEEFFF8EE)],
  );

  // Backwards-compatible token name used by Module 6 screens.
  static const LinearGradient businessLuxuryGradient =
      businessHeroGlassGradient;
}
