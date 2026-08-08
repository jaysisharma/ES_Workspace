import 'package:flutter/material.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';

class CustomNepaliCalendarWidget extends StatefulWidget {
  final NepaliDateTime selectedDate;
  final ValueChanged<NepaliDateTime> onDateSelected;
  final NepaliDateTime? rangeStartDate;
  final NepaliDateTime? rangeEndDate;
  final Set<DateTime> eventDates;
  final Map<DateTime, int>? eventCounts;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;

  const CustomNepaliCalendarWidget({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.rangeStartDate,
    this.rangeEndDate,
    this.eventDates = const {},
    this.eventCounts,
    this.isExpanded = true,
    this.onToggleExpand,
  });

  @override
  State<CustomNepaliCalendarWidget> createState() =>
      _CustomNepaliCalendarWidgetState();
}

class _CustomNepaliCalendarWidgetState
    extends State<CustomNepaliCalendarWidget> {
  late int _currentYear;
  late int _currentMonth;

  static const List<String> nepaliMonthsEnglish = [
    'Baisakh',
    'Jestha',
    'Asar',
    'Shrawan',
    'Bhadra',
    'Ashwin',
    'Kartik',
    'Mangsir',
    'Poush',
    'Magh',
    'Falgun',
    'Chaitra',
  ];

  static const List<String> weekdaysEnglish = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  @override
  void initState() {
    super.initState();
    _currentYear = widget.selectedDate.year;
    _currentMonth = widget.selectedDate.month;
  }

  @override
  void didUpdateWidget(covariant CustomNepaliCalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate.year != widget.selectedDate.year ||
        oldWidget.selectedDate.month != widget.selectedDate.month) {
      setState(() {
        _currentYear = widget.selectedDate.year;
        _currentMonth = widget.selectedDate.month;
      });
    }
  }

  void _previousMonth() {
    setState(() {
      if (_currentMonth == 1) {
        _currentMonth = 12;
        _currentYear--;
      } else {
        _currentMonth--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_currentMonth == 12) {
        _currentMonth = 1;
        _currentYear++;
      } else {
        _currentMonth++;
      }
    });
  }

  void _goToToday() {
    final nowNp = NepaliDateTime.now();
    setState(() {
      _currentYear = nowNp.year;
      _currentMonth = nowNp.month;
    });
    widget.onDateSelected(nowNp);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = colorScheme.primary;

    final todayNp = NepaliDateTime.now();
    final firstDayOfMonth = NepaliDateTime(_currentYear, _currentMonth, 1);
    final totalDaysInMonth = firstDayOfMonth.totalDays;

    // NepaliDateTime weekday: 1 = Sunday, 7 = Saturday in nepali_utils
    final startWeekdayOffset = firstDayOfMonth.weekday - 1; // 0 to 6

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Calendar Top Header ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                // Month Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _currentMonth,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: colorScheme.onSurface,
                      ),
                      items: List.generate(12, (i) {
                        final monthNum = i + 1;
                        return DropdownMenuItem(
                          value: monthNum,
                          child: Text(nepaliMonthsEnglish[i]),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _currentMonth = val);
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Year Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _currentYear,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: colorScheme.onSurface,
                      ),
                      items: List.generate(15, (i) {
                        final y = 2075 + i;
                        return DropdownMenuItem(
                          value: y,
                          child: Text('$y BS'),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _currentYear = val);
                        }
                      },
                    ),
                  ),
                ),

                const Spacer(),

                // Today Button
                InkWell(
                  onTap: _goToToday,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // Prev / Next Month Buttons
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 22),
                  onPressed: _previousMonth,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Previous Month',
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 22),
                  onPressed: _nextMonth,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Next Month',
                ),
              ],
            ),
          ),

          if (widget.isExpanded) ...[
            const SizedBox(height: 10),

            // ── Weekday Labels Header ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: List.generate(7, (index) {
                  final isSaturday = index == 6;
                  return Expanded(
                    child: Center(
                      child: Text(
                        weekdaysEnglish[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSaturday
                              ? Colors.red
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 6),

            // ── Calendar Days Grid ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 42, // 6 rows * 7 columns
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1.1,
                ),
                itemBuilder: (context, index) {
                  final dayNumber = index - startWeekdayOffset + 1;
                  final isValidDay =
                      dayNumber >= 1 && dayNumber <= totalDaysInMonth;

                  if (!isValidDay) {
                    return const SizedBox.shrink();
                  }

                  final currentDayNp = NepaliDateTime(
                    _currentYear,
                    _currentMonth,
                    dayNumber,
                  );
                  final currentDayAd = safeNepaliToDateTime(currentDayNp);

                  final isSelected =
                      widget.selectedDate.year == _currentYear &&
                      widget.selectedDate.month == _currentMonth &&
                      widget.selectedDate.day == dayNumber;

                  final isStartOfRange = widget.rangeStartDate != null &&
                      widget.rangeStartDate!.year == _currentYear &&
                      widget.rangeStartDate!.month == _currentMonth &&
                      widget.rangeStartDate!.day == dayNumber;

                  final isEndOfRange = widget.rangeEndDate != null &&
                      widget.rangeEndDate!.year == _currentYear &&
                      widget.rangeEndDate!.month == _currentMonth &&
                      widget.rangeEndDate!.day == dayNumber;

                  final isInRange = widget.rangeStartDate != null &&
                      widget.rangeEndDate != null &&
                      (currentDayNp.isAfter(widget.rangeStartDate!) || isStartOfRange) &&
                      (currentDayNp.isBefore(widget.rangeEndDate!) || isEndOfRange);

                  final isToday =
                      todayNp.year == _currentYear &&
                      todayNp.month == _currentMonth &&
                      todayNp.day == dayNumber;

                  final isSaturday = (index % 7) == 6;

                  final hasEvent = widget.eventDates.any(
                    (d) =>
                        d.year == currentDayAd.year &&
                        d.month == currentDayAd.month &&
                        d.day == currentDayAd.day,
                  );

                  final eventCount =
                      widget.eventCounts?[DateTime(
                            currentDayAd.year,
                            currentDayAd.month,
                            currentDayAd.day,
                          )] ??
                          0;

                  Color cellBgColor;
                  Color cellTextColor;

                  if (isSelected || isStartOfRange || isEndOfRange) {
                    cellBgColor = primaryColor;
                    cellTextColor = Colors.white;
                  } else if (isInRange) {
                    cellBgColor = primaryColor.withValues(alpha: 0.2);
                    cellTextColor = primaryColor;
                  } else if (isToday) {
                    cellBgColor = primaryColor.withValues(alpha: 0.12);
                    cellTextColor = primaryColor;
                  } else {
                    cellBgColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.2);
                    cellTextColor = isSaturday ? Colors.red.shade700 : colorScheme.onSurface;
                  }

                  return GestureDetector(
                    onTap: () {
                      widget.onDateSelected(currentDayNp);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: cellBgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (isSelected || isStartOfRange || isEndOfRange)
                              ? primaryColor
                              : (isToday || isInRange
                                  ? primaryColor.withValues(alpha: 0.6)
                                  : colorScheme.outline.withValues(alpha: 0.2)),
                          width: (isSelected || isStartOfRange || isEndOfRange || isToday) ? 1.5 : 1.0,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Main Day Numeral (Nepali BS Day)
                              Text(
                                '$dayNumber',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: (isSelected || isStartOfRange || isEndOfRange || isToday)
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: cellTextColor,
                                ),
                              ),
                              const SizedBox(height: 1),

                              // AD Gregorian Subtext (e.g. 15 / Oct)
                              Text(
                                '${currentDayAd.day}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: (isSelected || isStartOfRange || isEndOfRange)
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),

                          // Event Indicator Dot
                          if (hasEvent)
                            Positioned(
                              bottom: 4,
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: (isSelected || isStartOfRange || isEndOfRange) ? Colors.white : primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),

                          // Event Count Badge
                          if (eventCount > 0 && !(isSelected || isStartOfRange || isEndOfRange))
                            Positioned(
                              top: 2,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$eventCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 7,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
