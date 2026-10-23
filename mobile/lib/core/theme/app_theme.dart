import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Centralized Material 3 Theme for adaa.
/// Uses locally bundled fonts from assets/fonts/.
class AppTheme {
  static ThemeData get lightTheme {
    final baseTextTheme = ThemeData.light().textTheme.apply(
      fontFamily: AppTypography.sansFamily,
      bodyColor: AppColors.textDark,
      displayColor: AppColors.textDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppTypography.sansFamily,
      scaffoldBackgroundColor: AppColors.canvas,

      // Local fonts: Plus Jakarta Sans for UI, Playfair Display for headings.
      textTheme: baseTextTheme.copyWith(
        displayLarge: AppTypography.displayLarge.copyWith(
          color: AppColors.textDark,
        ),
        displayMedium: AppTypography.displayMedium.copyWith(
          color: AppColors.textDark,
        ),
        displaySmall: AppTypography.displaySmall.copyWith(
          color: AppColors.textDark,
        ),
        headlineLarge: AppTypography.headlineLarge.copyWith(
          color: AppColors.textDark,
        ),
        headlineMedium: AppTypography.headlineMedium.copyWith(
          color: AppColors.textDark,
        ),
        headlineSmall: AppTypography.headlineSmall.copyWith(
          color: AppColors.textDark,
        ),
        titleLarge: AppTypography.titleLarge.copyWith(
          color: AppColors.textDark,
        ),
        titleMedium: AppTypography.titleMedium.copyWith(
          color: AppColors.textDark,
        ),
        titleSmall: AppTypography.titleSmall.copyWith(
          color: AppColors.textDark,
        ),
        bodyLarge: AppTypography.bodyLarge.copyWith(color: AppColors.textDark),
        bodyMedium: AppTypography.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        bodySmall: AppTypography.bodySmall.copyWith(
          color: AppColors.textSecondary,
        ),
        labelLarge: AppTypography.labelLarge,
        labelMedium: AppTypography.labelMedium,
        labelSmall: AppTypography.labelSmall,
      ),

      colorScheme: const ColorScheme.light(
        primary: AppColors.forest,
        onPrimary: AppColors.white,
        primaryContainer: AppColors.forestContainer,
        onPrimaryContainer: AppColors.white,
        secondary: AppColors.sage,
        onSecondary: AppColors.white,
        secondaryContainer: AppColors.sageContainer,
        onSecondaryContainer: AppColors.forestDark,
        tertiary: AppColors.gold,
        onTertiary: AppColors.forestDark,
        tertiaryContainer: AppColors.goldFixed,
        surface: AppColors.canvas,
        onSurface: AppColors.textDark,
        surfaceContainer: AppColors.surfaceContainer,
        surfaceContainerLow: AppColors.surfaceContainerLow,
        surfaceContainerHigh: AppColors.surfaceContainerHigh,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        error: AppColors.error,
        onError: AppColors.white,
        errorContainer: AppColors.errorContainer,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.wordmarkMedium,
        iconTheme: IconThemeData(color: AppColors.forest, size: 22),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outlineVariant, width: 0.8),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.forest,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          textStyle: AppTypography.labelLarge.copyWith(color: AppColors.white),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.forest,
          side: const BorderSide(color: AppColors.forest, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          textStyle: AppTypography.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.forest,
          textStyle: AppTypography.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceContainer,
        selectedColor: AppColors.forest,
        secondarySelectedColor: AppColors.sageContainer,
        labelStyle: AppTypography.labelSmall.copyWith(
          color: AppColors.textDark,
        ),
        secondaryLabelStyle: AppTypography.labelSmall.copyWith(
          color: AppColors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
          side: BorderSide.none,
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.forest,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.forest,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: AppTypography.titleSmall.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: AppTypography.titleSmall.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.canvas,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.outlineVariant, width: 0.8),
        ),
        titleTextStyle: AppTypography.headlineSmall,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.canvas,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.forest,
        foregroundColor: AppColors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textSubtle,
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.outlineVariant,
            width: 0.8,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.outlineVariant,
            width: 0.8,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1.0),
        ),
      ),
    );
  }
}
