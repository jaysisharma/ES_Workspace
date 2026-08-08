import 'package:flutter/material.dart';
import 'package:order_app/domain/entities/expense_entity.dart';

class ExpenseCardWidget extends StatelessWidget {
  final ExpenseEntity expense;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color labelColor;
  final Color primaryColor;
  final String currencyLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPreviewBill;

  const ExpenseCardWidget({
    super.key,
    required this.expense,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.labelColor,
    required this.primaryColor,
    required this.currencyLabel,
    required this.onEdit,
    required this.onDelete,
    required this.onPreviewBill,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
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
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  expense.category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
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
            expense.category == 'Other' && expense.description.isNotEmpty
                ? expense.description
                : expense.category,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          if (expense.vendorName != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.storefront_outlined, size: 14, color: labelColor),
                const SizedBox(width: 4),
                Text(
                  expense.vendorName!,
                  style: TextStyle(fontSize: 13, color: labelColor),
                ),
              ],
            ),
          ],
          if (expense.hasBill) ...[
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
                        'Attached Bill: ${expense.billName ?? "View Attachment"}',
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
              Text('Amount', style: TextStyle(fontSize: 13, color: labelColor)),
              Text(
                '$currencyLabel ${expense.amount.toStringAsFixed(0)}',
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
