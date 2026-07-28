class RevisionEntity {
  final String id;
  final String orderId;
  final String message;
  final String changedBy; // staffId or userId
  final DateTime createdAt;

  const RevisionEntity({
    required this.id,
    required this.orderId,
    required this.message,
    required this.changedBy,
    required this.createdAt,
  });

  RevisionEntity copyWith({
    String? id,
    String? orderId,
    String? message,
    String? changedBy,
    DateTime? createdAt,
  }) {
    return RevisionEntity(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      message: message ?? this.message,
      changedBy: changedBy ?? this.changedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RevisionEntity &&
        other.id == id &&
        other.orderId == orderId &&
        other.message == message &&
        other.changedBy == changedBy &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        orderId.hashCode ^
        message.hashCode ^
        changedBy.hashCode ^
        createdAt.hashCode;
  }
}
