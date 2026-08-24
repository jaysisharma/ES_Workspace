import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';

class OrderItemModel extends OrderItemEntity {
  const OrderItemModel({
    required super.id,
    required super.orderId,
    required super.itemName,
    required super.specification,
    required super.quantity,
    required super.unit,
    required super.days,
    required super.vendor,
    super.billingType = 'daily',
    super.rate = 0.0,
    super.amount = 0.0,
    super.vendorRate = 0.0,
    super.vendorAmount = 0.0,
    super.isCompleted = false,
    super.assignedStaffId,
    super.assignedStaffName,
    super.vendorBillUrl,
    super.vendorBillPath,
    super.vendorBillName,
    super.dueDate,
    super.createdBy,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    DateTime? dueDate;
    final rawDue = json['dueDate'];
    if (rawDue is Timestamp) {
      dueDate = rawDue.toDate();
    } else if (rawDue is String && rawDue.isNotEmpty) {
      dueDate = DateTime.tryParse(rawDue);
    }

    bool isCompleted = false;
    final rawCompleted = json['isCompleted'];
    if (rawCompleted is bool) {
      isCompleted = rawCompleted;
    } else if (rawCompleted is String) {
      isCompleted = rawCompleted.toLowerCase() == 'true' || rawCompleted == '1';
    } else if (rawCompleted is num) {
      isCompleted = rawCompleted == 1;
    }

    return OrderItemModel(
      id: (json['id'] as String?)?.isNotEmpty == true
          ? json['id'] as String
          : (docId ?? ''),
      orderId: json['orderId'] as String? ?? 'manual',
      itemName: json['itemName'] as String? ?? '',
      specification: json['specification'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unit: json['unit'] as String? ?? 'task',
      days: (json['days'] as num?)?.toInt() ?? 1,
      vendor: json['vendor'] as String? ?? '',
      billingType: json['billingType'] as String? ?? 'daily',
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      vendorRate: (json['vendorRate'] as num?)?.toDouble() ?? 0.0,
      vendorAmount: (json['vendorAmount'] as num?)?.toDouble() ?? 0.0,
      isCompleted: isCompleted,
      assignedStaffId: json['assignedStaffId'] as String?,
      assignedStaffName: json['assignedStaffName'] as String?,
      vendorBillUrl: json['vendorBillUrl'] as String?,
      vendorBillPath: json['vendorBillPath'] as String?,
      vendorBillName: json['vendorBillName'] as String?,
      dueDate: dueDate,
      createdBy: json['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'itemName': itemName,
      'specification': specification,
      'quantity': quantity,
      'unit': unit,
      'days': days,
      'vendor': vendor,
      'billingType': billingType,
      'rate': rate,
      'amount': amount,
      'vendorRate': vendorRate,
      'vendorAmount': vendorAmount,
      'isCompleted': isCompleted,
      'assignedStaffId': assignedStaffId,
      'assignedStaffName': assignedStaffName,
      'vendorBillUrl': vendorBillUrl,
      'vendorBillPath': vendorBillPath,
      'vendorBillName': vendorBillName,
      'dueDate': dueDate?.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  factory OrderItemModel.fromEntity(OrderItemEntity entity) {
    return OrderItemModel(
      id: entity.id,
      orderId: entity.orderId,
      itemName: entity.itemName,
      specification: entity.specification,
      quantity: entity.quantity,
      unit: entity.unit,
      days: entity.days,
      vendor: entity.vendor,
      billingType: entity.billingType,
      rate: entity.rate,
      amount: entity.amount,
      vendorRate: entity.vendorRate,
      vendorAmount: entity.vendorAmount,
      isCompleted: entity.isCompleted,
      assignedStaffId: entity.assignedStaffId,
      assignedStaffName: entity.assignedStaffName,
      vendorBillUrl: entity.vendorBillUrl,
      vendorBillPath: entity.vendorBillPath,
      vendorBillName: entity.vendorBillName,
      dueDate: entity.dueDate,
      createdBy: entity.createdBy,
    );
  }
}
