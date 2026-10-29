import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/recommended_outfit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/private_image_view.dart';
import '../../../state/outfits_provider.dart';
import '../../../state/stylist_provider.dart';
import '../../outfits/screens/outfits_screen.dart';
import '../../wardrobe/screens/wardrobe_detail_screen.dart';
import '../../../core/widgets/adaa_wordmark.dart';

class RecommendationsScreen extends StatefulWidget {
  final bool autoGenerate;
  final String? initialOccasion;

  const RecommendationsScreen({
    super.key,
    this.autoGenerate = true,
    this.initialOccasion,
  });

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final TextEditingController _instructionsController = TextEditingController();
  bool _showFilters = false;

  static const List<String> _occasions = [
    'Everyday',
    'Smart Casual',
    'Casual Weekend',
    'Formal',
    'Work',
    'Date Night',
    'Athletic',
    'Party',
    'Weekend Brunch',
    'Boardroom Polish',
    'Cocktail Hour',
    'Airport Layering',
  ];

  static const List<String> _vibes = [
    'Minimalist',
    'Streetwear',
    'Classic',
    'Monochromatic',
    'Vintage',
    'Preppy',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stylist = context.read<StylistProvider>();
      if (widget.initialOccasion != null &&
          widget.initialOccasion!.isNotEmpty) {
        stylist.setOccasion(widget.initialOccasion!);
      }
      _instructionsController.text = stylist.customInstructions;
      if (widget.autoGenerate && stylist.outfits.isEmpty) {
        stylist.generateOutfits();
      }
    });
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  void _onGenerate(StylistProvider stylist) {
    FocusScope.of(context).unfocus();
    stylist.setCustomInstructions(_instructionsController.text);
    stylist.generateOutfits(isRefinement: false);
  }

  void _onRefine(StylistProvider stylist) {
    FocusScope.of(context).unfocus();
    stylist.setCustomInstructions(_instructionsController.text);
    stylist.generateOutfits(isRefinement: true);
  }

  void _showInspectOutfitSheet(BuildContext context, RecommendedOutfit outfit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (sheetCtx, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              outfit.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${outfit.items.length} items • ${outfit.occasion} • ${outfit.vibe}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.borderLight),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: outfit.items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (itemCtx, i) {
                      final item = outfit.items[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 70,
                                height: 70,
                                child: PrivateImageView(
                                  imageUrl: item.imageUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: Container(
                                    color: AppColors.accentSoft,
                                    child: const Icon(
                                      Icons.checkroom,
                                      color: AppColors.primary,
                                    ),
                                  ),
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
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.category.toUpperCase()} • ${item.primaryColor.toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (item.brand != null &&
                                      item.brand!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Brand: ${item.brand}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.accent,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.open_in_new,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              tooltip: 'View in Closet',
                              onPressed: () {
                                Navigator.pop(sheetCtx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        WardrobeDetailScreen(item: item),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final stylist = context.watch<StylistProvider>();
    final outfitsProv = context.watch<OutfitsProvider>();

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
          IconButton(
            icon: const Icon(Icons.tune_outlined, size: 22),
            tooltip: 'Styling Filters',
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_outline, size: 22),
            tooltip: 'Saved Looks',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OutfitsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => stylist.generateOutfits(isRefinement: false),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            // Controls & Styling Filter Card
            _buildStylistControls(stylist),

            const SizedBox(height: 20),

            // Content Area
            if (stylist.isLoading)
              _buildLoadingState()
            else if (stylist.error != null)
              _buildErrorState(stylist)
            else if (stylist.generationResponse != null &&
                stylist.generationResponse!.isEmptyWardrobe)
              _buildEmptyWardrobeState()
            else if (stylist.generationResponse != null &&
                stylist.generationResponse!.isInsufficientItems)
              _buildInsufficientItemsState(stylist.generationResponse!)
            else if (stylist.outfits.isEmpty)
              _buildNoOutfitsState(stylist)
            else ...[
              _buildResultsHeader(stylist),
              const SizedBox(height: 16),
              ...stylist.outfits.map(
                (outfit) =>
                    _buildOutfitCard(context, outfit, stylist, outfitsProv),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStylistControls(StylistProvider stylist) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'AI Outfit Generator',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => setState(() => _showFilters = !_showFilters),
                child: Text(
                  _showFilters ? 'Hide Options' : 'Custom Vibe',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Occasion Chips
          const Text(
            'OCCASION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _occasions.map((occ) {
                final isSelected = stylist.selectedOccasion == occ;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(occ),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) stylist.setOccasion(occ);
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                    backgroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          if (_showFilters) ...[
            const SizedBox(height: 14),
            const Text(
              'AESTHETIC VIBE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Any Vibe'),
                      selected: stylist.selectedVibe == null,
                      onSelected: (val) {
                        if (val) stylist.setVibe(null);
                      },
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: stylist.selectedVibe == null
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                      backgroundColor: AppColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  ..._vibes.map((v) {
                    final isSelected = stylist.selectedVibe == v;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(v),
                        selected: isSelected,
                        onSelected: (val) {
                          stylist.setVibe(val ? v : null);
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                        backgroundColor: AppColors.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Custom instructions input
            TextField(
              controller: _instructionsController,
              decoration: InputDecoration(
                hintText: 'e.g. emphasize navy, warm layers, sneakers...',
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
                prefixIcon: const Icon(
                  Icons.edit_note,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: _instructionsController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _instructionsController.clear();
                          stylist.setCustomInstructions('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (val) => stylist.setCustomInstructions(val),
              onSubmitted: (_) => _onGenerate(stylist),
            ),
          ],

          const SizedBox(height: 16),

          // Actions Row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: stylist.isLoading
                      ? null
                      : () => _onGenerate(stylist),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text(
                    'Generate Looks',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (stylist.outfits.isNotEmpty) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: stylist.isLoading
                      ? null
                      : () => _onRefine(stylist),
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text(
                    'Alternatives',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsHeader(StylistProvider stylist) {
    final resp = stylist.generationResponse;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${stylist.selectedOccasion.toUpperCase()} LOOKS',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: AppColors.primary,
              ),
            ),
            if (resp != null && resp.appliedProfilePreferences.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  resp.appliedProfilePreferences.join(' • '),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${stylist.outfits.length} combinations',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOutfitCard(
    BuildContext context,
    RecommendedOutfit outfit,
    StylistProvider stylist,
    OutfitsProvider outfitsProv,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        outfit.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              outfit.occasion.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              outfit.vibe,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.exactMatch.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified,
                        size: 14,
                        color: AppColors.exactMatch,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${outfit.matchPercentage}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.exactMatch,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Horizontal Garment Thumbnails
          SizedBox(
            height: 120,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: outfit.items.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final item = outfit.items[i];
                return InkWell(
                  onTap: () => _showInspectOutfitSheet(context, outfit),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 90,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 1.0,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(13),
                            ),
                            child: Container(
                              color: AppColors.surfaceContainerLow,
                              width: double.infinity,
                              child: PrivateImageView(
                                imageUrl: item.imageUrl,
                                fit: BoxFit.contain,
                                backgroundColor: AppColors.surfaceContainerLow,
                                errorWidget: Container(
                                  color: AppColors.accentSoft,
                                  child: const Icon(
                                    Icons.checkroom,
                                    size: 24,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                item.category,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 9,
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
              },
            ),
          ),

          // Why this works explanation
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 14,
                        color: AppColors.accent,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'WHY THIS LOOK WORKS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    outfit.explanation,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Styling Tips (bulleted)
          if (outfit.stylingTips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: outfit.stylingTips.map((tip) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            tip,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          const Divider(height: 16, color: AppColors.borderLight),

          // Bottom Action Row (Save / Saved & Inspect)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => _showInspectOutfitSheet(context, outfit),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text(
                    'Inspect Pieces',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final success = await stylist.toggleSaveOutfit(
                      outfit,
                      outfitsProv,
                    );
                    if (context.mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            outfit.isSaved
                                ? 'Look saved to your collection!'
                                : 'Look removed from saved.',
                          ),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    outfit.isSaved ? Icons.bookmark : Icons.bookmark_border,
                    size: 16,
                  ),
                  label: Text(
                    outfit.isSaved ? 'Saved' : 'Save Look',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: outfit.isSaved
                        ? AppColors.terracotta
                        : AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 20),
            const Text(
              'Curating your wardrobe combinations...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Evaluating color harmonies and occasion compatibility',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(StylistProvider stylist) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.missing.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 40, color: AppColors.missing),
          const SizedBox(height: 12),
          Text(
            stylist.error ?? 'Failed to generate recommendations.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => stylist.generateOutfits(),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWardrobeState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: AppColors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.checkroom_outlined,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your wardrobe is empty',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start by uploading foundational garments like a clean tee, trousers, and sneakers to unlock AI styled looks.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsufficientItemsState(OutfitGenerationResponse resp) {
    final missing = resp.missingCategories.join(', ');
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.layers_clear_outlined,
              size: 40,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'More Garments Needed',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Add at least one top and one bottom to unlock complete styled combinations. Missing: ${missing.isNotEmpty ? missing : "compatible pairs"}.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoOutfitsState(StylistProvider stylist) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(
              Icons.style_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 14),
            const Text(
              'Ready to style your look',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select an occasion and tap "Generate Looks" to curate recommendations.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => stylist.generateOutfits(),
              child: const Text('Generate Now'),
            ),
          ],
        ),
      ),
    );
  }
}
