class OrderItemEntity {
  final String id;
  final String orderId;
  final String itemName;
  final String specification;
  final int quantity;
  final String unit;
  final int days;
  final String vendor;
  final String billingType; // 'daily' or 'event'
  final double rate;
  final double amount;
  final double vendorRate;
  final double vendorAmount;
  final bool isCompleted;
  final String? assignedStaffId;
  final String? assignedStaffName;
  final String? vendorBillUrl;
  final String? vendorBillPath;
  final String? vendorBillName;

  const OrderItemEntity({
    required this.id,
    required this.orderId,
    required this.itemName,
    required this.specification,
    required this.quantity,
    required this.unit,
    required this.days,
    required this.vendor,
    this.billingType = 'daily',
    this.rate = 0.0,
    this.amount = 0.0,
    this.vendorRate = 0.0,
    this.vendorAmount = 0.0,
    this.isCompleted = false,
    this.assignedStaffId,
    this.assignedStaffName,
    this.vendorBillUrl,
    this.vendorBillPath,
    this.vendorBillName,
  });

  bool get hasVendorBill => vendorBillUrl != null && vendorBillUrl!.isNotEmpty;

  OrderItemEntity copyWith({
    String? id,
    String? orderId,
    String? itemName,
    String? specification,
    int? quantity,
    String? unit,
    int? days,
    String? vendor,
    String? billingType,
    double? rate,
    double? amount,
    double? vendorRate,
    double? vendorAmount,
    bool? isCompleted,
    String? assignedStaffId,
    String? assignedStaffName,
    bool clearAssignedStaff = false,
    String? vendorBillUrl,
    String? vendorBillPath,
    String? vendorBillName,
    bool clearVendorBill = false,
  }) {
    return OrderItemEntity(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      itemName: itemName ?? this.itemName,
      specification: specification ?? this.specification,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      days: days ?? this.days,
      vendor: vendor ?? this.vendor,
      billingType: billingType ?? this.billingType,
      rate: rate ?? this.rate,
      amount: amount ?? this.amount,
      vendorRate: vendorRate ?? this.vendorRate,
      vendorAmount: vendorAmount ?? this.vendorAmount,
      isCompleted: isCompleted ?? this.isCompleted,
      assignedStaffId: clearAssignedStaff ? null : (assignedStaffId ?? this.assignedStaffId),
      assignedStaffName: clearAssignedStaff ? null : (assignedStaffName ?? this.assignedStaffName),
      vendorBillUrl: clearVendorBill ? null : (vendorBillUrl ?? this.vendorBillUrl),
      vendorBillPath: clearVendorBill ? null : (vendorBillPath ?? this.vendorBillPath),
      vendorBillName: clearVendorBill ? null : (vendorBillName ?? this.vendorBillName),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is OrderItemEntity &&
        other.id == id &&
        other.orderId == orderId &&
        other.itemName == itemName &&
        other.specification == specification &&
        other.quantity == quantity &&
        other.unit == unit &&
        other.days == days &&
        other.vendor == vendor &&
        other.billingType == billingType &&
        other.rate == rate &&
        other.amount == amount &&
        other.vendorRate == vendorRate &&
        other.vendorAmount == vendorAmount &&
        other.isCompleted == isCompleted &&
        other.assignedStaffId == assignedStaffId &&
        other.assignedStaffName == assignedStaffName &&
        other.vendorBillUrl == vendorBillUrl &&
        other.vendorBillPath == vendorBillPath &&
        other.vendorBillName == vendorBillName;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        orderId.hashCode ^
        itemName.hashCode ^
        specification.hashCode ^
        quantity.hashCode ^
        unit.hashCode ^
        days.hashCode ^
        vendor.hashCode ^
        billingType.hashCode ^
        rate.hashCode ^
        amount.hashCode ^
        vendorRate.hashCode ^
        vendorAmount.hashCode ^
        isCompleted.hashCode ^
        assignedStaffId.hashCode ^
        assignedStaffName.hashCode ^
        vendorBillUrl.hashCode ^
        vendorBillPath.hashCode ^
        vendorBillName.hashCode;
  }
}
