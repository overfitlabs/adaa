class StyleAttributes {
  final String? pattern;
  final String? material;
  final String? fit;
  final String? formality;
  final String? season;
  final String? necklineOrCollar;

  StyleAttributes({
    this.pattern,
    this.material,
    this.fit,
    this.formality,
    this.season,
    this.necklineOrCollar,
  });

  factory StyleAttributes.fromJson(Map<String, dynamic> json) {
    return StyleAttributes(
      pattern: json['pattern'],
      material: json['material'],
      fit: json['fit'],
      formality: json['formality'],
      season: json['season'],
      necklineOrCollar: json['neckline_or_collar'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pattern': pattern,
      'material': material,
      'fit': fit,
      'formality': formality,
      'season': season,
      'neckline_or_collar': necklineOrCollar,
    };
  }
}

class DetectedFashionItem {
  final String id;
  String category;
  String? subCategory;
  String name;
  String primaryColor;
  String? secondaryColor;
  StyleAttributes attributes;
  double confidence;
  String? boundingBoxDescription;
  List<int>? box2d;
  String? extractedImagePath;
  String? extractedImageUrl;

  DetectedFashionItem({
    required this.id,
    required this.category,
    this.subCategory,
    required this.name,
    required this.primaryColor,
    this.secondaryColor,
    required this.attributes,
    this.confidence = 0.9,
    this.boundingBoxDescription,
    this.box2d,
    this.extractedImagePath,
    this.extractedImageUrl,
  });

  factory DetectedFashionItem.fromJson(Map<String, dynamic> json) {
    return DetectedFashionItem(
      id: json['id'] ?? '',
      category: json['category'] ?? 'other',
      subCategory: json['sub_category'],
      name: json['name'] ?? 'Fashion Item',
      primaryColor: json['primary_color'] ?? 'Neutral',
      secondaryColor: json['secondary_color'],
      attributes: json['attributes'] != null
          ? StyleAttributes.fromJson(json['attributes'])
          : StyleAttributes(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.9,
      boundingBoxDescription: json['bounding_box_description'],
      box2d: (json['box_2d'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList(),
      extractedImagePath: json['extracted_image_path'],
      extractedImageUrl: json['extracted_image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'sub_category': subCategory,
      'name': name,
      'primary_color': primaryColor,
      'secondary_color': secondaryColor,
      'attributes': attributes.toJson(),
      'confidence': confidence,
      'bounding_box_description': boundingBoxDescription,
      'box_2d': box2d,
      'extracted_image_path': extractedImagePath,
      'extracted_image_url': extractedImageUrl,
    };
  }
}
