import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:order_app/domain/entities/change_request_entity.dart';

class ChangeRequestModel extends ChangeRequestEntity {
  const ChangeRequestModel({
    required super.id,
    required super.orderId,
    required super.itemId,
    required super.requestedBy,
    required super.changeType,
    required super.description,
    super.status = ChangeStatus.pending,
    required super.createdAt,
  });

  factory ChangeRequestModel.fromJson(Map<String, dynamic> json) {
    return ChangeRequestModel(
      id: json['id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      itemId: json['itemId']?.toString() ?? '',
      requestedBy: json['requestedBy']?.toString() ?? '',
      changeType: json['changeType']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: _parseStatus(json['status']?.toString()),
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'itemId': itemId,
      'requestedBy': requestedBy,
      'changeType': changeType,
      'description': description,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static ChangeStatus _parseStatus(String? statusStr) {
    if (statusStr == null) return ChangeStatus.pending;

    for (var value in ChangeStatus.values) {
      if (value.name.toLowerCase() == statusStr.toLowerCase()) {
        return value;
      }
    }
    return ChangeStatus.pending; // Default
  }

  // DRY helper for DateTime parsing
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

  factory ChangeRequestModel.fromEntity(ChangeRequestEntity entity) {
    return ChangeRequestModel(
      id: entity.id,
      orderId: entity.orderId,
      itemId: entity.itemId,
      requestedBy: entity.requestedBy,
      changeType: entity.changeType,
      description: entity.description,
      status: entity.status,
      createdAt: entity.createdAt,
    );
  }
}
