import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/private_image_view.dart';
import '../../../state/auth_provider.dart';
import '../../../state/community_provider.dart';
import '../../wardrobe/screens/wardrobe_detail_screen.dart';
import '../widgets/public_profile_sheet.dart';
import 'shared_item_detail_screen.dart';

class SharedClosetScreen extends StatefulWidget {
  const SharedClosetScreen({super.key});

  @override
  State<SharedClosetScreen> createState() => _SharedClosetScreenState();
}

class _SharedClosetScreenState extends State<SharedClosetScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'all';

  final List<String> _categoryOptions = [
    'all',
    'tops',
    'bottoms',
    'dresses',
    'outerwear',
    'shoes',
    'bags',
    'accessories',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommunityProvider>().loadSharedCloset();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onCategorySelected(String cat) {
    setState(() => _selectedCategory = cat);
    context.read<CommunityProvider>().loadSharedCloset(
          category: _selectedCategory,
          search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        );
  }

  void _onSearchChanged(String query) {
    context.read<CommunityProvider>().loadSharedCloset(
          category: _selectedCategory,
          search: query.trim().isEmpty ? null : query.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final commProv = context.watch<CommunityProvider>();
    final items = commProv.sharedClosetItems;
    final isLoading = commProv.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Shared Closets', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text(
              '${items.length} garments across all your circles',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search across all your fashion communities...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // Category Chips Bar
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categoryOptions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, idx) {
                final cat = _categoryOptions[idx];
                final isSel = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(
                    cat.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                      color: isSel ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  selected: isSel,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: isSel ? AppColors.primary : AppColors.border),
                  onSelected: (_) => _onCategorySelected(cat),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Main Grid Area
          Expanded(
            child: isLoading && items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : commProv.error != null && items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.missing),
                              const SizedBox(height: 12),
                              const Text('Unable to Load Shared Closet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              const SizedBox(height: 6),
                              Text(commProv.error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => commProv.loadSharedCloset(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : items.isEmpty
                        ? Center(
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
                                    child: const Icon(Icons.checkroom_outlined, size: 48, color: AppColors.primary),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('No Shared Garments Found', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'When you or members of your approved circles share clothing items, they will appear here in one combined feed.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => commProv.loadSharedCloset(),
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.58,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                              ),
                              itemCount: items.length,
                              itemBuilder: (ctx, idx) {
                                final shared = items[idx];
                                final item = shared.item;
                                final currentUserId = context.read<AuthProvider>().user?.id;
                                final isOwner = currentUserId != null && currentUserId == shared.ownerId;

                                return GestureDetector(
                                  onTap: () {
                                    if (isOwner) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => WardrobeDetailScreen(item: item)),
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => SharedItemDetailScreen(sharedItem: shared)),
                                      );
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Stack(
                                            children: [
                                              PrivateImageView(
                                                imageUrl: item.imageUrl,
                                                width: double.infinity,
                                                height: double.infinity,
                                                fit: BoxFit.cover,
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                              ),
                                              Positioned(
                                                top: 8,
                                                left: 8,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary.withValues(alpha: 0.9),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Text(
                                                    shared.communityName,
                                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.9),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    item.category.toUpperCase(),
                                                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.primary),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                item.brand != null && item.brand!.isNotEmpty
                                                    ? '${item.primaryColor} • ${item.brand}'
                                                    : item.primaryColor,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                              ),
                                              const SizedBox(height: 6),
                                              // Owner Identity
                                              InkWell(
                                                onTap: () => PublicProfileSheet.show(
                                                  context,
                                                  userId: shared.ownerId,
                                                  fallbackName: shared.resolvedOwnerName,
                                                ),
                                                borderRadius: BorderRadius.circular(4),
                                                child: Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 8,
                                                      backgroundColor: AppColors.accentSoft,
                                                      child: Text(
                                                        shared.ownerInitials,
                                                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.primary),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Expanded(
                                                      child: Text(
                                                        shared.resolvedOwnerName,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                'Shared with this community',
                                                style: TextStyle(fontSize: 9, color: AppColors.textMuted, fontStyle: FontStyle.italic),
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
          ),
        ],
      ),
    );
  }
}
