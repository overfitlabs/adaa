import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wardrobelens/core/models/tryon_task.dart';
import 'package:wardrobelens/core/models/wardrobe_item.dart';
import 'package:wardrobelens/features/tryon/screens/tryon_screen.dart';
import 'package:wardrobelens/state/analysis_provider.dart';
import 'package:wardrobelens/state/auth_provider.dart';
import 'package:wardrobelens/state/community_provider.dart';
import 'package:wardrobelens/state/notification_provider.dart';
import 'package:wardrobelens/state/outfits_provider.dart';
import 'package:wardrobelens/state/profile_provider.dart';
import 'package:wardrobelens/state/stylist_provider.dart';
import 'package:wardrobelens/state/tryon_provider.dart';
import 'package:wardrobelens/state/wardrobe_provider.dart';

Widget createTestTryOnApp({
  required TryOnProvider tryOnProvider,
  required WardrobeProvider wardrobeProvider,
  required OutfitsProvider outfitsProvider,
  String? prefilledInspirationUrl,
  String? prefilledWardrobeItemId,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ChangeNotifierProvider<WardrobeProvider>.value(value: wardrobeProvider),
      ChangeNotifierProvider<AnalysisProvider>(create: (_) => AnalysisProvider()),
      ChangeNotifierProvider<TryOnProvider>.value(value: tryOnProvider),
      ChangeNotifierProvider<CommunityProvider>(create: (_) => CommunityProvider()),
      ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
      ChangeNotifierProvider<NotificationProvider>(create: (_) => NotificationProvider()),
      ChangeNotifierProvider<OutfitsProvider>.value(value: outfitsProvider),
      ChangeNotifierProvider<StylistProvider>(create: (_) => StylistProvider()),
    ],
    child: MaterialApp(
      home: TryOnScreen(
        prefilledInspirationUrl: prefilledInspirationUrl,
        prefilledWardrobeItemId: prefilledWardrobeItemId,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TryOnProvider tryOn;
  late WardrobeProvider wardrobe;
  late OutfitsProvider outfits;

  setUp(() {
    tryOn = TryOnProvider();
    wardrobe = WardrobeProvider();
    outfits = OutfitsProvider();
  });

  testWidgets('TryOnScreen renders functional UI sections and category chips', (tester) async {
    await tester.pumpWidget(
      createTestTryOnApp(
        tryOnProvider: tryOn,
        wardrobeProvider: wardrobe,
        outfitsProvider: outfits,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1. Your Silhouette'), findsOneWidget);
    expect(find.text('2. Garment to Try On'), findsOneWidget);
    expect(find.text('3. Garment Type'), findsOneWidget);
    expect(find.text('From My Wardrobe'), findsOneWidget);
    expect(find.text('Upload Photo'), findsOneWidget);
    expect(find.text('Tops / Upper'), findsOneWidget);
    expect(find.text('Pants / Lower'), findsOneWidget);
    expect(find.text('Jackets / Outer'), findsOneWidget);
    expect(find.text('GENERATE VIRTUAL TRY-ON'), findsOneWidget);
  });

  testWidgets('TryOnScreen toggles category chip selection', (tester) async {
    await tester.pumpWidget(
      createTestTryOnApp(
        tryOnProvider: tryOn,
        wardrobeProvider: wardrobe,
        outfitsProvider: outfits,
      ),
    );
    await tester.pumpAndSettle();

    final outerChip = find.text('Jackets / Outer');
    expect(outerChip, findsOneWidget);
    await tester.ensureVisible(outerChip);
    await tester.tap(outerChip);
    await tester.pumpAndSettle();
  });

  testWidgets('TryOnScreen renders prefilled inspiration scan banner when provided', (tester) async {
    await tester.pumpWidget(
      createTestTryOnApp(
        tryOnProvider: tryOn,
        wardrobeProvider: wardrobe,
        outfitsProvider: outfits,
        prefilledInspirationUrl: 'https://example.com/scan.jpg',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inspiration Scan Attached'), findsOneWidget);
    expect(find.text('Using inspiration context for fitting calibration.'), findsOneWidget);
  });

  testWidgets('TryOnScreen auto-selects wardrobe item when prefilledWardrobeItemId matches', (tester) async {
    final testItem = WardrobeItem(
      id: 'item-outer-123',
      name: 'Cashmere Overcoat',
      category: 'Outerwear',
      primaryColor: 'Camel',
      imagePath: 'wardrobe/coat.jpg',
      imageUrl: 'https://example.com/coat.jpg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    wardrobe.items = [testItem];

    await tester.pumpWidget(
      createTestTryOnApp(
        tryOnProvider: tryOn,
        wardrobeProvider: wardrobe,
        outfitsProvider: outfits,
        prefilledWardrobeItemId: 'item-outer-123',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cashmere Overcoat'), findsOneWidget);
    expect(find.text('Outerwear • Camel'), findsOneWidget);
  });

  group('VTO History UI & Navigation Tests', () {
    testWidgets('TryOnScreen renders top tab bar and toggles between Studio and History', (tester) async {
      tryOn.setHistoryForTesting([]);
      await tester.pumpWidget(
        createTestTryOnApp(
          tryOnProvider: tryOn,
          wardrobeProvider: wardrobe,
          outfitsProvider: outfits,
        ),
      );
      await tester.pumpAndSettle();

      // Top Tab Bar is visible
      expect(find.byKey(const Key('tryon_tab_studio')), findsOneWidget);
      expect(find.byKey(const Key('tryon_tab_history')), findsOneWidget);
      expect(find.text('Try On Studio'), findsOneWidget);
      expect(find.text('Fitting History'), findsOneWidget);

      // Default tab is Studio
      expect(find.text('1. Your Silhouette'), findsOneWidget);

      // Tap Fitting History tab
      await tester.tap(find.byKey(const Key('tryon_tab_history')));
      await tester.pumpAndSettle();

      // Studio form is hidden, retention banner and history section are displayed
      expect(find.text('1. Your Silhouette'), findsNothing);
      expect(find.textContaining('Fitting photos are retained for 7 days'), findsOneWidget);
      expect(find.text('No Fitting History Yet'), findsOneWidget);

      // Tap back to Studio
      await tester.tap(find.byKey(const Key('tryon_tab_studio')));
      await tester.pumpAndSettle();
      expect(find.text('1. Your Silhouette'), findsOneWidget);
    });

    testWidgets('Fitting History empty state renders Start Fitting CTA that returns to Studio', (tester) async {
      tryOn.setHistoryForTesting([]);
      await tester.pumpWidget(
        createTestTryOnApp(
          tryOnProvider: tryOn,
          wardrobeProvider: wardrobe,
          outfitsProvider: outfits,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tryon_tab_history')));
      await tester.pumpAndSettle();

      final cta = find.byKey(const Key('tryon_empty_start_fitting_btn'));
      expect(cta, findsOneWidget);

      await tester.tap(cta);
      await tester.pumpAndSettle();

      // Successfully switched back to Studio
      expect(find.text('1. Your Silhouette'), findsOneWidget);
    });

    testWidgets('Fitting History displays loading state', (tester) async {
      tryOn.setLoadingHistoryForTesting(true);

      await tester.pumpWidget(
        createTestTryOnApp(
          tryOnProvider: tryOn,
          wardrobeProvider: wardrobe,
          outfitsProvider: outfits,
        ),
      );
      // Pump without settling to check loading
      await tester.pump();

      // Switch to history
      await tester.tap(find.byKey(const Key('tryon_tab_history')));
      await tester.pump();

      expect(find.text('Retrieving your virtual fittings...'), findsOneWidget);
    });

    testWidgets('Fitting History displays error state with retry action', (tester) async {
      tryOn.setHistoryErrorForTesting('Network connection dropped');

      await tester.pumpWidget(
        createTestTryOnApp(
          tryOnProvider: tryOn,
          wardrobeProvider: wardrobe,
          outfitsProvider: outfits,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tryon_tab_history')));
      await tester.pumpAndSettle();

      expect(find.text('Network connection dropped'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('Fitting History renders cards with category, date, and load more button', (tester) async {
      final task1 = TryOnTask(
        taskId: 'hist-1',
        status: 'success',
        provider: 'mock',
        userImageUrl: 'https://example.com/u1.jpg',
        garmentImageUrl: 'https://example.com/g1.jpg',
        resultImageUrl: 'https://example.com/res1.jpg',
        garmentCategory: 'outer',
        canRetry: true,
        createdAt: DateTime(2026, 10, 28, 14, 30),
        updatedAt: DateTime(2026, 10, 28, 14, 31),
      );
      final task2 = TryOnTask(
        taskId: 'hist-2',
        status: 'success',
        provider: 'mock',
        userImageUrl: 'https://example.com/u2.jpg',
        garmentImageUrl: 'https://example.com/g2.jpg',
        resultImageUrl: 'https://example.com/res2.jpg',
        garmentCategory: 'upper body',
        canRetry: false,
        createdAt: DateTime(2026, 10, 27, 9, 15),
        updatedAt: DateTime(2026, 10, 27, 9, 16),
      );

      tryOn.setHistoryForTesting([task1, task2], hasMore: true, nextCursor: 'token_abc');

      await tester.pumpWidget(
        createTestTryOnApp(
          tryOnProvider: tryOn,
          wardrobeProvider: wardrobe,
          outfitsProvider: outfits,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tryon_tab_history')));
      await tester.pumpAndSettle();

      // History grid renders cards
      expect(find.byKey(const Key('tryon_history_grid')), findsOneWidget);
      expect(find.text('OUTER'), findsOneWidget);
      expect(find.text('UPPER BODY'), findsOneWidget);

      // Pagination button is visible because hasMore is true
      expect(find.byKey(const Key('tryon_load_more_btn')), findsOneWidget);
      expect(find.text('Load More Previous Fittings'), findsOneWidget);
    });

    testWidgets('Tapping history card opens detail bottom sheet and Try Again pre-fills Studio', (tester) async {
      final task = TryOnTask(
        taskId: 'hist-detail-1',
        status: 'success',
        provider: 'mock',
        userImageUrl: 'https://example.com/u.jpg',
        garmentImageUrl: 'https://example.com/g.jpg',
        resultImageUrl: 'https://example.com/res.jpg',
        garmentCategory: 'outer',
        canRetry: true,
        createdAt: DateTime(2026, 10, 28, 14, 30),
        updatedAt: DateTime(2026, 10, 28, 14, 31),
      );

      tryOn.setHistoryForTesting([task]);

      await tester.pumpWidget(
        createTestTryOnApp(
          tryOnProvider: tryOn,
          wardrobeProvider: wardrobe,
          outfitsProvider: outfits,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tryon_tab_history')));
      await tester.pumpAndSettle();

      // Tap the card to open bottom sheet
      await tester.tap(find.text('OUTER'));
      await tester.pumpAndSettle();

      // Bottom sheet is rendered
      expect(find.text('Virtual Fitting'), findsOneWidget);
      expect(find.byKey(const Key('tryon_detail_try_again_btn')), findsOneWidget);
      expect(find.byKey(const Key('tryon_detail_save_btn')), findsOneWidget);
      expect(find.byKey(const Key('tryon_detail_delete_btn')), findsOneWidget);

      // Tap Try Again
      await tester.tap(find.byKey(const Key('tryon_detail_try_again_btn')));
      await tester.pumpAndSettle();

      // Returns to Studio tab
      expect(find.text('1. Your Silhouette'), findsOneWidget);
      expect(find.text('Switched to Try On Studio. Ready to fit again.'), findsOneWidget);
    });

    testWidgets('Opening History does not trigger task creation or provider startTryOn', (tester) async {
      expect(tryOn.isSubmitting, isFalse);
      expect(tryOn.activeTask, isNull);

      await tester.pumpWidget(
        createTestTryOnApp(
          tryOnProvider: tryOn,
          wardrobeProvider: wardrobe,
          outfitsProvider: outfits,
        ),
      );
      await tester.pumpAndSettle();

      // Switch to history
      await tester.tap(find.byKey(const Key('tryon_tab_history')));
      await tester.pumpAndSettle();

      // Verify no active task or submission was triggered
      expect(tryOn.isSubmitting, isFalse);
      expect(tryOn.activeTask, isNull);
    });
  });

  group('My Try-On Model & Friend Mode Tests', () {
    late TryOnProvider tryOn;
    late WardrobeProvider wardrobe;
    late OutfitsProvider outfits;

    setUp(() {
      tryOn = TryOnProvider();
      wardrobe = WardrobeProvider();
      outfits = OutfitsProvider();
    });

    testWidgets('TryOnScreen renders saved default model card when model exists', (tester) async {
      tryOn.setDefaultModelForTesting(
        UserTryOnModel(
          hasModel: true,
          modelId: 'mod-101',
          imageUrl: 'https://example.com/my-saved-body.jpg',
        ),
      );

      await tester.pumpWidget(
        createTestTryOnApp(
          tryOnProvider: tryOn,
          wardrobeProvider: wardrobe,
          outfitsProvider: outfits,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1. Your Silhouette'), findsOneWidget);
      expect(find.text('My Default Model'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
      expect(find.text('Try for a Friend'), findsOneWidget);
      expect(find.text('Using your saved default try-on model for 1-click fittings.'), findsOneWidget);
    });

    testWidgets('Tapping Try for a Friend switches to Friend mode and requires consent', (tester) async {
      tryOn.setDefaultModelForTesting(
        UserTryOnModel(
          hasModel: true,
          modelId: 'mod-102',
          imageUrl: 'https://example.com/my-saved-body.jpg',
        ),
      );

      await tester.pumpWidget(
        createTestTryOnApp(
          tryOnProvider: tryOn,
          wardrobeProvider: wardrobe,
          outfitsProvider: outfits,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Try for a Friend
      await tester.tap(find.text('Try for a Friend'));
      await tester.pumpAndSettle();

      // Verified switched to Friend's Silhouette
      expect(find.text('1. Friend\'s Silhouette'), findsOneWidget);
      expect(find.text('My Silhouette'), findsOneWidget);
      expect(find.text('I have permission to use this photo for styling advice.'), findsOneWidget);

      // Verify consent starts false
      expect(tryOn.friendConsentAcknowledged, isFalse);

      // Tap consent checkbox
      await tester.tap(find.text('I have permission to use this photo for styling advice.'));
      await tester.pumpAndSettle();

      // Verify consent updated to true
      expect(tryOn.friendConsentAcknowledged, isTrue);

      // Tap My Silhouette to switch back
      await tester.tap(find.text('My Silhouette'));
      await tester.pumpAndSettle();

      expect(find.text('1. Your Silhouette'), findsOneWidget);
      expect(find.text('My Default Model'), findsOneWidget);
    });
  });
}
