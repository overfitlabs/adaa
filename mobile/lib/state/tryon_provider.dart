import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../core/models/tryon_task.dart';
import '../core/network/api_client.dart';

class TryOnProvider extends ChangeNotifier {
  TryOnTask? _activeTask;
  bool _isSubmitting = false;
  String? _error;
  Timer? _pollingTimer;
  int _pollAttempts = 0;
  static const int maxPollAttempts = 40; // 40 * 3s = 120s max timeout

  // History state
  List<TryOnTask> _history = [];
  bool _isLoadingHistory = false;
  bool _isLoadingMore = false;
  String? _historyError;
  String? _nextCursor;
  bool _hasMore = false;
  int _totalCount = 0;

  // Default Try-On Model & Friend Mode state
  UserTryOnModel? _defaultModel;
  bool _isLoadingModel = false;
  String? _modelError;
  bool _isFriendMode = false;
  bool _friendConsentAcknowledged = false;
  bool _saveAsDefaultModel = false;

  TryOnTask? get activeTask => _activeTask;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;
  int get pollAttempts => _pollAttempts;

  List<TryOnTask> get history => _history;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get isLoadingMore => _isLoadingMore;
  String? get historyError => _historyError;
  bool get hasMoreHistory => _hasMore;
  int get totalHistoryCount => _totalCount;

  UserTryOnModel? get defaultModel => _defaultModel;
  bool get isLoadingModel => _isLoadingModel;
  String? get modelError => _modelError;
  bool get isFriendMode => _isFriendMode;
  bool get friendConsentAcknowledged => _friendConsentAcknowledged;
  bool get saveAsDefaultModel => _saveAsDefaultModel;

  @visibleForTesting
  bool bypassNetworkForTesting = false;

