import 'garment_item.dart';
import 'wardrobe_item.dart';

class MatchCandidate {
  final WardrobeItem wardrobeItem;
  final double overallScore;
  final bool categoryMatch;
  final double colorScore;
  final double attributeScore;
  final bool isExactMatch;
  final List<String> matchReasons;

  MatchCandidate({
    required this.wardrobeItem,
    required this.overallScore,
    required this.categoryMatch,
    required this.colorScore,
    required this.attributeScore,
    required this.isExactMatch,
    required this.matchReasons,
  });

  factory MatchCandidate.fromJson(Map<String, dynamic> json) {
    return MatchCandidate(
      wardrobeItem: WardrobeItem.fromJson(json['wardrobe_item']),
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0.0,
      categoryMatch: json['category_match'] ?? false,
      colorScore: (json['color_score'] as num?)?.toDouble() ?? 0.0,
      attributeScore: (json['attribute_score'] as num?)?.toDouble() ?? 0.0,
      isExactMatch: json['is_exact_match'] ?? false,
      matchReasons: (json['match_reasons'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class ItemMatchResult {
  final DetectedFashionItem targetItem;
  final String status; // exact_match | approximate_match | missing
  final MatchCandidate? bestMatch;
  final List<MatchCandidate> alternatives;

  ItemMatchResult({
    required this.targetItem,
    required this.status,
    this.bestMatch,
    this.alternatives = const [],
  });

  factory ItemMatchResult.fromJson(Map<String, dynamic> json) {
    return ItemMatchResult(
      targetItem: DetectedFashionItem.fromJson(json['target_item']),
      status: json['status'] ?? 'missing',
      bestMatch: json['best_match'] != null
          ? MatchCandidate.fromJson(json['best_match'])
          : null,
      alternatives: (json['alternatives'] as List<dynamic>? ?? [])
          .map((a) => MatchCandidate.fromJson(a))
          .toList(),
    );
  }
}

class OutfitMatchResponse {
  final String? analysisId;
  final int totalOutfitItems;
  final int matchedCount;
  final int missingCount;
  final double completenessPercentage;
  final List<ItemMatchResult> itemMatches;
  final List<DetectedFashionItem> missingItems;

  OutfitMatchResponse({
    this.analysisId,
    required this.totalOutfitItems,
    required this.matchedCount,
    required this.missingCount,
    required this.completenessPercentage,
    required this.itemMatches,
    required this.missingItems,
  });

  factory OutfitMatchResponse.fromJson(Map<String, dynamic> json) {
    return OutfitMatchResponse(
      analysisId: json['analysis_id'],
      totalOutfitItems: json['total_outfit_items'] ?? 0,
      matchedCount: json['matched_count'] ?? 0,
      missingCount: json['missing_count'] ?? 0,
      completenessPercentage:
          (json['completeness_percentage'] as num?)?.toDouble() ?? 0.0,
      itemMatches: (json['item_matches'] as List<dynamic>? ?? [])
          .map((m) => ItemMatchResult.fromJson(m))
          .toList(),
      missingItems: (json['missing_items'] as List<dynamic>? ?? [])
          .map((i) => DetectedFashionItem.fromJson(i))
          .toList(),
    );
  }
}
