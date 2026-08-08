import 'package:flutter/material.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';

class ExpenseItemCostsCardWidget extends StatelessWidget {
  final List<OrderItemEntity> items;
  final Map<String, TextEditingController> itemControllers;
  final Map<String, TextEditingController> itemQtyControllers;
  final Map<String, TextEditingController> itemDaysControllers;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color labelColor;
  final Color primaryColor;
  final String currencyLabel;
  final Function(int index, String billingType) onBillingTypeChanged;
  final VoidCallback onChanged;

  const ExpenseItemCostsCardWidget({
    super.key,
    required this.items,
    required this.itemControllers,
    required this.itemQtyControllers,
    required this.itemDaysControllers,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.labelColor,
    required this.primaryColor,
    required this.currencyLabel,
    required this.onBillingTypeChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ITEM-BASED VENDOR COSTS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: labelColor,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final rateController = itemControllers[item.id]!;
              final qtyController = itemQtyControllers[item.id]!;
              final daysController = itemDaysControllers[item.id]!;
              final isLast = idx == items.length - 1;

              final rate = double.tryParse(rateController.text) ?? 0.0;
              final qty = int.tryParse(qtyController.text) ?? item.quantity;
              final days = int.tryParse(daysController.text) ?? item.days;

              final double vendorSubtotal;
              if (item.billingType == 'event') {
                vendorSubtotal = rate * qty;
              } else {
                vendorSubtotal = rate * qty * days;
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.itemName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => onBillingTypeChanged(idx, 'event'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: item.billingType == 'event'
                                          ? primaryColor
                                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Event',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: item.billingType == 'event'
                                            ? Colors.white
                                            : labelColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => onBillingTypeChanged(idx, 'daily'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: item.billingType == 'daily'
                                          ? primaryColor
                                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Daily',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: item.billingType == 'daily'
                                            ? Colors.white
                                            : labelColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (item.vendor.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.storefront_outlined, size: 14, color: labelColor),
                              const SizedBox(width: 4),
                              Text(
                                'Vendor: ${item.vendor}',
                                style: TextStyle(fontSize: 12, color: labelColor),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'QTY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: labelColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: qtyController,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => onChanged(),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.all(8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                    style: TextStyle(fontSize: 13, color: textColor),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DAYS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: labelColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: daysController,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => onChanged(),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.all(8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                    style: TextStyle(fontSize: 13, color: textColor),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'VENDOR RATE ($currencyLabel)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: labelColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: rateController,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => onChanged(),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.all(8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                    style: TextStyle(fontSize: 13, color: textColor),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'SUBTOTAL',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: labelColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$currencyLabel ${vendorSubtotal.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isLast) Divider(color: borderColor, height: 1),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
