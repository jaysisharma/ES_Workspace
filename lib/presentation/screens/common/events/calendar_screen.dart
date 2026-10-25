import 'package:flutter/material.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/presentation/providers/event_providers.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/domain/entities/event_entity.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/screens/common/events/calendar_event_detail_screen.dart';
import 'package:order_app/presentation/screens/common/orders/create_order_screen.dart';
import 'package:order_app/core/calendar/nepali_calendar_engine.dart';
import 'package:order_app/presentation/widgets/calendar/nepali_calendar_view.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';

import '../orders/order_details_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class CalendarItem {
  final DateTime time;
  final dynamic data;
  CalendarItem(this.time, this.data);
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  final GlobalKey _eventsListKey = GlobalKey();
  DateTime _selectedDate = DateTime.now();
  bool _isCalendarExpanded = true;
  bool _isDayFiltered = false;

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsStreamProvider);
    final ordersAsync = ref.watch(ordersStreamProvider);
    final authState = ref.watch(authNotifierProvider);
    final isAdminOrFounder = authState.user?.role.canEditOrder ?? false;

    final selectedNepali = safeDateTimeToNepali(_selectedDate);

    final orderState = ref.watch(orderNotifierProvider);
    final allOrders = (ordersAsync.value ?? orderState.orders);
    final orderMap = {for (final o in allOrders) o.id: o};

    // Dynamically resolve event details from parent order to ensure up-to-date dates & locations
    final resolvedEvents = (eventsAsync.value ?? []).map((e) {
      final linkedOrder = orderMap[e.orderId];
      if (linkedOrder != null) {
        return e.copyWith(
          date: linkedOrder.eventDate,
          title: linkedOrder.eventName.isNotEmpty ? linkedOrder.eventName : e.title,
          location: linkedOrder.venue.isNotEmpty ? linkedOrder.venue : e.location,
          isArchived: linkedOrder.isArchived,
        );
      }
      return e;
    }).toList();

    // Filtered unified events for the timeline — filter by Nepali month/year with multi-day range support
    final totalDaysInCurrentMonth = NepaliCalendarEngine.daysInMonth(
      selectedNepali.year,
      selectedNepali.month,
    );
    final monthStart = NepaliDateTime(selectedNepali.year, selectedNepali.month, 1);
    final monthEnd = NepaliDateTime(selectedNepali.year, selectedNepali.month, totalDaysInCurrentMonth);

    final monthEvents = resolvedEvents.where((e) {
      if (e.isArchived) return false;
      final startNp = safeDateTimeToNepali(e.date);
      final linkedOrder = orderMap[e.orderId];
      final rawEndNp = linkedOrder?.eventEndDate != null
          ? safeDateTimeToNepali(linkedOrder!.eventEndDate!)
          : startNp;
      final endNp = rawEndNp.isBefore(startNp) ? startNp : rawEndNp;
      final startDayOnly = NepaliDateTime(startNp.year, startNp.month, startNp.day);
      final endDayOnly = NepaliDateTime(endNp.year, endNp.month, endNp.day);

      return !endDayOnly.isBefore(monthStart) && !startDayOnly.isAfter(monthEnd);
    }).toList();

    final monthOrders = allOrders.where((o) {
      if (o.isArchived) return false;
      if (o.status == OrderStatus.draft) return false;
      final startNp = safeDateTimeToNepali(o.eventDate);
      final rawEndNp = o.eventEndDate != null
          ? safeDateTimeToNepali(o.eventEndDate!)
          : startNp;
      final endNp = rawEndNp.isBefore(startNp) ? startNp : rawEndNp;
      final startDayOnly = NepaliDateTime(startNp.year, startNp.month, startNp.day);
      final endDayOnly = NepaliDateTime(endNp.year, endNp.month, endNp.day);

      return !endDayOnly.isBefore(monthStart) && !startDayOnly.isAfter(monthEnd);
    }).toList();

    // Orders that already have a linked event should not appear separately
    final eventOrderIds = monthEvents.map((e) => e.orderId).toSet();
    final ordersWithoutEvent = monthOrders.where(
      (o) => !eventOrderIds.contains(o.id),
    ).toList();

    // Calculate direct Bikram Sambat day counts (1..totalDays)
    final eventCountsByDay = <int, int>{};
    final orderCountsByDay = <int, int>{};

    for (int day = 1; day <= totalDaysInCurrentMonth; day++) {
      final currentDayNp = NepaliDateTime(selectedNepali.year, selectedNepali.month, day);

      int eventCount = 0;
      for (final e in monthEvents) {
        final startNp = safeDateTimeToNepali(e.date);
        final linkedOrder = orderMap[e.orderId];
        final rawEndNp = linkedOrder?.eventEndDate != null
            ? safeDateTimeToNepali(linkedOrder!.eventEndDate!)
            : startNp;
        final endNp = rawEndNp.isBefore(startNp) ? startNp : rawEndNp;
        final startDayOnly = NepaliDateTime(startNp.year, startNp.month, startNp.day);
        final endDayOnly = NepaliDateTime(endNp.year, endNp.month, endNp.day);

        if (!currentDayNp.isBefore(startDayOnly) && !currentDayNp.isAfter(endDayOnly)) {
          eventCount++;
        }
      }
      if (eventCount > 0) {
        eventCountsByDay[day] = eventCount;
      }

      int orderCount = 0;
      for (final o in ordersWithoutEvent) {
        final startNp = safeDateTimeToNepali(o.eventDate);
        final rawEndNp = o.eventEndDate != null
            ? safeDateTimeToNepali(o.eventEndDate!)
            : startNp;
        final endNp = rawEndNp.isBefore(startNp) ? startNp : rawEndNp;
        final startDayOnly = NepaliDateTime(startNp.year, startNp.month, startNp.day);
        final endDayOnly = NepaliDateTime(endNp.year, endNp.month, endNp.day);

        if (!currentDayNp.isBefore(startDayOnly) && !currentDayNp.isAfter(endDayOnly)) {
          orderCount++;
        }
      }
      if (orderCount > 0) {
        orderCountsByDay[day] = orderCount;
      }
    }

    final selectedDayNp = NepaliDateTime(
      selectedNepali.year,
      selectedNepali.month,
      selectedNepali.day,
    );
    final dayEvents = monthEvents.where((e) {
      final startNp = safeDateTimeToNepali(e.date);
      final linkedOrder = orderMap[e.orderId];
      final rawEndNp = linkedOrder?.eventEndDate != null
          ? safeDateTimeToNepali(linkedOrder!.eventEndDate!)
          : startNp;
      final endNp = rawEndNp.isBefore(startNp) ? startNp : rawEndNp;
      final startDayOnly = NepaliDateTime(startNp.year, startNp.month, startNp.day);
      final endDayOnly = NepaliDateTime(endNp.year, endNp.month, endNp.day);
      return !selectedDayNp.isBefore(startDayOnly) && !selectedDayNp.isAfter(endDayOnly);
    }).toList();

    final dayOrders = ordersWithoutEvent.where((o) {
      final startNp = safeDateTimeToNepali(o.eventDate);
      final rawEndNp = o.eventEndDate != null
          ? safeDateTimeToNepali(o.eventEndDate!)
          : startNp;
      final endNp = rawEndNp.isBefore(startNp) ? startNp : rawEndNp;
      final startDayOnly = NepaliDateTime(startNp.year, startNp.month, startNp.day);
      final endDayOnly = NepaliDateTime(endNp.year, endNp.month, endNp.day);
      return !selectedDayNp.isBefore(startDayOnly) && !selectedDayNp.isAfter(endDayOnly);
    }).toList();

    // Decide which list to show based on filtering state
    final displayEvents = _isDayFiltered ? dayEvents : monthEvents.toList();
    final displayOrders = _isDayFiltered
        ? dayOrders
        : ordersWithoutEvent.toList();

    final unifiedList = [
      ...displayEvents.map((e) => CalendarItem(e.date, e)),
      ...displayOrders.map((o) => CalendarItem(o.eventDate, o)),
    ]..sort((a, b) => a.time.compareTo(b.time));

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final primaryColor = const Color(0xFF0075db);
    final bgColor = isDarkMode
        ? const Color(0xFF0b0f13)
        : const Color(0xFFf5f7f8);
    final cardColor = isDarkMode ? const Color(0xFF1a1f26) : Colors.white;
    final borderColor = isDarkMode
        ? const Color(0xFF262f3a)
        : const Color(0xFFf1f5f9);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final labelColor = isDarkMode
        ? const Color(0xFF94a3b8)
        : const Color(0xFF64748b);

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: const BottomRightBackButton(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.9),
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 6.0,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 360;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (Navigator.canPop(context))
                          IconButton(
                            icon: Icon(Icons.arrow_back, color: textColor),
                            onPressed: () => Navigator.pop(context),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          )
                        else if (MediaQuery.of(context).size.width < 768)
                          Builder(
                            builder: (context) => IconButton(
                              icon: Icon(Icons.menu_rounded, color: textColor),
                              onPressed: () => Scaffold.of(context).openDrawer(),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Event Calendar',
                              style: TextStyle(
                                fontSize: isCompact ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              formatNepaliDate(_selectedDate, 'MMMM yyyy'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        _isCalendarExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: primaryColor,
                        size: 22,
                      ),
                      onPressed: () {
                        setState(() {
                          _isCalendarExpanded = !_isCalendarExpanded;
                        });
                      },
                      tooltip: _isCalendarExpanded ? 'Collapse Calendar' : 'Expand Calendar',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isCalendarExpanded)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14.0,
                  vertical: 8.0,
                ),
                child: NepaliCalendarView(
                  selectedDate: selectedNepali,
                  eventCountsByDay: eventCountsByDay,
                  orderCountsByDay: orderCountsByDay,
                  onMonthChanged: (newNepaliDate) {
                    setState(() {
                      _selectedDate = safeNepaliToDateTime(newNepaliDate);
                      _isDayFiltered = false;
                    });
                  },
                  onDateSelected: (nepaliDate) {
                    final targetDate = safeNepaliToDateTime(nepaliDate);

                    // If user taps the already-selected day, toggle back to full month view
                    if (_isDayFiltered &&
                        DateUtils.isSameDay(_selectedDate, targetDate)) {
                      setState(() {
                        _isDayFiltered = false;
                      });
                      return;
                    }

                    setState(() {
                      _selectedDate = targetDate;
                      _isDayFiltered = true;
                    });

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      final targetCtx = _eventsListKey.currentContext;
                      if (targetCtx != null && targetCtx.mounted) {
                        final ro = targetCtx.findRenderObject();
                        if (ro != null && ro.attached) {
                          Scrollable.ensureVisible(
                            targetCtx,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        }
                      }
                    });
                  },
                ),
              ),

            // Monthly Day Header
            Padding(
              key: _eventsListKey,
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isDayFiltered
                              ? '${formatNepaliDate(_selectedDate, 'MMMM dd')} Focus'
                              : '${formatNepaliDate(_selectedDate, 'MMMM')} Overview',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: labelColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _isDayFiltered
                              ? 'Events for this specific day'
                              : 'All events for this month',
                          style: TextStyle(
                            fontSize: 12,
                            color: labelColor.withValues(alpha: 0.7),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (_isDayFiltered) ...[
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isDayFiltered = false;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  size: 13,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Show Whole Month',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${unifiedList.length} Items',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Vertical timeline/events list
            eventsAsync.when(
              data: (_) {
                if (unifiedList.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 40,
                      horizontal: 20,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 48,
                            color: labelColor.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isDayFiltered
                                ? 'No events scheduled for this day'
                                : 'No events scheduled for this month',
                            style: TextStyle(color: labelColor, fontSize: 13),
                          ),
                          if (_isDayFiltered && isAdminOrFounder) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  SlidePageRoute(
                                    page: CreateOrderScreen(
                                      initialDate: _selectedDate,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 18,
                              ),
                              label: const Text('Create Order for this Date'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                  ).copyWith(bottom: 100),
                  itemCount: unifiedList.length,
                  itemBuilder: (context, index) {
                    final item = unifiedList[index];
                    final data = item.data;
                    final eventData = data is EventEntity ? data : null;
                    final orderData = data is OrderEntity ? data : null;
                    final isEvent = eventData != null;
                    final isOrder = orderData != null;

                    final title = isEvent
                        ? eventData.title
                        : orderData!.eventName;
                    final location = isEvent
                        ? eventData.location
                        : orderData!.venue;
                    final time = item.time;
                    final isLast = index == unifiedList.length - 1;

                    // Resolve date range
                    DateTime? endDate;
                    if (isEvent) {
                      final allOrders = ordersAsync.maybeWhen(
                        data: (o) => o,
                        orElse: () => <OrderEntity>[],
                      );
                      final linked = allOrders.cast<OrderEntity?>().firstWhere(
                        (o) => o!.id == eventData.orderId,
                        orElse: () => null,
                      );
                      endDate = linked?.eventEndDate;
                    } else if (isOrder) {
                      endDate = orderData.eventEndDate;
                    }
                    final startDate = isEvent
                        ? eventData.date
                        : orderData!.eventDate;

                    Color itemColor;
                    if (isEvent) {
                      itemColor =
                          data.color ??
                          (data.status == 'In Progress'
                              ? const Color(0xFF3b82f6)
                              : const Color(0xFFf59e0b));
                    } else {
                      switch (data.status) {
                        case OrderStatus.confirmed:
                          itemColor = primaryColor;
                          break;
                        case OrderStatus.inProgress:
                          itemColor = const Color(0xFFf59e0b);
                          break;
                        case OrderStatus.completed:
                          itemColor = const Color(0xFF10b981);
                          break;
                        default:
                          itemColor = labelColor;
                      }
                    }

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Timeline column
                          SizedBox(
                            width: 60,
                            child: Column(
                              children: [
                                Text(
                                  formatNepaliDate(time, 'dd'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                                Text(
                                  formatNepaliDate(time, 'E'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: labelColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  DateFormat('hh:mm').format(time),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  DateFormat('a').format(time),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: labelColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: isLast
                                      ? const SizedBox()
                                      : Container(width: 2, color: borderColor),
                                ),
                              ],
                            ),
                          ),

                          // Timeline dot
                          Column(
                            children: [
                              const SizedBox(height: 4),
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color:
                                      (isEvent && data.status == 'In Progress')
                                      ? bgColor
                                      : itemColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: itemColor,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),

                          // Event Card
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 24.0),
                              child: GestureDetector(
                                onTap: () {
                                  if (isEvent) {
                                    Navigator.push(
                                      context,
                                      SlidePageRoute(
                                        page:
                                            CalendarEventDetailScreen.fromEvent(
                                              event: eventData,
                                            ),
                                      ),
                                    );
                                  } else if (isOrder) {
                                    Navigator.push(
                                      context,
                                      SlidePageRoute(
                                        page: OrderDetailsScreen(
                                          order: orderData,
                                          fromCalendar: true,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: borderColor),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.02,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: itemColor.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              isEvent ? 'EVENT' : (data is OrderEntity && data.orderType.toLowerCase() == 'rental' ? 'RENTAL' : 'ORDER'),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: itemColor,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          if (isEvent &&
                                              data.status == 'In Progress')
                                            const Icon(
                                              Icons.sync,
                                              size: 16,
                                              color: Color(0xFF3b82f6),
                                            ),
                                          if (isOrder &&
                                              data.status ==
                                                  OrderStatus.inProgress)
                                            const Icon(
                                              Icons.sync,
                                              size: 16,
                                              color: Color(0xFFf59e0b),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.location_on_outlined,
                                            size: 14,
                                            color: labelColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              location,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: labelColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_month_outlined,
                                            size: 14,
                                            color: itemColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            endDate != null &&
                                                    endDate.year ==
                                                        startDate.year &&
                                                    endDate.month ==
                                                        startDate.month &&
                                                    endDate.day == startDate.day
                                                ? formatNepaliDate(
                                                    startDate,
                                                    'MMMM dd, yyyy',
                                                  )
                                                : endDate != null
                                                ? '${formatNepaliDate(startDate, 'MMMM dd')} – ${formatNepaliDate(endDate, 'MMMM dd, yyyy')}'
                                                : formatNepaliDate(
                                                    startDate,
                                                    'MMMM dd, yyyy',
                                                  ),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: itemColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text(
                  'Error: $err',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
