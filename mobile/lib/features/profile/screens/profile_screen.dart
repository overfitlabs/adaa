// ignore_for_file: unnecessary_underscores, unused_field

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'edit_profile_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/auth_provider.dart';
import '../../../state/community_provider.dart';
import '../../../state/profile_provider.dart';
import '../../../state/wardrobe_provider.dart';
import '../../requests/screens/requests_screen.dart';
import 'privacy_visibility_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onNavigateToCloset;
  final VoidCallback? onNavigateToCommunities;

  const ProfileScreen({
    super.key,
    this.onNavigateToCloset,
    this.onNavigateToCommunities,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _customDisplayName;
  String? _bio;
  bool _isUploadingPhoto = false;

  final List<String> _availableFitTypes = const [
    'slim',
    'regular',
    'relaxed',
    'oversized',
  ];
  final List<String> _availableStyleTags = const [
    'Minimalist',
    'Vintage',
    'Streetwear',
    'Classic',
    'Casual',
    'Athleisure',
    'Bohemian',
    'Chic',
    'Tailored',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    try {
      final profileProv = context.read<ProfileProvider>();
      await profileProv.loadProfile();
      if (mounted && profileProv.profile != null) {
        setState(() {
          _customDisplayName = profileProv.profile!.displayName;
          _bio = profileProv.profile!.bio;
        });
      }
    } catch (_) {
      if (!mounted) return;
      // Fallback if ProfileProvider is not in tree (e.g. legacy tests)
      final auth = context.read<AuthProvider>();
      final userId = auth.user?.id;
      if (userId == null) return;
      try {
        final prof = await ApiClient.getPublicProfile(userId);
        if (mounted) {
          setState(() {
            _customDisplayName = prof.displayName;
            _bio = prof.bio;
          });
        }
      } catch (_) {}
    }
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sign Out',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to sign out of your adaa account?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.missing),
            onPressed: () async {
              Navigator.pop(ctx);
              await SessionManager.performLogout(context);
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    ProfileProvider? profileProv;
    try {
      profileProv = context.read<ProfileProvider>();
    } catch (_) {}

    final picker = ImagePicker();
    try {
      final xFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (xFile == null) return;

      if (!mounted) return;
      setState(() => _isUploadingPhoto = true);

      try {
        if (profileProv != null) {
          final success = await profileProv.uploadAvatar(xFile);
          if (success) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Profile photo updated successfully!'),
                backgroundColor: AppColors.exactMatch,
              ),
            );
          } else if (profileProv.error != null) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(profileProv.error!),
                backgroundColor: AppColors.missing,
              ),
            );
          }
        } else {
          final newUrl = await ApiClient.uploadProfileAvatar(xFile);
          await ApiClient.updateMyProfile(avatarUrl: newUrl);
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Profile photo updated successfully!'),
              backgroundColor: AppColors.exactMatch,
            ),
          );
        }
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('ApiException: ', '')),
            backgroundColor: AppColors.missing,
          ),
        );
      } finally {
        if (mounted) setState(() => _isUploadingPhoto = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    ProfileProvider? profileProv;
    try {
      profileProv = context.watch<ProfileProvider>();
    } catch (_) {}
    final wardrobeProv = context.watch<WardrobeProvider>();
    final commProv = context.watch<CommunityProvider>();
    final userProfile = profileProv?.profile;
    final isAuthenticated = auth.isAuthenticated;
    final displayName =
        userProfile?.displayName ?? _customDisplayName ?? auth.displayName;
    final email = auth.user?.email ?? userProfile?.email ?? '';
    final avatarUrl = userProfile?.avatarUrl;
    final initials = displayName.isNotEmpty
        ? (displayName.length >= 2
              ? displayName.substring(0, 2).toUpperCase()
              : displayName[0].toUpperCase())
        : 'A';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Text(
            'My Profile',
            style: const TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 28,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Account and preferences',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Identity card - horizontal profile layout.
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipOval(
                      child: Container(
                        width: 64,
                        height: 64,
                        color: AppColors.accentSoft,
                        child: _isUploadingPhoto
                            ? const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.forest,
                                  ),
                                ),
                              )
                            : (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? Image.network(
                                ApiEndpoints.resolveImageUrl(avatarUrl),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      fontFamily: 'Playfair Display',
                                      fontSize: 20,
                                      color: AppColors.forest,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    fontFamily: 'Playfair Display',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.forest,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Material(
                        color: AppColors.forest,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _isUploadingPhoto
                              ? null
                              : () => _pickAndUploadAvatar(context),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.photo_camera_outlined,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Playfair Display',
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.forest,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final saved = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const EditProfileScreen(),
                                ),
                              );
                              if (saved == true && mounted) {
                                _loadProfile();
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.sage,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Edit',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if ((userProfile?.bio ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          userProfile?.bio ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.forest,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Two compact statistics
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [AppColors.subtleShadow],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _profileStat(
                    '${wardrobeProv.items.length}',
                    'CLOSET PIECES',
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: AppColors.outlineVariant,
                ),
                Expanded(
                  child: _profileStat(
                    '${commProv.myCommunities.length}',
                    'ACTIVE CIRCLES',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (isAuthenticated) ...[
            _sectionLabel('COMMUNITY'),
            _settingsCard([
              _settingsRow(
                icon: Icons.swap_horiz,
                title: 'Borrowing Requests',
                subtitle: 'Manage item lending & requests',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'View',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RequestsScreen()),
                ),
              ),
            ]),
            const SizedBox(height: 22),
          ],

          _sectionLabel('ACCOUNT'),
          _settingsCard([
            _settingsRow(
              icon: Icons.badge_outlined,
              title: 'Edit Profile',
              subtitle:
                  (userProfile?.fitPreferences != null &&
                      userProfile!.fitPreferences.hasAnyPreferences)
                  ? 'Tops: ${userProfile.fitPreferences.topsSize ?? "-"} • Bottoms: ${userProfile.fitPreferences.bottomsSize ?? "-"} • Fit: ${userProfile.fitPreferences.preferredFit ?? "-"}'
                  : 'Personal info, sizes & aesthetics',
              onTap: () async {
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
                if (saved == true && mounted) {
                  _loadProfile();
                }
              },
            ),
            _settingsDivider(),
            _settingsRow(
              icon: Icons.visibility_outlined,
              title: 'Privacy & Visibility',
              subtitle: 'Choose what others can see in your circles',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrivacyVisibilityScreen(),
                ),
              ),
            ),
            _settingsDivider(),
            _settingsRow(
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              onTap: () {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'We are just building, maybe next time you will see a long page of terms and conditions. ',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ]),
          const SizedBox(height: 22),

          _sectionLabel('APP'),
          _settingsCard([
            _settingsRow(
              icon: Icons.info_outline,
              title: 'App Version',
              trailing: const Text(
                'v1.0',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          if (isAuthenticated)
            Material(
              color: AppColors.error.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _confirmSignOut(context),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.logout,
                          size: 17,
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Sign Out',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward,
                        size: 19,
                        color: AppColors.error,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _profileStat(String value, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Playfair Display',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.forest,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    ),
  );

  Widget _settingsCard(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(children: children),
  );

  Widget _settingsDivider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(height: 1, color: AppColors.border),
  );

  Widget _settingsRow({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: AppColors.forest),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forest,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // ignore: use_null_aware_elements
            if (trailing != null) trailing,
            if (onTap != null) ...[
              if (trailing != null) const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
