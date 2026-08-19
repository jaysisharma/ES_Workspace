import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/domain/entities/notification_entity.dart';
import 'package:order_app/domain/repositories/notification_repository.dart';
import 'package:order_app/data/repositories/notification_repository_impl.dart';
import 'package:order_app/data/datasources/remote/firestore_notification_remote_datasource.dart';

final notificationRemoteDataSourceProvider =
    Provider<NotificationRemoteDataSource>((ref) {
      return FirestoreNotificationRemoteDataSource();
    });

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final dataSource = ref.watch(notificationRemoteDataSourceProvider);
  return NotificationRepositoryImpl(remoteDataSource: dataSource);
});

final notificationsStreamProvider = StreamProvider<List<NotificationEntity>>((
  ref,
) {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getNotificationsStream();
});

class NotificationNotifier extends Notifier<void> {
  @override
  void build() {}

  NotificationRepository get _repo => ref.read(notificationRepositoryProvider);

  Future<void> markAsRead(String id) => _repo.markAsRead(id);
  Future<void> markAllAsRead() => _repo.markAllAsRead();
  Future<void> addNotification(NotificationEntity notification) =>
      _repo.addNotification(notification);
  Future<void> deleteNotification(String id) => _repo.deleteNotification(id);
  Future<void> deleteMultipleNotifications(List<String> ids) async {
    await Future.wait(ids.map((id) => _repo.deleteNotification(id)));
  }
}

final notificationNotifierProvider =
    NotifierProvider<NotificationNotifier, void>(() {
      return NotificationNotifier();
    });
