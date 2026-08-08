import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/domain/entities/expense_entity.dart';
import 'order_providers.dart';

/// Provider to fetch all unique vendor names associated with a specific Order ID.
/// Checks both Order Items and Manual Expenses.
final vendorListProvider = FutureProvider.family<List<String>, String>((
  ref,
  orderId,
) async {
  final orderItemsAsync = ref.watch(allItemsStreamProvider);
  final manualExpensesAsync = await ref.watch(getExpensesUseCaseProvider)(
    orderId,
  );

  final List<String> vendors = [];

  // 1. Get vendors from Order Items
  orderItemsAsync.whenData((items) {
    for (final item in items) {
      if (item.orderId == orderId && item.vendor.isNotEmpty) {
        if (!vendors.contains(item.vendor)) {
          vendors.add(item.vendor);
        }
      }
    }
  });

  // 2. Get vendors from Manual Expenses
  for (final expense in manualExpensesAsync) {
    final name = expense.vendorName;
    if (name != null && name.isNotEmpty) {
      if (!vendors.contains(name)) {
        vendors.add(name);
      }
    }
  }

  vendors.sort();
  return vendors;
});

/// Data class to hold aggregated vendor expense details
class VendorExpenseDetails {
  final double totalAmount;
  final List<OrderItemEntity> items;
  final List<ExpenseEntity> manualExpenses;

  VendorExpenseDetails({
    required this.totalAmount,
    required this.items,
    required this.manualExpenses,
  });
}

/// Provider to fetch and aggregate all expenses for a specific vendor in a specific order.
final vendorExpensesProvider =
    FutureProvider.family<
      VendorExpenseDetails,
      ({String orderId, String vendorName})
    >((ref, arg) async {
      final orderItemsAsync = ref.watch(allItemsStreamProvider);
      final manualExpensesAsync = await ref.watch(getExpensesUseCaseProvider)(
        arg.orderId,
      );

      final List<OrderItemEntity> vendorItems = [];
      final List<ExpenseEntity> vendorManualExpenses = [];
      double total = 0.0;

      // 1. Filter Order Items
      orderItemsAsync.whenData((items) {
        for (final item in items) {
          if (item.orderId == arg.orderId && item.vendor == arg.vendorName) {
            vendorItems.add(item);
            total += item.vendorAmount;
          }
        }
      });

      // 2. Filter Manual Expenses
      for (final expense in manualExpensesAsync) {
        if (expense.vendorName == arg.vendorName) {
          vendorManualExpenses.add(expense);
          total += expense.amount;
        }
      }

      return VendorExpenseDetails(
        totalAmount: total,
        items: vendorItems,
        manualExpenses: vendorManualExpenses,
      );
    });
