import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wardrobelens/core/auth/supabase_auth_service.dart';
import 'package:wardrobelens/core/models/garment_item.dart';
import 'package:wardrobelens/core/models/wardrobe_item.dart';
import 'package:wardrobelens/core/models/outfit_match.dart';
import 'package:wardrobelens/core/network/api_endpoints.dart';
import 'package:wardrobelens/core/network/api_client.dart';
import 'package:wardrobelens/state/analysis_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:wardrobelens/core/widgets/private_image_view.dart';
import 'package:wardrobelens/features/wardrobe/screens/add_wardrobe_item_screen.dart';
import 'package:wardrobelens/features/wardrobe/screens/wardrobe_detail_screen.dart';
import 'package:wardrobelens/features/wardrobe/screens/wardrobe_screen.dart';
import 'package:wardrobelens/main.dart';
import 'package:wardrobelens/state/auth_provider.dart';
import 'package:wardrobelens/state/wardrobe_provider.dart';

void main() {
  group('Models Serialization Unit Tests', () {
    test('DetectedFashionItem fromJson and toJson round-trip', () {
      final json = {
        'id': 'item-101',
        'category': 'jackets',
        'sub_category': 'Wool Blazer',
        'name': 'Navy Tailored Blazer',
        'primary_color': 'Navy',
        'secondary_color': 'Black',
        'attributes': {
          'material': 'wool',
          'fit': 'tailored',
          'pattern': 'solid',
          'formality': 'smart-casual',
        },
        'confidence': 0.95,
        'bounding_box_description': 'Upper layer',
      };

      final item = DetectedFashionItem.fromJson(json);
      expect(item.id, 'item-101');
      expect(item.category, 'jackets');
      expect(item.name, 'Navy Tailored Blazer');
      expect(item.attributes.material, 'wool');

      final serialized = item.toJson();
      expect(serialized['name'], 'Navy Tailored Blazer');
      expect(serialized['primary_color'], 'Navy');
    });

    test('WardrobeItem fromJson parsing', () {
      final json = {
        'id': 'w-202',
        'name': 'White Linen Shirt',
        'category': 'shirts',
        'primary_color': 'White',
        'tags': ['summer', 'breathable'],
        'image_path': 'wardrobe/test.jpg',
        'image_url': '/storage/wardrobe/test.jpg',
        'created_at': '2026-10-19T12:00:00Z',
        'updated_at': '2026-10-19T12:00:00Z',
      };

      final item = WardrobeItem.fromJson(json);
      expect(item.id, 'w-202');
      expect(item.category, 'shirts');
      expect(item.tags, contains('summer'));
    });

    test('OutfitMatchResponse parsing', () {
      final json = {
        'total_outfit_items': 3,
        'matched_count': 2,
        'missing_count': 1,
        'completeness_percentage': 66.7,
        'item_matches': [],
        'missing_items': [],
      };

      final match = OutfitMatchResponse.fromJson(json);
      expect(match.totalOutfitItems, 3);
      expect(match.matchedCount, 2);
      expect(match.completenessPercentage, 66.7);
    });
  });

  group('Network & State Management Tests', () {
    test('ApiEndpoints setBaseUrl and candidateUrls', () {
      final initial = ApiEndpoints.baseUrl;
      expect(initial, isNotEmpty);

      ApiEndpoints.setBaseUrl('http://192.168.1.50:8000/');
      expect(ApiEndpoints.baseUrl, 'http://192.168.1.50:8000');
      expect(ApiEndpoints.analyzeImage, 'http://192.168.1.50:8000/api/analysis/analyze-image');
      expect(ApiEndpoints.candidateUrls, contains('http://192.168.1.50:8000'));
      expect(ApiEndpoints.candidateUrls, contains('http://127.0.0.1:8000'));

      // Restore default
      ApiEndpoints.setBaseUrl(initial);
    });

    test('AnalysisProvider preserves lastAnalyzedFile and error clearing', () {
      final provider = AnalysisProvider();
      expect(provider.lastAnalyzedFile, isNull);
      expect(provider.error, isNull);

      provider.clearError();
      expect(provider.error, isNull);
    });
  });

  group('WardrobeLensApp Widget Tests', () {
    testWidgets('App renders Home Screen with WardrobeLens branding', (WidgetTester tester) async {
      await tester.pumpWidget(const WardrobeLensApp());
      await tester.pump();

      // Check title elements
      expect(find.text('WARDROBE'), findsOneWidget);
      expect(find.text('LENS'), findsOneWidget);

      // Check hero action
      expect(find.text('Upload Outfit Photo'), findsOneWidget);
      expect(find.text('Digital Wardrobe'), findsOneWidget);
      expect(find.text('YouCam Virtual Try-On'), findsOneWidget);
    });
  });

  group('AuthProvider & Supabase Auth Unit Tests', () {
    test('AuthProvider defaults to unauthenticated anonymous state without crashing', () {
      final auth = AuthProvider();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.user, isNull);
      expect(auth.accessToken, isNull);
      expect(auth.displayName, 'Guest');
      expect(auth.isLoading, isFalse);
      expect(auth.errorMessage, isNull);
    });

    test('AuthProvider clearError resets error state', () {
      final auth = AuthProvider();
      auth.clearError();
      expect(auth.errorMessage, isNull);
    });

    test('ApiClient authToken gets attached and cleared properly', () {
      ApiClient.authToken = 'mock-supabase-jwt-token';
      expect(ApiClient.authToken, 'mock-supabase-jwt-token');

      ApiClient.authToken = null;
      expect(ApiClient.authToken, isNull);
    });

    test('Successful sign-up returns no active session before confirmation', () async {
      final mockService = MockSupabaseAuthService();
      final auth = AuthProvider(authService: mockService);

      final result = await auth.signUpWithEmail('student@campus.edu', 'SecurePass123!');
      expect(result.status, SignUpResultStatus.needsEmailConfirmation);
      expect(result.success, isTrue);
      expect(result.email, 'student@campus.edu');

      // Crucial security boundary: unconfirmed user MUST NOT be treated as authenticated
      expect(auth.isAuthenticated, isFalse);
      expect(auth.session, isNull);
      expect(auth.user, isNull);
      expect(ApiClient.authToken, isNull);
    });

    test('Duplicate account sign-up returns alreadyRegistered without leaking active session', () async {
      final mockService = MockSupabaseAuthService();
      mockService.shouldReturnDuplicateSignUp = true;
      final auth = AuthProvider(authService: mockService);

      final result = await auth.signUpWithEmail('existing@campus.edu', 'SecurePass123!');
      expect(result.status, SignUpResultStatus.alreadyRegistered);
      expect(result.success, isTrue);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.session, isNull);
      expect(ApiClient.authToken, isNull);
    });

    test('Sign-up failure captures error properly', () async {
      final mockService = MockSupabaseAuthService();
      mockService.shouldFailSignUp = true;
      final auth = AuthProvider(authService: mockService);

      final result = await auth.signUpWithEmail('bad-format', '123');
      expect(result.status, SignUpResultStatus.failed);
      expect(result.success, isFalse);
      expect(auth.errorMessage, isNotNull);
      expect(auth.isAuthenticated, isFalse);
    });

    test('Unconfirmed account sign-in is rejected and displays verification guidance', () async {
      final mockService = MockSupabaseAuthService();
      mockService.shouldFailSignInUnconfirmed = true;
      final auth = AuthProvider(authService: mockService);

      final success = await auth.signInWithEmail('unconfirmed@campus.edu', 'Pass123!');
      expect(success, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.errorMessage, contains('Email not verified'));
    });

    test('Resend confirmation email succeeds and handles rate limits', () async {
      final mockService = MockSupabaseAuthService();
      final auth = AuthProvider(authService: mockService);

      final resendSuccess = await auth.resendConfirmationEmail('student@campus.edu');
      expect(resendSuccess, isTrue);
      expect(auth.infoMessage, contains('Confirmation email resent'));

      // Test rate limit handling
      mockService.shouldFailRateLimit = true;
      final rateLimitSuccess = await auth.resendConfirmationEmail('student@campus.edu');
      expect(rateLimitSuccess, isFalse);
      expect(auth.errorMessage, contains('wait a minute'));
    });

    test('Confirmed account sign-in succeeds, attaches bearer token, and sets displayName', () async {
      final mockService = MockSupabaseAuthService();
      final auth = AuthProvider(authService: mockService);

      final success = await auth.signInWithEmail('student@campus.edu', 'CorrectPass123!');
      expect(success, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.session, isNotNull);
      expect(auth.accessToken, 'valid-confirmed-jwt-token');
      expect(ApiClient.authToken, 'valid-confirmed-jwt-token');
      expect(auth.displayName, 'Verified Student');
      expect(auth.email, 'student@campus.edu');
    });

    test('Sign-out immediately clears token, session, and user state', () async {
      final mockService = MockSupabaseAuthService();
      final auth = AuthProvider(authService: mockService);

      await auth.signInWithEmail('student@campus.edu', 'CorrectPass123!');
      expect(auth.isAuthenticated, isTrue);
      expect(ApiClient.authToken, isNotNull);

      await auth.signOut();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.user, isNull);
      expect(auth.session, isNull);
      expect(auth.accessToken, isNull);
      expect(ApiClient.authToken, isNull);
    });

    test('Google OAuth surfaces user-friendly error when provider is unconfigured in Supabase', () async {
      final mockService = MockSupabaseAuthService();
      mockService.shouldFailGoogleDisabled = true;
      final auth = AuthProvider(authService: mockService);

      final success = await auth.signInWithGoogle();
      expect(success, isFalse);
      expect(auth.errorMessage, contains('Google Sign-In is not yet enabled'));
      expect(auth.isAuthenticated, isFalse);
    });

    test('Google OAuth success establishes authenticated session and attaches token', () async {
      final mockService = MockSupabaseAuthService();
      final auth = AuthProvider(authService: mockService);

      final success = await auth.signInWithGoogle();
      expect(success, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(ApiClient.authToken, 'google-oauth-jwt-token');
      expect(auth.displayName, 'Google Campus User');
    });

    test('Deep link confirmation callback emits signedIn and displays success notice', () async {
      final mockService = MockSupabaseAuthService();
      final auth = AuthProvider(authService: mockService);

      final user = User.fromJson({
        'id': 'u-callback-1',
        'app_metadata': {'provider': 'email'},
        'user_metadata': {'full_name': 'Confirmed Callback User'},
        'aud': 'authenticated',
        'created_at': DateTime.now().toIso8601String(),
        'email': 'callback@campus.edu',
        'email_confirmed_at': DateTime.now().toIso8601String(),
      })!;
      final session = Session(
        accessToken: 'deep-link-callback-jwt-token',
        tokenType: 'bearer',
        user: user,
      );

      // Simulate incoming deep link callback
      mockService.authStateController.add(AuthState(AuthChangeEvent.signedIn, session));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(auth.isAuthenticated, isTrue);
      expect(ApiClient.authToken, 'deep-link-callback-jwt-token');
      expect(auth.infoMessage, contains('Email verified successfully'));
      expect(auth.displayName, 'Confirmed Callback User');
    });
  });

  group('Milestone 2A Private Image & Storage Privacy Tests', () {
    test('ApiEndpoints correctly handles relative local storage vs Cloudinary URLs', () {
      final localUrl = ApiEndpoints.resolveImageUrl('/storage/wardrobe/garment_123.jpg');
      expect(localUrl, startsWith(ApiEndpoints.baseUrl));
      expect(localUrl, endsWith('/storage/wardrobe/garment_123.jpg'));

      const cloudUrl = 'https://res.cloudinary.com/test-cloud/image/authenticated/s--abc--/v1/item.jpg';
      final resolvedCloud = ApiEndpoints.resolveImageUrl(cloudUrl);
      expect(resolvedCloud, cloudUrl); // Cloudinary URL must not be prefixed with localhost
    });

    test('ApiClient attaches bearer token to request headers when signed in', () {
      ApiClient.authToken = 'test-verified-jwt-bearer';
      final headers = ApiClient.authHeaders;
      expect(headers['Authorization'], 'Bearer test-verified-jwt-bearer');

      ApiClient.authToken = null;
      final emptyHeaders = ApiClient.authHeaders;
      expect(emptyHeaders.containsKey('Authorization'), isFalse);
    });

    test('Sign-out purges imageCache memory to prevent cross-session leakage', () async {
      final mockService = MockSupabaseAuthService();
      final auth = AuthProvider(authService: mockService);

      await auth.signInWithEmail('student@campus.edu', 'CorrectPass123!');
      expect(auth.isAuthenticated, isTrue);

      // Sign out
      await auth.signOut();
      expect(auth.isAuthenticated, isFalse);
      expect(ApiClient.authToken, isNull);
      // Image cache was purged by signOut()
      expect(PaintingBinding.instance.imageCache.currentSizeBytes, 0);
    });

    testWidgets('PrivateImageView renders placeholder when imageUrl is null or empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrivateImageView(
              imageUrl: null,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.checkroom), findsOneWidget);
    });

    testWidgets('PrivateImageView renders custom placeholder and errorWidget', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrivateImageView(
              imageUrl: '',
              placeholder: Text('Custom Placeholder Widget'),
            ),
          ),
        ),
      );

      expect(find.text('Custom Placeholder Widget'), findsOneWidget);
    });
  });

  group('Milestone 2B Personal Wardrobe Experience Tests', () {
    test('WardrobeItem serialization & deserialization includes brand, size, condition, notes', () {
      final json = {
        'id': 'w-301',
        'name': 'Selvedge Denim Jeans',
        'category': 'bottoms',
        'primary_color': 'Indigo',
        'brand': 'Levi\'s',
        'size': '32/30',
        'condition': 'Good',
        'notes': 'Stiff selvedge, cuffs rolled',
        'tags': ['denim', 'everyday'],
        'image_path': 'wardrobe/denim.jpg',
        'image_url': 'https://res.cloudinary.com/test/image/authenticated/s--123--/v1/denim.jpg',
        'created_at': '2026-10-20T08:00:00Z',
        'updated_at': '2026-10-20T09:00:00Z',
      };

      final item = WardrobeItem.fromJson(json);
      expect(item.id, 'w-301');
      expect(item.brand, 'Levi\'s');
      expect(item.size, '32/30');
      expect(item.condition, 'Good');
      expect(item.notes, 'Stiff selvedge, cuffs rolled');

      final serialized = item.toJson();
      expect(serialized['brand'], 'Levi\'s');
      expect(serialized['size'], '32/30');
      expect(serialized['condition'], 'Good');
      expect(serialized['notes'], 'Stiff selvedge, cuffs rolled');
    });

    test('WardrobeProvider state methods update category, search, and error clearing', () {
      final fake = FakeWardrobeProvider(error: 'Initial error');
      expect(fake.error, 'Initial error');
      fake.clearError();
      expect(fake.error, isNull);

      fake.setCategory('shoes');
      expect(fake.selectedCategory, 'shoes');

      fake.setSearchQuery('linen');
      expect(fake.searchQuery, 'linen');
    });

    testWidgets('WardrobeScreen renders empty closet guidance when items is empty', (WidgetTester tester) async {
      final fakeProvider = FakeWardrobeProvider(items: []);
      await tester.pumpWidget(
        ChangeNotifierProvider<WardrobeProvider>.value(
          value: fakeProvider,
          child: const MaterialApp(
            home: WardrobeScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Digital Wardrobe'), findsOneWidget);
      expect(find.text('Personal closet & garment manager'), findsOneWidget);
      expect(find.text('Your Wardrobe is Empty'), findsOneWidget);
      expect(find.text('Add Your First Piece'), findsOneWidget);
    });

    testWidgets('WardrobeScreen renders garment cards with category badges and brands', (WidgetTester tester) async {
      final sampleItem = WardrobeItem(
        id: 'w-test-1',
        name: 'Classic Linen Button-Down',
        category: 'tops',
        primaryColor: 'White',
        brand: 'Ralph Lauren',
        size: 'L',
        condition: 'Like New',
        notes: 'Dry clean recommended',
        tags: ['classic', 'summer'],
        imagePath: 'wardrobe/test_item.jpg',
        imageUrl: '',
        createdAt: DateTime(2026, 10, 19, 10, 0),
        updatedAt: DateTime(2026, 10, 19, 12, 0),
      );
      final fakeProvider = FakeWardrobeProvider(items: [sampleItem]);
      await tester.pumpWidget(
        ChangeNotifierProvider<WardrobeProvider>.value(
          value: fakeProvider,
          child: const MaterialApp(
            home: WardrobeScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('1 garment in closet'), findsOneWidget);
      expect(find.text('ALL GARMENTS (1)'), findsOneWidget);
      expect(find.text('Classic Linen Button-Down'), findsOneWidget);
      expect(find.text('TOPS'), findsWidgets);
      expect(find.textContaining('Ralph Lauren'), findsOneWidget);
    });

    testWidgets('WardrobeScreen renders error state and Try Again button', (WidgetTester tester) async {
      final fakeProvider = FakeWardrobeProvider(error: 'Network error connecting to closet backend');
      await tester.pumpWidget(
        ChangeNotifierProvider<WardrobeProvider>.value(
          value: fakeProvider,
          child: const MaterialApp(
            home: WardrobeScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Network error connecting to closet backend'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('WardrobeScreen renders filtered empty state with Reset Filters button', (WidgetTester tester) async {
      final fakeProvider = FakeWardrobeProvider(items: [], selectedCategory: 'shoes');
      await tester.pumpWidget(
        ChangeNotifierProvider<WardrobeProvider>.value(
          value: fakeProvider,
          child: const MaterialApp(
            home: WardrobeScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No matching garments'), findsOneWidget);
      expect(find.text('Reset Filters'), findsOneWidget);
    });

    testWidgets('WardrobeDetailScreen displays specification matrix and Change Photo action', (WidgetTester tester) async {
      final sampleItem = WardrobeItem(
        id: 'w-test-1',
        name: 'Classic Linen Button-Down',
        category: 'tops',
        primaryColor: 'White',
        brand: 'Ralph Lauren',
        size: 'L',
        condition: 'Like New',
        notes: 'Dry clean recommended, capsule staple',
        tags: ['classic', 'summer'],
        imagePath: 'wardrobe/test_item.jpg',
        imageUrl: '',
        createdAt: DateTime(2026, 10, 19, 10, 0),
        updatedAt: DateTime(2026, 10, 19, 12, 0),
      );
      final fakeProvider = FakeWardrobeProvider(items: [sampleItem]);
      await tester.pumpWidget(
        ChangeNotifierProvider<WardrobeProvider>.value(
          value: fakeProvider,
          child: MaterialApp(
            home: WardrobeDetailScreen(item: sampleItem),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Classic Linen Button-Down'), findsWidgets);
      expect(find.text('Ralph Lauren'), findsWidgets);
      expect(find.text('Like New'), findsOneWidget);
      expect(find.text('L'), findsOneWidget);
      expect(find.text('Dry clean recommended, capsule staple'), findsOneWidget);
      expect(find.text('Change Photo'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('WardrobeDetailScreen shows confirmation dialog before deleting', (WidgetTester tester) async {
      final sampleItem = WardrobeItem(
        id: 'w-test-delete',
        name: 'Vintage Silk Scarf',
        category: 'accessories',
        primaryColor: 'Burgundy',
        tags: ['vintage'],
        imagePath: 'wardrobe/scarf.jpg',
        imageUrl: '',
        createdAt: DateTime(2026, 10, 19, 10, 0),
        updatedAt: DateTime(2026, 10, 19, 12, 0),
      );
      final fakeProvider = FakeWardrobeProvider(items: [sampleItem]);
      await tester.pumpWidget(
        ChangeNotifierProvider<WardrobeProvider>.value(
          value: fakeProvider,
          child: MaterialApp(
            home: WardrobeDetailScreen(item: sampleItem),
          ),
        ),
      );
      await tester.pump();

      // Tap delete icon in AppBar
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Remove from Wardrobe?'), findsOneWidget);
      expect(find.text('Remove Piece'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Remove Piece
      await tester.tap(find.text('Remove Piece'));
      await tester.pumpAndSettle();

      expect(fakeProvider.deleteItemCalled, isTrue);
      expect(fakeProvider.lastDeletedId, 'w-test-delete');
    });

    testWidgets('AddWardrobeItemScreen validates that image is picked before saving', (WidgetTester tester) async {
      final fakeProvider = FakeWardrobeProvider();
      await tester.pumpWidget(
        ChangeNotifierProvider<WardrobeProvider>.value(
          value: fakeProvider,
          child: const MaterialApp(
            home: AddWardrobeItemScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Add Garment'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Tap Save without selecting image
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('Please select or capture a photo of the clothing item.'), findsOneWidget);
    });
  });
}

class FakeWardrobeProvider extends ChangeNotifier implements WardrobeProvider {
  @override
  List<WardrobeItem> items;
  @override
  List<Map<String, dynamic>> categories;
  @override
  String selectedCategory;
  @override
  String searchQuery;
  @override
  bool isLoading;
  @override
  String? error;

  bool deleteItemCalled = false;
  String? lastDeletedId;

  FakeWardrobeProvider({
    List<WardrobeItem>? items,
    List<Map<String, dynamic>>? categories,
    this.selectedCategory = 'all',
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
  })  : items = items ?? [],
        categories = categories ?? [
          {'category': 'tops', 'count': 1},
          {'category': 'bottoms', 'count': 1},
          {'category': 'shoes', 'count': 0},
        ];

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
  void clearError() {
    error = null;
    notifyListeners();
  }

  @override
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
    return true;
  }

  @override
  Future<bool> updateItem(String id, Map<String, dynamic> updates) async {
    return true;
  }

  @override
  Future<bool> updateItemPhoto(String id, XFile file) async {
    return true;
  }

  @override
  Future<WardrobeItem?> refreshItem(String id) async {
    return null;
  }

  @override
  Future<bool> deleteItem(String id) async {
    deleteItemCalled = true;
    lastDeletedId = id;
    items.removeWhere((it) => it.id == id);
    notifyListeners();
    return true;
  }
}

class MockSupabaseAuthService extends SupabaseAuthService {
  final StreamController<AuthState> authStateController = StreamController<AuthState>.broadcast();
  User? mockCurrentUser;
  Session? mockCurrentSession;
  bool shouldFailSignUp = false;
  bool shouldReturnDuplicateSignUp = false;
  bool shouldFailSignInUnconfirmed = false;
  bool shouldFailSignInCredentials = false;
  bool shouldFailGoogleDisabled = false;
  bool shouldFailRateLimit = false;

  @override
  bool get isConfigured => true;

  @override
  User? get currentUser => mockCurrentUser;

  @override
  Session? get currentSession => mockCurrentSession;

  @override
  Stream<AuthState> get onAuthStateChange => authStateController.stream;

  @override
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    if (shouldFailSignUp) {
      throw const AuthException('Unable to validate email address: invalid format', statusCode: '400');
    }
    if (shouldReturnDuplicateSignUp) {
      final user = User.fromJson({
        'id': 'u-dup-1',
        'app_metadata': {'provider': 'email'},
        'user_metadata': {'full_name': fullName ?? ''},
        'aud': 'authenticated',
        'created_at': DateTime.now().toIso8601String(),
        'email': email,
        'identities': <dynamic>[],
      })!;
      return AuthResponse(user: user, session: null);
    }
    final user = User.fromJson({
      'id': 'u-new-1',
      'app_metadata': {'provider': 'email'},
      'user_metadata': {'full_name': fullName ?? ''},
      'aud': 'authenticated',
      'created_at': DateTime.now().toIso8601String(),
      'email': email,
      'identities': [
        {'id': 'id-1', 'user_id': 'u-new-1', 'identity_data': {'email': email}, 'provider': 'email'}
      ],
    })!;
    return AuthResponse(user: user, session: null);
  }

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (shouldFailSignInUnconfirmed) {
      throw const AuthException('Email not confirmed', statusCode: '400');
    }
    if (shouldFailSignInCredentials) {
      throw const AuthException('Invalid login credentials', statusCode: '400');
    }
    final user = User.fromJson({
      'id': 'u-confirmed-1',
      'app_metadata': {'provider': 'email'},
      'user_metadata': {'full_name': 'Verified Student'},
      'aud': 'authenticated',
      'created_at': DateTime.now().toIso8601String(),
      'email': email,
      'email_confirmed_at': DateTime.now().toIso8601String(),
    })!;
    final session = Session(
      accessToken: 'valid-confirmed-jwt-token',
      tokenType: 'bearer',
      user: user,
    );
    mockCurrentUser = user;
    mockCurrentSession = session;
    return AuthResponse(user: user, session: session);
  }

  @override
  Future<void> resendConfirmationEmail(String email) async {
    if (shouldFailRateLimit) {
      throw const AuthException('For security purposes, you can only request this after 48 seconds.', statusCode: '429');
    }
  }

  @override
  Future<bool> signInWithGoogle() async {
    if (shouldFailGoogleDisabled) {
      throw const AuthException('Unsupported provider: provider is not enabled', statusCode: '400');
    }
    final user = User.fromJson({
      'id': 'u-google-1',
      'app_metadata': {'provider': 'google'},
      'user_metadata': {'full_name': 'Google Campus User'},
      'aud': 'authenticated',
      'created_at': DateTime.now().toIso8601String(),
      'email': 'campus@gmail.com',
    })!;
    final session = Session(
      accessToken: 'google-oauth-jwt-token',
      tokenType: 'bearer',
      user: user,
    );
    mockCurrentUser = user;
    mockCurrentSession = session;
    authStateController.add(AuthState(AuthChangeEvent.signedIn, session));
    return true;
  }

  @override
  Future<void> signOut() async {
    mockCurrentUser = null;
    mockCurrentSession = null;
    authStateController.add(const AuthState(AuthChangeEvent.signedOut, null));
  }
}
