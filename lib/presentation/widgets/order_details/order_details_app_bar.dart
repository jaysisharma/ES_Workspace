import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/providers/event_notifier.dart';
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
    final canManageFinances = isAdminOrFounder || userRole == UserRole.finance;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: textColor, size: 20),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
            style: IconButton.styleFrom(
              backgroundColor: surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(color: borderColor, width: 0.5),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
          if (canManageFinances)
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
          if (isAdminOrFounder)
            IconButton(
              icon: Icon(
                order.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                color: order.isArchived
                    ? const Color(0xFF10b981)
                    : const Color(0xFF64748b),
                size: 20,
              ),
              tooltip: order.isArchived
                  ? 'Restore (Unarchive) Order'
                  : 'Archive Order',
              onPressed: () async {
                final isCurrentlyArchived = order.isArchived;
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Text(
                      isCurrentlyArchived ? 'Restore Order?' : 'Archive Order?',
                    ),
                    content: Text(
                      isCurrentlyArchived
                          ? 'Move "${order.eventName}" back to active orders and calendar?'
                          : 'Archive "${order.eventName}"? It will be hidden from active calendar and orders, but saved in Archived Orders.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: isCurrentlyArchived
                              ? const Color(0xFF10b981)
                              : const Color(0xFF64748b),
                        ),
                        child: Text(
                          isCurrentlyArchived ? 'Restore' : 'Archive',
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref
                      .read(orderNotifierProvider.notifier)
                      .toggleArchiveOrder(order.id, !isCurrentlyArchived);
                  if (eventId != null) {
                    await ref
                        .read(eventNotifierProvider.notifier)
                        .toggleArchiveEvent(eventId!, !isCurrentlyArchived);
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isCurrentlyArchived
                              ? 'Order restored to active list'
                              : 'Order archived successfully',
                        ),
                        backgroundColor: isCurrentlyArchived
                            ? const Color(0xFF10b981)
                            : const Color(0xFF64748b),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: IconButton.styleFrom(
                backgroundColor: (order.isArchived
                        ? const Color(0xFF10b981)
                        : const Color(0xFF64748b))
                    .withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
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
