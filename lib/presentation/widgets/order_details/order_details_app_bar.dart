import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/screens/common/orders/create_order_screen.dart';
import 'package:order_app/presentation/screens/common/finance/revenue_breakdown_screen.dart';

class OrderDetailsAppBarWidget extends ConsumerWidget {
  final OrderEntity order;
  final List<OrderItemEntity> items;
  final bool fromCalendar;
  final String? eventId;
  final VoidCallback onSharePdf;
  final Future<void> Function(String? eventId, String orderId) onDeleteOrder;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final Color surfaceColor;
  final Color labelColor;
  final Color primaryColor;
  final Color successColor;

  const OrderDetailsAppBarWidget({
    super.key,
    required this.order,
    required this.items,
    required this.fromCalendar,
    required this.eventId,
    required this.onSharePdf,
    required this.onDeleteOrder,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.surfaceColor,
    required this.labelColor,
    required this.primaryColor,
    required this.successColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRole = ref.watch(authNotifierProvider).user?.role;
    final isAdminOrFounder = userRole == UserRole.admin || userRole == UserRole.founder;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: textColor),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              order.eventName,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: textColor,
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isAdminOrFounder)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Icon(
                  Icons.payments_outlined,
                  color: successColor,
                  size: 20,
                ),
                tooltip: 'Update Revenue',
                onPressed: () {
                  Navigator.push(
                    context,
                    SlidePageRoute(
                      page: RevenueBreakdownScreen(
                        order: order,
                        items: items,
                      ),
                    ),
                  );
                },
                style: IconButton.styleFrom(
                  backgroundColor: successColor.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: Icon(
              Icons.share_outlined,
              color: primaryColor,
              size: 20,
            ),
            tooltip: 'Share Order (PDF)',
            onPressed: onSharePdf,
            style: IconButton.styleFrom(
              backgroundColor: primaryColor.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (isAdminOrFounder)
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                color: primaryColor,
                size: 20,
              ),
              tooltip: 'Edit Order',
              onPressed: () async {
                await Navigator.push(
                  context,
                  SlidePageRoute(
                    page: CreateOrderScreen(existingOrder: order),
                  ),
                );
              },
              style: IconButton.styleFrom(
                backgroundColor: primaryColor.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          const SizedBox(width: 4),
          if (isAdminOrFounder)
            IconButton(
              icon: Icon(
                order.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                color: order.isArchived ? Colors.purple : labelColor,
                size: 20,
              ),
              tooltip: order.isArchived ? 'Unarchive Order' : 'Archive Order',
              onPressed: () async {
                final actionStr = order.isArchived ? 'unarchive' : 'archive';
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(
                      '${actionStr[0].toUpperCase()}${actionStr.substring(1)} Order?',
                    ),
                    content: Text(
                      'Are you sure you want to $actionStr "${order.eventName}"?\n\n'
                      '${order.isArchived ? "Unarchiving will restore it to the active homepage list." : "Archiving will hide it from the active homepage to keep your dashboard organized."}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              order.isArchived ? primaryColor : Colors.purple,
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
                        content: Text(
                          'Order "${order.eventName}" ${order.isArchived ? "unarchived" : "archived"} successfully.',
                        ),
                        backgroundColor: Colors.purple,
                      ),
                    );
                  }
                }
              },
              style: IconButton.styleFrom(
                backgroundColor: (order.isArchived
                        ? Colors.purple
                        : labelColor)
                    .withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          const SizedBox(width: 4),
          if (!fromCalendar && isAdminOrFounder)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: 20,
              ),
              tooltip: 'Delete Order',
              onPressed: () => onDeleteOrder(eventId, order.id),
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
