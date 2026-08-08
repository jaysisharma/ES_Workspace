// Lightweight data classes — only the fields needed for PDF rendering.
// Extracted from full entities before rendering so that complex entity objects are never needlessly copied.

class PdfItemData {
  final String itemName;
  final String specification;
  final int quantity;
  final String unit;
  final String billingType;
  final int days;
  final double rate;
  final double amount;
  final String vendor;
  final double vendorRate;
  final double vendorAmount;

  const PdfItemData({
    required this.itemName,
    required this.specification,
    required this.quantity,
    required this.unit,
    required this.billingType,
    required this.days,
    required this.rate,
    required this.amount,
    required this.vendor,
    required this.vendorRate,
    required this.vendorAmount,
  });
}

class PdfRevenueData {
  final String category;
  final String description;
  final double quantity;
  final String unit;
  final String billingType;
  final int days;
  final double rate;
  final double amount;
  final String vendorName;

  const PdfRevenueData({
    required this.category,
    required this.description,
    required this.quantity,
    this.unit = 'Pcs',
    required this.billingType,
    required this.days,
    required this.rate,
    required this.amount,
    required this.vendorName,
  });
}

class PdfExpenseData {
  final String category;
  final String description;
  final String specification;
  final int quantity;
  final String unit;
  final String billingType;
  final int days;
  final double rate;
  final double amount;
  final String vendorName;

  const PdfExpenseData({
    required this.category,
    required this.description,
    required this.specification,
    required this.quantity,
    required this.unit,
    required this.billingType,
    required this.days,
    required this.rate,
    required this.amount,
    required this.vendorName,
  });
}
