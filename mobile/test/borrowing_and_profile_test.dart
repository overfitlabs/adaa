import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wardrobelens/core/models/community_model.dart';
import 'package:wardrobelens/core/models/wardrobe_item.dart';
import 'package:wardrobelens/features/communities/screens/shared_item_detail_screen.dart';
import 'package:wardrobelens/features/communities/widgets/borrow_request_dialog.dart';
import 'package:wardrobelens/features/communities/widgets/public_profile_sheet.dart';
import 'package:wardrobelens/features/profile/screens/profile_screen.dart';
import 'package:wardrobelens/features/requests/screens/requests_screen.dart';
import 'package:wardrobelens/state/auth_provider.dart';
import 'package:wardrobelens/state/community_provider.dart';
import 'package:wardrobelens/state/wardrobe_provider.dart';

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  User? user = const User(
    id: 'user-requester-1',
    appMetadata: {},
    userMetadata: {'full_name': 'Test Requester'},
    aud: 'authenticated',
    createdAt: '2026-10-20T10:00:00Z',
    email: 'requester@adaa.test',
  );

  @override
  bool isAuthenticated = true;

  @override
  String get displayName => 'Test Requester';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockWardrobeProvider extends ChangeNotifier implements WardrobeProvider {
  @override
  List<WardrobeItem> items = [];

  @override
  void clear() {
    items.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockCommunityProvider extends ChangeNotifier implements CommunityProvider {
  @override
  List<CommunityModel> myCommunities = [];

  @override
  List<SharedClosetItemModel> sharedClosetItems = [];

  @override
  void clear() {
    myCommunities.clear();
    sharedClosetItems.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testGarment = WardrobeItem(
    id: 'item-vintage-coat',
    name: 'Vintage Wool Trench',
    category: 'outerwear',
    primaryColor: 'camel',
    brand: 'Burberry',
    imagePath: 'items/item-vintage-coat.jpg',
    imageUrl: 'https://res.cloudinary.com/demo/image/authenticated/s--123--/v1/adaa/trench.jpg',
    createdAt: DateTime(2026, 10, 15),
    updatedAt: DateTime(2026, 10, 15),
  );

  final testSharedItem = SharedClosetItemModel(
    listingId: 'listing-456',
    communityId: 'comm-123',
    communityName: 'Campus Style Collective',
    ownerId: 'user-owner-99',
    ownerName: 'Elena Rostova',
    ownerBio: 'Fashion design student specializing in structured tailoring.',
    status: 'active',
    item: testGarment,
    notes: 'Dry clean only, fits sizes S-M comfortably.',
    createdAt: DateTime(2026, 10, 18),
  );

  group('ItemRequestModel & PublicUserProfileModel Tests', () {
    test('ItemRequestModel deserialization and status helpers', () {
      final json = {
        'id': 'req-001',
        'listing_id': 'listing-456',
        'wardrobe_item_id': 'item-vintage-coat',
        'community_id': 'comm-123',
        'community_name': 'Campus Style Collective',
        'requester_id': 'user-requester-1',
        'requester_name': 'Alex Kim',
        'owner_id': 'user-owner-99',
        'owner_name': 'Elena Rostova',
        'status': 'pending',
        'message': 'Would love to borrow this for weekend fashion showcase!',
        'start_date': '2026-10-25T00:00:00.000',
        'end_date': '2026-10-28T00:00:00.000',
        'created_at': '2026-10-20T12:00:00.000',
        'updated_at': '2026-10-20T12:00:00.000',
        'item': testGarment.toJson(),
      };

      final req = ItemRequestModel.fromJson(json);
      expect(req.id, 'req-001');
      expect(req.isPending, isTrue);
      expect(req.isAccepted, isFalse);
      expect(req.isTerminal, isFalse);
      expect(req.resolvedRequesterName, 'Alex Kim');
      expect(req.dateRangeSummary, contains('Oct 25'));
      expect(req.dateRangeSummary, contains('Oct 28'));
    });

    test('ItemRequestModel terminal state helper', () {
      final jsonDeclined = {
        'id': 'req-002',
        'listing_id': 'listing-456',
        'wardrobe_item_id': 'item-vintage-coat',
        'community_id': 'comm-123',
        'requester_id': 'user-requester-1',
        'owner_id': 'user-owner-99',
        'status': 'declined',
        'created_at': '2026-10-20T12:00:00.000',
        'updated_at': '2026-10-20T12:00:00.000',
      };
      final reqDeclined = ItemRequestModel.fromJson(jsonDeclined);
      expect(reqDeclined.isTerminal, isTrue);
      expect(reqDeclined.isPending, isFalse);

      final jsonCompleted = {
        'id': 'req-003',
        'listing_id': 'listing-456',
        'wardrobe_item_id': 'item-vintage-coat',
        'community_id': 'comm-123',
        'requester_id': 'user-requester-1',
        'owner_id': 'user-owner-99',
        'status': 'completed',
        'created_at': '2026-10-20T12:00:00.000',
        'updated_at': '2026-10-20T12:00:00.000',
      };
      final reqCompleted = ItemRequestModel.fromJson(jsonCompleted);
      expect(reqCompleted.isTerminal, isTrue);

      final jsonCancelled = {
        'id': 'req-004',
        'listing_id': 'listing-456',
        'wardrobe_item_id': 'item-vintage-coat',
        'community_id': 'comm-123',
        'requester_id': 'user-requester-1',
        'owner_id': 'user-owner-99',
        'status': 'cancelled',
        'created_at': '2026-10-20T12:00:00.000',
        'updated_at': '2026-10-20T12:00:00.000',
      };
      final reqCancelled = ItemRequestModel.fromJson(jsonCancelled);
      expect(reqCancelled.isTerminal, isTrue);
    });

    test('PublicUserProfileModel parses safe profile fields', () {
      final json = {
        'id': 'user-owner-99',
        'display_name': 'Elena Rostova',
        'avatar_url': null,
        'bio': 'Sustainable capsule enthusiast.',
        'shared_communities_count': 3,
        'shared_items_count': 8,
      };

      final profile = PublicUserProfileModel.fromJson(json);
      expect(profile.displayName, 'Elena Rostova');
      expect(profile.initials, 'ER');
      expect(profile.bio, 'Sustainable capsule enthusiast.');
      expect(profile.sharedCommunitiesCount, 3);
      expect(profile.sharedItemsCount, 8);
    });
  });

  group('SharedItemDetailScreen Widget Tests', () {
    testWidgets('renders read-only garment information with owner identity', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SharedItemDetailScreen(sharedItem: testSharedItem),
        ),
      );

      // Verify garment information
      expect(find.text('Vintage Wool Trench'), findsWidgets);
      expect(find.text('Elena Rostova'), findsWidgets);
      expect(find.text('Campus Style Collective'), findsOneWidget);
      expect(find.text('Dry clean only, fits sizes S-M comfortably.'), findsOneWidget);
      expect(find.text('Request to Borrow'), findsOneWidget);

      // Verify NO owner management buttons are rendered
      expect(find.text('Delete Garment'), findsNothing);
      expect(find.text('Unlist Item'), findsNothing);
      expect(find.text('Edit Garment'), findsNothing);
    });

    testWidgets('factory fromListing creates valid read-only view', (tester) async {
      final listing = CommunityListingModel(
        id: 'list-777',
        communityId: 'comm-123',
        communityName: 'Campus Style Collective',
        wardrobeItemId: 'item-vintage-coat',
        ownerId: 'user-owner-99',
        ownerName: 'Elena Rostova',
        ownerBio: 'Designer',
        status: 'active',
        notes: 'Hand wash only',
        createdAt: DateTime(2026, 10, 19),
        item: testGarment,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SharedItemDetailScreen.fromListing(
            listing: listing,
            communityName: 'Campus Style Collective',
          ),
        ),
      );

      expect(find.text('Vintage Wool Trench'), findsWidgets);
      expect(find.text('Elena Rostova'), findsWidgets);
      expect(find.text('Hand wash only'), findsOneWidget);
      expect(find.text('Request to Borrow'), findsOneWidget);
    });
  });

  group('BorrowRequestDialog Widget Tests', () {
    testWidgets('renders dialog with garment and owner information', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => BorrowRequestDialog.show(
                  context,
                  communityId: 'comm-123',
                  listingId: 'listing-456',
                  communityName: 'Campus Style Collective',
                  garment: testGarment,
                  ownerName: 'Elena Rostova',
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Request to Borrow'), findsOneWidget);
      expect(find.textContaining('Elena Rostova'), findsOneWidget);
      expect(find.text('Vintage Wool Trench'), findsOneWidget);
      expect(find.text('Start Date'), findsOneWidget);
      expect(find.text('End Date'), findsOneWidget);
      expect(find.text('Send Request'), findsOneWidget);
    });
  });

  group('PublicProfileSheet Widget Tests', () {
    testWidgets('renders safe public profile sheet without private details', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PublicProfileSheet.show(
                  context,
                  userId: 'user-owner-99',
                  fallbackName: 'Elena Rostova',
                ),
                child: const Text('View Profile'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('View Profile'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Elena Rostova'), findsWidgets);

      // Verify privacy guarantees: no private email or credentials ever shown
      expect(find.text('requester@adaa.test'), findsNothing);
      expect(find.text('Password'), findsNothing);
      expect(find.text('Phone'), findsNothing);
    });
  });

  group('Owner vs Non-Owner Item Navigation Routing', () {
    test('correctly identifies ownership for routing', () {
      const currentUserId = 'user-owner-99';
      final isOwner = (currentUserId == testSharedItem.ownerId);
      expect(isOwner, isTrue);

      const nonOwnerUserId = 'user-other-member';
      final isNonOwner = (nonOwnerUserId == testSharedItem.ownerId);
      expect(isNonOwner, isFalse);
    });
  });

  group('ProfileScreen Widget Tests', () {
    testWidgets('renders profile screen and edit profile button for authenticated user', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => MockAuthProvider()),
            ChangeNotifierProvider<WardrobeProvider>(create: (_) => MockWardrobeProvider()),
            ChangeNotifierProvider<CommunityProvider>(create: (_) => MockCommunityProvider()),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Test Requester'), findsOneWidget);
      expect(find.text('AUTHENTICATED MEMBER'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Borrowing Requests'), findsOneWidget);

      // Open Edit Profile Sheet
      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Bio / Style Notes'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });
  });

  group('RequestsScreen Widget Tests', () {
    testWidgets('renders tabs for incoming and outgoing borrowing requests', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RequestsScreen(),
        ),
      );

      await tester.pump();

      expect(find.text('activity & requests'), findsOneWidget);
      expect(find.text('Incoming'), findsOneWidget);
      expect(find.text('Outgoing'), findsOneWidget);
    });
  });
}
