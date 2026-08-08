import 'package:flutter/material.dart';
import 'package:order_app/domain/entities/expense_entity.dart';

class RevenueManualItemCardWidget extends StatelessWidget {
  final ExpenseEntity revenue;
  final String currencyLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPreviewBill;

  const RevenueManualItemCardWidget({
    super.key,
    required this.revenue,
    required this.currencyLabel,
    required this.onEdit,
    required this.onDelete,
    required this.onPreviewBill,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = colorScheme.onSurface;
    final labelColor = colorScheme.onSurfaceVariant;
    final surfaceColor = colorScheme.surface;
    final borderColor = colorScheme.outline;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${revenue.category.toUpperCase()} (${revenue.billingType.toUpperCase()})',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: labelColor,
                    ),
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: Colors.red.withValues(alpha: 0.7),
                    ),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            revenue.category == 'Other' && revenue.description.isNotEmpty
                ? revenue.description
                : revenue.category,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          if (revenue.vendorName != null && revenue.vendorName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 14,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Vendor: ${revenue.vendorName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Rate: $currencyLabel ${revenue.rate.toStringAsFixed(0)} | Qty: ${revenue.quantity} | Days: ${revenue.days}',
            style: TextStyle(fontSize: 12, color: labelColor),
          ),
          if (revenue.hasBill) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: onPreviewBill,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Attached Bill: ${revenue.billName ?? "View Attachment"}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.open_in_new, size: 12, color: Colors.green),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: TextStyle(fontSize: 13, color: labelColor),
              ),
              Text(
                '$currencyLabel ${revenue.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
