import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

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
import '../models/community_model.dart';
import '../models/user_profile_model.dart';
import '../models/notification_model.dart';
import '../models/recommended_outfit.dart';
import '../models/stylist_chat_model.dart';
import 'api_endpoints.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]) {
    if (statusCode == 401 && ApiClient.authToken != null) {
      ApiClient.authToken = null;
      ApiClient.onSessionExpired?.call();
    }
  }

  @override
  String toString() => message;
}

class ApiClient {
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _analysisTimeout = Duration(seconds: 60);
  static const Duration _timeout = _defaultTimeout;

  /// Optional Bearer token from Supabase session
  static String? authToken;

  /// Callback invoked when any authenticated request receives a 401 Unauthorized status
  static void Function()? onSessionExpired;

  static Map<String, String> get authHeaders {
    final headers = <String, String>{};
    if (authToken != null && authToken!.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${authToken!.trim()}';
    }
    return headers;
  }

  static Map<String, String> get _defaultHeaders {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...authHeaders,
    };
    return headers;
  }

  static ApiException _handleNetworkError(dynamic error) {
    if (error is ApiException) return error;
    if (error is TimeoutException) {
      return ApiException(
        'Request timed out. The server at ${ApiEndpoints.baseUrl} took too long to respond. If you are testing on a physical phone, ensure "adb reverse tcp:8000 tcp:8000" is active or configure your computer\'s Wi-Fi IP.',
        408,
      );
    }
    if (error is SocketException) {
      return ApiException(
        'Cannot connect to server at ${ApiEndpoints.baseUrl}. If on a physical phone, run "adb reverse tcp:8000 tcp:8000" in terminal or configure host IP in Connection Settings.',
        503,
      );
    }
    if (error is http.ClientException) {
      return ApiException(
        'Connection failed: ${error.message}. Verify that the backend is running at ${ApiEndpoints.baseUrl}.',
        503,
      );
    }
    return ApiException(error.toString());
  }

  // Health
  static Future<bool> checkHealth([String? url]) async {
    final target = url != null ? '$url/health' : ApiEndpoints.health;
    try {
      final res = await http
          .get(Uri.parse(target))
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Automatically detects reachable backend URL across USB adb reverse, emulator, and local network
  static Future<bool> autoDetectBaseUrl() async {
    if (await checkHealth()) return true;

    for (final candidate in ApiEndpoints.candidateUrls) {
      if (candidate == ApiEndpoints.baseUrl) continue;
      if (await checkHealth(candidate)) {
        ApiEndpoints.setBaseUrl(candidate);
        return true;
      }
    }
    return false;
  }

  // Outfit Analysis
  static Future<OutfitAnalysisResponse> analyzeOutfitImage(
    XFile imageFile,
  ) async {
    try {
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

      if (authToken != null && authToken!.trim().isNotEmpty) {
        request.headers['Authorization'] = 'Bearer ${authToken!.trim()}';
      }

      final streamedResponse = await request.send().timeout(_analysisTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final initial = OutfitAnalysisResponse.fromJson(json);

        // If MediaFlows is enabled on server and analysis is pending/processing, poll until ready
        if (initial.status.toLowerCase() == 'processing' || initial.status.toLowerCase() == 'pending') {
          return await pollScanUntilComplete(initial.analysisId);
        }

        return initial;
      } else {
        final error = _extractError(response.body);
        throw ApiException(error, response.statusCode);
      }
    } catch (e) {
      throw _handleNetworkError(e);
    }
  }

  static Future<Map<String, dynamic>> getScanStatus(String scanId) async {
    try {
      final uri = Uri.parse(ApiEndpoints.scanStatus(scanId));
      final response = await http.get(uri, headers: _defaultHeaders).timeout(_timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } else {
        final error = _extractError(response.body);
        throw ApiException(error, response.statusCode);
      }
    } catch (e) {
      throw _handleNetworkError(e);
    }
  }

  static Future<OutfitAnalysisResponse> pollScanUntilComplete(
    String scanId, {
    Duration timeout = const Duration(seconds: 35),
    Duration interval = const Duration(milliseconds: 1500),
  }) async {
    final startTime = DateTime.now();
    while (DateTime.now().difference(startTime) < timeout) {
      await Future.delayed(interval);
      final statusData = await getScanStatus(scanId);
      final status = (statusData['status'] as String? ?? 'processing').toLowerCase();

      if (status == 'completed') {
        final resultData = statusData['result'] as Map<String, dynamic>?;
        if (resultData != null) {
          return OutfitAnalysisResponse.fromJson(resultData);
        }
        return await getAnalysisDetail(scanId);
      } else if (status == 'failed') {
        final err = statusData['error'] as String? ?? 'Outfit analysis failed';
        throw ApiException(err, 500);
      }
    }
    throw ApiException('Scan timed out waiting for results', 504);
  }

  static Future<OutfitAnalysisResponse> getAnalysisDetail(String analysisId) async {
    final res = await http
        .get(Uri.parse(ApiEndpoints.analysisDetail(analysisId)), headers: _defaultHeaders)
        .timeout(_timeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return OutfitAnalysisResponse.fromJson(json);
    }
    throw ApiException('Failed to fetch analysis details', res.statusCode);
  }

  static Future<List<OutfitAnalysisResponse>> getAnalysisHistory() async {
    final res = await http
        .get(Uri.parse(ApiEndpoints.analysisHistory), headers: _defaultHeaders)
        .timeout(_timeout);
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return list.map((e) => OutfitAnalysisResponse.fromJson(e)).toList();
    }
    throw ApiException('Failed to fetch analysis history', res.statusCode);
  }

  // Auth Profile
  static Future<Map<String, dynamic>> getCurrentUser() async {
    final res = await http
        .get(Uri.parse(ApiEndpoints.authMe), headers: _defaultHeaders)
        .timeout(_timeout);
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    final error = _extractError(res.body);
    throw ApiException(error, res.statusCode);
  }

  // Wardrobe Items Detection (Strictly separated from outfit analysis history)
  static Future<Map<String, dynamic>> detectWardrobeItemFromPhoto(
    XFile imageFile,
  ) async {
    try {
      final uri = Uri.parse(ApiEndpoints.detectWardrobeItem);
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

      if (authToken != null && authToken!.trim().isNotEmpty) {
        request.headers['Authorization'] = 'Bearer ${authToken!.trim()}';
      }

      final streamed = await request.send().timeout(_analysisTimeout);
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      final error = _extractError(res.body);
      throw ApiException(error, res.statusCode);
    } catch (e) {
      throw _handleNetworkError(e);
    }
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
    String? brand,
    String? size,
    String? condition,
    String? notes,
    List<String> tags = const [],
    String? imagePath,
    XFile? file,
  }) async {
    final uri = Uri.parse(ApiEndpoints.wardrobeItems);
    final request = http.MultipartRequest('POST', uri);

    request.fields['name'] = name;
    request.fields['category'] = category;
    request.fields['primary_color'] = primaryColor;
    if (subCategory != null && subCategory.isNotEmpty) {
      request.fields['sub_category'] = subCategory;
    }
    if (secondaryColor != null && secondaryColor.isNotEmpty) {
      request.fields['secondary_color'] = secondaryColor;
    }
    if (pattern != null && pattern.isNotEmpty) {
      request.fields['pattern'] = pattern;
    }
    if (material != null && material.isNotEmpty) {
      request.fields['material'] = material;
    }
    if (fit != null && fit.isNotEmpty) request.fields['fit'] = fit;
    if (season != null && season.isNotEmpty) request.fields['season'] = season;
    if (formality != null && formality.isNotEmpty) {
      request.fields['formality'] = formality;
    }
    if (brand != null && brand.isNotEmpty) request.fields['brand'] = brand;
    if (size != null && size.isNotEmpty) request.fields['size'] = size;
    if (condition != null && condition.isNotEmpty) {
      request.fields['condition'] = condition;
    }
    if (notes != null && notes.isNotEmpty) request.fields['notes'] = notes;
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

    if (authToken != null && authToken!.trim().isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${authToken!.trim()}';
    }

    final streamed = await request.send().timeout(_timeout);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 201) {
      return WardrobeItem.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<Map<String, dynamic>> bulkCreateWardrobeItems({
    required List<DetectedFashionItem> items,
    String? sourceAnalysisId,
  }) async {
    final uri = Uri.parse(ApiEndpoints.wardrobeBulkItems);
    final payload = {
      'source_analysis_id': sourceAnalysisId,
      'items': items.map((i) {
        return {
          'client_id': i.id,
          'name': i.name,
          'category': i.category,
          'sub_category': i.subCategory,
          'primary_color': i.primaryColor,
          'secondary_color': i.secondaryColor,
          'pattern': i.attributes.pattern,
          'material': i.attributes.material,
          'fit': i.attributes.fit,
          'season': i.attributes.season,
          'formality': i.attributes.formality,
          'image_path': i.extractedImagePath,
          'extracted_image_url': i.extractedImageUrl,
          'tags': [
            if (i.subCategory != null) i.subCategory!,
            if (i.attributes.formality != null) i.attributes.formality!,
          ],
        };
      }).toList(),
    };

    final res = await http
        .post(uri, headers: _defaultHeaders, body: jsonEncode(payload))
        .timeout(_timeout);

    if (res.statusCode == 201) {
      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      final savedItems = <WardrobeItem>[];
      for (final r in results) {
        if (r['success'] == true && r['item'] != null) {
          savedItems.add(WardrobeItem.fromJson(r['item']));
        }
      }
      return {
        'saved_count': data['saved_count'] ?? 0,
        'failed_count': data['failed_count'] ?? 0,
        'saved_items': savedItems,
        'raw_results': results,
      };
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<List<WardrobeItem>> getWardrobeItems({
    String? category,
    String? search,
    String? color,
    String? brand,
  }) async {
    final params = <String, String>{};
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (color != null && color.isNotEmpty) params['color'] = color;
    if (brand != null && brand.isNotEmpty) params['brand'] = brand;

    final uri = Uri.parse(ApiEndpoints.wardrobeItems)
        .replace(queryParameters: params);
    final res = await http.get(uri, headers: _defaultHeaders).timeout(_timeout);
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return list.map((i) => WardrobeItem.fromJson(i)).toList();
    }
    throw ApiException('Failed to load wardrobe items', res.statusCode);
  }

  static Future<WardrobeItem> getWardrobeItem(String id) async {
    final uri = Uri.parse(ApiEndpoints.wardrobeItemDetail(id));
    final res = await http.get(uri, headers: _defaultHeaders).timeout(_timeout);
    if (res.statusCode == 200) {
      return WardrobeItem.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<WardrobeItem> updateWardrobeItem(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final uri = Uri.parse(ApiEndpoints.wardrobeItemDetail(id));
    final res = await http
        .put(uri, headers: _defaultHeaders, body: jsonEncode(updates))
        .timeout(_timeout);

    if (res.statusCode == 200) {
      return WardrobeItem.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<WardrobeItem> updateWardrobeItemPhoto(
    String id,
    XFile file,
  ) async {
    final uri = Uri.parse(ApiEndpoints.wardrobeItemPhoto(id));
    final request = http.MultipartRequest('PUT', uri);

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

    if (authToken != null && authToken!.trim().isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${authToken!.trim()}';
    }

    final streamed = await request.send().timeout(_timeout);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200) {
      return WardrobeItem.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<void> deleteWardrobeItem(String id) async {
    final uri = Uri.parse(ApiEndpoints.wardrobeItemDetail(id));
    final res = await http
        .delete(uri, headers: _defaultHeaders)
        .timeout(_timeout);
    if (res.statusCode != 204) {
      throw ApiException('Failed to delete item', res.statusCode);
    }
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    final uri = Uri.parse(ApiEndpoints.wardrobeCategories);
    final res = await http.get(uri, headers: _defaultHeaders).timeout(_timeout);
    if (res.statusCode == 200) {
      return (jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>)
          .cast<Map<String, dynamic>>();
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

    final res = await http
        .post(uri, headers: _defaultHeaders, body: body)
        .timeout(_timeout);

    if (res.statusCode == 200) {
      return OutfitMatchResponse.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)),
      );
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

    final res = await http
        .post(uri, headers: _defaultHeaders, body: body)
        .timeout(_timeout);

    if (res.statusCode == 201) {
      return SavedOutfit.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<List<SavedOutfit>> getSavedOutfits() async {
    final res = await http
        .get(Uri.parse(ApiEndpoints.outfits), headers: _defaultHeaders)
        .timeout(_timeout);
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return list.map((o) => SavedOutfit.fromJson(o)).toList();
    }
    throw ApiException('Failed to load saved outfits', res.statusCode);
  }

  static Future<void> deleteSavedOutfit(String id) async {
    final res = await http
        .delete(
          Uri.parse(ApiEndpoints.outfitDetail(id)),
          headers: _defaultHeaders,
        )
        .timeout(_timeout);
    if (res.statusCode != 204) {
      throw ApiException('Failed to delete outfit', res.statusCode);
    }
  }

  // Virtual Try-On
  static Future<TryOnTask> createTryOnTask({
    XFile? userImage,
    XFile? garmentImage,
    String? wardrobeItemId,
    String? inspirationAnalysisId,
    String? inspirationItemId,
    String? inspirationImageUrl,
    String garmentCategory = 'upper body',
    bool useSavedModel = false,
    bool isFriendTryon = false,
    bool friendConsentAcknowledged = false,
    bool saveAsDefaultModel = false,
  }) async {
    final uri = Uri.parse(ApiEndpoints.tryOnTasks);
    final request = http.MultipartRequest('POST', uri);

    if (userImage != null) {
      final userBytes = await userImage.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'user_image',
          userBytes,
          filename: userImage.name.isNotEmpty ? userImage.name : 'user.jpg',
          contentType: MediaType.parse('image/jpeg'),
        ),
      );
    }

    if (garmentImage != null) {
      final gBytes = await garmentImage.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'garment_image',
          gBytes,
          filename: garmentImage.name.isNotEmpty
              ? garmentImage.name
              : 'garment.jpg',
          contentType: MediaType.parse('image/jpeg'),
        ),
      );
    } else if (wardrobeItemId != null) {
      request.fields['wardrobe_item_id'] = wardrobeItemId;
    }

    if (inspirationAnalysisId != null && inspirationAnalysisId.trim().isNotEmpty) {
      request.fields['inspiration_analysis_id'] = inspirationAnalysisId.trim();
    }
    if (inspirationItemId != null && inspirationItemId.trim().isNotEmpty) {
      request.fields['inspiration_item_id'] = inspirationItemId.trim();
    }
    if (inspirationImageUrl != null && inspirationImageUrl.trim().isNotEmpty) {
      request.fields['inspiration_image_url'] = inspirationImageUrl.trim();
    }

    request.fields['garment_category'] = garmentCategory;
    if (useSavedModel) request.fields['use_saved_model'] = 'true';
    if (isFriendTryon) request.fields['is_friend_tryon'] = 'true';
    if (friendConsentAcknowledged) {
      request.fields['friend_consent_acknowledged'] = 'true';
    }
    if (saveAsDefaultModel) request.fields['save_as_default_model'] = 'true';

    if (authToken != null && authToken!.trim().isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${authToken!.trim()}';
    }

    final streamed = await request.send().timeout(_timeout);
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 201 || res.statusCode == 202) {
      return TryOnTask.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<UserTryOnModel> getTryOnModel() async {
    final res = await http
        .get(Uri.parse(ApiEndpoints.tryOnModel), headers: _defaultHeaders)
        .timeout(_timeout);
    if (res.statusCode == 200) {
      return UserTryOnModel.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException('Failed to load try-on model', res.statusCode);
  }

  static Future<UserTryOnModel> saveTryOnModel(XFile image) async {
    final uri = Uri.parse(ApiEndpoints.tryOnModel);
    final request = http.MultipartRequest('POST', uri);
    final bytes = await image.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: image.name.isNotEmpty ? image.name : 'model.jpg',
        contentType: MediaType.parse('image/jpeg'),
      ),
    );

    if (authToken != null && authToken!.trim().isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${authToken!.trim()}';
    }

    final streamed = await request.send().timeout(_analysisTimeout);
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 200 || res.statusCode == 201) {
      return UserTryOnModel.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<void> deleteTryOnModel() async {
    final res = await http
        .delete(Uri.parse(ApiEndpoints.tryOnModel), headers: _defaultHeaders)
        .timeout(_timeout);
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw ApiException('Failed to delete try-on model', res.statusCode);
    }
  }

  static Future<TryOnTask> pollTryOnTask(String taskId) async {
    final uri = Uri.parse(ApiEndpoints.tryOnTaskDetail(taskId));
    final res = await http.get(uri, headers: _defaultHeaders).timeout(_timeout);
    if (res.statusCode == 200) {
      return TryOnTask.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException('Failed to poll try-on task', res.statusCode);
  }

  static Future<TryOnHistoryResponseModel> getTryOnHistory({
    int limit = 20,
    String? cursor,
    String? status,
  }) async {
    final uri = Uri.parse(
      ApiEndpoints.tryOnHistory(limit: limit, cursor: cursor, status: status),
    );
    final res = await http.get(uri, headers: _defaultHeaders).timeout(_timeout);
    if (res.statusCode == 200) {
      return TryOnHistoryResponseModel.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)),
      );
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<bool> deleteTryOnTask(String taskId) async {
    final uri = Uri.parse(ApiEndpoints.tryOnTaskDetail(taskId));
    final res = await http.delete(uri, headers: _defaultHeaders).timeout(_timeout);
    if (res.statusCode == 204 || res.statusCode == 200) {
      return true;
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  // Recommendations & AI Stylist
  static Future<List<StyleRecommendation>> getRecommendations() async {
    final res = await http
        .get(Uri.parse(ApiEndpoints.recommendations), headers: _defaultHeaders)
        .timeout(_timeout);
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return list.map((r) => StyleRecommendation.fromJson(r)).toList();
    }
    return [];
  }

  static Future<OutfitGenerationResponse> generateOutfits({
    String? occasion,
    String? vibe,
    String? instructions,
    int? refineIndex,
    List<String>? excludeItemIds,
  }) async {
    final payload = <String, dynamic>{
      if (occasion != null && occasion.trim().isNotEmpty)
        'occasion': occasion.trim(),
      if (vibe != null && vibe.trim().isNotEmpty) 'vibe': vibe.trim(),
      if (instructions != null && instructions.trim().isNotEmpty)
        'instructions': instructions.trim(),
      'refine_index': ?refineIndex,
      'exclude_item_ids': ?excludeItemIds,
    };

    final res = await http
        .post(
          Uri.parse(ApiEndpoints.generateRecommendations),
          headers: _defaultHeaders,
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    if (res.statusCode == 200) {
      return OutfitGenerationResponse.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)),
      );
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  // Communities & Shared Closets
  static Future<List<CommunityModel>> getCommunities({String? query}) async {
    var uri = Uri.parse(ApiEndpoints.communities);
    if (query != null && query.trim().isNotEmpty) {
      uri = uri.replace(queryParameters: {'query': query.trim()});
    }
    final res = await http.get(uri, headers: _defaultHeaders).timeout(_timeout);
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return list.map((c) => CommunityModel.fromJson(c)).toList();
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<List<CommunityModel>> getMyCommunities() async {
    final res = await http
        .get(Uri.parse(ApiEndpoints.myCommunities), headers: _defaultHeaders)
        .timeout(_timeout);
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return list.map((c) => CommunityModel.fromJson(c)).toList();
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<CommunityModel> getCommunityDetail(String id) async {
    final res = await http
        .get(
          Uri.parse(ApiEndpoints.communityDetail(id)),
          headers: _defaultHeaders,
        )
        .timeout(_timeout);
    if (res.statusCode == 200) {
      return CommunityModel.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<CommunityModel> createCommunity({
    required String name,
    String? description,
    bool isPrivate = true,
  }) async {
    final body = jsonEncode({
      'name': name.trim(),
      'description': description?.trim().isEmpty == true
          ? null
          : description?.trim(),
      'is_private': isPrivate,
    });
    final res = await http
        .post(
          Uri.parse(ApiEndpoints.communities),
          headers: _defaultHeaders,
          body: body,
        )
        .timeout(_timeout);
    if (res.statusCode == 201) {
      return CommunityModel.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<List<CommunityMemberModel>> getCommunityMembers(
    String commId,
  ) async {
    final res = await http
        .get(
          Uri.parse(ApiEndpoints.communityMembers(commId)),
          headers: _defaultHeaders,
        )
        .timeout(_timeout);
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return list.map((m) => CommunityMemberModel.fromJson(m)).toList();
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<CommunityMemberModel> joinCommunity(String commId) async {
    final res = await http
        .post(
          Uri.parse(ApiEndpoints.communityJoin(commId)),
          headers: _defaultHeaders,
        )
        .timeout(_timeout);
    if (res.statusCode == 200) {
      return CommunityMemberModel.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)),
      );
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<void> leaveCommunity(String commId) async {
    final res = await http
        .post(
          Uri.parse(ApiEndpoints.communityLeave(commId)),
          headers: _defaultHeaders,
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw ApiException(_extractError(res.body), res.statusCode);
    }
  }

  static Future<CommunityMemberModel> approveJoinRequest(
    String commId,
    String userId,
  ) async {
    final res = await http
        .post(
          Uri.parse(ApiEndpoints.communityApproveMember(commId, userId)),
          headers: _defaultHeaders,
        )
        .timeout(_timeout);
    if (res.statusCode == 200) {
      return CommunityMemberModel.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)),
      );
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<CommunityMemberModel> rejectJoinRequest(
    String commId,
    String userId,
  ) async {
    final res = await http
        .post(
          Uri.parse(ApiEndpoints.communityRejectMember(commId, userId)),
          headers: _defaultHeaders,
        )
        .timeout(_timeout);
    if (res.statusCode == 200) {
      return CommunityMemberModel.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)),
      );
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<void> removeCommunityMember(
    String commId,
    String userId,
  ) async {
    final res = await http
        .delete(
          Uri.parse(ApiEndpoints.communityRemoveMember(commId, userId)),
          headers: _defaultHeaders,
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw ApiException(_extractError(res.body), res.statusCode);
    }
  }

  static Future<CommunityMemberModel> updateMemberRole(
    String commId,
    String userId,
    String role,
  ) async {
    final res = await http
        .patch(
          Uri.parse(ApiEndpoints.communityMemberRole(commId, userId)),
          headers: _defaultHeaders,
          body: jsonEncode({'role': role}),
        )
        .timeout(_timeout);
    if (res.statusCode == 200) {
      return CommunityMemberModel.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)),
      );
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<List<CommunityListingModel>> getCommunityListings(
    String commId, {
    String? category,
    String? search,
  }) async {
    var uri = Uri.parse(ApiEndpoints.communityListings(commId));
    final params = <String, String>{};
    if (category != null && category.trim().isNotEmpty && category != 'all') {
      params['category'] = category.trim();
    }
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (params.isNotEmpty) {
      uri = uri.replace(queryParameters: params);
    }
    final res = await http.get(uri, headers: _defaultHeaders).timeout(_timeout);
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return list.map((l) => CommunityListingModel.fromJson(l)).toList();
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<List<SharedClosetItemModel>> getCrossCommunitySharedCloset({
    String? category,
    String? search,
  }) async {
    var uri = Uri.parse(ApiEndpoints.sharedCloset);
    final params = <String, String>{};
    if (category != null && category.trim().isNotEmpty && category != 'all') {
      params['category'] = category.trim();
    }
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (params.isNotEmpty) {
      uri = uri.replace(queryParameters: params);
    }
    final res = await http.get(uri, headers: _defaultHeaders).timeout(_timeout);
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return list.map((s) => SharedClosetItemModel.fromJson(s)).toList();
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<CommunityListingModel> listWardrobeItemInCommunity(
    String commId, {
    required String wardrobeItemId,
    String? notes,
  }) async {
    final body = jsonEncode({
      'wardrobe_item_id': wardrobeItemId,
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
    });
    final res = await http
        .post(
          Uri.parse(ApiEndpoints.communityListings(commId)),
          headers: _defaultHeaders,
          body: body,
        )
        .timeout(_timeout);
    if (res.statusCode == 201) {
      return CommunityListingModel.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)),
      );
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<void> unlistSharedItem(String commId, String listingId) async {
    final res = await http
        .delete(
          Uri.parse(ApiEndpoints.communityListingDetail(commId, listingId)),
          headers: _defaultHeaders,
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw ApiException(_extractError(res.body), res.statusCode);
    }
  }

  static Future<List<CommunityListingModel>> getWardrobeItemListings(
    String itemId,
  ) async {
    final res = await http
        .get(
          Uri.parse(ApiEndpoints.wardrobeItemListings(itemId)),
          headers: _defaultHeaders,
        )
        .timeout(_timeout);
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return list.map((l) => CommunityListingModel.fromJson(l)).toList();
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  // Borrowing Requests
  static Future<ItemRequestModel> createBorrowRequest(
    String commId,
    String listingId, {
    String? message,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final body = jsonEncode({
      'message': message?.trim().isEmpty == true ? null : message?.trim(),
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
    });
    final res = await http
        .post(
          Uri.parse(ApiEndpoints.borrowRequest(commId, listingId)),
          headers: _defaultHeaders,
          body: body,
        )
        .timeout(_timeout);
    if (res.statusCode == 201) {
      return ItemRequestModel.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<List<ItemRequestModel>> getIncomingRequests({
    String? status,
  }) async {
    var uri = Uri.parse(ApiEndpoints.incomingRequests);
    if (status != null && status.isNotEmpty && status != 'all') {
      uri = uri.replace(queryParameters: {'status': status.trim()});
    }
    final res = await http.get(uri, headers: _defaultHeaders).timeout(_timeout);
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return list.map((r) => ItemRequestModel.fromJson(r)).toList();
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<List<ItemRequestModel>> getOutgoingRequests({
    String? status,
  }) async {
    var uri = Uri.parse(ApiEndpoints.outgoingRequests);
    if (status != null && status.isNotEmpty && status != 'all') {
      uri = uri.replace(queryParameters: {'status': status.trim()});
    }
    final res = await http.get(uri, headers: _defaultHeaders).timeout(_timeout);
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return list.map((r) => ItemRequestModel.fromJson(r)).toList();
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<ItemRequestModel> updateRequestStatus(
    String requestId,
    String status,
  ) async {
    final body = jsonEncode({'status': status.trim()});
    final res = await http
        .patch(
          Uri.parse(ApiEndpoints.updateRequestStatus(requestId)),
          headers: _defaultHeaders,
          body: body,
        )
        .timeout(_timeout);
    if (res.statusCode == 200) {
      return ItemRequestModel.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  // Public Profiles & Self Profile Updates
  static Future<PublicUserProfileModel> getPublicProfile(String userId) async {
    final res = await http
        .get(
          Uri.parse(ApiEndpoints.publicProfile(userId)),
          headers: _defaultHeaders,
        )
        .timeout(_timeout);
    if (res.statusCode == 200) {
      return PublicUserProfileModel.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)),
      );
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  // Users, Profiles & Field-Level Privacy
  static Future<UserProfileModel> getMyProfile() async {
    final res = await http
        .get(Uri.parse(ApiEndpoints.myProfile), headers: _defaultHeaders)
        .timeout(_timeout);
    if (res.statusCode == 200) {
      return UserProfileModel.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<UserProfileModel> updateMyProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
    int? age,
    String? phoneNumber,
    FitPreferencesModel? fitPreferences,
    List<String>? preferredStyles,
    ProfilePrivacySettingsModel? privacySettings,
  }) async {
    final payload = <String, dynamic>{};
    if (displayName != null) payload['display_name'] = displayName.trim();
    if (bio != null) payload['bio'] = bio.trim().isEmpty ? null : bio.trim();
    if (avatarUrl != null) payload['avatar_url'] = avatarUrl.trim();
    if (age != null) payload['age'] = age;
    if (phoneNumber != null) {
      payload['phone_number'] = phoneNumber.trim().isEmpty
          ? null
          : phoneNumber.trim();
    }
    if (fitPreferences != null) {
      payload['fit_preferences'] = fitPreferences.toJson();
    }
    if (preferredStyles != null) payload['preferred_styles'] = preferredStyles;
    if (privacySettings != null) {
      payload['privacy_settings'] = privacySettings.toJson();
    }

    final body = jsonEncode(payload);
    final res = await http
        .patch(
          Uri.parse(ApiEndpoints.updateMyProfile),
          headers: _defaultHeaders,
          body: body,
        )
        .timeout(_timeout);
    if (res.statusCode == 200) {
      return UserProfileModel.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<ProfilePrivacySettingsModel> getMyPrivacySettings() async {
    final res = await http
        .get(Uri.parse(ApiEndpoints.myPrivacy), headers: _defaultHeaders)
        .timeout(_timeout);
    if (res.statusCode == 200) {
      return ProfilePrivacySettingsModel.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)),
      );
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<ProfilePrivacySettingsModel> updateMyPrivacySettings(
    ProfilePrivacySettingsModel settings,
  ) async {
    final body = jsonEncode(settings.toJson());
    final res = await http
        .patch(
          Uri.parse(ApiEndpoints.myPrivacy),
          headers: _defaultHeaders,
          body: body,
        )
        .timeout(_timeout);
    if (res.statusCode == 200) {
      return ProfilePrivacySettingsModel.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)),
      );
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<String> uploadProfileAvatar(XFile file) async {
    final uri = Uri.parse(ApiEndpoints.uploadAvatar);
    final request = http.MultipartRequest('POST', uri);
    final bytes = await file.readAsBytes();
    final ext = file.name.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name.isNotEmpty ? file.name : 'avatar.jpg',
        contentType: MediaType.parse(mimeType),
      ),
    );

    if (authToken != null && authToken!.trim().isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${authToken!.trim()}';
    }

    final streamed = await request.send().timeout(_timeout);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200) {
      final json =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return json['avatar_url'] as String? ?? '';
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  // Notifications & Activity Center
  static Future<List<NotificationModel>> getNotifications({
    bool unreadOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'unread_only': unreadOnly.toString(),
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    final uri = Uri.parse(ApiEndpoints.notifications)
        .replace(queryParameters: queryParams);
    final res = await http.get(uri, headers: _defaultHeaders).timeout(_timeout);
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return list
          .map((n) => NotificationModel.fromJson(n as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<int> getUnreadNotificationCount() async {
    final uri = Uri.parse(ApiEndpoints.unreadNotificationCount);
    final res = await http.get(uri, headers: _defaultHeaders).timeout(_timeout);
    if (res.statusCode == 200) {
      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return data['unread_count'] as int? ?? 0;
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<NotificationModel> markNotificationAsRead(
    String notificationId,
  ) async {
    final uri = Uri.parse(ApiEndpoints.markNotificationRead(notificationId));
    final res = await http
        .patch(uri, headers: _defaultHeaders)
        .timeout(_timeout);
    if (res.statusCode == 200) {
      return NotificationModel.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
      );
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  static Future<int> markAllNotificationsAsRead() async {
    final uri = Uri.parse(ApiEndpoints.markAllNotificationsRead);
    final res = await http
        .post(uri, headers: _defaultHeaders)
        .timeout(_timeout);
    if (res.statusCode == 200) {
      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return data['marked_count'] as int? ?? 0;
    }
    throw ApiException(_extractError(res.body), res.statusCode);
  }

  // adaa Conversational Stylist
  static Future<StylistChatResponseModel> sendStylistChat({
    required String message,
    List<Map<String, dynamic>> history = const [],
  }) async {
    final uri = Uri.parse(ApiEndpoints.stylistChat);
    final payload = jsonEncode({'message': message, 'history': history});
    final res = await http
        .post(uri, headers: _defaultHeaders, body: payload)
        .timeout(_defaultTimeout);

    if (res.statusCode == 200) {
      final json =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return StylistChatResponseModel.fromJson(json);
    }
    throw ApiException(_extractError(res.body), res.statusCode);
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
