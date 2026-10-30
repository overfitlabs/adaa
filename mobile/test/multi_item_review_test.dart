import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wardrobelens/core/models/garment_item.dart';
import 'package:wardrobelens/core/models/outfit_analysis.dart';
import 'package:wardrobelens/core/models/wardrobe_item.dart';
import 'package:wardrobelens/core/widgets/private_image_view.dart';
import 'package:wardrobelens/features/analysis/screens/item_review_screen.dart';
import 'package:wardrobelens/state/analysis_provider.dart';
import 'package:wardrobelens/state/wardrobe_provider.dart';

class FakeWardrobeForReview extends ChangeNotifier implements WardrobeProvider {
  @override
  List<WardrobeItem> items = [];
  @override
  List<Map<String, dynamic>> categories = [];
  @override
  String selectedCategory = 'all';
  @override
  String searchQuery = '';
  @override
  bool isLoading = false;
  @override
  String? error;

  bool bulkAddCalled = false;
  List<DetectedFashionItem> lastSavedDetectedItems = [];

  @override
  Future<Map<String, dynamic>> bulkAddItems(
    List<DetectedFashionItem> detectedItems, {
    String? sourceAnalysisId,
  }) async {
    bulkAddCalled = true;
    lastSavedDetectedItems = List.from(detectedItems);
    return {
      'saved_count': detectedItems.length,
      'failed_count': 0,
      'saved_items': <WardrobeItem>[],
      'errors': [],
    };
  }

  @override
  Future<void> loadWardrobe({bool silent = false}) async {}

  @override
  void setCategory(String category) {}

  @override
  void setSearchQuery(String query) {}

  @override
  void clearError() {}

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
    dynamic file,
  }) async => true;

  @override
  Future<bool> updateItem(String id, Map<String, dynamic> updates) async => true;

  @override
  Future<bool> updateItemPhoto(String id, dynamic file) async => true;

  @override
  Future<WardrobeItem?> refreshItem(String id) async => null;

  @override
  Future<bool> deleteItem(String id) async => true;

  @override
  void clear() {
    items = [];
    categories = [];
    selectedCategory = 'all';
    searchQuery = '';
    isLoading = false;
    error = null;
    notifyListeners();
  }
}

