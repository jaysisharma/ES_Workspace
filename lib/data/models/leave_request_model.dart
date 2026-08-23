import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:order_app/domain/entities/leave_request_entity.dart';

class LeaveRequestModel extends LeaveRequestEntity {
  LeaveRequestModel({
    required super.id,
    required super.staffId,
    required super.staffName,
    required super.startDate,
    required super.endDate,
    required super.leaveType,
    required super.reason,
    super.status = LeaveStatus.pending,
    super.reviewedBy,
    super.reviewedAt,
    required super.createdAt,
  });

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.now();
  }

  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      if (value.trim().isEmpty) return null;
      return DateTime.tryParse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return LeaveRequestModel(
      id: json['id']?.toString() ?? '',
      staffId: json['staffId']?.toString() ?? '',
      staffName: json['staffName']?.toString() ?? '',
      startDate: _parseDateTime(json['startDate']),
      endDate: _parseDateTime(json['endDate']),
      leaveType: json['leaveType']?.toString() ?? 'General',
      reason: json['reason']?.toString() ?? '',
      status: LeaveStatus.fromString(json['status']?.toString() ?? 'pending'),
      reviewedBy: json['reviewedBy']?.toString(),
      reviewedAt: _parseNullableDateTime(json['reviewedAt']),
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staffId': staffId,
      'staffName': staffName,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'leaveType': leaveType,
      'reason': reason,
      'status': status.name,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewedAt != null) 'reviewedAt': reviewedAt!.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LeaveRequestModel.fromEntity(LeaveRequestEntity entity) {
    return LeaveRequestModel(
      id: entity.id,
      staffId: entity.staffId,
      staffName: entity.staffName,
      startDate: entity.startDate,
      endDate: entity.endDate,
      leaveType: entity.leaveType,
      reason: entity.reason,
      status: entity.status,
      reviewedBy: entity.reviewedBy,
      reviewedAt: entity.reviewedAt,
      createdAt: entity.createdAt,
    );
  }
}
