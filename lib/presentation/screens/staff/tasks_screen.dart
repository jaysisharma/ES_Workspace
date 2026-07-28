import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/nepali_date_formatter.dart';
import '../../providers/order_providers.dart';
import '../../../domain/entities/order_item_entity.dart';
import '../../../domain/entities/order_entity.dart';

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
              final activeOrderIds = orders
                  .where((o) => o.status != OrderStatus.draft)
                  .map((o) => o.id)
                  .toSet();

              final activeItems = allItems
                  .where((item) => activeOrderIds.contains(item.orderId))
                  .toList();

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
            error: (err, _) =>
                Center(child: Text('Error loading orders: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading tasks: $err')),
      ),
    );
  }

  Widget _buildEmptyState(Color labelColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.checklist_rtl,
            size: 64,
            color: labelColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks found from active orders',
            style: TextStyle(
              fontSize: 16,
              color: labelColor,
              fontWeight: FontWeight.w500,
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0, left: 4),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.eventName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: labelColor,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Text(
                formatNepaliDate(order.eventDate, 'MMM dd'),
                style: TextStyle(fontSize: 12, color: labelColor),
              ),
            ],
          ),
        ),
        ...items.map(
          (item) => _buildTaskItem(
            item: item,
            isDarkMode: isDarkMode,
            cardColor: cardColor,
            borderColor: borderColor,
            textColor: textColor,
            labelColor: labelColor,
            primaryColor: primaryColor,
            ref: ref,
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTaskItem({
    required OrderItemEntity item,
    required bool isDarkMode,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color labelColor,
    required Color primaryColor,
    required WidgetRef ref,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildItemCheckbox(item, ref),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: item.isCompleted ? labelColor : textColor,
                    decoration: item.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.vendor} | ${item.specification}',
                  style: TextStyle(fontSize: 12, color: labelColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.quantity} ${item.unit}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              if (item.days > 0)
                Text(
                  '${item.days} Days',
                  style: TextStyle(fontSize: 10, color: labelColor),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemCheckbox(OrderItemEntity item, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final updatedItem = item.copyWith(isCompleted: !item.isCompleted);
        await ref
            .read(orderItemNotifierProvider.notifier)
            .updateItem(updatedItem);
      },
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: item.isCompleted
              ? const Color(0xFF10b981)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: item.isCompleted
                ? const Color(0xFF10b981)
                : const Color(0xFFcbd5e1),
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
