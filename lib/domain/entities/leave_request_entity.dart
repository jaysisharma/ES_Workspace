enum LeaveStatus {
  pending,
  approved,
  rejected;

  String get displayName {
    switch (this) {
      case LeaveStatus.pending:
        return 'Pending';
      case LeaveStatus.approved:
        return 'Approved';
      case LeaveStatus.rejected:
        return 'Rejected';
    }
  }

  static LeaveStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'approved':
        return LeaveStatus.approved;
      case 'rejected':
        return LeaveStatus.rejected;
      default:
        return LeaveStatus.pending;
    }
  }
}

class LeaveRequestEntity {
  static const List<String> availableLeaveTypes = [
    'Casual Leave',
    'Sick Leave',
    'Maternity Leave',
    'Paternity Leave',
    'Mourning Leave',
    'Festive Leave',
  ];

  final String id;
  final String staffId;
  final String staffName;
  final DateTime startDate;
  final DateTime endDate;
  final String leaveType;
  final String reason;
  final LeaveStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  const LeaveRequestEntity({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.startDate,
    required this.endDate,
    required this.leaveType,
    required this.reason,
    this.status = LeaveStatus.pending,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
  });

  LeaveRequestEntity copyWith({
    String? id,
    String? staffId,
    String? staffName,
    DateTime? startDate,
    DateTime? endDate,
    String? leaveType,
    String? reason,
    LeaveStatus? status,
    String? reviewedBy,
    DateTime? reviewedAt,
    DateTime? createdAt,
  }) {
    return LeaveRequestEntity(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      leaveType: leaveType ?? this.leaveType,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
