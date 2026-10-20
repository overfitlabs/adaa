import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wardrobelens/core/models/community_model.dart';
import 'package:wardrobelens/core/models/wardrobe_item.dart';
import 'package:wardrobelens/features/communities/screens/communities_screen.dart';
import 'package:wardrobelens/features/communities/screens/community_detail_screen.dart';
import 'package:wardrobelens/features/communities/screens/shared_closet_screen.dart';
import 'package:wardrobelens/features/communities/widgets/share_item_dialog.dart';
import 'package:wardrobelens/state/auth_provider.dart';
import 'package:wardrobelens/state/community_provider.dart';
import 'package:wardrobelens/state/wardrobe_provider.dart';

class FakeCommunityProvider extends ChangeNotifier implements CommunityProvider {
  List<CommunityModel> testCommunities = [];
  List<CommunityModel> testMyCommunities = [];
  List<CommunityMemberModel> testMembers = [];
  List<CommunityListingModel> testCommunityListings = [];
  List<SharedClosetItemModel> testSharedClosetItems = [];
  List<CommunityListingModel> testWardrobeItemListings = [];

  bool testIsLoading = false;
  String? testError;

  bool createCommunityCalled = false;
  bool joinCommunityCalled = false;
  bool leaveCommunityCalled = false;
  bool approveMemberCalled = false;
  bool rejectMemberCalled = false;
  bool removeMemberCalled = false;
  bool listWardrobeItemCalled = false;
  bool unlistSharedItemCalled = false;
  String? lastUnlistedListingId;

  @override
  List<CommunityModel> get communities => testCommunities;

  @override
  List<CommunityModel> get myCommunities => testMyCommunities;

  @override
  CommunityModel? get selectedCommunity => testCommunities.isNotEmpty ? testCommunities.first : null;

  @override
  List<CommunityMemberModel> get members => testMembers;

  @override
  List<CommunityListingModel> get communityListings => testCommunityListings;

  @override
  List<SharedClosetItemModel> get sharedClosetItems => testSharedClosetItems;

  @override
  String get searchQuery => '';

  @override
  String get sharedClosetCategory => 'all';

  @override
  String get sharedClosetSearch => '';

  @override
  bool get isLoading => testIsLoading;

  @override
  String? get error => testError;

  @override
  List<CommunityModel> get approvedCommunities =>
      testMyCommunities.where((c) => c.isApprovedMember).toList();

  @override
  void clearError() {
    testError = null;
    notifyListeners();
  }

  @override
  void loggerPrint(String msg) {}

  @override
  Future<void> loadDiscoveredCommunities({String? query, bool silent = false}) async {
    if (!silent) notifyListeners();
  }

  @override
  Future<void> loadMyCommunities({bool silent = false}) async {
    if (!silent) notifyListeners();
  }

  @override
  Future<void> selectCommunity(String id) async {
    notifyListeners();
  }

  @override
  Future<void> loadCommunityMembers(String commId) async {
    notifyListeners();
  }

  @override
  Future<void> loadCommunityListings(String commId, {String? category, String? search}) async {
    notifyListeners();
  }

  @override
  Future<void> loadSharedCloset({String? category, String? search, bool silent = false}) async {
    if (!silent) notifyListeners();
  }

  @override
  Future<bool> createCommunity({
    required String name,
    String? description,
    bool isPrivate = true,
  }) async {
    createCommunityCalled = true;
    final now = DateTime.now();
    final newComm = CommunityModel(
      id: 'comm-new',
      name: name,
      description: description,
      creatorId: 'user-admin',
      status: 'active',
      isPrivate: isPrivate,
      createdAt: now,
      updatedAt: now,
      membersCount: 1,
      listingsCount: 0,
      myMembership: CommunityMembershipSummary(
        id: 'mem-new',
        role: 'owner',
        status: 'approved',
        requestedAt: now,
        decidedAt: now,
      ),
    );
    testCommunities.insert(0, newComm);
    testMyCommunities.insert(0, newComm);
    notifyListeners();
    return true;
  }

  @override
  Future<bool> joinCommunity(String commId) async {
    joinCommunityCalled = true;
    final idx = testCommunities.indexWhere((c) => c.id == commId);
    if (idx != -1) {
      final old = testCommunities[idx];
      final now = DateTime.now();
      final updated = CommunityModel(
        id: old.id,
        name: old.name,
        description: old.description,
        creatorId: old.creatorId,
        status: old.status,
        isPrivate: old.isPrivate,
        createdAt: old.createdAt,
        updatedAt: now,
        membersCount: old.membersCount,
        listingsCount: old.listingsCount,
        myMembership: CommunityMembershipSummary(
          id: 'mem-req',
          role: 'member',
          status: 'requested',
          requestedAt: now,
        ),
      );
      testCommunities[idx] = updated;
      testMyCommunities.add(updated);
      notifyListeners();
    }
    return true;
  }

