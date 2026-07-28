/// Values for [targetRole]:
/// - `'admin_founder'` — only admin and founder devices
/// - `'staff'`         — only staff devices
/// - `'all'`           — every device (use sparingly)
/// If [targetUserId] is set, the notification goes only to that specific user
/// (used for per-staff change-request responses).
class NotificationEntity {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final bool isRead;
  final String type; // 'order', 'finance', 'system', 'warning', etc.
  final String? relatedId; // ID of the order, change request, etc.
  final String targetRole; // 'admin_founder' | 'staff' | 'all'
  final String? targetUserId; // set when notification is for one specific user

  const NotificationEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    this.isRead = false,
    required this.type,
    this.relatedId,
    this.targetRole = 'admin_founder',
    this.targetUserId,
  });

  NotificationEntity copyWith({
    String? title,
    String? description,
    DateTime? timestamp,
    bool? isRead,
    String? type,
    String? relatedId,
    String? targetRole,
    String? targetUserId,
  }) {
    return NotificationEntity(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      relatedId: relatedId ?? this.relatedId,
      targetRole: targetRole ?? this.targetRole,
      targetUserId: targetUserId ?? this.targetUserId,
    );
  }
}