void main() {
  final sampleAnalysis = OutfitAnalysisResponse(
    analysisId: 'ana-multi-100',
    imageUrl: 'https://example.com/outfit.jpg',
    summary: 'Editorial Streetwear with tailored elements',
    vibeOrStyle: 'Editorial Streetwear',
    detectedGarmentCount: 3,
    createdAt: DateTime(2026, 10, 20),
    items: [
      DetectedFashionItem(
        id: 'garment-1',
        category: 'jackets',
        subCategory: 'Blazer',
        name: 'Oversized Wool Blazer',
        primaryColor: 'Charcoal',
        attributes: StyleAttributes(material: 'Wool', fit: 'Oversized'),
        confidence: 0.96,
        box2d: [120, 200, 580, 800],
        extractedImagePath: 'extracted/crop_1.jpg',
        extractedImageUrl: 'https://example.com/crop_1.jpg',
      ),
      DetectedFashionItem(
        id: 'garment-2',
        category: 'trousers',
        subCategory: 'Pleated Pants',
        name: 'Wide Pleated Trousers',
        primaryColor: 'Sage Green',
        attributes: StyleAttributes(material: 'Cotton blend', fit: 'Wide leg'),
        confidence: 0.91,
        box2d: [550, 250, 920, 750],
        extractedImagePath: 'extracted/crop_2.jpg',
        extractedImageUrl: 'https://example.com/crop_2.jpg',
      ),
      DetectedFashionItem(
        id: 'garment-3',
        category: 'footwear',
        subCategory: 'Loafers',
        name: 'Chunky Leather Loafers',
        primaryColor: 'Black',
        attributes: StyleAttributes(material: 'Leather'),
        confidence: 0.88,
        box2d: [880, 300, 1000, 700],
        extractedImagePath: 'extracted/crop_3.jpg',
        extractedImageUrl: 'https://example.com/crop_3.jpg',
      ),
    ],
  );

  Widget createReviewApp({
    required FakeWardrobeForReview wardrobeProv,
    ItemReviewIntent? initialIntent,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WardrobeProvider>.value(value: wardrobeProv),
        ChangeNotifierProvider<AnalysisProvider>(create: (_) => AnalysisProvider()),
      ],
      child: MaterialApp(
        home: ItemReviewScreen(
          analysis: sampleAnalysis,
          initialIntent: initialIntent,
        ),
      ),
    );
  }

  group('ItemReviewScreen Multi-Item Extraction and Dual Intent Tests', () {
    testWidgets('Displays all detected candidate items with isolated crops and confidence', (tester) async {
      final fakeWardrobe = FakeWardrobeForReview();
      await tester.pumpWidget(createReviewApp(wardrobeProv: fakeWardrobe, initialIntent: ItemReviewIntent.addToCloset));
      await tester.pump();

      expect(find.text('review detected pieces'), findsOneWidget);
      expect(find.text('Oversized Wool Blazer'), findsOneWidget);
      expect(find.text('Wide Pleated Trousers'), findsOneWidget);
      expect(find.text('Chunky Leather Loafers'), findsOneWidget);
      expect(find.text('96% confidence'), findsOneWidget);
      expect(find.text('91% confidence'), findsOneWidget);
      expect(find.text('88% confidence'), findsOneWidget);
    });

    testWidgets('User can select only some detected items and save them separately to closet', (tester) async {
      final fakeWardrobe = FakeWardrobeForReview();
      await tester.pumpWidget(createReviewApp(wardrobeProv: fakeWardrobe, initialIntent: ItemReviewIntent.addToCloset));
      await tester.pump();

      // Initially all 3 are selected
      expect(find.text('Save 3 of 3 to My Closet'), findsOneWidget);

      // Deselect the third item (Loafers)
      await tester.tap(find.text('Chunky Leather Loafers'));
      await tester.pump();

      expect(find.text('Save 2 of 3 to My Closet'), findsOneWidget);

      // Tap save
      await tester.tap(find.text('Save 2 of 3 to My Closet'));
      await tester.pump();

      // Verify bulkAddItems was called with ONLY the 2 selected pieces
      expect(fakeWardrobe.bulkAddCalled, isTrue);
      expect(fakeWardrobe.lastSavedDetectedItems.length, 2);
      expect(fakeWardrobe.lastSavedDetectedItems.map((i) => i.id), containsAll(['garment-1', 'garment-2']));
      expect(fakeWardrobe.lastSavedDetectedItems.map((i) => i.id), isNot(contains('garment-3')));
    });

    testWidgets('Find a piece intent enforces single item selection and does NOT save to closet', (tester) async {
      final fakeWardrobe = FakeWardrobeForReview();
      await tester.pumpWidget(createReviewApp(wardrobeProv: fakeWardrobe, initialIntent: ItemReviewIntent.findPiece));
      await tester.pump();

      // Shows Find Matches button instead of Save to closet
      expect(find.text('Find Matches for Selected Piece'), findsOneWidget);
      expect(find.textContaining('Save'), findsNothing);

      // Tap on second item
      await tester.tap(find.text('Wide Pleated Trousers'));
      await tester.pump();

      // Tap Find Matches
      await tester.tap(find.text('Find Matches for Selected Piece'));
      await tester.pump();

      // Verify closet was NOT modified
      expect(fakeWardrobe.bulkAddCalled, isFalse);
      expect(fakeWardrobe.lastSavedDetectedItems, isEmpty);
    });

    testWidgets('Fallback: user can toggle Keep original to fall back from extracted crop', (tester) async {
      final fakeWardrobe = FakeWardrobeForReview();
      await tester.pumpWidget(createReviewApp(wardrobeProv: fakeWardrobe, initialIntent: ItemReviewIntent.addToCloset));
      await tester.pump();

      expect(find.text('Keep original'), findsWidgets);

      // Tap 'Keep original' on the first item
      await tester.tap(find.text('Keep original').first);
      await tester.pump();

      expect(find.text('Show crop'), findsOneWidget);
    });

    testWidgets('Garment items render in standardized 1:1 square containers with BoxFit.contain', (tester) async {
      final fakeWardrobe = FakeWardrobeForReview();
      await tester.pumpWidget(createReviewApp(wardrobeProv: fakeWardrobe, initialIntent: ItemReviewIntent.addToCloset));
      await tester.pump();

      final imageViews = tester.widgetList<PrivateImageView>(find.byType(PrivateImageView));
      expect(imageViews, isNotEmpty);
      for (final view in imageViews) {
        expect(view.fit, equals(BoxFit.contain));
      }
    });

    testWidgets('Wardrobe detection flow renders customItems without requiring an analysis record', (tester) async {
      final fakeWardrobe = FakeWardrobeForReview();
      final customItem1 = DetectedFashionItem(
        id: 'c-1',
        category: 'tops',
        name: 'Cotton Oxford Shirt',
        primaryColor: 'White',
        confidence: 0.95,
        attributes: StyleAttributes(material: 'cotton', pattern: 'solid'),
        extractedImageUrl: 'https://example.com/c1.jpg',
      );
      final customItem2 = DetectedFashionItem(
        id: 'c-2',
        category: 'bottoms',
        name: 'Denim Jeans',
        primaryColor: 'Blue',
        confidence: 0.92,
        attributes: StyleAttributes(material: 'denim', pattern: 'solid'),
        extractedImageUrl: 'https://example.com/c2.jpg',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<WardrobeProvider>.value(value: fakeWardrobe),
              ChangeNotifierProvider<AnalysisProvider>(create: (_) => AnalysisProvider()),
            ],
            child: ItemReviewScreen(
              customItems: [customItem1, customItem2],
              sourceImageUrl: 'https://example.com/full.jpg',
              initialIntent: ItemReviewIntent.addToCloset,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Cotton Oxford Shirt'), findsOneWidget);
      expect(find.text('Denim Jeans'), findsOneWidget);
      expect(find.text('Save 2 of 2 to My Closet'), findsOneWidget);

      await tester.tap(find.text('Save 2 of 2 to My Closet'));
      await tester.pump();

      expect(fakeWardrobe.bulkAddCalled, isTrue);
      expect(fakeWardrobe.lastSavedDetectedItems.length, equals(2));
    });
  });
}
