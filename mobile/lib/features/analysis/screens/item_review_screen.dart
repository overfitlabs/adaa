import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/garment_item.dart';
import '../../../core/models/outfit_analysis.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaa_brand_badge.dart';
import '../../../core/widgets/private_image_view.dart';
import '../../../state/analysis_provider.dart';
import '../../../state/wardrobe_provider.dart';
import '../../matching/screens/matching_result_screen.dart';
import '../../../core/widgets/adaa_wordmark.dart';

enum ItemReviewIntent { addToCloset, findPiece }

class ItemReviewScreen extends StatefulWidget {
  final OutfitAnalysisResponse? analysis;
  final List<DetectedFashionItem>? customItems;
  final String? sourceImageUrl;
  final ItemReviewIntent? initialIntent;

  const ItemReviewScreen({
    super.key,
    this.analysis,
    this.customItems,
    this.sourceImageUrl,
    this.initialIntent,
  });

  @override
  State<ItemReviewScreen> createState() => _ItemReviewScreenState();
}

class _ItemReviewScreenState extends State<ItemReviewScreen> {
  late ItemReviewIntent _intent;
  late List<DetectedFashionItem> _items;
  final Set<String> _selectedIds = {};
  bool _isSaving = false;
  final Map<String, bool> _useOriginalCrop = {};

  @override
  void initState() {
    super.initState();
    _intent = widget.initialIntent ?? ItemReviewIntent.addToCloset;
    _items = List.from(widget.customItems ?? widget.analysis?.items ?? []);

    if (_intent == ItemReviewIntent.addToCloset) {
      _selectedIds.addAll(_items.map((i) => i.id));
    } else if (_items.isNotEmpty) {
      _selectedIds.add(_items.first.id);
    }
  }

  void _onToggleSelection(String itemId) {
    setState(() {
      if (_intent == ItemReviewIntent.findPiece) {
        _selectedIds.clear();
        _selectedIds.add(itemId);
      } else {
        if (_selectedIds.contains(itemId)) {
          _selectedIds.remove(itemId);
        } else {
          _selectedIds.add(itemId);
        }
      }
    });
  }

