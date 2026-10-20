import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wardrobelens/core/auth/session_manager.dart';
import 'package:wardrobelens/core/models/wardrobe_item.dart';
import 'package:wardrobelens/core/network/api_client.dart';
import 'package:wardrobelens/features/auth/screens/auth_gate.dart';
import 'package:wardrobelens/features/auth/screens/auth_screen.dart';
import 'package:wardrobelens/features/auth/screens/logout_success_screen.dart';
import 'package:wardrobelens/features/home/screens/home_screen.dart';
import 'package:wardrobelens/state/analysis_provider.dart';
import 'package:wardrobelens/state/auth_provider.dart';
import 'package:wardrobelens/state/community_provider.dart';
import 'package:wardrobelens/state/notification_provider.dart';
import 'package:wardrobelens/state/outfits_provider.dart';
import 'package:wardrobelens/state/stylist_provider.dart';
import 'package:wardrobelens/state/tryon_provider.dart';
import 'package:wardrobelens/state/wardrobe_provider.dart';

class TestAuthProvider extends ChangeNotifier implements AuthProvider {
  User? _user;
  bool _isAuthenticated = false;

  @override
  User? get user => _user;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  bool get isConfigured => true;

  @override
  String? get email => _user?.email;

  @override
  String get displayName => _user?.email?.split('@').first ?? 'User';

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  String? get infoMessage => null;

  @override
  Session? get session => null;

  @override
  String? get accessToken => null;

