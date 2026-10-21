import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/wardrobe_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/wardrobe_provider.dart';
import '../../../core/widgets/private_image_view.dart';
import 'add_wardrobe_item_screen.dart';
import 'wardrobe_detail_screen.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WardrobeProvider>().loadWardrobe();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<WardrobeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Digital Wardrobe', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text(
              prov.items.isNotEmpty
                  ? '${prov.items.length} ${prov.items.length == 1 ? "garment" : "garments"} in closet'
                  : 'Personal closet & garment manager',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo_outlined),
            tooltip: 'Add Garment',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddWardrobeItemScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by title, brand, fabric, color, or notes...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                prov.setSearchQuery('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (val) => prov.setSearchQuery(val),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.tune, size: 20, color: AppColors.forest),
                    tooltip: 'Filter options',
                    onPressed: () {
                      if (prov.selectedCategory != 'all') {
                        prov.setCategory('all');
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Category Chips Bar
          _buildCategoryChips(prov),

          const SizedBox(height: 6),

          // Active filter & count summary bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 14, color: AppColors.gold),
                    const SizedBox(width: 6),
                    Text(
                      prov.selectedCategory == 'all'
                          ? 'ALL GARMENTS (${prov.items.length})'
                          : '${prov.selectedCategory.toUpperCase()} (${prov.items.length})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (prov.isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Content Area (Loading, Error, Empty, or Grid)
          Expanded(
            child: _buildBodyContent(context, prov),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, color: AppColors.gold),
        label: const Text('Add Piece', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddWardrobeItemScreen()),
          );
        },
      ),
    );
  }

  Widget _buildBodyContent(BuildContext context, WardrobeProvider prov) {
    if (prov.isLoading && prov.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (prov.error != null && prov.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.missing),
              const SizedBox(height: 12),
              const Text(
                'Unable to Load Wardrobe',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                prov.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => prov.loadWardrobe(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (prov.items.isEmpty) {
      return _buildEmptyState(context, prov);
    }

    return RefreshIndicator(
      onRefresh: () => prov.loadWardrobe(),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: prov.items.length,
        itemBuilder: (ctx, idx) {
          final item = prov.items[idx];
          return _buildWardrobeGridTile(context, item);
        },
      ),
    );
  }

  Widget _buildCategoryChips(WardrobeProvider prov) {
    final categories = [
      {'category': 'all', 'count': prov.items.length},
      ...prov.categories,
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (ctx, idx) {
          final cat = categories[idx]['category'].toString();
          final count = categories[idx]['count'] ?? 0;
          final isSelected = prov.selectedCategory.toLowerCase() == cat.toLowerCase();

          return ChoiceChip(
            label: Text(
              '${cat.toUpperCase()} ($count)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
            onSelected: (_) => prov.setCategory(cat),
          );
        },
      ),
    );
  }

  Widget _buildWardrobeGridTile(BuildContext context, WardrobeItem item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WardrobeDetailScreen(item: item),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [AppColors.subtleShadow],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: AppColors.sandSoft,
                  child: Stack(
                    children: [
                      PrivateImageView(
                        imageUrl: item.imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        onRefreshUrl: () => context.read<WardrobeProvider>().loadWardrobe(),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.88),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite_border,
                            size: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.category.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.brand != null && item.brand!.isNotEmpty
                        ? '${item.primaryColor} • ${item.brand}'
                        : '${item.primaryColor} • ${item.material ?? item.fit ?? 'Garment'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WardrobeProvider prov) {
    final bool hasFilter = _searchController.text.isNotEmpty || prov.selectedCategory != 'all';

    if (hasFilter) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_outlined, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              const Text(
                'No matching garments',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'No items found matching your current filter criteria.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  prov.setSearchQuery('');
                  prov.setCategory('all');
                },
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Reset Filters'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.terracottaSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.checkroom_outlined, size: 48, color: AppColors.terracotta),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Wardrobe is Empty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Take photos of your garments or flat-lays. adaa AI will detect categories, colors, and materials automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddWardrobeItemScreen()),
                );
              },
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Add Your First Piece'),
            ),
          ],
        ),
      ),
    );
  }
}
