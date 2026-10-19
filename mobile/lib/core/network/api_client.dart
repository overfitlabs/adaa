import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../models/garment_item.dart';
import '../models/outfit_analysis.dart';
import '../models/outfit_match.dart';
import '../models/saved_outfit.dart';
import '../models/style_recommendation.dart';
import '../models/tryon_task.dart';
import '../models/wardrobe_item.dart';
import 'api_endpoints.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiClient {
  static const Duration _timeout = Duration(seconds: 45);

  // Health
  static Future<bool> checkHealth() async {
    try {
      final res = await http.get(Uri.parse(ApiEndpoints.health)).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Outfit Analysis
  static Future<OutfitAnalysisResponse> analyzeOutfitImage(XFile imageFile) async {
    final uri = Uri.parse(ApiEndpoints.analyzeImage);
    final request = http.MultipartRequest('POST', uri);

    final bytes = await imageFile.readAsBytes();
    final ext = imageFile.name.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: imageFile.name.isNotEmpty ? imageFile.name : 'upload.jpg',
        contentType: MediaType.parse(mimeType),
      ),
    );

    final streamedResponse = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return OutfitAnalysisResponse.fromJson(json);
    } else {
      final error = _extractError(response.body);
      throw ApiException(error, response.statusCode);
    }
  }

  static Future<List<OutfitAnalysisResponse>> getAnalysisHistory() async {
    final res = await http.get(Uri.parse(ApiEndpoints.analysisHistory)).timeout(_timeout);
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return list.map((e) => OutfitAnalysisResponse.fromJson(e)).toList();
    }
    throw ApiException('Failed to fetch analysis history', res.statusCode);
  }

  // Wardrobe Items
  static Future<Map<String, dynamic>> detectWardrobeItemFromPhoto(XFile imageFile) async {
    final uri = Uri.parse(ApiEndpoints.detectWardrobeItem);
    final request = http.MultipartRequest('POST', uri);
    final bytes = await imageFile.readAsBytes();
    final ext = imageFile.name.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: imageFile.name,
        contentType: MediaType.parse(mimeType),
      ),
    );

    final streamed = await request.send().timeout(_timeout);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<WardrobeItem> createWardrobeItem({
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
    List<String> tags = const [],
    String? imagePath,
    XFile? file,
  }) async {
    final uri = Uri.parse(ApiEndpoints.wardrobeItems);
    final request = http.MultipartRequest('POST', uri);

    request.fields['name'] = name;
    request.fields['category'] = category;
    request.fields['primary_color'] = primaryColor;
    if (subCategory != null) request.fields['sub_category'] = subCategory;
    if (secondaryColor != null) request.fields['secondary_color'] = secondaryColor;
    if (pattern != null) request.fields['pattern'] = pattern;
    if (material != null) request.fields['material'] = material;
    if (fit != null) request.fields['fit'] = fit;
    if (season != null) request.fields['season'] = season;
    if (formality != null) request.fields['formality'] = formality;
    request.fields['tags'] = jsonEncode(tags);

    if (imagePath != null) {
      request.fields['image_path'] = imagePath;
    }

    if (file != null) {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name,
          contentType: MediaType.parse(mimeType),
        ),
      );
    }

    final streamed = await request.send().timeout(_timeout);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 201) {
      return WardrobeItem.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<List<WardrobeItem>> getWardrobeItems({
    String? category,
    String? search,
    String? color,
  }) async {
    final params = <String, String>{};
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (color != null && color.isNotEmpty) params['color'] = color;

    final uri = Uri.parse(ApiEndpoints.wardrobeItems).replace(queryParameters: params);
    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return list.map((i) => WardrobeItem.fromJson(i)).toList();
    }
    throw ApiException('Failed to load wardrobe items', res.statusCode);
  }

  static Future<WardrobeItem> updateWardrobeItem(String id, Map<String, dynamic> updates) async {
    final uri = Uri.parse(ApiEndpoints.wardrobeItemDetail(id));
    final res = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(updates),
    ).timeout(_timeout);

    if (res.statusCode == 200) {
      return WardrobeItem.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<void> deleteWardrobeItem(String id) async {
    final uri = Uri.parse(ApiEndpoints.wardrobeItemDetail(id));
    final res = await http.delete(uri).timeout(_timeout);
    if (res.statusCode != 204) {
      throw ApiException('Failed to delete item', res.statusCode);
    }
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    final uri = Uri.parse(ApiEndpoints.wardrobeCategories);
    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode == 200) {
      return (jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>).cast<Map<String, dynamic>>();
    }
    return [];
  }

  // Matching
  static Future<OutfitMatchResponse> matchOutfitAgainstWardrobe({
    required List<DetectedFashionItem> items,
    String? analysisId,
  }) async {
    final uri = Uri.parse(ApiEndpoints.matchOutfit);
    final body = jsonEncode({
      'items': items.map((i) => i.toJson()).toList(),
      'analysis_id': analysisId,
    });

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(_timeout);

    if (res.statusCode == 200) {
      return OutfitMatchResponse.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  // Saved Outfits
  static Future<SavedOutfit> saveOutfit({
    required String name,
    String? occasion,
    String? notes,
    required List<String> itemIds,
    String? inspirationAnalysisId,
  }) async {
    final uri = Uri.parse(ApiEndpoints.outfits);
    final body = jsonEncode({
      'name': name,
      'occasion': occasion,
      'notes': notes,
      'item_ids': itemIds,
      'inspiration_analysis_id': inspirationAnalysisId,
    });

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(_timeout);

    if (res.statusCode == 201) {
      return SavedOutfit.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<List<SavedOutfit>> getSavedOutfits() async {
    final res = await http.get(Uri.parse(ApiEndpoints.outfits)).timeout(_timeout);
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return list.map((o) => SavedOutfit.fromJson(o)).toList();
    }
    throw ApiException('Failed to load saved outfits', res.statusCode);
  }

  static Future<void> deleteSavedOutfit(String id) async {
    final res = await http.delete(Uri.parse(ApiEndpoints.outfitDetail(id))).timeout(_timeout);
    if (res.statusCode != 204) {
      throw ApiException('Failed to delete outfit', res.statusCode);
    }
  }

  // Virtual Try-On
  static Future<TryOnTask> createTryOnTask({
    required XFile userImage,
    XFile? garmentImage,
    String? wardrobeItemId,
    String garmentCategory = 'upper body',
  }) async {
    final uri = Uri.parse(ApiEndpoints.tryOnTasks);
    final request = http.MultipartRequest('POST', uri);

    final userBytes = await userImage.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes(
        'user_image',
        userBytes,
        filename: userImage.name.isNotEmpty ? userImage.name : 'user.jpg',
        contentType: MediaType.parse('image/jpeg'),
      ),
    );

    if (garmentImage != null) {
      final gBytes = await garmentImage.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'garment_image',
          gBytes,
          filename: garmentImage.name.isNotEmpty ? garmentImage.name : 'garment.jpg',
          contentType: MediaType.parse('image/jpeg'),
        ),
      );
    } else if (wardrobeItemId != null) {
      request.fields['wardrobe_item_id'] = wardrobeItemId;
    }

    request.fields['garment_category'] = garmentCategory;

    final streamed = await request.send().timeout(_timeout);
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 202) {
      return TryOnTask.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<TryOnTask> pollTryOnTask(String taskId) async {
    final uri = Uri.parse(ApiEndpoints.tryOnTaskDetail(taskId));
    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode == 200) {
      return TryOnTask.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException('Failed to poll try-on task', res.statusCode);
  }

  // Recommendations
  static Future<List<StyleRecommendation>> getRecommendations() async {
    final res = await http.get(Uri.parse(ApiEndpoints.recommendations)).timeout(_timeout);
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return list.map((r) => StyleRecommendation.fromJson(r)).toList();
    }
    return [];
  }

  static String _extractError(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map && json.containsKey('detail')) {
        return json['detail'].toString();
      }
    } catch (_) {}
    return 'An unexpected error occurred. Please try again.';
  }
}