  Future<void> loadHistory({bool refresh = false}) async {
    if (_isLoadingHistory || bypassNetworkForTesting) return;
    _isLoadingHistory = true;
    _historyError = null;
    if (refresh) {
      _nextCursor = null;
    }
    notifyListeners();

    try {
      final res = await ApiClient.getTryOnHistory(limit: 20);
      _history = res.items;
      _nextCursor = res.nextCursor;
      _hasMore = res.hasMore;
      _totalCount = res.totalCount;
      _historyError = null;
    } catch (e) {
      _historyError = e.toString().replaceAll('ApiException: ', '');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreHistory() async {
    if (_isLoadingMore || !_hasMore || _nextCursor == null) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final res = await ApiClient.getTryOnHistory(
        limit: 20,
        cursor: _nextCursor,
      );
      _history.addAll(res.items);
      _nextCursor = res.nextCursor;
      _hasMore = res.hasMore;
      _totalCount = res.totalCount;
    } catch (e) {
      _historyError = e.toString().replaceAll('ApiException: ', '');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<bool> deleteHistoryItem(String taskId) async {
    try {
      await ApiClient.deleteTryOnTask(taskId);
      _history.removeWhere((item) => item.taskId == taskId);
      _totalCount = (_totalCount - 1).clamp(0, 999999);
      if (_activeTask?.taskId == taskId) {
        _activeTask = null;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _historyError = e.toString().replaceAll('ApiException: ', '');
      notifyListeners();
      return false;
    }
  }

  @visibleForTesting
  void setHistoryForTesting(
    List<TryOnTask> items, {
    bool hasMore = false,
    String? nextCursor,
  }) {
    bypassNetworkForTesting = true;
    _history = List.from(items);
    _totalCount = items.length;
    _hasMore = hasMore;
    _nextCursor = nextCursor;
    _isLoadingHistory = false;
    _historyError = null;
    notifyListeners();
  }

  @visibleForTesting
  void setHistoryErrorForTesting(String err) {
    bypassNetworkForTesting = true;
    _historyError = err;
    _isLoadingHistory = false;
    notifyListeners();
  }

  @visibleForTesting
  void setLoadingHistoryForTesting(bool loading) {
    bypassNetworkForTesting = true;
    _isLoadingHistory = loading;
    notifyListeners();
  }

  void toggleFriendMode(bool enabled) {
    _isFriendMode = enabled;
    if (!enabled) {
      _friendConsentAcknowledged = false;
    }
    notifyListeners();
  }

  void setFriendConsent(bool acknowledged) {
    _friendConsentAcknowledged = acknowledged;
    notifyListeners();
  }

  void setSaveAsDefaultModel(bool save) {
    _saveAsDefaultModel = save;
    notifyListeners();
  }

  Future<void> loadDefaultModel() async {
    if (bypassNetworkForTesting) return;
    _isLoadingModel = true;
    _modelError = null;
    notifyListeners();

    try {
      final model = await ApiClient.getTryOnModel();
      _defaultModel = model.hasModel ? model : null;
      _modelError = null;
    } catch (e) {
      _modelError = e.toString().replaceAll('ApiException: ', '');
    } finally {
      _isLoadingModel = false;
      notifyListeners();
    }
  }

  Future<bool> saveDefaultModel(XFile image) async {
    _isLoadingModel = true;
    _modelError = null;
    notifyListeners();

    try {
      final model = await ApiClient.saveTryOnModel(image);
      _defaultModel = model;
      _modelError = null;
      notifyListeners();
      return true;
    } catch (e) {
      _modelError = e.toString().replaceAll('ApiException: ', '');
      notifyListeners();
      return false;
    } finally {
      _isLoadingModel = false;
      notifyListeners();
    }
  }

  Future<bool> deleteDefaultModel() async {
    _isLoadingModel = true;
    _modelError = null;
    notifyListeners();

    try {
      await ApiClient.deleteTryOnModel();
      _defaultModel = null;
      _modelError = null;
      notifyListeners();
      return true;
    } catch (e) {
      _modelError = e.toString().replaceAll('ApiException: ', '');
      notifyListeners();
      return false;
    } finally {
      _isLoadingModel = false;
      notifyListeners();
    }
  }

  @visibleForTesting
  void setDefaultModelForTesting(UserTryOnModel? model) {
    bypassNetworkForTesting = true;
    _defaultModel = model;
    _isLoadingModel = false;
    notifyListeners();
  }

  Future<bool> startTryOn({
    XFile? userImage,
    XFile? garmentImage,
    String? wardrobeItemId,
    String garmentCategory = 'upper body',
    bool useSavedModel = false,
    bool isFriendTryon = false,
    bool friendConsentAcknowledged = false,
    bool saveAsDefaultModel = false,
  }) async {
    _isSubmitting = true;
    _error = null;
    _activeTask = null;
    _pollAttempts = 0;
    _cancelPolling();
    notifyListeners();

    try {
      final task = await ApiClient.createTryOnTask(
        userImage: userImage,
        garmentImage: garmentImage,
        wardrobeItemId: wardrobeItemId,
        garmentCategory: garmentCategory,
        useSavedModel: useSavedModel,
        isFriendTryon: isFriendTryon,
        friendConsentAcknowledged: friendConsentAcknowledged,
        saveAsDefaultModel: saveAsDefaultModel,
      );
      _activeTask = task;
      _error = null;
      notifyListeners();

      // Begin polling
      _startPolling(task.taskId);
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('ApiException: ', '');
      notifyListeners();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void _startPolling(String taskId) {
    _cancelPolling();
    _pollAttempts = 0;
    // Poll every 3 seconds with bounded retry timeout
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      _pollAttempts++;
      if (_pollAttempts > maxPollAttempts) {
        _cancelPolling();
        _error = 'Virtual Try-On timed out after 2 minutes. Please try again.';
        notifyListeners();
        return;
      }

      try {
        final updated = await ApiClient.pollTryOnTask(taskId);
        _activeTask = updated;
        if (updated.isFailed) {
          _error = updated.errorMessage ?? 'Try-On generation failed. Please try again.';
        }
        notifyListeners();

        if (updated.isSuccess || updated.isFailed) {
          _cancelPolling();
          if (updated.isSuccess) {
            final idx = _history.indexWhere((t) => t.taskId == updated.taskId);
            if (idx >= 0) {
              _history[idx] = updated;
            } else {
              _history.insert(0, updated);
              _totalCount++;
            }
          }
        }
        notifyListeners();
      } catch (e) {
        if (_pollAttempts >= maxPollAttempts) {
          _cancelPolling();
          _error = 'Failed to poll try-on status: ${e.toString()}';
          notifyListeners();
        }
      }
    });
  }

  void _cancelPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void cancelCurrentTask() {
    _cancelPolling();
    _isSubmitting = false;
    _activeTask = null;
    _error = null;
    _pollAttempts = 0;
    notifyListeners();
  }

  void reset() {
    _cancelPolling();
    _activeTask = null;
    _error = null;
    _pollAttempts = 0;
    notifyListeners();
  }

  /// Completely clears active task and polling timer.
  /// Called on logout or when switching accounts to ensure total session isolation.
  void clear() {
    _cancelPolling();
    _activeTask = null;
    _isSubmitting = false;
    _error = null;
    _pollAttempts = 0;
    _history.clear();
    _nextCursor = null;
    _hasMore = false;
    _totalCount = 0;
    _historyError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelPolling();
    super.dispose();
  }
}
