import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/community_model.dart';
import '../../../core/models/wardrobe_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/private_image_view.dart';
import '../../../state/community_provider.dart';
import '../../../state/wardrobe_provider.dart';

class ShareItemDialog extends StatefulWidget {
  final WardrobeItem item;
  final String? preselectedCommunityId;

  const ShareItemDialog({
    super.key,
    required this.item,
    this.preselectedCommunityId,
  });

  @override
  State<ShareItemDialog> createState() => _ShareItemDialogState();
}

class _ShareItemDialogState extends State<ShareItemDialog> {
  final TextEditingController _notesController = TextEditingController();
  String? _selectedCommunityId;
  bool _isLoadingListings = true;
  List<CommunityListingModel> _currentListings = [];
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _selectedCommunityId = widget.preselectedCommunityId;
    _fetchExistingListings();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchExistingListings() async {
    setState(() => _isLoadingListings = true);
    final commProv = context.read<CommunityProvider>();
    await commProv.loadMyCommunities(silent: true);
    final listings = await commProv.getWardrobeItemListings(widget.item.id);
    if (mounted) {
      setState(() {
        _currentListings = listings;
        _isLoadingListings = false;
      });
    }
  }

  Future<void> _shareToCommunity(String commId) async {
    setState(() => _isActionInProgress = true);
    final commProv = context.read<CommunityProvider>();
    final wardrobeProv = context.read<WardrobeProvider>();

    final success = await commProv.listWardrobeItem(
      commId,
      wardrobeItemId: widget.item.id,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    if (mounted) {
      setState(() => _isActionInProgress = false);
      if (success) {
        await wardrobeProv.loadWardrobe(silent: true);
        await _fetchExistingListings();
        _notesController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Garment successfully shared to community!'),
              backgroundColor: AppColors.exactMatch,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(commProv.error ?? 'Failed to share item.'),
            backgroundColor: AppColors.missing,
          ),
        );
      }
    }
  }

  Future<void> _unlistItem(CommunityListingModel listing) async {
    setState(() => _isActionInProgress = true);
    final commProv = context.read<CommunityProvider>();
    final wardrobeProv = context.read<WardrobeProvider>();

    final success = await commProv.unlistSharedItem(listing.communityId, listing.id);
    if (mounted) {
      setState(() => _isActionInProgress = false);
      if (success) {
        await wardrobeProv.loadWardrobe(silent: true);
        await _fetchExistingListings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item unlisted. Your personal wardrobe remains unchanged.'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(commProv.error ?? 'Failed to unlist item.'),
            backgroundColor: AppColors.missing,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final commProv = context.watch<CommunityProvider>();
    final approvedComms = commProv.approvedCommunities;

    // Filter communities where this item is NOT yet listed
    final listedCommIds = _currentListings.map((l) => l.communityId).toSet();
    final availableComms = approvedComms.where((c) => !listedCommIds.contains(c.id)).toList();

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Community Sharing',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Item summary row
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: PrivateImageView(
                    imageUrl: widget.item.imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${widget.item.category.toUpperCase()} • ${widget.item.primaryColor}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 10),

            // Active Listings Section
            const Text(
              'CURRENTLY SHARED IN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),

            if (_isLoadingListings)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
            else if (_currentListings.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'This item is private and not shared with any communities.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              )
            else
              Column(
                children: _currentListings.map((listing) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    elevation: 0,
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.people_outline, color: AppColors.primary),
                      title: Text(
                        listing.communityName ?? 'Community',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      subtitle: listing.notes != null ? Text(listing.notes!, style: const TextStyle(fontSize: 11)) : null,
                      trailing: TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: AppColors.missing),
                        onPressed: _isActionInProgress ? null : () => _unlistItem(listing),
                        icon: const Icon(Icons.link_off, size: 16),
                        label: const Text('Unlist', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 20),

            // Share to new community section
            const Text(
              'SHARE TO A COMMUNITY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),

            if (approvedComms.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No Approved Communities', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    SizedBox(height: 4),
                    Text(
                      'You must be an approved member of at least one community to share clothing items.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            else if (availableComms.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Already shared to all your approved communities!',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                ),
              )
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedCommunityId != null && availableComms.any((c) => c.id == _selectedCommunityId)
                    ? _selectedCommunityId
                    : availableComms.first.id,
                decoration: const InputDecoration(
                  labelText: 'Select Community',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                items: availableComms.map((comm) {
                  return DropdownMenuItem(
                    value: comm.id,
                    child: Text(comm.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCommunityId = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Sharing Note (Optional)',
                  hintText: 'e.g. Great for presentations, fits slightly small',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isActionInProgress
                      ? null
                      : () {
                          final targetId = _selectedCommunityId ?? (availableComms.isNotEmpty ? availableComms.first.id : null);
                          if (targetId != null) {
                            _shareToCommunity(targetId);
                          }
                        },
                  icon: const Icon(Icons.share_outlined),
                  label: Text(_isActionInProgress ? 'Sharing...' : 'Share to Community'),
                ),
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
