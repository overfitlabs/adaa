import 'wardrobe_item.dart';

class RecommendedOutfit {
  final String id;
  final String name;
  final String occasion;
  final String vibe;
  final double compatibilityScore;
  final String explanation;
  final List<String> stylingTips;
  final List<String> itemIds;
  final List<WardrobeItem> items;
  bool isSaved;
  String? savedOutfitId;

  RecommendedOutfit({
    required this.id,
    required this.name,
    required this.occasion,
    required this.vibe,
    required this.compatibilityScore,
    required this.explanation,
    required this.stylingTips,
    required this.itemIds,
    required this.items,
    this.isSaved = false,
    this.savedOutfitId,
  });

  factory RecommendedOutfit.fromJson(Map<String, dynamic> json) {
    return RecommendedOutfit(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Curated Outfit',
      occasion: json['occasion']?.toString() ?? 'Everyday',
      vibe: json['vibe']?.toString() ?? 'Minimalist',
      compatibilityScore: (json['compatibility_score'] as num?)?.toDouble() ?? 0.85,
      explanation: json['explanation']?.toString() ?? '',
      stylingTips: (json['styling_tips'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      itemIds: (json['item_ids'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((i) => WardrobeItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      isSaved: json['is_saved'] == true,
      savedOutfitId: json['saved_outfit_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'occasion': occasion,
      'vibe': vibe,
      'compatibility_score': compatibilityScore,
      'explanation': explanation,
      'styling_tips': stylingTips,
      'item_ids': itemIds,
      'items': items.map((i) => i.toJson()).toList(),
      'is_saved': isSaved,
      'saved_outfit_id': savedOutfitId,
    };
  }

  int get matchPercentage => (compatibilityScore * 100).round();
}

class OutfitGenerationResponse {
  final String status;
  final String message;
  final String occasion;
  final String? vibe;
  final List<String> appliedProfilePreferences;
  final List<String> missingCategories;
  final List<RecommendedOutfit> outfits;

  OutfitGenerationResponse({
    required this.status,
    required this.message,
    required this.occasion,
    this.vibe,
    required this.appliedProfilePreferences,
    required this.missingCategories,
    required this.outfits,
  });

  factory OutfitGenerationResponse.fromJson(Map<String, dynamic> json) {
    return OutfitGenerationResponse(
      status: json['status']?.toString() ?? 'success',
      message: json['message']?.toString() ?? '',
      occasion: json['occasion']?.toString() ?? 'Everyday',
      vibe: json['vibe']?.toString(),
      appliedProfilePreferences: (json['applied_profile_preferences'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      missingCategories: (json['missing_categories'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      outfits: (json['outfits'] as List<dynamic>? ?? [])
          .map((o) => RecommendedOutfit.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isSuccess => status == 'success';
  bool get isEmptyWardrobe => status == 'empty_wardrobe';
  bool get isInsufficientItems => status == 'insufficient_items';
}
