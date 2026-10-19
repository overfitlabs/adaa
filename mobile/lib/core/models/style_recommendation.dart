class StyleRecommendation {
  final String title;
  final String description;
  final String occasion;
  final List<String> suggestedItemIds;
  final List<String> stylingTips;

  StyleRecommendation({
    required this.title,
    required this.description,
    required this.occasion,
    required this.suggestedItemIds,
    required this.stylingTips,
  });

  factory StyleRecommendation.fromJson(Map<String, dynamic> json) {
    return StyleRecommendation(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      occasion: json['occasion'] ?? 'Everyday',
      suggestedItemIds: (json['suggested_item_ids'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      stylingTips: (json['styling_tips'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
