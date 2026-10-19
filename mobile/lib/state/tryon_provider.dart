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

  TryOnTask? get activeTask => _activeTask;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  Future<bool> startTryOn({
    required XFile userImage,
    XFile? garmentImage,
    String? wardrobeItemId,
    String garmentCategory = 'upper body',
  }) async {
    _isSubmitting = true;
    _error = null;
    _activeTask = null;
    _cancelPolling();
    notifyListeners();

    try {
      final task = await ApiClient.createTryOnTask(
        userImage: userImage,
        garmentImage: garmentImage,
        wardrobeItemId: wardrobeItemId,
        garmentCategory: garmentCategory,
      );
      _activeTask = task;
      _error = null;
      notifyListeners();

      // Begin polling
      _startPolling(task.taskId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void _startPolling(String taskId) {
    _cancelPolling();
    // Poll every 3 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final updated = await ApiClient.pollTryOnTask(taskId);
        _activeTask = updated;
        notifyListeners();

        if (updated.isSuccess || updated.isFailed) {
          _cancelPolling();
        }
      } catch (e) {
        // Continue polling unless max tries exceeded
      }
    });
  }

  void _cancelPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void reset() {
    _cancelPolling();
    _activeTask = null;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelPolling();
    super.dispose();
  }
}
