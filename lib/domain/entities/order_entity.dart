enum OrderStatus { draft, confirmed, inProgress, completed, locked }

class OrderLogEntity {
  final DateTime timestamp;
  final String message;

  const OrderLogEntity({required this.timestamp, required this.message});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderLogEntity &&
          other.timestamp == timestamp &&
          other.message == message;

  @override
  int get hashCode => timestamp.hashCode ^ message.hashCode;
}

class OrderEntity {
  final String id;
  final String eventName;
  final DateTime eventDate;
  final DateTime? eventEndDate;
  final DateTime setupDate;
  final DateTime? setupEndDate;
  final String venue;
  final String contactPerson;
  final String contactNumber;
  final String notes;
  final OrderStatus status;
  final List<String> assignedStaffIds;
  final double totalAmount;
  final double totalExpenses;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderLogEntity> logs;
  final String category;
  final String client;
  final String description;
  final double vatRate;
  final bool isArchived;
  final double advanceReceived;
  final String advanceReferenceNo;
  final double managementCharge;
  final bool isMgtChargePercent;
  final double discount;
  final bool isDiscountPercent;

  const OrderEntity({
    required this.id,
    required this.eventName,
    required this.eventDate,
    this.eventEndDate,
    required this.setupDate,
    this.setupEndDate,
    required this.venue,
    required this.contactPerson,
    required this.contactNumber,
    required this.notes,
    required this.status,
    required this.assignedStaffIds,
    this.totalAmount = 0.0,
    this.totalExpenses = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.logs = const [],
    this.category = '',
    this.client = '',
    this.description = '',
    this.vatRate = 0.0,
    this.isArchived = false,
    this.advanceReceived = 0.0,
    this.advanceReferenceNo = '',
    this.managementCharge = 0.0,
    this.isMgtChargePercent = true,
    this.discount = 0.0,
    this.isDiscountPercent = true,
  });

  OrderEntity copyWith({
    String? eventName,
    DateTime? eventDate,
    DateTime? eventEndDate,
    DateTime? setupDate,
    DateTime? setupEndDate,
    String? venue,
    String? contactPerson,
    String? contactNumber,
    String? notes,
    OrderStatus? status,
    List<String>? assignedStaffIds,
    double? totalAmount,
    double? totalExpenses,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<OrderLogEntity>? logs,
    String? category,
    String? client,
    String? description,
    double? vatRate,
    bool? isArchived,
    double? advanceReceived,
    String? advanceReferenceNo,
    double? managementCharge,
    bool? isMgtChargePercent,
    double? discount,
    bool? isDiscountPercent,
  }) {
    return OrderEntity(
      id: id,
      eventName: eventName ?? this.eventName,
      eventDate: eventDate ?? this.eventDate,
      eventEndDate: eventEndDate ?? this.eventEndDate,
      setupDate: setupDate ?? this.setupDate,
      setupEndDate: setupEndDate ?? this.setupEndDate,
      venue: venue ?? this.venue,
      contactPerson: contactPerson ?? this.contactPerson,
      contactNumber: contactNumber ?? this.contactNumber,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      assignedStaffIds: assignedStaffIds ?? this.assignedStaffIds,
      totalAmount: totalAmount ?? this.totalAmount,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      logs: logs ?? this.logs,
      category: category ?? this.category,
      client: client ?? this.client,
      description: description ?? this.description,
      vatRate: vatRate ?? this.vatRate,
      isArchived: isArchived ?? this.isArchived,
      advanceReceived: advanceReceived ?? this.advanceReceived,
      advanceReferenceNo: advanceReferenceNo ?? this.advanceReferenceNo,
      managementCharge: managementCharge ?? this.managementCharge,
      isMgtChargePercent: isMgtChargePercent ?? this.isMgtChargePercent,
      discount: discount ?? this.discount,
      isDiscountPercent: isDiscountPercent ?? this.isDiscountPercent,
    );
  }

  double get totalWithVat => totalAmount * (1 + vatRate);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is OrderEntity &&
        other.id == id &&
        other.eventName == eventName &&
        other.eventDate == eventDate &&
        other.eventEndDate == eventEndDate &&
        other.setupDate == setupDate &&
        other.setupEndDate == setupEndDate &&
        other.venue == venue &&
        other.contactPerson == contactPerson &&
        other.contactNumber == contactNumber &&
        other.notes == notes &&
        other.status == status &&
        other.assignedStaffIds.length == assignedStaffIds.length &&
        other.totalAmount == totalAmount &&
        other.totalExpenses == totalExpenses &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.category == category &&
        other.client == client &&
        other.description == description &&
        other.advanceReceived == advanceReceived &&
        other.advanceReferenceNo == advanceReferenceNo &&
        other.managementCharge == managementCharge &&
        other.isMgtChargePercent == isMgtChargePercent &&
        other.discount == discount &&
        other.isDiscountPercent == isDiscountPercent;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        eventName.hashCode ^
        eventDate.hashCode ^
        eventEndDate.hashCode ^
        setupDate.hashCode ^
        setupEndDate.hashCode ^
        venue.hashCode ^
        contactPerson.hashCode ^
        contactNumber.hashCode ^
        notes.hashCode ^
        status.hashCode ^
        assignedStaffIds.hashCode ^
        totalAmount.hashCode ^
        totalExpenses.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        category.hashCode ^
        client.hashCode ^
        description.hashCode ^
        advanceReceived.hashCode ^
        advanceReferenceNo.hashCode ^
        managementCharge.hashCode ^
        isMgtChargePercent.hashCode ^
        discount.hashCode ^
        isDiscountPercent.hashCode;
  }
}
