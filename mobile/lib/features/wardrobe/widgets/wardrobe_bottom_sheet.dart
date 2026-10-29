import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/wardrobe_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/private_image_view.dart';
import '../../../state/wardrobe_provider.dart';
import '../screens/add_wardrobe_item_screen.dart';
import '../screens/wardrobe_detail_screen.dart';

/// Modal draggable bottom sheet for browsing or selecting wardrobe items
/// while keeping the underlying screen (e.g. Ask ADAA Chat) and scroll position intact.
class WardrobeBottomSheet extends StatefulWidget {
  final ValueChanged<WardrobeItem>? onItemSelected;
  final String title;

  const WardrobeBottomSheet({
    super.key,
    this.onItemSelected,
    this.title = 'Digital Wardrobe',
  });

  static Future<WardrobeItem?> show(
    BuildContext context, {
    ValueChanged<WardrobeItem>? onItemSelected,
    String title = 'Digital Wardrobe',
  }) {
    return showModalBottomSheet<WardrobeItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WardrobeBottomSheet(
        onItemSelected: onItemSelected,
        title: title,
      ),
    );
  }

  @override
  State<WardrobeBottomSheet> createState() => _WardrobeBottomSheetState();
}

class _WardrobeBottomSheetState extends State<WardrobeBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<WardrobeProvider>();
      if (prov.items.isEmpty && !prov.isLoading) {
        prov.loadWardrobe();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<WardrobeItem> _filterItems(List<WardrobeItem> allItems) {
    final query = _searchController.text.trim().toLowerCase();
    return allItems.where((item) {
      final matchesCategory = _selectedCategory == 'all' ||
          (item.category.toLowerCase() == _selectedCategory.toLowerCase());
      if (!matchesCategory) return false;

      if (query.isEmpty) return true;
      final name = item.name.toLowerCase();
      final brand = (item.brand ?? '').toLowerCase();
      final color = item.primaryColor.toLowerCase();
      final sub = (item.subCategory ?? '').toLowerCase();
      final notes = (item.notes ?? '').toLowerCase();
      return name.contains(query) ||
          brand.contains(query) ||
          color.contains(query) ||
          sub.contains(query) ||
          notes.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<WardrobeProvider>();
    final filteredItems = _filterItems(prov.items);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (sheetContext, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: AppTypography.displaySmall.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            prov.items.isNotEmpty
                                ? '${prov.items.length} ${prov.items.length == 1 ? "garment" : "garments"} in your closet'
                                : 'Your personal closet, thoughtfully organized.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                      tooltip: 'Close Wardrobe',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search items, colors, brands...',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: AppColors.forest),
                    ),
                  ),
                ),
              ),

              // Category Selector
              _buildCategorySelector(prov),

              const Divider(height: 12, thickness: 0.8, color: AppColors.border),

              // Main Body (Loading / Error / Empty / Grid)
              Expanded(
                child: _buildSheetBody(
                  context: context,
                  prov: prov,
                  items: filteredItems,
                  scrollController: scrollController,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategorySelector(WardrobeProvider prov) {
    final categories = ['all', 'tops', 'bottoms', 'outerwear', 'footwear', 'accessories'];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, index) => const SizedBox(width: 6),
        itemBuilder: (ctx, idx) {
          final cat = categories[idx];
          final isSelected = _selectedCategory == cat;

          return ChoiceChip(
            label: Text(
              cat.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.forest,
                letterSpacing: 0.5,
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.forest,
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: isSelected ? AppColors.forest : AppColors.border,
            ),
            onSelected: (_) {
              setState(() {
                _selectedCategory = cat;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildSheetBody({
    required BuildContext context,
    required WardrobeProvider prov,
    required List<WardrobeItem> items,
    required ScrollController scrollController,
  }) {
    if (prov.isLoading && prov.items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: AppColors.forest),
            SizedBox(height: 16),
            Text(
              'Loading your wardrobe...',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (prov.error != null && prov.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 36, color: Color(0xFF9B1C1C)),
              const SizedBox(height: 12),
              Text(
                prov.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF9B1C1C)),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => prov.loadWardrobe(),
                icon: const Icon(Icons.refresh, size: 16, color: AppColors.forest),
                label: const Text('Try Again', style: TextStyle(color: AppColors.forest)),
              ),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) {
      final isFiltered = _searchController.text.isNotEmpty || _selectedCategory != 'all';
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isFiltered ? Icons.search_off : Icons.checkroom_outlined,
                size: 40,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                isFiltered
                    ? 'No matching pieces found'
                    : 'Your wardrobe is currently empty',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isFiltered
                    ? 'Try adjusting your search query or category filters.'
                    : 'Add items using the scanner to style personalized outfits.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (!isFiltered) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddWardrobeItemScreen()),
                    );
                  },
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: const Text('Scan New Garment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, idx) {
        final item = items[idx];
        return _buildItemCard(context, item);
      },
    );
  }

  Widget _buildItemCard(BuildContext context, WardrobeItem item) {
    return InkWell(
      onTap: () {
        if (widget.onItemSelected != null) {
          widget.onItemSelected!(item);
          Navigator.of(context).pop(item);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WardrobeDetailScreen(item: item),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [AppColors.subtleShadow],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PrivateImageView(
                    imageUrl: item.imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      color: AppColors.accentSoft,
                      child: const Icon(
                        Icons.checkroom,
                        color: AppColors.textMuted,
                        size: 32,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.category.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 8,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forest,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.primaryColor.isNotEmpty
                        ? '${item.primaryColor} • ${item.subCategory ?? item.category}'
                        : (item.subCategory ?? item.category),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
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
}
