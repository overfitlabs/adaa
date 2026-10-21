import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/saved_outfit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/private_image_view.dart';
import '../../../state/outfits_provider.dart';
import '../../tryon/screens/tryon_screen.dart';
import 'create_outfit_screen.dart';

class OutfitsScreen extends StatefulWidget {
  const OutfitsScreen({super.key});

  @override
  State<OutfitsScreen> createState() => _OutfitsScreenState();
}

class _OutfitsScreenState extends State<OutfitsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedOccasion = 'all';

  final List<String> _occasions = const [
    'all',
    'workwear',
    'weekend',
    'dinner',
    'casual',
    'vacation',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OutfitsProvider>().loadOutfits();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDelete(BuildContext context, SavedOutfit outfit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Saved Look?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete "${outfit.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.missing),
            onPressed: () async {
              await context.read<OutfitsProvider>().deleteOutfit(outfit.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<OutfitsProvider>();

    final query = _searchController.text.toLowerCase().trim();
    final filteredOutfits = prov.outfits.where((outfit) {
      final matchesQuery = query.isEmpty ||
          outfit.name.toLowerCase().contains(query) ||
          (outfit.occasion?.toLowerCase().contains(query) ?? false) ||
          (outfit.notes?.toLowerCase().contains(query) ?? false);
      final matchesOccasion = _selectedOccasion == 'all' ||
          (outfit.occasion?.toLowerCase().contains(_selectedOccasion) ?? false);
      return matchesQuery && matchesOccasion;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Saved Outfits & Looks', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text(
              '${prov.outfits.length} ${prov.outfits.length == 1 ? "look" : "looks"} curated',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Create Look',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateOutfitScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search saved looks, tags, or pieces...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() => _searchController.clear());
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (_) => setState(() {}),
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
                    tooltip: 'Filter looks',
                    onPressed: () {
                      setState(() => _selectedOccasion = 'all');
                    },
                  ),
                ),
              ],
            ),
          ),

          // Occasion Pill Filter Carousel
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _occasions.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (ctx, idx) {
                final occ = _occasions[idx];
                final isSelected = _selectedOccasion == occ;
                final label = occ == 'all'
                    ? 'All (${prov.outfits.length})'
                    : '${occ[0].toUpperCase()}${occ.substring(1)}';

                return ChoiceChip(
                  label: Text(
                    label,
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
                  onSelected: (_) => setState(() => _selectedOccasion = occ),
                );
              },
            ),
          ),

          // Editorial Sub-Bar with Summary & AI Sparkle Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'SAVED LOOKS',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.forest,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${filteredOutfits.length} CURATIONS',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.sandSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 12, color: AppColors.gold),
                      const SizedBox(width: 4),
                      Text(
                        'AI Styled',
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 10,
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Outfits List
          Expanded(
            child: prov.isLoading && prov.outfits.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filteredOutfits.isEmpty
                    ? _buildEmptyState(context)
                    : RefreshIndicator(
                        onRefresh: () => prov.loadOutfits(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredOutfits.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 14),
                          itemBuilder: (ctx, idx) {
                            final outfit = filteredOutfits[idx];
                            return _buildOutfitCard(ctx, outfit);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.checkroom, color: AppColors.gold),
        label: const Text('Build New Look', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateOutfitScreen()),
          );
        },
      ),
    );
  }

  Widget _buildOutfitCard(BuildContext context, SavedOutfit outfit) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppColors.subtleShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outfit.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                    if (outfit.occasion != null && outfit.occasion!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.sageContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            outfit.occasion!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textMuted),
                tooltip: 'Delete look',
                onPressed: () => _confirmDelete(context, outfit),
              ),
            ],
          ),

          if (outfit.notes != null && outfit.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              outfit.notes!,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),

          // Horizontal row of garment thumbnails
          if (outfit.items.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.checkroom, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${outfit.items.length} PIECES IN THIS LOOK',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    final firstItemId = outfit.items.firstOrNull?.id;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TryOnScreen(
                          prefilledWardrobeItemId: firstItemId,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Try on',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.arrow_forward, size: 12, color: AppColors.forest),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: outfit.items.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final item = outfit.items[i];
                  return Container(
                    width: 60,
                    decoration: BoxDecoration(
                      color: AppColors.sandSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: PrivateImageView(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          color: AppColors.sandSoft,
                          child: const Icon(Icons.checkroom, size: 18, color: AppColors.forest),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            Text(
              '${outfit.itemIds.length} items linked',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.sandSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_mosaic_outlined, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Saved Outfits Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Assemble combinations from your wardrobe or save matched outfits from your analyses.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateOutfitScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Assemble a Look'),
            ),
          ],
        ),
      ),
    );
  }
}
