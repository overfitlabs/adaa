// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';

import '../../../core/models/community_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/private_image_view.dart';
import '../../../core/widgets/adaa_wordmark.dart';
import '../../communities/widgets/public_profile_sheet.dart';

class RequestsScreen extends StatefulWidget {
  final int initialIndex;

  const RequestsScreen({super.key, this.initialIndex = 0});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<ItemRequestModel> _incoming = [];
  List<ItemRequestModel> _outgoing = [];
  bool _isLoadingIncoming = true;
  bool _isLoadingOutgoing = true;
  String? _incomingError;
  String? _outgoingError;
  final Set<String> _processingIds = {};

  List<ItemRequestModel> get _history {
    final all = <ItemRequestModel>[..._incoming, ..._outgoing];
    final seen = <String>{};
    return all.where((request) {
      if (!request.isTerminal || !seen.add(request.id)) return false;
      return true;
    }).toList()..sort((a, b) => b.id.compareTo(a.id));
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialIndex < 0
          ? 0
          : widget.initialIndex > 2
          ? 2
          : widget.initialIndex,
    );
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
      if (!mounted) return;
      setState(() {
        _incoming = list;
        _isLoadingIncoming = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _incomingError = e.toString();
        _isLoadingIncoming = false;
      });
    }
  }

  Future<void> _loadOutgoing() async {
    setState(() {
      _isLoadingOutgoing = true;
      _outgoingError = null;
    });
    try {
      final list = await ApiClient.getOutgoingRequests();
      if (!mounted) return;
      setState(() {
        _outgoing = list;
        _isLoadingOutgoing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _outgoingError = e.toString();
        _isLoadingOutgoing = false;
      });
    }
  }

  Future<void> _updateStatus(
    ItemRequestModel request,
    String newStatus,
    String actionLabel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.canvas,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            newStatus == 'accepted'
                ? Icons.check_circle_outline
                : newStatus == 'declined'
                ? Icons.block_outlined
                : newStatus == 'cancelled'
                ? Icons.cancel_outlined
                : Icons.task_alt,
            color: AppColors.forest,
          ),
        ),
        title: Text(
          '$actionLabel request?',
          style: const TextStyle(
            fontFamily: 'Playfair Display',
            color: AppColors.forest,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to $actionLabel the request for '
          '"${request.item?.name ?? 'this item'}"?',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Keep reviewing',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.forest,
              foregroundColor: AppColors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _processingIds.add(request.id));

    try {
      final updated = await ApiClient.updateRequestStatus(
        request.id,
        newStatus,
      );
      if (!mounted) return;
      setState(() {
        _processingIds.remove(request.id);
        final incomingIndex = _incoming.indexWhere((r) => r.id == request.id);
        if (incomingIndex != -1) _incoming[incomingIndex] = updated;
        final outgoingIndex = _outgoing.indexWhere((r) => r.id == request.id);
        if (outgoingIndex != -1) _outgoing[outgoingIndex] = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request updated: ${updated.status}.'),
          backgroundColor: AppColors.forest,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingIds.remove(request.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.missing,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showHelp() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.canvas,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Borrowing requests'),
        content: const Text(
          'Received requests are from members who want to borrow an item '
          'you shared. Sent requests are the items you have asked to borrow. '
          'Once a request is declined, cancelled, or completed, it appears '
          'in History.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.forest),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incomingPending = _incoming.where((r) => r.isPending).length;
    final outgoingPending = _outgoing.where((r) => r.isPending).length;

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
            tooltip: 'Help and information',
            onPressed: _showHelp,
            icon: const Icon(
              Icons.help_outline_rounded,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Borrowing Requests',
                                  style: TextStyle(
                                    fontFamily: 'Playfair Display',
                                    fontSize: 30,
                                    height: 1.2,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.forest,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.sageWash,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 6,
                                      color: AppColors.sage,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'COMMUNITY LOANS',
                                      style: TextStyle(
                                        color: AppColors.sageDark,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Manage community garment loans, requests, and lending history.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              dividerColor: Colors.transparent,
                              indicatorSize: TabBarIndicatorSize.tab,
                              indicator: BoxDecoration(
                                color: AppColors.forest,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [AppColors.subtleShadow],
                              ),
                              labelColor: AppColors.white,
                              unselectedLabelColor: AppColors.textSecondary,
                              labelStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                              unselectedLabelStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              labelPadding: EdgeInsets.zero,
                              tabs: [
                                _tabLabel(
                                  'Received ${incomingPending == 0 ? "" : "($incomingPending)"}',
                                ),
                                _tabLabel(
                                  'Sent ${outgoingPending == 0 ? "" : "($outgoingPending)"}',
                                ),
                                _tabLabel(
                                  'History ${_history.isNotEmpty ? "(${_history.length})" : ""}',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildActiveList(
                      items: _incoming.where((r) => !r.isTerminal).toList(),
                      isLoading: _isLoadingIncoming,
                      error: _incomingError,
                      isIncoming: true,
                      onRefresh: _loadIncoming,
                      emptyTitle: 'All caught up',
                      emptyDescription: 'No pending borrowing requests from your circles at the moment.',
                    ),
                    _buildActiveList(
                      items: _outgoing.where((r) => !r.isTerminal).toList(),
                      isLoading: _isLoadingOutgoing,
                      error: _outgoingError,
                      isIncoming: false,
                      onRefresh: _loadOutgoing,
                      emptyTitle: 'Nothing sent yet',
                      emptyDescription: 'Requests you send to borrow pieces from your circles will appear here.',
                    ),
                    _buildHistoryList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Tab _tabLabel(String label) {
    return Tab(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [Text(label)],
      ),
    );
  }

  Widget _buildActiveList({
    required List<ItemRequestModel> items,
    required bool isLoading,
    required String? error,
    required bool isIncoming,
    required Future<void> Function() onRefresh,
    required String emptyTitle,
    required String emptyDescription,
  }) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.forest),
      );
    }
    if (error != null) {
      return _errorState(error, onRefresh);
    }
    if (items.isEmpty) {
      return _emptyState(
        icon: isIncoming ? Icons.inbox_outlined : Icons.outbox_outlined,
        title: emptyTitle,
        description: emptyDescription,
        onRefresh: onRefresh,
      );
    }

    return RefreshIndicator(
      color: AppColors.forest,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) =>
            _buildRequestCard(items[index], isIncoming),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_isLoadingIncoming || _isLoadingOutgoing) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.forest),
      );
    }
    if (_incomingError != null) {
      return _errorState(_incomingError!, _loadIncoming);
    }
    if (_outgoingError != null) {
      return _errorState(_outgoingError!, _loadOutgoing);
    }

    final items = _history;
    if (items.isEmpty) {
      return _emptyState(
        icon: Icons.history_rounded,
        title: 'Your story starts here',
        description: 'Completed, declined, and cancelled borrowing requests will live here.',
        onRefresh: () async {
          await Future.wait([_loadIncoming(), _loadOutgoing()]);
        },
      );
    }

    return RefreshIndicator(
      color: AppColors.forest,
      onRefresh: () async {
        await Future.wait([_loadIncoming(), _loadOutgoing()]);
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildHistoryCard(items[index]),
      ),
    );
  }

  Widget _errorState(String error, Future<void> Function() onRefresh) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 60),
        const Icon(
          Icons.error_outline_rounded,
          size: 42,
          color: AppColors.missing,
        ),
        const SizedBox(height: 14),
        Text(
          error,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String description,
    required Future<void> Function() onRefresh,
  }) {
    return RefreshIndicator(
      color: AppColors.forest,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(32, 56, 32, 32),
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, size: 28, color: AppColors.sage),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Playfair Display',
              color: AppColors.forest,
              fontSize: 22,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(ItemRequestModel request, bool isIncoming) {
    final otherPartyName = isIncoming
        ? request.resolvedRequesterName
        : request.resolvedOwnerName;
    final otherPartyId = isIncoming ? request.requesterId : request.ownerId;
    final initials = otherPartyName.trim().isNotEmpty
        ? otherPartyName.trim().substring(0, 1).toUpperCase()
        : 'M';
    final isProcessing = _processingIds.contains(request.id);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [AppColors.subtleShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.sageWash,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.forest,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => PublicProfileSheet.show(
                    context,
                    userId: otherPartyId,
                    fallbackName: otherPartyName,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          otherPartyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              isIncoming
                                  ? Icons.verified_user_outlined
                                  : Icons.style_outlined,
                              size: 13,
                              color: AppColors.sage,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                request.communityName ?? 'Community shared',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.sage,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusChip(request.status),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 56,
                    height: 56,
                    color: AppColors.surfaceContainerLow,
                    child: PrivateImageView(
                      imageUrl: request.item?.imageUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.contain,
                      backgroundColor: AppColors.surfaceContainerLow,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.item?.name ?? 'Garment piece',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: AppColors.sage,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              request.dateRangeSummary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.sageDark,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (request.message != null &&
              request.message!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '“${request.message}”',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          if (!request.isTerminal) ...[
            const SizedBox(height: 14),
            Container(
              height: 1,
              color: AppColors.outlineVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            if (isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.forest,
                    ),
                  ),
                ),
              )
            else if (isIncoming && request.isPending)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.outlineVariant),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () =>
                          _updateStatus(request, 'declined', 'Decline'),
                      icon: const Icon(Icons.close_rounded, size: 17),
                      label: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () =>
                          _updateStatus(request, 'accepted', 'Accept'),
                      icon: const Icon(Icons.check_rounded, size: 17),
                      label: const Text('Accept'),
                    ),
                  ),
                ],
              )
            else if (!isIncoming && request.isPending)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.missing,
                    side: const BorderSide(color: AppColors.missing),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () =>
                      _updateStatus(request, 'cancelled', 'Cancel'),
                  icon: const Icon(Icons.cancel_outlined, size: 17),
                  label: const Text('Cancel request'),
                ),
              )
            else if (request.isAccepted)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () =>
                      _updateStatus(request, 'completed', 'Mark completed'),
                  icon: const Icon(Icons.task_alt, size: 17),
                  label: const Text('Mark arrangement completed'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryCard(ItemRequestModel request) {
    final isIncoming = _incoming.any((r) => r.id == request.id);
    final otherPartyName = isIncoming
        ? request.resolvedRequesterName
        : request.resolvedOwnerName;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${isIncoming ? 'Requested by' : 'Sent to'} $otherPartyName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              _buildStatusChip(request.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 48,
                  height: 48,
                  color: AppColors.surfaceContainerLow,
                  child: PrivateImageView(
                    imageUrl: request.item?.imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    backgroundColor: AppColors.surfaceContainerLow,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.item?.name ?? 'Garment piece',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      request.dateRangeSummary,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (request.message != null &&
              request.message!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              request.message!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    late final Color background;
    late final Color foreground;
    late final String label;

    switch (status.toLowerCase()) {
      case 'pending':
        background = AppColors.goldFixed.withValues(alpha: 0.65);
        foreground = AppColors.forestDark;
        label = 'Pending review';
        break;
      case 'accepted':
      case 'approved':
        background = AppColors.sageContainer;
        foreground = AppColors.forest;
        label = 'Accepted';
        break;
      case 'declined':
        background = AppColors.errorContainer;
        foreground = AppColors.error;
        label = 'Declined';
        break;
      case 'cancelled':
        background = AppColors.surfaceContainerHigh;
        foreground = AppColors.textSecondary;
        label = 'Cancelled';
        break;
      case 'completed':
        background = AppColors.sageWash;
        foreground = AppColors.forest;
        label = 'Completed';
        break;
      default:
        background = AppColors.surfaceContainerHigh;
        foreground = AppColors.textSecondary;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          color: foreground,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
