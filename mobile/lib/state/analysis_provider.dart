import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../core/models/garment_item.dart';
import '../core/models/outfit_analysis.dart';
import '../core/models/outfit_match.dart';
import '../core/network/api_client.dart';

class AnalysisProvider extends ChangeNotifier {
  OutfitAnalysisResponse? _currentAnalysis;
  List<OutfitAnalysisResponse> _history = [];
  OutfitMatchResponse? _currentMatchResult;
  bool _isAnalyzing = false;
  bool _isMatching = false;
  String? _error;
  XFile? _lastAnalyzedFile;

  OutfitAnalysisResponse? get currentAnalysis => _currentAnalysis;
  List<OutfitAnalysisResponse> get history => _history;
  OutfitMatchResponse? get currentMatchResult => _currentMatchResult;
  bool get isAnalyzing => _isAnalyzing;
  bool get isMatching => _isMatching;
  String? get error => _error;
  XFile? get lastAnalyzedFile => _lastAnalyzedFile;
  int _activeScanToken = 0;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void cancelActiveScan() {
    _activeScanToken++;
    _isAnalyzing = false;
    _error = null;
    notifyListeners();
  }

  Future<bool> retryLastAnalysis() async {
    if (_lastAnalyzedFile == null) return false;
    return analyzeImage(_lastAnalyzedFile!);
  }

  Future<bool> analyzeImage(XFile imageFile) async {
    _lastAnalyzedFile = imageFile;
    _isAnalyzing = true;
    _error = null;
    _currentMatchResult = null;
    final token = ++_activeScanToken;
    notifyListeners();

    try {
      final res = await ApiClient.analyzeOutfitImage(imageFile);
      if (_activeScanToken != token) {
        return false;
      }
      _currentAnalysis = res;
      _history.insert(0, res);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      if (_activeScanToken != token) {
        return false;
      }
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      if (_activeScanToken == token) {
        _isAnalyzing = false;
        notifyListeners();
      }
    }
  }

  void setAnalysis(OutfitAnalysisResponse analysis) {
    _currentAnalysis = analysis;
    _currentMatchResult = null;
    notifyListeners();
  }

  Future<void> loadHistory() async {
    try {
      _history = await ApiClient.getAnalysisHistory();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> matchAgainstWardrobe({List<DetectedFashionItem>? customItems}) async {
    final itemsToMatch = customItems ?? _currentAnalysis?.items;
    if (itemsToMatch == null || itemsToMatch.isEmpty) return false;

    _isMatching = true;
    _error = null;
    notifyListeners();

    try {
      final result = await ApiClient.matchOutfitAgainstWardrobe(
        items: itemsToMatch,
        analysisId: _currentAnalysis?.analysisId,
      );
      _currentMatchResult = result;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isMatching = false;
      notifyListeners();
    }
  }

  void updateDetectedItem(int index, DetectedFashionItem updated) {
    if (_currentAnalysis != null && index >= 0 && index < _currentAnalysis!.items.length) {
      _currentAnalysis!.items[index] = updated;
      notifyListeners();
    }
  }

  /// Completely clears all cached analyses, history, match results, and staged files.
  /// Called on logout or when switching accounts to ensure total session isolation.
  void clear() {
    _currentAnalysis = null;
    _history = [];
    _currentMatchResult = null;
    _isAnalyzing = false;
    _isMatching = false;
    _error = null;
    _lastAnalyzedFile = null;
    notifyListeners();
  }

  @visibleForTesting
  void setHistoryForTesting(List<OutfitAnalysisResponse> history) {
    _history = List.from(history);
    notifyListeners();
  }
}
