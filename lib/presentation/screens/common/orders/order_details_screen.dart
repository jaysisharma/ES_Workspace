import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/change_request_providers.dart';
import 'package:order_app/presentation/providers/event_providers.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/providers/settings_provider.dart';
import 'package:order_app/presentation/widgets/order_details/order_details_activity_log.dart';
import 'package:order_app/presentation/widgets/order_details/order_details_actions_helper.dart';
import 'package:order_app/presentation/widgets/order_details/order_details_app_bar.dart';
import 'package:order_app/presentation/widgets/order_details/order_details_assigned_staff.dart';
import 'package:order_app/presentation/widgets/order_details/order_details_bottom_actions.dart';
import 'package:order_app/presentation/widgets/order_details/order_details_change_requests.dart';
import 'package:order_app/presentation/widgets/order_details/order_details_event_dates.dart';
import 'package:order_app/presentation/widgets/order_details/order_details_financial_summary.dart';
import 'package:order_app/presentation/widgets/order_details/order_details_header.dart';
import 'package:order_app/presentation/widgets/order_details/order_details_items_section.dart';

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

    final settings = ref.watch(settingsProvider);
    final currencyLabel = settings.currency.split(' ').first;

    final currentUserRole = ref.watch(authNotifierProvider).user?.role;
    final isCanAssign = currentUserRole == UserRole.admin || currentUserRole == UserRole.founder;

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
            OrderDetailsAppBarWidget(
              order: order,
              items: itemState.items,
              fromCalendar: widget.fromCalendar,
              eventId: event?.id,
              onSharePdf: () => OrderDetailsActionsHelper.sharePdf(
                context: context,
                order: order,
                items: itemState.items,
              ),
              onDeleteOrder: (eventId, orderId) => OrderDetailsActionsHelper.handleDeleteOrder(
                context: context,
                ref: ref,
                eventId: eventId,
                orderId: orderId,
              ),
              bgColor: bgColor,
              borderColor: borderColor,
              textColor: textColor,
              surfaceColor: surfaceColor,
              labelColor: labelColor,
              primaryColor: primaryColor,
              successColor: successColor,
            ),
            // ── Scrollable Body ──────────────────────────────────────────
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;

                  final headerCard = OrderDetailsHeaderWidget(
                    order: order,
                    statusColor: statusColor,
                    statusWellColor: statusWellColor,
                    textColor: textColor,
                    labelColor: labelColor,
                    primaryColor: primaryColor,
                    statusLabel: _statusLabel,
                  );

                  final financialCard = OrderDetailsFinancialSummaryWidget(
                    order: order,
                    items: itemState.items,
                    userRole: ref.watch(authNotifierProvider).user?.role,
                    primaryColor: primaryColor,
                    primaryWellColor: primaryWellColor,
                    successColor: successColor,
                    warningColor: warningColor,
                    inputBgColor: inputBgColor,
                    textColor: textColor,
                    labelColor: labelColor,
                    currencyLabel: currencyLabel,
                  );

                  final itemsCard = OrderDetailsItemsSectionWidget(
                    order: order,
                    itemState: itemState,
                    event: event,
                    isCanAssign: isCanAssign,
                    isDarkMode: isDarkMode,
                    primaryColor: primaryColor,
                    successColor: successColor,
                    defaultWellColor: defaultWellColor,
                    borderColor: borderColor,
                    textColor: textColor,
                    labelColor: labelColor,
                    inputBgColor: inputBgColor,
                  );

                  final datesCard = OrderDetailsEventDatesWidget(
                    order: order,
                    defaultWellColor: defaultWellColor,
                    borderColor: borderColor,
                    textColor: textColor,
                    labelColor: labelColor,
                    primaryColor: primaryColor,
                  );

                  final assignedStaffCard = OrderDetailsAssignedStaffWidget(
                    order: order,
                    isCanAssign: isCanAssign,
                    defaultWellColor: defaultWellColor,
                    borderColor: borderColor,
                    textColor: textColor,
                    labelColor: labelColor,
                    primaryColor: primaryColor,
                    inputBgColor: inputBgColor,
                  );

                  final activityLogCard = OrderDetailsActivityLogWidget(
                    order: order,
                    defaultWellColor: defaultWellColor,
                    borderColor: borderColor,
                    textColor: textColor,
                    labelColor: labelColor,
                    primaryColor: primaryColor,
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
                                  OrderDetailsChangeRequestsWidget(
                                    orderId: order.id,
                                    surfaceColor: surfaceColor,
                                    borderColor: borderColor,
                                    textColor: textColor,
                                    labelColor: labelColor,
                                    primaryColor: primaryColor,
                                    successColor: successColor,
                                    warningColor: warningColor,
                                    errorColor: errorColor,
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
                                assignedStaffCard,
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
                        assignedStaffCard,
                        const SizedBox(height: 16),
                        itemsCard,
                        const SizedBox(height: 16),
                        if (!widget.fromCalendar)
                          OrderDetailsChangeRequestsWidget(
                            orderId: order.id,
                            surfaceColor: surfaceColor,
                            borderColor: borderColor,
                            textColor: textColor,
                            labelColor: labelColor,
                            primaryColor: primaryColor,
                            successColor: successColor,
                            warningColor: warningColor,
                            errorColor: errorColor,
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
          child: OrderDetailsBottomActionsWidget(
            order: order,
            statusLabel: _statusLabel,
            onUpdateStatus: _updateStatus,
            primaryColor: primaryColor,
            successColor: successColor,
            warningColor: warningColor,
            surfaceColor: surfaceColor,
            textColor: textColor,
            isDarkMode: isDarkMode,
          ),
        ),
      ),
    );
  }
}


