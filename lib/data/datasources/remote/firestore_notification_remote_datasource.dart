import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/notification_model.dart';
import 'package:order_app/domain/entities/notification_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';

abstract class NotificationRemoteDataSource {
  Stream<List<NotificationEntity>> getNotifications({
    String? userId,
    UserRole? role,
  });
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
  Stream<List<NotificationEntity>> getNotifications({
    String? userId,
    UserRole? role,
  }) {
    final effectiveUid = userId ?? _auth.currentUser?.uid;
    final effectiveRole = role ?? UserRole.admin;
    final allowedTargetRoles = _allowedTargetRoles(effectiveRole);

    return _firestore
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                try {
                  final data = doc.data();
                  if (!data.containsKey('id') || data['id'] == null) {
                    data['id'] = doc.id;
                  }
                  return NotificationModel.fromJson(data);
                } catch (e) {
                  return null;
                }
              })
              .whereType<NotificationModel>()
              .where((n) {
                // 1. User-specific notification targeting this user
                if (n.targetUserId != null && n.targetUserId!.isNotEmpty) {
                  return effectiveUid != null && n.targetUserId == effectiveUid;
                }

                // 2. Role-based notification matching this user's role
                return allowedTargetRoles.contains(n.targetRole);
              })
              .toList();
        });
  }

  static List<String> _allowedTargetRoles(UserRole role) {
    switch (role) {
      case UserRole.founder:
        return ['admin_founder', 'founder', 'management', 'all'];
      case UserRole.admin:
        return ['admin_founder', 'admin', 'founder', 'management', 'all'];
      case UserRole.finance:
        return ['finance', 'management', 'all'];
      case UserRole.staff:
        return ['staff', 'all'];
    }
  }

  @override
  Future<void> markAsRead(String id) async {
    final uid = _auth.currentUser?.uid;
    final docRef = _firestore.collection('notifications').doc(id);
    if (uid != null) {
      await docRef.set({
        'isRead': true,
        'readBy': FieldValue.arrayUnion([uid]),
      }, SetOptions(merge: true));
    } else {
      await docRef.set({'isRead': true}, SetOptions(merge: true));
    }
  }

  @override
  Future<void> markAllAsRead() async {
    final uid = _auth.currentUser?.uid;
    final snapshot = await _firestore
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      if (uid != null) {
        batch.set(doc.reference, {
          'readBy': FieldValue.arrayUnion([uid]),
        }, SetOptions(merge: true));
      } else {
        batch.set(doc.reference, {'isRead': true}, SetOptions(merge: true));
      }
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
