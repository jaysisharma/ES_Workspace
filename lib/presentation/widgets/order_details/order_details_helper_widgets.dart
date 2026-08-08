import 'package:flutter/material.dart';
import 'package:order_app/core/utils/currency_formatter.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';

class SectionLabelWidget extends StatelessWidget {
  final String text;
  final Color labelColor;
  final Color? accentColor;

  const SectionLabelWidget(this.text, {super.key, required this.labelColor, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final effectiveAccentColor = accentColor ?? labelColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: effectiveAccentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: labelColor,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class InfoRowWidget extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color labelColor;

  const InfoRowWidget({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 13, color: labelColor)),
        ),
      ],
    );
  }
}

class FinanceCardWidget extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final Color surfaceColor;
  final Color textColor;
  final Color labelColor;
  final String currencyLabel;

  const FinanceCardWidget({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
    required this.surfaceColor,
    required this.textColor,
    required this.labelColor,
    required this.currencyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: labelColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyFormatter.formatWithLabel(amount, currencyLabel),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class DetailCellWidget extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color labelColor;

  const DetailCellWidget({
    super.key,
    required this.label,
    required this.value,
    required this.textColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: labelColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class OrderItemRowWidget extends StatelessWidget {
  final OrderItemEntity item;
  final VoidCallback? onTap;
  final VoidCallback? onAssignStaff;
  final Color primaryColor;
  final Color successColor;
  final Color inputBgColor;
  final Color borderColor;
  final Color textColor;
  final Color labelColor;

  const OrderItemRowWidget({
    super.key,
    required this.item,
    this.onTap,
    this.onAssignStaff,
    required this.primaryColor,
    required this.successColor,
    required this.inputBgColor,
    required this.borderColor,
    required this.textColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final assignedName = item.assignedStaffName;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.isCompleted
            ? successColor.withValues(alpha: 0.15)
            : inputBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isCompleted
              ? successColor.withValues(alpha: 0.3)
              : borderColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: item.isCompleted ? successColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: item.isCompleted
                      ? successColor
                      : borderColor.withValues(alpha: 0.8),
                  width: 1.5,
                ),
                boxShadow: item.isCompleted
                    ? [
                        BoxShadow(
                          color: successColor.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: item.isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.specification}  •  ${item.vendor}',
                    style: TextStyle(fontSize: 11, color: labelColor),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Qty: ${item.quantity} ${item.unit}  •  ${item.days} days',
                    style: TextStyle(fontSize: 11, color: labelColor),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: assignedName != null && assignedName.isNotEmpty
                              ? primaryColor.withValues(alpha: 0.12)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: assignedName != null && assignedName.isNotEmpty
                                ? primaryColor.withValues(alpha: 0.3)
                                : Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 11,
                              color: assignedName != null && assignedName.isNotEmpty
                                  ? primaryColor
                                  : labelColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              assignedName != null && assignedName.isNotEmpty
                                  ? 'Assigned: $assignedName'
                                  : 'Unassigned',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: assignedName != null && assignedName.isNotEmpty
                                    ? primaryColor
                                    : labelColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (onAssignStaff != null)
            IconButton(
              icon: Icon(
                Icons.person_add_alt_1_outlined,
                size: 18,
                color: primaryColor,
              ),
              tooltip: 'Assign task to staff',
              onPressed: onAssignStaff,
            )
          else if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  item.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                  color: item.isCompleted ? successColor : labelColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TimelineItemWidget extends StatelessWidget {
  final String label;
  final String time;
  final bool isFirst;
  final bool isLast;
  final bool isPrimary;
  final Color primaryColor;
  final Color borderColor;
  final Color textColor;
  final Color labelColor;

  const TimelineItemWidget({
    super.key,
    required this.label,
    required this.time,
    required this.isFirst,
    required this.isPrimary,
    required this.primaryColor,
    required this.borderColor,
    required this.textColor,
    required this.labelColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isPrimary ? primaryColor : borderColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: borderColor)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(time, style: TextStyle(fontSize: 11, color: labelColor)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