  @override
  Future<bool> leaveCommunity(String commId) async {
    leaveCommunityCalled = true;
    testMyCommunities.removeWhere((c) => c.id == commId);
    notifyListeners();
    return true;
  }

  @override
  Future<bool> approveMember(String commId, String userId) async {
    approveMemberCalled = true;
    final idx = testMembers.indexWhere((m) => m.userId == userId);
    if (idx != -1) {
      final old = testMembers[idx];
      testMembers[idx] = CommunityMemberModel(
        id: old.id,
        communityId: old.communityId,
        userId: old.userId,
        role: old.role,
        status: 'approved',
        requestedAt: old.requestedAt,
        decidedAt: DateTime.now(),
        decidedById: 'user-admin',
        createdAt: old.createdAt,
      );
      notifyListeners();
    }
    return true;
  }

  @override
  Future<bool> rejectMember(String commId, String userId) async {
    rejectMemberCalled = true;
    testMembers.removeWhere((m) => m.userId == userId);
    notifyListeners();
    return true;
  }

  @override
  Future<bool> removeMember(String commId, String userId) async {
    removeMemberCalled = true;
    testMembers.removeWhere((m) => m.userId == userId);
    notifyListeners();
    return true;
  }

  @override
  Future<bool> updateMemberRole(String commId, String userId, String role) async {
    final idx = testMembers.indexWhere((m) => m.userId == userId);
    if (idx != -1) {
      final old = testMembers[idx];
      testMembers[idx] = CommunityMemberModel(
        id: old.id,
        communityId: old.communityId,
        userId: old.userId,
        role: role,
        status: old.status,
        requestedAt: old.requestedAt,
        decidedAt: old.decidedAt,
        decidedById: old.decidedById,
        createdAt: old.createdAt,
      );
      notifyListeners();
    }
    return true;
  }

  @override
  Future<bool> listWardrobeItem(String commId, {required String wardrobeItemId, String? notes}) async {
    listWardrobeItemCalled = true;
    final newListing = CommunityListingModel(
      id: 'listing-${DateTime.now().millisecondsSinceEpoch}',
      communityId: commId,
      communityName: 'Campus Fashion Circle',
      wardrobeItemId: wardrobeItemId,
      ownerId: 'user-admin',
      status: 'active',
      notes: notes,
      createdAt: DateTime.now(),
    );
    testWardrobeItemListings.add(newListing);
    testCommunityListings.add(newListing);
    notifyListeners();
    return true;
  }

  @override
  Future<bool> unlistSharedItem(String commId, String listingId) async {
    unlistSharedItemCalled = true;
    lastUnlistedListingId = listingId;
    testWardrobeItemListings.removeWhere((l) => l.id == listingId);
    testCommunityListings.removeWhere((l) => l.id == listingId);
    testSharedClosetItems.removeWhere((l) => l.listingId == listingId);
    notifyListeners();
    return true;
  }

  @override
  Future<List<CommunityListingModel>> getWardrobeItemListings(String itemId) async {
    return testWardrobeItemListings.where((l) => l.wardrobeItemId == itemId).toList();
  }

  @override
  void clear() {
    testCommunities.clear();
    testMyCommunities.clear();
    testMembers.clear();
    testCommunityListings.clear();
    testSharedClosetItems.clear();
    testWardrobeItemListings.clear();
    testIsLoading = false;
    testError = null;
    notifyListeners();
  }

  @override
  set communities(List<CommunityModel> value) {
    testCommunities = value;
    notifyListeners();
  }

  @override
  set myCommunities(List<CommunityModel> value) {
    testMyCommunities = value;
    notifyListeners();
  }

