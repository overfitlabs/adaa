import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/saved_outfit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/private_image_view.dart';
import '../../../state/outfits_provider.dart';
import 'create_outfit_screen.dart';

class OutfitsScreen extends StatefulWidget {
  const OutfitsScreen({super.key});

  @override
  State<OutfitsScreen> createState() => _OutfitsScreenState();
}

class _OutfitsScreenState extends State<OutfitsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OutfitsProvider>().loadOutfits();
    });
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Outfits & Looks'),
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
      body: prov.isLoading && prov.outfits.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : prov.outfits.isEmpty
              ? _buildEmptyState(context)
              : RefreshIndicator(
                  onRefresh: () => prov.loadOutfits(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: prov.outfits.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (ctx, idx) {
                      final outfit = prov.outfits[idx];
                      return _buildOutfitCard(ctx, outfit);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.checkroom),
        label: const Text('Build New Look', style: TextStyle(fontWeight: FontWeight.w600)),
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
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (outfit.occasion != null && outfit.occasion!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          outfit.occasion!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textMuted),
                onPressed: () => _confirmDelete(context, outfit),
              ),
            ],
          ),

          if (outfit.notes != null && outfit.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              outfit.notes!,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 14),

          // Horizontal row of garment thumbnails
          if (outfit.items.isNotEmpty) ...[
            Text(
              '${outfit.items.length} PIECES IN THIS LOOK',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: AppColors.textSecondary,
              ),
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
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: PrivateImageView(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          color: AppColors.accentSoft,
                          child: const Icon(Icons.checkroom, size: 18),
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
                color: AppColors.accentSoft,
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
