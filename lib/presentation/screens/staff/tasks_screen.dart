import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Design Tokens
    final primaryColor = const Color(0xFF0075db);
    final bgColor =
        isDarkMode ? const Color(0xFF0f172a) : const Color(0xFFf8fafc);
    final cardColor = isDarkMode ? const Color(0xFF1e293b) : Colors.white;
    final borderColor =
        isDarkMode ? const Color(0xFF334155) : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1e293b);
    final labelColor =
        isDarkMode ? const Color(0xFF94a3b8) : const Color(0xFF64748b);

    final currentUser = ref.watch(authNotifierProvider).user;
    final ordersAsync = ref.watch(ordersStreamProvider);
    final itemsAsync = ref.watch(allItemsStreamProvider);

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: const BottomRightBackButton(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.8),
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                if (Navigator.canPop(context)) ...[
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: textColor),
                    tooltip: 'Back',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  'My Tasks',
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
          final orders = ordersAsync.value ?? [];
          final isStaff = currentUser?.role == UserRole.staff;
          final currentUid = currentUser?.uid;
          final currentEmail = currentUser?.email.toLowerCase().trim();

          // ── Manual (admin-assigned) tasks for this staff member ──────────
          final manualTasks = allItems.where((item) {
            if (!item.isManualTask) return false;

            if (isStaff) {
              // 1. Direct UID match
              if (currentUid != null && item.assignedStaffId == currentUid) {
                return true;
              }
              // 2. Email in assignedStaffId
              if (currentEmail != null &&
                  item.assignedStaffId != null &&
                  item.assignedStaffId!.toLowerCase().trim() == currentEmail) {
                return true;
              }
              // 3. Name or email in assignedStaffName
              if (currentEmail != null &&
                  item.assignedStaffName != null &&
                  (item.assignedStaffName!.toLowerCase().contains(currentEmail) ||
                      currentEmail.contains(item.assignedStaffName!.toLowerCase()))) {
                return true;
              }
              // 4. Global task (not assigned to specific staff)
              if (item.assignedStaffId == null || item.assignedStaffId!.isEmpty) {
                return true;
              }
              return false;
            }

            // Admin / Founder sees all
            return true;
          }).toList()
            ..sort((a, b) {
              if (a.isCompleted != b.isCompleted) {
                return a.isCompleted ? 1 : -1;
              }
              return 0;
            });

          // ── Order-linked tasks ───────────────────────────────────────────
          final activeOrderMap = {
            for (final o
                in orders.where((o) => o.status != OrderStatus.draft))
              o.id: o
          };

          final activeItems = allItems.where((item) {
            if (item.isManualTask) return false;
            final order = activeOrderMap[item.orderId];
            if (order == null) return false;

            if (isStaff) {
              final isExplicitlyAssigned = (currentUid != null &&
                      item.assignedStaffId == currentUid) ||
                  (currentEmail != null &&
                      item.assignedStaffId?.toLowerCase().trim() == currentEmail);
              final isOrderAssigned = item.assignedStaffId == null &&
                  ((currentUid != null &&
                          order.assignedStaffIds.contains(currentUid)) ||
                      (currentEmail != null &&
                          order.assignedStaffIds.any((id) =>
                              id.toLowerCase().trim() == currentEmail)));
              return isExplicitlyAssigned || isOrderAssigned;
            }
            return true;
          }).toList();

          final groupedItems = <String, List<OrderItemEntity>>{};
          for (var item in activeItems) {
            groupedItems.putIfAbsent(item.orderId, () => []).add(item);
          }

          final hasAnything =
              manualTasks.isNotEmpty || activeItems.isNotEmpty;
          if (!hasAnything) {
            return _buildEmptyState(labelColor);
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(ordersStreamProvider);
              ref.invalidate(allItemsStreamProvider);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                // ── Section: Admin-assigned tasks ─────────────────────────
                if (manualTasks.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Assigned by Admin',
                    color: const Color(0xFFf97316),
                    icon: Icons.assignment_ind_rounded,
                  ),
                  const SizedBox(height: 8),
                  ...manualTasks.map((task) => _buildManualTaskCard(
                        task: task,
                        isDarkMode: isDarkMode,
                        cardColor: cardColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        labelColor: labelColor,
                        primaryColor: primaryColor,
                        ref: ref,
                      )),
                  if (activeItems.isNotEmpty) const SizedBox(height: 20),
                ],

                // ── Section: Order tasks ──────────────────────────────────
                if (activeItems.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Event & Order Tasks',
                    color: primaryColor,
                    icon: Icons.event_note_rounded,
                  ),
                  const SizedBox(height: 8),
                  ...groupedItems.entries.map((entry) {
                    final orderId = entry.key;
                    final orderItems = entry.value;
                    final order = orders.where((o) => o.id == orderId).firstOrNull;
                    if (order == null) return const SizedBox.shrink();

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
                  }),
                ],
              ],
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

  // ── Manual task card ─────────────────────────────────────────────────────────
  Widget _buildManualTaskCard({
    required OrderItemEntity task,
    required bool isDarkMode,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color labelColor,
    required Color primaryColor,
    required WidgetRef ref,
  }) {
    final overdue = task.dueDate != null &&
        !task.isCompleted &&
        task.dueDate!.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: overdue
              ? Colors.red.shade300
              : const Color(0xFFf97316).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          GestureDetector(
            onTap: () => ref
                .read(orderItemNotifierProvider.notifier)
                .toggleCompletion(task),
            child: Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: task.isCompleted ? Colors.green : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: task.isCompleted ? Colors.green : Colors.grey,
                  width: 2,
                ),
              ),
              child: task.isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.itemName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: task.isCompleted ? labelColor : textColor,
                    decoration:
                        task.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (task.specification.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.specification,
                    style: TextStyle(fontSize: 13, color: labelColor),
                  ),
                ],
                if (task.dueDate != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.event_outlined,
                        size: 13,
                        color: overdue ? Colors.red : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Due: ${DateFormat('d MMM yyyy').format(task.dueDate!)}${overdue ? ' · Overdue' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: overdue ? Colors.red : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (task.isCompleted
                      ? Colors.green
                      : const Color(0xFFf97316))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              task.isCompleted ? 'Done' : 'Pending',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: task.isCompleted
                    ? Colors.green
                    : const Color(0xFFf97316),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color labelColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt,
              size: 64, color: labelColor.withValues(alpha: 0.5)),
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
            'Tasks will appear here when assigned by admin or\nwhen events are created.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: labelColor.withValues(alpha: 0.8)),
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
                          Icon(Icons.calendar_today,
                              size: 12, color: labelColor),
                          const SizedBox(width: 4),
                          Text(
                            formatNepaliDate(order.eventDate, 'dd MMM yyyy'),
                            style:
                                TextStyle(fontSize: 12, color: labelColor),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.location_on,
                              size: 12, color: labelColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              order.venue,
                              style:
                                  TextStyle(fontSize: 12, color: labelColor),
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
                      horizontal: 10, vertical: 4),
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
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: borderColor.withValues(alpha: 0.5)),
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
                              color:
                                  item.isCompleted ? labelColor : textColor,
                              decoration: item.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (item.specification.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.specification,
                              style:
                                  TextStyle(fontSize: 12, color: labelColor),
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

// ── Section header widget ─────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _SectionHeader(
      {required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
