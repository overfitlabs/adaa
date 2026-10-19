import 'wardrobe_item.dart';

class SavedOutfit {
  final String id;
  String name;
  String? occasion;
  String? notes;
  String? imagePath;
  List<String> itemIds;
  List<WardrobeItem> items;
  String? inspirationAnalysisId;
  final DateTime createdAt;
  final DateTime updatedAt;

  SavedOutfit({
    required this.id,
    required this.name,
    this.occasion,
    this.notes,
    this.imagePath,
    required this.itemIds,
    this.items = const [],
    this.inspirationAnalysisId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SavedOutfit.fromJson(Map<String, dynamic> json) {
    return SavedOutfit(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      occasion: json['occasion'],
      notes: json['notes'],
      imagePath: json['image_path'],
      itemIds: (json['item_ids'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      items: (json['items'] as List<dynamic>? ?? []).map((i) => WardrobeItem.fromJson(i)).toList(),
      inspirationAnalysisId: json['inspiration_analysis_id'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
    );
  }
}
