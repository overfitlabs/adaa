import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/models/tryon_task.dart';
import '../../../core/models/wardrobe_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaa_wordmark.dart';
import '../../../core/widgets/private_image_view.dart';
import '../../../state/outfits_provider.dart';
import '../../../state/tryon_provider.dart';
import '../../../state/wardrobe_provider.dart';

class TryOnScreen extends StatefulWidget {
  final String? prefilledInspirationUrl;
  final String? prefilledWardrobeItemId;

  const TryOnScreen({
    super.key,
    this.prefilledInspirationUrl,
    this.prefilledWardrobeItemId,
  });

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> {
  static const Color _background = Color(0xFFFCF9F4);
  static const Color _primary = Color(0xFF082217);
  static const Color _secondary = Color(0xFF456651);
  static const Color _surfaceLow = Color(0xFFF6F3EE);
  static const Color _gold = Color(0xFFC89142);

  final ImagePicker _picker = ImagePicker();

  XFile? _userImage;
  XFile? _garmentImage;
  String? _selectedWardrobeItemId;
  WardrobeItem? _selectedWardrobeItem;
  String _selectedCategory = 'upper body';
  bool _useWardrobeItem = true;
  bool _isSavingOutfit = false;
  int _selectedTab = 0; // 0: Studio, 1: History

  final List<Map<String, String>> _categories = [
    {'label': 'Tops / Upper', 'value': 'upper body'},
    {'label': 'Pants / Lower', 'value': 'lower body'},
    {'label': 'Dress / Full', 'value': 'dress'},
    {'label': 'Jackets / Outer', 'value': 'outer'},
    {'label': 'Footwear', 'value': 'shoes'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wardrobe = context.read<WardrobeProvider>();
      if (wardrobe.items.isEmpty && !wardrobe.isLoading) {
        wardrobe.loadWardrobe(silent: true);
      }
      context.read<TryOnProvider>().loadDefaultModel();
      _applyPrefills();
    });
  }

  void _applyPrefills() {
    if (widget.prefilledWardrobeItemId != null) {
      final wardrobe = context.read<WardrobeProvider>();
      final match = wardrobe.items
          .where((i) => i.id == widget.prefilledWardrobeItemId)
          .firstOrNull;
      setState(() {
        _useWardrobeItem = true;
        _selectedWardrobeItemId = widget.prefilledWardrobeItemId;
        _selectedWardrobeItem = match;
        if (match != null) {
          final cat = match.category.toLowerCase();
          if (cat.contains('outer') ||
              cat.contains('jacket') ||
              cat.contains('coat')) {
            _selectedCategory = 'outer';
          } else if (cat.contains('bottom') ||
              cat.contains('pant') ||
              cat.contains('jean')) {
            _selectedCategory = 'lower body';
          } else if (cat.contains('dress') || cat.contains('suit')) {
            _selectedCategory = 'dress';
          } else if (cat.contains('shoe') ||
              cat.contains('boot') ||
              cat.contains('sneaker')) {
            _selectedCategory = 'shoes';
          } else {
            _selectedCategory = 'upper body';
          }
        }
      });
    }
  }

