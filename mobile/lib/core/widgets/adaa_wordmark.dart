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

  const AdaaWordmark({
    super.key,
    this.size = AdaaWordmarkSize.medium,
    this.color,
    this.withDotAccent = true,
    this.showSubtitle = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.espresso;

    final TextStyle baseStyle;
    final double dotSize;
    final double spacing;

    switch (size) {
      case AdaaWordmarkSize.small:
        baseStyle = AppTypography.wordmarkSmall.copyWith(color: effectiveColor);
        dotSize = 4.0;
        spacing = 3.0;
        break;
      case AdaaWordmarkSize.medium:
        baseStyle = AppTypography.wordmarkMedium.copyWith(color: effectiveColor);
        dotSize = 5.0;
        spacing = 4.0;
        break;
      case AdaaWordmarkSize.large:
        baseStyle = AppTypography.wordmarkLarge.copyWith(color: effectiveColor);
        dotSize = 6.5;
        spacing = 5.0;
        break;
    }

    final wordmarkWidget = Row(
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
              color: AppColors.terracotta,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );

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
          subtitle ?? 'fashion & style intelligence',
          style: AppTypography.overline.copyWith(
            fontSize: size == AdaaWordmarkSize.large ? 11 : 9,
            letterSpacing: 2.0,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
