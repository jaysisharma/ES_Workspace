class PurchaseOrderItemEntity {
  final String id;
  final String itemName;
  final String specification;
  final int quantity;
  final String unit;
  final int days;
  final String billingType; // 'daily' or 'event'
  final double rate;
  final double amount;

  const PurchaseOrderItemEntity({
    required this.id,
    required this.itemName,
    required this.specification,
    required this.quantity,
    this.unit = 'Pcs',
    required this.days,
    this.billingType = 'daily',
    required this.rate,
    required this.amount,
  });

  factory PurchaseOrderItemEntity.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItemEntity(
      id: json['id'] ?? '',
      itemName: json['itemName'] ?? '',
      specification: json['specification'] ?? '',
      quantity: json['quantity'] ?? 1,
      unit: json['unit'] ?? 'Pcs',
      days: json['days'] ?? 1,
      billingType: json['billingType'] ?? 'daily',
      rate: (json['rate'] ?? 0.0).toDouble(),
      amount: (json['amount'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'itemName': itemName,
      'specification': specification,
      'quantity': quantity,
      'unit': unit,
      'days': days,
      'billingType': billingType,
      'rate': rate,
      'amount': amount,
    };
  }
}

class PurchaseOrderEntity {
  final String id;
  final String poNumber;
  final String orderId; // Related Main Order ID
  final String vendorName;
  final String eventName;
  final String venue;
  final DateTime eventDate;
  final DateTime? eventEndDate;
  final DateTime setupDate;
  final DateTime? setupEndDate;
  final List<PurchaseOrderItemEntity> items;
  final double totalAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // draft, sent, etc.
  final double vatRate;

  const PurchaseOrderEntity({
    required this.id,
    required this.poNumber,
    required this.orderId,
    required this.vendorName,
    required this.eventName,
    required this.venue,
    required this.eventDate,
    this.eventEndDate,
    required this.setupDate,
    this.setupEndDate,
    required this.items,
    required this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
    this.status = 'draft',
    this.vatRate = 0.0,
  });

  factory PurchaseOrderEntity.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderEntity(
      id: json['id'] ?? '',
      poNumber: json['poNumber'] ?? '',
      orderId: json['orderId'] ?? '',
      vendorName: json['vendorName'] ?? '',
      eventName: json['eventName'] ?? '',
      venue: json['venue'] ?? '',
      eventDate: DateTime.parse(json['eventDate']),
      eventEndDate: json['eventEndDate'] != null
          ? DateTime.parse(json['eventEndDate'])
          : null,
      setupDate: DateTime.parse(json['setupDate']),
      setupEndDate: json['setupEndDate'] != null
          ? DateTime.parse(json['setupEndDate'])
          : null,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((i) => PurchaseOrderItemEntity.fromJson(i))
              .toList() ??
          [],
      totalAmount: (json['totalAmount'] ?? 0.0).toDouble(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      status: json['status'] ?? 'draft',
      vatRate: (json['vatRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'poNumber': poNumber,
      'orderId': orderId,
      'vendorName': vendorName,
      'eventName': eventName,
      'venue': venue,
      'eventDate': eventDate.toIso8601String(),
      'eventEndDate': eventEndDate?.toIso8601String(),
      'setupDate': setupDate.toIso8601String(),
      'setupEndDate': setupEndDate?.toIso8601String(),
      'items': items.map((i) => i.toJson()).toList(),
      'totalAmount': totalAmount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status,
      'vatRate': vatRate,
    };
  }

  PurchaseOrderEntity copyWith({
    String? poNumber,
    String? orderId,
    String? vendorName,
    String? eventName,
    String? venue,
    DateTime? eventDate,
    DateTime? eventEndDate,
    DateTime? setupDate,
    DateTime? setupEndDate,
    List<PurchaseOrderItemEntity>? items,
    double? totalAmount,
    DateTime? updatedAt,
    String? status,
    double? vatRate,
  }) {
    return PurchaseOrderEntity(
      id: id,
      poNumber: poNumber ?? this.poNumber,
      orderId: orderId ?? this.orderId,
      vendorName: vendorName ?? this.vendorName,
      eventName: eventName ?? this.eventName,
      venue: venue ?? this.venue,
      eventDate: eventDate ?? this.eventDate,
      eventEndDate: eventEndDate ?? this.eventEndDate,
      setupDate: setupDate ?? this.setupDate,
      setupEndDate: setupEndDate ?? this.setupEndDate,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      vatRate: vatRate ?? this.vatRate,
    );
  }

  double get totalWithVat => totalAmount * (1 + vatRate);
}
