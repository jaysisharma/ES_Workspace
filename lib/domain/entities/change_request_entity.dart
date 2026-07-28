enum ChangeStatus { pending, approved, rejected }

class ChangeRequestEntity {
  final String id;
  final String orderId;
  final String itemId;
  final String requestedBy; // staffId
  final String changeType;
  final String description;
  final ChangeStatus status;
  final DateTime createdAt;

  const ChangeRequestEntity({
    required this.id,
    required this.orderId,
    required this.itemId,
    required this.requestedBy,
    required this.changeType,
    required this.description,
    this.status = ChangeStatus.pending,
    required this.createdAt,
  });

  ChangeRequestEntity copyWith({
    String? id,
    String? orderId,
    String? itemId,
    String? requestedBy,
    String? changeType,
    String? description,
    ChangeStatus? status,
    DateTime? createdAt,
  }) {
    return ChangeRequestEntity(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      itemId: itemId ?? this.itemId,
      requestedBy: requestedBy ?? this.requestedBy,
      changeType: changeType ?? this.changeType,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChangeRequestEntity &&
        other.id == id &&
        other.orderId == orderId &&
        other.itemId == itemId &&
        other.requestedBy == requestedBy &&
        other.changeType == changeType &&
        other.description == description &&
        other.status == status &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        orderId.hashCode ^
        itemId.hashCode ^
        requestedBy.hashCode ^
        changeType.hashCode ^
        description.hashCode ^
        status.hashCode ^
        createdAt.hashCode;
  }
}