  Future<void> _pickUserImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 2000,
        imageQuality: 88,
      );
      if (picked != null) {
        setState(() => _userImage = picked);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not access image: $e')));
      }
    }
  }

  Future<void> _pickGarmentImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 2000,
        imageQuality: 88,
      );
      if (picked != null) {
        setState(() {
          _garmentImage = picked;
          _selectedWardrobeItemId = null;
          _selectedWardrobeItem = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access garment image: $e')),
        );
      }
    }
  }

  void _openWardrobePicker(List<WardrobeItem> items) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select from Wardrobe',
                      style: TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Text(
                        'Your wardrobe is empty. Upload a garment instead.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.8,
                          ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isSelected = item.id == _selectedWardrobeItemId;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedWardrobeItemId = item.id;
                              _selectedWardrobeItem = item;
                              _garmentImage = null;
                              // auto-detect category
                              final cat = item.category.toLowerCase();
                              if (cat.contains('outer') ||
                                  cat.contains('jacket') ||
                                  cat.contains('coat')) {
                                _selectedCategory = 'outer';
                              } else if (cat.contains('bottom') ||
                                  cat.contains('pant') ||
                                  cat.contains('jean')) {
                                _selectedCategory = 'lower body';
                              } else if (cat.contains('dress') ||
                                  cat.contains('suit')) {
                                _selectedCategory = 'dress';
                              } else if (cat.contains('shoe') ||
                                  cat.contains('boot') ||
                                  cat.contains('sneaker')) {
                                _selectedCategory = 'shoes';
                              } else {
                                _selectedCategory = 'upper body';
                              }
                            });
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? _gold : Colors.black12,
                                width: isSelected ? 2.5 : 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                PrivateImageView(
                                  imageUrl: item.imageUrl,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    color: Colors.black54,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 3,
                                    ),
                                    child: Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitTryOn() async {
    final tryOnProvider = context.read<TryOnProvider>();
    final isFriend = tryOnProvider.isFriendMode;
    final hasSavedModel = tryOnProvider.defaultModel != null;
    final useSavedModel = !isFriend && hasSavedModel && _userImage == null;

    if (isFriend) {
      if (_userImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload a photo of your friend.')),
        );
        return;
      }
      if (!tryOnProvider.friendConsentAcknowledged) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please confirm consent before styling a friend.')),
        );
        return;
      }
    } else if (!useSavedModel && _userImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or capture your silhouette photo.'),
        ),
      );
      return;
    }

    if (_useWardrobeItem && _selectedWardrobeItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a garment from your wardrobe.'),
        ),
      );
      return;
    }

    if (!_useWardrobeItem && _garmentImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a garment image.')),
      );
      return;
    }

    await tryOnProvider.startTryOn(
      userImage: _userImage,
      garmentImage: _useWardrobeItem ? null : _garmentImage,
      wardrobeItemId: _useWardrobeItem ? _selectedWardrobeItemId : null,
      garmentCategory: _selectedCategory,
      useSavedModel: useSavedModel,
      isFriendTryon: isFriend,
      friendConsentAcknowledged: tryOnProvider.friendConsentAcknowledged,
      saveAsDefaultModel: tryOnProvider.saveAsDefaultModel,
    );
  }

  Future<void> _saveAsOutfit(TryOnTask task) async {
    if (task.resultImageUrl == null) return;

    setState(() => _isSavingOutfit = true);
    final outfits = context.read<OutfitsProvider>();

    final garmentName = _selectedWardrobeItem?.name ?? 'Styling Garment';
    final outfitName = 'Try-On: $garmentName';
    final itemIds = _selectedWardrobeItemId != null
        ? [_selectedWardrobeItemId!]
        : <String>[];

    final success = await outfits.saveOutfit(
      name: outfitName,
      occasion: 'Virtual Fitting',
      notes:
          'Generated via adaa Virtual Try-On fitting studio.\nSilhouette fitting with $garmentName.',
      itemIds: itemIds,
    );

    setState(() => _isSavingOutfit = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved to your curated outfits!'),
            backgroundColor: AppColors.forest,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(outfits.error ?? 'Failed to save outfit.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tryOn = context.watch<TryOnProvider>();
    final wardrobe = context.watch<WardrobeProvider>();
    final activeTask = tryOn.activeTask;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        title: const AdaaWordmark(
          size: AdaaWordmarkSize.medium,
          color: AppColors.espresso,
          withDotAccent: true,
          showSubtitle: true,
          subtitle: 'virtual fitting room',
        ),
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (tryOn.isSubmitting ||
                (activeTask != null && activeTask.isProcessing)) {
              tryOn.cancelCurrentTask();
            }
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _primary,
            size: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildTopTabBar(tryOn),
              if (_selectedTab == 1)
                _buildHistorySection(tryOn)
              else if (activeTask != null && activeTask.isProcessing)
                _buildProcessingState(tryOn)
              else if (activeTask != null &&
                  activeTask.isSuccess &&
                  activeTask.resultImageUrl != null)
                _buildResultState(activeTask)
              else
                _buildInputForm(wardrobe, tryOn),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingState(TryOnProvider tryOn) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _surfaceLow,
              border: Border.all(color: _gold.withValues(alpha: 0.4), width: 2),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: _secondary,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Calibrating Silhouette & Drape',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _primary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'adaa is rendering your virtual try-on with\nrealistic lighting, fabric proportions, and fold dynamics.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Elapsed: ${(tryOn.pollAttempts * 3)}s / 120s max',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 36),
          OutlinedButton(
            onPressed: () {
              tryOn.cancelCurrentTask();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              side: const BorderSide(color: Colors.black26),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Cancel Fitting'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultState(TryOnTask task) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 14, color: _gold),
              SizedBox(width: 6),
              Text(
                'FITTING COMPLETE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: _primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Image display with PrivateImageView
        Container(
          width: double.infinity,
          height: 420,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: PrivateImageView(
            imageUrl: task.resultImageUrl,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSavingOutfit ? null : () => _saveAsOutfit(task),
                icon: _isSavingOutfit
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.bookmark_border_rounded, size: 18),
                label: const Text('Save Look'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E382B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  context.read<TryOnProvider>().reset();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Another'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: Colors.black26),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopTabBar(TryOnProvider tryOn) {
    final count = tryOn.totalHistoryCount;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              key: const Key('tryon_tab_studio'),
              onTap: () {
                if (_selectedTab != 0) setState(() => _selectedTab = 0);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: _selectedTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_fix_high_rounded,
                        size: 15,
                        color: _selectedTab == 0 ? _primary : AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Try On Studio',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              _selectedTab == 0 ? FontWeight.w700 : FontWeight.w500,
                          color: _selectedTab == 0 ? _primary : AppColors.textMuted,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              key: const Key('tryon_tab_history'),
              onTap: () {
                if (_selectedTab != 1) {
                  setState(() => _selectedTab = 1);
                  if (tryOn.history.isEmpty && !tryOn.isLoadingHistory) {
                    tryOn.loadHistory();
                  }
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: _selectedTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 15,
                        color: _selectedTab == 1 ? _primary : AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Fitting History',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              _selectedTab == 1 ? FontWeight.w700 : FontWeight.w500,
                          color: _selectedTab == 1 ? _primary : AppColors.textMuted,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1 ? _primary : Colors.black12,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _selectedTab == 1
                                  ? Colors.white
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetentionBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, size: 16, color: _gold),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Private & ephemeral: Fitting photos are retained for 7 days before automated cleanup.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(TryOnProvider tryOn) {
    if (tryOn.isLoadingHistory && tryOn.history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _secondary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Retrieving your virtual fittings...',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (tryOn.historyError != null && tryOn.history.isEmpty) {
      return _buildHistoryError(tryOn);
    }

    if (tryOn.history.isEmpty) {
      return Column(
        children: [
          _buildRetentionBanner(),
          _buildHistoryEmptyState(tryOn),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRetentionBanner(),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
            return GridView.builder(
              key: const Key('tryon_history_grid'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.70,
              ),
              itemCount: tryOn.history.length,
              itemBuilder: (context, index) {
                final item = tryOn.history[index];
                return _buildHistoryCard(item, tryOn);
              },
            );
          },
        ),
        if (tryOn.hasMoreHistory)
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            child: Center(
              child: OutlinedButton(
                key: const Key('tryon_load_more_btn'),
                onPressed:
                    tryOn.isLoadingMore ? null : () => tryOn.loadMoreHistory(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: Colors.black26),
                  shape: const StadiumBorder(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: tryOn.isLoadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _primary,
                        ),
                      )
                    : const Text(
                        'Load More Previous Fittings',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryEmptyState(TryOnProvider tryOn) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _gold.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.checkroom_outlined,
              size: 28,
              color: _secondary,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No Fitting History Yet',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: _primary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'When you style a silhouette in the Studio,\nyour completed virtual fittings will appear here for 7 days.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            key: const Key('tryon_empty_start_fitting_btn'),
            onPressed: () {
              setState(() => _selectedTab = 0);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E382B),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Start a Virtual Fitting'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryError(TryOnProvider tryOn) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 36, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(
            tryOn.historyError ?? 'Failed to load fitting history',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => tryOn.loadHistory(refresh: true),
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              shape: const StadiumBorder(),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(TryOnTask item, TryOnProvider tryOn) {
    final hasResult =
        item.resultImageUrl != null && item.resultImageUrl!.isNotEmpty;
    final dateStr = _formatDate(item.createdAt);

    return GestureDetector(
      onTap: () => _openHistoryDetail(context, item, tryOn),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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
                    imageUrl:
                        hasResult ? item.resultImageUrl : item.garmentImageUrl,
                    fit: BoxFit.cover,
                  ),
                  if (!hasResult)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Text(
                          'Expired / Missing',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Delete Fitting',
                        onPressed: () => _confirmDelete(item, tryOn),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'FITTING',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: _gold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.garmentCategory?.toUpperCase() ?? 'LOOK FITTING',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _primary,
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

  Future<void> _confirmDelete(
    TryOnTask item,
    TryOnProvider tryOn,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Fitting?',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.w600,
            color: _primary,
          ),
        ),
        content: const Text(
          'Are you sure you want to permanently remove this virtual fitting result? This cannot be undone.',
          style:
              TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await tryOn.deleteHistoryItem(item.taskId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(success ? 'Fitting removed.' : 'Failed to delete fitting.'),
          backgroundColor: success ? AppColors.forest : Colors.redAccent,
        ),
      );
    }
  }

  void _openHistoryDetail(
    BuildContext context,
    TryOnTask item,
    TryOnProvider tryOn,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Virtual Fitting',
                      style: TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatDate(item.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          key: const Key('tryon_detail_delete_btn'),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                          tooltip: 'Delete Fitting',
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _confirmDelete(item, tryOn);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Full image preview
                Container(
                  width: double.infinity,
                  height: 360,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.black.withValues(alpha: 0.08)),
                  ),
                  child: PrivateImageView(
                    imageUrl: item.resultImageUrl ?? item.garmentImageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 14, color: _gold),
                    const SizedBox(width: 6),
                    Text(
                      item.expiresAt != null
                          ? 'Retained until ${_formatDate(item.expiresAt!)}'
                          : 'Ephemeral 7-day retention policy',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (item.canRetry) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('tryon_detail_try_again_btn'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedTab = 0;
                              if (item.garmentCategory != null) {
                                _selectedCategory = item.garmentCategory!;
                              }
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Switched to Try On Studio. Ready to fit again.',
                                ),
                                backgroundColor: AppColors.forest,
                              ),
                            );
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 17),
                          label: const Text('Try Again'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primary,
                            side: const BorderSide(color: Colors.black26),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const Key('tryon_detail_save_btn'),
                        onPressed: item.resultImageUrl != null
                            ? () {
                                Navigator.pop(ctx);
                                _saveAsOutfit(item);
                              }
                            : null,
                        icon:
                            const Icon(Icons.bookmark_border_rounded, size: 17),
                        label: const Text('Save Look'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E382B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final m = months[dt.month - 1];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$m ${dt.day}, $hour:$min $ampm';
  }

  Widget _buildInputForm(WardrobeProvider wardrobe, TryOnProvider tryOn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.prefilledInspirationUrl != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surfaceLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _gold.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: PrivateImageView(
                    imageUrl: widget.prefilledInspirationUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inspiration Scan Attached',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: _primary,
                        ),
                      ),
                      Text(
                        'Using inspiration context for fitting calibration.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        if (tryOn.error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red.shade700,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tryOn.error!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        // Section 1: User Silhouette Photo / Saved Model / Friend Mode
        Consumer<TryOnProvider>(
          builder: (context, provider, _) {
            final hasModel = provider.defaultModel != null;
            final isFriend = provider.isFriendMode;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isFriend ? '1. Friend\'s Silhouette' : '1. Your Silhouette',
                      style: const TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        provider.toggleFriendMode(!isFriend);
                        setState(() => _userImage = null);
                      },
                      icon: Icon(
                        isFriend ? Icons.person : Icons.group_outlined,
                        size: 16,
                        color: _secondary,
                      ),
                      label: Text(
                        isFriend ? 'My Silhouette' : 'Try for a Friend',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isFriend
                      ? 'One-off fitting for a friend. Requires their photo & consent.'
                      : (hasModel && _userImage == null
                          ? 'Using your saved default try-on model for 1-click fittings.'
                          : 'Full or half-body photo with clean lighting and neutral pose.'),
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                if (!isFriend && hasModel && _userImage == null)
                  Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      color: _surfaceLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _secondary, width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (provider.defaultModel?.imageUrl != null)
                          Image.network(
                            provider.defaultModel!.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.person, size: 48, color: _secondary),
                            ),
                          ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.verified, size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'My Default Model',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _pickUserImage(ImageSource.gallery),
                                icon: const Icon(Icons.edit, size: 14),
                                label: const Text('Change'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: _primary,
                                  elevation: 2,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Remove Default Model?'),
                                      content: const Text('You will need to upload a silhouette photo for fittings.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    await provider.deleteDefaultModel();
                                  }
                                },
                                icon: const Icon(Icons.delete_outline, color: Colors.white),
                                style: IconButton.styleFrom(backgroundColor: Colors.black45),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      color: _surfaceLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _userImage != null ? _secondary : Colors.black12,
                        width: _userImage != null ? 1.5 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _userImage != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              kIsWeb
                                  ? Image.network(_userImage!.path, fit: BoxFit.cover)
                                  : Image.file(File(_userImage!.path), fit: BoxFit.cover),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: CircleAvatar(
                                  backgroundColor: Colors.black54,
                                  radius: 16,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    onPressed: () => setState(() => _userImage = null),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _pickUserImage(ImageSource.camera),
                                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                  label: const Text('Camera'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: _primary,
                                    elevation: 0,
                                    side: const BorderSide(color: Colors.black12),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () => _pickUserImage(ImageSource.gallery),
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Gallery'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: _primary,
                                    elevation: 0,
                                    side: const BorderSide(color: Colors.black12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                if (isFriend) ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: provider.friendConsentAcknowledged,
                    onChanged: (val) => provider.setFriendConsent(val ?? false),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'I have permission to use this photo for styling advice.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: _secondary,
                  ),
                ] else if (!hasModel && _userImage != null) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: provider.saveAsDefaultModel,
                    onChanged: (val) => provider.setSaveAsDefaultModel(val),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Save as My Default Model for 1-click fittings',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        // Section 2: Garment Source
        const Text(
          '2. Garment to Try On',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _primary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ChoiceChip(
              label: const Text('From My Wardrobe'),
              selected: _useWardrobeItem,
              selectedColor: _primary,
              labelStyle: TextStyle(
                color: _useWardrobeItem ? Colors.white : _primary,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
              onSelected: (val) {
                if (val) setState(() => _useWardrobeItem = true);
              },
            ),
            const SizedBox(width: 10),
            ChoiceChip(
              label: const Text('Upload Photo'),
              selected: !_useWardrobeItem,
              selectedColor: _primary,
              labelStyle: TextStyle(
                color: !_useWardrobeItem ? Colors.white : _primary,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
              onSelected: (val) {
                if (val) setState(() => _useWardrobeItem = false);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_useWardrobeItem) ...[
          if (_selectedWardrobeItem != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surfaceLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _gold.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: PrivateImageView(
                      imageUrl: _selectedWardrobeItem!.imageUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedWardrobeItem!.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _primary,
                          ),
                        ),
                        Text(
                          '${_selectedWardrobeItem!.category} • ${_selectedWardrobeItem!.primaryColor}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openWardrobePicker(wardrobe.items),
                    child: const Text('Change'),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _openWardrobePicker(wardrobe.items),
                icon: const Icon(Icons.checkroom_rounded, size: 18),
                label: const Text('Choose Garment from Wardrobe'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: Colors.black26),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
        ] else ...[
          Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: _surfaceLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _garmentImage != null ? _secondary : Colors.black12,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _garmentImage != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      kIsWeb
                          ? Image.network(
                              _garmentImage!.path,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(_garmentImage!.path),
                              fit: BoxFit.cover,
                            ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          radius: 14,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            onPressed: () =>
                                setState(() => _garmentImage = null),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () =>
                              _pickGarmentImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined, size: 16),
                          label: const Text('Camera'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _primary,
                            elevation: 0,
                            side: const BorderSide(color: Colors.black12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _pickGarmentImage(ImageSource.gallery),
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            size: 16,
                          ),
                          label: const Text('Gallery'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _primary,
                            elevation: 0,
                            side: const BorderSide(color: Colors.black12),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],

        const SizedBox(height: 24),

        // Section 3: Garment Category
        const Text(
          '3. Garment Type',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _primary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((cat) {
            final isSelected = _selectedCategory == cat['value'];
            return ChoiceChip(
              label: Text(cat['label']!),
              selected: isSelected,
              selectedColor: _primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : _primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              onSelected: (val) {
                if (val) setState(() => _selectedCategory = cat['value']!);
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 36),

        // Primary Action Button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: tryOn.isSubmitting ? null : _submitTryOn,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E382B),
              foregroundColor: Colors.white,
              elevation: 1,
              shadowColor: _primary.withValues(alpha: 0.2),
              shape: const StadiumBorder(),
            ),
            child: tryOn.isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, size: 18, color: _gold),
                      SizedBox(width: 8),
                      Text(
                        'GENERATE VIRTUAL TRY-ON',
                        style: TextStyle(
                          fontSize: 13,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
