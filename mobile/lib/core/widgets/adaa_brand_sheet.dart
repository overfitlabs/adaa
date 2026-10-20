import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'adaa_wordmark.dart';

/// Editorial brand sheet displaying the `adaa` identity, philosophy, and features.
class AdaaBrandSheet extends StatelessWidget {
  const AdaaBrandSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AdaaBrandSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Wordmark + Tagline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdaaWordmark(
                size: AdaaWordmarkSize.large,
                color: AppColors.espresso,
                withDotAccent: true,
                showSubtitle: true,
                subtitle: 'modern indian fashion sensibility',
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.terracottaSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.sand, width: 0.8),
                ),
                child: Text(
                  'v1.0',
                  style: AppTypography.overline.copyWith(fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Brand philosophy
          Text(
            'adaa is a personal wardrobe and style intelligence platform designed with modern Indian fashion sensibility, tactile warmth, and refined editorial elegance.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Core pillars
          _buildPillarTile(
            icon: Icons.auto_awesome,
            title: 'AI Outfit Intelligence',
            subtitle: 'Deconstruct any street style or moodboard photo into garment attributes and match your closet.',
          ),
          const SizedBox(height: 12),
          _buildPillarTile(
            icon: Icons.checkroom,
            title: 'Personal Digital Wardrobe',
            subtitle: 'Curate, categorize, and preserve your clothing items with secure private image delivery.',
          ),
          const SizedBox(height: 12),
          _buildPillarTile(
            icon: Icons.groups_outlined,
            title: 'Style Circles & Shared Closets',
            subtitle: 'Connect with college and community style circles to share, borrow, and co-create looks.',
          ),
          const SizedBox(height: 24),

          // Palette swatches
          Text(
            'SIGNATURE PALETTE',
            style: AppTypography.overline.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildSwatch(AppColors.terracotta, 'Terracotta', '#A05B49'),
              const SizedBox(width: 8),
              _buildSwatch(AppColors.espresso, 'Espresso', '#342820'),
              const SizedBox(width: 8),
              _buildSwatch(AppColors.warmIvory, 'Warm Ivory', '#F5F0E8', hasBorder: true),
              const SizedBox(width: 8),
              _buildSwatch(AppColors.sand, 'Sand', '#D6C4A8'),
            ],
          ),
          const SizedBox(height: 24),

          // Dismiss button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.espresso,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back to adaa'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.terracottaSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.terracotta),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.titleSmall),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTypography.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwatch(Color color, String name, String hex, {bool hasBorder = false}) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: hasBorder ? Border.all(color: AppColors.border, width: 1) : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
