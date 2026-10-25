import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:order_app/domain/entities/auth_entity.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginLocationData {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String userRole;
  final DateTime timestamp;
  final String address;
  final double? latitude;
  final double? longitude;
  final String device;
  final String? ip;

  const LoginLocationData({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
    required this.timestamp,
    required this.address,
    this.latitude,
    this.longitude,
    required this.device,
    this.ip,
  });

  factory LoginLocationData.fromJson(Map<String, dynamic> json, {String? docId}) {
    DateTime parsedTime = DateTime.now();
    if (json['timestamp'] is Timestamp) {
      parsedTime = (json['timestamp'] as Timestamp).toDate();
    } else if (json['timestamp'] is String) {
      parsedTime = DateTime.tryParse(json['timestamp']) ?? DateTime.now();
    }

    return LoginLocationData(
      id: docId ?? json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Staff Member',
      userEmail: json['userEmail'] as String? ?? '',
      userRole: json['userRole'] as String? ?? 'staff',
      timestamp: parsedTime,
      address: json['address'] as String? ?? 'Location unavailable',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      device: json['device'] as String? ?? 'Unknown device',
      ip: json['ip'] as String?,
    );
  }
}

class LocationTrackingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Captures current location & records the login in Firestore in the background
  static Future<void> recordLogin(AuthEntity user) async {
    try {
      debugPrint('📍 [LocationTracker] Starting location detection for ${user.email} (${user.uid})...');
      
      final device = _getDevicePlatform();
      Position? position;
      String address = 'Location unavailable';
      String? ipAddress;

      // 1. Try GPS Location Detection
      try {
        position = await _getCurrentPosition();
      } catch (e) {
        debugPrint('⚠️ [LocationTracker] GPS location retrieval error: $e');
      }

      // 2. Resolve Human-Readable Address
      if (position != null) {
        address = await _resolveAddress(position.latitude, position.longitude);
      } else {
        // Fallback: Try IP-based location if GPS is unavailable
        try {
          final ipLocation = await _fetchIpLocation();
          if (ipLocation != null) {
            address = ipLocation['city_region'] ?? 'Approx. location (IP)';
            ipAddress = ipLocation['ip'];
          }
        } catch (_) {}
      }

      final now = FieldValue.serverTimestamp();

      // 3. Update User Document in 'users' collection
      final userUpdate = <String, dynamic>{
        'lastLoginAt': now,
        'lastLoginLocation': address,
        'lastLoginDevice': device,
      };

      if (position != null) {
        userUpdate['lastLoginLatitude'] = position.latitude;
        userUpdate['lastLoginLongitude'] = position.longitude;
      }
      if (ipAddress != null) {
        userUpdate['lastLoginIp'] = ipAddress;
      }

      await _firestore.collection('users').doc(user.uid).set(
        userUpdate,
        SetOptions(merge: true),
      );

      // 4. Create an entry in 'login_logs' collection for Admin history audit
      final logRef = _firestore.collection('login_logs').doc();
      await logRef.set({
        'id': logRef.id,
        'userId': user.uid,
        'userEmail': user.email,
        'userName': user.email.contains('@') ? user.email.split('@').first : 'User',
        'userRole': user.role.name,
        'timestamp': now,
        'address': address,
        'latitude': position?.latitude,
        'longitude': position?.longitude,
        'device': device,
        'ip': ipAddress,
      });

      debugPrint('✅ [LocationTracker] Recorded login location: "$address" on $device for UID: ${user.uid}');
    } catch (e, stack) {
      debugPrint('❌ [LocationTracker] Failed to record login location: $e');
      debugPrint('❌ [LocationTracker] StackTrace: $stack');
    }
  }

  /// Tries to get GPS position with multi-tiered fallbacks and quick timeouts
  static Future<Position?> _getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('⚠️ [LocationTracker] Location services are disabled.');
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ [LocationTracker] Location permission denied.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );
    } catch (_) {
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 3),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
    }

    return pos;
  }

  /// Resolves human-readable address with geocoding plugin and OpenStreetMap fallback
  static Future<String> _resolveAddress(double lat, double lng) async {
    try {
      final geocoding = Geocoding();
      List<Placemark> placemarks = await geocoding.placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = [
          place.street,
          place.subLocality,
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
          place.country,
        ].where((p) => p != null && p.trim().isNotEmpty).toSet().toList();

        if (parts.isNotEmpty) {
          return parts.join(', ');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [LocationTracker] Geocoding plugin failed: $e, trying HTTP fallback...');
    }

    // HTTP Nominatim Fallback
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'OrderApp/1.0 (LocationTracker)'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          return displayName;
        }
      }
    } catch (_) {}

    return 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';
  }

  /// IP-based approximate location lookup
  static Future<Map<String, String>?> _fetchIpLocation() async {
    try {
      final url = Uri.parse('https://ipapi.co/json/');
      final response = await http.get(
        url,
        headers: {'User-Agent': 'OrderApp/1.0'},
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final city = data['city'] as String? ?? '';
        final region = data['region'] as String? ?? '';
        final country = data['country_name'] as String? ?? '';
        final ip = data['ip'] as String? ?? '';

        final parts = [city, region, country].where((s) => s.isNotEmpty).join(', ');
        return {
          'city_region': parts.isNotEmpty ? parts : 'Approximate Location (IP)',
          'ip': ip,
        };
      }
    } catch (_) {}
    return null;
  }

  /// Returns friendly device/platform label
  static String _getDevicePlatform() {
    if (kIsWeb) return 'Web Browser';
    try {
      if (Platform.isAndroid) return 'Android Phone';
      if (Platform.isIOS) return 'iPhone / iPad';
      if (Platform.isMacOS) return 'macOS App';
      if (Platform.isWindows) return 'Windows PC';
      if (Platform.isLinux) return 'Linux PC';
    } catch (_) {}
    return 'Mobile App';
  }

  /// Opens the location coordinates on Google Maps / Apple Maps
  static Future<void> openMap(double latitude, double longitude) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Stream of recent login logs for the admin dashboard
  static Stream<List<LoginLocationData>> getLoginLogsStream({int limit = 100}) {
    return _firestore
        .collection('login_logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return LoginLocationData.fromJson(doc.data(), docId: doc.id);
          }).toList();
        });
  }
}
