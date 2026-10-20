import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized editorial typography system for `adaa`.
/// Blends refined editorial high-fashion heading styles with clear, legible UI typefaces.
class AppTypography {
  // Brand Wordmark - Always lowercase: 'adaa'
  static const TextStyle wordmarkLarge = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w400,
    letterSpacing: 3.5,
    height: 1.1,
    color: AppColors.espresso,
    fontFamily: 'serif',
  );

  static const TextStyle wordmarkMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w400,
    letterSpacing: 2.8,
    height: 1.15,
    color: AppColors.espresso,
    fontFamily: 'serif',
  );

  static const TextStyle wordmarkSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    letterSpacing: 2.2,
    height: 1.2,
    color: AppColors.espresso,
    fontFamily: 'serif',
  );

  // Editorial Section Titles & Display Headings
  static const TextStyle displayLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.5,
    height: 1.2,
    color: AppColors.textPrimary,
    fontFamily: 'serif',
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.3,
    height: 1.25,
    color: AppColors.textPrimary,
    fontFamily: 'serif',
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  // Overlines / Category Eyebrows
  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    height: 1.2,
    color: AppColors.terracotta,
  );

  static const TextStyle overlineMuted = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
    height: 1.2,
    color: AppColors.textSecondary,
  );

  // UI Headings
  static const TextStyle titleLarge = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  // Body & Content
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: 0.1,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  // Buttons & Labels
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    color: AppColors.textMuted,
  );
}
