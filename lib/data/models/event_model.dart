import 'package:flutter/material.dart';
import 'package:order_app/domain/entities/event_entity.dart';

class EventModel extends EventEntity {
  const EventModel({
    required super.id,
    required super.orderId,
    required super.title,
    required super.date,
    required super.location,
    required super.role,
    required super.status,
    required super.completion,
    super.assignedStaffId,
    super.color,
    super.isArchived = false,
    super.createdAt,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final createdDate = json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.parse(json['date'] as String)
        : DateTime.parse(json['date'] as String);
    final isArchived = json['isArchived'] as bool? ?? false;

    return EventModel(
      id: json['id'] as String,
      orderId: json['orderId'] as String,
      title: json['title'] as String,
      date: DateTime.parse(json['date'] as String),
      location: json['location'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
      completion: (json['completion'] as num).toDouble(),
      assignedStaffId: json['assignedStaffId'] as String?,
      color: json['color'] != null ? Color(json['color'] as int) : null,
      isArchived: isArchived,
      createdAt: createdDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'title': title,
      'date': date.toIso8601String(),
      'location': location,
      'role': role,
      'status': status,
      'completion': completion,
      'assignedStaffId': assignedStaffId,
      'color': color?.toARGB32(),
      'isArchived': isArchived,
      'createdAt': (createdAt ?? date).toIso8601String(),
    };
  }

  factory EventModel.fromEntity(EventEntity entity) {
    return EventModel(
      id: entity.id,
      orderId: entity.orderId,
      title: entity.title,
      date: entity.date,
      location: entity.location,
      role: entity.role,
      status: entity.status,
      completion: entity.completion,
      assignedStaffId: entity.assignedStaffId,
      color: entity.color,
      isArchived: entity.isArchived,
      createdAt: entity.createdAt,
    );
  }
}
