import 'package:geolocator/geolocator.dart';

class GeofenceService {
  /// Default radius tolerance in meters if not specified for an event (e.g. 200m)
  static const double defaultRadiusMeters = 200.0;

  /// Calculates the distance between two geographical points in meters.
  static double calculateDistance({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Determines if current position is within the geofence radius of venue coordinates.
  static bool isWithinGeofence({
    required double currentLatitude,
    required double currentLongitude,
    required double venueLatitude,
    required double venueLongitude,
    double radiusMeters = defaultRadiusMeters,
  }) {
    final distance = calculateDistance(
      startLatitude: currentLatitude,
      startLongitude: currentLongitude,
      endLatitude: venueLatitude,
      endLongitude: venueLongitude,
    );
    return distance <= radiusMeters;
  }

  /// Returns human-readable distance string (e.g., "120 m away" or "2.4 km away").
  static String formatDistance(double? distanceInMeters) {
    if (distanceInMeters == null) return 'Unknown distance';
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()} m away';
    }
    final km = distanceInMeters / 1000;
    return '${km.toStringAsFixed(1)} km away';
  }
}
