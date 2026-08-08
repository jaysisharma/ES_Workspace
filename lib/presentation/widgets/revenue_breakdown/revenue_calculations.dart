import 'package:flutter/material.dart';
import 'package:order_app/domain/entities/expense_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'revenue_financials_card.dart';

class RevenueCalculations {
  static double calculateItemTotal({
    required List<OrderItemEntity> items,
    required Map<String, TextEditingController> itemControllers,
    required Map<String, TextEditingController> itemQtyControllers,
    required Map<String, TextEditingController> itemDaysControllers,
  }) {
    double total = 0;
    for (var item in items) {
      final rate = double.tryParse(itemControllers[item.id]?.text ?? '') ?? 0.0;
      final qty = int.tryParse(itemQtyControllers[item.id]?.text ?? '') ?? item.quantity;
      final days = int.tryParse(itemDaysControllers[item.id]?.text ?? '') ?? item.days;
      if (item.billingType == 'event') {
        total += rate * qty;
      } else {
        total += rate * qty * days;
      }
    }
    return total;
  }

  static double calculateManualTotal(List<ExpenseEntity> manualRevenues) {
    return manualRevenues.fold(0, (sum, e) => sum + e.amount);
  }

  static double calculateManagementChargeAmount({
    required double totalRevenue,
    required String mgtChargeText,
    required bool isPercent,
  }) {
    final val = double.tryParse(mgtChargeText.trim()) ?? 0.0;
    if (val <= 0) return 0.0;
    return isPercent ? (totalRevenue * val / 100) : val;
  }

  static double calculateDiscountAmount({
    required double totalRevenue,
    required String discountText,
    required bool isPercent,
  }) {
    final val = double.tryParse(discountText.trim()) ?? 0.0;
    if (val <= 0) return 0.0;
    return isPercent ? (totalRevenue * val / 100) : val;
  }

  static double calculateNetTotal({
    required double totalRevenue,
    required double mgtChargeAmount,
    required double discountAmount,
  }) {
    final total = totalRevenue + mgtChargeAmount - discountAmount;
    return total < 0 ? 0.0 : total;
  }

  static double calculateEffectiveVatRate({
    required VatOption vatOption,
    required String customVatText,
  }) {
    switch (vatOption) {
      case VatOption.noVat:
        return 0.0;
      case VatOption.vat13:
        return 0.13;
      case VatOption.custom:
        final customVal = double.tryParse(customVatText.trim()) ?? 0.0;
        return customVal / 100;
    }
  }

  static double calculateVatAmount({
    required double netTotal,
    required double effectiveVatRate,
  }) {
    return netTotal * effectiveVatRate;
  }

  static double calculateGrandTotal({
    required double netTotal,
    required double vatAmount,
  }) {
    return netTotal + vatAmount;
  }
}
