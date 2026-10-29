class TryOnTask {
  final String taskId;
  final String status; // pending, processing, success, failed
  final String provider;
  final String userImageUrl;
  final String garmentImageUrl;
  final String? resultImageUrl;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;
  final bool canRetry;
  final String? garmentCategory;
  final bool isFriendTryon;
  final bool usedSavedModel;

  TryOnTask({
    required this.taskId,
    required this.status,
    required this.provider,
    required this.userImageUrl,
    required this.garmentImageUrl,
    this.resultImageUrl,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
    this.canRetry = false,
    this.garmentCategory,
    this.isFriendTryon = false,
    this.usedSavedModel = false,
  });

  factory TryOnTask.fromJson(Map<String, dynamic> json) {
    return TryOnTask(
      taskId: json['task_id'] ?? '',
      status: json['status'] ?? 'pending',
      provider: json['provider'] ?? 'mock',
      userImageUrl: json['user_image_url'] ?? '',
      garmentImageUrl: json['garment_image_url'] ?? '',
      resultImageUrl: json['result_image_url'],
      errorMessage: json['error_message'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at']) : null,
      canRetry: json['can_retry'] ?? false,
      garmentCategory: json['garment_category'],
      isFriendTryon: json['is_friend_tryon'] ?? false,
      usedSavedModel: json['used_saved_model'] ?? false,
    );
  }

  bool get isProcessing => status == 'pending' || status == 'processing';
  bool get isSuccess => status == 'success';
  bool get isFailed => status == 'failed';
}

class TryOnHistoryResponseModel {
  final List<TryOnTask> items;
  final String? nextCursor;
  final bool hasMore;
  final int totalCount;

  TryOnHistoryResponseModel({
    required this.items,
    this.nextCursor,
    required this.hasMore,
    required this.totalCount,
  });

  factory TryOnHistoryResponseModel.fromJson(Map<String, dynamic> json) {
    final rawList = json['items'] as List<dynamic>? ?? [];
    final items = rawList
        .map((e) => TryOnTask.fromJson(e as Map<String, dynamic>))
        .toList();
    return TryOnHistoryResponseModel(
      items: items,
      nextCursor: json['next_cursor'],
      hasMore: json['has_more'] ?? false,
      totalCount: json['total_count'] ?? items.length,
    );
  }
}

class UserTryOnModel {
  final bool hasModel;
  final String? modelId;
  final String? imageUrl;
  final String? storageProvider;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserTryOnModel({
    required this.hasModel,
    this.modelId,
    this.imageUrl,
    this.storageProvider,
    this.createdAt,
    this.updatedAt,
  });

  factory UserTryOnModel.fromJson(Map<String, dynamic> json) {
    return UserTryOnModel(
      hasModel: json['has_model'] ?? false,
      modelId: json['model_id'],
      imageUrl: json['image_url'],
      storageProvider: json['storage_provider'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }
}
