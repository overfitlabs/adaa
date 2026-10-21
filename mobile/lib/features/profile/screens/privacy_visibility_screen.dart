import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/profile_provider.dart';

/// Stitch-designed "Privacy & Visibility" screen (`a1b462f9f3c44162b6afb28552d59e56`).
/// Granular circle exposure control with tactile segmented pills for 7 privacy fields:
/// Photo, Bio, Age, Phone, Gender, Sizes, Fit Preferences.
class PrivacyVisibilityScreen extends StatefulWidget {
  const PrivacyVisibilityScreen({super.key});

  @override
  State<PrivacyVisibilityScreen> createState() => _PrivacyVisibilityScreenState();
}

class _PrivacyVisibilityScreenState extends State<PrivacyVisibilityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().loadPrivacySettings(silent: true);
    });
  }

  Future<void> _handleToggle(String field, bool isCommunityVisible) async {
    final provider = context.read<ProfileProvider>();
    final success = await provider.updatePrivacySetting(field, isCommunityVisible);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to update privacy preference'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProv = context.watch<ProfileProvider>();
    final privacy = profileProv.privacySettings;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.forest),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/branding/brand_name_logo.png',
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Text('adaa', style: AppTypography.wordmarkSmall),
            ),
            const SizedBox(width: 8),
            Text(
              'Privacy & Visibility',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.forest,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Eyebrow & Title
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: AppColors.gold),
                const SizedBox(width: 6),
                Text(
                  'CIRCLE BOUNDARIES',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.gold,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Privacy & Visibility',
              style: AppTypography.displaySmall.copyWith(
                color: AppColors.forest,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose what approved members of your circles can see on your profile.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),

            // Clarity Banner Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant, width: 0.8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_user, color: AppColors.forest, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wardrobe Items Are Independent',
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.forest,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Wardrobe items have separate sharing permissions. Adjusting these settings only impacts your personal profile details in community circles.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Group 1: Identity & Style Bio
            _buildSectionHeader(
              title: 'Identity & Style Bio',
              tag: 'Circle Exposure',
              tagColor: AppColors.sage,
            ),
            const SizedBox(height: 10),
            _buildPrivacyTile(
              icon: Icons.account_circle_outlined,
              title: 'Profile Photo',
              subtitle: 'Shows your photo or initials in circle member lists.',
              isCommunityVisible: privacy.isPhotoVisible,
              onChanged: (val) => _handleToggle('photo', val),
            ),
            const SizedBox(height: 12),
            _buildPrivacyTile(
              icon: Icons.edit_note_outlined,
              title: 'Bio & Style Notes',
              subtitle: 'Allows circle members to read your personal style summary.',
              isCommunityVisible: privacy.isBioVisible,
              onChanged: (val) => _handleToggle('bio', val),
            ),
            const SizedBox(height: 28),

            // Group 2: Sensitive Personal Details
            _buildSectionHeader(
              title: 'Sensitive Personal Details',
              tag: 'Private by Default',
              tagColor: AppColors.gold,
            ),
            const SizedBox(height: 10),
            _buildPrivacyTile(
              icon: Icons.calendar_today_outlined,
              title: 'Age',
              subtitle: 'Kept private by default for your comfort.',
              badgeText: 'Encrypted',
              isCommunityVisible: privacy.isAgeVisible,
              onChanged: (val) => _handleToggle('age', val),
            ),
            const SizedBox(height: 12),
            _buildPrivacyTile(
              icon: Icons.phone_iphone_outlined,
              title: 'Phone Number',
              subtitle: 'Used for account security and recovery.',
              badgeText: 'Private',
              isCommunityVisible: privacy.isPhoneVisible,
              onChanged: (val) => _handleToggle('phone', val),
            ),
            const SizedBox(height: 12),
            _buildPrivacyTile(
              icon: Icons.wc_outlined,
              title: 'Gender / Pronouns',
              subtitle: 'Pronouns and gender identity in circles.',
              isCommunityVisible: privacy.isGenderVisible,
              onChanged: (val) => _handleToggle('gender', val),
            ),
            const SizedBox(height: 12),
            _buildPrivacyTile(
              icon: Icons.straighten_outlined,
              title: 'Sizes & Measurements',
              subtitle: 'Helps peers check if borrowable items fit you.',
              isCommunityVisible: privacy.isSizesVisible,
              onChanged: (val) => _handleToggle('sizes', val),
            ),
            const SizedBox(height: 12),
            _buildPrivacyTile(
              icon: Icons.style_outlined,
              title: 'Fit Preferences',
              subtitle: 'Top & bottom silhouette preferences (e.g. Oversized, Slim).',
              isCommunityVisible: privacy.isFitPreferencesVisible,
              onChanged: (val) => _handleToggle('fit_preferences', val),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String tag,
    required Color tagColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTypography.headlineSmall.copyWith(
            color: AppColors.forest,
            fontSize: 17,
          ),
        ),
        Text(
          tag.toUpperCase(),
          style: AppTypography.labelSmall.copyWith(
            color: tagColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyTile({
    required IconData icon,
    required String title,
    required String subtitle,
    String? badgeText,
    required bool isCommunityVisible,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.forest, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.forest,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: Text(
                              badgeText,
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.sage,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Stitch Segmented Pill Toggle Container
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(true),
                    borderRadius: BorderRadius.circular(9999),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isCommunityVisible ? AppColors.forest : Colors.transparent,
                        borderRadius: BorderRadius.circular(9999),
                        boxShadow: isCommunityVisible ? [AppColors.subtleShadow] : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.groups_outlined,
                            size: 15,
                            color: isCommunityVisible ? Colors.white : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Visible to Community',
                            style: AppTypography.labelSmall.copyWith(
                              color: isCommunityVisible ? Colors.white : AppColors.textSecondary,
                              fontWeight: isCommunityVisible ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(false),
                    borderRadius: BorderRadius.circular(9999),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !isCommunityVisible ? AppColors.forest : Colors.transparent,
                        borderRadius: BorderRadius.circular(9999),
                        boxShadow: !isCommunityVisible ? [AppColors.subtleShadow] : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 15,
                            color: !isCommunityVisible ? Colors.white : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Only Me',
                            style: AppTypography.labelSmall.copyWith(
                              color: !isCommunityVisible ? Colors.white : AppColors.textSecondary,
                              fontWeight: !isCommunityVisible ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
