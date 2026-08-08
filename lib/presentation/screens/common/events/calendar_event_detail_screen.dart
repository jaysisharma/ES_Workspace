import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/event_entity.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/presentation/providers/order_providers.dart';

/// A simple read-only detail page for calendar items.
/// Shown when tapping an event or order in the calendar — no admin actions.
class CalendarEventDetailScreen extends ConsumerWidget {
  /// Pass either [event] or [order], not both.
  final EventEntity? event;
  final OrderEntity? order;

  const CalendarEventDetailScreen.fromEvent({super.key, required EventEntity this.event})
      : order = null;

  const CalendarEventDetailScreen.fromOrder({super.key, required OrderEntity this.order})
      : event = null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0075db);
    final bgColor = isDarkMode ? const Color(0xFF0b0f13) : const Color(0xFFf5f7f8);
    final cardColor = isDarkMode ? const Color(0xFF1a1f26) : Colors.white;
    final borderColor = isDarkMode ? const Color(0xFF262f3a) : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final labelColor = isDarkMode ? const Color(0xFF94a3b8) : const Color(0xFF64748b);

    final isEvent = event != null;

    // For events, look up the linked order to get end date and setup date
    OrderEntity? linkedOrder;
    if (isEvent) {
      final ordersAsync = ref.watch(ordersStreamProvider);
      linkedOrder = ordersAsync.maybeWhen(
        data: (orders) => orders.cast<OrderEntity?>().firstWhere(
          (o) => o!.id == event!.orderId,
          orElse: () => null,
        ),
        orElse: () => null,
      );
    }

    final title = isEvent ? event!.title : order!.eventName;
    final location = isEvent ? event!.location : order!.venue;
    final status = isEvent ? event!.status : _orderStatusLabel(order!.status);
    final role = isEvent ? event!.role : 'Order';

    // Date range — for events, use the linked order's dates if available
    final DateTime startDate = isEvent
        ? (linkedOrder?.eventDate ?? event!.date)
        : order!.eventDate;
    final DateTime? endDate = isEvent
        ? linkedOrder?.eventEndDate
        : order!.eventEndDate;
    final DateTime? setupDate = isEvent ? linkedOrder?.setupDate : order!.setupDate;

    final String dateLabel;
    if (endDate == null ||
        (endDate.year == startDate.year &&
            endDate.month == startDate.month &&
            endDate.day == startDate.day)) {
      dateLabel = formatNepaliDate(startDate, 'MMMM dd, yyyy');
    } else {
      dateLabel =
          '${formatNepaliDate(startDate, 'MMMM dd')} – ${formatNepaliDate(endDate, 'MMMM dd, yyyy')}';
    }

    final bool isRange = endDate != null &&
        !(endDate.year == startDate.year &&
            endDate.month == startDate.month &&
            endDate.day == startDate.day);

    final Color statusColor = _statusColor(isEvent ? event!.status : order!.status.name);

    // Contact info (orders only)
    final String? contact = isEvent
        ? (linkedOrder != null
            ? '${linkedOrder.contactPerson}  ·  ${linkedOrder.contactNumber}'
            : null)
        : '${order!.contactPerson}  ·  ${order!.contactNumber}';

    final String? notes = isEvent ? linkedOrder?.notes : order!.notes;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Event Details',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Details card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.calendar_month_outlined,
                    label: isRange ? 'Date Range' : 'Event Date',
                    value: dateLabel,
                    iconColor: primaryColor,
                    textColor: textColor,
                    labelColor: labelColor,
                  ),
                  _Divider(color: borderColor),
                  _DetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    value: location,
                    iconColor: primaryColor,
                    textColor: textColor,
                    labelColor: labelColor,
                  ),
                  if (setupDate != null) ...[
                    _Divider(color: borderColor),
                    _DetailRow(
                      icon: Icons.build_outlined,
                      label: 'Setup Date',
                      value: formatNepaliDate(setupDate, 'MMMM dd, yyyy'),
                      iconColor: primaryColor,
                      textColor: textColor,
                      labelColor: labelColor,
                    ),
                  ],
                  if (contact != null) ...[
                    _Divider(color: borderColor),
                    _DetailRow(
                      icon: Icons.person_outline,
                      label: 'Contact',
                      value: contact,
                      iconColor: primaryColor,
                      textColor: textColor,
                      labelColor: labelColor,
                    ),
                  ],
                ],
              ),
            ),

            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NOTES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: labelColor,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      notes,
                      style: TextStyle(fontSize: 14, color: textColor, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _orderStatusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.inProgress:
        return 'In Progress';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.locked:
        return 'Locked';
      case OrderStatus.draft:
        return 'Draft';
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return const Color(0xFF0075db);
      case 'inprogress':
      case 'in progress':
        return const Color(0xFFf59e0b);
      case 'completed':
        return const Color(0xFF10b981);
      case 'locked':
        return const Color(0xFF8b5cf6);
      default:
        return const Color(0xFF94a3b8);
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color textColor;
  final Color labelColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    required this.textColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: labelColor, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;
  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: color);
  }
}
