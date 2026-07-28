import 'package:flutter/material.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/nepali_date_formatter.dart';
import '../../../core/services/order_pdf_service.dart';
import '../../../domain/entities/order_entity.dart';
import '../../../domain/entities/order_item_entity.dart';
import '../../providers/order_providers.dart';
import '../../providers/event_providers.dart';
import '../../providers/event_notifier.dart';
import 'create_order_screen.dart';
import '../../providers/auth_provider.dart';
import '../../../domain/entities/user_entity.dart';
import 'revenue_breakdown_screen.dart';
import 'expense_breakdown_screen.dart';
import 'pdf_preview_screen.dart';
import '../../providers/settings_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../providers/change_request_providers.dart';
import '../../../domain/entities/change_request_entity.dart';

class OrderDetailsScreen extends ConsumerStatefulWidget {
  final OrderEntity order;
  final bool fromCalendar;

  const OrderDetailsScreen({super.key, required this.order, this.fromCalendar = false});

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(orderItemNotifierProvider.notifier).loadItems(widget.order.id);
      ref
          .read(changeRequestNotifierProvider.notifier)
          .loadRequests(widget.order.id);
    });
  }

  Future<void> _sharePdf(OrderEntity order, List<OrderItemEntity> items) async {
    String progressMessage = 'Preparing PDF to share…';
    StateSetter setSnackBarState = (_) {};

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: StatefulBuilder(
          builder: (context, setState) {
            setSnackBarState = setState;
            return Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(progressMessage)),
              ],
            );
          },
        ),
        duration: const Duration(seconds: 30),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );

    try {
      final pdf = await OrderPdfService.generateOrderPdf(
        order: order,
        items: items,
        showFinancials: false,
        onProgress: (status) {
          if (mounted) {
            setSnackBarState(() {
              progressMessage = status;
            });
          }
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final fileName = 'Order_${order.id}_${order.venue.replaceAll(RegExp(r'[ ,]+'), '_')}.pdf';
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            pdfData: pdf,
            title: 'Order Summary PDF',
            fileName: fileName,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('PDF generation error [order_details]: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share PDF: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      );
    }
  }

  Future<void> _updateStatus(OrderStatus newStatus) async {
    final updated = _buildUpdatedOrder(newStatus);
    await ref.read(orderNotifierProvider.notifier).updateOrder(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to ${_statusLabel(newStatus)}'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      );
    }
  }

  Future<void> _handleDeleteOrder(String? eventId, String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: const Text(
          'Are you sure you want to delete this order? This will also delete all associated items and any linked event. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Order'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) {
        // Show loading snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deleting...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // 1. Delete Order Items
      await ref
          .read(orderItemNotifierProvider.notifier)
          .deleteItemsForOrder(orderId);

      // 2. Delete Order
      await ref.read(orderNotifierProvider.notifier).delete(orderId);

      // 3. Delete Event (if exists)
      bool eventDeleteOk = true;
      if (eventId != null) {
        eventDeleteOk = await ref
            .read(eventNotifierProvider.notifier)
            .deleteEvent(eventId);
      }

      if (mounted) {
        if (eventDeleteOk) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Order deleted successfully'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
          );
          Navigator.pop(context);
        } else {
          final error = ref.read(eventNotifierProvider).errorMessage;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${error ?? 'Failed to complete deletion'}'),
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

  OrderEntity _buildUpdatedOrder(OrderStatus status) {
    return OrderEntity(
      id: widget.order.id,
      eventName: widget.order.eventName,
      eventDate: widget.order.eventDate,
      eventEndDate: widget.order.eventEndDate,
      setupDate: widget.order.setupDate,
      setupEndDate: widget.order.setupEndDate,
      venue: widget.order.venue,
      contactPerson: widget.order.contactPerson,
      contactNumber: widget.order.contactNumber,
      notes: widget.order.notes,
      status: status,
      assignedStaffIds: widget.order.assignedStaffIds,
      totalAmount: widget.order.totalAmount,
      totalExpenses: widget.order.totalExpenses,
      createdAt: widget.order.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  String _statusLabel(OrderStatus s) {
    switch (s) {
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.inProgress:
        return 'In Progress';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.locked:
        return 'Locked';
      default:
        return s.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final primaryColor = colorScheme.primary;
    final successColor = colorScheme
        .secondary; // Using secondary for success as per current logic
    final warningColor = colorScheme.tertiary; // Using tertiary for warning
    final errorColor = colorScheme.error;

    final bgColor = colorScheme.surface;
    final surfaceColor = colorScheme.surface;
    final borderColor = colorScheme.outline;
    final textColor = colorScheme.onSurface;
    final labelColor = colorScheme.onSurfaceVariant;
    final inputBgColor = colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.5,
    );

    final itemState = ref.watch(orderItemNotifierProvider);
    final eventsAsync = ref.watch(eventsStreamProvider);

    // Look up real-time order from stream if available
    final ordersAsync = ref.watch(ordersStreamProvider);
    final order = ordersAsync.maybeWhen(
      data: (orders) =>
          orders.where((o) => o.id == widget.order.id).firstOrNull ??
          widget.order,
      orElse: () => widget.order,
    );

    // Find associated event
    final event = eventsAsync.maybeWhen(
      data: (events) => events.where((e) => e.orderId == order.id).firstOrNull,
      orElse: () => null,
    );

    // Status color
    Color statusColor;
    switch (order.status) {
      case OrderStatus.confirmed:
        statusColor = primaryColor;
        break;
      case OrderStatus.inProgress:
        statusColor = warningColor;
        break;
      case OrderStatus.completed:
        statusColor = successColor;
        break;
      default:
        statusColor = labelColor;
    }

    final totalItems = itemState.items.length;
    final completedItems = itemState.items.where((i) => i.isCompleted).length;
    final completion = totalItems > 0 ? completedItems / totalItems : 0.0;

    final settings = ref.watch(settingsProvider);
    final currencyLabel = settings.currency.split(' ').first;

    // Well colors (Boosted for vibrancy)
    final statusWellColor = statusColor.withValues(alpha: 0.12);
    final primaryWellColor = primaryColor.withValues(alpha: 0.12);
    final defaultWellColor = isDarkMode
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.15)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar ─────────────────────────────────────────────────
            Container(
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
                  // Revenue button (Admin only)
                  if (ref.watch(authNotifierProvider).user?.role ==
                          UserRole.admin ||
                      ref.watch(authNotifierProvider).user?.role ==
                          UserRole.founder)
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
                            SlidePageRoute(page: RevenueBreakdownScreen(
                                order: order,
                                items: itemState.items,
                              )),
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
                  // Share PDF button
                  IconButton(
                    icon: Icon(
                      Icons.share_outlined,
                      color: primaryColor,
                      size: 20,
                    ),
                    tooltip: 'Share Order (PDF)',
                    onPressed: () => _sharePdf(order, itemState.items),
                    style: IconButton.styleFrom(
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Edit button (Admin/Founder only)
                  if (ref.watch(authNotifierProvider).user?.role ==
                          UserRole.admin ||
                      ref.watch(authNotifierProvider).user?.role ==
                          UserRole.founder)
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
                          SlidePageRoute(page: CreateOrderScreen(existingOrder: order)),
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
                  // Delete button (Admin only, hidden when from calendar)
                  if (!widget.fromCalendar &&
                      (ref.watch(authNotifierProvider).user?.role ==
                              UserRole.admin ||
                          ref.watch(authNotifierProvider).user?.role ==
                              UserRole.founder))
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                        size: 20,
                      ),
                      tooltip: 'Delete Order',
                      onPressed: () => _handleDeleteOrder(event?.id, order.id),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── Scrollable Body ──────────────────────────────────────────
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;

                  final headerCard = Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          statusWellColor,
                          statusWellColor.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                _statusLabel(order.status).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            Text(
                              'ID: ${order.id.length > 10 ? order.id.substring(0, 10) : order.id}',
                              style: TextStyle(
                                fontSize: 11,
                                color: labelColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          order.eventName,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.calendar_today_outlined,
                          text: () {
                            final start = order.eventDate;
                            final end = order.eventEndDate;
                            if (end == null ||
                                (end.year == start.year &&
                                    end.month == start.month &&
                                    end.day == start.day)) {
                              return formatNepaliDate(start, 'MMMM dd, yyyy');
                            }
                            return '${formatNepaliDate(start, 'MMMM dd')} – ${formatNepaliDate(end, 'MMMM dd, yyyy')}';
                          }(),
                          color: primaryColor,
                          labelColor: labelColor,
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.location_on_outlined,
                          text: order.venue,
                          color: primaryColor,
                          labelColor: labelColor,
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.person_outline_rounded,
                          text:
                              '${order.contactPerson}  •  ${order.contactNumber}',
                          color: primaryColor,
                          labelColor: labelColor,
                        ),
                      ],
                    ),
                  );

                  final financialCard = Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primaryWellColor,
                          primaryWellColor.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _SectionLabel(
                              'FINANCIAL SUMMARY',
                              labelColor: labelColor,
                              accentColor: primaryColor,
                            ),
                            if (ref.watch(authNotifierProvider).user?.role ==
                                    UserRole.admin ||
                                ref.watch(authNotifierProvider).user?.role ==
                                    UserRole.founder)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: order.totalAmount > 0
                                      ? successColor.withValues(alpha: 0.1)
                                      : warningColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  order.totalAmount > 0
                                      ? 'FINALIZED'
                                      : 'PENDING',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: order.totalAmount > 0
                                        ? successColor
                                        : warningColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _FinanceCard(
                                label: 'Total Revenue',
                                amount: order.totalAmount,
                                color: primaryColor,
                                surfaceColor: inputBgColor,
                                textColor: textColor,
                                labelColor: labelColor,
                                currencyLabel: currencyLabel,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _FinanceCard(
                                label: 'Expenses',
                                amount: order.totalExpenses,
                                color: warningColor,
                                surfaceColor: inputBgColor,
                                textColor: textColor,
                                labelColor: labelColor,
                                currencyLabel: currencyLabel,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _FinanceCard(
                                label: 'Net Profit',
                                amount:
                                    order.totalAmount - order.totalExpenses,
                                color: successColor,
                                surfaceColor: inputBgColor,
                                textColor: textColor,
                                labelColor: labelColor,
                                currencyLabel: currencyLabel,
                              ),
                            ),
                          ],
                        ),
                        if (ref.watch(authNotifierProvider).user?.role ==
                                UserRole.admin ||
                            ref.watch(authNotifierProvider).user?.role ==
                                UserRole.founder) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: Column(
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      SlidePageRoute(
                                        page: RevenueBreakdownScreen(
                                          order: order,
                                          items: itemState.items,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.analytics_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('View Revenue Breakdown'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: primaryColor,
                                    backgroundColor: primaryColor.withValues(
                                      alpha: 0.05,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    minimumSize: const Size(
                                      double.infinity,
                                      0,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      SlidePageRoute(
                                        page: ExpenseBreakdownScreen(
                                          order: order,
                                          items: itemState.items,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.receipt_long_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('View Expense Breakdown'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: warningColor,
                                    backgroundColor: warningColor.withValues(
                                      alpha: 0.05,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    minimumSize: const Size(
                                      double.infinity,
                                      0,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );

                  final datesCard = Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: defaultWellColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(
                          'EVENT DETAILS',
                          labelColor: labelColor,
                          accentColor: primaryColor,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _DetailCell(
                                label: 'Setup Date',
                                value: formatNepaliDate(
                                  order.setupDate,
                                  'MMMM dd, yyyy',
                                ),
                                textColor: textColor,
                                labelColor: labelColor,
                              ),
                            ),
                            Expanded(
                              child: _DetailCell(
                                label: 'Event Date',
                                value: () {
                                  final start = order.eventDate;
                                  final end = order.eventEndDate;
                                  if (end == null ||
                                      (end.year == start.year &&
                                          end.month == start.month &&
                                          end.day == start.day)) {
                                    return formatNepaliDate(
                                      start,
                                      'MMMM dd, yyyy',
                                    );
                                  }
                                  return '${formatNepaliDate(start, 'MMMM dd')} – ${formatNepaliDate(end, 'MMMM dd, yyyy')}';
                                }(),
                                textColor: textColor,
                                labelColor: labelColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );

                  final itemsCard = Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: defaultWellColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _SectionLabel(
                              'ITEMS LIST',
                              labelColor: labelColor,
                              accentColor: primaryColor,
                            ),
                            Text(
                              '$completedItems / $totalItems done',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    completedItems == totalItems &&
                                            totalItems > 0
                                        ? successColor
                                        : labelColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (itemState.isLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (itemState.items.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'No items added yet',
                                style: TextStyle(color: labelColor),
                              ),
                            ),
                          )
                        else
                          ...itemState.items.map(
                            (item) => _ItemRow(
                              item: item,
                              onTap:
                                  (ref
                                              .watch(authNotifierProvider)
                                              .user
                                              ?.role ==
                                          UserRole.admin ||
                                      ref
                                              .watch(authNotifierProvider)
                                              .user
                                              ?.role ==
                                          UserRole.founder)
                                      ? () async {
                                          await ref
                                              .read(
                                                orderItemNotifierProvider
                                                    .notifier,
                                              )
                                              .toggleCompletion(item);

                                          if (event != null) {
                                            final updatedItems = ref
                                                .read(orderItemNotifierProvider)
                                                .items;
                                            if (updatedItems.isNotEmpty) {
                                              final completedCount =
                                                  updatedItems
                                                      .where(
                                                        (i) => i.isCompleted,
                                                      )
                                                      .length;
                                              final newCompletion =
                                                  completedCount /
                                                  updatedItems.length;

                                              await ref
                                                  .read(
                                                    eventNotifierProvider
                                                        .notifier,
                                                  )
                                                  .updateCompletion(
                                                    event.id,
                                                    newCompletion,
                                                  );

                                              final newStatus =
                                                  newCompletion == 1.0
                                                      ? 'Completed'
                                                      : 'In Progress';
                                              if (event.status != newStatus) {
                                                await ref
                                                    .read(
                                                      eventNotifierProvider
                                                          .notifier,
                                                    )
                                                    .updateStatus(
                                                      event.id,
                                                      newStatus,
                                                    );
                                              }
                                            }
                                          }
                                        }
                                      : null,
                              primaryColor: primaryColor,
                              successColor: successColor,
                              inputBgColor: inputBgColor,
                              borderColor: borderColor,
                              textColor: textColor,
                              labelColor: labelColor,
                            ),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _SectionLabel(
                              'TASK COMPLETION',
                              labelColor: labelColor,
                              accentColor: Colors.greenAccent.shade700,
                            ),
                            Text(
                              '${(completion * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: completion == 1.0
                                    ? Colors.greenAccent.shade700
                                    : primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: completion,
                            minHeight: 10,
                            backgroundColor: isDarkMode
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.05),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              completion == 1.0
                                  ? Colors.greenAccent.shade700
                                  : primaryColor,
                            ),
                          ),
                        ),
                        if (event == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'No event linked yet',
                              style: TextStyle(
                                fontSize: 12,
                                color: labelColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );

                  final activityLogCard = Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: defaultWellColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(
                          'ACTIVITY LOG',
                          labelColor: labelColor,
                          accentColor: primaryColor,
                        ),
                        const SizedBox(height: 16),
                        if (order.logs.isEmpty)
                          _TimelineItem(
                            label: 'Order Created',
                            time:
                                '${formatNepaliDate(order.createdAt, 'MMMM dd, yyyy')}  ${DateFormat('h:mm a').format(order.createdAt)}',
                            isFirst: true,
                            isPrimary: true,
                            isLast: true,
                            primaryColor: primaryColor,
                            borderColor: borderColor,
                            textColor: textColor,
                            labelColor: labelColor,
                          )
                        else
                          ...order.logs.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final log = entry.value;
                            return _TimelineItem(
                              label: log.message,
                              time:
                                  '${formatNepaliDate(log.timestamp, 'MMMM dd')}, ${DateFormat('h:mm a').format(log.timestamp)}',
                              isFirst: idx == 0,
                              isPrimary: idx == order.logs.length - 1,
                              isLast: idx == order.logs.length - 1,
                              primaryColor: primaryColor,
                              borderColor: borderColor,
                              textColor: textColor,
                              labelColor: labelColor,
                            );
                          }),
                        if (order.updatedAt
                                .difference(order.createdAt)
                                .inMinutes >=
                            1) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 36),
                            child: Text(
                              'Last updated: ${formatNepaliDate(order.updatedAt, 'MMMM dd')}, ${DateFormat('h:mm a').format(order.updatedAt)}',
                              style: TextStyle(
                                fontSize: 10,
                                color: labelColor,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );

                  if (isWide) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24).copyWith(bottom: 170),
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                headerCard,
                                const SizedBox(height: 16),
                                financialCard,
                                const SizedBox(height: 16),
                                if (!widget.fromCalendar)
                                  _buildChangeRequestsSection(
                                    surfaceColor,
                                    borderColor,
                                    textColor,
                                    labelColor,
                                    primaryColor,
                                    successColor,
                                    warningColor,
                                    errorColor,
                                  ),
                                const SizedBox(height: 16),
                                activityLogCard,
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                datesCard,
                                const SizedBox(height: 16),
                                itemsCard,
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16).copyWith(bottom: 170),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        headerCard,
                        const SizedBox(height: 16),
                        financialCard,
                        const SizedBox(height: 16),
                        datesCard,
                        const SizedBox(height: 16),
                        itemsCard,
                        const SizedBox(height: 16),
                        if (!widget.fromCalendar)
                          _buildChangeRequestsSection(
                            surfaceColor,
                            borderColor,
                            textColor,
                            labelColor,
                            primaryColor,
                            successColor,
                            warningColor,
                            errorColor,
                          ),
                        const SizedBox(height: 16),
                        activityLogCard,
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // ── Sticky Bottom Actions ───────────────────────────────────────────
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: SafeArea(
          child: _buildBottomActions(
            order,
            primaryColor,
            successColor,
            warningColor,
            surfaceColor,
            textColor,
            isDarkMode,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions(
    OrderEntity order,
    Color primaryColor,
    Color successColor,
    Color warningColor,
    Color surfaceColor,
    Color textColor,
    bool isDarkMode,
  ) {
    if (order.status == OrderStatus.draft) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _updateStatus(OrderStatus.confirmed),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          icon: const Icon(Icons.check_circle_outline, color: Colors.white),
          label: const Text(
            'Confirm Order',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    if (order.status == OrderStatus.confirmed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _updateStatus(OrderStatus.inProgress),
              style: ElevatedButton.styleFrom(
                backgroundColor: warningColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              label: const Text(
                'Mark In Progress',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (order.status == OrderStatus.inProgress) {
      final itemState = ref.watch(orderItemNotifierProvider);
      final completedItems = itemState.items.where((i) => i.isCompleted).length;
      final totalItems = itemState.items.length;
      final allDone = totalItems > 0 && completedItems == totalItems;

      final authState = ref.watch(authNotifierProvider);
      final isAdmin =
          authState.user?.role == UserRole.admin ||
          authState.user?.role == UserRole.founder;

      final canComplete = allDone;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!allDone && isAdmin)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Items pending, but Admin bypass enabled',
                style: TextStyle(
                  fontSize: 12,
                  color: warningColor,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: canComplete
                  ? Colors.greenAccent.shade700
                  : successColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: canComplete
                  ? [
                      BoxShadow(
                        color: Colors.greenAccent.shade700.withValues(
                          alpha: 0.4,
                        ),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton.icon(
              onPressed: canComplete
                  ? () => _updateStatus(OrderStatus.completed)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                canComplete
                    ? Icons.done_all_rounded
                    : Icons.lock_clock_outlined,
                color: canComplete
                    ? Colors.white
                    : successColor.withValues(alpha: 0.5),
              ),
              label: Text(
                allDone
                    ? 'Mark as Completed'.toUpperCase()
                    : 'Finish all items to complete'.toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: canComplete
                      ? Colors.white
                      : successColor.withValues(alpha: 0.5),
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Completed / Locked
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: successColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: successColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_rounded, color: successColor),
          const SizedBox(width: 8),
          Text(
            'Order ${_statusLabel(order.status)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: successColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeRequestsSection(
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color labelColor,
    Color primaryColor,
    Color successColor,
    Color warningColor,
    Color errorColor,
  ) {
    final requestState = ref.watch(changeRequestNotifierProvider);

    final defaultWellColor = Theme.of(context).brightness == Brightness.dark
        ? Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1)
        : Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: defaultWellColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionLabel(
                'CHANGE REQUESTS',
                labelColor: labelColor,
                accentColor: warningColor,
              ),
              if (requestState.isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (requestState.requests.isEmpty && !requestState.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No change requests for this order.',
                style: TextStyle(fontSize: 13, color: labelColor),
              ),
            )
          else
            ...requestState.requests.map((request) {
              Color statusColor;
              switch (request.status) {
                case ChangeStatus.approved:
                  statusColor = successColor;
                  break;
                case ChangeStatus.rejected:
                  statusColor = errorColor;
                  break;
                default:
                  statusColor = warningColor;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: labelColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
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
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            request.status.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      request.description,
                      style: TextStyle(fontSize: 12, color: labelColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${formatNepaliDate(request.createdAt, 'MMMM dd')}, ${DateFormat('h:mm a').format(request.createdAt)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: labelColor.withValues(alpha: 0.6),
                      ),
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
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color labelColor;
  final Color? accentColor;

  const _SectionLabel(this.text, {required this.labelColor, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final effectiveAccentColor = accentColor ?? labelColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: effectiveAccentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: labelColor,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color labelColor;

  const _InfoRow({
    required this.icon,
    required this.text,
    required this.color,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 13, color: labelColor)),
        ),
      ],
    );
  }
}

class _FinanceCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final Color surfaceColor;
  final Color textColor;
  final Color labelColor;
  final String currencyLabel;

  const _FinanceCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.surfaceColor,
    required this.textColor,
    required this.labelColor,
    required this.currencyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: labelColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyFormatter.formatWithLabel(amount, currencyLabel),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCell extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color labelColor;

  const _DetailCell({
    required this.label,
    required this.value,
    required this.textColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: labelColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final OrderItemEntity item;
  final VoidCallback? onTap;
  final Color primaryColor;
  final Color successColor;
  final Color inputBgColor;
  final Color borderColor;
  final Color textColor;
  final Color labelColor;

  const _ItemRow({
    required this.item,
    this.onTap,
    required this.primaryColor,
    required this.successColor,
    required this.inputBgColor,
    required this.borderColor,
    required this.textColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isCompleted
              ? successColor.withValues(alpha: 0.15)
              : inputBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.isCompleted
                ? successColor.withValues(alpha: 0.3)
                : borderColor.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: item.isCompleted ? successColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: item.isCompleted
                      ? successColor
                      : borderColor.withValues(alpha: 0.8),
                  width: 1.5,
                ),
                boxShadow: item.isCompleted
                    ? [
                        BoxShadow(
                          color: successColor.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: item.isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.specification}  •  ${item.vendor}',
                    style: TextStyle(fontSize: 11, color: labelColor),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Qty: ${item.quantity} ${item.unit}  •  ${item.days} days',
                    style: TextStyle(fontSize: 11, color: labelColor),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  item.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                  color: item.isCompleted ? successColor : labelColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String label;
  final String time;
  final bool isFirst;
  final bool isLast;
  final bool isPrimary;
  final Color primaryColor;
  final Color borderColor;
  final Color textColor;
  final Color labelColor;

  const _TimelineItem({
    required this.label,
    required this.time,
    required this.isFirst,
    required this.isPrimary,
    required this.primaryColor,
    required this.borderColor,
    required this.textColor,
    required this.labelColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isPrimary ? primaryColor : borderColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: borderColor)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(time, style: TextStyle(fontSize: 11, color: labelColor)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
