import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized editorial typography system for `adaa`.
/// Blends Playfair Display (editorial serif headlines) with Plus Jakarta Sans (clean, legible UI text).
class AppTypography {
  // Font Family constants with safe system fallbacks
  static const String serifFamily = 'Playfair Display';
  static const List<String> serifFallbacks = ['Georgia', 'Times New Roman', 'serif'];

  static const String sansFamily = 'Plus Jakarta Sans';
  static const List<String> sansFallbacks = ['Inter', 'Roboto', 'sans-serif'];

  // Brand Wordmark - Always lowercase: 'adaa'
  static const TextStyle wordmarkLarge = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.5,
    height: 1.1,
    color: AppColors.primary,
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallbacks,
  );

  static const TextStyle wordmarkMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.0,
    height: 1.15,
    color: AppColors.primary,
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallbacks,
  );

  static const TextStyle wordmarkSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    height: 1.2,
    color: AppColors.primary,
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallbacks,
  );

  // Editorial Section Titles & Display Headings (Playfair Display)
  static const TextStyle displayLarge = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.8,
    height: 1.15,
    color: AppColors.textPrimary,
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallbacks,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.2,
    color: AppColors.textPrimary,
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallbacks,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.25,
    color: AppColors.textPrimary,
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallbacks,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.25,
    color: AppColors.textPrimary,
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallbacks,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.3,
    color: AppColors.textPrimary,
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallbacks,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.35,
    color: AppColors.textPrimary,
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallbacks,
  );

  // Overlines / Category Eyebrows
  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    height: 1.2,
    color: AppColors.accent,
    fontFamily: sansFamily,
    fontFamilyFallback: sansFallbacks,
  );

  static const TextStyle overlineMuted = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
    height: 1.2,
    color: AppColors.textSecondary,
    fontFamily: sansFamily,
    fontFamilyFallback: sansFallbacks,
  );

  // UI Headings (Plus Jakarta Sans)
  static const TextStyle titleLarge = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
    fontFamily: sansFamily,
    fontFamilyFallback: sansFallbacks,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.textPrimary,
    fontFamily: sansFamily,
    fontFamilyFallback: sansFallbacks,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.textPrimary,
    fontFamily: sansFamily,
    fontFamilyFallback: sansFallbacks,
  );

  // Body & Content (Plus Jakarta Sans)
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0,
    color: AppColors.textPrimary,
    fontFamily: sansFamily,
    fontFamilyFallback: sansFallbacks,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: 0,
    color: AppColors.textSecondary,
    fontFamily: sansFamily,
    fontFamilyFallback: sansFallbacks,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textSecondary,
    fontFamily: sansFamily,
    fontFamilyFallback: sansFallbacks,
  );

  // Buttons & Labels (Plus Jakarta Sans)
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    fontFamily: sansFamily,
    fontFamilyFallback: sansFallbacks,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    fontFamily: sansFamily,
    fontFamilyFallback: sansFallbacks,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    fontFamily: sansFamily,
    fontFamilyFallback: sansFallbacks,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    fontFamily: sansFamily,
    fontFamilyFallback: sansFallbacks,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    color: AppColors.textMuted,
    fontFamily: sansFamily,
    fontFamilyFallback: sansFallbacks,
  );
}
