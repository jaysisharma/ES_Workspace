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

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String,
      orderId: json['orderId'] as String,
      description: json['description'] as String,
      specification: json['specification'] as String? ?? '',
      unit: json['unit'] as String? ?? 'Pcs',
      amount: (json['amount'] as num).toDouble(),
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as int? ?? 1,
      days: json['days'] as int? ?? 1,
      billingType: json['billingType'] as String? ?? 'event',
      vendorId: json['vendorId'] as String?,
      vendorName: json['vendorName'] as String?,
      category: json['category'] as String? ?? 'Miscellaneous',
      createdAt: DateTime.parse(json['createdAt'] as String),
      billUrl: json['billUrl'] as String?,
      billPath: json['billPath'] as String?,
      billName: json['billName'] as String?,
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
