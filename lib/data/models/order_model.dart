import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:order_app/domain/entities/order_entity.dart';

class OrderModel extends OrderEntity {
  const OrderModel({
    required super.id,
    required super.eventName,
    required super.eventDate,
    super.eventEndDate,
    required super.setupDate,
    super.setupEndDate,
    required super.venue,
    required super.contactPerson,
    required super.contactNumber,
    required super.notes,
    required super.status,
    required super.assignedStaffIds,
    super.totalAmount = 0.0,
    super.totalExpenses = 0.0,
    required super.createdAt,
    required super.updatedAt,
    super.logs = const [],
    super.category = '',
    super.client = '',
    super.description = '',
    super.vatRate = 0.0,
    super.isArchived = false,
    super.advanceReceived = 0.0,
    super.advanceReferenceNo = '',
    super.advanceReceiptUrl = '',
    super.advanceReceiptPath = '',
    super.advanceReceiptName = '',
    super.finalBillUrl = '',
    super.finalBillPath = '',
    super.finalBillName = '',
    super.managementCharge = 0.0,
    super.isMgtChargePercent = true,
    super.discount = 0.0,
    super.isDiscountPercent = true,
    super.orderType = 'Event',
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final createdAtDate = _parseDateTime(json['createdAt']);
    final isArchived = json['isArchived'] as bool? ?? false;
    final orderType = json['orderType'] as String? ??
        json['type'] as String? ??
        'Event';

    return OrderModel(
      id: json['id']?.toString() ?? '',
      eventName: json['eventName']?.toString() ?? '',
      eventDate: _parseDateTime(json['eventDate']),
      eventEndDate: _parseNullableDateTime(json['eventEndDate']),
      setupDate: _parseDateTime(json['setupDate']),
      setupEndDate: _parseNullableDateTime(json['setupEndDate']),
      venue: json['venue']?.toString() ?? '',
      contactPerson: json['contactPerson']?.toString() ?? '',
      contactNumber: json['contactNumber']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      status: _parseStatus(json['status']?.toString()),
      assignedStaffIds: List<String>.from(json['assignedStaffIds'] ?? []),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      totalExpenses: (json['totalExpenses'] as num?)?.toDouble() ?? 0.0,
      createdAt: createdAtDate,
      updatedAt: _parseDateTime(json['updatedAt']),
      logs:
          (json['logs'] as List<dynamic>?)
              ?.map((log) => _parseLog(log is Map<String, dynamic> ? log : Map<String, dynamic>.from(log as Map)))
              .toList() ??
          [],
      category: json['category']?.toString() ?? '',
      client: json['client']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      vatRate: (json['vatRate'] as num?)?.toDouble() ?? 0.0,
      isArchived: isArchived,
      advanceReceived: (json['advanceReceived'] as num?)?.toDouble() ?? 0.0,
      advanceReferenceNo: json['advanceReferenceNo']?.toString() ?? '',
      advanceReceiptUrl: json['advanceReceiptUrl']?.toString() ?? '',
      advanceReceiptPath: json['advanceReceiptPath']?.toString() ?? '',
      advanceReceiptName: json['advanceReceiptName']?.toString() ?? '',
      finalBillUrl: json['finalBillUrl']?.toString() ?? '',
      finalBillPath: json['finalBillPath']?.toString() ?? '',
      finalBillName: json['finalBillName']?.toString() ?? '',
      managementCharge: (json['managementCharge'] as num?)?.toDouble() ?? 0.0,
      isMgtChargePercent: json['isMgtChargePercent'] as bool? ?? true,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      isDiscountPercent: json['isDiscountPercent'] as bool? ?? true,
      orderType: orderType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventName': eventName,
      'eventDate': eventDate.toIso8601String(),
      'eventEndDate': eventEndDate?.toIso8601String(),
      'setupDate': setupDate.toIso8601String(),
      'setupEndDate': setupEndDate?.toIso8601String(),
      'venue': venue,
      'contactPerson': contactPerson,
      'contactNumber': contactNumber,
      'notes': notes,
      'status': status.name,
      'assignedStaffIds': assignedStaffIds,
      'totalAmount': totalAmount,
      'totalExpenses': totalExpenses,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'category': category,
      'client': client,
      'description': description,
      'vatRate': vatRate,
      'isArchived': isArchived,
      'advanceReceived': advanceReceived,
      'advanceReferenceNo': advanceReferenceNo,
      'advanceReceiptUrl': advanceReceiptUrl,
      'advanceReceiptPath': advanceReceiptPath,
      'advanceReceiptName': advanceReceiptName,
      'finalBillUrl': finalBillUrl,
      'finalBillPath': finalBillPath,
      'finalBillName': finalBillName,
      'managementCharge': managementCharge,
      'isMgtChargePercent': isMgtChargePercent,
      'discount': discount,
      'isDiscountPercent': isDiscountPercent,
      'orderType': orderType,
      'type': orderType,
      'logs': logs
          .map(
            (log) => {
              'timestamp': log.timestamp.toIso8601String(),
              'message': log.message,
            },
          )
          .toList(),
    };
  }

  static OrderLogEntity _parseLog(Map<String, dynamic> json) {
    return OrderLogEntity(
      timestamp: _parseDateTime(json['timestamp']),
      message: json['message']?.toString() ?? '',
    );
  }

  static OrderStatus _parseStatus(String? statusStr) {
    if (statusStr == null) return OrderStatus.draft;

    for (var value in OrderStatus.values) {
      if (value.name.toLowerCase() == statusStr.toLowerCase()) {
        return value;
      }
    }
    return OrderStatus.draft; // Default
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

  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      if (value.trim().isEmpty) return null;
      return DateTime.tryParse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  factory OrderModel.fromEntity(OrderEntity entity) {
    return OrderModel(
      id: entity.id,
      eventName: entity.eventName,
      eventDate: entity.eventDate,
      eventEndDate: entity.eventEndDate,
      setupDate: entity.setupDate,
      setupEndDate: entity.setupEndDate,
      venue: entity.venue,
      contactPerson: entity.contactPerson,
      contactNumber: entity.contactNumber,
      notes: entity.notes,
      status: entity.status,
      assignedStaffIds: entity.assignedStaffIds,
      totalAmount: entity.totalAmount,
      totalExpenses: entity.totalExpenses,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      logs: entity.logs,
      category: entity.category,
      client: entity.client,
      description: entity.description,
      vatRate: entity.vatRate,
      isArchived: entity.isArchived,
      advanceReceived: entity.advanceReceived,
      advanceReferenceNo: entity.advanceReferenceNo,
      advanceReceiptUrl: entity.advanceReceiptUrl,
      advanceReceiptPath: entity.advanceReceiptPath,
      advanceReceiptName: entity.advanceReceiptName,
      finalBillUrl: entity.finalBillUrl,
      finalBillPath: entity.finalBillPath,
      finalBillName: entity.finalBillName,
      managementCharge: entity.managementCharge,
      isMgtChargePercent: entity.isMgtChargePercent,
      discount: entity.discount,
      isDiscountPercent: entity.isDiscountPercent,
      orderType: entity.orderType,
    );
  }
}
