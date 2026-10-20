import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/private_image_view.dart';
import '../../../state/tryon_provider.dart';
import '../../../state/wardrobe_provider.dart';

class TryOnScreen extends StatefulWidget {
  final String? prefilledInspirationUrl;
  final String? prefilledWardrobeItemId;

  const TryOnScreen({
    super.key,
    this.prefilledInspirationUrl,
    this.prefilledWardrobeItemId,
  });

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _userImage;
  XFile? _garmentImage;
  String? _selectedWardrobeItemId;
  String _selectedGarmentCategory = 'upper body';

  final List<String> _garmentCategories = [
    'upper body',
    'lower body',
    'full body',
    'dress',
    'outer',
  ];

  @override
  void initState() {
    super.initState();
    _selectedWardrobeItemId = widget.prefilledWardrobeItemId;
  }

  Future<void> _pickUserImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _userImage = picked);
    }
  }

  Future<void> _pickGarmentImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _garmentImage = picked;
        _selectedWardrobeItemId = null; // Prioritize newly picked photo
      });
    }
  }

  Future<void> _startTryOn() async {
    if (_userImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a photo of yourself first.'),
          backgroundColor: AppColors.missing,
        ),
      );
      return;
    }

    if (_garmentImage == null && _selectedWardrobeItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or upload a garment to try on.'),
          backgroundColor: AppColors.missing,
        ),
      );
      return;
    }

    final prov = context.read<TryOnProvider>();
    final success = await prov.startTryOn(
      userImage: _userImage!,
      garmentImage: _garmentImage,
      wardrobeItemId: _selectedWardrobeItemId,
      garmentCategory: _selectedGarmentCategory,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(prov.error ?? 'Failed to initiate try-on task.'),
          backgroundColor: AppColors.missing,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tryonProv = context.watch<TryOnProvider>();
    final wardrobeProv = context.watch<WardrobeProvider>();
    final task = tryonProv.activeTask;

    return Scaffold(
      appBar: AppBar(
        title: const Text('YouCam Virtual Try-On'),
        actions: [
          if (task != null)
            TextButton(
              onPressed: () => tryonProv.reset(),
              child: const Text('New Try-On', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status or Result Banner if Task Active
            if (task != null) ...[
              _buildTaskStatusCard(task),
              const SizedBox(height: 24),
            ],

            // Step 1: User Photo
            const Text(
              'STEP 1: YOUR PHOTO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _buildUserPhotoCard(),

            const SizedBox(height: 24),

            // Step 2: Target Garment
            const Text(
              'STEP 2: TARGET GARMENT OR INSPIRATION LOOK',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _buildGarmentSelectionSection(wardrobeProv),

            const SizedBox(height: 24),

            // Step 3: Garment Category
            const Text(
              'STEP 3: GARMENT CATEGORY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _garmentCategories.map((cat) {
                final isSelected = _selectedGarmentCategory == cat;
                return ChoiceChip(
                  label: Text(
                    cat.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
                  onSelected: (_) => setState(() => _selectedGarmentCategory = cat),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: tryonProv.isSubmitting || (task != null && task.isProcessing)
                    ? null
                    : _startTryOn,
                icon: const Icon(Icons.auto_awesome),
                label: Text(
                  tryonProv.isSubmitting
                      ? 'Submitting to YouCam...'
                      : task != null && task.isProcessing
                          ? 'Generating Look with YouCam AI...'
                          : 'Generate Virtual Try-On',
                ),
              ),
            ),

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildUserPhotoCard() {
    return GestureDetector(
      onTap: () => _pickUserImage(ImageSource.gallery),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: _userImage != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: kIsWeb
                        ? Image.network(
                            _userImage!.path,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(_userImage!.path),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Change Photo',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_outline, size: 38, color: AppColors.primary),
                  const SizedBox(height: 8),
                  const Text(
                    'Upload Full or Half-Body Photo',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ensure clear lighting and standard posture for best rendering',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _pickUserImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                    label: const Text('Select from Gallery'),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildGarmentSelectionSection(WardrobeProvider wardrobe) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickGarmentImage(ImageSource.gallery),
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Upload Garment Photo'),
                ),
              ),
            ],
          ),
          if (_garmentImage != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: kIsWeb
                      ? Image.network(_garmentImage!.path, width: 44, height: 44, fit: BoxFit.cover)
                      : Image.file(File(_garmentImage!.path), width: 44, height: 44, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Selected uploaded garment photo',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _garmentImage = null),
                ),
              ],
            ),
          ],
          if (wardrobe.items.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Or pick an item from your digital closet:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: wardrobe.items.length,
                itemBuilder: (ctx, idx) {
                  final wItem = wardrobe.items[idx];
                  final isChosen = _selectedWardrobeItemId == wItem.id;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedWardrobeItemId = wItem.id;
                        _garmentImage = null; // Clear manual upload
                      });
                    },
                    child: Container(
                      width: 72,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isChosen ? AppColors.primary : AppColors.border,
                          width: isChosen ? 2.5 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: PrivateImageView(
                          imageUrl: wItem.imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: AppColors.accentSoft,
                            child: const Icon(Icons.checkroom, size: 20),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskStatusCard(dynamic task) {
    if (task.isProcessing) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.accentSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Generating Try-On Preview...',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'YouCam AI is adjusting drape, proportions, and lighting onto your photo.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (task.isSuccess) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.exactMatch, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.exactMatch, size: 22),
                const SizedBox(width: 10),
                const Text(
                  'Virtual Try-On Render Ready',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.exactMatch.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    task.provider.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.exactMatch,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: PrivateImageView(
                imageUrl: task.resultImageUrl ?? '',
                width: double.infinity,
                height: 320,
                fit: BoxFit.cover,
                errorWidget: Container(
                  height: 200,
                  color: AppColors.accentSoft,
                  child: const Center(child: Text('Image preview not available')),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.missing.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.missing.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.missing),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                task.errorMessage ?? 'Try-on rendering encountered an error. Please retry.',
                style: const TextStyle(fontSize: 13, color: AppColors.missing),
              ),
            ),
          ],
        ),
      );
    }
  }
}
