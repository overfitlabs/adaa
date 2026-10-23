import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/notification_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaa_brand_badge.dart';
import '../../../state/community_provider.dart';
import '../../../state/notification_provider.dart';
import '../../communities/screens/communities_screen.dart';
import '../../communities/screens/community_detail_screen.dart';
import '../../requests/screens/requests_screen.dart';
import '../../../core/widgets/adaa_wordmark.dart';

/// Notifications & Activity Center for `adaa`.
/// Displays borrowing lifecycle events, community decisions, and unread badges.
class NotificationsScreen extends StatefulWidget {
  final bool autoLoad;

  const NotificationsScreen({super.key, this.autoLoad = true});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _showOnlyUnread = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<NotificationProvider>().loadNotifications();
      });
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    final notifProv = context.read<NotificationProvider>();
    if (!notification.isRead) {
      notifProv.markAsRead(notification.id);
    }

    // Deep-linking based on notification context
    if (notification.isBorrowRequest) {
      final initialIndex = notification.eventType == 'borrow_request_created'
          ? 0
          : 1;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RequestsScreen(initialIndex: initialIndex),
        ),
      );
    } else if (notification.isCommunity) {
      if (notification.communityId != null &&
          notification.communityId!.isNotEmpty) {
        final commProv = context.read<CommunityProvider>();
        final allComms = [...commProv.myCommunities, ...commProv.communities];
        final match = allComms
            .where((c) => c.id == notification.communityId)
            .firstOrNull;

        if (match != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CommunityDetailScreen(community: match),
            ),
          );
          return;
        }
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CommunitiesScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifProv = context.watch<NotificationProvider>();
    final allNotifications = notifProv.notifications;
    final displayedNotifications = _showOnlyUnread
        ? allNotifications.where((n) => !n.isRead).toList()
        : allNotifications;
    final unreadCount = notifProv.unreadCount;

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

      // AppBar(
      //         title: const Text(
      //           'activity',
      //           style: TextStyle(
      //             fontWeight: FontWeight.bold,
      //             color: AppColors.espresso,
      //             letterSpacing: -0.5,
      //           ),
      //   ),
      //   actions: [

      //     const SizedBox(width: 8),
      //   ],
      // ),
      body: RefreshIndicator(
        color: AppColors.terracotta,
        onRefresh: () => notifProv.loadNotifications(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsetsGeometry.fromLTRB(20, 0, 20, 0),
              child: const Text(
                'Notifications',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 32,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forest,
                ),
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: AppColors.surface,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text('All (${allNotifications.length})'),
                        selected: !_showOnlyUnread,
                        selectedColor: AppColors.terracottaSoft,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: !_showOnlyUnread
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: !_showOnlyUnread
                              ? AppColors.terracottaDark
                              : AppColors.textSecondary,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _showOnlyUnread = false);
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Unread ($unreadCount)'),
                            if (unreadCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.terracotta,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        selected: _showOnlyUnread,
                        selectedColor: AppColors.terracottaSoft,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: _showOnlyUnread
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _showOnlyUnread
                              ? AppColors.terracottaDark
                              : AppColors.textSecondary,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _showOnlyUnread = true);
                        },
                      ),
                    ],
                  ),
                ),
                if (unreadCount > 0)
                  TextButton.icon(
                    onPressed: () => notifProv.markAllAsRead(),
                    icon: const Icon(
                      Icons.done_all_outlined,
                      size: 16,
                      color: AppColors.terracotta,
                    ),
                    label: const Text(
                      'Read',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.terracotta,
                      ),
                    ),
                  ),
              ],
            ),
            // Content Area
            Expanded(child: _buildBody(notifProv, displayedNotifications)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    NotificationProvider notifProv,
    List<NotificationModel> notifications,
  ) {
    if (notifProv.isLoading && notifications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.terracotta),
      );
    }

    if (notifProv.error != null && notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 12),
              const Text(
                'Could not load notifications',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.espresso,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                notifProv.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => notifProv.loadNotifications(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.sandSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none_outlined,
                  size: 32,
                  color: AppColors.espresso,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _showOnlyUnread ? 'no unread notifications' : 'no activity yet',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.espresso,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _showOnlyUnread
                    ? "You are completely caught up! Tap 'All' to review your past activity history."
                    : 'Activity updates for item borrowing requests and community memberships will appear here.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: notifications.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final notif = notifications[index];
        return _buildNotificationCard(notif);
      },
    );
  }

  Widget _buildNotificationCard(NotificationModel notif) {
    return Container(
      decoration: BoxDecoration(
        color: notif.isRead ? AppColors.surface : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notif.isRead ? AppColors.borderLight : AppColors.sand,
          width: notif.isRead ? 1 : 1.2,
        ),
        boxShadow: notif.isRead
            ? [AppColors.subtleShadow]
            : [AppColors.cardShadow],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handleNotificationTap(notif),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event Icon Avatar
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: notif.iconBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(notif.iconData, size: 20, color: notif.iconColor),
                ),
                const SizedBox(width: 12),

                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              notif.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: notif.isRead
                                    ? FontWeight.w600
                                    : FontWeight.bold,
                                color: AppColors.espresso,
                              ),
                            ),
                          ),
                          Text(
                            notif.formattedRelativeTime,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: notif.isRead
                              ? AppColors.textSecondary
                              : AppColors.espresso,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Context tag
                      Row(
                        children: [
                          if (notif.isBorrowRequest)
                            const AdaaBrandBadge(
                              text: 'borrow request',
                              backgroundColor: AppColors.sandSoft,
                              textColor: AppColors.espresso,
                            )
                          else if (notif.isCommunity)
                            const AdaaBrandBadge(
                              text: 'community',
                              backgroundColor: AppColors.terracottaSoft,
                              textColor: AppColors.espresso,
                            ),
                          const Spacer(),
                          const Text(
                            'Tap to view details',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.forest,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 14,
                            color: AppColors.forest,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Unread Indicator Dot
                if (!notif.isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: const BoxDecoration(
                      color: AppColors.terracotta,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
