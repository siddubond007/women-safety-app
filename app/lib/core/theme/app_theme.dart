import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final baseTextTheme = ThemeData.light().textTheme.apply(
      fontFamily: AppTypography.uiSansFamily,
      fontFamilyFallback: AppTypography.uiSansFallbacks,
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.uiSansFamily,
      fontFamilyFallback: AppTypography.uiSansFallbacks,
      scaffoldBackgroundColor: AppColors.scaffoldBackground,
      primaryColor: AppColors.primaryPurple,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryPurple,
        primary: AppColors.primaryPurple,
        secondary: AppColors.primaryPurpleLight,
        surface: AppColors.cardSurface,
        error: AppColors.sosRed,
      ),
      textTheme: baseTextTheme.copyWith(
        headlineLarge: AppTypography.heroTitle.copyWith(fontSize: 26),
        headlineMedium: AppTypography.heroTitle,
        titleLarge: AppTypography.appBarTitle,
        titleMedium: AppTypography.sectionTitle,
        titleSmall: AppTypography.cardTitle,
        bodyLarge: AppTypography.bodyMedium,
        bodyMedium: AppTypography.bodyRegular,
        bodySmall: AppTypography.subtitle,
        labelSmall: AppTypography.caption,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: AppTypography.appBarTitle,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        hintStyle: AppTypography.subtitle,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerColor,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