  void setAuthenticated(bool authenticated, {String userId = 'user-test-1', String email = 'user1@test.com'}) {
    _isAuthenticated = authenticated;
    if (authenticated) {
      _user = User(
        id: userId,
        appMetadata: {},
        userMetadata: {'full_name': 'Test User'},
        aud: 'authenticated',
        email: email,
        emailConfirmedAt: '2026-10-20T10:00:00Z',
        createdAt: '2026-10-20T10:00:00Z',
      );
    } else {
      _user = null;
    }
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _isAuthenticated = false;
    ApiClient.authToken = null;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget createTestApp({
  required TestAuthProvider authProvider,
  required WardrobeProvider wardrobeProvider,
  required CommunityProvider communityProvider,
  required AnalysisProvider analysisProvider,
  required OutfitsProvider outfitsProvider,
  required TryOnProvider tryOnProvider,
  NotificationProvider? notificationProvider,
  StylistProvider? stylistProvider,
  Widget? home,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<WardrobeProvider>.value(value: wardrobeProvider),
      ChangeNotifierProvider<CommunityProvider>.value(value: communityProvider),
      ChangeNotifierProvider<AnalysisProvider>.value(value: analysisProvider),
      ChangeNotifierProvider<OutfitsProvider>.value(value: outfitsProvider),
      ChangeNotifierProvider<TryOnProvider>.value(value: tryOnProvider),
      ChangeNotifierProvider<NotificationProvider>.value(
        value: notificationProvider ?? NotificationProvider(),
      ),
      ChangeNotifierProvider<StylistProvider>.value(
        value: stylistProvider ?? StylistProvider(),
      ),
    ],
    child: MaterialApp(
      navigatorKey: SessionManager.navigatorKey,
      home: home ?? const AuthGate(),
    ),
  );
}

void main() {
  late TestAuthProvider authProvider;
  late WardrobeProvider wardrobeProvider;
  late CommunityProvider communityProvider;
  late AnalysisProvider analysisProvider;
  late OutfitsProvider outfitsProvider;
  late TryOnProvider tryOnProvider;
  late NotificationProvider notificationProvider;
  late StylistProvider stylistProvider;

  setUp(() {
    authProvider = TestAuthProvider();
    wardrobeProvider = WardrobeProvider();
    communityProvider = CommunityProvider();
    analysisProvider = AnalysisProvider();
    outfitsProvider = OutfitsProvider();
    tryOnProvider = TryOnProvider();
    notificationProvider = NotificationProvider();
    stylistProvider = StylistProvider();
    ApiClient.authToken = null;
  });

  tearDown(() {
    ApiClient.authToken = null;
    ApiClient.onSessionExpired = null;
  });

  group('Phase 1 Auth, Logout & Session Isolation Tests', () {
    testWidgets('1. Unauthenticated state shows only AuthScreen with zero guest experience', (tester) async {
      authProvider.setAuthenticated(false);

      await tester.pumpWidget(
        createTestApp(
          authProvider: authProvider,
          wardrobeProvider: wardrobeProvider,
          communityProvider: communityProvider,
          analysisProvider: analysisProvider,
          outfitsProvider: outfitsProvider,
          tryOnProvider: tryOnProvider,
          home: const AuthGate(),
        ),
      );
      await tester.pumpAndSettle();

      // AuthScreen must be visible
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      // Verify Sign In & Create Account options exist
      expect(find.text('Sign In'), findsAtLeastNWidgets(1));
      expect(find.text('Create Account'), findsAtLeastNWidgets(1));

      // Strictly verify there is no guest button or anonymous bypass
      expect(find.textContaining('Guest', findRichText: true), findsNothing);
      expect(find.textContaining('Continue without', findRichText: true), findsNothing);
      expect(find.textContaining('Skip', findRichText: true), findsNothing);
    });

    testWidgets('2. Authenticated user renders HomeScreen', (tester) async {
      authProvider.setAuthenticated(true, userId: 'user-auth-123', email: 'adaa@example.com');

      await tester.pumpWidget(
        createTestApp(
          authProvider: authProvider,
          wardrobeProvider: wardrobeProvider,
          communityProvider: communityProvider,
          analysisProvider: analysisProvider,
          outfitsProvider: outfitsProvider,
          tryOnProvider: tryOnProvider,
          home: const AuthGate(),
        ),
      );
      await tester.pump();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(AuthScreen), findsNothing);
    });

    testWidgets('3. SessionManager.clearAllUserData wipes state across all providers and resets auth token', (tester) async {
      ApiClient.authToken = 'valid-test-token-123';

      // Seed state
      wardrobeProvider.items = [
        WardrobeItem(
          id: 'item-1',
          name: 'Navy Cashmere Sweater',
          category: 'sweaters',
          primaryColor: 'navy',
          imagePath: 'items/item-1.jpg',
          imageUrl: 'https://example.com/item-1.jpg',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          authProvider: authProvider,
          wardrobeProvider: wardrobeProvider,
          communityProvider: communityProvider,
          analysisProvider: analysisProvider,
          outfitsProvider: outfitsProvider,
          tryOnProvider: tryOnProvider,
          notificationProvider: notificationProvider,
          stylistProvider: stylistProvider,
          home: Builder(
            builder: (ctx) {
              return ElevatedButton(
                onPressed: () => SessionManager.clearAllUserData(ctx),
                child: const Text('Clear All'),
              );
            },
          ),
        ),
      );
      await tester.pump();

      expect(wardrobeProvider.items.length, 1);
      expect(ApiClient.authToken, 'valid-test-token-123');

      // Trigger clear
      await tester.tap(find.text('Clear All'));
      await tester.pump();

      expect(wardrobeProvider.items, isEmpty);
      expect(communityProvider.communities, isEmpty);
      expect(communityProvider.myCommunities, isEmpty);
      expect(communityProvider.sharedClosetItems, isEmpty);
      expect(analysisProvider.currentAnalysis, isNull);
      expect(analysisProvider.history, isEmpty);
      expect(analysisProvider.currentMatchResult, isNull);
      expect(outfitsProvider.outfits, isEmpty);
      expect(tryOnProvider.activeTask, isNull);
      expect(notificationProvider.notifications, isEmpty);
      expect(notificationProvider.unreadCount, 0);
      expect(stylistProvider.outfits, isEmpty);
      expect(ApiClient.authToken, isNull);
    });

    testWidgets('4. Logout flow invalidates session, clears data, and displays LogoutSuccessScreen', (tester) async {
      authProvider.setAuthenticated(true, userId: 'user-logout-test');
      ApiClient.authToken = 'active-jwt-token';

      wardrobeProvider.items = [
        WardrobeItem(
          id: 'w-item-secure',
          name: 'Silk Shirt',
          category: 'tops',
          primaryColor: 'black',
          imagePath: 'items/silk-shirt.jpg',
          imageUrl: 'https://example.com/silk-shirt.jpg',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          authProvider: authProvider,
          wardrobeProvider: wardrobeProvider,
          communityProvider: communityProvider,
          analysisProvider: analysisProvider,
          outfitsProvider: outfitsProvider,
          tryOnProvider: tryOnProvider,
          home: Builder(
            builder: (ctx) {
              return ElevatedButton(
                onPressed: () => SessionManager.performLogout(ctx),
                child: const Text('Sign Out Button'),
              );
            },
          ),
        ),
      );
      await tester.pump();

      expect(authProvider.isAuthenticated, isTrue);
      expect(wardrobeProvider.items.length, 1);
      expect(ApiClient.authToken, 'active-jwt-token');

      // Tap Sign Out
      await tester.tap(find.text('Sign Out Button'));
      await tester.pumpAndSettle();

      // Verify LogoutSuccessScreen is visible
      expect(find.byType(LogoutSuccessScreen), findsOneWidget);
      expect(find.text('Successfully Signed Out'), findsOneWidget);
      expect(find.text('SESSION SECURELY CLOSED'), findsOneWidget);

      // Verify all cached data is invalidated
      expect(authProvider.isAuthenticated, isFalse);
      expect(wardrobeProvider.items, isEmpty);
      expect(ApiClient.authToken, isNull);

      // Verify "Return to Sign In" navigates to AuthScreen and wipes history
      await tester.tap(find.text('Return to Sign In'));
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byType(LogoutSuccessScreen), findsNothing);
    });

    testWidgets('5. Session expiration handler purges state and informs user', (tester) async {
      authProvider.setAuthenticated(true);
      ApiClient.authToken = 'expired-jwt-token';

      wardrobeProvider.items = [
        WardrobeItem(
          id: 'w-item-secret',
          name: 'Designer Coat',
          category: 'outerwear',
          primaryColor: 'beige',
          imagePath: 'items/coat.jpg',
          imageUrl: 'https://example.com/coat.jpg',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          authProvider: authProvider,
          wardrobeProvider: wardrobeProvider,
          communityProvider: communityProvider,
          analysisProvider: analysisProvider,
          outfitsProvider: outfitsProvider,
          tryOnProvider: tryOnProvider,
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () => SessionManager.handleSessionExpired(ctx),
                  child: const Text('Simulate 401 Expiry'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Simulate 401 Expiry'));
      await tester.pumpAndSettle();

      // State purged
      expect(wardrobeProvider.items, isEmpty);
      expect(ApiClient.authToken, isNull);
      expect(authProvider.isAuthenticated, isFalse);

      // SnackBar displayed
      expect(find.text('Your session has expired. Please sign in again.'), findsOneWidget);
    });

    testWidgets('6. Account switching never leaks User A cached data to User B', (tester) async {
      // Step A: User A logs in and has items in wardrobe and community
      authProvider.setAuthenticated(true, userId: 'user-A', email: 'userA@adaa.app');
      ApiClient.authToken = 'token-user-a';
      wardrobeProvider.items = [
        WardrobeItem(
          id: 'item-user-a',
          name: 'User A Vintage Leather Jacket',
          category: 'outerwear',
          primaryColor: 'brown',
          imagePath: 'items/leather.jpg',
          imageUrl: 'https://example.com/leather.jpg',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          authProvider: authProvider,
          wardrobeProvider: wardrobeProvider,
          communityProvider: communityProvider,
          analysisProvider: analysisProvider,
          outfitsProvider: outfitsProvider,
          tryOnProvider: tryOnProvider,
          home: Builder(
            builder: (ctx) {
              return ElevatedButton(
                onPressed: () => SessionManager.performLogout(ctx),
                child: const Text('Logout User A'),
              );
            },
          ),
        ),
      );
      await tester.pump();

      expect(wardrobeProvider.items.first.name, 'User A Vintage Leather Jacket');

      // User A logs out
      await tester.tap(find.text('Logout User A'));
      await tester.pumpAndSettle();

      expect(wardrobeProvider.items, isEmpty);
      expect(ApiClient.authToken, isNull);

      // User B logs in
      authProvider.setAuthenticated(true, userId: 'user-B', email: 'userB@adaa.app');
      ApiClient.authToken = 'token-user-b';

      // User B has not loaded items yet -> state must be completely clean and isolated
      expect(wardrobeProvider.items, isEmpty);
      expect(communityProvider.communities, isEmpty);
      expect(communityProvider.sharedClosetItems, isEmpty);

      // User B adds their own item
      wardrobeProvider.items = [
        WardrobeItem(
          id: 'item-user-b',
          name: 'User B Silk Scarf',
          category: 'accessories',
          primaryColor: 'red',
          imagePath: 'items/scarf.jpg',
          imageUrl: 'https://example.com/scarf.jpg',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // Verify only User B items exist and zero traces of User A
      expect(wardrobeProvider.items.length, 1);
      expect(wardrobeProvider.items.first.name, 'User B Silk Scarf');
      expect(wardrobeProvider.items.any((it) => it.id == 'item-user-a'), isFalse);
    });

    test('7. ApiClient 401 response invokes onSessionExpired and clears authToken', () {
      bool expiredCalled = false;
      ApiClient.onSessionExpired = () {
        expiredCalled = true;
      };
      ApiClient.authToken = 'some-unauthorized-token';

      final _ = ApiException('Could not validate credentials', 401);

      expect(expiredCalled, isTrue);
      expect(ApiClient.authToken, isNull);
    });
  });
}
