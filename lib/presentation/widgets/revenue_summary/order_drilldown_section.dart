import 'package:flutter/material.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';

class OrderDrilldownSection extends StatelessWidget {
  final OrderEntity order;
  final List<OrderItemEntity> allItems;
  final Map<String, TextEditingController> rateControllers;
  final String currencyLabel;

  const OrderDrilldownSection({
    super.key,
    required this.order,
    required this.allItems,
    required this.rateControllers,
    required this.currencyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;
    final borderColor = colorScheme.outline;

    final emeraldColor = colorScheme.secondary;
    final roseColor = colorScheme.error;

    final orderItems = allItems.where((i) => i.orderId == order.id).toList();

    double orderRevenue = 0;
    for (var item in orderItems) {
      final rate =
          double.tryParse(rateControllers[item.id]?.text ?? '') ?? item.rate;
      if (item.billingType == 'event') {
        orderRevenue += rate * item.quantity;
      } else {
        orderRevenue += rate * item.quantity * item.days;
      }
    }

    final orderNetProfit = orderRevenue - order.totalExpenses;
    final orderMargin = orderItems.isNotEmpty && orderRevenue > 0
        ? (orderNetProfit / orderRevenue * 100)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.eventName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatNepaliDate(order.eventDate, 'MMM dd, yyyy'),
                      style: TextStyle(fontSize: 11, color: labelColor),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: order.status == OrderStatus.draft
                      ? Colors.orange.withValues(alpha: 0.1)
                      : colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  order.status.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: order.status == OrderStatus.draft
                        ? Colors.orange
                        : colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric(
                'Revenue',
                '$currencyLabel ${orderRevenue.toStringAsFixed(0)}',
                colorScheme.onSurface,
              ),
              _buildMiniMetric(
                'Expenses',
                '$currencyLabel ${order.totalExpenses.toStringAsFixed(0)}',
                roseColor,
              ),
              _buildMiniMetric(
                'Profit',
                '$currencyLabel ${orderNetProfit.toStringAsFixed(0)}',
                emeraldColor,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'MARGIN',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${orderMargin.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: emeraldColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
