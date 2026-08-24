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

  static final List<StreamSubscription<QuerySnapshot>> _firestoreSubscriptions = [];

  // Deduplication cache to prevent dual-delivery duplicate banners in foreground
  static final Set<String> _recentNotificationKeys = {};

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

      // Show a local notification for FCM messages received in foreground with deduplication
      FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        if (n != null) {
          final notifId = message.data['notificationId'] ?? message.messageId;
          showLocalNotification(
            title: n.title ?? '',
            body: n.body ?? '',
            notificationId: notifId,
          );
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
        FirebaseMessaging.instance.unsubscribeFromTopic('role_finance'),
        FirebaseMessaging.instance.unsubscribeFromTopic('role_staff'),
        FirebaseMessaging.instance.unsubscribeFromTopic('role_management'),
      ]);
      // Subscribe to this user's role topic
      final cleanRole = role.toLowerCase().trim();
      await FirebaseMessaging.instance.subscribeToTopic('role_$cleanRole');

      if (cleanRole == 'admin' || cleanRole == 'founder' || cleanRole == 'finance') {
        await FirebaseMessaging.instance.subscribeToTopic('role_management');
      }

      // Subscribe to personal topic for user-specific notifications
      await FirebaseMessaging.instance.subscribeToTopic('user_$userId');
      debugPrint('🔔 [PushNotificationService] Subscribed to role_$cleanRole and user_$userId');
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
        FirebaseMessaging.instance.unsubscribeFromTopic('role_admin'),
        FirebaseMessaging.instance.unsubscribeFromTopic('role_founder'),
        FirebaseMessaging.instance.unsubscribeFromTopic('role_finance'),
        FirebaseMessaging.instance.unsubscribeFromTopic('role_staff'),
        FirebaseMessaging.instance.unsubscribeFromTopic('role_management'),
        FirebaseMessaging.instance.unsubscribeFromTopic('user_$userId'),
      ]);
    } catch (e) {
      debugPrint('PushNotificationService topic unsubscription error: $e');
    }
  }

  /// Call right after login.
  /// Starts watching Firestore with targeted streams (User-specific + Role-broadcast)
  /// so individual notifications are NEVER missed or pushed out by global query limits.
  static Future<void> startListening({
    required String userId,
    required String role,
  }) async {
    // Cancel any previous listeners first
    await stopListening();

    _listeningSince = DateTime.now();
    final allowedRoles = _allowedTargetRoles(role);

    // 1. User-Specific Listener (Never eclipsed by global limits)
    final userSub = FirebaseFirestore.instance
        .collection('notifications')
        .where('targetUserId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(25)
        .snapshots()
        .listen(
          (snapshot) => _handleSnapshot(snapshot),
          onError: (e) => debugPrint('User notification listener error: $e'),
        );
    _firestoreSubscriptions.add(userSub);

    // 2. Role / Broadcast Listener
    final roleSub = FirebaseFirestore.instance
        .collection('notifications')
        .where('targetRole', whereIn: allowedRoles)
        .orderBy('timestamp', descending: true)
        .limit(25)
        .snapshots()
        .listen(
          (snapshot) => _handleSnapshot(snapshot),
          onError: (e) => debugPrint('Role notification listener error: $e'),
        );
    _firestoreSubscriptions.add(roleSub);
  }

  static void _handleSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
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

      final title = data['title'] as String? ?? 'New Notification';
      final body = data['description'] as String? ?? '';
      final notifId = change.doc.id;

      showLocalNotification(
        title: title,
        body: body,
        notificationId: notifId,
      );
    }
  }

  /// Call on logout — stops all Firestore listeners.
  static Future<void> stopListening() async {
    for (final sub in _firestoreSubscriptions) {
      await sub.cancel();
    }
    _firestoreSubscriptions.clear();
    _listeningSince = null;
  }

  /// Which targetRole values a given role should receive.
  static List<String> _allowedTargetRoles(String role) {
    switch (role.toLowerCase()) {
      case 'founder':
      case 'director':
      case 'ceo':
        return ['admin_founder', 'founder', 'management', 'all'];
      case 'finance':
        return ['finance', 'management', 'all'];
      case 'staff':
        return ['staff', 'all'];
      case 'admin':
      default:
        return ['admin_founder', 'admin', 'founder', 'management', 'all'];
    }
  }

  /// Immediately shows a notification in the phone/desktop notification panel
  /// with automatic deduplication across FCM and Firestore.
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String? notificationId,
  }) async {
    final dedupKey = notificationId ?? '$title::$body';
    if (_recentNotificationKeys.contains(dedupKey)) {
      debugPrint('🔕 [PushNotificationService] Skipped duplicate notification: $dedupKey');
      return;
    }
    _recentNotificationKeys.add(dedupKey);
    // Expire deduplication key after 8 seconds
    Future.delayed(const Duration(seconds: 8), () {
      _recentNotificationKeys.remove(dedupKey);
    });

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
