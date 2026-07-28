import 'package:flutter/material.dart';
import '../../../core/utils/route_transitions.dart';
import '../../../domain/entities/order_entity.dart';
import '../../screens/common/order_details_screen.dart';

class OrderCard extends StatelessWidget {
  final OrderEntity order;
  final double completion;

  const OrderCard({super.key, required this.order, required this.completion});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;
    final borderColor = colorScheme.outline;

    Color statusColor;
    String statusText;
    switch (order.status) {
      case OrderStatus.confirmed:
        statusColor = colorScheme.primary;
        statusText = 'Confirmed';
        break;
      case OrderStatus.inProgress:
        statusColor = colorScheme.tertiary; // progress/warning
        statusText = 'In Progress';
        break;
      case OrderStatus.completed:
        statusColor = colorScheme.secondary; // done/success
        statusText = 'Completed';
        break;
      default:
        statusColor = labelColor;
        statusText = order.status.name.toUpperCase();
    }

    return GestureDetector(
      onTap: () {
        context.pushPage(OrderDetailsScreen(order: order));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.eventName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 11,
                            color: labelColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              order.venue,
                              style: TextStyle(fontSize: 11, color: labelColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusText.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Completion Bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: completion,
                      backgroundColor: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        completion == 1.0
                            ? Colors.greenAccent.shade700
                            : statusColor,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(completion * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: completion == 1.0
                        ? Colors.greenAccent.shade700
                        : statusColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
