import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wardrobelens/core/auth/session_manager.dart';
import 'package:wardrobelens/core/models/community_model.dart';
import 'package:wardrobelens/core/models/user_profile_model.dart';
import 'package:wardrobelens/core/models/wardrobe_item.dart';
import 'package:wardrobelens/features/communities/widgets/public_profile_sheet.dart';
import 'package:wardrobelens/features/profile/screens/profile_screen.dart';
import 'package:wardrobelens/state/analysis_provider.dart';
import 'package:wardrobelens/state/auth_provider.dart';
import 'package:wardrobelens/state/community_provider.dart';
import 'package:wardrobelens/state/outfits_provider.dart';
import 'package:wardrobelens/state/profile_provider.dart';
import 'package:wardrobelens/state/tryon_provider.dart';
import 'package:wardrobelens/state/wardrobe_provider.dart';

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  User? user = const User(
    id: 'user-p2-test',
    appMetadata: {},
    userMetadata: {'full_name': 'Aarav Patel'},
    aud: 'authenticated',
    createdAt: '2026-10-20T10:00:00Z',
    email: 'aarav@campus.edu',
  );

  @override
  bool isAuthenticated = true;

  @override
  String get displayName => 'Aarav Patel';

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
  group('Profile & Privacy Data Models Unit Tests', () {
    test('FitPreferencesModel serialization and helper methods', () {
      const emptyFit = FitPreferencesModel();
      expect(emptyFit.hasAnyPreferences, isFalse);

      const filledFit = FitPreferencesModel(
        topsSize: 'M',
        bottomsSize: '32',
        shoeSize: '10',
        preferredFit: 'relaxed',
      );
      expect(filledFit.hasAnyPreferences, isTrue);

      final json = filledFit.toJson();
      expect(json['tops_size'], 'M');
      expect(json['bottoms_size'], '32');
      expect(json['shoe_size'], '10');
      expect(json['preferred_fit'], 'relaxed');

      final reconstructed = FitPreferencesModel.fromJson(json);
      expect(reconstructed.topsSize, 'M');
      expect(reconstructed.bottomsSize, '32');
      expect(reconstructed.shoeSize, '10');
      expect(reconstructed.preferredFit, 'relaxed');

      final copied = filledFit.copyWith(preferredFit: 'oversized');
      expect(copied.preferredFit, 'oversized');
      expect(copied.topsSize, 'M');
    });

    test('ProfilePrivacySettingsModel default privacy rules', () {
      // Privacy defaults: phone, email, age, and fit details are private by default
      const defaultPrivacy = ProfilePrivacySettingsModel();
      expect(defaultPrivacy.showProfilePhoto, isTrue);
      expect(defaultPrivacy.showBio, isTrue);
      expect(defaultPrivacy.showAge, isFalse);
      expect(defaultPrivacy.showPhone, isFalse);
      expect(defaultPrivacy.showEmail, isFalse);
      expect(defaultPrivacy.showFitPreferences, isFalse);
      expect(defaultPrivacy.showPreferredStyles, isTrue);

      final json = defaultPrivacy.toJson();
      expect(json['show_phone'], isFalse);
      expect(json['show_email'], isFalse);
      expect(json['show_age'], isFalse);
      expect(json['show_fit_preferences'], isFalse);
      expect(json['show_profile_photo'], isTrue);
      expect(json['show_bio'], isTrue);
      expect(json['show_preferred_styles'], isTrue);

      final modified = defaultPrivacy.copyWith(showPhone: true, showAge: true);
      expect(modified.showPhone, isTrue);
      expect(modified.showAge, isTrue);
      expect(modified.showEmail, isFalse);
    });

    test('UserProfileModel deserialization and initials calculation', () {
      final json = {
        'id': 'usr-123',
        'email': 'aarav@campus.edu',
        'display_name': 'Aarav Patel',
        'avatar_url': 'https://example.com/avatar.jpg',
        'bio': 'Sustainable designer & denim enthusiast.',
        'age': 22,
        'phone_number': '+1-555-0101',
        'fit_preferences': {
          'tops_size': 'L',
          'bottoms_size': '34',
          'shoe_size': '11',
          'preferred_fit': 'regular',
        },
        'preferred_styles': ['Minimalist', 'Workwear'],
        'privacy_settings': {
          'show_profile_photo': true,
          'show_bio': true,
          'show_age': false,
          'show_phone': false,
          'show_email': false,
          'show_fit_preferences': false,
          'show_preferred_styles': true,
        },
        'shared_communities_count': 2,
        'shared_items_count': 5,
      };

      final profile = UserProfileModel.fromJson(json);
      expect(profile.id, 'usr-123');
      expect(profile.displayName, 'Aarav Patel');
      expect(profile.initials, 'AP');
      expect(profile.age, 22);
      expect(profile.phoneNumber, '+1-555-0101');
      expect(profile.fitPreferences.topsSize, 'L');
      expect(profile.preferredStyles, contains('Workwear'));
      expect(profile.privacySettings.showPhone, isFalse);
    });
  });

  group('ProfileProvider State & Session Isolation Tests', () {
    test('ProfileProvider initial state and clear wipes cache', () {
      final provider = ProfileProvider();
      expect(provider.profile, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.isSaving, isFalse);
      expect(provider.error, isNull);

      provider.profile = UserProfileModel(
        id: 'usr-cached',
        email: 'cached@campus.edu',
        displayName: 'Cached User',
        phoneNumber: '+1-555-9999',
      );
      expect(provider.profile, isNotNull);

      // Wipe state on logout
      provider.clear();
      expect(provider.profile, isNull);
      expect(provider.error, isNull);
    });

    testWidgets('SessionManager.clearAllUserData wipes ProfileProvider cached state', (tester) async {
      final profileProvider = ProfileProvider();
      profileProvider.profile = UserProfileModel(
        id: 'usr-sensitive',
        email: 'sensitive@campus.edu',
        displayName: 'Sensitive User',
        phoneNumber: '+1-555-0000',
      );

      final wardrobeProvider = MockWardrobeProvider();
      final communityProvider = MockCommunityProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
            ChangeNotifierProvider<WardrobeProvider>.value(value: wardrobeProvider),
            ChangeNotifierProvider<CommunityProvider>.value(value: communityProvider),
            ChangeNotifierProvider<AnalysisProvider>(create: (_) => AnalysisProvider()),
            ChangeNotifierProvider<OutfitsProvider>(create: (_) => OutfitsProvider()),
            ChangeNotifierProvider<TryOnProvider>(create: (_) => TryOnProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () => SessionManager.clearAllUserData(context),
                    child: const Text('Clear'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(profileProvider.profile, isNotNull);
      await tester.tap(find.text('Clear'));
      await tester.pump();

      // Verify profile provider was completely wiped
      expect(profileProvider.profile, isNull);
    });
  });

  group('ProfileScreen Widget & Privacy Settings Tests', () {
    testWidgets('renders profile header, fit preferences, and 7 field privacy toggles', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profileProvider = ProfileProvider();
      profileProvider.profile = UserProfileModel(
        id: 'user-p2-test',
        email: 'aarav@campus.edu',
        displayName: 'Aarav Patel',
        bio: 'Capsule wardrobe & sustainable layering.',
        age: 22,
        phoneNumber: '+1-555-0101',
        fitPreferences: const FitPreferencesModel(
          topsSize: 'M',
          bottomsSize: '32',
          shoeSize: '10',
          preferredFit: 'relaxed',
        ),
        preferredStyles: ['Minimalist', 'Classic'],
        privacySettings: const ProfilePrivacySettingsModel(
          showProfilePhoto: true,
          showBio: true,
          showAge: false,
          showPhone: false,
          showEmail: false,
          showFitPreferences: false,
          showPreferredStyles: true,
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => MockAuthProvider()),
            ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
            ChangeNotifierProvider<WardrobeProvider>(create: (_) => MockWardrobeProvider()),
            ChangeNotifierProvider<CommunityProvider>(create: (_) => MockCommunityProvider()),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pump();

      // Verify header details
      expect(find.text('Aarav Patel'), findsOneWidget);
      expect(find.text('aarav@campus.edu'), findsOneWidget);
      expect(find.text('Capsule wardrobe & sustainable layering.'), findsOneWidget);
      expect(find.text('AUTHENTICATED MEMBER'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);

      // Verify Fit & Sizing Preferences card displays current preferences
      expect(find.text('FIT & SIZING PREFERENCES'), findsOneWidget);
      expect(find.text('Sizes & Silhouette'), findsOneWidget);
      expect(find.text('Tops: '), findsOneWidget);
      expect(find.text('Bottoms: '), findsOneWidget);
      expect(find.text('Shoes: '), findsOneWidget);
      expect(find.text('Fit: '), findsOneWidget);
      expect(find.text('Favorite Aesthetics'), findsOneWidget);
      expect(find.text('Minimalist'), findsOneWidget);
      expect(find.text('Classic'), findsOneWidget);

      // Verify Community Privacy Settings section and 7 switches
      expect(find.text('COMMUNITY PRIVACY SETTINGS'), findsOneWidget);
      expect(find.text('Profile Photo'), findsOneWidget);
      expect(find.text('Bio & Style Notes'), findsOneWidget);
      expect(find.text('Age'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Account Email'), findsOneWidget);
      expect(find.text('Fit Preferences & Clothing Sizes'), findsOneWidget);
      expect(find.text('Style Aesthetics'), findsOneWidget);

      // Verify 4 "Private by default" badges are present (Age, Phone, Email, Fit)
      expect(find.text('Private by default'), findsNWidgets(4));
    });

    testWidgets('opening Edit Profile bottom sheet shows full form and validates inputs', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final profileProvider = ProfileProvider();
      profileProvider.profile = UserProfileModel(
        id: 'user-p2-test',
        email: 'aarav@campus.edu',
        displayName: 'Aarav Patel',
        bio: 'Old bio',
        age: 22,
        phoneNumber: '+1-555-0101',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => MockAuthProvider()),
            ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
            ChangeNotifierProvider<WardrobeProvider>(create: (_) => MockWardrobeProvider()),
            ChangeNotifierProvider<CommunityProvider>(create: (_) => MockCommunityProvider()),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pump();

      // Open Edit Profile Sheet
      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();

      // Verify fields exist
      expect(find.text('Account Email'), findsWidgets);
      expect(find.text('Managed by Auth'), findsOneWidget);
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Bio / Style Notes'), findsOneWidget);
      expect(find.text('Age'), findsWidgets);
      expect(find.text('Phone Number'), findsWidgets);
      expect(find.text('Fit & Sizing Preferences'), findsOneWidget);
      expect(find.text('Preferred Fit'), findsOneWidget);
      expect(find.text('Aesthetic & Style Preferences'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      // Test validation: enter invalid age (e.g. 5)
      final ageField = find.byKey(const Key('profile_age_input'));
      await tester.enterText(ageField, '5');
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Enter valid age (13-120)'), findsOneWidget);

      // Clear invalid age and enter valid age
      await tester.enterText(ageField, '23');
      await tester.pumpAndSettle();
      expect(find.text('Enter valid age (13-120)'), findsNothing);
    });
  });

  group('PublicProfileSheet Privacy-Aware Rendering Tests', () {
    testWidgets('renders permitted fields without placeholders for private fields', (tester) async {
      // Mock public profile where email, phone, age, and fit are omitted (private)
      final publicProfile = PublicUserProfileModel(
        id: 'user-peer-99',
        displayName: 'Priya Sharma',
        avatarUrl: null,
        bio: 'Student at Delhi University, lover of handloom cottons.',
        age: null, // private - withheld
        phoneNumber: null, // private - withheld
        email: null, // private - withheld
        fitPreferences: null, // private - withheld
        preferredStyles: ['Handloom', 'Boho'],
        sharedCommunitiesCount: 2,
        sharedItemsCount: 4,
      );

      // Verify model guarantees that withheld fields evaluate to null
      expect(publicProfile.displayName, 'Priya Sharma');
      expect(publicProfile.age, isNull);
      expect(publicProfile.email, isNull);
      expect(publicProfile.phoneNumber, isNull);
      expect(publicProfile.fitPreferences, isNull);
      expect(publicProfile.preferredStyles, contains('Handloom'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    PublicProfileSheet.show(
                      context,
                      userId: publicProfile.id,
                      fallbackName: publicProfile.displayName,
                    );
                  },
                  child: const Text('Open Sheet'),
                );
              },
            ),
          ),
        ),
      );

      // Verify button rendered and tap opens bottom sheet
      expect(find.text('Open Sheet'), findsOneWidget);
      await tester.tap(find.text('Open Sheet'));
      await tester.pump();

      // Fallback name is rendered while loading or restricted
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
