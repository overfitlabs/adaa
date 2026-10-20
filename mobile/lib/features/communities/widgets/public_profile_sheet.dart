import 'package:flutter/material.dart';
import '../../../core/models/community_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaa_brand_badge.dart';

class PublicProfileSheet extends StatefulWidget {
  final String userId;
  final String? fallbackName;

  const PublicProfileSheet({
    super.key,
    required this.userId,
    this.fallbackName,
  });

  static Future<void> show(BuildContext context, {required String userId, String? fallbackName}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PublicProfileSheet(userId: userId, fallbackName: fallbackName),
    );
  }

  @override
  State<PublicProfileSheet> createState() => _PublicProfileSheetState();
}

class _PublicProfileSheetState extends State<PublicProfileSheet> {
  PublicUserProfileModel? _profile;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await ApiClient.getPublicProfile(widget.userId);
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            if (_isLoading) ...[
              const SizedBox(height: 30),
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              const Text('Loading community profile...', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 30),
            ] else if (_errorMessage != null) ...[
              const SizedBox(height: 20),
              const Icon(Icons.shield_outlined, color: AppColors.accent, size: 36),
              const SizedBox(height: 10),
              Text(
                widget.fallbackName ?? 'Community Member',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Full profile details are restricted to members sharing approved community circles.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),
            ] else if (_profile != null) ...[
              // Profile Photo / Avatar
              ClipOval(
                child: Container(
                  width: 72,
                  height: 72,
                  color: AppColors.accentSoft,
                  child: (_profile!.avatarUrl != null && _profile!.avatarUrl!.trim().isNotEmpty)
                      ? Image.network(
                          ApiEndpoints.resolveImageUrl(_profile!.avatarUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Text(
                              _profile!.initials,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            _profile!.initials,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Name & Optional Age
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _profile!.displayName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  if (_profile!.age != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '${_profile!.age} yrs',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              const AdaaBrandBadge(text: 'COMMUNITY MEMBER'),
              const SizedBox(height: 14),

              // Bio
              if (_profile!.bio != null && _profile!.bio!.trim().isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _profile!.bio!.trim(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Contact Details (Only if permitted and present)
              if ((_profile!.email != null && _profile!.email!.isNotEmpty) ||
                  (_profile!.phoneNumber != null && _profile!.phoneNumber!.isNotEmpty)) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      if (_profile!.email != null && _profile!.email!.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 15, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _profile!.email!,
                                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      if (_profile!.email != null &&
                          _profile!.email!.isNotEmpty &&
                          _profile!.phoneNumber != null &&
                          _profile!.phoneNumber!.isNotEmpty)
                        const Divider(height: 12),
                      if (_profile!.phoneNumber != null && _profile!.phoneNumber!.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 15, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _profile!.phoneNumber!,
                                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Fit Preferences (Only if permitted and present)
              if (_profile!.fitPreferences != null && _profile!.fitPreferences!.hasAnyPreferences) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.straighten_outlined, size: 14, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'Sizing & Fit Preferences',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (_profile!.fitPreferences!.topsSize != null &&
                              _profile!.fitPreferences!.topsSize!.isNotEmpty)
                            _buildPreferenceChip('Tops', _profile!.fitPreferences!.topsSize!),
                          if (_profile!.fitPreferences!.bottomsSize != null &&
                              _profile!.fitPreferences!.bottomsSize!.isNotEmpty)
                            _buildPreferenceChip('Bottoms', _profile!.fitPreferences!.bottomsSize!),
                          if (_profile!.fitPreferences!.shoeSize != null &&
                              _profile!.fitPreferences!.shoeSize!.isNotEmpty)
                            _buildPreferenceChip('Shoes', _profile!.fitPreferences!.shoeSize!),
                          if (_profile!.fitPreferences!.preferredFit != null &&
                              _profile!.fitPreferences!.preferredFit!.isNotEmpty)
                            _buildPreferenceChip('Fit', _profile!.fitPreferences!.preferredFit!),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Preferred Styles (Only if permitted and present)
              if (_profile!.preferredStyles != null && _profile!.preferredStyles!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.style_outlined, size: 14, color: AppColors.accent),
                          SizedBox(width: 6),
                          Text(
                            'Style Aesthetics',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _profile!.preferredStyles!.map((style) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accentSoft.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              style,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.espresso),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStat('Active Circles', _profile!.sharedCommunitiesCount),
                  Container(height: 28, width: 1, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 24)),
                  _buildStat('Shared Pieces', _profile!.sharedItemsCount),
                ],
              ),
              const SizedBox(height: 20),
            ],

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildStat(String label, int count) {
    return Column(
      children: [
        Text(
          '$count',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
