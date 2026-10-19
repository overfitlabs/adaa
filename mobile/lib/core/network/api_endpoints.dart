import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class ApiEndpoints {
  // Dynamically configure host based on execution platform
  static String get defaultBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }
    try {
      if (Platform.isAndroid) {
        // Android emulator maps 10.0.2.2 to host machine's localhost
        return 'http://10.0.2.2:8000';
      }
    } catch (_) {}
    return 'http://127.0.0.1:8000';
  }

  static String baseUrl = defaultBaseUrl;

  // Analysis
  static String get analyzeImage => '$baseUrl/api/analysis/analyze-image';
  static String get analysisHistory => '$baseUrl/api/analysis';
  static String analysisDetail(String id) => '$baseUrl/api/analysis/$id';

  // Wardrobe
  static String get wardrobeItems => '$baseUrl/api/wardrobe/items';
  static String wardrobeItemDetail(String id) => '$baseUrl/api/wardrobe/items/$id';
  static String get wardrobeCategories => '$baseUrl/api/wardrobe/categories';
  static String get detectWardrobeItem => '$baseUrl/api/wardrobe/detect-item';

  // Matching
  static String get matchOutfit => '$baseUrl/api/matching/match-outfit';

  // Outfits
  static String get outfits => '$baseUrl/api/outfits';
  static String outfitDetail(String id) => '$baseUrl/api/outfits/$id';

  // Virtual Try-On
  static String get tryOnTasks => '$baseUrl/api/tryon/tasks';
  static String tryOnTaskDetail(String taskId) => '$baseUrl/api/tryon/tasks/$taskId';

  // Recommendations
  static String get recommendations => '$baseUrl/api/recommendations';

  // Health
  static String get health => '$baseUrl/health';

  static String resolveImageUrl(String? urlOrPath) {
    if (urlOrPath == null || urlOrPath.isEmpty) return '';
    if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
      return urlOrPath;
    }
    final clean = urlOrPath.startsWith('/') ? urlOrPath : '/$urlOrPath';
    return '$baseUrl$clean';
  }
}
