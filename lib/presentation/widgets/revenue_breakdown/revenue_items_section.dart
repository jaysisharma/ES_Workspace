import 'package:flutter/material.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/presentation/widgets/revenue_breakdown/revenue_breakdown_item_card.dart';

class RevenueItemsSectionWidget extends StatelessWidget {
  final List<OrderItemEntity> items;
  final Map<String, TextEditingController> itemControllers;
  final Map<String, TextEditingController> itemQtyControllers;
  final Map<String, TextEditingController> itemDaysControllers;
  final Map<String, FocusNode> focusNodes;
  final Color primaryColor;
  final Color labelColor;
  final String currencyLabel;
  final Function(int index, String billingType) onBillingTypeChanged;
  final VoidCallback onChanged;

  const RevenueItemsSectionWidget({
    super.key,
    required this.items,
    required this.itemControllers,
    required this.itemQtyControllers,
    required this.itemDaysControllers,
    required this.focusNodes,
    required this.primaryColor,
    required this.labelColor,
    required this.currencyLabel,
    required this.onBillingTypeChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.shopping_bag_outlined, size: 16, color: primaryColor),
            const SizedBox(width: 8),
            Text(
              'ITEMS REVENUE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: labelColor,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 48,
                    color: labelColor.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No items in this order',
                    style: TextStyle(color: labelColor, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RevenueItemCardWidget(
                item: item,
                index: idx,
                rateController: itemControllers[item.id]!,
                qtyController: itemQtyControllers[item.id]!,
                daysController: itemDaysControllers[item.id]!,
                focusNode: focusNodes[item.id]!,
                currencyLabel: currencyLabel,
                onBillingTypeChanged: (type) => onBillingTypeChanged(idx, type),
                onChanged: onChanged,
              ),
            );
          }),
      ],
    );
  }
}
