import 'package:flutter/material.dart';
import '../../../core/models/community_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/private_image_view.dart';
import '../../communities/widgets/public_profile_sheet.dart';

class RequestsScreen extends StatefulWidget {
  final int initialIndex;

  const RequestsScreen({super.key, this.initialIndex = 0});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<ItemRequestModel> _incoming = [];
  List<ItemRequestModel> _outgoing = [];
  bool _isLoadingIncoming = true;
  bool _isLoadingOutgoing = true;
  String? _incomingError;
  String? _outgoingError;

  // Track item IDs being updated
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialIndex);
    _loadIncoming();
    _loadOutgoing();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadIncoming() async {
    setState(() {
      _isLoadingIncoming = true;
      _incomingError = null;
    });

    try {
      final list = await ApiClient.getIncomingRequests();
      if (mounted) {
        setState(() {
          _incoming = list;
          _isLoadingIncoming = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _incomingError = e.toString();
          _isLoadingIncoming = false;
        });
      }
    }
  }

  Future<void> _loadOutgoing() async {
    setState(() {
      _isLoadingOutgoing = true;
      _outgoingError = null;
    });

    try {
      final list = await ApiClient.getOutgoingRequests();
      if (mounted) {
        setState(() {
          _outgoing = list;
          _isLoadingOutgoing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _outgoingError = e.toString();
          _isLoadingOutgoing = false;
        });
      }
    }
  }

  Future<void> _updateStatus(ItemRequestModel req, String newStatus, String actionLabel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$actionLabel Request?', style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to $actionLabel this borrow request for "${req.item?.name ?? 'item'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingIds.add(req.id));

    try {
      final updated = await ApiClient.updateRequestStatus(req.id, newStatus);
      if (mounted) {
        setState(() {
          _processingIds.remove(req.id);
          // Update in local lists immediately
          final incIdx = _incoming.indexWhere((r) => r.id == req.id);
          if (incIdx != -1) _incoming[incIdx] = updated;

          final outIdx = _outgoing.indexWhere((r) => r.id == req.id);
          if (outIdx != -1) _outgoing[outIdx] = updated;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request successfully updated to ${updated.status}.'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingIds.remove(req.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.missing,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('activity & requests'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Incoming'),
                  if (_incoming.any((r) => r.isPending)) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_incoming.where((r) => r.isPending).length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Outgoing'),
                  if (_outgoing.any((r) => r.isPending)) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: AppColors.approxMatch,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_outgoing.where((r) => r.isPending).length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestList(
            items: _incoming,
            isLoading: _isLoadingIncoming,
            error: _incomingError,
            isIncoming: true,
            onRefresh: _loadIncoming,
          ),
          _buildRequestList(
            items: _outgoing,
            isLoading: _isLoadingOutgoing,
            error: _outgoingError,
            isIncoming: false,
            onRefresh: _loadOutgoing,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestList({
    required List<ItemRequestModel> items,
    required bool isLoading,
    required String? error,
    required bool isIncoming,
    required Future<void> Function() onRefresh,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: AppColors.missing),
              const SizedBox(height: 12),
              Text(error, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isIncoming ? Icons.move_to_inbox_outlined : Icons.outbox_outlined,
                    size: 48,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isIncoming ? 'No incoming requests yet' : 'No outgoing requests submitted',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isIncoming
                        ? 'When community members request to borrow pieces from your shared closet, they will appear here.'
                        : 'Discover clothing shared in your circles and request to borrow pieces for events or styling!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (ctx, idx) {
          final req = items[idx];
          return _buildRequestCard(req, isIncoming);
        },
      ),
    );
  }

  Widget _buildRequestCard(ItemRequestModel req, bool isIncoming) {
    final otherPartyName = isIncoming ? req.resolvedRequesterName : req.resolvedOwnerName;
    final otherPartyId = isIncoming ? req.requesterId : req.ownerId;
    final otherPartyInitials = otherPartyName.isNotEmpty ? otherPartyName.substring(0, 1).toUpperCase() : 'M';
    final isProcessing = _processingIds.contains(req.id);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Item Image, Title, Status Chip
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: PrivateImageView(
                  imageUrl: req.item?.imageUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.item?.name ?? 'Garment Piece',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      req.communityName != null ? 'Circle: ${req.communityName}' : 'Community Shared',
                      style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      req.dateRangeSummary,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _buildStatusChip(req.status),
            ],
          ),
          const SizedBox(height: 12),

          // Other party row (Tappable for public profile)
          InkWell(
            onTap: () => PublicProfileSheet.show(context, userId: otherPartyId, fallbackName: otherPartyName),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.accentSoft,
                    child: Text(
                      otherPartyInitials,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isIncoming ? 'From: $otherPartyName' : 'Owner: $otherPartyName',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  const Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),

          // Message (if provided)
          if (req.message != null && req.message!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentSoft.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '"${req.message}"',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
              ),
            ),
          ],

          // Action Buttons
          if (!req.isTerminal) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            if (isProcessing) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
            ] else ...[
              // Incoming Pending Actions
              if (isIncoming && req.isPending) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.missing,
                          side: const BorderSide(color: AppColors.missing),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => _updateStatus(req, 'declined', 'Decline'),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.exactMatch,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => _updateStatus(req, 'accepted', 'Accept'),
                        child: const Text('Accept Request'),
                      ),
                    ),
                  ],
                ),
              ],

              // Outgoing Pending Actions
              if (!isIncoming && req.isPending) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.missing,
                      side: const BorderSide(color: AppColors.missing),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _updateStatus(req, 'cancelled', 'Cancel'),
                    child: const Text('Cancel Request'),
                  ),
                ),
              ],

              // Accepted Actions (Owner or Borrower can mark completed)
              if (req.isAccepted) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _updateStatus(req, 'completed', 'Mark Completed'),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Mark Arrangement Completed'),
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'pending':
        bg = AppColors.approxMatch.withValues(alpha: 0.15);
        fg = Colors.orange.shade800;
        label = 'Pending Review';
        break;
      case 'accepted':
        bg = AppColors.exactMatch.withValues(alpha: 0.15);
        fg = AppColors.exactMatch;
        label = 'Accepted';
        break;
      case 'declined':
        bg = AppColors.missing.withValues(alpha: 0.15);
        fg = AppColors.missing;
        label = 'Declined';
        break;
      case 'cancelled':
        bg = Colors.grey.shade200;
        fg = AppColors.textSecondary;
        label = 'Cancelled';
        break;
      case 'completed':
        bg = AppColors.primary.withValues(alpha: 0.15);
        fg = AppColors.primary;
        label = 'Completed';
        break;
      default:
        bg = Colors.grey.shade200;
        fg = AppColors.textSecondary;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
