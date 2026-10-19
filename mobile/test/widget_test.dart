import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobelens/core/models/garment_item.dart';
import 'package:wardrobelens/core/models/wardrobe_item.dart';
import 'package:wardrobelens/core/models/outfit_match.dart';
import 'package:wardrobelens/main.dart';

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
}
