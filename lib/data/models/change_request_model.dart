import '../../domain/entities/change_request_entity.dart';

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
      id: json['id'] as String,
      orderId: json['orderId'] as String,
      itemId: json['itemId'] as String,
      requestedBy: json['requestedBy'] as String,
      changeType: json['changeType'] as String,
      description: json['description'] as String,
      status: _parseStatus(json['status'] as String?),
      createdAt: _parseDateTime(json['createdAt'] as String),
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
  static DateTime _parseDateTime(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      // Fallback in case of formatting issues
      return DateTime.now();
    }
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
