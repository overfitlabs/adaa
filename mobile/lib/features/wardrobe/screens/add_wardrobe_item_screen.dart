import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/models/garment_item.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/private_image_view.dart';
import '../../../state/wardrobe_provider.dart';
import '../../../core/widgets/adaa_wordmark.dart';
import '../../analysis/screens/item_review_screen.dart';

class AddWardrobeItemScreen extends StatefulWidget {
  const AddWardrobeItemScreen({super.key});

  @override
  State<AddWardrobeItemScreen> createState() => _AddWardrobeItemScreenState();
}

class _AddWardrobeItemScreenState extends State<AddWardrobeItemScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController(text: 'tops');
  final _subCategoryController = TextEditingController();
  final _primaryColorController = TextEditingController();
  final _secondaryColorController = TextEditingController();
  final _brandController = TextEditingController();
  final _sizeController = TextEditingController();
  final _conditionController = TextEditingController(text: 'Good');
  final _notesController = TextEditingController();
  final _materialController = TextEditingController();
  final _patternController = TextEditingController();
  final _fitController = TextEditingController();
  final _seasonController = TextEditingController();
  final _formalityController = TextEditingController();
  final _tagsController = TextEditingController();

  bool _isDetecting = false;
  bool _isSaving = false;
  DetectedFashionItem? _detectedItem;
  List<DetectedFashionItem> _detectedItems = [];
  bool _showExtractedCrop = true;

  final List<String> _categoryOptions = [
    'tops',
    'bottoms',
    'dresses',
    'outerwear',
    'shoes',
    'bags',
    'accessories',
    'other',
  ];

  final List<String> _conditionOptions = [
    'New with tags',
    'Like New',
    'Good',
    'Fair',
    'Vintage',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _subCategoryController.dispose();
    _primaryColorController.dispose();
    _secondaryColorController.dispose();
    _brandController.dispose();
    _sizeController.dispose();
    _conditionController.dispose();
    _notesController.dispose();
    _materialController.dispose();
    _patternController.dispose();
    _fitController.dispose();
    _seasonController.dispose();
    _formalityController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = picked;
        });
        // Automatically suggest running AI garment detection
        _runAutoDetection();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.missing,
          ),
        );
      }
    }
  }

  Future<void> _runAutoDetection() async {
    if (_selectedImage == null) return;
    setState(() => _isDetecting = true);

    try {
      final data = await ApiClient.detectWardrobeItemFromPhoto(_selectedImage!);
      setState(() {
        final rawList = data['detected_items'] as List<dynamic>? ?? [];
        _detectedItems = rawList
            .map((e) => DetectedFashionItem.fromJson(e as Map<String, dynamic>))
            .toList();

        _detectedItem = data['detected_item'] != null
            ? DetectedFashionItem.fromJson(data['detected_item'])
            : (_detectedItems.isNotEmpty ? _detectedItems.first : null);
        _showExtractedCrop = true;
        final detected = _detectedItem;

        if (detected != null) {
          _nameController.text = detected.name;
          final cat = detected.category.toLowerCase().trim();
          if (_categoryOptions.contains(cat)) {
            _categoryController.text = cat;
          } else if (cat.contains('jacket') ||
              cat.contains('coat') ||
              cat.contains('blazer')) {
            _categoryController.text = 'outerwear';
          } else if (cat.contains('jean') ||
              cat.contains('trouser') ||
              cat.contains('pant') ||
              cat.contains('skirt') ||
              cat.contains('short')) {
            _categoryController.text = 'bottoms';
          } else if (cat.contains('shoe') ||
              cat.contains('boot') ||
              cat.contains('sneaker') ||
              cat.contains('footwear')) {
            _categoryController.text = 'shoes';
          } else if (cat.contains('bag') ||
              cat.contains('clutch') ||
              cat.contains('tote')) {
            _categoryController.text = 'bags';
          } else if (cat.contains('dress') || cat.contains('gown')) {
            _categoryController.text = 'dresses';
          } else if (cat.contains('shirt') ||
              cat.contains('top') ||
              cat.contains('sweater') ||
              cat.contains('hoodie')) {
            _categoryController.text = 'tops';
          } else {
            _categoryController.text = 'other';
          }

          _subCategoryController.text = detected.subCategory ?? '';
          _primaryColorController.text = detected.primaryColor;
          _secondaryColorController.text = detected.secondaryColor ?? '';
          _materialController.text = detected.attributes.material ?? '';
          _patternController.text = detected.attributes.pattern ?? '';
          _fitController.text = detected.attributes.fit ?? '';
          _seasonController.text = detected.attributes.season ?? '';
          _formalityController.text = detected.attributes.formality ?? '';
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'AI detected garment attributes! Verify and edit details below.',
            ),
            backgroundColor: AppColors.exactMatch,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-detect note: $e'),
            backgroundColor: AppColors.approxMatch,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDetecting = false);
    }
  }

  Future<void> _saveItem() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select or capture a photo of the clothing item.',
          ),
          backgroundColor: AppColors.missing,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final prov = context.read<WardrobeProvider>();
    final success = await prov.addItem(
      name: _nameController.text.trim(),
      category: _categoryController.text.trim().toLowerCase(),
      primaryColor: _primaryColorController.text.trim(),
      subCategory: _subCategoryController.text.trim().isEmpty
          ? null
          : _subCategoryController.text.trim(),
      secondaryColor: _secondaryColorController.text.trim().isEmpty
          ? null
          : _secondaryColorController.text.trim(),
      brand: _brandController.text.trim().isEmpty
          ? null
          : _brandController.text.trim(),
      size: _sizeController.text.trim().isEmpty
          ? null
          : _sizeController.text.trim(),
      condition: _conditionController.text.trim().isEmpty
          ? null
          : _conditionController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      material: _materialController.text.trim().isEmpty
          ? null
          : _materialController.text.trim(),
      pattern: _patternController.text.trim().isEmpty
          ? null
          : _patternController.text.trim(),
      fit: _fitController.text.trim().isEmpty
          ? null
          : _fitController.text.trim(),
      season: _seasonController.text.trim().isEmpty
          ? null
          : _seasonController.text.trim(),
      formality: _formalityController.text.trim().isEmpty
          ? null
          : _formalityController.text.trim(),
      tags: tags,
      imagePath: (_showExtractedCrop && _detectedItem?.extractedImagePath != null)
          ? _detectedItem!.extractedImagePath
          : null,
      file: (_showExtractedCrop && _detectedItem?.extractedImagePath != null)
          ? null
          : _selectedImage,
    );

    setState(() => _isSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Garment added to your digital wardrobe!'),
          backgroundColor: AppColors.exactMatch,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(prov.error ?? 'Failed to save item.'),
          backgroundColor: AppColors.missing,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add to Your Wardrobe',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 30,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Capture a piece and let adaa help catalogue its details.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 22),
              // Image Picker Area
              _buildImagePickerBox(),

              if (_detectedItems.length > 1) ...[
                const SizedBox(height: 14),
                _buildMultiItemBanner(),
              ],

              if (_selectedImage != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isDetecting ? null : _runAutoDetection,
                        icon: _isDetecting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.forest,
                                ),
                              )
                            : const Icon(
                                Icons.auto_awesome,
                                size: 18,
                                color: AppColors.forest,
                              ),
                        label: Text(
                          _isDetecting
                              ? 'Detecting Garment...'
                              : 'Auto-Detect Details with AI',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: AppColors.forest,
                            width: 1.2,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 18),

              if (_isDetecting)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.forest,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'AI is analyzing your garment details...',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const Text(
                'GARMENT DETAILS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Title *',
                  hintText: 'e.g. Classic White Linen Button-Down',
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Please enter a title'
                    : null,
              ),

              const SizedBox(height: 14),

              // Category Selector Dropdown
              DropdownButtonFormField<String>(
                initialValue:
                    _categoryOptions.contains(_categoryController.text)
                    ? _categoryController.text
                    : 'tops',
                decoration: const InputDecoration(labelText: 'Category *'),
                items: _categoryOptions.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _categoryController.text = val);
                  }
                },
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _primaryColorController,
                      decoration: const InputDecoration(
                        labelText: 'Primary Color *',
                        hintText: 'e.g. Navy, Cream',
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Color is required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _secondaryColorController,
                      decoration: const InputDecoration(
                        labelText: 'Accent Color',
                        hintText: 'Optional',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _brandController,
                      decoration: const InputDecoration(
                        labelText: 'Brand',
                        hintText: 'e.g. Zara, Levi\'s, Nike',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _sizeController,
                      decoration: const InputDecoration(
                        labelText: 'Size',
                        hintText: 'e.g. M, 32/30, US 9',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                initialValue:
                    _conditionOptions.contains(_conditionController.text)
                    ? _conditionController.text
                    : 'Good',
                decoration: const InputDecoration(
                  labelText: 'Condition',
                  hintText: 'Select condition',
                ),
                items: _conditionOptions.map((cond) {
                  return DropdownMenuItem(value: cond, child: Text(cond));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _conditionController.text = val);
                  }
                },
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'e.g. Dry clean only, gifts from family, favorite styling tip',
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _materialController,
                      decoration: const InputDecoration(
                        labelText: 'Material',
                        hintText: 'e.g. Cotton, Denim',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fitController,
                      decoration: const InputDecoration(
                        labelText: 'Fit',
                        hintText: 'e.g. Tailored, Relaxed',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _patternController,
                      decoration: const InputDecoration(
                        labelText: 'Pattern',
                        hintText: 'e.g. Solid, Striped',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _formalityController,
                      decoration: const InputDecoration(
                        labelText: 'Formality',
                        hintText: 'e.g. Smart-Casual',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma separated)',
                  hintText: 'e.g. office, capsule, summer, favorite',
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveItem,
                  icon: const Icon(Icons.checkroom),
                  label: Text(
                    _isSaving ? 'Saving Garment...' : 'Save To Wardrobe',
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultiItemBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_detectedItems.length} garments detected in this photo!',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Review and add all pieces to your closet at once.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            onPressed: () async {
              final res = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => ItemReviewScreen(
                    customItems: _detectedItems,
                    sourceImageUrl: _selectedImage?.path,
                    initialIntent: ItemReviewIntent.addToCloset,
                  ),
                ),
              );
              if (res == true && mounted) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Add All'),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePickerBox() {
    return GestureDetector(
      onTap: () => _showPickerModal(),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant, width: 1.5),
          ),
          child: _selectedImage != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: (_showExtractedCrop && _detectedItem?.extractedImageUrl != null)
                          ? PrivateImageView(
                              imageUrl: _detectedItem!.extractedImageUrl,
                              fit: BoxFit.contain,
                              backgroundColor: AppColors.surfaceContainerLow,
                            )
                          : (kIsWeb
                              ? Image.network(
                                  _selectedImage!.path,
                                  fit: BoxFit.contain,
                                )
                              : Image.file(
                                  File(_selectedImage!.path),
                                  fit: BoxFit.contain,
                                )),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.forest.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Change Photo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_detectedItem?.extractedImageUrl != null)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showExtractedCrop = !_showExtractedCrop;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.espresso.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _showExtractedCrop ? Icons.crop : Icons.photo,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _showExtractedCrop ? 'Extracted Crop' : 'Original Photo',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.surface,
                      child: Icon(
                        Icons.camera_alt_outlined,
                        color: AppColors.forest,
                        size: 26,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Upload Photo of Your Garment',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'AI will extract garment pieces and auto-populate details',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _showPickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.forest,
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.forest,
                ),
                title: const Text(
                  'Take Photo with Camera',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