  void _onSelectAll() {
    setState(() {
      if (_selectedIds.length == _items.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_items.map((i) => i.id));
      }
    });
  }

  void _openEditDialog(int index, DetectedFashionItem item) {
    final nameCtrl = TextEditingController(text: item.name);
    final catCtrl = TextEditingController(text: item.category);
    final colorCtrl = TextEditingController(text: item.primaryColor);
    final secColorCtrl = TextEditingController(text: item.secondaryColor ?? '');
    final materialCtrl = TextEditingController(
      text: item.attributes.material ?? '',
    );
    final patternCtrl = TextEditingController(
      text: item.attributes.pattern ?? '',
    );
    final fitCtrl = TextEditingController(text: item.attributes.fit ?? '');
    final seasonCtrl = TextEditingController(
      text: item.attributes.season ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Edit Garment Attributes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Garment Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: catCtrl,
                decoration: const InputDecoration(
                  labelText: 'Category (tops, bottoms, outerwear, dresses, shoes, bags, accessories)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: colorCtrl,
                decoration: const InputDecoration(labelText: 'Primary Color'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secColorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Secondary Color (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: patternCtrl,
                decoration: const InputDecoration(
                  labelText: 'Pattern (e.g. solid, striped, floral, plaid)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: materialCtrl,
                decoration: const InputDecoration(
                  labelText: 'Material (e.g. cotton, denim, wool, linen)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Fit / Silhouette (e.g. slim, regular, relaxed, oversized)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: seasonCtrl,
                decoration: const InputDecoration(
                  labelText:
                      'Season (spring, summer, fall, winter, all-season)',
                ),
              ),
            ],
          ),
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
            onPressed: () {
              setState(() {
                final updated = DetectedFashionItem(
                  id: item.id,
                  category: catCtrl.text.trim().toLowerCase(),
                  subCategory: item.subCategory,
                  name: nameCtrl.text.trim(),
                  primaryColor: colorCtrl.text.trim(),
                  secondaryColor: secColorCtrl.text.trim().isEmpty
                      ? null
                      : secColorCtrl.text.trim(),
                  attributes: StyleAttributes(
                    material: materialCtrl.text.trim().isEmpty
                        ? null
                        : materialCtrl.text.trim(),
                    fit: fitCtrl.text.trim().isEmpty
                        ? null
                        : fitCtrl.text.trim(),
                    pattern: patternCtrl.text.trim().isEmpty
                        ? null
                        : patternCtrl.text.trim(),
                    formality: item.attributes.formality,
                    season: seasonCtrl.text.trim().isEmpty
                        ? null
                        : seasonCtrl.text.trim(),
                    necklineOrCollar: item.attributes.necklineOrCollar,
                  ),
                  confidence: item.confidence,
                  boundingBoxDescription: item.boundingBoxDescription,
                  box2d: item.box2d,
                  extractedImagePath: item.extractedImagePath,
                  extractedImageUrl: item.extractedImageUrl,
                );
                _items[index] = updated;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Apply Changes'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePrimaryAction() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one garment.'),
          backgroundColor: AppColors.missing,
        ),
      );
      return;
    }

    if (_intent == ItemReviewIntent.addToCloset) {
      setState(() => _isSaving = true);
      final wardrobeProv = context.read<WardrobeProvider>();
      final fallbackOriginal =
          widget.sourceImageUrl ?? widget.analysis?.imageUrl ?? '';

      final itemsToSave = _items.where((i) => _selectedIds.contains(i.id)).map((
        i,
      ) {
        if (_useOriginalCrop[i.id] == true) {
          return DetectedFashionItem(
            id: i.id,
            category: i.category,
            subCategory: i.subCategory,
            name: i.name,
            primaryColor: i.primaryColor,
            secondaryColor: i.secondaryColor,
            attributes: i.attributes,
            confidence: i.confidence,
            boundingBoxDescription: i.boundingBoxDescription,
            box2d: i.box2d,
            extractedImagePath: fallbackOriginal,
            extractedImageUrl: fallbackOriginal,
          );
        }
        return i;
      }).toList();

      final res = await wardrobeProv.bulkAddItems(
        itemsToSave,
        sourceAnalysisId: widget.analysis?.analysisId,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        final savedCount = res['saved_count'] ?? 0;

        if (savedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Saved $savedCount ${savedCount == 1 ? 'item' : 'items'} to your closet!',
              ),
              backgroundColor: AppColors.exactMatch,
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                wardrobeProv.error ?? 'Failed to save items to closet.',
              ),
              backgroundColor: AppColors.missing,
            ),
          );
        }
      }
    } else {
      final selectedItem = _items.firstWhere(
        (i) => _selectedIds.contains(i.id),
      );
      final analysisProv = context.read<AnalysisProvider>();
      setState(() => _isSaving = true);

      final success = await analysisProv.matchAgainstWardrobe(
        customItems: [selectedItem],
      );
      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MatchingResultScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                analysisProv.error ?? 'Failed to find matching pieces.',
              ),
              backgroundColor: AppColors.missing,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedIds.length;
    final totalCount = _items.length;

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
        actions: [
          if (_intent == ItemReviewIntent.addToCloset)
            TextButton(
              onPressed: _onSelectAll,
              child: Text(
                _selectedIds.length == _items.length
                    ? 'Deselect All'
                    : 'Select All',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsetsGeometry.fromLTRB(20, 0, 20, 0),
            child: const Text(
              'Review Detected Items',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 32,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: AppColors.forest,
              ),
            ),
          ),
          SizedBox(height: 8),
          if (widget.initialIntent == null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _intent = ItemReviewIntent.addToCloset;
                          _selectedIds.clear();
                          _selectedIds.addAll(_items.map((i) => i.id));
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _intent == ItemReviewIntent.addToCloset
                              ? AppColors.surface
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _intent == ItemReviewIntent.addToCloset
                              ? [AppColors.cardShadow]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.checkroom_outlined,
                              size: 16,
                              color: _intent == ItemReviewIntent.addToCloset
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'These are mine: add to my closet',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _intent == ItemReviewIntent.addToCloset
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _intent = ItemReviewIntent.findPiece;
                          _selectedIds.clear();
                          if (_items.isNotEmpty) {
                            _selectedIds.add(_items.first.id);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _intent == ItemReviewIntent.findPiece
                              ? AppColors.surface
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _intent == ItemReviewIntent.findPiece
                              ? [AppColors.cardShadow]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              size: 16,
                              color: _intent == ItemReviewIntent.findPiece
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "I'm looking for something like this",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _intent == ItemReviewIntent.findPiece
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    _intent == ItemReviewIntent.addToCloset
                        ? Icons.checkroom_outlined
                        : Icons.search,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _intent == ItemReviewIntent.addToCloset
                        ? 'Select garments to add to your personal wardrobe'
                        : 'Choose one garment to discover matching looks',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (ctx, idx) {
                final item = _items[idx];
                final isSelected = _selectedIds.contains(item.id);
                final useOriginal = _useOriginalCrop[item.id] == true;
                final fallbackOriginal =
                    widget.sourceImageUrl ?? widget.analysis?.imageUrl ?? '';
                final displayImageUrl = useOriginal
                    ? fallbackOriginal
                    : (item.extractedImageUrl ?? fallbackOriginal);

                return InkWell(
                  onTap: () => _onToggleSelection(item.id),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [AppColors.cardShadow],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 24, right: 10),
                          child: Icon(
                            _intent == ItemReviewIntent.findPiece
                                ? (isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off)
                                : (isSelected
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank),
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 84,
                            height: 84,
                            color: AppColors.surfaceContainerLow,
                            child: PrivateImageView(
                              imageUrl: displayImageUrl,
                              fit: BoxFit.contain,
                              backgroundColor: AppColors.surfaceContainerLow,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: AppColors.textSecondary,
                                    ),
                                    tooltip: 'Edit Details',
                                    onPressed: () => _openEditDialog(idx, item),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  AdaaBrandBadge(
                                    text: item.category.toUpperCase(),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Text(
                                      item.primaryColor,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (item.secondaryColor != null &&
                                      item.secondaryColor!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppColors.borderLight,
                                        ),
                                      ),
                                      child: Text(
                                        item.secondaryColor!,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  if (item.attributes.pattern != null &&
                                      item.attributes.pattern!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.attributes.pattern!,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  if (item.attributes.material != null &&
                                      item.attributes.material!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.attributes.material!,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  if (item.attributes.fit != null &&
                                      item.attributes.fit!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.attributes.fit!,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  if (item.attributes.season != null &&
                                      item.attributes.season!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.attributes.season!,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    '${(item.confidence * 100).toInt()}% confidence',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (item.extractedImageUrl != null)
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _useOriginalCrop[item.id] =
                                              !useOriginal;
                                        });
                                      },
                                      child: Text(
                                        useOriginal
                                            ? 'Show crop'
                                            : 'Keep original',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handlePrimaryAction,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _intent == ItemReviewIntent.addToCloset
                              ? Icons.save_alt
                              : Icons.search,
                          size: 20,
                        ),
                  label: Text(
                    _intent == ItemReviewIntent.addToCloset
                        ? 'Save $selectedCount of $totalCount to My Closet'
                        : 'Find Matches for Selected Piece',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
