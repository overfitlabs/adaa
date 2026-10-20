import 'package:flutter/material.dart';

/// Centralized color palette for `adaa`.
/// Modern Indian fashion sensibility with refined editorial styling.
/// Warm, tactile, confident, understated, and fashion-first.
class AppColors {
  // Brand Core Palette
  static const Color terracotta = Color(0xFFA05B49);     // Signature Terracotta #A05B49
  static const Color terracottaDark = Color(0xFF834333); // Deep Rust #834333
  static const Color terracottaSoft = Color(0xFFF7ECE9); // Warm Blush Wash #F7ECE9
  
  static const Color espresso = Color(0xFF342820);       // Rich Espresso #342820
  static const Color espressoDark = Color(0xFF231A14);   // Deep Noir Espresso
  static const Color espressoLight = Color(0xFF4D3C32);  // Soft Espresso
  
  static const Color warmIvory = Color(0xFFF5F0E8);      // Tactile Warm Ivory Canvas #F5F0E8
  static const Color sand = Color(0xFFD6C4A8);           // Handloom Sand #D6C4A8
  static const Color sandSoft = Color(0xFFEFE7DC);       // Soft Sand
  static const Color sandLight = Color(0xFFFBF9F5);      // Pure Linen Tint
  static const Color white = Color(0xFFFFFFFF);          // Clean White

  // Semantic UI Mappings (Maintains backward compatibility across codebase)
  static const Color primary = espresso;                 // Espresso anchors primary action & typography
  static const Color primaryDark = espressoDark;
  static const Color accent = terracotta;                // Terracotta is the signature brand accent
  static const Color accentSoft = terracottaSoft;        // Warm terracotta wash for badges/containers

  static const Color background = warmIvory;             // Warm Ivory Canvas
  static const Color surface = white;                    // Clean White Surface Cards
  static const Color surfaceElevated = Color(0xFFFCFAF7);// Ivory-tinted Elevated Surface

  static const Color textPrimary = espresso;             // Espresso text for maximum warmth & contrast
  static const Color textSecondary = Color(0xFF736257);  // Warm muted espresso
  static const Color textMuted = Color(0xFFA49488);      // Subtle sand-grey
  static const Color textTertiary = textMuted;

  static const Color border = Color(0xFFE3DACF);         // Refined sand hairline border
  static const Color borderLight = Color(0xFFEFE8DF);

  // Status & Match Indicators (Warm & Editorial)
  static const Color exactMatch = Color(0xFF2E7D52);     // Forest Olive
  static const Color approxMatch = Color(0xFFC8822B);    // Warm Ochre Amber
  static const Color missing = Color(0xFFC04B37);        // Terracotta Rust

  // Subtle elevation shadows
  static final BoxShadow cardShadow = BoxShadow(
    color: espresso.withValues(alpha: 0.06),
    blurRadius: 8,
    offset: const Offset(0, 2),
  );

  static final BoxShadow subtleShadow = BoxShadow(
    color: espresso.withValues(alpha: 0.04),
    blurRadius: 4,
    offset: const Offset(0, 1),
  );
}
