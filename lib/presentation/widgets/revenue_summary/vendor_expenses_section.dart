import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_app/core/utils/currency_formatter.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';

class VendorExpensesSection extends StatelessWidget {
  final List<OrderItemEntity> allItems;
  final List<OrderEntity> filteredOrders;
  final double totalExpenses;
  final String currencyLabel;

  const VendorExpensesSection({
    super.key,
    required this.allItems,
    required this.filteredOrders,
    required this.totalExpenses,
    required this.currencyLabel,
  });

  Map<String, List<OrderItemEntity>> _groupByVendor(
    List<OrderItemEntity> items,
  ) {
    final Map<String, List<OrderItemEntity>> map = {};
    for (final item in items) {
      if (item.vendorAmount > 0) {
        map.putIfAbsent(item.vendor, () => []).add(item);
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;
    final borderColor = colorScheme.outline;
    final roseColor = colorScheme.error;

    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.shopping_cart, color: roseColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'VENDOR EXPENSES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: labelColor,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Group expenses by vendor from order items
              if (allItems.isEmpty || _groupByVendor(allItems).isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 32,
                          color: labelColor.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No vendor expense data available',
                          style: TextStyle(color: labelColor, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._groupByVendor(
                  allItems,
                ).entries.toList().asMap().entries.map((entry) {
                  final isLast =
                      entry.key == _groupByVendor(allItems).length - 1;
                  final vendor = entry.value.key;
                  final items = entry.value.value;
                  final vendorTotal = items.fold(
                    0.0,
                    (s, i) => s + i.vendorAmount,
                  );
                  return Column(
                    children: [
                      _buildExpenseVendor(
                        context: context,
                        vendor: vendor,
                        amount: CurrencyFormatter.formatWithLabel(
                          vendorTotal,
                          currencyLabel,
                        ),
                        items: items,
                        orders: filteredOrders,
                      ),
                      if (!isLast)
                        Divider(
                          color: borderColor.withValues(alpha: 0.5),
                          height: 1,
                        ),
                    ],
                  );
                }),

              // Expenses footer
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: roseColor.withValues(alpha: 0.05),
                  border: Border(
                    top: BorderSide(color: borderColor.withValues(alpha: 0.5)),
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL EXPENSES',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: roseColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '$currencyLabel ${NumberFormat('#,##0.00').format(totalExpenses)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: roseColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseVendor({
    required BuildContext context,
    required String vendor,
    required String amount,
    required List<OrderItemEntity> items,
    required List<OrderEntity> orders,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;
    final borderColor = colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.isEmpty ? 'Unknown Vendor' : vendor,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  amount,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...() {
              final itemsByOrder = <String, List<OrderItemEntity>>{};
              for (var i in items) {
                itemsByOrder.putIfAbsent(i.orderId, () => []).add(i);
              }

              return itemsByOrder.entries.map((orderEntry) {
                final order = orders
                        .where((o) => o.id == orderEntry.key)
                        .firstOrNull ??
                    OrderEntity(
                      id: orderEntry.key,
                      eventName: 'Unknown Order',
                      eventDate: DateTime.now(),
                      setupDate: DateTime.now(),
                      venue: '',
                      contactPerson: '',
                      contactNumber: '',
                      notes: '',
                      status: OrderStatus.draft,
                      assignedStaffIds: [],
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );

                final orderTotal = orderEntry.value.fold(
                  0.0,
                  (s, i) => s + i.vendorAmount,
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: borderColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              order.eventName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            CurrencyFormatter.format(orderTotal),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        orderEntry.value.map((i) => i.itemName).join(', '),
                        style: TextStyle(
                          fontSize: 11,
                          color: labelColor,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatNepaliDate(order.eventDate, 'MMM dd, yyyy'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            }(),
          ],
        ],
      ),
    );
  }
}
