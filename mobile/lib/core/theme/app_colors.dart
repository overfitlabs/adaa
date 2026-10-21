import 'package:flutter/material.dart';

/// Centralized Stitch design system color palette for `adaa`.
/// Editorial luxury fashion sensibility: deep forest green, muted sage,
/// warm ivory surfaces, restrained ochre gold accents, and tactile sand cards.
class AppColors {
  // Stitch Editorial Core Palette
  static const Color forest = Color(0xFF1E382B);          // Deep Forest Green #1E382B (Primary anchor)
  static const Color forestDark = Color(0xFF082217);      // High-contrast Forest #082217
  static const Color forestContainer = Color(0xFF1E382B); // Primary container
  
  static const Color sage = Color(0xFF4A6B56);            // Muted Sage Green #4A6B56 (Secondary)
  static const Color sageDark = Color(0xFF2D4D3A);        // Deep Sage #2D4D3A
  static const Color sageContainer = Color(0xFFC4E9CE);   // Soft Sage Container #C4E9CE
  static const Color sageWash = Color(0xFFE2ECE5);        // Light Sage Wash #E2ECE5
  
  static const Color gold = Color(0xFFD49B4B);            // Restrained Ochre Gold #D49B4B (AI / Sparkle)
  static const Color goldDim = Color(0xFFF9BB68);         // Warm Gold Tint #F9BB68
  static const Color goldFixed = Color(0xFFFFDDB5);       // Soft Gold Badge #FFDDB5
  
  static const Color canvas = Color(0xFFFCF9F4);          // Warm Editorial Ivory Canvas #FCF9F4
  static const Color canvasIvory = Color(0xFFFBF8F3);     // Soft Studio Ivory #FBF8F3
  static const Color surfaceContainer = Color(0xFFF0EDE9);// Neutral Container #F0EDE9
  static const Color surfaceContainerLow = Color(0xFFF6F3EE); // Low Surface #F6F3EE
  static const Color surfaceContainerHigh = Color(0xFFEBE8E3);// High Surface #EBE8E3
  static const Color surfaceContainerHighest = Color(0xFFE5E2DD);// Highest Surface #E5E2DD
  static const Color cardSand = Color(0xFFEFE8DD);        // Garment Backdrop Sand #EFE8DD
  static const Color white = Color(0xFFFFFFFF);           // Pure White
  
  static const Color textDark = Color(0xFF1C1C19);        // Primary Dark Text #1C1C19
  static const Color textMuted = Color(0xFF424844);       // Muted Editorial Text #424844
  static const Color textSubtle = Color(0xFF727973);      // Subtle Secondary Text #727973
  static const Color outline = Color(0xFF727973);         // Outline #727973
  static const Color outlineVariant = Color(0xFFC2C8C2);  // Hairline Outline #C2C8C2
  
  static const Color error = Color(0xFFBA1A1A);           // Editorial Error #BA1A1A
  static const Color errorContainer = Color(0xFFFFDAD6);  // Soft Error Container #FFDAD6

  // Semantic UI Mappings (Full backward compatibility for existing screens & tests)
  static const Color primary = forest;                   // Forest Green primary
  static const Color primaryDark = forestDark;
  static const Color accent = gold;                      // Gold sparkle / AI accent
  static const Color accentSoft = sageWash;              // Soft sage wash for badges

  static const Color background = canvas;                // Warm Ivory Canvas
  static const Color surface = canvas;                   // Warm Canvas
  static const Color surfaceElevated = surfaceContainerLow; // Elevated Surface
  static const Color surfaceCard = cardSand;             // Garment Card Neutral

  static const Color textPrimary = textDark;             // Primary text
  static const Color textSecondary = textMuted;          // Secondary text
  static const Color textTertiary = textSubtle;          // Subtle text

  static const Color border = outlineVariant;            // Hairline border
  static const Color borderLight = surfaceContainerHigh;

  // Backward-compatible color tokens
  static const Color terracotta = gold;
  static const Color terracottaDark = Color(0xFF834333);
  static const Color terracottaSoft = Color(0xFFF7ECE9);
  static const Color espresso = forest;
  static const Color espressoDark = forestDark;
  static const Color espressoLight = sage;
  static const Color warmIvory = canvas;
  static const Color sand = cardSand;
  static const Color sandSoft = surfaceContainerLow;
  static const Color sandLight = canvas;

  // Status & Match Indicators
  static const Color exactMatch = Color(0xFF2E7D52);     // Forest Green Match
  static const Color approxMatch = gold;                 // Warm Ochre Amber
  static const Color missing = Color(0xFFC04B37);        // Terracotta Rust

  // Stitch Diffused Forest-tinted Shadows
  static final BoxShadow cardShadow = BoxShadow(
    color: forest.withValues(alpha: 0.06),
    blurRadius: 20,
    offset: const Offset(0, 8),
  );

  static final BoxShadow subtleShadow = BoxShadow(
    color: forest.withValues(alpha: 0.04),
    blurRadius: 8,
    offset: const Offset(0, 2),
  );
}
