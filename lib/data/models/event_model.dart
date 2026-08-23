import 'package:cloud_firestore/cloud_firestore.dart';
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

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final date = _parseDateTime(json['date']);
    final createdDate = json['createdAt'] != null
        ? _parseDateTime(json['createdAt'])
        : date;
    final isArchived = json['isArchived'] as bool? ?? false;

    return EventModel(
      id: json['id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      date: date,
      location: json['location']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      completion: (json['completion'] as num?)?.toDouble() ?? 0.0,
      assignedStaffId: json['assignedStaffId']?.toString(),
      color: json['color'] != null && json['color'] is int ? Color(json['color'] as int) : null,
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
