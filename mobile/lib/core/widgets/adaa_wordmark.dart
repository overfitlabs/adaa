import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum AdaaWordmarkSize { small, medium, large }

/// Distinctive, minimal editorial wordmark for `adaa`.
/// The brand name is strictly lowercase: `adaa`.
/// Seamlessly integrates Stitch design assets (`brand_name_logo.png`).
class AdaaWordmark extends StatelessWidget {
  final AdaaWordmarkSize size;
  final Color? color;
  final bool withDotAccent;
  final bool showSubtitle;
  final String? subtitle;
  final bool useLogoAsset;

  const AdaaWordmark({
    super.key,
    this.size = AdaaWordmarkSize.medium,
    this.color,
    this.withDotAccent = true,
    this.showSubtitle = false,
    this.subtitle,
    this.useLogoAsset = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.primary;

    final TextStyle baseStyle;
    final double dotSize;
    final double spacing;
    final double logoHeight;

    switch (size) {
      case AdaaWordmarkSize.small:
        baseStyle = AppTypography.wordmarkSmall.copyWith(color: effectiveColor);
        dotSize = 4.0;
        spacing = 3.0;
        logoHeight = 22.0;
        break;
      case AdaaWordmarkSize.medium:
        baseStyle = AppTypography.wordmarkMedium.copyWith(color: effectiveColor);
        dotSize = 5.0;
        spacing = 4.0;
        logoHeight = 28.0;
        break;
      case AdaaWordmarkSize.large:
        baseStyle = AppTypography.wordmarkLarge.copyWith(color: effectiveColor);
        dotSize = 6.5;
        spacing = 5.0;
        logoHeight = 36.0;
        break;
    }

    if (useLogoAsset) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/branding/brand_name_logo.png',
            height: logoHeight,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _buildTextWordmark(baseStyle, dotSize, spacing),
          ),
          if (showSubtitle) ...[
            const SizedBox(width: 8),
            Container(
              height: 14,
              width: 1,
              color: AppColors.outlineVariant,
            ),
            const SizedBox(width: 8),
            Text(
              subtitle ?? 'style studio',
              style: AppTypography.labelSmall.copyWith(
                fontSize: size == AdaaWordmarkSize.large ? 11 : 9.5,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      );
    }

    final wordmarkWidget = _buildTextWordmark(baseStyle, dotSize, spacing);

    if (!showSubtitle) {
      return wordmarkWidget;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        wordmarkWidget,
        const SizedBox(height: 2),
        Text(
          subtitle ?? 'style studio',
          style: AppTypography.labelSmall.copyWith(
            fontSize: size == AdaaWordmarkSize.large ? 11 : 9,
            letterSpacing: 2.0,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTextWordmark(TextStyle baseStyle, double dotSize, double spacing) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          'adaa',
          style: baseStyle,
        ),
        if (withDotAccent) ...[
          SizedBox(width: spacing),
          Container(
            width: dotSize,
            height: dotSize,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}
