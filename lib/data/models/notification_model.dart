import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:order_app/domain/entities/notification_entity.dart';

class NotificationModel extends NotificationEntity {
  NotificationModel({
    required super.id,
    required super.title,
    required super.description,
    required super.timestamp,
    super.isRead = false,
    super.readBy = const [],
    required super.type,
    super.relatedId,
    super.targetRole = 'admin_founder',
    super.targetUserId,
  });

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.now();
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final rawReadBy = json['readBy'];
    final List<String> readBy = rawReadBy is List
        ? rawReadBy.map((e) => e.toString()).toList()
        : <String>[];

    return NotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      timestamp: _parseDateTime(json['timestamp']),
      isRead: json['isRead'] as bool? ?? false,
      readBy: readBy,
      type: json['type']?.toString() ?? 'general',
      relatedId: json['relatedId']?.toString(),
      targetRole: json['targetRole']?.toString() ?? 'admin_founder',
      targetUserId: json['targetUserId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'readBy': readBy,
      'type': type,
      'relatedId': relatedId,
      'targetRole': targetRole,
      if (targetUserId != null) 'targetUserId': targetUserId,
    };
  }

  factory NotificationModel.fromEntity(NotificationEntity entity) {
    return NotificationModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      timestamp: entity.timestamp,
      isRead: entity.isRead,
      readBy: entity.readBy,
      type: entity.type,
      relatedId: entity.relatedId,
      targetRole: entity.targetRole,
      targetUserId: entity.targetUserId,
    );
  }
}
