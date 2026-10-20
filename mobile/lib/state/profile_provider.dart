import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../core/models/user_profile_model.dart';
import '../core/network/api_client.dart';

class ProfileProvider extends ChangeNotifier {
  UserProfileModel? _profile;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  UserProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  @visibleForTesting
  set profile(UserProfileModel? value) {
    _profile = value;
    notifyListeners();
  }

  Future<void> loadProfile({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final prof = await ApiClient.getMyProfile();
      _profile = prof;
      _error = null;
    } catch (e) {
      _error = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
    int? age,
    String? phoneNumber,
    FitPreferencesModel? fitPreferences,
    List<String>? preferredStyles,
    ProfilePrivacySettingsModel? privacySettings,
  }) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final updated = await ApiClient.updateMyProfile(
        displayName: displayName,
        bio: bio,
        avatarUrl: avatarUrl,
        age: age,
        phoneNumber: phoneNumber,
        fitPreferences: fitPreferences,
        preferredStyles: preferredStyles,
        privacySettings: privacySettings,
      );
      _profile = updated;
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePrivacy(ProfilePrivacySettingsModel settings) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final updatedSettings = await ApiClient.updateMyPrivacySettings(settings);
      if (_profile != null) {
        _profile = UserProfileModel(
          id: _profile!.id,
          email: _profile!.email,
          displayName: _profile!.displayName,
          avatarUrl: _profile!.avatarUrl,
          bio: _profile!.bio,
          age: _profile!.age,
          phoneNumber: _profile!.phoneNumber,
          fitPreferences: _profile!.fitPreferences,
          preferredStyles: _profile!.preferredStyles,
          privacySettings: updatedSettings,
          sharedCommunitiesCount: _profile!.sharedCommunitiesCount,
          sharedItemsCount: _profile!.sharedItemsCount,
        );
      }
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadAvatar(XFile file) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final newUrl = await ApiClient.uploadProfileAvatar(file);
      if (_profile != null) {
        _profile = UserProfileModel(
          id: _profile!.id,
          email: _profile!.email,
          displayName: _profile!.displayName,
          avatarUrl: newUrl,
          bio: _profile!.bio,
          age: _profile!.age,
          phoneNumber: _profile!.phoneNumber,
          fitPreferences: _profile!.fitPreferences,
          preferredStyles: _profile!.preferredStyles,
          privacySettings: _profile!.privacySettings,
          sharedCommunitiesCount: _profile!.sharedCommunitiesCount,
          sharedItemsCount: _profile!.sharedItemsCount,
        );
      }
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Completely clears cached profile and privacy details.
  /// Called on logout or when switching accounts to ensure total session isolation.
  void clear() {
    _profile = null;
    _isLoading = false;
    _isSaving = false;
    _error = null;
    notifyListeners();
  }
}
