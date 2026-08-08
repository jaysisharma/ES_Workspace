import 'package:flutter/material.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/presentation/providers/event_providers.dart';
import 'package:order_app/domain/entities/event_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/screens/common/utility/notifications_screen.dart';
import 'package:order_app/presentation/providers/notification_notifier.dart';
import 'package:order_app/presentation/screens/common/events/event_task_detail_screen.dart';
import 'package:order_app/presentation/widgets/common/shimmer_loading.dart';
import 'package:order_app/presentation/widgets/hr_management/leave_request_sheet.dart';
import 'package:order_app/presentation/screens/admin/synology_company_pdf_screen.dart';

class StaffDashboard extends ConsumerStatefulWidget {
  const StaffDashboard({super.key});

  @override
  ConsumerState<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends ConsumerState<StaffDashboard> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;

    final notificationState = ref.watch(notificationsStreamProvider);

    final unreadCount = notificationState.maybeWhen(
      data: (list) => list.where((n) => !n.isRead).length,
      orElse: () => 0,
    );

    return Column(
      children: [
        // Custom Header
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (MediaQuery.of(context).size.width < 768)
                      Builder(
                        builder: (context) => IconButton(
                          icon: Icon(
                            Icons.menu_rounded,
                            color: colorScheme.onSurface,
                          ),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      'Work Overview',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        SlidePageRoute(page: const SynologyCompanyPdfScreen()),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: BorderSide(color: colorScheme.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: Icon(Icons.picture_as_pdf_outlined, size: 16, color: colorScheme.primary),
                      label: Text(
                        'Company PDF',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => showStaffLeaveRequestSheet(context, ref),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: BorderSide(color: colorScheme.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: Icon(Icons.time_to_leave_rounded, size: 16, color: colorScheme.primary),
                      label: Text(
                        'Request Leave',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        SlidePageRoute(page: const NotificationsScreen()),
                      ),
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: colorScheme.outline),
                            ),
                            child: Icon(
                              Icons.notifications_none_rounded,
                              color: colorScheme.onSurface,
                              size: 20,
                            ),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 1,
                              top: 1,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colorScheme.surface,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ref
              .watch(eventsStreamProvider)
              .when(
                data: (events) {
                  // Since staff assignment was removed, show all confirmed/active events
                  final assignedEvents = events
                      .where((e) => e.status != 'Draft')
                      .toList();

                  if (assignedEvents.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 64,
                            color: labelColor.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No active events found',
                            style: TextStyle(
                              fontSize: 18,
                              color: labelColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Summary Stats for Staff
                  final activeEvents = assignedEvents
                      .where((e) => e.status == 'In Progress')
                      .length;
                  final completedEvents = assignedEvents
                      .where((e) => e.status == 'Completed')
                      .length;

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(eventsStreamProvider);
                      ref.invalidate(allItemsStreamProvider);
                      ref.invalidate(notificationsStreamProvider);
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats Grid
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Consumer(
                              builder: (context, ref, _) {
                                final allItemsAsync = ref.watch(
                                  allItemsStreamProvider,
                                );
                                final allItems = allItemsAsync.maybeWhen(
                                  data: (items) => items,
                                  orElse: () => <OrderItemEntity>[],
                                );

                                final avgComp = assignedEvents.isEmpty
                                    ? 0.0
                                    : assignedEvents
                                              .map((e) {
                                                final orderItems = allItems
                                                    .where(
                                                      (i) =>
                                                          i.orderId ==
                                                          e.orderId,
                                                    )
                                                    .toList();
                                                final total = orderItems.length;
                                                final completed = orderItems
                                                    .where((i) => i.isCompleted)
                                                    .length;
                                                return total > 0
                                                    ? completed / total
                                                    : 0.0;
                                              })
                                              .reduce((a, b) => a + b) /
                                          assignedEvents.length;

                                return Row(
                                  children: [
                                    _buildStaffStatCard(
                                      'Active',
                                      activeEvents.toString(),
                                      colorScheme.primary,
                                    ),
                                    const SizedBox(width: 16),
                                    _buildStaffStatCard(
                                      'Done',
                                      completedEvents.toString(),
                                      colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 16),
                                    _buildStaffStatCard(
                                      'Progress',
                                      '${(avgComp * 100).toInt()}%',
                                      colorScheme.tertiary,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 32),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Ongoing Events',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: assignedEvents.length,
                            itemBuilder: (context, index) {
                              final event = assignedEvents[index];
                              return Consumer(
                                builder: (context, ref, _) {
                                  final allItemsAsync = ref.watch(
                                    allItemsStreamProvider,
                                  );
                                  final allItems = allItemsAsync.maybeWhen(
                                    data: (items) => items,
                                    orElse: () => <OrderItemEntity>[],
                                  );

                                  final orderItems = allItems
                                      .where((i) => i.orderId == event.orderId)
                                      .toList();
                                  final total = orderItems.length;
                                  final completed = orderItems
                                      .where((i) => i.isCompleted)
                                      .length;
                                  final completion = total > 0
                                      ? completed / total
                                      : 0.0;

                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 24.0,
                                    ),
                                    child: _buildEventCard(
                                      event: event,
                                      calculatedCompletion: completion,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => _buildShimmerLoading(context),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
        ),
      ],
    );
  }

  Widget _buildStaffStatCard(String label, String value, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard({
    required EventEntity event,
    required double calculatedCompletion,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;

    final statusColor = event.status == 'In Progress'
        ? colorScheme.primary
        : (event.status == 'Completed'
              ? colorScheme.secondary
              : colorScheme.tertiary);

    final dateStr = formatNepaliDate(event.date, 'MMM dd, yyyy');
    final completionText = '${(calculatedCompletion * 100).toInt()}% Completed';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  event.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.calendar_today, color: labelColor, size: 18),
              const SizedBox(width: 8),
              Text(dateStr, style: TextStyle(fontSize: 14, color: labelColor)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on, color: labelColor, size: 18),
              const SizedBox(width: 8),
              Text(
                event.location,
                style: TextStyle(fontSize: 14, color: labelColor),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Task Progress',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
              Text(
                completionText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: (calculatedCompletion * 100)
                      .toInt()
                      .clamp(0, 100)
                      .toInt(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Expanded(
                  flex:
                      (100 - (calculatedCompletion * 100).toInt().clamp(0, 100))
                          .toInt(),
                  child: const SizedBox(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      SlidePageRoute(page: EventTaskDetailScreen(event: event)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'View Tasks',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    return ShimmerLoading(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        itemBuilder: (context, index) => const OrderCardShimmer(),
      ),
    );
  }
}
