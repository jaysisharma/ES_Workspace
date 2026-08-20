class PaymentReceiptEntity {
  final String id;
  final String orderId;
  final double amount;
  final DateTime paymentDate;
  final String paymentMode; // 'Cash', 'Bank Transfer', 'Cheque', 'Fonepay / QR'
  final String referenceNo;
  final String notes;
  final String receivedBy;
  final DateTime createdAt;

  const PaymentReceiptEntity({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.paymentDate,
    this.paymentMode = 'Cash',
    this.referenceNo = '',
    this.notes = '',
    this.receivedBy = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'amount': amount,
      'paymentDate': paymentDate.toIso8601String(),
      'paymentMode': paymentMode,
      'referenceNo': referenceNo,
      'notes': notes,
      'receivedBy': receivedBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PaymentReceiptEntity.fromMap(Map<String, dynamic> map, String id) {
    return PaymentReceiptEntity(
      id: id,
      orderId: map['orderId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paymentDate: map['paymentDate'] != null
          ? DateTime.tryParse(map['paymentDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      paymentMode: map['paymentMode'] as String? ?? 'Cash',
      referenceNo: map['referenceNo'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      receivedBy: map['receivedBy'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
