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
    );
  }

  bool get isProcessing => status == 'pending' || status == 'processing';
  bool get isSuccess => status == 'success';
  bool get isFailed => status == 'failed';
}