  @override
  set sharedClosetItems(List<SharedClosetItemModel> value) {
    testSharedClosetItems = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeWardrobeProvider extends ChangeNotifier implements WardrobeProvider {
  @override
  void clear() {
    items.clear();
    categories.clear();
    selectedCategory = 'all';
    searchQuery = '';
    isLoading = false;
    error = null;
    notifyListeners();
  }
  @override
  List<WardrobeItem> items = [];
  @override
  List<Map<String, dynamic>> categories = [];
  @override
  bool isLoading = false;
  @override
  String? error;
  @override
  String selectedCategory = 'all';
  @override
  String searchQuery = '';

  bool deleteItemCalled = false;

  @override
  Future<void> loadWardrobe({bool silent = false}) async {
    notifyListeners();
  }

  @override
  void setCategory(String category) {
    selectedCategory = category;
    notifyListeners();
  }

  @override
  void setSearchQuery(String query) {
    searchQuery = query;
    notifyListeners();
  }

  @override
  Future<bool> deleteItem(String id) async {
    deleteItemCalled = true;
    items.removeWhere((it) => it.id == id);
    notifyListeners();
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  User? user = const User(
    id: 'user-admin',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-10-20T10:00:00Z',
  );

  @override
  bool isAuthenticated = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Community Models Serialization Unit Tests', () {
    test('CommunityModel fromJson and toJson round-trip', () {
      final json = {
        'id': 'comm-101',
        'name': 'NYU Sustainable Fashion',
        'description': 'Student clothing swap and shared capsule closet.',
        'creator_id': 'user-1',
        'status': 'active',
        'is_private': true,
        'created_at': '2026-10-20T10:00:00Z',
        'updated_at': '2026-10-20T10:00:00Z',
        'members_count': 42,
        'listings_count': 12,
        'my_membership': {
          'id': 'mem-1',
          'role': 'owner',
          'status': 'approved',
          'requested_at': '2026-10-20T10:00:00Z',
          'decided_at': '2026-10-20T10:00:00Z',
        },
      };

      final model = CommunityModel.fromJson(json);
      expect(model.id, 'comm-101');
      expect(model.name, 'NYU Sustainable Fashion');
      expect(model.membersCount, 42);
      expect(model.listingsCount, 12);
      expect(model.isOwner, isTrue);
      expect(model.isAdminOrOwner, isTrue);
      expect(model.isApprovedMember, isTrue);

      final out = model.toJson();
      expect(out['name'], 'NYU Sustainable Fashion');
      expect(out['is_private'], true);
    });

    test('CommunityMemberModel fromJson handles status and role', () {
      final json = {
        'id': 'mem-202',
        'community_id': 'comm-101',
        'user_id': 'user-2',
        'role': 'admin',
        'status': 'requested',
        'requested_at': '2026-10-20T11:00:00Z',
        'created_at': '2026-10-20T11:00:00Z',
      };

      final member = CommunityMemberModel.fromJson(json);
      expect(member.id, 'mem-202');
      expect(member.role, 'admin');
      expect(member.status, 'requested');
    });

    test('SharedClosetItemModel fromJson parsing with community context', () {
      final json = {
        'listing_id': 'list-303',
        'community_id': 'comm-101',
        'community_name': 'Columbia Thrift Collective',
        'owner_id': 'user-3',
        'status': 'active',
        'notes': 'Great for autumn evenings',
        'created_at': '2026-10-20T12:00:00Z',
        'item': {
          'id': 'w-999',
          'name': 'Vintage Leather Jacket',
          'category': 'outerwear',
          'primary_color': 'Brown',
          'brand': 'Schott',
          'size': 'M',
          'condition': 'Vintage',
          'image_path': 'wardrobe/jacket.jpg',
          'image_url': '/storage/wardrobe/jacket.jpg',
          'created_at': '2026-10-20T12:00:00Z',
          'updated_at': '2026-10-20T12:00:00Z',
        },
      };

      final item = SharedClosetItemModel.fromJson(json);
      expect(item.listingId, 'list-303');
      expect(item.communityName, 'Columbia Thrift Collective');
      expect(item.item.name, 'Vintage Leather Jacket');
      expect(item.item.category, 'outerwear');
    });
  });

  group('CommunitiesScreen Widget Tests', () {
    late FakeCommunityProvider fakeCommProv;
    late FakeWardrobeProvider fakeWardrobeProv;
    late FakeAuthProvider fakeAuthProv;

    setUp(() {
      fakeCommProv = FakeCommunityProvider();
      fakeWardrobeProv = FakeWardrobeProvider();
      fakeAuthProv = FakeAuthProvider();
    });

    Widget createTestApp(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<CommunityProvider>.value(value: fakeCommProv),
          ChangeNotifierProvider<WardrobeProvider>.value(value: fakeWardrobeProv),
          ChangeNotifierProvider<AuthProvider>.value(value: fakeAuthProv),
        ],
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('CommunitiesScreen renders 3 tabs and empty state', (tester) async {
      await tester.pumpWidget(createTestApp(const CommunitiesScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Explore'), findsOneWidget);
      expect(find.textContaining('My Circles'), findsOneWidget);
      expect(find.text('Shared Closet'), findsOneWidget);

      // Explore tab is active by default with no communities
      expect(find.text('No Communities Found'), findsOneWidget);
      expect(find.text('Create First Circle'), findsOneWidget);
    });

    testWidgets('CommunitiesScreen displays community cards with membership badges', (tester) async {
      final now = DateTime.now();
      fakeCommProv.testCommunities = [
        CommunityModel(
          id: 'c-1',
          name: 'NYU Campus Closet',
          description: 'Share and borrow event wear.',
          creatorId: 'u-1',
          status: 'active',
          isPrivate: true,
          createdAt: now,
          updatedAt: now,
          membersCount: 15,
          listingsCount: 4,
          myMembership: CommunityMembershipSummary(
            id: 'm-1',
            role: 'owner',
            status: 'approved',
            requestedAt: now,
            decidedAt: now,
          ),
        ),
        CommunityModel(
          id: 'c-2',
          name: 'Parsons Design Circle',
          description: 'Curated studio garments.',
          creatorId: 'u-2',
          status: 'active',
          isPrivate: true,
          createdAt: now,
          updatedAt: now,
          membersCount: 8,
          listingsCount: 2,
          myMembership: CommunityMembershipSummary(
            id: 'm-2',
            role: 'member',
            status: 'requested',
            requestedAt: now,
          ),
        ),
        CommunityModel(
          id: 'c-3',
          name: 'Brooklyn Vintage Club',
          description: 'Archive pieces & denim.',
          creatorId: 'u-3',
          status: 'active',
          isPrivate: true,
          createdAt: now,
          updatedAt: now,
          membersCount: 22,
          listingsCount: 10,
          myMembership: null,
        ),
      ];

      await tester.pumpWidget(createTestApp(const CommunitiesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('NYU Campus Closet'), findsOneWidget);
      expect(find.text('Parsons Design Circle'), findsOneWidget);
      expect(find.text('Brooklyn Vintage Club'), findsOneWidget);

      // Badges: OWNER, PENDING, Join
      expect(find.text('OWNER'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('Join'), findsOneWidget);
    });

    testWidgets('Tapping Join triggers joinCommunity on CommunityProvider', (tester) async {
      final now = DateTime.now();
      fakeCommProv.testCommunities = [
        CommunityModel(
          id: 'c-joinable',
          name: 'Columbia Closet',
          description: 'Fashion sharing',
          creatorId: 'u-other',
          status: 'active',
          isPrivate: true,
          createdAt: now,
          updatedAt: now,
          membersCount: 5,
          listingsCount: 1,
          myMembership: null,
        ),
      ];

      await tester.pumpWidget(createTestApp(const CommunitiesScreen()));
      await tester.pumpAndSettle();

      final joinButton = find.text('Join');
      expect(joinButton, findsOneWidget);

      await tester.tap(joinButton);
      await tester.pumpAndSettle();

      expect(fakeCommProv.joinCommunityCalled, isTrue);
      // Status changes to PENDING
      expect(find.text('PENDING'), findsOneWidget);
    });

    testWidgets('Tapping Create Community opens dialog and creates community', (tester) async {
      await tester.pumpWidget(createTestApp(const CommunitiesScreen()));
      await tester.pumpAndSettle();

      final createFab = find.text('New Circle');
      expect(createFab, findsOneWidget);

      await tester.tap(createFab);
      await tester.pumpAndSettle();

      expect(find.text('Create Fashion Circle'), findsOneWidget);

      // Enter community name and description in dialog text fields
      final dialogFields = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
      await tester.enterText(dialogFields.first, 'Berkeley Style Hub');
      await tester.enterText(dialogFields.last, 'Sustainable campus clothing library');
      await tester.pumpAndSettle();

      final createButton = find.text('Create Circle');
      expect(createButton, findsOneWidget);

      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(fakeCommProv.createCommunityCalled, isTrue);
    });
  });

  group('CommunityDetailScreen Widget Tests', () {
    late FakeCommunityProvider fakeCommProv;
    late FakeWardrobeProvider fakeWardrobeProv;
    late FakeAuthProvider fakeAuthProv;

    setUp(() {
      fakeCommProv = FakeCommunityProvider();
      fakeWardrobeProv = FakeWardrobeProvider();
      fakeAuthProv = FakeAuthProvider();
    });

    Widget createTestApp(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<CommunityProvider>.value(value: fakeCommProv),
          ChangeNotifierProvider<WardrobeProvider>.value(value: fakeWardrobeProv),
          ChangeNotifierProvider<AuthProvider>.value(value: fakeAuthProv),
        ],
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('Owner sees Shared Closet tab and Members tab with admin actions', (tester) async {
      final now = DateTime.now();
      final comm = CommunityModel(
        id: 'comm-admin-1',
        name: 'Leadership Fashion Club',
        description: 'Executive committee capsule closet',
        creatorId: 'user-admin',
        status: 'active',
        isPrivate: true,
        createdAt: now,
        updatedAt: now,
        membersCount: 4,
        listingsCount: 0,
        myMembership: CommunityMembershipSummary(
          id: 'mem-admin',
          role: 'owner',
          status: 'approved',
          requestedAt: now,
          decidedAt: now,
        ),
      );

      await tester.pumpWidget(createTestApp(CommunityDetailScreen(community: comm)));
      await tester.pumpAndSettle();

      expect(find.text('Leadership Fashion Club'), findsNWidgets(2));
      expect(find.textContaining('Shared Closet'), findsOneWidget);
      expect(find.textContaining('Members'), findsOneWidget);
    });

    testWidgets('Admin can approve pending join requests in Members tab', (tester) async {
      final now = DateTime.now();
      final comm = CommunityModel(
        id: 'comm-admin-1',
        name: 'Leadership Fashion Club',
        description: 'Executive capsule closet',
        creatorId: 'user-admin',
        status: 'active',
        isPrivate: true,
        createdAt: now,
        updatedAt: now,
        membersCount: 2,
        listingsCount: 0,
        myMembership: CommunityMembershipSummary(
          id: 'mem-admin',
          role: 'owner',
          status: 'approved',
          requestedAt: now,
          decidedAt: now,
        ),
      );

      fakeCommProv.testCommunities = [comm];
      fakeCommProv.testMembers = [
        CommunityMemberModel(
          id: 'mem-req-1',
          communityId: 'comm-admin-1',
          userId: 'user-applicant-123',
          role: 'member',
          status: 'requested',
          requestedAt: now,
          createdAt: now,
        ),
      ];

      await tester.pumpWidget(createTestApp(CommunityDetailScreen(community: comm)));
      await tester.pumpAndSettle();

      // Switch to Members tab
      await tester.tap(find.textContaining('Members'));
      await tester.pumpAndSettle();

      expect(find.text('PENDING REQUESTS (1)'), findsOneWidget);

      final approveBtn = find.byTooltip('Approve');
      expect(approveBtn, findsOneWidget);

      await tester.tap(approveBtn);
      await tester.pumpAndSettle();

      // Confirm in dialog
      expect(find.text('Approve Membership'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Approve'));
      await tester.pumpAndSettle();

      expect(fakeCommProv.approveMemberCalled, isTrue);
    });

    testWidgets('Non-member sees request to join banner', (tester) async {
      final now = DateTime.now();
      final comm = CommunityModel(
        id: 'comm-guest',
        name: 'Exclusive Circle',
        description: 'Private styling group',
        creatorId: 'other-user',
        status: 'active',
        isPrivate: true,
        createdAt: now,
        updatedAt: now,
        membersCount: 12,
        listingsCount: 5,
        myMembership: null,
      );

      await tester.pumpWidget(createTestApp(CommunityDetailScreen(community: comm)));
      await tester.pumpAndSettle();

      expect(find.text('Exclusive Community Closet'), findsOneWidget);
      expect(find.text('Request to Join Circle'), findsOneWidget);

      await tester.tap(find.text('Request to Join Circle'));
      await tester.pumpAndSettle();

      expect(fakeCommProv.joinCommunityCalled, isTrue);
    });
  });

  group('SharedClosetScreen & Unlisting Tests', () {
    late FakeCommunityProvider fakeCommProv;
    late FakeWardrobeProvider fakeWardrobeProv;
    late FakeAuthProvider fakeAuthProv;

    setUp(() {
      fakeCommProv = FakeCommunityProvider();
      fakeWardrobeProv = FakeWardrobeProvider();
      fakeAuthProv = FakeAuthProvider();
    });

    Widget createTestApp(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<CommunityProvider>.value(value: fakeCommProv),
          ChangeNotifierProvider<WardrobeProvider>.value(value: fakeWardrobeProv),
          ChangeNotifierProvider<AuthProvider>.value(value: fakeAuthProv),
        ],
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('Cross-community shared closet displays items across communities', (tester) async {
      final now = DateTime.now();
      fakeCommProv.testSharedClosetItems = [
        SharedClosetItemModel(
          listingId: 'list-1',
          communityId: 'c-1',
          communityName: 'NYU Closet',
          ownerId: 'u-friend-1',
          status: 'active',
          createdAt: now,
          item: WardrobeItem(
            id: 'w-1',
            name: 'Cashmere Knit Sweater',
            category: 'tops',
            primaryColor: 'Cream',
            size: 'M',
            imagePath: 'wardrobe/sweater.jpg',
            imageUrl: '/storage/wardrobe/sweater.jpg',
            createdAt: now,
            updatedAt: now,
          ),
        ),
        SharedClosetItemModel(
          listingId: 'list-2',
          communityId: 'c-2',
          communityName: 'Columbia Style Club',
          ownerId: 'u-friend-2',
          status: 'active',
          createdAt: now,
          item: WardrobeItem(
            id: 'w-2',
            name: 'Pleated Wool Trousers',
            category: 'bottoms',
            primaryColor: 'Charcoal',
            size: '32',
            imagePath: 'wardrobe/trousers.jpg',
            imageUrl: '/storage/wardrobe/trousers.jpg',
            createdAt: now,
            updatedAt: now,
          ),
        ),
      ];

      await tester.pumpWidget(createTestApp(const SharedClosetScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Cashmere Knit Sweater'), findsOneWidget);
      expect(find.text('Pleated Wool Trousers'), findsOneWidget);

      // Community context badges
      expect(find.text('NYU Closet'), findsOneWidget);
      expect(find.text('Columbia Style Club'), findsOneWidget);
    });

    testWidgets('ShareItemDialog displays active listings and unlists without deleting wardrobe item', (tester) async {
      final now = DateTime.now();
      final testGarment = WardrobeItem(
        id: 'garment-to-share',
        name: 'Classic Trench Coat',
        category: 'outerwear',
        primaryColor: 'Beige',
        tags: ['classic', 'waterproof'],
        imagePath: 'wardrobe/trench.jpg',
        imageUrl: '/storage/wardrobe/trench.jpg',
        createdAt: now,
        updatedAt: now,
      );

      // Garment is currently in user's personal wardrobe
      fakeWardrobeProv.items = [testGarment];

      // Garment is listed in Community A
      fakeCommProv.testMyCommunities = [
        CommunityModel(
          id: 'comm-approved-1',
          name: 'Campus Fashion Circle',
          description: 'Wardrobe swap',
          creatorId: 'u-1',
          status: 'active',
          isPrivate: true,
          createdAt: now,
          updatedAt: now,
          membersCount: 10,
          listingsCount: 3,
          myMembership: CommunityMembershipSummary(
            id: 'mem-10',
            role: 'member',
            status: 'approved',
            requestedAt: now,
            decidedAt: now,
          ),
        ),
      ];

      fakeCommProv.testWardrobeItemListings = [
        CommunityListingModel(
          id: 'listing-to-remove',
          communityId: 'comm-approved-1',
          communityName: 'Campus Fashion Circle',
          wardrobeItemId: 'garment-to-share',
          ownerId: 'user-admin',
          status: 'active',
          notes: 'Available for interviews',
          createdAt: now,
        ),
      ];

      await tester.pumpWidget(createTestApp(ShareItemDialog(item: testGarment)));
      await tester.pumpAndSettle();

      expect(find.text('Community Sharing'), findsOneWidget);
      expect(find.text('Classic Trench Coat'), findsOneWidget);
      expect(find.text('Campus Fashion Circle'), findsOneWidget);

      final unlistBtn = find.text('Unlist');
      expect(unlistBtn, findsOneWidget);

      await tester.tap(unlistBtn);
      await tester.pumpAndSettle();

      // Verify unlist was called on the community listing
      expect(fakeCommProv.unlistSharedItemCalled, isTrue);
      expect(fakeCommProv.lastUnlistedListingId, 'listing-to-remove');

      // Crucial Milestone 3 requirement: Unlisting must NOT delete the personal wardrobe item
      expect(fakeWardrobeProv.deleteItemCalled, isFalse);
      expect(fakeWardrobeProv.items.any((it) => it.id == 'garment-to-share'), isTrue);
      expect(find.text('Item unlisted. Your personal wardrobe remains unchanged.'), findsOneWidget);
    });
  });
}
