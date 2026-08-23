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
    super.managementCharge = 0.0,
    super.isMgtChargePercent = true,
    super.discount = 0.0,
    super.isDiscountPercent = true,
    super.orderType = 'Event',
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final createdAtDate = _parseDateTime(json['createdAt'] as String);
    final isArchived = json['isArchived'] as bool? ?? false;
    final orderType = json['orderType'] as String? ??
        json['type'] as String? ??
        'Event';

    return OrderModel(
      id: json['id'] as String,
      eventName: json['eventName'] as String,
      eventDate: _parseDateTime(json['eventDate'] as String),
      eventEndDate: json['eventEndDate'] != null
          ? _parseDateTime(json['eventEndDate'] as String)
          : null,
      setupDate: _parseDateTime(json['setupDate'] as String),
      setupEndDate: json['setupEndDate'] != null
          ? _parseDateTime(json['setupEndDate'] as String)
          : null,
      venue: json['venue'] as String,
      contactPerson: json['contactPerson'] as String,
      contactNumber: json['contactNumber'] as String,
      notes: json['notes'] as String? ?? '',
      status: _parseStatus(json['status'] as String?),
      assignedStaffIds: List<String>.from(json['assignedStaffIds'] ?? []),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      totalExpenses: (json['totalExpenses'] as num?)?.toDouble() ?? 0.0,
      createdAt: createdAtDate,
      updatedAt: _parseDateTime(json['updatedAt'] as String),
      logs:
          (json['logs'] as List<dynamic>?)
              ?.map((log) => _parseLog(log as Map<String, dynamic>))
              .toList() ??
          [],
      category: json['category'] as String? ?? '',
      client: json['client'] as String? ?? '',
      description: json['description'] as String? ?? '',
      vatRate: (json['vatRate'] as num?)?.toDouble() ?? 0.0,
      isArchived: isArchived,
      advanceReceived: (json['advanceReceived'] as num?)?.toDouble() ?? 0.0,
      advanceReferenceNo: json['advanceReferenceNo'] as String? ?? '',
      advanceReceiptUrl: json['advanceReceiptUrl'] as String? ?? '',
      advanceReceiptPath: json['advanceReceiptPath'] as String? ?? '',
      advanceReceiptName: json['advanceReceiptName'] as String? ?? '',
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
      timestamp: _parseDateTime(json['timestamp'] as String),
      message: json['message'] as String,
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
  static DateTime _parseDateTime(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      // Fallback in case of formatting issues
      return DateTime.now();
    }
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
      managementCharge: entity.managementCharge,
      isMgtChargePercent: entity.isMgtChargePercent,
      discount: entity.discount,
      isDiscountPercent: entity.isDiscountPercent,
      orderType: entity.orderType,
    );
  }
}
