import 'package:flutter/material.dart';

/// Centralized color palette matching the 12-screen Sakhi visual design reference.
class AppColors {
  AppColors._();

  // Primary brand colors
  static const Color primaryPurple = Color(0xFF5D196A);
  static const Color primaryPurpleDark = Color(0xFF4C1458);
  static const Color primaryPurpleLight = Color(0xFF8E44AD);

  // Backgrounds & Surfaces
  static const Color scaffoldBackground = Color(0xFFFDF4F7);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color cardTintPink = Color(0xFFFDF4F7);
  static const Color searchFieldFill = Color(0xFFF5EBF9);
  static const Color borderSubtle = Color(0xFFEAD8F0);
  static const Color dividerColor = Color(0xFFEAD8F0);

  // Typography colors
  static const Color textPrimary = Color(0xFF2A1130);
  static const Color textSecondary = Color(0xFF634B68);
  static const Color textMuted = Color(0xFF796A7D);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Pastel accents & category backgrounds
  static const Color pastelLavender = Color(0xFFF5EBF9);
  static const Color pastelPink = Color(0xFFFDF4F7);
  static const Color pastelBlue = Color(0xFFE8F2FF);
  static const Color pastelMint = Color(0xFFE6F7EF);
  static const Color pastelPeach = Color(0xFFFFF0E3);
  static const Color pastelQuoteBg = Color(0xFFF5EFFB);

  // Semantic & Icon accents
  static const Color sosRed = Color(0xFFC92A42);
  static const Color sosRedSoft = Color(0xFFFDE8EC);
  static const Color wellnessGreen = Color(0xFF289B6B);
  static const Color infoBlue = Color(0xFF2B7CE9);
  static const Color amberAccent = Color(0xFFE67E22);
  static const Color verifiedGreenBg = Color(0xFFE6F6EE);
  static const Color verifiedGreenText = Color(0xFF1E7E52);
  static const Color heartPink = Color(0xFFE84C88);

  // Gradients
  static const LinearGradient heroBannerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFCE4F0), Color(0xFFF3DCF8)],
  );

  static const LinearGradient wellnessBannerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBE6F2), Color(0xFFEFDDF8)],
  );
}
