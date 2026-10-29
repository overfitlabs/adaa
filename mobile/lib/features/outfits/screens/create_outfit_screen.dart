import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/private_image_view.dart';
import '../../../state/outfits_provider.dart';
import '../../../state/wardrobe_provider.dart';
import '../../../core/widgets/adaa_wordmark.dart';

class CreateOutfitScreen extends StatefulWidget {
  const CreateOutfitScreen({super.key});

  @override
  State<CreateOutfitScreen> createState() => _CreateOutfitScreenState();
}

class _CreateOutfitScreenState extends State<CreateOutfitScreen> {
  final _nameController = TextEditingController();
  final _occasionController = TextEditingController(text: 'Casual');
  final _notesController = TextEditingController();
  final Set<String> _selectedItemIds = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WardrobeProvider>().loadWardrobe(silent: true);
    });
  }

  Future<void> _submitOutfit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please name this outfit look.'),
          backgroundColor: AppColors.missing,
        ),
      );
      return;
    }

    if (_selectedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select at least one garment from your wardrobe.',
          ),
          backgroundColor: AppColors.missing,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final prov = context.read<OutfitsProvider>();
    final success = await prov.saveOutfit(
      name: name,
      occasion: _occasionController.text.trim(),
      notes: _notesController.text.trim(),
      itemIds: _selectedItemIds.toList(),
    );
    setState(() => _isSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Outfit saved to collection!'),
          backgroundColor: AppColors.exactMatch,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(prov.error ?? 'Failed to save outfit.'),
          backgroundColor: AppColors.missing,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeProvider>();

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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'create_outfit_fab',
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        onPressed: _isSaving ? null : _submitOutfit,
        icon: Icon(Icons.bookmark_outline),
        label: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assemble Look',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 28,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Look Title *',
                hintText: 'e.g. Minimalist Autumn Monday',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _occasionController,
              decoration: const InputDecoration(
                labelText: 'Occasion',
                hintText: 'e.g. Work, Dinner, Weekend',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Styling Notes',
                hintText: 'e.g. Leave coat open, wear silver watch',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SELECT CLOSET PIECES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${_selectedItemIds.length} selected',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (wardrobe.items.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'No clothes in wardrobe. Add pieces to your wardrobe first to assemble looks.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: wardrobe.items.length,
                itemBuilder: (ctx, idx) {
                  final item = wardrobe.items[idx];
                  final isSelected = _selectedItemIds.contains(item.id);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedItemIds.remove(item.id);
                        } else {
                          _selectedItemIds.add(item.id);
                        }
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              color: AppColors.surfaceContainerLow,
                              child: PrivateImageView(
                                imageUrl: item.imageUrl,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.contain,
                                backgroundColor: AppColors.surfaceContainerLow,
                                errorWidget: Container(
                                  color: AppColors.accentSoft,
                                  child: const Icon(Icons.checkroom, size: 24),
                                ),
                              ),
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
