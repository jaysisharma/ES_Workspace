import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:order_app/domain/entities/event_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/providers/dashboard_strip_notifier.dart';
import 'package:order_app/presentation/screens/common/events/calendar_event_detail_screen.dart';
import 'dashboard_event_selection_dialog.dart';

class ThisWeekEventsStrip extends ConsumerStatefulWidget {
  final List<EventEntity> events;

  const ThisWeekEventsStrip({super.key, required this.events});

  @override
  ConsumerState<ThisWeekEventsStrip> createState() =>
      _ThisWeekEventsStripState();
}

class _ThisWeekEventsStripState extends ConsumerState<ThisWeekEventsStrip> {
  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  bool _isUserInteracting = false;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    // Scroll every 35 milliseconds continuously
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 35), (
      timer,
    ) {
      if (!_scrollController.hasClients || _isUserInteracting) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;

      if (maxScroll <= 0) return;

      if (currentScroll >= maxScroll - 2) {
        // Reset to start smoothly when reaching the end
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(
          currentScroll + 1.2,
          duration: const Duration(milliseconds: 35),
          curve: Curves.linear,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatEventDate(DateTime date) {
    try {
      final nepaliStr = formatNepaliDate(date, 'd MMMM');
      return nepaliStr;
    } catch (_) {
      return DateFormat('d MMM').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final stripState = ref.watch(dashboardStripNotifierProvider);
    final authState = ref.watch(authNotifierProvider);
    final isAdminOrFounder = authState.user?.role == UserRole.admin ||
        authState.user?.role == UserRole.founder;

    // Fallback: Combine active orders if EventEntity records are not explicitly created
    final ordersAsync = ref.watch(ordersStreamProvider);
    final orders = ordersAsync.value ?? [];

    final existingOrderIds = widget.events.map((e) => e.orderId).toSet();
    final orderEvents = orders
        .where((o) => !existingOrderIds.contains(o.id))
        .map((o) => EventEntity(
              id: 'ord_evt_${o.id}',
              orderId: o.id,
              title: o.eventName.isNotEmpty ? o.eventName : 'Event #${o.id}',
              date: o.eventDate,
              location: o.venue,
              role: 'Order',
              status: o.status.name,
              completion: 0.0,
            ))
        .toList();

    final allEvents = [...widget.events, ...orderEvents];

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    // Monday of current week
    final startOfWeek = todayStart.subtract(Duration(days: now.weekday - 1));
    // Sunday of current week
    final endOfWeek = startOfWeek.add(
      const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
    );

    // Filter events based on active mode with timezone safety
    List<EventEntity> filteredEvents;
    switch (stripState.mode) {
      case DashboardStripMode.thisWeek:
        filteredEvents = allEvents.where((e) {
          if (e.isArchived) return false;
          final localDate = e.date.toLocal();
          final eventDay = DateTime(localDate.year, localDate.month, localDate.day);
          return (eventDay.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
                  eventDay.isBefore(endOfWeek)) ||
                 DateUtils.isSameDay(localDate, now);
        }).toList();
        break;
      case DashboardStripMode.upcoming:
        filteredEvents = allEvents.where((e) {
          if (e.isArchived) return false;
          final localDate = e.date.toLocal();
          final eventDay = DateTime(localDate.year, localDate.month, localDate.day);
          return eventDay.isAfter(todayStart.subtract(const Duration(seconds: 1))) ||
                 DateUtils.isSameDay(localDate, now);
        }).toList();
        break;
      case DashboardStripMode.custom:
        filteredEvents = allEvents.where((e) {
          if (e.isArchived) return false;
          return stripState.selectedEventIds.contains(e.id) ||
                 stripState.selectedEventIds.contains(e.orderId);
        }).toList();
        break;
      case DashboardStripMode.all:
        filteredEvents = allEvents.where((e) => !e.isArchived).toList();
        break;
    }

    // Sort chronologically
    filteredEvents.sort((a, b) => a.date.compareTo(b.date));

    // Duplicate list for infinite smooth marquee effect when events are present
    final displayEvents = filteredEvents.length > 1
        ? [...filteredEvents, ...filteredEvents, ...filteredEvents]
        : filteredEvents;

    final emptyMessage = stripState.mode == DashboardStripMode.custom
        ? 'No custom events selected'
        : stripState.mode == DashboardStripMode.upcoming
            ? 'No upcoming events scheduled'
            : 'No events scheduled for this week';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Listener(
        onPointerDown: (_) => setState(() => _isUserInteracting = true),
        onPointerUp: (_) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _isUserInteracting = false);
          });
        },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.45)
                : colorScheme.primaryContainer.withValues(alpha: 0.22),
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left Highlighted Marquee / Info Tag
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.campaign_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      stripState.mode.badgeText,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Auto-scrolling Ticker Content
              Expanded(
                child: displayEvents.isEmpty
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          emptyMessage,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.trackpad,
                            PointerDeviceKind.stylus,
                          },
                        ),
                        child: ListView.separated(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          itemCount: displayEvents.length,
                        separatorBuilder: (context, index) => Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 15,
                          ),
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                        ),
                        itemBuilder: (context, index) {
                          final event = displayEvents[index];
                          final dateStr = _formatEventDate(event.date);
                          final isToday = DateUtils.isSameDay(event.date, now);

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => Navigator.push(
                                context,
                                SlidePageRoute(
                                  page: CalendarEventDetailScreen.fromEvent(
                                    event: event,
                                  ),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Highlighted Date Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isToday
                                            ? const Color(0xFFD97706)
                                            : const Color(0xFF10B981),
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (isToday
                                                    ? const Color(0xFFD97706)
                                                    : const Color(0xFF10B981))
                                                .withValues(alpha: 0.25),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        isToday
                                            ? 'TODAY · $dateStr'
                                            : dateStr,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Event Title with Highlight
                                    Text(
                                      event.title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
              ),

              // Admin Event Selector Tool Button
              if (isAdminOrFounder)
                IconButton(
                  icon: Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  tooltip: 'Configure Strip Events',
                  onPressed: () => DashboardEventSelectionDialog.show(
                    context,
                    widget.events,
                  ),
                ),

            ],
          ),
        ),
      ),
    );
  }
}
