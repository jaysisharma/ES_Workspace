import 'package:flutter/material.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';

enum AttendanceViewMode { day, month }

class AdminAttendanceFilterBarWidget extends StatefulWidget {
  final AttendanceViewMode viewMode;
  final ValueChanged<AttendanceViewMode> onViewModeChanged;
  final DateTime selectedDate;
  final VoidCallback onPickDate;
  final VoidCallback onPickMonth;
  final String? selectedStaffId;
  final List<UserEntity> staffList;
  final ValueChanged<String?> onStaffChanged;
  final String searchQuery;
  final ValueChanged<String> onSearchQueryChanged;
  final bool showOnlyOutOfBounds;
  final ValueChanged<bool> onOutOfBoundsToggled;

  const AdminAttendanceFilterBarWidget({
    super.key,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.selectedDate,
    required this.onPickDate,
    required this.onPickMonth,
    required this.selectedStaffId,
    required this.staffList,
    required this.onStaffChanged,
    required this.searchQuery,
    required this.onSearchQueryChanged,
    required this.showOnlyOutOfBounds,
    required this.onOutOfBoundsToggled,
  });

  @override
  State<AdminAttendanceFilterBarWidget> createState() =>
      _AdminAttendanceFilterBarWidgetState();
}

class _AdminAttendanceFilterBarWidgetState
    extends State<AdminAttendanceFilterBarWidget> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant AdminAttendanceFilterBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery &&
        _searchController.text != widget.searchQuery) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nepaliDateLabel = formatNepaliDate(widget.selectedDate, 'yyyy MMMM dd');
    final nepaliMonthLabel = formatNepaliDate(widget.selectedDate, 'yyyy MMMM');

    // Filter staff list by search query if typed
    final filteredStaff = widget.staffList.where((staff) {
      if (widget.searchQuery.isEmpty) return true;
      final q = widget.searchQuery.toLowerCase();
      return staff.name.toLowerCase().contains(q) ||
          staff.email.toLowerCase().contains(q);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: View Mode Switcher + Nepali Date/Month Picker Trigger
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Segmented View Switcher
              SegmentedButton<AttendanceViewMode>(
                segments: const [
                  ButtonSegment(
                    value: AttendanceViewMode.day,
                    label: Text('Day View'),
                    icon: Icon(Icons.today_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: AttendanceViewMode.month,
                    label: Text('Month View'),
                    icon: Icon(Icons.calendar_month_rounded, size: 16),
                  ),
                ],
                selected: {widget.viewMode},
                onSelectionChanged: (set) => widget.onViewModeChanged(set.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),

              // Nepali BS Date Button
              OutlinedButton.icon(
                onPressed: widget.viewMode == AttendanceViewMode.day
                    ? widget.onPickDate
                    : widget.onPickMonth,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: colorScheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(
                  widget.viewMode == AttendanceViewMode.day
                      ? Icons.calendar_today
                      : Icons.date_range_rounded,
                  size: 15,
                  color: colorScheme.primary,
                ),
                label: Text(
                  widget.viewMode == AttendanceViewMode.day
                      ? '$nepaliDateLabel BS'
                      : '$nepaliMonthLabel BS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Search Staff Input Field
          TextField(
            controller: _searchController,
            onChanged: widget.onSearchQueryChanged,
            decoration: InputDecoration(
              hintText: 'Search staff by name or email...',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: widget.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        widget.onSearchQueryChanged('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              isDense: true,
              filled: true,
              fillColor: colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Row 3: Specified Employee Dropdown
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: widget.selectedStaffId,
                      isExpanded: true,
                      hint: const Text('All Employees'),
                      icon: const Icon(Icons.person_search_rounded, size: 20),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'All Employees (Company Wide)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...filteredStaff.map((staff) {
                          return DropdownMenuItem<String?>(
                            value: staff.id,
                            child: Text(
                              '${staff.name} (${staff.role.name.toUpperCase()})',
                            ),
                          );
                        }),
                      ],
                      onChanged: widget.onStaffChanged,
                    ),
                  ),
                ),
              ),

              if (widget.selectedStaffId != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Clear Employee Selection',
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  onPressed: () => widget.onStaffChanged(null),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
