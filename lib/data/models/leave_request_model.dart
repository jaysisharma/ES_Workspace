import '../../domain/entities/leave_request_entity.dart';

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

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return LeaveRequestModel(
      id: json['id'] as String,
      staffId: json['staffId'] as String,
      staffName: json['staffName'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      leaveType: json['leaveType'] as String? ?? 'General',
      reason: json['reason'] as String? ?? '',
      status: LeaveStatus.fromString(json['status'] as String? ?? 'pending'),
      reviewedBy: json['reviewedBy'] as String?,
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.parse(json['reviewedAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
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
