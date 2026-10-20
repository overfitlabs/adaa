import 'package:flutter/foundation.dart';
import '../core/models/notification_model.dart';
import '../core/network/api_client.dart';

class NotificationProvider extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;
  bool _unreadOnlyFilter = false;

  List<NotificationModel> get notifications => _notifications;
  List<NotificationModel> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get unreadOnlyFilter => _unreadOnlyFilter;

  @visibleForTesting
  set notifications(List<NotificationModel> value) {
    _notifications = value;
    _unreadCount = value.where((n) => !n.isRead).length;
    notifyListeners();
  }

  @visibleForTesting
  set unreadCount(int value) {
    _unreadCount = value;
    notifyListeners();
  }

  void setUnreadOnlyFilter(bool value) {
    if (_unreadOnlyFilter != value) {
      _unreadOnlyFilter = value;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> loadNotifications({bool silent = false, bool unreadOnly = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final fetched = await ApiClient.getNotifications(unreadOnly: unreadOnly);
      _notifications = fetched;
      _unreadCount = fetched.where((n) => !n.isRead).length;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUnreadCount({bool silent = true}) async {
    try {
      final count = await ApiClient.getUnreadNotificationCount();
      _unreadCount = count;
      notifyListeners();
    } catch (e) {
      if (!silent) {
        _error = e.toString();
        notifyListeners();
      }
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1 && !_notifications[idx].isRead) {
      // Optimistic update
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      if (_unreadCount > 0) {
        _unreadCount--;
      }
      notifyListeners();

      try {
        await ApiClient.markNotificationAsRead(notificationId);
      } catch (e) {
        debugPrint('Failed to mark notification as read on server: $e');
      }
    }
  }

  Future<void> markAllAsRead() async {
    if (_unreadCount == 0 && _notifications.every((n) => n.isRead)) {
      return;
    }

    // Optimistic update
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    _unreadCount = 0;
    notifyListeners();

    try {
      await ApiClient.markAllNotificationsAsRead();
    } catch (e) {
      debugPrint('Failed to mark all notifications as read on server: $e');
    }
  }

  /// Completely clears all notification state and resets unread count.
  /// Called on logout or session expiration to guarantee strict session isolation.
  void clear() {
    _notifications = [];
    _unreadCount = 0;
    _isLoading = false;
    _error = null;
    _unreadOnlyFilter = false;
    notifyListeners();
  }
}
