import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/outfit_match.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/analysis_provider.dart';
import '../../../state/outfits_provider.dart';
import '../../../core/widgets/private_image_view.dart';
import '../../outfits/screens/outfits_screen.dart';

class MatchingResultScreen extends StatelessWidget {
  const MatchingResultScreen({super.key});

  void _saveMatchedOutfitDialog(BuildContext context, OutfitMatchResponse matchResult) {
    final matchedItemIds = matchResult.itemMatches
        .where((m) => m.bestMatch != null)
        .map((m) => m.bestMatch!.wardrobeItem.id)
        .toList();

    if (matchedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot save outfit: No wardrobe items matched yet.'),
          backgroundColor: AppColors.missing,
        ),
      );
      return;
    }

    final nameController = TextEditingController(text: 'Matched Capsule Look');
    final occasionController = TextEditingController(text: 'Smart Casual');
    final notesController = TextEditingController(
      text: 'Matched from outfit analysis. Completeness: ${matchResult.completenessPercentage}%',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Save Outfit to Collection', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Look Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: occasionController,
              decoration: const InputDecoration(labelText: 'Occasion / Setting'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Styling Notes'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final prov = context.read<OutfitsProvider>();
              final success = await prov.saveOutfit(
                name: nameController.text.trim(),
                occasion: occasionController.text.trim(),
                notes: notesController.text.trim(),
                itemIds: matchedItemIds,
                inspirationAnalysisId: matchResult.analysisId,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Look successfully saved to your collection!'),
                    backgroundColor: AppColors.exactMatch,
                  ),
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OutfitsScreen()),
                );
              }
            },
            child: const Text('Save Look'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AnalysisProvider>();
    final matchResult = prov.currentMatchResult;

    if (matchResult == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wardrobe Match')),
        body: const Center(child: Text('No match result available.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Closet Match Results'),
        actions: [
          IconButton(
            tooltip: 'Save Look',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: () => _saveMatchedOutfitDialog(context, matchResult),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Completeness Banner
            _buildCompletenessBanner(matchResult),

            const SizedBox(height: 24),

            // Item-by-item comparison breakdown
            const Text(
              'GARMENT MATCH BREAKDOWN',
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
              itemCount: matchResult.itemMatches.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (ctx, idx) {
                final match = matchResult.itemMatches[idx];
                return _buildMatchTile(ctx, match);
              },
            ),

            const SizedBox(height: 28),

            // Action Button to Save Look
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _saveMatchedOutfitDialog(context, matchResult),
                icon: const Icon(Icons.checkroom_outlined),
                label: const Text('Save Combination As Look'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletenessBanner(OutfitMatchResponse match) {
    final pct = match.completenessPercentage;
    final color = pct >= 80
        ? AppColors.exactMatch
        : pct >= 40
            ? AppColors.approxMatch
            : AppColors.missing;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: pct / 100.0,
                  strokeWidth: 6,
                  color: color,
                  backgroundColor: AppColors.borderLight,
                ),
              ),
              Text(
                '${pct.toInt()}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pct >= 80
                      ? 'Closet Replicable'
                      : pct >= 40
                          ? 'Partial Match'
                          : 'Pieces Missing',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${match.matchedCount} of ${match.totalOutfitItems} pieces matched in your wardrobe.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchTile(BuildContext context, ItemMatchResult match) {
    final isExact = match.status == 'exact_match';
    final isApprox = match.status == 'approximate_match';
    final isMissing = match.status == 'missing';

    final statusColor = isExact
        ? AppColors.exactMatch
        : isApprox
            ? AppColors.approxMatch
            : AppColors.missing;

    final statusLabel = isExact
        ? 'EXACT MATCH'
        : isApprox
            ? 'APPROXIMATE'
            : 'MISSING PIECE';

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
          // Header: Target Inspiration Item + Match Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.targetItem.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${match.targetItem.primaryColor} • ${match.targetItem.category.toUpperCase()}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 14),

          // Closest Match Piece in User's Wardrobe
          if (isMissing || match.bestMatch == null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No matching ${match.targetItem.category} in ${match.targetItem.primaryColor} found in your wardrobe.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: PrivateImageView(
                    imageUrl: match.bestMatch!.wardrobeItem.imageUrl,
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      width: 54,
                      height: 54,
                      color: AppColors.accentSoft,
                      child: const Icon(Icons.checkroom, color: AppColors.textMuted),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              match.bestMatch!.wardrobeItem.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${(match.bestMatch!.overallScore * 100).toInt()}% Match',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your closet item (${match.bestMatch!.wardrobeItem.primaryColor})',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      if (match.bestMatch!.matchReasons.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          match.bestMatch!.matchReasons.join(' • '),
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Alternatives if any
            if (match.alternatives.isNotEmpty) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 8),
                title: Text(
                  '${match.alternatives.length} other closet alternative(s)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                children: match.alternatives.map((alt) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: PrivateImageView(
                            imageUrl: alt.wardrobeItem.imageUrl,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorWidget: Container(
                              width: 36,
                              height: 36,
                              color: AppColors.accentSoft,
                              child: const Icon(Icons.checkroom, size: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            alt.wardrobeItem.name,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          '${(alt.overallScore * 100).toInt()}%',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
