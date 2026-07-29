import 'package:flutter/foundation.dart';

@immutable
class InventoryItemEntity {
  final String id;
  final String name;
  final String sku;
  final String category;
  final int totalQuantity;
  final int availableQuantity;
  final double rentalRatePerDay;
  final String status; // Available, Low Stock, Out of Stock, Maintenance
  final String location;
  final String description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const InventoryItemEntity({
    required this.id,
    required this.name,
    this.sku = '',
    this.category = 'General',
    this.totalQuantity = 0,
    this.availableQuantity = 0,
    this.rentalRatePerDay = 0.0,
    this.status = 'Available',
    this.location = 'Warehouse',
    this.description = '',
    this.createdAt,
    this.updatedAt,
  });

  bool get isLowStock => availableQuantity > 0 && availableQuantity <= 3;
  bool get isOutOfStock => availableQuantity <= 0;

  InventoryItemEntity copyWith({
    String? id,
    String? name,
    String? sku,
    String? category,
    int? totalQuantity,
    int? availableQuantity,
    double? rentalRatePerDay,
    String? status,
    String? location,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventoryItemEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      rentalRatePerDay: rentalRatePerDay ?? this.rentalRatePerDay,
      status: status ?? this.status,
      location: location ?? this.location,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
