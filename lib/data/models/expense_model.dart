import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:order_app/domain/entities/expense_entity.dart';

class ExpenseModel extends ExpenseEntity {
  const ExpenseModel({
    required super.id,
    required super.orderId,
    required super.description,
    super.specification = '',
    super.unit = 'Pcs',
    required super.amount,
    super.rate = 0.0,
    super.quantity = 1,
    super.days = 1,
    super.billingType = 'event',
    super.vendorId,
    super.vendorName,
    required super.category,
    required super.createdAt,
    super.billUrl,
    super.billPath,
    super.billName,
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

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      specification: json['specification']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'Pcs',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      days: (json['days'] as num?)?.toInt() ?? 1,
      billingType: json['billingType']?.toString() ?? 'event',
      vendorId: json['vendorId']?.toString(),
      vendorName: json['vendorName']?.toString(),
      category: json['category']?.toString() ?? 'Miscellaneous',
      createdAt: _parseDateTime(json['createdAt']),
      billUrl: json['billUrl']?.toString(),
      billPath: json['billPath']?.toString(),
      billName: json['billName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'description': description,
      'specification': specification,
      'unit': unit,
      'amount': amount,
      'rate': rate,
      'quantity': quantity,
      'days': days,
      'billingType': billingType,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'billUrl': billUrl,
      'billPath': billPath,
      'billName': billName,
    };
  }

  factory ExpenseModel.fromEntity(ExpenseEntity entity) {
    return ExpenseModel(
      id: entity.id,
      orderId: entity.orderId,
      description: entity.description,
      specification: entity.specification,
      unit: entity.unit,
      amount: entity.amount,
      rate: entity.rate,
      quantity: entity.quantity,
      days: entity.days,
      billingType: entity.billingType,
      vendorId: entity.vendorId,
      vendorName: entity.vendorName,
      category: entity.category,
      createdAt: entity.createdAt,
      billUrl: entity.billUrl,
      billPath: entity.billPath,
      billName: entity.billName,
    );
  }
}
