import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/event_entity.dart';
import 'package:order_app/presentation/providers/dashboard_strip_notifier.dart';
import 'package:order_app/presentation/providers/event_providers.dart';
import 'package:order_app/presentation/providers/order_providers.dart';

class DashboardEventSelectionDialog extends ConsumerStatefulWidget {
  final List<EventEntity> allEvents;

  const DashboardEventSelectionDialog({super.key, this.allEvents = const []});

  static Future<void> show(BuildContext context, [List<EventEntity>? events]) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          DashboardEventSelectionDialog(allEvents: events ?? const []),
    );
  }

  @override
  ConsumerState<DashboardEventSelectionDialog> createState() =>
      _DashboardEventSelectionDialogState();
}

class _DashboardEventSelectionDialogState
    extends ConsumerState<DashboardEventSelectionDialog> {
  late List<String> _selectedIds;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final currentState = ref.read(dashboardStripNotifierProvider);
    _selectedIds = List<String>.from(currentState.selectedEventIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    try {
      return formatNepaliDate(date, 'd MMMM, yyyy');
    } catch (_) {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final eventsAsync = ref.watch(eventsStreamProvider);
    final ordersAsync = ref.watch(ordersStreamProvider);
    final orderState = ref.watch(orderNotifierProvider);

    final rawEvents = eventsAsync.value ?? widget.allEvents;
    final orders = (ordersAsync.value ?? orderState.orders)
        .where((o) => !o.isArchived)
        .toList();
    final orderMap = {for (final o in orders) o.id: o};

    final activeEvents = rawEvents.where((e) => !e.isArchived).map((e) {
      final linkedOrder = orderMap[e.orderId];
      if (linkedOrder != null) {
        return e.copyWith(
          date: linkedOrder.eventDate,
          title: linkedOrder.eventName.isNotEmpty
              ? linkedOrder.eventName
              : e.title,
          location: linkedOrder.venue.isNotEmpty
              ? linkedOrder.venue
              : e.location,
          isArchived: linkedOrder.isArchived,
        );
      }
      return e;
    }).toList();

    final existingOrderIds = activeEvents.map((e) => e.orderId).toSet();
    final orderEvents = orders
        .where((o) => !existingOrderIds.contains(o.id))
        .map(
          (o) => EventEntity(
            id: 'ord_evt_${o.id}',
            orderId: o.id,
            title: o.eventName.isNotEmpty ? o.eventName : 'Event #${o.id}',
            date: o.eventDate,
            location: o.venue,
            role: 'Order',
            status: o.status.name,
            completion: 0.0,
          ),
        )
        .toList();

    final allCombinedEvents = [...activeEvents, ...orderEvents];

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final availableEvents = allCombinedEvents.where((e) {
      final localDate = e.date.toLocal();
      final eventDay = DateTime(localDate.year, localDate.month, localDate.day);
      return !eventDay.isBefore(todayStart);
    }).toList();
    availableEvents.sort((a, b) => a.date.compareTo(b.date));

    final filteredEvents = availableEvents.where((e) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return e.title.toLowerCase().contains(q) ||
          e.location.toLowerCase().contains(q) ||
          e.status.toLowerCase().contains(q);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Strip Events',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          fontFamily: 'Manrope',
                        ),
                      ),
                      Text(
                        'Choose the events you want to display on the dashboard strip',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),

          // Content Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Count & Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'EVENTS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedIds.isNotEmpty
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant.withValues(
                                      alpha: 0.2,
                                    ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_selectedIds.length} selected',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _selectedIds.isNotEmpty
                                    ? Colors.white
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedIds = availableEvents
                                    .map((e) => e.id)
                                    .toList();
                              });
                            },
                            child: const Text(
                              'Select All',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedIds.clear();
                              });
                            },
                            child: const Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search events by name, venue...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.3,
                            )
                          : colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.5,
                            ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Events List
                  if (filteredEvents.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'No events match "$_searchQuery"'
                              : 'No active events available',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredEvents.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final event = filteredEvents[index];
                        final isChecked =
                            _selectedIds.contains(event.id) ||
                            (event.orderId.isNotEmpty &&
                                _selectedIds.contains(event.orderId));
                        final dateStr = _formatDate(event.date);

                        void toggleEventSelection(bool select) {
                          setState(() {
                            if (select) {
                              if (!_selectedIds.contains(event.id)) {
                                _selectedIds.add(event.id);
                              }
                              if (event.orderId.isNotEmpty &&
                                  !_selectedIds.contains(event.orderId)) {
                                _selectedIds.add(event.orderId);
                              }
                            } else {
                              _selectedIds.remove(event.id);
                              _selectedIds.remove(event.orderId);
                              _selectedIds.remove('ord_evt_${event.orderId}');
                            }
                          });
                        }

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => toggleEventSelection(!isChecked),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isChecked
                                    ? colorScheme.primary.withValues(
                                        alpha: 0.08,
                                      )
                                    : isDark
                                    ? colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.2)
                                    : colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isChecked
                                      ? colorScheme.primary.withValues(
                                          alpha: 0.5,
                                        )
                                      : colorScheme.outline.withValues(
                                          alpha: 0.15,
                                        ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isChecked,
                                    activeColor: colorScheme.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    onChanged: (val) =>
                                        toggleEventSelection(val == true),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          event.title,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today_rounded,
                                              size: 11,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              dateStr,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                            if (event.location.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Icon(
                                                Icons.location_on_outlined,
                                                size: 11,
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 2),
                                              Expanded(
                                                child: Text(
                                                  event.location,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      event.status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final notifier = ref.read(
                        dashboardStripNotifierProvider.notifier,
                      );
                      await notifier.setSelectedEvents(_selectedIds);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Dashboard strip updated (${_selectedIds.length} events selected)',
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text(
                      'Save & Apply',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
