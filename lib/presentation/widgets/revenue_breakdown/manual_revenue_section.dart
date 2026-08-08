import 'package:flutter/material.dart';
import 'package:order_app/domain/entities/expense_entity.dart';
import 'package:order_app/presentation/widgets/revenue_breakdown/revenue_manual_item_card.dart';

class ManualRevenueSectionWidget extends StatelessWidget {
  final List<ExpenseEntity> manualRevenues;
  final Color primaryColor;
  final Color labelColor;
  final String currencyLabel;
  final VoidCallback onAddManual;
  final ValueChanged<ExpenseEntity> onEdit;
  final ValueChanged<ExpenseEntity> onDelete;

  const ManualRevenueSectionWidget({
    super.key,
    required this.manualRevenues,
    required this.primaryColor,
    required this.labelColor,
    required this.currencyLabel,
    required this.onAddManual,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.add_chart_outlined, size: 16, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  'ADDITIONAL REVENUE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: labelColor,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: onAddManual,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Manual'),
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (manualRevenues.isEmpty)
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
                    'No additional revenue added',
                    style: TextStyle(color: labelColor, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          ...manualRevenues.map(
            (revenue) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RevenueManualItemCardWidget(
                revenue: revenue,
                currencyLabel: currencyLabel,
                onEdit: () => onEdit(revenue),
                onDelete: () => onDelete(revenue),
                onPreviewBill: () {},
              ),
            ),
          ),
      ],
    );
  }
}
