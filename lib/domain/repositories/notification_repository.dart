import 'package:order_app/domain/entities/notification_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';

abstract class NotificationRepository {
  Stream<List<NotificationEntity>> getNotificationsStream({
    String? userId,
    UserRole? role,
  });
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
  Future<void> addNotification(NotificationEntity notification);
  Future<void> deleteNotification(String id);
}
