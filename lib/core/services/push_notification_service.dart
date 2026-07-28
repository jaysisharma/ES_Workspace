import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background FCM handler — must be a top-level function.
/// Android/iOS show notification automatically for messages with a notification
/// payload when the app is in background/terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // System handles notification display automatically for notification messages.
  // Nothing extra needed here.
}

class PushNotificationService {
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channelId = 'order_app_high';
  static const _channelName = 'Order App Notifications';
  static const _channelDescription = 'Real-time updates from Order App';

  static StreamSubscription<QuerySnapshot>? _firestoreSubscription;

  // Track when we started listening so we only show NEW notifications
  static DateTime? _listeningSince;

  /// Call once at app start — sets up local notification channel and permissions.
  static Future<void> initialize() async {
    try {
      // Request permission (covers iOS + Android 13+)
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('PushNotificationService: Permission request skipped/failed: $e');
    }

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _localNotifications.initialize(
        InitializationSettings(
          android: androidInit,
          iOS: darwinInit,
          macOS: darwinInit,
        ),
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.high,
              playSound: true,
            ),
          );

      // Show a local notification for FCM messages received in foreground
      FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        if (n != null) {
          showLocalNotification(title: n.title ?? '', body: n.body ?? '');
        }
      });
    } catch (e) {
      debugPrint('PushNotificationService local notifications init skipped/failed: $e');
    }
  }

  /// Call right after login — subscribes to role + personal FCM topics
  /// so FCM can deliver pushes even when the app is terminated.
  static Future<void> subscribeToTopics({
    required String userId,
    required String role,
  }) async {
    try {
      // Unsubscribe from all role topics first (clean slate)
      await Future.wait([
        FirebaseMessaging.instance.unsubscribeFromTopic('role_admin'),
        FirebaseMessaging.instance.unsubscribeFromTopic('role_founder'),
        FirebaseMessaging.instance.unsubscribeFromTopic('role_staff'),
      ]);
      // Subscribe to this user's role topic
      await FirebaseMessaging.instance.subscribeToTopic('role_$role');
      // Subscribe to personal topic for user-specific notifications
      await FirebaseMessaging.instance.subscribeToTopic('user_$userId');
    } catch (e) {
      debugPrint('PushNotificationService topic subscription skipped/failed: $e');
    }
  }

  /// Call on logout — unsubscribes from all topics.
  static Future<void> unsubscribeFromTopics({
    required String userId,
    required String role,
  }) async {
    try {
      await Future.wait([
        FirebaseMessaging.instance.unsubscribeFromTopic('role_$role'),
        FirebaseMessaging.instance.unsubscribeFromTopic('user_$userId'),
      ]);
    } catch (e) {
      debugPrint('PushNotificationService topic unsubscription error: $e');
    }
  }

  /// Call right after login.
  /// Starts watching Firestore for notifications targeted at this user/role
  /// and pops a system notification for each new one that arrives.
  static Future<void> startListening({
    required String userId,
    required String role,
  }) async {
    // Cancel any previous listener first
    await stopListening();

    _listeningSince = DateTime.now();
    final allowedRoles = _allowedTargetRoles(role);

    _firestoreSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(30)
        .snapshots()
        .listen(
          (snapshot) {
            for (final change in snapshot.docChanges) {
              // Only react to genuinely new documents
              if (change.type != DocumentChangeType.added) continue;

              final data = change.doc.data();
              if (data == null) continue;

              // Ignore notifications that existed before we started listening
              final rawTs = data['timestamp'];
              DateTime? ts;
              try {
                ts = rawTs is String ? DateTime.parse(rawTs) : null;
              } catch (_) {}
              if (ts == null || !ts.isAfter(_listeningSince!)) continue;

              final targetRole = data['targetRole'] as String? ?? 'admin_founder';
              final targetUserId = data['targetUserId'] as String?;

              // Decide if this notification is meant for this user
              final bool isForMe = targetUserId != null
                  ? targetUserId == userId
                  : allowedRoles.contains(targetRole);

              if (!isForMe) continue;

              final title = data['title'] as String? ?? 'New Notification';
              final body = data['description'] as String? ?? '';
              showLocalNotification(title: title, body: body);
            }
          },
          onError: (e) => debugPrint('Notification listener error: $e'),
        );
  }

  /// Call on logout — stops the Firestore listener.
  static Future<void> stopListening() async {
    await _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
    _listeningSince = null;
  }

  /// Which targetRole values a given role should receive.
  static List<String> _allowedTargetRoles(String role) {
    switch (role) {
      case 'founder':
        return ['admin_founder', 'founder', 'all'];
      case 'staff':
        return ['staff', 'all'];
      default: // admin
        return ['admin_founder', 'admin', 'all'];
    }
  }

  /// Immediately shows a notification in the phone's notification panel.
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }
}
