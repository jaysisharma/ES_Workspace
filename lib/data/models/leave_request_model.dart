import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:order_app/domain/entities/leave_request_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';

class LeaveRequestModel extends LeaveRequestEntity {
  LeaveRequestModel({
    required super.id,
    required super.staffId,
    required super.staffName,
    super.applicantRole = UserRole.staff,
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

  static UserRole _parseRole(String? roleStr) {
    if (roleStr == null) return UserRole.staff;
    final clean = roleStr
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('_', '')
        .replaceAll('-', '');
    switch (clean) {
      case 'superadmin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'director':
      case 'founder':
      case 'ceo':
        return UserRole.director;
      case 'companysecretary':
      case 'secretary':
        return UserRole.companySecretary;
      case 'seniorstaff':
        return UserRole.seniorStaff;
      case 'finance':
        return UserRole.finance;
      case 'staff':
      default:
        return UserRole.staff;
    }
  }

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return LeaveRequestModel(
      id: json['id']?.toString() ?? '',
      staffId: json['staffId']?.toString() ?? '',
      staffName: json['staffName']?.toString() ?? '',
      applicantRole: _parseRole(json['applicantRole']?.toString()),
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
      'applicantRole': applicantRole.name,
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
      applicantRole: entity.applicantRole,
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
