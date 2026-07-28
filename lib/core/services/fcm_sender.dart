import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Sends FCM push notifications directly from the app using a service account.
/// FCM itself is free on all Firebase plans — no Cloud Functions needed.
///
/// ⚠️  The service account key grants admin access to your Firebase project.
///     Keep this app internal and never publish it to a public app store.
class FcmSender {
  static const _fcmScope = 'https://www.googleapis.com/auth/firebase.messaging';
  static const _projectId = 'orderapp-bcea2';

  static Map<String, dynamic>? _cachedCredentials;
  static http.Client? _authClient;

  /// Loads service account JSON from assets once and caches it.
  static Future<Map<String, dynamic>> _loadCredentials() async {
    _cachedCredentials ??= jsonDecode(
      await rootBundle.loadString('assets/service_account.json'),
    ) as Map<String, dynamic>;
    return _cachedCredentials!;
  }

  /// Returns an authenticated HTTP client, reusing it if still valid.
  static Future<http.Client> _getClient() async {
    if (_authClient != null) return _authClient!;
    final credentials = ServiceAccountCredentials.fromJson(
      await _loadCredentials(),
    );
    _authClient = await clientViaServiceAccount(credentials, [_fcmScope]);
    return _authClient!;
  }

  /// Sends an FCM message to a **topic** (e.g. `role_admin`, `role_founder`).
  static Future<void> sendToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final client = await _getClient();
      final url = Uri.parse(
        'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send',
      );

      final payload = {
        'message': {
          'topic': topic,
          'notification': {'title': title, 'body': body},
          'data': data ?? {},
          'android': {
            'priority': 'high',
            'notification': {'channel_id': 'order_app_high', 'sound': 'default'},
          },
          'apns': {
            'payload': {
              'aps': {'sound': 'default', 'badge': 1},
            },
          },
        },
      };

      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        debugPrint('FCM error [topic=$topic]: ${response.body}');
      }
    } catch (e) {
      debugPrint('FCM send failed: $e');
    }
  }

  /// Sends an FCM message to a **specific user** via their personal topic
  /// `user_<uid>` (every device subscribes to this on login).
  static Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) =>
      sendToTopic(
        topic: 'user_$userId',
        title: title,
        body: body,
        data: data,
      );

  /// Sends to multiple topics in parallel.
  static Future<void> sendToTopics({
    required List<String> topics,
    required String title,
    required String body,
    Map<String, String>? data,
  }) =>
      Future.wait(
        topics.map(
          (t) => sendToTopic(topic: t, title: title, body: body, data: data),
        ),
      );
}
