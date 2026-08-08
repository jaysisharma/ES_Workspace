import 'package:order_app/domain/entities/notification_entity.dart';

abstract class NotificationRepository {
  Stream<List<NotificationEntity>> getNotificationsStream();
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
  Future<void> addNotification(NotificationEntity notification);
  Future<void> deleteNotification(String id);
}
