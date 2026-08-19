enum AttendanceStatus {
  present,
  halfDay,
  absent;

  String get displayName {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.halfDay:
        return 'Half Day';
    }
  }

  static AttendanceStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'present':
      case 'late':
        return AttendanceStatus.present;
      case 'absent':
        return AttendanceStatus.absent;
      case 'halfday':
      case 'half_day':
        return AttendanceStatus.halfDay;
      default:
        return AttendanceStatus.present;
    }
  }
}

class AttendanceEntity {
  final String id;
  final String staffId;
  final String staffName;
  final String eventId;
  final String eventTitle;
  final String orderId;
  final DateTime date;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final AttendanceStatus status;
  final String? checkInSelfieUrl;
  final String? checkOutSelfieUrl;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final String? checkInAddress;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final String? checkOutAddress;
  final String? notes;
  final bool verifiedByQr;
  final bool isWithinGeofence;
  final double? distanceToVenueMeters;
  final DateTime createdAt;

  const AttendanceEntity({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.eventId,
    required this.eventTitle,
    required this.orderId,
    required this.date,
    required this.checkInTime,
    this.checkOutTime,
    this.status = AttendanceStatus.present,
    this.checkInSelfieUrl,
    this.checkOutSelfieUrl,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkInAddress,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.checkOutAddress,
    this.notes,
    this.verifiedByQr = false,
    this.isWithinGeofence = true,
    this.distanceToVenueMeters,
    required this.createdAt,
  });

  bool get isCheckedOut => checkOutTime != null;

  Duration get workingDuration {
    if (checkOutTime == null) {
      return DateTime.now().difference(checkInTime);
    }
    return checkOutTime!.difference(checkInTime);
  }

  AttendanceEntity copyWith({
    String? id,
    String? staffId,
    String? staffName,
    String? eventId,
    String? eventTitle,
    String? orderId,
    DateTime? date,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    AttendanceStatus? status,
    String? checkInSelfieUrl,
    String? checkOutSelfieUrl,
    double? checkInLatitude,
    double? checkInLongitude,
    String? checkInAddress,
    double? checkOutLatitude,
    double? checkOutLongitude,
    String? checkOutAddress,
    String? notes,
    bool? verifiedByQr,
    bool? isWithinGeofence,
    double? distanceToVenueMeters,
    DateTime? createdAt,
  }) {
    return AttendanceEntity(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      eventId: eventId ?? this.eventId,
      eventTitle: eventTitle ?? this.eventTitle,
      orderId: orderId ?? this.orderId,
      date: date ?? this.date,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      status: status ?? this.status,
      checkInSelfieUrl: checkInSelfieUrl ?? this.checkInSelfieUrl,
      checkOutSelfieUrl: checkOutSelfieUrl ?? this.checkOutSelfieUrl,
      checkInLatitude: checkInLatitude ?? this.checkInLatitude,
      checkInLongitude: checkInLongitude ?? this.checkInLongitude,
      checkInAddress: checkInAddress ?? this.checkInAddress,
      checkOutLatitude: checkOutLatitude ?? this.checkOutLatitude,
      checkOutLongitude: checkOutLongitude ?? this.checkOutLongitude,
      checkOutAddress: checkOutAddress ?? this.checkOutAddress,
      notes: notes ?? this.notes,
      verifiedByQr: verifiedByQr ?? this.verifiedByQr,
      isWithinGeofence: isWithinGeofence ?? this.isWithinGeofence,
      distanceToVenueMeters: distanceToVenueMeters ?? this.distanceToVenueMeters,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
