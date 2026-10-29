import 'garment_item.dart';

class OutfitAnalysisResponse {
  final String analysisId;
  final String imageUrl;
  final String summary;
  final String vibeOrStyle;
  final List<DetectedFashionItem> items;
  final int detectedGarmentCount;
  final DateTime createdAt;
  final String status;
  final String? error;

  OutfitAnalysisResponse({
    required this.analysisId,
    required this.imageUrl,
    required this.summary,
    required this.vibeOrStyle,
    required this.items,
    required this.detectedGarmentCount,
    required this.createdAt,
    this.status = 'completed',
    this.error,
  });

  factory OutfitAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return OutfitAnalysisResponse(
      analysisId: json['analysis_id'] ?? '',
      imageUrl: json['image_url'] ?? '',
      summary: json['summary'] ?? '',
      vibeOrStyle: json['vibe_or_style'] ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((i) => DetectedFashionItem.fromJson(i))
          .toList(),
      detectedGarmentCount: json['detected_garment_count'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      status: json['status'] ?? 'completed',
      error: json['error'],
    );
  }
}
