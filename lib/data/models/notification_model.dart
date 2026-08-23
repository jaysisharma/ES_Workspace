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

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final rawReadBy = json['readBy'];
    final List<String> readBy = rawReadBy is List
        ? rawReadBy.map((e) => e.toString()).toList()
        : <String>[];

    return NotificationModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
      readBy: readBy,
      type: json['type'] as String,
      relatedId: json['relatedId'] as String?,
      targetRole: json['targetRole'] as String? ?? 'admin_founder',
      targetUserId: json['targetUserId'] as String?,
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
