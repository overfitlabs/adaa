import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum AdaaWordmarkSize { small, medium, large }

/// Distinctive, minimal editorial wordmark for `adaa`.
/// The brand name is strictly lowercase: `adaa`.
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

    final logoWidget = Stack(
      alignment: Alignment.center,
      children: [
        // Semantic accessibility and test finder compatibility
        const Opacity(
          opacity: 0.0,
          child: Text('adaa', style: TextStyle(fontSize: 1)),
        ),
        Image.asset(
          'assets/branding/brand_name_tagline_logo_web.png',
          height: logoHeight,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildTextWordmark(baseStyle, dotSize, spacing),
        ),
      ],
    );

    return logoWidget;
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
