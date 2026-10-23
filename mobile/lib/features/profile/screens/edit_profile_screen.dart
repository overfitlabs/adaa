// ignore_for_file: unnecessary_underscores

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/models/user_profile_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/auth_provider.dart';
import '../../../state/community_provider.dart';
import '../../../state/profile_provider.dart';
import '../../../core/widgets/adaa_wordmark.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _topsController = TextEditingController();
  final _bottomsController = TextEditingController();
  final _shoesController = TextEditingController();

  static const _styles = [
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
  static const _fits = ['Slim', 'Regular', 'Relaxed', 'Oversized'];

  String? _selectedFit;
  final Set<String> _selectedStyles = {};
  bool _initialized = false;
  bool _saving = false;
  bool _dirty = false;
  String? _error;
  XFile? _pendingAvatar;
  String? _pendingAvatarPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final profile = context.read<ProfileProvider>().profile;
    final auth = context.read<AuthProvider>();
    _nameController.text = profile?.displayName ?? auth.displayName;
    _bioController.text = profile?.bio ?? '';
    _ageController.text = profile?.age?.toString() ?? '';
    _phoneController.text = profile?.phoneNumber ?? '';
    _topsController.text = profile?.fitPreferences.topsSize ?? '';
    _bottomsController.text = profile?.fitPreferences.bottomsSize ?? '';
    _shoesController.text = profile?.fitPreferences.shoeSize ?? '';
    _selectedFit = profile?.fitPreferences.preferredFit;
    _selectedStyles.addAll(profile?.preferredStyles ?? const []);
    for (final controller in [
      _nameController,
      _bioController,
      _ageController,
      _phoneController,
      _topsController,
      _bottomsController,
      _shoesController,
    ]) {
      controller.addListener(() => _dirty = true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _topsController.dispose();
    _bottomsController.dispose();
    _shoesController.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (file == null || !mounted) return;
    setState(() {
      _pendingAvatar = file;
      _pendingAvatarPath = file.path;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profileProvider = context.read<ProfileProvider>();
      final rawAge = _ageController.text.trim();
      final age = rawAge.isEmpty ? null : int.tryParse(rawAge);
      final fit = FitPreferencesModel(
        topsSize: _optional(_topsController.text),
        bottomsSize: _optional(_bottomsController.text),
        shoeSize: _optional(_shoesController.text),
        preferredFit: _selectedFit?.toLowerCase(),
      );

      if (_pendingAvatar != null) {
        final uploaded = await profileProvider.uploadAvatar(_pendingAvatar!);
        if (!uploaded) {
          throw Exception(
            profileProvider.error ?? 'Could not upload profile photo',
          );
        }
      }

      final ok = await profileProvider.updateProfile(
        displayName: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        age: age,
        phoneNumber: _optional(_phoneController.text),
        fitPreferences: fit,
        preferredStyles: _selectedStyles.toList(),
      );
      if (!ok) {
        throw Exception(profileProvider.error ?? 'Failed to update profile');
      }
      if (!mounted) return;
      try {
        final community = context.read<CommunityProvider>();
        community.loadMyCommunities();
        community.loadSharedCloset();
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppColors.exactMatch,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e
              .toString()
              .replaceFirst('ApiException: ', '')
              .replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _cancel() async {
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text(
            'You have unsaved changes. Discard them and return to Profile?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>().profile;
    final email = auth.user?.email ?? profile?.email ?? '';
    final displayName = profile?.displayName ?? auth.displayName;
    final initials = displayName.isEmpty
        ? 'AD'
        : displayName.length >= 2
        ? displayName.substring(0, 2).toUpperCase()
        : displayName.toUpperCase();

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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            const Text(
              'Edit Profile',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 32,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Keep your style profile and preferences up to date.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              _notice(
                Icons.error_outline,
                'Could not save changes',
                _error!,
                isError: true,
              ),
              const SizedBox(height: 18),
            ],
            _sectionHeader('PROFILE PHOTO', trailing: 'Avatar'),
            const SizedBox(height: 16),
            Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceContainerLow,
                        border: Border.all(
                          color: AppColors.outlineVariant,
                          width: 2,
                        ),
                        image: _pendingAvatarPath == null
                            ? null
                            : DecorationImage(
                                image: FileImage(__file(_pendingAvatarPath!)),
                                fit: BoxFit.cover,
                              ),
                      ),
                      alignment: Alignment.center,
                      child: _pendingAvatarPath == null
                          ? Text(
                              initials,
                              style: const TextStyle(
                                fontFamily: 'Playfair Display',
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                                color: AppColors.forest,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Material(
                        color: AppColors.forest,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: _choosePhoto,
                          customBorder: const CircleBorder(),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.photo_camera_outlined,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextButton(
                        onPressed: _choosePhoto,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.forest,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          'Change Photo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'JPG or PNG • Max 5MB recommended',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_pendingAvatar != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: AppColors.forest,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'New photo selected',
                        style: TextStyle(fontSize: 12, color: AppColors.forest),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _pendingAvatar = null;
                        _pendingAvatarPath = null;
                      }),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            _sectionHeader('ACCOUNT INFORMATION', trailing: 'Core Details'),
            const SizedBox(height: 16),
            _fieldLabel('ACCOUNT EMAIL'),
            const SizedBox(height: 6),
            TextFormField(
              initialValue: email,
              readOnly: true,
              enabled: false,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              decoration: _inputDecoration().copyWith(
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                prefixIcon: const Icon(Icons.lock_outline, size: 16),
                suffixIcon: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                  child: Text(
                    'READ-ONLY',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                suffixIconConstraints: const BoxConstraints(minWidth: 80),
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Email is linked to your secure adaa authentication and cannot be edited here.',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            _fieldLabel('DISPLAY NAME'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              maxLength: 50,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Display name cannot be empty'
                  : null,
              decoration: _inputDecoration(hint: 'Your full name')
                  .copyWith(counterText: ''),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _fieldLabel('BIO / STYLE NOTES'),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _bioController,
                  builder: (_, value, __) => Text(
                    '${value.text.length} / 250',
                    style: TextStyle(
                      fontSize: 11,
                      color: value.text.length >= 240
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _bioController,
              maxLength: 250,
              maxLines: 3,
              decoration: _inputDecoration(hint: 'Describe your personal style')
                  .copyWith(counterText: ''),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _labeledField(
                    'AGE (OPTIONAL)',
                    _ageController,
                    keyboard: TextInputType.number,
                    hint: 'e.g. 28',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final age = int.tryParse(value.trim());
                      if (age == null || age < 13 || age > 120) {
                        return 'Use 13-120';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _labeledField(
                    'PHONE (OPTIONAL)',
                    _phoneController,
                    keyboard: TextInputType.phone,
                    hint: '+1 555-0199',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _sectionHeader('FIT & SIZING PREFERENCES'),
            const SizedBox(height: 6),
            const Text(
              'Helps your AI Stylist curate precise recommendations.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _labeledField(
                    'TOPS SIZE',
                    _topsController,
                    hint: 'S, M, L',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _labeledField(
                    'BOTTOMS',
                    _bottomsController,
                    hint: '27 / S',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _labeledField(
                    'SHOES',
                    _shoesController,
                    hint: 'EU 38',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _fieldLabel('PREFERRED FIT SILHOUETTE'),
            const SizedBox(height: 8),
            Row(
              children: _fits.map((fit) {
                final selected =
                    _selectedFit?.toLowerCase() == fit.toLowerCase();
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() {
                        _selectedFit = selected ? null : fit;
                        _dirty = true;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 11,
                          horizontal: 2,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.forest
                              : AppColors.surface,
                          border: Border.all(
                            color: selected
                                ? AppColors.forest
                                : AppColors.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          fit,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected ? Colors.white : AppColors.forest,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            _sectionHeader('AESTHETIC & STYLE PREFERENCES'),
            const SizedBox(height: 6),
            const Text(
              'Select all aesthetics that reflect your personal wardrobe:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _styles.map((style) {
                final selected = _selectedStyles.contains(style);
                return InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () => setState(() {
                    selected
                        ? _selectedStyles.remove(style)
                        : _selectedStyles.add(style);
                    _dirty = true;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.forest
                          : AppColors.surfaceContainerLow,
                      border: Border.all(
                        color: selected
                            ? AppColors.forest
                            : AppColors.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          style,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: selected ? Colors.white : AppColors.forest,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _notice(
              Icons.verified_user_outlined,
              'COMMUNITY VISIBILITY',
              'Profile visibility to approved community members is managed via Community Privacy Settings on the main Profile screen.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: AppColors.canvas,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const StadiumBorder(),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _saving ? null : _cancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forest,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {String? trailing}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
            color: AppColors.forest,
          ),
        ),
      ),
      if (trailing != null)
        Text(
          trailing,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
    ],
  );

  Widget _fieldLabel(String label) => Text(
    label,
    style: const TextStyle(
      fontSize: 10,
      letterSpacing: 1,
      fontWeight: FontWeight.w800,
      color: AppColors.forest,
    ),
  );

  Widget _labeledField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
    String? hint,
    String? Function(String?)? validator,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _fieldLabel(label),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        keyboardType: keyboard,
        validator: validator,
        decoration: _inputDecoration(hint: hint).copyWith(counterText: ''),
      ),
    ],
  );

  InputDecoration _inputDecoration({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: AppColors.outlineVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: AppColors.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: AppColors.forest, width: 1.3),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: AppColors.error),
    ),
  );

  Widget _notice(
    IconData icon,
    String title,
    String body, {
    bool isError = false,
  }) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isError
          ? AppColors.error.withValues(alpha: 0.06)
          : AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isError
            ? AppColors.error.withValues(alpha: 0.25)
            : AppColors.outlineVariant,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: isError ? AppColors.error : AppColors.forest,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isError ? AppColors.error : AppColors.forest,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// Kept separate to avoid loading an image package dependency into the widget tree.
File __file(String path) => File(path);
