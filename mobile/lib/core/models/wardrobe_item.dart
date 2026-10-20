class WardrobeItem {
  final String id;
  String name;
  String category;
  String? subCategory;
  String primaryColor;
  String? secondaryColor;
  String? pattern;
  String? material;
  String? fit;
  String? season;
  String? formality;
  String? brand;
  String? size;
  String? condition;
  String? notes;
  List<String> tags;
  final String imagePath;
  final String imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  WardrobeItem({
    required this.id,
    required this.name,
    required this.category,
    this.subCategory,
    required this.primaryColor,
    this.secondaryColor,
    this.pattern,
    this.material,
    this.fit,
    this.season,
    this.formality,
    this.brand,
    this.size,
    this.condition,
    this.notes,
    this.tags = const [],
    required this.imagePath,
    required this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WardrobeItem.fromJson(Map<String, dynamic> json) {
    return WardrobeItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'other',
      subCategory: json['sub_category'],
      primaryColor: json['primary_color'] ?? '',
      secondaryColor: json['secondary_color'],
      pattern: json['pattern'],
      material: json['material'],
      fit: json['fit'],
      season: json['season'],
      formality: json['formality'],
      brand: json['brand'],
      size: json['size'],
      condition: json['condition'],
      notes: json['notes'],
      tags: (json['tags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      imagePath: json['image_path'] ?? '',
      imageUrl: json['image_url'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'sub_category': subCategory,
      'primary_color': primaryColor,
      'secondary_color': secondaryColor,
      'pattern': pattern,
      'material': material,
      'fit': fit,
      'season': season,
      'formality': formality,
      'brand': brand,
      'size': size,
      'condition': condition,
      'notes': notes,
      'tags': tags,
      'image_path': imagePath,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
