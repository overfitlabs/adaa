import 'package:flutter/foundation.dart';
import '../core/models/recommended_outfit.dart';
import '../core/network/api_client.dart';
import 'outfits_provider.dart';

class StylistProvider extends ChangeNotifier {
  String _selectedOccasion = 'Everyday';
  String? _selectedVibe;
  String _customInstructions = '';
  int _refineIndex = 0;
  bool _isLoading = false;
  String? _error;
  OutfitGenerationResponse? _generationResponse;
  List<RecommendedOutfit> _outfits = [];

  String get selectedOccasion => _selectedOccasion;
  String? get selectedVibe => _selectedVibe;
  String get customInstructions => _customInstructions;
  int get refineIndex => _refineIndex;
  bool get isLoading => _isLoading;
  String? get error => _error;
  OutfitGenerationResponse? get generationResponse => _generationResponse;
  List<RecommendedOutfit> get outfits => _outfits;

  void setOccasion(String occasion) {
    if (_selectedOccasion != occasion) {
      _selectedOccasion = occasion;
      _refineIndex = 0;
      notifyListeners();
    }
  }

  void setVibe(String? vibe) {
    if (_selectedVibe != vibe) {
      _selectedVibe = vibe;
      _refineIndex = 0;
      notifyListeners();
    }
  }

  void setCustomInstructions(String instructions) {
    _customInstructions = instructions;
    _refineIndex = 0;
    notifyListeners();
  }

  Future<void> generateOutfits({bool isRefinement = false}) async {
    _isLoading = true;
    _error = null;
    if (isRefinement) {
      _refineIndex++;
    } else {
      _refineIndex = 0;
    }
    notifyListeners();

    try {
      final resp = await ApiClient.generateOutfits(
        occasion: _selectedOccasion,
        vibe: _selectedVibe,
        instructions: _customInstructions,
        refineIndex: _refineIndex,
      );
      _generationResponse = resp;
      _outfits = resp.outfits;
      _error = null;
    } catch (e) {
      _error = e.toString().replaceAll('ApiException: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleSaveOutfit(RecommendedOutfit outfit, OutfitsProvider outfitsProvider) async {
    if (outfit.isSaved && outfit.savedOutfitId != null) {
      // Unsave outfit
      final success = await outfitsProvider.deleteOutfit(outfit.savedOutfitId!);
      if (success) {
        outfit.isSaved = false;
        outfit.savedOutfitId = null;
        notifyListeners();
        return true;
      }
      return false;
    } else {
      // Save outfit
      final success = await outfitsProvider.saveOutfit(
        name: outfit.name,
        occasion: outfit.occasion,
        notes: '${outfit.explanation}\n\nStyling Tips:\n${outfit.stylingTips.map((t) => '• $t').join('\n')}',
        itemIds: outfit.itemIds,
      );
      if (success) {
        outfit.isSaved = true;
        if (outfitsProvider.outfits.isNotEmpty) {
          outfit.savedOutfitId = outfitsProvider.outfits.first.id;
        }
        notifyListeners();
        return true;
      }
      return false;
    }
  }

  /// Total state purge on logout or session expiration
  void clear() {
    _selectedOccasion = 'Everyday';
    _selectedVibe = null;
    _customInstructions = '';
    _refineIndex = 0;
    _isLoading = false;
    _error = null;
    _generationResponse = null;
    _outfits = [];
    notifyListeners();
  }
}
