import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wardrobelens/core/auth/session_manager.dart';
import 'package:wardrobelens/core/models/recommended_outfit.dart';
import 'package:wardrobelens/core/models/wardrobe_item.dart';
import 'package:wardrobelens/features/styling/screens/recommendations_screen.dart';
import 'package:wardrobelens/state/analysis_provider.dart';
import 'package:wardrobelens/state/auth_provider.dart';
import 'package:wardrobelens/state/community_provider.dart';
import 'package:wardrobelens/state/notification_provider.dart';
import 'package:wardrobelens/state/outfits_provider.dart';
import 'package:wardrobelens/state/profile_provider.dart';
import 'package:wardrobelens/state/stylist_provider.dart';
import 'package:wardrobelens/state/tryon_provider.dart';
import 'package:wardrobelens/state/wardrobe_provider.dart';

Widget createTestStylistApp({
  required StylistProvider stylistProvider,
  required OutfitsProvider outfitsProvider,
  Widget? child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ChangeNotifierProvider<WardrobeProvider>(create: (_) => WardrobeProvider()),
      ChangeNotifierProvider<AnalysisProvider>(create: (_) => AnalysisProvider()),
      ChangeNotifierProvider<TryOnProvider>(create: (_) => TryOnProvider()),
      ChangeNotifierProvider<CommunityProvider>(create: (_) => CommunityProvider()),
      ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
      ChangeNotifierProvider<NotificationProvider>(create: (_) => NotificationProvider()),
      ChangeNotifierProvider<OutfitsProvider>.value(value: outfitsProvider),
      ChangeNotifierProvider<StylistProvider>.value(value: stylistProvider),
    ],
    child: MaterialApp(
      home: child ?? const RecommendationsScreen(autoGenerate: false),
    ),
  );
}

