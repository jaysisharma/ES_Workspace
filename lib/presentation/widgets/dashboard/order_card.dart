import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/presentation/screens/common/orders/order_details_screen.dart';

class OrderCard extends ConsumerWidget {
  final OrderEntity order;
  final double completion;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectionChanged;

  const OrderCard({
    super.key,
    required this.order,
    required this.completion,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        if (isSelectionMode) {
          onSelectionChanged?.call(!isSelected);
        } else {
          context.pushPage(OrderDetailsScreen(order: order));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.red.withValues(alpha: 0.08)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.red.shade400
                : borderColor.withValues(alpha: 0.3),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    activeColor: Colors.red,
                    onChanged: (val) => onSelectionChanged?.call(val),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.eventName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
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
                const SizedBox(width: 8),
                Row(
                  children: [
                    if (order.orderType.toLowerCase() == 'rental') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8b5cf6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFF8b5cf6).withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 10,
                              color: Color(0xFF8b5cf6),
                            ),
                            SizedBox(width: 3),
                            Text(
                              'RENTAL',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF8b5cf6),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
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
