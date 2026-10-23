import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String? actorId;
  final String? actorName;
  final String eventType;
  final String title;
  final String message;
  final String? referenceId;
  final String? referenceType;
  final String? communityId;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    this.actorId,
    this.actorName,
    required this.eventType,
    required this.title,
    required this.message,
    this.referenceId,
    this.referenceType,
    this.communityId,
    this.isRead = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      actorId: json['actor_id'] as String?,
      actorName: json['actor_name'] as String?,
      eventType: json['event_type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      referenceId: json['reference_id'] as String?,
      referenceType: json['reference_type'] as String?,
      communityId: json['community_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ??
                DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())?.toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'actor_id': actorId,
      'actor_name': actorName,
      'event_type': eventType,
      'title': title,
      'message': message,
      'reference_id': referenceId,
      'reference_type': referenceType,
      'community_id': communityId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? actorId,
    String? actorName,
    String? eventType,
    String? title,
    String? message,
    String? referenceId,
    String? referenceType,
    String? communityId,
    bool? isRead,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      actorId: actorId ?? this.actorId,
      actorName: actorName ?? this.actorName,
      eventType: eventType ?? this.eventType,
      title: title ?? this.title,
      message: message ?? this.message,
      referenceId: referenceId ?? this.referenceId,
      referenceType: referenceType ?? this.referenceType,
      communityId: communityId ?? this.communityId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isBorrowRequest =>
      referenceType == 'borrow_request' ||
      eventType.startsWith('borrow_request_');

  bool get isCommunity =>
      referenceType == 'community' || eventType.startsWith('membership_');

  IconData get iconData {
    switch (eventType) {
      case 'borrow_request_created':
        return Icons.handshake_outlined;
      case 'borrow_request_accepted':
        return Icons.check_circle_outline;
      case 'borrow_request_declined':
        return Icons.cancel_outlined;
      case 'borrow_request_cancelled':
        return Icons.do_not_disturb_on_outlined;
      case 'borrow_request_completed':
        return Icons.task_alt_outlined;
      case 'membership_requested':
        return Icons.group_add_outlined;
      case 'membership_approved':
        return Icons.verified_outlined;
      case 'membership_rejected':
        return Icons.person_off_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get iconColor {
    switch (eventType) {
      case 'borrow_request_accepted':
      case 'membership_approved':
      case 'borrow_request_completed':
        return AppColors.exactMatch;
      case 'borrow_request_declined':
      case 'membership_rejected':
      case 'borrow_request_cancelled':
        return AppColors.missing;
      case 'borrow_request_created':
      case 'membership_requested':
        return AppColors.terracotta;
      default:
        return AppColors.espresso;
    }
  }

  Color get iconBackgroundColor {
    switch (eventType) {
      case 'borrow_request_accepted':
      case 'membership_approved':
      case 'borrow_request_completed':
        return const Color(0xFFE8F5E9);
      case 'borrow_request_declined':
      case 'membership_rejected':
      case 'borrow_request_cancelled':
        return const Color(0xFFFFEBEE);
      case 'borrow_request_created':
      case 'membership_requested':
        return AppColors.terracottaSoft;
      default:
        return AppColors.sandSoft;
    }
  }

  String get formattedRelativeTime {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }
}
