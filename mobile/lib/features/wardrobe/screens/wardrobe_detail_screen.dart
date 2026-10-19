import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/wardrobe_item.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/wardrobe_provider.dart';
import '../../tryon/screens/tryon_screen.dart';

class WardrobeDetailScreen extends StatelessWidget {
  final WardrobeItem item;

  const WardrobeDetailScreen({super.key, required this.item});

  void _showEditDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: item.name);
    final colorCtrl = TextEditingController(text: item.primaryColor);
    final materialCtrl = TextEditingController(text: item.material ?? '');
    final fitCtrl = TextEditingController(text: item.fit ?? '');
    final seasonCtrl = TextEditingController(text: item.season ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Garment Details', style: TextStyle(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: colorCtrl,
                decoration: const InputDecoration(labelText: 'Color'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: materialCtrl,
                decoration: const InputDecoration(labelText: 'Material'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fitCtrl,
                decoration: const InputDecoration(labelText: 'Fit'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: seasonCtrl,
                decoration: const InputDecoration(labelText: 'Season'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final prov = context.read<WardrobeProvider>();
              final updates = <String, dynamic>{
                'name': nameCtrl.text.trim(),
                'primary_color': colorCtrl.text.trim(),
                'material': materialCtrl.text.trim().isEmpty ? null : materialCtrl.text.trim(),
                'fit': fitCtrl.text.trim().isEmpty ? null : fitCtrl.text.trim(),
                'season': seasonCtrl.text.trim().isEmpty ? null : seasonCtrl.text.trim(),
              };
              final success = await prov.updateItem(item.id, updates);
              if (ctx.mounted) Navigator.pop(ctx);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Garment details updated.'),
                    backgroundColor: AppColors.exactMatch,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove from Wardrobe?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to remove "${item.name}" from your digital closet?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.missing),
            onPressed: () async {
              final prov = context.read<WardrobeProvider>();
              await prov.deleteItem(item.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Garment removed from wardrobe.'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
            child: const Text('Remove Piece', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => _showEditDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.missing),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Garment Image
            Image.network(
              ApiEndpoints.resolveImageUrl(item.imageUrl),
              width: double.infinity,
              height: 340,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 240,
                color: AppColors.accentSoft,
                child: const Center(child: Icon(Icons.checkroom, size: 50, color: AppColors.textMuted)),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.category.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      if (item.subCategory != null)
                        Text(
                          item.subCategory!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Attribute Matrix
                  const Text(
                    'GARMENT SPECIFICATIONS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _buildSpecRow('Primary Shade', item.primaryColor),
                        if (item.secondaryColor != null)
                          _buildSpecRow('Secondary Shade', item.secondaryColor!),
                        _buildSpecRow('Fabric / Material', item.material ?? 'Not specified'),
                        _buildSpecRow('Cut / Fit', item.fit ?? 'Regular'),
                        _buildSpecRow('Pattern', item.pattern ?? 'Solid'),
                        _buildSpecRow('Formality', item.formality ?? 'Versatile'),
                        _buildSpecRow('Seasonality', item.season ?? 'All-Season'),
                      ],
                    ),
                  ),

                  if (item.tags.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'STYLE TAGS',
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
                      runSpacing: 8,
                      children: item.tags.map((t) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '#$t',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Virtual Try-On this piece
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TryOnScreen(prefilledWardrobeItemId: item.id),
                          ),
                        );
                      },
                      icon: const Icon(Icons.face_retouching_natural_outlined),
                      label: const Text('Try On This Garment with YouCam AI'),
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

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
