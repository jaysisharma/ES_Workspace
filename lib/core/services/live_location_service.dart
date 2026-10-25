import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:order_app/domain/entities/auth_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';

class LiveLocationData {
  final String userId;
  final String userEmail;
  final String userRole;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final bool isSharing;
  final DateTime? updatedAt;
  final String device;

  const LiveLocationData({
    required this.userId,
    required this.userEmail,
    required this.userRole,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    required this.isSharing,
    this.updatedAt,
    required this.device,
  });

  /// Considered online when sharing and a heartbeat arrived recently.
  bool get isOnline =>
      isSharing &&
      updatedAt != null &&
      DateTime.now().difference(updatedAt!) < LiveLocationService.staleAfter;

  factory LiveLocationData.fromJson(Map<String, dynamic> json, {required String docId}) {
    return LiveLocationData(
      userId: docId,
      userEmail: json['userEmail'] as String? ?? '',
      userRole: json['userRole'] as String? ?? 'staff',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      isSharing: json['isSharing'] as bool? ?? false,
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
      device: json['device'] as String? ?? 'Unknown device',
    );
  }
}

/// Streams the signed-in employee's position to `live_locations/{uid}` so
/// management can see where staff are in real time.
class LiveLocationService {
  LiveLocationService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'live_locations';

  /// A location older than this is shown as offline / last seen.
  static const staleAfter = Duration(minutes: 3);
  static const _minWriteInterval = Duration(seconds: 20);
  static const _heartbeatInterval = Duration(seconds: 60);

  static StreamSubscription<Position>? _positionSub;
  static Timer? _heartbeat;
  static Position? _lastPosition;
  static DateTime? _lastWriteAt;
  static AuthEntity? _user;

  /// Roles that view live locations instead of sharing their own.
  static bool isViewerRole(UserRole role) =>
      role == UserRole.superAdmin ||
      role == UserRole.director ||
      role == UserRole.founder ||
      role == UserRole.companySecretary;

  static bool get _isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Starts sharing location for tracked roles. Safe to call more than once.
  static Future<void> start(AuthEntity user) async {
    if (!_isMobile || isViewerRole(user.role)) return;
    if (_positionSub != null && _user?.uid == user.uid) return;
    await stop();
    _user = user;

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        debugPrint('⚠️ [LiveLocation] Location services disabled; not sharing.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ [LiveLocation] Permission denied; not sharing.');
        return;
      }

      _positionSub = Geolocator.getPositionStream(
        locationSettings: _locationSettings(),
      ).listen(
        (position) {
          _lastPosition = position;
          final last = _lastWriteAt;
          if (last == null || DateTime.now().difference(last) >= _minWriteInterval) {
            _write(position);
          }
        },
        onError: (e) => debugPrint('⚠️ [LiveLocation] Position stream error: $e'),
      );

      // Stationary users produce no stream events, so refresh periodically.
      _heartbeat = Timer.periodic(_heartbeatInterval, (_) async {
        final position = _lastPosition ?? await Geolocator.getLastKnownPosition();
        if (position != null) _write(position);
      });

      debugPrint('📡 [LiveLocation] Sharing started for ${user.email}');
    } catch (e) {
      debugPrint('❌ [LiveLocation] Failed to start sharing: $e');
    }
  }

  /// Stops sharing and marks the user as no longer live.
  static Future<void> stop() async {
    final user = _user;
    await _positionSub?.cancel();
    _positionSub = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    _lastPosition = null;
    _lastWriteAt = null;
    _user = null;

    if (user == null) return;
    try {
      await _firestore.collection(_collection).doc(user.uid).set(
        {'isSharing': false, 'stoppedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      debugPrint('🛑 [LiveLocation] Sharing stopped for ${user.email}');
    } catch (e) {
      debugPrint('⚠️ [LiveLocation] Failed to mark sharing stopped: $e');
    }
  }

  static LocationSettings _locationSettings() {
    if (Platform.isAndroid) {
      // Foreground service keeps updates flowing while the app is minimised,
      // with a persistent notification so the employee knows they are shared.
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
        intervalDuration: const Duration(seconds: 15),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Location sharing active',
          notificationText: 'Your live location is visible to management while you are signed in.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    return AppleSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
      activityType: ActivityType.otherNavigation,
      pauseLocationUpdatesAutomatically: true,
      allowBackgroundLocationUpdates: false,
    );
  }

  static Future<void> _write(Position position) async {
    final user = _user;
    if (user == null) return;
    _lastWriteAt = DateTime.now();
    try {
      await _firestore.collection(_collection).doc(user.uid).set({
        'userId': user.uid,
        'userEmail': user.email,
        'userRole': user.role.name,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'isSharing': true,
        'device': Platform.isAndroid ? 'Android Phone' : 'iPhone / iPad',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ [LiveLocation] Failed to write position: $e');
    }
  }

  /// Live stream of every employee's latest shared location.
  static Stream<List<LiveLocationData>> getLiveLocationsStream() {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) => doc.data()['latitude'] != null)
          .map((doc) => LiveLocationData.fromJson(doc.data(), docId: doc.id))
          .toList();
    });
  }
}
