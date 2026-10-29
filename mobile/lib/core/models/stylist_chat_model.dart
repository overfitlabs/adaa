import 'wardrobe_item.dart';

class StylistActionModel {
  final String actionType;
  final String title;
  final Map<String, dynamic> payload;

  StylistActionModel({
    required this.actionType,
    required this.title,
    this.payload = const {},
  });

  factory StylistActionModel.fromJson(Map<String, dynamic> json) {
    return StylistActionModel(
      actionType: json['action_type'] ?? '',
      title: json['title'] ?? '',
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'action_type': actionType,
    'title': title,
    'payload': payload,
  };
}

class ChatMessageModel {
  final String id;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;
  final List<WardrobeItem> suggestedItems;
  final List<String> suggestedAcquisitions;
  final List<StylistActionModel> actions;
  final String domainStatus;

  ChatMessageModel({
    String? id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.suggestedItems = const [],
    this.suggestedAcquisitions = const [],
    this.actions = const [],
    this.domainStatus = 'allowed',
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  Map<String, dynamic> toRequestHistoryJson() => {
    'role': role,
    'content': content,
  };
}

class StylistChatResponseModel {
  final String reply;
  final String domainStatus;
  final List<WardrobeItem> suggestedItems;
  final List<String> suggestedAcquisitions;
  final List<StylistActionModel> actions;

  StylistChatResponseModel({
    required this.reply,
    required this.domainStatus,
    this.suggestedItems = const [],
    this.suggestedAcquisitions = const [],
    this.actions = const [],
  });

  factory StylistChatResponseModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['suggested_items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((i) => WardrobeItem.fromJson(i as Map<String, dynamic>))
        .toList();

    final rawAcq = json['suggested_acquisitions'] as List<dynamic>? ?? [];
    final acquisitions = rawAcq.map((a) => a.toString()).toList();

    final rawActions = json['actions'] as List<dynamic>? ?? [];
    final actions = rawActions
        .map((a) => StylistActionModel.fromJson(a as Map<String, dynamic>))
        .toList();

    return StylistChatResponseModel(
      reply: json['reply'] ?? '',
      domainStatus: json['domain_status'] ?? 'allowed',
      suggestedItems: items,
      suggestedAcquisitions: acquisitions,
      actions: actions,
    );
  }
}
