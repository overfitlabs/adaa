import 'package:flutter/foundation.dart';
import '../core/models/community_model.dart';
import '../core/network/api_client.dart';

class CommunityProvider extends ChangeNotifier {
  List<CommunityModel> _communities = [];
  List<CommunityModel> _myCommunities = [];
  CommunityModel? _selectedCommunity;
  List<CommunityMemberModel> _members = [];
  List<CommunityListingModel> _communityListings = [];
  List<SharedClosetItemModel> _sharedClosetItems = [];

  String _searchQuery = '';
  String _sharedClosetCategory = 'all';
  String _sharedClosetSearch = '';
  bool _isLoading = false;
  String? _error;

  List<CommunityModel> get communities => _communities;
  List<CommunityModel> get myCommunities => _myCommunities;
  CommunityModel? get selectedCommunity => _selectedCommunity;
  List<CommunityMemberModel> get members => _members;
  List<CommunityListingModel> get communityListings => _communityListings;
  List<SharedClosetItemModel> get sharedClosetItems => _sharedClosetItems;

  @visibleForTesting
  set communities(List<CommunityModel> value) {
    _communities = value;
    notifyListeners();
  }

  @visibleForTesting
  set myCommunities(List<CommunityModel> value) {
    _myCommunities = value;
    notifyListeners();
  }

  @visibleForTesting
  set sharedClosetItems(List<SharedClosetItemModel> value) {
    _sharedClosetItems = value;
    notifyListeners();
  }

  String get searchQuery => _searchQuery;
  String get sharedClosetCategory => _sharedClosetCategory;
  String get sharedClosetSearch => _sharedClosetSearch;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<CommunityModel> get approvedCommunities =>
      _myCommunities.where((c) => c.isApprovedMember).toList();

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> loadDiscoveredCommunities({String? query, bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }
    _searchQuery = query ?? '';
    try {
      final list = await ApiClient.getCommunities(query: query);
      _communities = list;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMyCommunities({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final list = await ApiClient.getMyCommunities();
      _myCommunities = list;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectCommunity(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final detail = await ApiClient.getCommunityDetail(id);
      _selectedCommunity = detail;
      if (detail.isApprovedMember) {
        await loadCommunityListings(id);
      } else {
        _communityListings = [];
      }
      if (detail.isApprovedMember) {
        await loadCommunityMembers(id);
      } else {
        _members = [];
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCommunityMembers(String commId) async {
    try {
      final list = await ApiClient.getCommunityMembers(commId);
      _members = list;
      notifyListeners();
    } catch (e) {
      loggerPrint('Could not load members: $e');
    }
  }

  Future<void> loadCommunityListings(String commId, {String? category, String? search}) async {
    try {
      final list = await ApiClient.getCommunityListings(commId, category: category, search: search);
      _communityListings = list;
      notifyListeners();
    } catch (e) {
      loggerPrint('Could not load community listings: $e');
    }
  }

  Future<void> loadSharedCloset({String? category, String? search, bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }
    _sharedClosetCategory = category ?? _sharedClosetCategory;
    _sharedClosetSearch = search ?? _sharedClosetSearch;

    try {
      final list = await ApiClient.getCrossCommunitySharedCloset(
        category: _sharedClosetCategory,
        search: _sharedClosetSearch,
      );
      _sharedClosetItems = list;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createCommunity({
    required String name,
    String? description,
    bool isPrivate = true,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newComm = await ApiClient.createCommunity(
        name: name,
        description: description,
        isPrivate: isPrivate,
      );
      _communities.insert(0, newComm);
      _myCommunities.insert(0, newComm);
      _selectedCommunity = newComm;
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

  Future<bool> joinCommunity(String commId) async {
    try {
      final mem = await ApiClient.joinCommunity(commId);
      // Update local state
      final idx = _communities.indexWhere((c) => c.id == commId);
      if (idx != -1) {
        final existing = _communities[idx];
        _communities[idx] = CommunityModel(
          id: existing.id,
          name: existing.name,
          description: existing.description,
          creatorId: existing.creatorId,
          status: existing.status,
          isPrivate: existing.isPrivate,
          createdAt: existing.createdAt,
          updatedAt: existing.updatedAt,
          membersCount: existing.membersCount,
          listingsCount: existing.listingsCount,
          myMembership: CommunityMembershipSummary(
            id: mem.id,
            role: mem.role,
            status: mem.status,
            requestedAt: mem.requestedAt,
            decidedAt: mem.decidedAt,
          ),
        );
      }
      await loadMyCommunities(silent: true);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> leaveCommunity(String commId) async {
    try {
      await ApiClient.leaveCommunity(commId);
      _myCommunities.removeWhere((c) => c.id == commId);
      if (_selectedCommunity?.id == commId) {
        _selectedCommunity = null;
      }
      await loadDiscoveredCommunities(silent: true);
      await loadSharedCloset(silent: true);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> approveMember(String commId, String userId) async {
    try {
      final updated = await ApiClient.approveJoinRequest(commId, userId);
      final idx = _members.indexWhere((m) => m.userId == userId);
      if (idx != -1) {
        _members[idx] = updated;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectMember(String commId, String userId) async {
    try {
      final updated = await ApiClient.rejectJoinRequest(commId, userId);
      final idx = _members.indexWhere((m) => m.userId == userId);
      if (idx != -1) {
        _members[idx] = updated;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeMember(String commId, String userId) async {
    try {
      await ApiClient.removeCommunityMember(commId, userId);
      _members.removeWhere((m) => m.userId == userId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateMemberRole(String commId, String userId, String role) async {
    try {
      final updated = await ApiClient.updateMemberRole(commId, userId, role);
      final idx = _members.indexWhere((m) => m.userId == userId);
      if (idx != -1) {
        _members[idx] = updated;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> listWardrobeItem(
    String commId, {
    required String wardrobeItemId,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final listing = await ApiClient.listWardrobeItemInCommunity(
        commId,
        wardrobeItemId: wardrobeItemId,
        notes: notes,
      );
      _communityListings.insert(0, listing);
      await loadSharedCloset(silent: true);
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

  Future<bool> unlistSharedItem(String commId, String listingId) async {
    try {
      await ApiClient.unlistSharedItem(commId, listingId);
      _communityListings.removeWhere((l) => l.id == listingId);
      _sharedClosetItems.removeWhere((s) => s.listingId == listingId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<CommunityListingModel>> getWardrobeItemListings(String itemId) async {
    try {
      return await ApiClient.getWardrobeItemListings(itemId);
    } catch (e) {
      return [];
    }
  }

  void loggerPrint(String msg) {
    if (kDebugMode) {
      print('[CommunityProvider] $msg');
    }
  }

  /// Completely clears all cached community listings, memberships, and shared closet items.
  /// Called on logout or when switching accounts to ensure total session isolation.
  void clear() {
    _communities = [];
    _myCommunities = [];
    _selectedCommunity = null;
    _members = [];
    _communityListings = [];
    _sharedClosetItems = [];
    _searchQuery = '';
    _sharedClosetCategory = 'all';
    _sharedClosetSearch = '';
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
