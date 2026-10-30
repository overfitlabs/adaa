import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/garment_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/analysis_provider.dart';
import '../../../core/widgets/private_image_view.dart';
import '../../matching/screens/matching_result_screen.dart';
import '../../tryon/screens/tryon_screen.dart';
import '../../../core/widgets/adaa_wordmark.dart';

class AnalysisDetailScreen extends StatefulWidget {
  const AnalysisDetailScreen({super.key});

  @override
  State<AnalysisDetailScreen> createState() => _AnalysisDetailScreenState();
}

class _AnalysisDetailScreenState extends State<AnalysisDetailScreen> {
  void _editItemDialog(
    BuildContext context,
    int index,
    DetectedFashionItem item,
  ) {
    final nameController = TextEditingController(text: item.name);
    final categoryController = TextEditingController(text: item.category);
    final colorController = TextEditingController(text: item.primaryColor);
    final materialController = TextEditingController(
      text: item.attributes.material ?? '',
    );
    final fitController = TextEditingController(
      text: item.attributes.fit ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Edit Garment Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category (e.g. jackets, tops, jeans)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(labelText: 'Primary Color'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: materialController,
                decoration: const InputDecoration(
                  labelText: 'Material (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fitController,
                decoration: const InputDecoration(
                  labelText: 'Fit / Silhouette (optional)',
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
              final updated = DetectedFashionItem(
                id: item.id,
                category: categoryController.text.trim().toLowerCase(),
                subCategory: item.subCategory,
                name: nameController.text.trim(),
                primaryColor: colorController.text.trim(),
                secondaryColor: item.secondaryColor,
                attributes: StyleAttributes(
                  material: materialController.text.trim().isEmpty
                      ? null
                      : materialController.text.trim(),
                  fit: fitController.text.trim().isEmpty
                      ? null
                      : fitController.text.trim(),
                  pattern: item.attributes.pattern,
                  formality: item.attributes.formality,
                  season: item.attributes.season,
                  necklineOrCollar: item.attributes.necklineOrCollar,
                ),
                confidence: item.confidence,
                boundingBoxDescription: item.boundingBoxDescription,
              );
              context.read<AnalysisProvider>().updateDetectedItem(
                index,
                updated,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Save Details'),
          ),
        ],
      ),
    );
  }

  Future<void> _runMatching() async {
    final prov = context.read<AnalysisProvider>();
    final success = await prov.matchAgainstWardrobe();
    if (success && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MatchingResultScreen()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(prov.error ?? 'Failed to match against wardrobe.'),
          backgroundColor: AppColors.missing,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AnalysisProvider>();
    final analysis = prov.currentAnalysis;

    if (analysis == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analysis')),
        body: const Center(child: Text('No outfit analysis found.')),
      );
    }

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsetsGeometry.fromLTRB(20, 0, 20, 0),
              child: const Text(
                'Outfit Analysis',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 32,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forest,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: EdgeInsetsGeometry.fromLTRB(20, 0, 20, 0),
              child: Text(
                "The looks really good! Can't wait to see you in this",
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Inspiration Image Banner
            AspectRatio(
              aspectRatio: 1.0,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PrivateImageView(
                    imageUrl: analysis.imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: AppColors.accentSoft,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: Container(
                      color: AppColors.accentSoft,
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined, size: 40),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        analysis.vibeOrStyle.isNotEmpty
                            ? analysis.vibeOrStyle
                            : 'Curated Look',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Summary Card
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${analysis.detectedGarmentCount} Fashion Pieces Identified',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    analysis.summary,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Garment Item Cards
                  const Text(
                    'DETECTED GARMENTS & ACCESSORIES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: analysis.items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) {
                      final item = analysis.items[idx];
                      return _buildItemCard(ctx, idx, item);
                    },
                  ),

                  const SizedBox(height: 28),

                  // Match Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: prov.isMatching ? null : _runMatching,
                      icon: prov.isMatching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.compare_arrows_rounded),
                      label: Text(
                        prov.isMatching
                            ? 'Matching Against Closet...'
                            : 'Match With My Wardrobe',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TryOnScreen(
                              prefilledInspirationUrl: analysis.imageUrl,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.face_retouching_natural_outlined,
                        size: 18,
                      ),
                      label: const Text('Try this outfit'),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    int index,
    DetectedFashionItem item,
  ) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 52,
                  height: 52,
                  color: AppColors.surfaceContainerLow,
                  child: item.extractedImageUrl != null
                      ? PrivateImageView(
                          imageUrl: item.extractedImageUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.contain,
                          backgroundColor: AppColors.surfaceContainerLow,
                        )
                      : Icon(
                          _getCategoryIcon(item.category),
                          color: AppColors.primary,
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subCategory ?? item.category.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Edit details',
                onPressed: () => _editItemDialog(context, index, item),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),

          // Attributes Badges
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildBadge('Color', item.primaryColor, Icons.palette_outlined),
              if (item.attributes.material != null)
                _buildBadge(
                  'Fabric',
                  item.attributes.material!,
                  Icons.texture_outlined,
                ),
              if (item.attributes.pattern != null)
                _buildBadge(
                  'Pattern',
                  item.attributes.pattern!,
                  Icons.grid_view_outlined,
                ),
              if (item.attributes.fit != null)
                _buildBadge(
                  'Fit',
                  item.attributes.fit!,
                  Icons.straighten_outlined,
                ),
              if (item.attributes.formality != null)
                _buildBadge(
                  'Style',
                  item.attributes.formality!,
                  Icons.stars_outlined,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('jacket') ||
        cat.contains('coat') ||
        cat.contains('blazer')) {
      return Icons.dry_cleaning_outlined;
    } else if (cat.contains('jean') ||
        cat.contains('trouser') ||
        cat.contains('pant')) {
      return Icons.airline_seat_legroom_extra_outlined;
    } else if (cat.contains('shoe') ||
        cat.contains('footwear') ||
        cat.contains('boot')) {
      return Icons.roller_skating_outlined;
    } else if (cat.contains('bag')) {
      return Icons.shopping_bag_outlined;
    } else if (cat.contains('watch')) {
      return Icons.watch_outlined;
    } else if (cat.contains('sunglass') || cat.contains('glass')) {
      return Icons.visibility_outlined;
    }
    return Icons.checkroom_outlined;
  }
}
