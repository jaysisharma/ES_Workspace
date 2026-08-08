import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/screens/common/orders/order_details_screen.dart';

class OrderCard extends ConsumerWidget {
  final OrderEntity order;
  final double completion;

  const OrderCard({super.key, required this.order, required this.completion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;
    final borderColor = colorScheme.outline;
    final authState = ref.watch(authNotifierProvider);
    final isAdminOrFounder = authState.user?.role == UserRole.admin || authState.user?.role == UserRole.founder;

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
          border: Border.all(
            color: borderColor.withValues(alpha: 0.3),
          ),
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
                          if (order.isArchived) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                              ),
                              child: const Text(
                                'ARCHIVED',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                            ),
                          ],
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
                    if (isAdminOrFounder) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          order.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                          size: 18,
                          color: order.isArchived ? Colors.purple : labelColor,
                        ),
                        tooltip: order.isArchived ? 'Unarchive Event' : 'Archive Event',
                        onPressed: () async {
                          final actionStr = order.isArchived ? 'unarchive' : 'archive';
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('${actionStr[0].toUpperCase()}${actionStr.substring(1)} Event?'),
                              content: Text(
                                'Are you sure you want to $actionStr "${order.eventName}"?\n\n${order.isArchived ? "Unarchiving will bring it back to your active homepage." : "Archiving will hide it from active homepage lists to keep your dashboard clean."}'
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: order.isArchived ? colorScheme.primary : Colors.purple,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(actionStr.toUpperCase()),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await ref
                                .read(orderNotifierProvider.notifier)
                                .toggleArchiveOrder(order.id, !order.isArchived);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Event "${order.eventName}" ${order.isArchived ? "unarchived" : "archived"} successfully.'),
                                  backgroundColor: Colors.purple,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
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
