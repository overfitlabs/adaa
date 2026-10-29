import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wardrobelens/core/models/community_model.dart';
import 'package:wardrobelens/core/models/user_profile_model.dart';
import 'package:wardrobelens/core/models/wardrobe_item.dart';
import 'package:wardrobelens/features/profile/screens/profile_screen.dart';
import 'package:wardrobelens/state/auth_provider.dart';
import 'package:wardrobelens/state/community_provider.dart';
import 'package:wardrobelens/state/profile_provider.dart';
import 'package:wardrobelens/state/wardrobe_provider.dart';

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  User? user = const User(
    id: 'user-signout-test',
    appMetadata: {},
    userMetadata: {'full_name': 'Test User'},
    aud: 'authenticated',
    createdAt: '2026-10-20T10:00:00Z',
    email: 'test@adaa.style',
  );

  @override
  bool isAuthenticated = true;

  @override
  String get displayName => 'Test User';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockWardrobeProvider extends ChangeNotifier implements WardrobeProvider {
  @override
  List<WardrobeItem> get items => [];

  @override
  void clear() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockCommunityProvider extends ChangeNotifier implements CommunityProvider {
  @override
  List<CommunityModel> get myCommunities => [];

  @override
  List<SharedClosetItemModel> get sharedClosetItems => [];

  @override
  void clear() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Sign Out dialog Cancel button dismisses dialog without signing out', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final profileProvider = ProfileProvider();
    profileProvider.profile = UserProfileModel(
      id: 'user-signout-test',
      email: 'test@adaa.style',
      displayName: 'Test User',
      bio: 'Minimalist designer',
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

    // Scroll to the Sign Out row if needed and tap it
    final signOutFinder = find.text('Sign Out');
    expect(signOutFinder, findsOneWidget);
    await tester.ensureVisible(signOutFinder);
    await tester.tap(signOutFinder);
    await tester.pumpAndSettle();

    // Verify confirmation dialog appears
    expect(find.text('Are you sure you want to sign out of your adaa account?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Verify dialog is dismissed and user remains on ProfileScreen
    expect(find.text('Are you sure you want to sign out of your adaa account?'), findsNothing);
    expect(find.text('Test User'), findsOneWidget);
  });
}
