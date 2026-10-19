import 'package:flutter/foundation.dart';
import '../core/models/saved_outfit.dart';
import '../core/network/api_client.dart';

class OutfitsProvider extends ChangeNotifier {
  List<SavedOutfit> _outfits = [];
  bool _isLoading = false;
  String? _error;

  List<SavedOutfit> get outfits => _outfits;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadOutfits() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _outfits = await ApiClient.getSavedOutfits();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveOutfit({
    required String name,
    String? occasion,
    String? notes,
    required List<String> itemIds,
    String? inspirationAnalysisId,
  }) async {
    try {
      final saved = await ApiClient.saveOutfit(
        name: name,
        occasion: occasion,
        notes: notes,
        itemIds: itemIds,
        inspirationAnalysisId: inspirationAnalysisId,
      );
      _outfits.insert(0, saved);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteOutfit(String id) async {
    try {
      await ApiClient.deleteSavedOutfit(id);
      _outfits.removeWhere((o) => o.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
