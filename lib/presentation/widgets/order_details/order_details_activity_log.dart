import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/presentation/widgets/order_details/order_details_helper_widgets.dart';

class OrderDetailsActivityLogWidget extends StatelessWidget {
  final OrderEntity order;
  final Color defaultWellColor;
  final Color borderColor;
  final Color textColor;
  final Color labelColor;
  final Color primaryColor;

  const OrderDetailsActivityLogWidget({
    super.key,
    required this.order,
    required this.defaultWellColor,
    required this.borderColor,
    required this.textColor,
    required this.labelColor,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: defaultWellColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabelWidget(
            'ACTIVITY LOG',
            labelColor: labelColor,
            accentColor: primaryColor,
          ),
          const SizedBox(height: 16),
          if (order.logs.isEmpty)
            TimelineItemWidget(
              label: 'Order Created',
              time:
                  '${formatNepaliDate(order.createdAt, 'MMMM dd, yyyy')}  ${DateFormat('h:mm a').format(order.createdAt)}',
              isFirst: true,
              isPrimary: true,
              isLast: true,
              primaryColor: primaryColor,
              borderColor: borderColor,
              textColor: textColor,
              labelColor: labelColor,
            )
          else
            ...order.logs.asMap().entries.map((entry) {
              final idx = entry.key;
              final log = entry.value;
              return TimelineItemWidget(
                label: log.message,
                time:
                    '${formatNepaliDate(log.timestamp, 'MMMM dd')}, ${DateFormat('h:mm a').format(log.timestamp)}',
                isFirst: idx == 0,
                isPrimary: idx == order.logs.length - 1,
                isLast: idx == order.logs.length - 1,
                primaryColor: primaryColor,
                borderColor: borderColor,
                textColor: textColor,
                labelColor: labelColor,
              );
            }),
          if (order.updatedAt.difference(order.createdAt).inMinutes >= 1) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(
                'Last updated: ${formatNepaliDate(order.updatedAt, 'MMMM dd')}, ${DateFormat('h:mm a').format(order.updatedAt)}',
                style: TextStyle(
                  fontSize: 10,
                  color: labelColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
