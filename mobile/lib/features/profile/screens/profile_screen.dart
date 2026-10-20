import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/models/user_profile_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaa_brand_badge.dart';
import '../../../core/widgets/adaa_wordmark.dart';
import '../../../state/auth_provider.dart';
import '../../../state/community_provider.dart';
import '../../../state/profile_provider.dart';
import '../../../state/wardrobe_provider.dart';
import '../../requests/screens/requests_screen.dart';

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

  final List<String> _availableFitTypes = const ['slim', 'regular', 'relaxed', 'oversized'];
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
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Are you sure you want to sign out of your adaa account?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.missing),
            onPressed: () async {
              Navigator.pop(ctx);
              await SessionManager.performLogout(context);
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
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
      final xFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
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
              SnackBar(content: Text(profileProv.error!), backgroundColor: AppColors.missing),
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

  void _showEditProfileDialog(BuildContext context) {
    final auth = context.read<AuthProvider>();
    ProfileProvider? profileProv;
    try {
      profileProv = context.read<ProfileProvider>();
    } catch (_) {}

    final currentProf = profileProv?.profile;
    final initialName = currentProf?.displayName ?? _customDisplayName ?? auth.displayName;
    final initialBio = currentProf?.bio ?? _bio ?? '';
    final initialAge = currentProf?.age?.toString() ?? '';
    final initialPhone = currentProf?.phoneNumber ?? '';
    final initialTops = currentProf?.fitPreferences.topsSize ?? '';
    final initialBottoms = currentProf?.fitPreferences.bottomsSize ?? '';
    final initialShoes = currentProf?.fitPreferences.shoeSize ?? '';
    String? selectedFit = currentProf?.fitPreferences.preferredFit;
    final List<String> selectedStyles = List<String>.from(currentProf?.preferredStyles ?? []);

    final nameController = TextEditingController(text: initialName);
    final bioController = TextEditingController(text: initialBio);
    final ageController = TextEditingController(text: initialAge);
    final phoneController = TextEditingController(text: initialPhone);
    final topsController = TextEditingController(text: initialTops);
    final bottomsController = TextEditingController(text: initialBottoms);
    final shoesController = TextEditingController(text: initialShoes);

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    String? formError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.9,
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      const SizedBox(height: 16),
                      const Text(
                        'Edit Profile',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.espresso),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Update your identity, clothing sizes, and style tags.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      if (formError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.missing.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.missing.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            formError!,
                            style: const TextStyle(fontSize: 12, color: AppColors.missing),
                          ),
                        ),
                      ],

                      // Account Email (Read-only Supabase Auth)
                      const SizedBox(height: 16),
                      const Text('Account Email', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.sandSoft.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_outline, size: 15, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                auth.user?.email ?? currentProf?.email ?? 'Account email',
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Text('Managed by Auth', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Authentication email is secured and cannot be modified via profile update.',
                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),

                      // Display Name
                      const SizedBox(height: 16),
                      const Text('Display Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameController,
                        maxLength: 50,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Alex Morgan',
                          counterText: '',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Display name cannot be empty';
                          }
                          return null;
                        },
                      ),

                      // Bio / Style Notes
                      const SizedBox(height: 14),
                      const Text('Bio / Style Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: bioController,
                        maxLines: 3,
                        maxLength: 250,
                        decoration: const InputDecoration(
                          hintText: 'Share your sizing, style preferences, or borrowing notes...',
                        ),
                      ),

                      // Age & Phone Number
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Age', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  key: const Key('profile_age_input'),
                                  controller: ageController,
                                  keyboardType: TextInputType.number,
                                  autovalidateMode: AutovalidateMode.onUserInteraction,
                                  maxLength: 3,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. 21',
                                    counterText: '',
                                  ),
                                  validator: (val) {
                                    if (val != null && val.trim().isNotEmpty) {
                                      final parsed = int.tryParse(val.trim());
                                      if (parsed == null || parsed < 13 || parsed > 120) {
                                        return 'Enter valid age (13-120)';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Phone Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: phoneController,
                                  keyboardType: TextInputType.phone,
                                  maxLength: 20,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. +1 555-0199',
                                    counterText: '',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Sizing & Fit Preferences
                      const SizedBox(height: 20),
                      const Row(
                        children: [
                          Icon(Icons.straighten_outlined, size: 16, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text('Fit & Sizing Preferences', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.espresso)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Helps community members discover garments that match your dimensions. (All optional)',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tops Size', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: topsController,
                                  maxLength: 10,
                                  decoration: const InputDecoration(hintText: 'S, M, L...', counterText: ''),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Bottoms', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: bottomsController,
                                  maxLength: 10,
                                  decoration: const InputDecoration(hintText: '28, 30, 32...', counterText: ''),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Shoes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: shoesController,
                                  maxLength: 10,
                                  decoration: const InputDecoration(hintText: 'US 9, 41...', counterText: ''),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text('Preferred Fit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: _availableFitTypes.map((fit) {
                          final isSelected = selectedFit == fit;
                          return ChoiceChip(
                            label: Text(fit),
                            selected: isSelected,
                            selectedColor: AppColors.sandSoft,
                            backgroundColor: AppColors.surface,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppColors.espresso : AppColors.textSecondary,
                            ),
                            onSelected: (selected) {
                              setSheetState(() {
                                selectedFit = selected ? fit : null;
                              });
                            },
                          );
                        }).toList(),
                      ),

                      // Preferred Styles
                      const SizedBox(height: 16),
                      const Text('Aesthetic & Style Preferences', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _availableStyleTags.map((style) {
                          final isSelected = selectedStyles.contains(style);
                          return FilterChip(
                            label: Text(style),
                            selected: isSelected,
                            selectedColor: AppColors.terracottaSoft,
                            backgroundColor: AppColors.surface,
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppColors.terracottaDark : AppColors.textSecondary,
                            ),
                            checkmarkColor: AppColors.terracottaDark,
                            onSelected: (selected) {
                              setSheetState(() {
                                if (selected) {
                                  selectedStyles.add(style);
                                } else {
                                  selectedStyles.remove(style);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),

                      // Privacy Notice Banner
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.shield_outlined, size: 16, color: AppColors.primary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You can control which fields approved circle peers see using the Community Privacy Settings section on your profile screen.',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSaving ? null : () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.terracotta,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) return;
                                      setSheetState(() {
                                        isSaving = true;
                                        formError = null;
                                      });

                                      final messenger = ScaffoldMessenger.of(context);
                                      CommunityProvider? commProvider;
                                      try {
                                        commProvider = context.read<CommunityProvider>();
                                      } catch (_) {}
                                      final rawAge = ageController.text.trim();
                                      final parsedAge = rawAge.isNotEmpty ? int.tryParse(rawAge) : null;
                                      final fitPrefs = FitPreferencesModel(
                                        topsSize: topsController.text.trim().isEmpty ? null : topsController.text.trim(),
                                        bottomsSize: bottomsController.text.trim().isEmpty ? null : bottomsController.text.trim(),
                                        shoeSize: shoesController.text.trim().isEmpty ? null : shoesController.text.trim(),
                                        preferredFit: selectedFit,
                                      );

                                      try {
                                        if (profileProv != null) {
                                          final ok = await profileProv.updateProfile(
                                            displayName: nameController.text.trim(),
                                            bio: bioController.text.trim(),
                                            age: parsedAge,
                                            phoneNumber: phoneController.text.trim(),
                                            fitPreferences: fitPrefs,
                                            preferredStyles: selectedStyles,
                                          );
                                          if (!ok) {
                                            throw Exception(profileProv?.error ?? 'Failed to update profile');
                                          }
                                        } else {
                                          final updated = await ApiClient.updateMyProfile(
                                            displayName: nameController.text.trim(),
                                            bio: bioController.text.trim(),
                                            age: parsedAge,
                                            phoneNumber: phoneController.text.trim(),
                                            fitPreferences: fitPrefs,
                                            preferredStyles: selectedStyles,
                                          );
                                          if (mounted) {
                                            setState(() {
                                              _customDisplayName = updated.displayName;
                                              _bio = updated.bio;
                                            });
                                          }
                                        }

                                        if (mounted) {
                                          setState(() {
                                            _customDisplayName = nameController.text.trim();
                                            _bio = bioController.text.trim();
                                          });
                                          commProvider?.loadMyCommunities();
                                          commProvider?.loadSharedCloset();
                                        }

                                        if (ctx.mounted) {
                                          Navigator.pop(ctx);
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text('Profile updated successfully!'),
                                              backgroundColor: AppColors.exactMatch,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setSheetState(() {
                                          isSaving = false;
                                          formError = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
                                        });
                                      }
                                    },
                              child: isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showServerSettingsDialog(BuildContext context) {
    final controller = TextEditingController(text: ApiEndpoints.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('API Connection', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Server Endpoint URL:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'http://127.0.0.1:8000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                ApiEndpoints.setBaseUrl(newUrl);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('API URL updated to $newUrl')),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyTile({
    required String title,
    required String subtitle,
    required bool value,
    required bool isPrivateByDefault,
    required ValueChanged<bool> onChanged,
    bool isSaving = false,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: isSaving ? null : onChanged,
      activeThumbColor: AppColors.terracotta,
      activeTrackColor: AppColors.terracottaSoft,
      dense: true,
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
          if (isPrivateByDefault)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(left: 6),
              decoration: BoxDecoration(
                color: AppColors.sandSoft.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Private by default',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    );
  }

  Future<void> _handlePrivacyToggle(
    BuildContext context,
    ProfilePrivacySettingsModel currentSettings,
    ProfilePrivacySettingsModel newSettings,
  ) async {
    ProfileProvider? profileProv;
    try {
      profileProv = context.read<ProfileProvider>();
    } catch (_) {}

    final messenger = ScaffoldMessenger.of(context);
    try {
      if (profileProv != null) {
        final success = await profileProv.updatePrivacy(newSettings);
        if (!success && profileProv.error != null) {
          messenger.showSnackBar(
            SnackBar(content: Text(profileProv.error!), backgroundColor: AppColors.missing),
          );
        }
      } else {
        await ApiClient.updateMyPrivacySettings(newSettings);
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('ApiException: ', '')),
          backgroundColor: AppColors.missing,
        ),
      );
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
    final displayName = userProfile?.displayName ?? _customDisplayName ?? auth.displayName;
    final bio = userProfile?.bio ?? _bio;
    final avatarUrl = userProfile?.avatarUrl;
    final privacySettings = userProfile?.privacySettings ?? const ProfilePrivacySettingsModel();
    final fitPrefs = userProfile?.fitPreferences ?? const FitPreferencesModel();
    final preferredStyles = userProfile?.preferredStyles ?? const [];

    final initials = displayName.isNotEmpty
        ? (displayName.length >= 2 ? displayName.substring(0, 2).toUpperCase() : displayName[0].toUpperCase())
        : 'A';

    return Scaffold(
      appBar: AppBar(
        title: const Text('profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Profile Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [AppColors.cardShadow],
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    ClipOval(
                      child: Container(
                        width: 76,
                        height: 76,
                        color: AppColors.accentSoft,
                        child: (_isUploadingPhoto)
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                ),
                              )
                            : (avatarUrl != null && avatarUrl.isNotEmpty)
                                ? Image.network(
                                    ApiEndpoints.resolveImageUrl(avatarUrl),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Center(
                                      child: Text(
                                        initials,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                      ),
                    ),
                    InkWell(
                      onTap: _isUploadingPhoto ? null : () => _pickAndUploadAvatar(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.espresso,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                if (bio != null && bio.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      bio.trim(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.espresso, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  auth.user?.email ?? userProfile?.email ?? '',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                const AdaaBrandBadge(text: 'AUTHENTICATED MEMBER'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showEditProfileDialog(context),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Overview Stats
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: widget.onNavigateToCloset,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [AppColors.cardShadow],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.checkroom_outlined, color: AppColors.primary, size: 22),
                        const SizedBox(height: 8),
                        Text(
                          '${wardrobeProv.items.length}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        const Text(
                          'Closet Pieces',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: widget.onNavigateToCommunities,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [AppColors.cardShadow],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.groups_outlined, color: AppColors.accent, size: 22),
                        const SizedBox(height: 8),
                        Text(
                          '${commProv.myCommunities.length}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        const Text(
                          'Active Circles',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Activity & Borrowing Section
          if (isAuthenticated) ...[
            const Text(
              'BORROWING & ACTIVITY',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Card(
              color: AppColors.surface,
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              child: ListTile(
                leading: const Icon(Icons.handshake_outlined, color: AppColors.primary),
                title: const Text('Borrowing Requests', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Review incoming requests and track outgoing clothes', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RequestsScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Fit & Sizing Preferences Card
          if (fitPrefs.hasAnyPreferences || preferredStyles.isNotEmpty) ...[
            const Text(
              'FIT & SIZING PREFERENCES',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Card(
              color: AppColors.surface,
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (fitPrefs.hasAnyPreferences) ...[
                      const Row(
                        children: [
                          Icon(Icons.straighten_outlined, size: 14, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text('Sizes & Silhouette', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (fitPrefs.topsSize != null && fitPrefs.topsSize!.isNotEmpty)
                            _buildInfoChip('Tops', fitPrefs.topsSize!),
                          if (fitPrefs.bottomsSize != null && fitPrefs.bottomsSize!.isNotEmpty)
                            _buildInfoChip('Bottoms', fitPrefs.bottomsSize!),
                          if (fitPrefs.shoeSize != null && fitPrefs.shoeSize!.isNotEmpty)
                            _buildInfoChip('Shoes', fitPrefs.shoeSize!),
                          if (fitPrefs.preferredFit != null && fitPrefs.preferredFit!.isNotEmpty)
                            _buildInfoChip('Fit', fitPrefs.preferredFit!),
                        ],
                      ),
                      if (preferredStyles.isNotEmpty) const SizedBox(height: 14),
                    ],
                    if (preferredStyles.isNotEmpty) ...[
                      const Row(
                        children: [
                          Icon(Icons.style_outlined, size: 14, color: AppColors.accent),
                          SizedBox(width: 6),
                          Text('Favorite Aesthetics', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: preferredStyles.map((style) {
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Community Privacy Settings Section
          const Text(
            'COMMUNITY PRIVACY SETTINGS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose what approved members of your shared circles can see. Display name remains visible for community sharing.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Card(
            color: AppColors.surface,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Column(
              children: [
                _buildPrivacyTile(
                  title: 'Profile Photo',
                  subtitle: 'Show your avatar to circle peers',
                  value: privacySettings.showProfilePhoto,
                  isPrivateByDefault: false,
                  onChanged: (val) {
                    _handlePrivacyToggle(
                      context,
                      privacySettings,
                      privacySettings.copyWith(showProfilePhoto: val),
                    );
                  },
                ),
                const Divider(height: 1),
                _buildPrivacyTile(
                  title: 'Bio & Style Notes',
                  subtitle: 'Display your bio on community profile',
                  value: privacySettings.showBio,
                  isPrivateByDefault: false,
                  onChanged: (val) {
                    _handlePrivacyToggle(
                      context,
                      privacySettings,
                      privacySettings.copyWith(showBio: val),
                    );
                  },
                ),
                const Divider(height: 1),
                _buildPrivacyTile(
                  title: 'Age',
                  subtitle: 'Show your age to approved members',
                  value: privacySettings.showAge,
                  isPrivateByDefault: true,
                  onChanged: (val) {
                    _handlePrivacyToggle(
                      context,
                      privacySettings,
                      privacySettings.copyWith(showAge: val),
                    );
                  },
                ),
                const Divider(height: 1),
                _buildPrivacyTile(
                  title: 'Phone Number',
                  subtitle: 'Show contact phone to approved circle peers',
                  value: privacySettings.showPhone,
                  isPrivateByDefault: true,
                  onChanged: (val) {
                    _handlePrivacyToggle(
                      context,
                      privacySettings,
                      privacySettings.copyWith(showPhone: val),
                    );
                  },
                ),
                const Divider(height: 1),
                _buildPrivacyTile(
                  title: 'Account Email',
                  subtitle: 'Show email to approved circle peers',
                  value: privacySettings.showEmail,
                  isPrivateByDefault: true,
                  onChanged: (val) {
                    _handlePrivacyToggle(
                      context,
                      privacySettings,
                      privacySettings.copyWith(showEmail: val),
                    );
                  },
                ),
                const Divider(height: 1),
                _buildPrivacyTile(
                  title: 'Fit Preferences & Clothing Sizes',
                  subtitle: 'Share tops, bottoms, shoe sizes, and fit',
                  value: privacySettings.showFitPreferences,
                  isPrivateByDefault: true,
                  onChanged: (val) {
                    _handlePrivacyToggle(
                      context,
                      privacySettings,
                      privacySettings.copyWith(showFitPreferences: val),
                    );
                  },
                ),
                const Divider(height: 1),
                _buildPrivacyTile(
                  title: 'Style Aesthetics',
                  subtitle: 'Show your fashion aesthetic tags to circle peers',
                  value: privacySettings.showPreferredStyles,
                  isPrivateByDefault: false,
                  onChanged: (val) {
                    _handlePrivacyToggle(
                      context,
                      privacySettings,
                      privacySettings.copyWith(showPreferredStyles: val),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),


          // Settings Section
          const Text(
            'ACCOUNT & PREFERENCES',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Card(
            color: AppColors.surface,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.router_outlined, color: AppColors.primary),
                  title: const Text('Backend API Server', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(ApiEndpoints.baseUrl, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => _showServerSettingsDialog(context),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.shield_outlined, color: AppColors.primary),
                  title: Text('Privacy & Sharing', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('Personal wardrobe items are private by default', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ),
                if (isAuthenticated) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.missing),
                    title: const Text('Sign Out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.missing)),
                    onTap: () => _confirmSignOut(context),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Brand footer
          const Center(
            child: Column(
              children: [
                AdaaWordmark(size: AdaaWordmarkSize.small),
                SizedBox(height: 4),
                Text(
                  'fashion intelligence & campus sharing',
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.sandSoft.withValues(alpha: 0.5),
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
}
