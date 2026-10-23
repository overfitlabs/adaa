import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/models/community_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/private_image_view.dart';
import '../../../state/auth_provider.dart';
import '../../../state/community_provider.dart';
import '../../../state/wardrobe_provider.dart';
import '../../wardrobe/screens/wardrobe_detail_screen.dart';
import '../widgets/public_profile_sheet.dart';
import 'shared_item_detail_screen.dart';
import '../../../core/widgets/adaa_wordmark.dart';

class CommunityDetailScreen extends StatefulWidget {
  final CommunityModel community;

  const CommunityDetailScreen({super.key, required this.community});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
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
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommunityProvider>().selectCommunity(widget.community.id);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onCategorySelected(String cat) {
    setState(() => _selectedCategory = cat);
    context.read<CommunityProvider>().loadCommunityListings(
      widget.community.id,
      category: _selectedCategory,
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
    );
  }

  void _onSearchChanged(String query) {
    context.read<CommunityProvider>().loadCommunityListings(
      widget.community.id,
      category: _selectedCategory,
      search: query.trim().isEmpty ? null : query.trim(),
    );
  }

  Future<void> _requestToJoin() async {
    final commProv = context.read<CommunityProvider>();
    final success = await commProv.joinCommunity(widget.community.id);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Join request submitted! An administrator will review your request.',
            ),
            backgroundColor: AppColors.exactMatch,
          ),
        );
        commProv.selectCommunity(widget.community.id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(commProv.error ?? 'Failed to submit join request.'),
            backgroundColor: AppColors.missing,
          ),
        );
      }
    }
  }

  Future<void> _confirmLeaveCommunity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Community?'),
        content: Text(
          'Are you sure you want to leave "${widget.community.name}"? Your shared items in this circle will be unlisted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.missing),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Leave Circle',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final commProv = context.read<CommunityProvider>();
      final success = await commProv.leaveCommunity(widget.community.id);
      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have left the community.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(commProv.error ?? 'Failed to leave community.'),
              backgroundColor: AppColors.missing,
            ),
          );
        }
      }
    }
  }

  void _showShareGarmentSheet(BuildContext context) {
    final wardrobeProv = context.read<WardrobeProvider>();
    final items = wardrobeProv.items;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollCtrl) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Share to this Circle',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a garment from your personal digital closet to share with ${widget.community.name}.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Your personal wardrobe is empty. Add garments first!',
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      controller: scrollCtrl,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (ctx, idx) {
                        final item = items[idx];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: PrivateImageView(
                              imageUrl: item.imageUrl,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${item.category.toUpperCase()} • ${item.primaryColor}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                            ),
                            onPressed: () async {
                              final commProv = context
                                  .read<CommunityProvider>();
                              final messenger = ScaffoldMessenger.of(context);
                              Navigator.pop(ctx);
                              final success = await commProv.listWardrobeItem(
                                widget.community.id,
                                wardrobeItemId: item.id,
                              );
                              if (mounted) {
                                if (success) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '"${item.name}" shared to ${widget.community.name}!',
                                      ),
                                      backgroundColor: AppColors.exactMatch,
                                    ),
                                  );
                                } else {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        commProv.error ??
                                            'Failed to share item.',
                                      ),
                                      backgroundColor: AppColors.missing,
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text('Share'),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final commProv = context.watch<CommunityProvider>();
    final currentComm = commProv.selectedCommunity ?? widget.community;
    final isApproved = currentComm.isApprovedMember;
    final isPending = currentComm.isPendingRequest;
    final isAdminOrOwner = currentComm.isAdminOrOwner;

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
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: _buildCommunityHeader(currentComm, isApproved, isPending),
            ),
            if (isApproved)
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.espresso,
                    unselectedLabelColor: AppColors.textMuted,
                    indicatorColor: AppColors.forest,
                    indicatorWeight: 2.5,
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.checkroom_outlined, size: 20),
                        text: 'Shared Closet (${currentComm.listingsCount})',
                      ),
                      Tab(
                        icon: const Icon(Icons.people_outline, size: 20),
                        text: 'Members (${currentComm.membersCount})',
                      ),
                    ],
                  ),
                ),
              ),
          ];
        },
        body: !isApproved
            ? _buildNonMemberGate(currentComm, isPending)
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildSharedClosetTab(commProv),
                  _buildMembersTab(commProv, isAdminOrOwner),
                ],
              ),
      ),
      floatingActionButton: isApproved
          ? FloatingActionButton(
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              child: const Icon(Icons.share_sharp),
              onPressed: () => _showShareGarmentSheet(context),
            )
          : null,
    );
  }

  Widget _buildCommunityHeader(
    CommunityModel comm,
    bool isApproved,
    bool isPending,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.groups_outlined,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comm.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
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
                            color: comm.isPrivate
                                ? Colors.grey.shade200
                                : AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            comm.isPrivate ? 'PRIVATE CIRCLE' : 'PUBLIC CIRCLE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: comm.isPrivate
                                  ? AppColors.textSecondary
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${comm.membersCount} members • ${comm.listingsCount} garments',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comm.description != null && comm.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              comm.description!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMembershipStatusBadge(comm),
              if (isApproved)
                IconButton(
                  icon: const Icon(Icons.exit_to_app_outlined),
                  tooltip: 'Leave Community',
                  onPressed: _confirmLeaveCommunity,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipStatusBadge(CommunityModel comm) {
    final mem = comm.myMembership;
    if (mem == null) {
      return const SizedBox.shrink();
    }

    Color bgColor;
    Color fgColor;
    String label;
    IconData icon;

    switch (mem.status) {
      case 'approved':
        bgColor = AppColors.exactMatch.withValues(alpha: 0.15);
        fgColor = AppColors.exactMatch;
        label = 'Active Member (${mem.role.toUpperCase()})';
        icon = Icons.verified;
        break;
      case 'requested':
        bgColor = AppColors.approxMatch.withValues(alpha: 0.2);
        fgColor = Colors.orange.shade800;
        label = 'Join Request Pending Review';
        icon = Icons.hourglass_top;
        break;
      case 'rejected':
        bgColor = AppColors.missing.withValues(alpha: 0.15);
        fgColor = AppColors.missing;
        label = 'Membership Request Declined';
        icon = Icons.cancel;
        break;
      default:
        bgColor = Colors.grey.shade200;
        fgColor = AppColors.textSecondary;
        label = 'Membership Inactive';
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fgColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNonMemberGate(CommunityModel comm, bool isPending) {
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
              child: const Icon(
                Icons.lock_outline,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Exclusive Community Closet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              isPending
                  ? 'Your membership request is currently awaiting review by a community administrator. You will get full access once approved.'
                  : 'Join this circle to browse shared closets, borrow looks, and share garments with members.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            if (!isPending)
              ElevatedButton.icon(
                onPressed: _requestToJoin,
                icon: const Icon(Icons.group_add),
                label: const Text('Request to Join Circle'),
              )
            else
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.hourglass_bottom),
                label: const Text('Request Pending...'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedClosetTab(CommunityProvider commProv) {
    final listings = commProv.communityListings;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search community garments, brands, styles...',
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
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

        // Category Chips
        SizedBox(
          height: 40,
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
                    fontSize: 10,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                selected: isSel,
                showCheckmark: false, // Removes the tick mark
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : AppColors.textPrimary,
                ),
                onSelected: (_) => _onCategorySelected(cat),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: listings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.checkroom_outlined,
                        size: 40,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No garments listed yet',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Be the first to share a piece with this community!',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.58,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: listings.length,
                  itemBuilder: (ctx, idx) {
                    final listing = listings[idx];
                    final item = listing.item;
                    if (item == null) return const SizedBox.shrink();

                    final currentUserId = context.read<AuthProvider>().user?.id;
                    final isOwner =
                        currentUserId != null &&
                        currentUserId == listing.ownerId;

                    return GestureDetector(
                      onTap: () {
                        if (isOwner) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WardrobeDetailScreen(item: item),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SharedItemDetailScreen.fromListing(
                                    listing: listing,
                                    communityName: widget.community.name,
                                  ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
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
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(14),
                                    ),
                                  ),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        item.category.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.brand != null && item.brand!.isNotEmpty
                                        ? '${item.primaryColor} • ${item.brand}'
                                        : item.primaryColor,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  // Owner attribution
                                  InkWell(
                                    onTap: () => PublicProfileSheet.show(
                                      context,
                                      userId: listing.ownerId,
                                      fallbackName: listing.resolvedOwnerName,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 8,
                                          backgroundColor: AppColors.accentSoft,
                                          child: Text(
                                            listing.ownerInitials,
                                            style: const TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            listing.resolvedOwnerName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Shared with this community',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: AppColors.textMuted,
                                      fontStyle: FontStyle.italic,
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
      ],
    );
  }

  void _confirmApproveMember(CommunityMemberModel member) {
    final memberName = member.resolvedName;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Approve Membership',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Allow $memberName to join ${widget.community.name}? They will gain access to browse and borrow from the shared closet.',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.exactMatch,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final commProv = context.read<CommunityProvider>();
              final messenger = ScaffoldMessenger.of(context);
              final success = await commProv.approveMember(
                widget.community.id,
                member.userId,
              );
              if (mounted) {
                if (success) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('$memberName has been approved to join!'),
                      backgroundColor: AppColors.exactMatch,
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        commProv.error ?? 'Failed to approve membership.',
                      ),
                      backgroundColor: AppColors.missing,
                    ),
                  );
                }
              }
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _confirmRejectMember(CommunityMemberModel member) {
    final memberName = member.resolvedName;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Decline Request',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Decline $memberName\'s request to join ${widget.community.name}?',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.missing),
            onPressed: () async {
              Navigator.pop(ctx);
              final commProv = context.read<CommunityProvider>();
              final messenger = ScaffoldMessenger.of(context);
              final success = await commProv.rejectMember(
                widget.community.id,
                member.userId,
              );
              if (mounted) {
                if (success) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Membership request from $memberName was declined.',
                      ),
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        commProv.error ?? 'Failed to decline request.',
                      ),
                      backgroundColor: AppColors.missing,
                    ),
                  );
                }
              }
            },
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersTab(CommunityProvider commProv, bool isAdminOrOwner) {
    final currentComm = commProv.selectedCommunity ?? widget.community;
    final allMembers = commProv.members;
    final currentUserId = context.read<AuthProvider>().user?.id;

    final pending = allMembers.where((m) => m.status == 'requested').toList();
    final approved = allMembers.where((m) => m.status == 'approved').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isAdminOrOwner && pending.isNotEmpty) ...[
          Text(
            'PENDING REQUESTS (${pending.length})',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...pending.map((m) {
            // final dateStr = m.requestedAt.toLocal().toString().split(' ').first;
            final dateStr = DateFormat('dd-MM-yyyy')
                .format(m.requestedAt.toLocal());
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.forestDark),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.accentSoft,
                  child: Text(
                    m.initials,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                title: Text(
                  m.resolvedName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  m.bio != null && m.bio!.trim().isNotEmpty
                      ? '$dateStr • ${m.bio!.trim()}'
                      : 'Requested on $dateStr',
                  style: const TextStyle(fontSize: 11, color: AppColors.forest),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.check_circle,
                        color: AppColors.exactMatch,
                      ),
                      tooltip: 'Approve',
                      onPressed: () => _confirmApproveMember(m),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: AppColors.missing),
                      tooltip: 'Decline',
                      onPressed: () => _confirmRejectMember(m),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 18),
        ],

        Text(
          'ACTIVE MEMBERS (${approved.length})',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ...approved.map((m) {
          final isMe = m.userId == currentUserId;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.border),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: m.role == 'owner'
                    ? Colors.deepPurple.shade100
                    : AppColors.accentSoft,
                child: Text(
                  m.initials,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: m.role == 'owner'
                        ? Colors.deepPurple
                        : AppColors.primary,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      isMe ? 'You (${m.resolvedName})' : m.resolvedName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: m.role == 'owner'
                          ? Colors.deepPurple.shade50
                          : AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      m.role.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: m.role == 'owner'
                            ? Colors.deepPurple
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: m.bio != null && m.bio!.trim().isNotEmpty
                  ? Text(
                      m.bio!.trim(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              trailing: isAdminOrOwner && !isMe
                  ? PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (val) {
                        if (val == 'remove') {
                          commProv.removeMember(widget.community.id, m.userId);
                        } else if (val == 'make_admin') {
                          commProv.updateMemberRole(
                            widget.community.id,
                            m.userId,
                            'admin',
                          );
                        } else if (val == 'make_member') {
                          commProv.updateMemberRole(
                            widget.community.id,
                            m.userId,
                            'member',
                          );
                        }
                      },
                      itemBuilder: (ctx) => [
                        if (currentComm.isOwner && m.role == 'member')
                          const PopupMenuItem(
                            value: 'make_admin',
                            child: Text('Promote to Admin'),
                          ),
                        if (currentComm.isOwner && m.role == 'admin')
                          const PopupMenuItem(
                            value: 'make_member',
                            child: Text('Demote to Member'),
                          ),
                        const PopupMenuItem(
                          value: 'remove',
                          child: Text(
                            'Remove from Circle',
                            style: TextStyle(color: AppColors.missing),
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          );
        }),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppColors.surface, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
