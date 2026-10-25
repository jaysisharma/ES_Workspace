import 'package:flutter/foundation.dart';

@immutable
class InventoryItemEntity {
  final String id;
  final String itemNo;
  final String category;
  final String name;
  final String specification;
  final int quantity;
  final int availableQuantity;
  final double rate;
  final String status; // Available, Low Stock, Out of Stock, Maintenance
  final String location;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const InventoryItemEntity({
    required this.id,
    required this.name,
    this.itemNo = '',
    this.category = 'General',
    this.specification = '',
    this.quantity = 0,
    this.availableQuantity = 0,
    this.rate = 0.0,
    this.status = 'Available',
    this.location = 'Warehouse',
    this.createdAt,
    this.updatedAt,
  });

  /// Total calculated as Quantity * Rate
  double get total => quantity * rate;

  // Backward compatibility getters
  String get sku => itemNo;
  String get description => specification;
  int get totalQuantity => quantity;
  double get rentalRatePerDay => rate;

  bool get isLowStock => availableQuantity > 0 && availableQuantity <= 3;
  bool get isOutOfStock => availableQuantity <= 0;

  InventoryItemEntity copyWith({
    String? id,
    String? name,
    String? itemNo,
    String? sku,
    String? category,
    String? specification,
    String? description,
    int? quantity,
    int? totalQuantity,
    int? availableQuantity,
    double? rate,
    double? rentalRatePerDay,
    String? status,
    String? location,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final effectiveItemNo = itemNo ?? sku ?? this.itemNo;
    final effectiveSpec = specification ?? description ?? this.specification;
    final effectiveQty = quantity ?? totalQuantity ?? this.quantity;
    final effectiveRate = rate ?? rentalRatePerDay ?? this.rate;

    return InventoryItemEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      itemNo: effectiveItemNo,
      category: category ?? this.category,
      specification: effectiveSpec,
      quantity: effectiveQty,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      rate: effectiveRate,
      status: status ?? this.status,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
