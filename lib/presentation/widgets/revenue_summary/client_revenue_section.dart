import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_app/core/utils/currency_formatter.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';

class ClientRevenueSection extends StatelessWidget {
  final List<OrderItemEntity> allItems;
  final Map<String, TextEditingController> rateControllers;
  final String currencyLabel;
  final double currentTotalRevenue;
  final double totalExpenses;
  final double grandTotal;
  final VoidCallback onRateChanged;

  const ClientRevenueSection({
    super.key,
    required this.allItems,
    required this.rateControllers,
    required this.currencyLabel,
    required this.currentTotalRevenue,
    required this.totalExpenses,
    required this.grandTotal,
    required this.onRateChanged,
  });

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
            Icon(Icons.payments, color: colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'CLIENT REVENUE',
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
              // Table header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: borderColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        'ITEM DESCRIPTION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: labelColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'QTY',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: labelColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'RATE ($currencyLabel)',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: labelColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'LINE TOTAL',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: labelColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Real items from order items
              if (allItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 32,
                          color: labelColor.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No items found. Load items from an order.',
                          style: TextStyle(color: labelColor, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...allItems.asMap().entries.map((entry) {
                  final item = entry.value;
                  final isLast = entry.key == allItems.length - 1;
                  final ctrl = rateControllers[item.id]!;
                  final rateVal = double.tryParse(ctrl.text) ?? 0.0;
                  final double lineTotal;
                  if (item.billingType == 'event') {
                    lineTotal = rateVal * item.quantity;
                  } else {
                    lineTotal = rateVal * item.quantity * item.days;
                  }

                  return Column(
                    children: [
                      _buildRevenueItem(
                        context: context,
                        title: item.itemName,
                        subtitle: item.specification.isNotEmpty
                            ? item.specification
                            : (item.billingType == 'event'
                                ? 'Event Based'
                                : '${item.days} Day(s)'),
                        qty: '${item.quantity}',
                        rateController: ctrl,
                        lineTotal:
                            '$currencyLabel ${NumberFormat('#,##0.00').format(lineTotal)}',
                        onChanged: onRateChanged,
                      ),
                      if (!isLast)
                        Divider(
                          color: borderColor.withValues(alpha: 0.5),
                          height: 1,
                        ),
                    ],
                  );
                }),

              // Footer summary
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.02),
                  border: Border(
                    top: BorderSide(color: borderColor.withValues(alpha: 0.5)),
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow(
                      'Total Revenue',
                      CurrencyFormatter.formatWithLabel(
                        currentTotalRevenue,
                        currencyLabel,
                      ),
                      labelColor,
                      colorScheme.onSurface,
                      false,
                    ),
                    const SizedBox(height: 10),
                    _buildSummaryRow(
                      'Total Expenses',
                      CurrencyFormatter.formatWithLabel(
                        totalExpenses,
                        currencyLabel,
                      ),
                      labelColor,
                      roseColor,
                      false,
                    ),
                    const SizedBox(height: 16),
                    Divider(color: borderColor.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Grand Total',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              CurrencyFormatter.formatWithLabel(
                                grandTotal,
                                currencyLabel,
                              ),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildRevenueItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String qty,
    required TextEditingController rateController,
    required String lineTotal,
    required VoidCallback onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;
    final borderColor = colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: labelColor),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              qty,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                controller: rateController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => onChanged(),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 0,
                  ),
                  filled: true,
                  fillColor: colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: borderColor.withValues(alpha: 0.5),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: borderColor.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              lineTotal,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color labelColor,
    Color valueColor,
    bool isBold,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: labelColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
