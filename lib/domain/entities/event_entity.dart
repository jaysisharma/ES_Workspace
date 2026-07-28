import 'package:flutter/material.dart';

class EventEntity {
  final String id;
  final String title;
  final DateTime date;
  final String location;
  final String role;
  final String status;
  final double completion;
  final String orderId;
  final String? assignedStaffId;
  final Color? color;

  const EventEntity({
    required this.id,
    required this.orderId,
    required this.title,
    required this.date,
    required this.location,
    required this.role,
    required this.status,
    required this.completion,
    this.assignedStaffId,
    this.color,
  });

  EventEntity copyWith({
    String? id,
    String? orderId,
    String? title,
    DateTime? date,
    String? location,
    String? role,
    String? status,
    double? completion,
    String? assignedStaffId,
    Color? color,
  }) {
    return EventEntity(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      title: title ?? this.title,
      date: date ?? this.date,
      location: location ?? this.location,
      role: role ?? this.role,
      status: status ?? this.status,
      completion: completion ?? this.completion,
      assignedStaffId: assignedStaffId ?? this.assignedStaffId,
      color: color ?? this.color,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is EventEntity &&
        other.id == id &&
        other.orderId == orderId &&
        other.title == title &&
        other.date == date &&
        other.location == location &&
        other.role == role &&
        other.status == status &&
        other.completion == completion &&
        other.assignedStaffId == assignedStaffId &&
        other.color == color;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        orderId.hashCode ^
        title.hashCode ^
        date.hashCode ^
        location.hashCode ^
        role.hashCode ^
        status.hashCode ^
        completion.hashCode ^
        assignedStaffId.hashCode ^
        color.hashCode;
  }
}