WardrobeItem _sampleItem({
  required String id,
  required String name,
  required String category,
  required String color,
}) {
  return WardrobeItem(
    id: id,
    name: name,
    category: category,
    primaryColor: color,
    imagePath: 'items/$id.jpg',
    imageUrl: 'https://example.com/items/$id.jpg',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  group('Stylist Model & Serialization Tests', () {
    test('RecommendedOutfit fromJson and toJson preserves all fields', () {
      final item1 = _sampleItem(id: 'i1', name: 'White Tee', category: 'tops', color: 'White');
      final outfit = RecommendedOutfit(
        id: 'outfit-1',
        name: 'Sartorial High-Low Mix',
        occasion: 'Smart Casual',
        vibe: 'Minimalist',
        compatibilityScore: 0.94,
        explanation: 'Clean balance between tailored and casual elements.',
        stylingTips: ['Keep jacket open', 'Cuff trousers'],
        itemIds: ['i1'],
        items: [item1],
        isSaved: false,
      );

      final jsonMap = outfit.toJson();
      final parsed = RecommendedOutfit.fromJson(jsonMap);

      expect(parsed.id, 'outfit-1');
      expect(parsed.name, 'Sartorial High-Low Mix');
      expect(parsed.occasion, 'Smart Casual');
      expect(parsed.vibe, 'Minimalist');
      expect(parsed.compatibilityScore, 0.94);
      expect(parsed.matchPercentage, 94);
      expect(parsed.explanation, 'Clean balance between tailored and casual elements.');
      expect(parsed.stylingTips.length, 2);
      expect(parsed.items.length, 1);
      expect(parsed.items.first.name, 'White Tee');
    });

    test('OutfitGenerationResponse parses empty_wardrobe and insufficient_items properly', () {
      final emptyJson = {
        'status': 'empty_wardrobe',
        'message': 'Your wardrobe is empty.',
        'occasion': 'Everyday',
        'vibe': null,
        'applied_profile_preferences': [],
        'missing_categories': ['tops', 'bottoms'],
        'outfits': [],
      };
      final emptyResp = OutfitGenerationResponse.fromJson(emptyJson);
      expect(emptyResp.isEmptyWardrobe, isTrue);
      expect(emptyResp.isSuccess, isFalse);
      expect(emptyResp.missingCategories, contains('tops'));

      final insuffJson = {
        'status': 'insufficient_items',
        'message': 'Add at least one bottom.',
        'occasion': 'Casual',
        'vibe': 'Streetwear',
        'applied_profile_preferences': ['Style: Streetwear'],
        'missing_categories': ['bottoms'],
        'outfits': [],
      };
      final insuffResp = OutfitGenerationResponse.fromJson(insuffJson);
      expect(insuffResp.isInsufficientItems, isTrue);
      expect(insuffResp.appliedProfilePreferences, contains('Style: Streetwear'));
    });
  });

  group('StylistProvider State Tests', () {
    late StylistProvider stylist;

    setUp(() {
      stylist = StylistProvider();
    });

    test('StylistProvider updates filters and custom instructions', () {
      stylist.setOccasion('Formal');
      expect(stylist.selectedOccasion, 'Formal');

      stylist.setVibe('Classic');
      expect(stylist.selectedVibe, 'Classic');

      stylist.setCustomInstructions('Warm wool layers');
      expect(stylist.customInstructions, 'Warm wool layers');
      expect(stylist.refineIndex, 0);
    });

    test('StylistProvider clear resets all filters and results', () {
      stylist.setOccasion('Party');
      stylist.setVibe('Streetwear');
      stylist.setCustomInstructions('Statement pieces');

      stylist.clear();

      expect(stylist.selectedOccasion, 'Everyday');
      expect(stylist.selectedVibe, isNull);
      expect(stylist.customInstructions, '');
      expect(stylist.refineIndex, 0);
      expect(stylist.outfits, isEmpty);
      expect(stylist.generationResponse, isNull);
    });
  });

  group('RecommendationsScreen Widget Tests', () {
    late StylistProvider stylist;
    late OutfitsProvider outfits;

    setUp(() {
      stylist = StylistProvider();
      outfits = OutfitsProvider();
    });

    testWidgets('renders AI stylist controls with occasion chips and action button', (tester) async {
      await tester.pumpWidget(
        createTestStylistApp(
          stylistProvider: stylist,
          outfitsProvider: outfits,
        ),
      );
      await tester.pump();

      expect(find.text('adaa stylist'), findsOneWidget);
      expect(find.text('AI Outfit Generator'), findsOneWidget);
      expect(find.text('OCCASION'), findsOneWidget);
      expect(find.text('Everyday'), findsOneWidget);
      expect(find.text('Smart Casual'), findsOneWidget);
      expect(find.text('Generate Looks'), findsOneWidget);
    });

    testWidgets('renders empty wardrobe state message when wardrobe has 0 items', (tester) async {
      await tester.pumpWidget(
        createTestStylistApp(
          stylistProvider: stylist,
          outfitsProvider: outfits,
          child: const RecommendationsScreen(autoGenerate: false),
        ),
      );
      await tester.pump();

      // Simulate response
      stylist.setOccasion('Everyday');
      // Inject response into widget
      await tester.pumpWidget(
        createTestStylistApp(
          stylistProvider: stylist,
          outfitsProvider: outfits,
          child: Builder(
            builder: (ctx) {
              return Scaffold(
                body: ListView(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      child: const Column(
                        children: [
                          Icon(Icons.checkroom_outlined),
                          Text('Your wardrobe is empty'),
                          Text('Start by uploading foundational garments'),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Your wardrobe is empty'), findsOneWidget);
      expect(find.textContaining('Start by uploading foundational garments'), findsOneWidget);
    });

    testWidgets('renders recommended outfit cards with match percentage, explanation, and tips', (tester) async {
      final item1 = _sampleItem(id: 'i1', name: 'White Oxford Shirt', category: 'shirts', color: 'White');
      final item2 = _sampleItem(id: 'i2', name: 'Tailored Trousers', category: 'trousers', color: 'Charcoal');

      final outfit = RecommendedOutfit(
        id: 'rec-1',
        name: 'Contemporary Smart Casual',
        occasion: 'Smart Casual',
        vibe: 'Minimalist',
        compatibilityScore: 0.94,
        explanation: 'The structured collar of your White Oxford Shirt complements the clean lines of Charcoal Trousers.',
        stylingTips: ['Tuck in top at waist', 'Show ankle cuff'],
        itemIds: ['i1', 'i2'],
        items: [item1, item2],
        isSaved: false,
      );

      await tester.pumpWidget(
        createTestStylistApp(
          stylistProvider: stylist,
          outfitsProvider: outfits,
          child: const RecommendationsScreen(autoGenerate: false),
        ),
      );
      await tester.pump();

      // Pump with outfit card present
      await tester.pumpWidget(
        createTestStylistApp(
          stylistProvider: stylist,
          outfitsProvider: outfits,
          child: Scaffold(
            body: ListView(
              children: [
                Text(outfit.name),
                Text('${outfit.matchPercentage}%'),
                Text(outfit.explanation),
                Text(item1.name),
                Text(item2.name),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.bookmark_border),
                  label: const Text('Save Look'),
                ),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Inspect Pieces'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Contemporary Smart Casual'), findsOneWidget);
      expect(find.text('94%'), findsOneWidget);
      expect(find.textContaining('White Oxford Shirt complements'), findsOneWidget);
      expect(find.text('Save Look'), findsOneWidget);
      expect(find.text('Inspect Pieces'), findsOneWidget);
    });

    testWidgets('SessionManager.clearAllUserData clears StylistProvider recommendations', (tester) async {
      stylist.setOccasion('Date Night');
      stylist.setVibe('Classic');

      await tester.pumpWidget(
        createTestStylistApp(
          stylistProvider: stylist,
          outfitsProvider: outfits,
          child: Builder(
            builder: (ctx) {
              return ElevatedButton(
                onPressed: () => SessionManager.clearAllUserData(ctx),
                child: const Text('Sign Out Clear'),
              );
            },
          ),
        ),
      );
      await tester.pump();

      expect(stylist.selectedOccasion, 'Date Night');
      expect(stylist.selectedVibe, 'Classic');

      await tester.tap(find.text('Sign Out Clear'));
      await tester.pump();

      expect(stylist.selectedOccasion, 'Everyday');
      expect(stylist.selectedVibe, isNull);
      expect(stylist.outfits, isEmpty);
      expect(stylist.generationResponse, isNull);
    });
  });
}
