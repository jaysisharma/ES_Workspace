import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/attendance_entity.dart';

class AttendanceModel extends AttendanceEntity {
  const AttendanceModel({
    required super.id,
    required super.staffId,
    required super.staffName,
    required super.eventId,
    required super.eventTitle,
    required super.orderId,
    required super.date,
    required super.checkInTime,
    super.checkOutTime,
    super.status = AttendanceStatus.present,
    super.checkInSelfieUrl,
    super.checkOutSelfieUrl,
    super.checkInLatitude,
    super.checkInLongitude,
    super.checkInAddress,
    super.checkOutLatitude,
    super.checkOutLongitude,
    super.checkOutAddress,
    super.notes,
    super.verifiedByQr = false,
    super.isWithinGeofence = true,
    super.distanceToVenueMeters,
    required super.createdAt,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json, [String? docId]) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }

    return AttendanceModel(
      id: docId ?? (json['id'] as String? ?? ''),
      staffId: json['staffId'] as String? ?? '',
      staffName: json['staffName'] as String? ?? '',
      eventId: json['eventId'] as String? ?? '',
      eventTitle: json['eventTitle'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
      date: parseDateTime(json['date']),
      checkInTime: parseDateTime(json['checkInTime']),
      checkOutTime: json['checkOutTime'] != null ? parseDateTime(json['checkOutTime']) : null,
      status: json['status'] != null ? AttendanceStatus.fromString(json['status'] as String) : AttendanceStatus.present,
      checkInSelfieUrl: json['checkInSelfieUrl'] as String?,
      checkOutSelfieUrl: json['checkOutSelfieUrl'] as String?,
      checkInLatitude: (json['checkInLatitude'] as num?)?.toDouble(),
      checkInLongitude: (json['checkInLongitude'] as num?)?.toDouble(),
      checkInAddress: json['checkInAddress'] as String?,
      checkOutLatitude: (json['checkOutLatitude'] as num?)?.toDouble(),
      checkOutLongitude: (json['checkOutLongitude'] as num?)?.toDouble(),
      checkOutAddress: json['checkOutAddress'] as String?,
      notes: json['notes'] as String?,
      verifiedByQr: json['verifiedByQr'] as bool? ?? false,
      isWithinGeofence: json['isWithinGeofence'] as bool? ?? true,
      distanceToVenueMeters: (json['distanceToVenueMeters'] as num?)?.toDouble(),
      createdAt: parseDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staffId': staffId,
      'staffName': staffName,
      'eventId': eventId,
      'eventTitle': eventTitle,
      'orderId': orderId,
      'date': Timestamp.fromDate(date),
      'checkInTime': Timestamp.fromDate(checkInTime),
      'checkOutTime': checkOutTime != null ? Timestamp.fromDate(checkOutTime!) : null,
      'status': status.name,
      'checkInSelfieUrl': checkInSelfieUrl,
      'checkOutSelfieUrl': checkOutSelfieUrl,
      'checkInLatitude': checkInLatitude,
      'checkInLongitude': checkInLongitude,
      'checkInAddress': checkInAddress,
      'checkOutLatitude': checkOutLatitude,
      'checkOutLongitude': checkOutLongitude,
      'checkOutAddress': checkOutAddress,
      'notes': notes,
      'verifiedByQr': verifiedByQr,
      'isWithinGeofence': isWithinGeofence,
      'distanceToVenueMeters': distanceToVenueMeters,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory AttendanceModel.fromEntity(AttendanceEntity entity) {
    return AttendanceModel(
      id: entity.id,
      staffId: entity.staffId,
      staffName: entity.staffName,
      eventId: entity.eventId,
      eventTitle: entity.eventTitle,
      orderId: entity.orderId,
      date: entity.date,
      checkInTime: entity.checkInTime,
      checkOutTime: entity.checkOutTime,
      status: entity.status,
      checkInSelfieUrl: entity.checkInSelfieUrl,
      checkOutSelfieUrl: entity.checkOutSelfieUrl,
      checkInLatitude: entity.checkInLatitude,
      checkInLongitude: entity.checkInLongitude,
      checkInAddress: entity.checkInAddress,
      checkOutLatitude: entity.checkOutLatitude,
      checkOutLongitude: entity.checkOutLongitude,
      checkOutAddress: entity.checkOutAddress,
      notes: entity.notes,
      verifiedByQr: entity.verifiedByQr,
      isWithinGeofence: entity.isWithinGeofence,
      distanceToVenueMeters: entity.distanceToVenueMeters,
      createdAt: entity.createdAt,
    );
  }
}
