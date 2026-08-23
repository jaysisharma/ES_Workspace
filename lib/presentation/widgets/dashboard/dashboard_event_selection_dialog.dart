import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/event_entity.dart';
import 'package:order_app/presentation/providers/dashboard_strip_notifier.dart';

class DashboardEventSelectionDialog extends ConsumerStatefulWidget {
  final List<EventEntity> allEvents;

  const DashboardEventSelectionDialog({
    super.key,
    required this.allEvents,
  });

  static Future<void> show(BuildContext context, List<EventEntity> events) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DashboardEventSelectionDialog(allEvents: events),
    );
  }

  @override
  ConsumerState<DashboardEventSelectionDialog> createState() =>
      _DashboardEventSelectionDialogState();
}

class _DashboardEventSelectionDialogState
    extends ConsumerState<DashboardEventSelectionDialog> {
  late DashboardStripMode _selectedMode;
  late List<String> _selectedIds;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final currentState = ref.read(dashboardStripNotifierProvider);
    _selectedMode = currentState.mode;
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

    final availableEvents = List<EventEntity>.from(widget.allEvents);
    availableEvents.sort((a, b) => b.date.compareTo(a.date));

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
                        'Dashboard Events Strip',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          fontFamily: 'Manrope',
                        ),
                      ),
                      Text(
                        'Choose which events appear on the dashboard banner',
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
                  // Mode Selection Section
                  Text(
                    'FILTER MODE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Mode Cards Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: DashboardStripMode.values.map((mode) {
                      final isSelected = _selectedMode == mode;
                      IconData icon;
                      String subtitle;

                      switch (mode) {
                        case DashboardStripMode.thisWeek:
                          icon = Icons.date_range_rounded;
                          subtitle = 'Current week events';
                          break;
                        case DashboardStripMode.upcoming:
                          icon = Icons.upcoming_rounded;
                          subtitle = 'Today & future events';
                          break;
                        case DashboardStripMode.custom:
                          icon = Icons.push_pin_rounded;
                          subtitle = 'Handpicked selection';
                          break;
                        case DashboardStripMode.all:
                          icon = Icons.all_inbox_rounded;
                          subtitle = 'All active events';
                          break;
                      }

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => _selectedMode = mode),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.primary.withValues(alpha: 0.12)
                                  : isDark
                                      ? colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.3)
                                      : colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.outline.withValues(alpha: 0.2),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  icon,
                                  size: 20,
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        mode.label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          color: isSelected
                                              ? colorScheme.primary
                                              : colorScheme.onSurface,
                                        ),
                                      ),
                                      Text(
                                        subtitle,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Custom Selection Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'EVENT SELECTION',
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
                                  : colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.2),
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
                            child: const Text('Select All',
                                style: TextStyle(fontSize: 11)),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedIds.clear();
                              });
                            },
                            child: const Text('Clear',
                                style: TextStyle(fontSize: 11)),
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
                      hintText: 'Search events by name or location...',
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
                          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                        final isChecked = _selectedIds.contains(event.id);
                        final dateStr = _formatDate(event.date);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (isChecked) {
                                  _selectedIds.remove(event.id);
                                } else {
                                  _selectedIds.add(event.id);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isChecked
                                    ? colorScheme.primary.withValues(alpha: 0.08)
                                    : isDark
                                        ? colorScheme.surfaceContainerHighest
                                            .withValues(alpha: 0.2)
                                        : colorScheme.surfaceContainerHighest
                                            .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isChecked
                                      ? colorScheme.primary.withValues(alpha: 0.5)
                                      : colorScheme.outline.withValues(alpha: 0.15),
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
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          if (!_selectedIds.contains(event.id)) {
                                            _selectedIds.add(event.id);
                                          }
                                        } else {
                                          _selectedIds.remove(event.id);
                                        }
                                      });
                                    },
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
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              dateStr,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                            if (event.location.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Icon(
                                                Icons.location_on_outlined,
                                                size: 11,
                                                color: colorScheme.onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 2),
                                              Expanded(
                                                child: Text(
                                                  event.location,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        colorScheme.onSurfaceVariant,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
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
                                      color: colorScheme.primary
                                          .withValues(alpha: 0.1),
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
                      final notifier =
                          ref.read(dashboardStripNotifierProvider.notifier);
                      await notifier.setMode(_selectedMode);
                      await notifier.setSelectedEvents(_selectedIds);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Dashboard events strip updated (${_selectedMode.label})',
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
