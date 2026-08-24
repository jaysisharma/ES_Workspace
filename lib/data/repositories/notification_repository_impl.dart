import 'package:order_app/domain/entities/notification_entity.dart';
import 'package:order_app/domain/repositories/notification_repository.dart';
import '../datasources/remote/firestore_notification_remote_datasource.dart';

import 'package:order_app/domain/entities/user_entity.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource remoteDataSource;

  NotificationRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<NotificationEntity>> getNotificationsStream({
    String? userId,
    UserRole? role,
  }) {
    return remoteDataSource.getNotifications(userId: userId, role: role);
  }

  @override
  Future<void> markAsRead(String id) {
    return remoteDataSource.markAsRead(id);
  }

  @override
  Future<void> markAllAsRead() {
    return remoteDataSource.markAllAsRead();
  }

  @override
  Future<void> addNotification(NotificationEntity notification) {
    return remoteDataSource.addNotification(notification);
  }

  @override
  Future<void> deleteNotification(String id) {
    return remoteDataSource.deleteNotification(id);
  }
}
