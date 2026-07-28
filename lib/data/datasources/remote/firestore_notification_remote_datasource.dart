import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/notification_model.dart';
import '../../../domain/entities/notification_entity.dart';
import '../../../domain/entities/user_entity.dart';

abstract class NotificationRemoteDataSource {
  Stream<List<NotificationEntity>> getNotifications();
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
  Future<void> addNotification(NotificationEntity notification);
  Future<void> deleteNotification(String id);
}

class FirestoreNotificationRemoteDataSource
    implements NotificationRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreNotificationRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  @override
  Stream<List<NotificationEntity>> getNotifications() {
    final uid = _auth.currentUser?.uid;

    // Fetch notifications where:
    //  - targetRole matches the current user's role, OR
    //  - targetUserId matches the current user's uid
    // We do this client-side by merging two streams and deduplicating.
    // The first stream covers role-based notifications; the second covers
    // user-specific ones.
    return _firestore
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          // Get current user's role from Firestore users collection
          String? roleStr;
          if (uid != null) {
            try {
              final userDoc = await _firestore.collection('users').doc(uid).get();
              roleStr = userDoc.data()?['role'] as String?;
            } catch (_) {}
          }

          final role = _roleFromString(roleStr);
          final allowedTargetRoles = _allowedTargetRoles(role);

          return snapshot.docs
              .map((doc) => NotificationModel.fromJson(doc.data()))
              .where((n) {
                // User-specific notification
                if (n.targetUserId != null) return n.targetUserId == uid;
                // Role-based notification
                return allowedTargetRoles.contains(n.targetRole);
              })
              .toList();
        });
  }

  static UserRole _roleFromString(String? role) {
    switch (role) {
      case 'founder':
        return UserRole.founder;
      case 'staff':
        return UserRole.staff;
      default:
        return UserRole.admin;
    }
  }

  /// Returns the targetRole values this role is allowed to see.
  static List<String> _allowedTargetRoles(UserRole role) {
    switch (role) {
      case UserRole.founder:
        return ['admin_founder', 'founder', 'all'];
      case UserRole.admin:
        return ['admin_founder', 'admin', 'all'];
      case UserRole.staff:
        return ['staff', 'all'];
    }
  }

  @override
  Future<void> markAsRead(String id) async {
    await _firestore.collection('notifications').doc(id).update({
      'isRead': true,
    });
  }

  @override
  Future<void> markAllAsRead() async {
    final unread = await _firestore
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  @override
  Future<void> addNotification(NotificationEntity notification) async {
    final model = NotificationModel.fromEntity(notification);
    await _firestore
        .collection('notifications')
        .doc(model.id)
        .set(model.toJson());
  }

  @override
  Future<void> deleteNotification(String id) async {
    await _firestore.collection('notifications').doc(id).delete();
  }
}
