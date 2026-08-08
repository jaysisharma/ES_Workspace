import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:order_app/domain/entities/revision_entity.dart';

class RevisionModel extends RevisionEntity {
  const RevisionModel({
    required super.id,
    required super.orderId,
    required super.message,
    required super.changedBy,
    required super.createdAt,
  });

  factory RevisionModel.fromJson(Map<String, dynamic> json) {
    return RevisionModel(
      id: json['id'] as String,
      orderId: json['orderId'] as String,
      message: json['message'] as String,
      changedBy: json['changedBy'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'message': message,
      'changedBy': changedBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory RevisionModel.fromEntity(RevisionEntity entity) {
    return RevisionModel(
      id: entity.id,
      orderId: entity.orderId,
      message: entity.message,
      changedBy: entity.changedBy,
      createdAt: entity.createdAt,
    );
  }
}
