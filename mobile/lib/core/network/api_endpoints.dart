import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

class ApiEndpoints {
  // Support compile-time environment overrides: flutter run --dart-define=API_BASE_URL=http://...
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get defaultBaseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _cleanUrl(_envBaseUrl);
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }
    try {
      if (Platform.isAndroid) {
        // http://127.0.0.1:8000 works on physical Android devices when "adb reverse tcp:8000 tcp:8000" is run.
        // http://10.0.2.2:8000 is used on standard Android emulators.
        // Auto-detection probes both.
        return 'http://127.0.0.1:8000';
      }
    } catch (_) {}
    return 'http://127.0.0.1:8000';
  }

  static String baseUrl = defaultBaseUrl;

  static void setBaseUrl(String url) {
    baseUrl = _cleanUrl(url);
  }

  static String _cleanUrl(String url) {
    var clean = url.trim();
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean;
  }

  static List<String> get candidateUrls {
    final list = <String>[];
    if (_envBaseUrl.isNotEmpty) {
      list.add(_cleanUrl(_envBaseUrl));
      return list;
    }
    list.add(baseUrl);
    list.add('http://127.0.0.1:8000');
    list.add('http://10.0.2.2:8000');
    return list.toSet().toList();
  }

  // Analysis
  static String get analyzeImage => '$baseUrl/api/analysis/analyze-image';
  static String get analysisHistory => '$baseUrl/api/analysis';
  static String analysisDetail(String id) => '$baseUrl/api/analysis/$id';
  static String scanStatus(String scanId) => '$baseUrl/api/analysis/scans/$scanId';

  // Wardrobe
  static String get wardrobeItems => '$baseUrl/api/wardrobe/items';
  static String wardrobeItemDetail(String id) =>
      '$baseUrl/api/wardrobe/items/$id';
  static String wardrobeItemPhoto(String id) =>
      '$baseUrl/api/wardrobe/items/$id/photo';
  static String get wardrobeCategories => '$baseUrl/api/wardrobe/categories';
  static String get detectWardrobeItem => '$baseUrl/api/wardrobe/detect-item';
  static String get wardrobeBulkItems => '$baseUrl/api/wardrobe/items/bulk';

  // Matching
  static String get matchOutfit => '$baseUrl/api/matching/match-outfit';

  // Outfits
  static String get outfits => '$baseUrl/api/outfits';
  static String outfitDetail(String id) => '$baseUrl/api/outfits/$id';

  // Virtual Try-On
  static String get tryOnTasks => '$baseUrl/api/tryon/tasks';
  static String tryOnTaskDetail(String taskId) =>
      '$baseUrl/api/tryon/tasks/$taskId';
  static String get tryOnModel => '$baseUrl/api/tryon/model';
  static String tryOnHistory({int limit = 20, String? cursor, String? status}) {
    var url = '$baseUrl/api/tryon/history?limit=$limit';
    if (cursor != null && cursor.isNotEmpty) {
      url += '&cursor=${Uri.encodeComponent(cursor)}';
    }
    if (status != null && status.isNotEmpty) {
      url += '&status=${Uri.encodeComponent(status)}';
    }
    return url;
  }

  // Recommendations & adaa Conversational Stylist
  static String get recommendations => '$baseUrl/api/recommendations';
  static String get generateRecommendations =>
      '$baseUrl/api/recommendations/generate';
  static String get stylistChat => '$baseUrl/api/stylist/chat';

  // Communities & Shared Closets
  static String get communities => '$baseUrl/api/communities';
  static String get myCommunities => '$baseUrl/api/communities/my';
  static String get sharedCloset => '$baseUrl/api/communities/shared-closet';
  static String communityDetail(String id) => '$baseUrl/api/communities/$id';
  static String communityMembers(String id) =>
      '$baseUrl/api/communities/$id/members';
  static String communityJoin(String id) => '$baseUrl/api/communities/$id/join';
  static String communityLeave(String id) =>
      '$baseUrl/api/communities/$id/leave';
  static String communityMembership(String id) =>
      '$baseUrl/api/communities/$id/membership';
  static String communityApproveMember(String commId, String userId) =>
      '$baseUrl/api/communities/$commId/members/$userId/approve';
  static String communityRejectMember(String commId, String userId) =>
      '$baseUrl/api/communities/$commId/members/$userId/reject';
  static String communityRemoveMember(String commId, String userId) =>
      '$baseUrl/api/communities/$commId/members/$userId';
  static String communityMemberRole(String commId, String userId) =>
      '$baseUrl/api/communities/$commId/members/$userId/role';
  static String communityListings(String commId) =>
      '$baseUrl/api/communities/$commId/listings';
  static String communityListingDetail(String commId, String listingId) =>
      '$baseUrl/api/communities/$commId/listings/$listingId';
  static String wardrobeItemListings(String itemId) =>
      '$baseUrl/api/wardrobe/items/$itemId/listings';

  // Borrowing Requests
  static String borrowRequest(String commId, String listingId) =>
      '$baseUrl/api/communities/$commId/listings/$listingId/requests';
  static String get incomingRequests => '$baseUrl/api/requests/incoming';
  static String get outgoingRequests => '$baseUrl/api/requests/outgoing';
  static String updateRequestStatus(String reqId) =>
      '$baseUrl/api/requests/$reqId/status';

  // Users & Profiles
  static String get myProfile => '$baseUrl/api/users/me';
  static String get updateMyProfile => '$baseUrl/api/users/me/profile';
  static String get myPrivacy => '$baseUrl/api/users/me/privacy';
  static String get uploadAvatar => '$baseUrl/api/users/me/avatar';
  static String publicProfile(String userId) =>
      '$baseUrl/api/users/$userId/public-profile';

  // Auth
  static String get authMe => '$baseUrl/api/auth/me';

  // Notifications & Activity Center
  static String get notifications => '$baseUrl/api/notifications';
  static String get unreadNotificationCount =>
      '$baseUrl/api/notifications/unread-count';
  static String markNotificationRead(String id) =>
      '$baseUrl/api/notifications/$id/read';
  static String get markAllNotificationsRead =>
      '$baseUrl/api/notifications/read-all';

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
