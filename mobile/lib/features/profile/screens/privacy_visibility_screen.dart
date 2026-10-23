// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/adaa_wordmark.dart';
import '../../../state/profile_provider.dart';

/// Privacy controls for profile details shared with approved community members.
/// Each selection is saved immediately through ProfileProvider.
class PrivacyVisibilityScreen extends StatefulWidget {
  const PrivacyVisibilityScreen({super.key});

  @override
  State<PrivacyVisibilityScreen> createState() =>
      _PrivacyVisibilityScreenState();
}

class _PrivacyVisibilityScreenState extends State<PrivacyVisibilityScreen> {
  String? _savingField;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProfileProvider>().loadPrivacySettings(silent: true);
      }
    });
  }

  Future<void> _handleToggle(String field, bool visible) async {
    if (_savingField != null) return;
    setState(() {
      _savingField = field;
      _saveError = null;
    });

    final provider = context.read<ProfileProvider>();
    final success = await provider.updatePrivacySetting(field, visible);
    if (!mounted) return;

    setState(() {
      _savingField = null;
      _saveError = success
          ? null
          : (provider.error ?? 'Could not save this preference.');
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_saveError ?? 'Could not save this preference.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final privacy = provider.privacySettings;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 68,
        automaticallyImplyLeading: false,

        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: IconButton(
            tooltip: 'Go back',
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: AppColors.forest,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),

        title: const AdaaWordmark(
          size: AdaaWordmarkSize.medium,
          color: AppColors.espresso,
          withDotAccent: true,
          showSubtitle: true,
          subtitle: 'style intelligence & closet',
        ),
        centerTitle: true,
        titleSpacing: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy & Visibility',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 32,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose what approved members of your circles can see on your profile.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            _buildInfoBanner(),
            const SizedBox(height: 26),
            _buildSectionHeader(title: 'Identity & Style Bio'),
            const SizedBox(height: 12),
            _buildPrivacyTile(
              field: 'photo',
              icon: Icons.account_circle_outlined,
              title: 'Profile Photo',
              subtitle: 'Shows your photo or initials in circle member lists.',
              visible: privacy.isPhotoVisible,
            ),
            const SizedBox(height: 12),
            _buildPrivacyTile(
              field: 'bio',
              icon: Icons.edit_note_outlined,
              title: 'Bio & Style Notes',
              subtitle:
                  'Allows circle members to read your personal style summary.',
              visible: privacy.isBioVisible,
            ),
            const SizedBox(height: 26),
            _buildSectionHeader(title: 'Sensitive Personal Details'),
            const SizedBox(height: 12),
            _buildPrivacyTile(
              field: 'age',
              icon: Icons.calendar_today_outlined,
              title: 'Age',
              subtitle:
                  'Choose whether your age appears to approved circle members.',
              visible: privacy.isAgeVisible,
              badgeText: 'PRIVATE BY DEFAULT',
            ),
            const SizedBox(height: 12),
            _buildPrivacyTile(
              field: 'phone',
              icon: Icons.smartphone_outlined,
              title: 'Phone Number',
              subtitle: 'Used only for account security and recovery.',
              visible: privacy.isPhoneVisible,
              badgeText: 'PRIVATE BY DEFAULT',
            ),
            const SizedBox(height: 12),
            _buildPrivacyTile(
              field: 'email',
              icon: Icons.alternate_email,
              title: 'Account Email',
              subtitle: 'Your adaa login address remains hidden unless you choose to share it.',
              visible: privacy.isEmailVisible,
              badgeText: 'PRIVATE BY DEFAULT',
            ),
            const SizedBox(height: 26),
            _buildSectionHeader(title: 'Sizing & Wardrobe Curation'),
            const SizedBox(height: 12),
            _buildPrivacyTile(
              field: 'sizes',
              icon: Icons.straighten_outlined,
              title: 'Fit & Clothing Sizes',
              subtitle: 'Tops, bottoms, and shoe sizes. Keep private or share with borrowing circles.',
              visible: privacy.isSizesVisible,
            ),
            const SizedBox(height: 12),
            _buildPrivacyTile(
              field: 'styles',
              icon: Icons.palette_outlined,
              title: 'Style Aesthetics',
              subtitle: 'Your preferred style tags, such as Minimalist or Classic, to match circle tastes.',
              visible: privacy.isStylesVisible,
            ),
            const SizedBox(height: 28),
            _buildPrivacyPolicyCard(),
            const SizedBox(height: 14),
            _buildSaveStatus(provider.isSaving),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.65)),
        boxShadow: [AppColors.subtleShadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: AppColors.forest,
              size: 20,
            ),
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
                const SizedBox(height: 5),
                Text(
                  'Wardrobe items have separate sharing permissions. These settings only affect your personal profile details in community circles.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required String title}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.forest,
              fontSize: 17,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyTile({
    required String field,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool visible,
    String? badgeText,
  }) {
    final isSavingThis =
        _savingField == field ||
        (_savingField == 'fit_preferences' && field == 'sizes') ||
        (_savingField == 'sizes' && field == 'sizes');

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: _savingField != null && !isSavingThis ? 0.72 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.outlineVariant.withOpacity(0.55),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.forest, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 7,
                        runSpacing: 5,
                        children: [
                          Text(
                            title,
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.forest,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (badgeText != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badgeText,
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.sage,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
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
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSegment(
                      label: 'Community',
                      icon: Icons.groups_outlined,
                      selected: visible,
                      enabled: _savingField == null,
                      onTap: () => _handleToggle(field, true),
                    ),
                  ),
                  Expanded(
                    child: _buildSegment(
                      label: 'Only Me',
                      icon: Icons.lock_outline,
                      selected: !visible,
                      enabled: _savingField == null,
                      onTap: () => _handleToggle(field, false),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegment({
    required String label,
    required IconData icon,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? AppColors.forest : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        boxShadow: selected ? [AppColors.subtleShadow] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyPolicyCard() {
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Privacy Policy'),
              content: const Text(
                'Everything on internet is public. Your profile visibility preferences are saved to your adaa account.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppColors.forest,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy Policy',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.forest,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "Read adaa's full privacy & circle governance policy",
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveStatus(bool providerSaving) {
    final saving = providerSaving || _savingField != null;
    final hasError = _saveError != null;
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (saving)
            const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              hasError ? Icons.error_outline : Icons.check_circle,
              size: 16,
              color: hasError ? AppColors.error : AppColors.sage,
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              saving
                  ? 'Updating circle visibility…'
                  : hasError
                  ? 'Could not save changes. Please try again.'
                  : 'Changes are automatically saved to your account.',
              textAlign: TextAlign.center,
              style: AppTypography.labelSmall.copyWith(
                color: hasError ? AppColors.error : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
