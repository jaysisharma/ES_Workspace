import 'package:flutter/material.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/event_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/change_request_providers.dart';
import 'package:order_app/domain/entities/change_request_entity.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/providers/event_providers.dart';
import 'package:order_app/presentation/providers/event_notifier.dart';
import 'package:order_app/presentation/screens/common/orders/request_change_screen.dart';
import 'package:order_app/domain/entities/user_entity.dart';

class EventTaskDetailScreen extends ConsumerStatefulWidget {
  final EventEntity event;

  const EventTaskDetailScreen({super.key, required this.event});

  @override
  ConsumerState<EventTaskDetailScreen> createState() =>
      _EventTaskDetailScreenState();
}

class _EventTaskDetailScreenState extends ConsumerState<EventTaskDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Load items and change requests for this event's order
    Future.microtask(() {
      ref
          .read(orderItemNotifierProvider.notifier)
          .loadItems(widget.event.orderId);
      ref
          .read(changeRequestNotifierProvider.notifier)
          .loadRequests(widget.event.orderId);
    });
  }

  Future<void> _toggleTaskCompletion(OrderItemEntity item) async {
    final updatedItem = item.copyWith(isCompleted: !item.isCompleted);
    await ref.read(orderItemNotifierProvider.notifier).updateItem(updatedItem);

    // Recalculate event completion
    final items = ref.read(orderItemNotifierProvider).items;
    if (items.isNotEmpty) {
      final completedCount = items.where((i) => i.isCompleted).length;
      final newCompletion = completedCount / items.length;
      await ref
          .read(eventNotifierProvider.notifier)
          .updateCompletion(widget.event.id, newCompletion);

      if (newCompletion == 1.0) {
        await ref
            .read(eventNotifierProvider.notifier)
            .updateStatus(widget.event.id, 'Completed');
      } else {
        await ref
            .read(eventNotifierProvider.notifier)
            .updateStatus(widget.event.id, 'In Progress');
      }
    }
  }

  Future<void> _deleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event & Order'),
        content: const Text(
          'Are you sure you want to delete this event and its associated order? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Deleting...')));
      }

      // 1. Delete items
      await ref
          .read(orderItemNotifierProvider.notifier)
          .deleteItemsForOrder(widget.event.orderId);

      // 2. Delete Order
      await ref
          .read(orderNotifierProvider.notifier)
          .delete(widget.event.orderId);

      // 3. Delete Event
      final ok = await ref
          .read(eventNotifierProvider.notifier)
          .deleteEvent(widget.event.id);

      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event and Order deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          final error = ref.read(eventNotifierProvider).errorMessage;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${error ?? 'Failed to delete event'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _updateRequestStatus(
    ChangeRequestEntity request,
    ChangeStatus newStatus,
  ) async {
    await ref
        .read(changeRequestNotifierProvider.notifier)
        .updateStatus(request.id, request.orderId, newStatus.name, requestedByUserId: request.requestedBy);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request ${newStatus.name} successfully'),
          backgroundColor: newStatus == ChangeStatus.approved
              ? Colors.green
              : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final surfaceColor = colorScheme.surface;
    final successColor = colorScheme.secondary;
    final borderColor = colorScheme.outline;
    final textColor = colorScheme.onSurface;
    final labelColor = colorScheme.onSurfaceVariant;

    final itemState = ref.watch(orderItemNotifierProvider);
    final eventStateResult = ref.watch(eventsStreamProvider);

    final EventEntity currentEvent = eventStateResult.maybeWhen(
      data: (events) => events.firstWhere(
        (e) => e.id == widget.event.id,
        orElse: () => widget.event,
      ),
      orElse: () => widget.event,
    );

    final ordersAsync = ref.watch(ordersStreamProvider);
    final currentOrder = ordersAsync.maybeWhen(
      data: (orders) {
        try {
          return orders.firstWhere((o) => o.id == currentEvent.orderId);
        } catch (_) {
          return null;
        }
      },
      orElse: () => null,
    );

    final userRole = ref.watch(authNotifierProvider).user?.role;
    final isAdmin = userRole == UserRole.admin || userRole == UserRole.founder;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.8),
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textColor),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Event Tasks',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (isAdmin)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red,
                        ),
                        onPressed: _deleteEvent,
                        tooltip: 'Delete Event',
                      ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (currentEvent.status == 'Completed'
                                    ? successColor
                                    : primaryColor)
                                .withValues(alpha: 0.2),
                        border: Border.all(
                          color:
                              (currentEvent.status == 'Completed'
                                      ? successColor
                                      : primaryColor)
                                  .withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        currentEvent.status.toUpperCase(),
                        style: TextStyle(
                          color: currentEvent.status == 'Completed'
                              ? successColor
                              : primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: itemState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0).copyWith(bottom: 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Event Summary Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentEvent.title,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSummaryInfoRow(
                          Icons.calendar_today,
                          'Event: ${formatNepaliDate(currentEvent.date, 'MMM dd, yyyy')}',
                          labelColor,
                          primaryColor,
                        ),
                        if (currentOrder != null) ...[
                          const SizedBox(height: 12),
                          _buildSummaryInfoRow(
                            Icons.settings_suggest,
                            'Setup: ${formatNepaliDate(currentOrder.setupDate, 'MMM dd, yyyy')}',
                            labelColor,
                            primaryColor,
                          ),
                        ],
                        const SizedBox(height: 12),
                        _buildSummaryInfoRow(
                          Icons.location_on,
                          currentEvent.location,
                          labelColor,
                          primaryColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Assigned Items Section
                  Text(
                    'Assigned Items',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (itemState.items.isEmpty)
                    Center(
                      child: Text(
                        'No items found for this event',
                        style: TextStyle(color: labelColor),
                      ),
                    ),

                  ...itemState.items.map((item) {
                    if (item.isCompleted) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: InkWell(
                          onTap: () => _toggleTaskCompletion(item),
                          child: _buildCompletedTaskItem(
                            title: item.itemName,
                            subtitle:
                                'Vendor: ${item.vendor} | Spec: ${item.specification}',
                            qty: '${item.quantity} ${item.unit}',
                            days: '${item.days} Days',
                            note: 'Item confirmed and ready.',
                            successColor: successColor,
                            isDarkMode: isDarkMode,
                            textColor: textColor,
                            labelColor: labelColor,
                          ),
                        ),
                      );
                    } else {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: InkWell(
                          onTap: () => _toggleTaskCompletion(item),
                          child: _buildPendingTaskItem(
                            title: item.itemName,
                            subtitle:
                                'Vendor: ${item.vendor} | Spec: ${item.specification}',
                            qty: '${item.quantity} ${item.unit}',
                            days: '${item.days} Days',
                            primaryColor: primaryColor,
                            isDarkMode: isDarkMode,
                            surfaceDark: surfaceColor,
                            borderColor: borderColor,
                            textColor: textColor,
                            labelColor: labelColor,
                            onAddNote: () {
                              Navigator.push(
                                context,
                                SlidePageRoute(page: RequestChangeScreen(
                                    event: currentEvent,
                                    item: item,
                                  )),
                              );
                            },
                          ),
                        ),
                      );
                    }
                  }),

                  const SizedBox(height: 24),

                  // Change Requests Section
                  _buildChangeRequestsSection(
                    isDarkMode,
                    surfaceColor,
                    borderColor,
                    textColor,
                    labelColor,
                    primaryColor,
                    successColor,
                  ),
                ],
              ),
            ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Overall Progress',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    '${(currentEvent.completion * 100).toInt()}% Complete',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: currentEvent.status == 'Completed'
                          ? successColor
                          : primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? borderColor
                      : borderColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: (currentEvent.completion * 100).toInt().clamp(
                        0,
                        100,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: currentEvent.status == 'Completed'
                              ? successColor
                              : primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: (100 - (currentEvent.completion * 100).toInt())
                          .clamp(0, 100),
                      child: const SizedBox(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: currentEvent.status == 'Completed'
                      ? () async {
                          await ref
                              .read(eventNotifierProvider.notifier)
                              .updateStatus(currentEvent.id, 'Ready');
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Event marked as ready!'),
                              backgroundColor: successColor,
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: successColor,
                    disabledBackgroundColor: textColor.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    currentEvent.status == 'Ready'
                        ? 'Event Ready'
                        : 'Mark Event Ready',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryInfoRow(
    IconData icon,
    String text,
    Color labelColor,
    Color iconColor,
  ) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(fontSize: 14, color: labelColor)),
      ],
    );
  }

  Widget _buildChangeRequestsSection(
    bool isDarkMode,
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color labelColor,
    Color primaryColor,
    Color successColor,
  ) {
    final requestState = ref.watch(changeRequestNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Change Requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            if (requestState.isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (requestState.requests.isEmpty && !requestState.isLoading)
                Text(
                  'No change requests yet.',
                  style: TextStyle(color: labelColor, fontSize: 14),
                )
              else
                ...requestState.requests.map((request) {
                  Color statusColor;
                  switch (request.status) {
                    case ChangeStatus.approved:
                      statusColor = Colors.green;
                      break;
                    case ChangeStatus.rejected:
                      statusColor = Colors.red;
                      break;
                    default:
                      statusColor = Colors.orange;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              request.changeType,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                request.status.name.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          request.description,
                          style: TextStyle(color: textColor, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${formatNepaliDate(request.createdAt, 'MMM dd, yyyy')} ${DateFormat('h:mm a').format(request.createdAt)}',
                          style: TextStyle(color: labelColor, fontSize: 11),
                        ),
                        if (request.status == ChangeStatus.pending &&
                            (ref.watch(authNotifierProvider).user?.role ==
                                    UserRole.admin ||
                                ref.watch(authNotifierProvider).user?.role ==
                                    UserRole.founder)) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _updateRequestStatus(
                                    request,
                                    ChangeStatus.rejected,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.red),
                                    foregroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                  ),
                                  child: const Text(
                                    'Reject',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _updateRequestStatus(
                                    request,
                                    ChangeStatus.approved,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: successColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Approve',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedTaskItem({
    required String title,
    required String subtitle,
    required String qty,
    required String days,
    required String note,
    required Color successColor,
    required bool isDarkMode,
    required Color textColor,
    required Color labelColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: successColor.withValues(alpha: 0.1),
        border: Border.all(color: successColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: labelColor),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'COMPLETED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: successColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: successColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: successColor.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Qty: $qty',
                style: TextStyle(fontSize: 14, color: labelColor),
              ),
              Text(
                'Days: $days',
                style: TextStyle(fontSize: 14, color: labelColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              note,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: labelColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTaskItem({
    required String title,
    required String subtitle,
    required String qty,
    required String days,
    required Color primaryColor,
    required bool isDarkMode,
    required Color surfaceDark,
    required Color borderColor,
    required Color textColor,
    required Color labelColor,
    required VoidCallback onAddNote,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceDark,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: labelColor),
                    ),
                  ],
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDarkMode
                        ? const Color(0xFF475569)
                        : const Color(0xFFcbd5e1),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: borderColor),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Qty: $qty',
                style: TextStyle(fontSize: 14, color: labelColor),
              ),
              Text(
                'Days: $days',
                style: TextStyle(fontSize: 14, color: labelColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onAddNote,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF0f1a23).withValues(alpha: 0.5)
                    : const Color(0xFFf8fafc),
                border: Border.all(
                  color: isDarkMode
                      ? const Color(0xFF334155)
                      : const Color(0xFFcbd5e1),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_note, size: 16, color: labelColor),
                  const SizedBox(width: 8),
                  Text(
                    'Add operational notes / request change...',
                    style: TextStyle(fontSize: 12, color: labelColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
