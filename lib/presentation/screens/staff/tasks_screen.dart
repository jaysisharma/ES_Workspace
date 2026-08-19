import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/domain/entities/user_entity.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Design Tokens
    final primaryColor = const Color(0xFF0075db);
    final bgColor = isDarkMode
        ? const Color(0xFF0f172a)
        : const Color(0xFFf8fafc);
    final cardColor = isDarkMode ? const Color(0xFF1e293b) : Colors.white;
    final borderColor = isDarkMode
        ? const Color(0xFF334155)
        : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1e293b);
    final labelColor = isDarkMode
        ? const Color(0xFF94a3b8)
        : const Color(0xFF64748b);

    final currentUser = ref.watch(authNotifierProvider).user;
    final ordersAsync = ref.watch(ordersStreamProvider);
    final itemsAsync = ref.watch(allItemsStreamProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.8),
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Text(
                  'All Tasks',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: itemsAsync.when(
        data: (allItems) {
          return ordersAsync.when(
            data: (orders) {
              // Filter out items belonging to Draft orders
              final activeOrderMap = {
                for (final o in orders.where((o) => o.status != OrderStatus.draft))
                  o.id: o
              };

              final activeItems = allItems.where((item) {
                final order = activeOrderMap[item.orderId];
                if (order == null) return false;

                if (currentUser?.role == UserRole.staff) {
                  // Staff member sees tasks explicitly assigned to them OR tasks assigned to their order without a specific staff assignment
                  final isExplicitlyAssigned = item.assignedStaffId == currentUser!.uid;
                  final isOrderAssigned = item.assignedStaffId == null && order.assignedStaffIds.contains(currentUser.uid);
                  return isExplicitlyAssigned || isOrderAssigned;
                }

                // Admin / Founder sees all tasks
                return true;
              }).toList();

              if (activeItems.isEmpty) {
                return _buildEmptyState(labelColor);
              }

              // Group items by order for better context
              final groupedItems = <String, List<OrderItemEntity>>{};
              for (var item in activeItems) {
                groupedItems.putIfAbsent(item.orderId, () => []).add(item);
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(ordersStreamProvider);
                  ref.invalidate(allItemsStreamProvider);
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  itemCount: groupedItems.length,
                  itemBuilder: (context, index) {
                    final orderId = groupedItems.keys.elementAt(index);
                    final orderItems = groupedItems[orderId]!;
                    final order = orders.firstWhere((o) => o.id == orderId);

                    return _buildOrderTaskGroup(
                      order: order,
                      items: orderItems,
                      isDarkMode: isDarkMode,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      labelColor: labelColor,
                      primaryColor: primaryColor,
                      ref: ref,
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(
              child: Text(
                'Error loading orders: $err',
                style: TextStyle(color: labelColor),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(
            'Error loading tasks: $err',
            style: TextStyle(color: labelColor),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color labelColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 64, color: labelColor.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No tasks assigned',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tasks will appear here when events are created or assigned.',
            style: TextStyle(fontSize: 13, color: labelColor.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTaskGroup({
    required OrderEntity order,
    required List<OrderItemEntity> items,
    required bool isDarkMode,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color labelColor,
    required Color primaryColor,
    required WidgetRef ref,
  }) {
    final completedCount = items.where((i) => i.isCompleted).length;
    final progress = items.isEmpty ? 0.0 : completedCount / items.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.eventName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: labelColor),
                          const SizedBox(width: 4),
                          Text(
                            formatNepaliDate(order.eventDate, 'dd MMM yyyy'),
                            style: TextStyle(fontSize: 12, color: labelColor),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.location_on, size: 12, color: labelColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              order.venue,
                              style: TextStyle(fontSize: 12, color: labelColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$completedCount/${items.length} Done',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Progress Bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: borderColor.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress == 1.0 ? Colors.green : primaryColor,
            ),
            minHeight: 3,
          ),

          // Item List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: borderColor.withValues(alpha: 0.5)),
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _buildItemCheckbox(item, ref),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.itemName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: item.isCompleted ? labelColor : textColor,
                              decoration: item.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (item.specification.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.specification,
                              style: TextStyle(fontSize: 12, color: labelColor),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      'Qty: ${item.quantity} ${item.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: labelColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemCheckbox(OrderItemEntity item, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        await ref
            .read(orderItemNotifierProvider.notifier)
            .toggleCompletion(item);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: item.isCompleted ? Colors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: item.isCompleted ? Colors.green : Colors.grey,
            width: 2,
          ),
        ),
        child: item.isCompleted
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}
