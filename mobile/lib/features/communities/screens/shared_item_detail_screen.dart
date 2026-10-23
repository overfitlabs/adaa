import 'package:flutter/material.dart';

import '../../../core/models/community_model.dart';
import '../../../core/models/wardrobe_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaa_brand_badge.dart';
import '../../../core/widgets/private_image_view.dart';
import '../widgets/borrow_request_dialog.dart';
import '../widgets/public_profile_sheet.dart';
import '../../../core/widgets/adaa_wordmark.dart';

class SharedItemDetailScreen extends StatelessWidget {
  final SharedClosetItemModel sharedItem;

  const SharedItemDetailScreen({super.key, required this.sharedItem});

  factory SharedItemDetailScreen.fromListing({
    Key? key,
    required CommunityListingModel listing,
    required String communityName,
  }) {
    return SharedItemDetailScreen(
      key: key,
      sharedItem: SharedClosetItemModel(
        listingId: listing.id,
        communityId: listing.communityId,
        communityName: communityName,
        ownerId: listing.ownerId,
        ownerName: listing.ownerName,
        ownerAvatarUrl: listing.ownerAvatarUrl,
        ownerBio: listing.ownerBio,
        status: listing.status,
        item: listing.item!,
        notes: listing.notes,
        createdAt: listing.createdAt,
      ),
    );
  }

  WardrobeItem get garment => sharedItem.item;

  void _openOwnerProfile(BuildContext context) {
    PublicProfileSheet.show(
      context,
      userId: sharedItem.ownerId,
      fallbackName: sharedItem.resolvedOwnerName,
    );
  }

  void _openBorrowRequest(BuildContext context) {
    BorrowRequestDialog.show(
      context,
      communityId: sharedItem.communityId,
      listingId: sharedItem.listingId,
      communityName: sharedItem.communityName,
      garment: garment,
      ownerName: sharedItem.resolvedOwnerName,
    );
  }

  @override
  Widget build(BuildContext context) {
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
            // Garment Image
            Stack(
              children: [
                PrivateImageView(
                  imageUrl: garment.imageUrl,
                  width: double.infinity,
                  height: 360,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    height: 260,
                    color: AppColors.accentSoft,
                    child: const Center(
                      child: Icon(
                        Icons.checkroom,
                        size: 50,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.groups, color: Colors.white, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          sharedItem.communityName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Category
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          garment.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AdaaBrandBadge(text: garment.category.toUpperCase()),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Owner Bar (Tappable)
                  InkWell(
                    onTap: () => _openOwnerProfile(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.accentSoft,
                            child: Text(
                              sharedItem.ownerInitials,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sharedItem.resolvedOwnerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                const Text(
                                  'Shared with this community',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Attribute Pills
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (garment.primaryColor.isNotEmpty)
                        _buildPill(
                          Icons.palette_outlined,
                          garment.primaryColor,
                        ),
                      if (garment.brand != null && garment.brand!.isNotEmpty)
                        _buildPill(Icons.local_offer_outlined, garment.brand!),
                      if (garment.size != null && garment.size!.isNotEmpty)
                        _buildPill(
                          Icons.straighten_outlined,
                          'Size ${garment.size!}',
                        ),
                      if (garment.material != null &&
                          garment.material!.isNotEmpty)
                        _buildPill(Icons.texture_outlined, garment.material!),
                      if (garment.condition != null &&
                          garment.condition!.isNotEmpty)
                        _buildPill(Icons.verified_outlined, garment.condition!),
                      if (garment.formality != null &&
                          garment.formality!.isNotEmpty)
                        _buildPill(Icons.style_outlined, garment.formality!),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Notes from listing or item
                  if (sharedItem.notes != null &&
                      sharedItem.notes!.trim().isNotEmpty) ...[
                    const Text(
                      'SHARING NOTES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        sharedItem.notes!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else if (garment.notes != null &&
                      garment.notes!.trim().isNotEmpty) ...[
                    const Text(
                      'GARMENT DETAILS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        garment.notes!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  const SizedBox(height: 60), // Space for bottom button
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: () => _openBorrowRequest(context),
          icon: const Icon(Icons.handshake_outlined),
          label: const Text('Request to Borrow'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
