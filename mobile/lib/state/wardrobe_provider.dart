import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../core/models/garment_item.dart';
import '../core/models/wardrobe_item.dart';
import '../core/network/api_client.dart';

class WardrobeProvider extends ChangeNotifier {
  List<WardrobeItem> _items = [];
  List<Map<String, dynamic>> _categories = [];
  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;

  List<WardrobeItem> get items => _items;
  List<Map<String, dynamic>> get categories => _categories;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadWardrobe({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final items = await ApiClient.getWardrobeItems(
        category: _selectedCategory == 'all' ? null : _selectedCategory,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );
      _items = items;
      _categories = await ApiClient.getCategories();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      loadWardrobe();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    loadWardrobe();
  }

  Future<bool> addItem({
    required String name,
    required String category,
    required String primaryColor,
    String? subCategory,
    String? secondaryColor,
    String? pattern,
    String? material,
    String? fit,
    String? season,
    String? formality,
    String? brand,
    String? size,
    String? condition,
    String? notes,
    List<String> tags = const [],
    String? imagePath,
    XFile? file,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final newItem = await ApiClient.createWardrobeItem(
        name: name,
        category: category,
        primaryColor: primaryColor,
        subCategory: subCategory,
        secondaryColor: secondaryColor,
        pattern: pattern,
        material: material,
        fit: fit,
        season: season,
        formality: formality,
        brand: brand,
        size: size,
        condition: condition,
        notes: notes,
        tags: tags,
        imagePath: imagePath,
        file: file,
      );
      _items.insert(0, newItem);
      _categories = await ApiClient.getCategories();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> bulkAddItems(
    List<DetectedFashionItem> detectedItems, {
    String? sourceAnalysisId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiClient.bulkCreateWardrobeItems(
        items: detectedItems,
        sourceAnalysisId: sourceAnalysisId,
      );
      final savedItems = res['saved_items'] as List<WardrobeItem>? ?? [];
      for (final item in savedItems) {
        _items.removeWhere((i) => i.id == item.id);
        _items.insert(0, item);
      }
      _categories = await ApiClient.getCategories();
      notifyListeners();
      return res;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return {
        'saved_count': 0,
        'failed_count': detectedItems.length,
        'error': e.toString(),
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateItem(String id, Map<String, dynamic> updates) async {
    try {
      final updated = await ApiClient.updateWardrobeItem(id, updates);
      final idx = _items.indexWhere((i) => i.id == id);
      if (idx != -1) {
        _items[idx] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateItemPhoto(String id, XFile file) async {
    try {
      final updated = await ApiClient.updateWardrobeItemPhoto(id, file);
      final idx = _items.indexWhere((i) => i.id == id);
      if (idx != -1) {
        _items[idx] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<WardrobeItem?> refreshItem(String id) async {
    try {
      final updated = await ApiClient.getWardrobeItem(id);
      final idx = _items.indexWhere((i) => i.id == id);
      if (idx != -1) {
        _items[idx] = updated;
        notifyListeners();
      }
      return updated;
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteItem(String id) async {
    try {
      await ApiClient.deleteWardrobeItem(id);
      _items.removeWhere((i) => i.id == id);
      _categories = await ApiClient.getCategories();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
