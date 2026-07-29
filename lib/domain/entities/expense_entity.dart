class ExpenseEntity {
  final String id;
  final String orderId;
  final String description;
  final String specification;
  final String unit;
  final double amount;
  final double rate;
  final int quantity;
  final int days;
  final String billingType; // 'daily' or 'event'
  final String? vendorId;
  final String? vendorName;
  final String category; // 'Labour' or 'Transportation'
  final DateTime createdAt;
  final String? billUrl;
  final String? billPath;
  final String? billName;

  const ExpenseEntity({
    required this.id,
    required this.orderId,
    required this.description,
    this.specification = '',
    this.unit = 'Pcs',
    required this.amount,
    this.rate = 0.0,
    this.quantity = 1,
    this.days = 1,
    this.billingType = 'event',
    this.vendorId,
    this.vendorName,
    required this.category,
    required this.createdAt,
    this.billUrl,
    this.billPath,
    this.billName,
  });

  bool get hasBill => billUrl != null && billUrl!.isNotEmpty;

  ExpenseEntity copyWith({
    String? id,
    String? orderId,
    String? description,
    String? specification,
    String? unit,
    double? amount,
    double? rate,
    int? quantity,
    int? days,
    String? billingType,
    String? vendorId,
    String? vendorName,
    String? category,
    DateTime? createdAt,
    String? billUrl,
    String? billPath,
    String? billName,
  }) {
    return ExpenseEntity(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      description: description ?? this.description,
      specification: specification ?? this.specification,
      unit: unit ?? this.unit,
      amount: amount ?? this.amount,
      rate: rate ?? this.rate,
      quantity: quantity ?? this.quantity,
      days: days ?? this.days,
      billingType: billingType ?? this.billingType,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      billUrl: billUrl ?? this.billUrl,
      billPath: billPath ?? this.billPath,
      billName: billName ?? this.billName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          orderId == other.orderId &&
          description == other.description &&
          specification == other.specification &&
          unit == other.unit &&
          amount == other.amount &&
          rate == other.rate &&
          quantity == other.quantity &&
          days == other.days &&
          billingType == other.billingType &&
          vendorId == other.vendorId &&
          vendorName == other.vendorName &&
          category == other.category &&
          createdAt == other.createdAt &&
          billUrl == other.billUrl &&
          billPath == other.billPath &&
          billName == other.billName;

  @override
  int get hashCode =>
      id.hashCode ^
      orderId.hashCode ^
      description.hashCode ^
      specification.hashCode ^
      unit.hashCode ^
      amount.hashCode ^
      rate.hashCode ^
      quantity.hashCode ^
      days.hashCode ^
      billingType.hashCode ^
      vendorId.hashCode ^
      vendorName.hashCode ^
      category.hashCode ^
      createdAt.hashCode ^
      billUrl.hashCode ^
      billPath.hashCode ^
      billName.hashCode;
}
