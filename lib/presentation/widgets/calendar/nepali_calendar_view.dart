import 'package:flutter/material.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:order_app/core/calendar/nepali_calendar_engine.dart';
import 'package:order_app/core/calendar/nepali_holidays.dart';
import 'package:order_app/presentation/widgets/calendar/nepali_year_month_picker_dialog.dart';

class NepaliCalendarView extends StatefulWidget {
  final NepaliDateTime selectedDate;
  final ValueChanged<NepaliDateTime>? onDateSelected;
  final NepaliDateTime? rangeStartDate;
  final NepaliDateTime? rangeEndDate;
  final Function(NepaliDateTime start, NepaliDateTime? end)? onRangeSelected;
  final Set<DateTime> eventDates;
  final Map<DateTime, int>? eventCounts;
  final Map<DateTime, int>? orderCounts;
  final bool isRangePicker;
  final bool showDualAdDates;

  const NepaliCalendarView({
    super.key,
    required this.selectedDate,
    this.onDateSelected,
    this.rangeStartDate,
    this.rangeEndDate,
    this.onRangeSelected,
    this.eventDates = const {},
    this.eventCounts,
    this.orderCounts,
    this.isRangePicker = false,
    this.showDualAdDates = true,
  });

  @override
  State<NepaliCalendarView> createState() => _NepaliCalendarViewState();
}

class _NepaliCalendarViewState extends State<NepaliCalendarView> {
  late int _displayYear;
  late int _displayMonth;

  NepaliDateTime? _tempRangeStart;
  NepaliDateTime? _tempRangeEnd;

  @override
  void initState() {
    super.initState();
    _displayYear = widget.selectedDate.year;
    _displayMonth = widget.selectedDate.month;
    _tempRangeStart = widget.rangeStartDate;
    _tempRangeEnd = widget.rangeEndDate;
  }

  @override
  void didUpdateWidget(covariant NepaliCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate.year != widget.selectedDate.year ||
        oldWidget.selectedDate.month != widget.selectedDate.month) {
      setState(() {
        _displayYear = widget.selectedDate.year;
        _displayMonth = widget.selectedDate.month;
      });
    }
    if (oldWidget.rangeStartDate != widget.rangeStartDate ||
        oldWidget.rangeEndDate != widget.rangeEndDate) {
      setState(() {
        _tempRangeStart = widget.rangeStartDate;
        _tempRangeEnd = widget.rangeEndDate;
      });
    }
  }

  void _previousMonth() {
    setState(() {
      if (_displayMonth == 1) {
        _displayMonth = 12;
        _displayYear--;
      } else {
        _displayMonth--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_displayMonth == 12) {
        _displayMonth = 1;
        _displayYear++;
      } else {
        _displayMonth++;
      }
    });
  }

  void _goToToday() {
    final now = NepaliCalendarEngine.now();
    setState(() {
      _displayYear = now.year;
      _displayMonth = now.month;
    });
    widget.onDateSelected?.call(now);
  }

  Future<void> _openYearMonthPicker() async {
    final result = await NepaliYearMonthPickerDialog.show(
      context: context,
      initialYear: _displayYear,
      initialMonth: _displayMonth,
    );
    if (result != null && mounted) {
      setState(() {
        _displayYear = result['year']!;
        _displayMonth = result['month']!;
      });
    }
  }

  void _handleDayTap(NepaliDateTime day) {
    if (widget.isRangePicker) {
      if (_tempRangeStart == null ||
          (_tempRangeStart != null && _tempRangeEnd != null)) {
        setState(() {
          _tempRangeStart = day;
          _tempRangeEnd = null;
        });
        widget.onRangeSelected?.call(day, null);
      } else if (_tempRangeStart != null && _tempRangeEnd == null) {
        if (day.isBefore(_tempRangeStart!)) {
          setState(() {
            _tempRangeEnd = _tempRangeStart;
            _tempRangeStart = day;
          });
          widget.onRangeSelected?.call(day, _tempRangeEnd);
        } else {
          setState(() {
            _tempRangeEnd = day;
          });
          widget.onRangeSelected?.call(_tempRangeStart!, day);
        }
      }
    } else {
      widget.onDateSelected?.call(day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0075db);
    final cardBgColor = isDarkMode ? const Color(0xFF141f28) : Colors.white;
    final surfaceAccent = isDarkMode
        ? const Color(0xFF1c2936)
        : const Color(0xFFf8fafc);
    final borderColor = isDarkMode
        ? const Color(0xFF243444)
        : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final textMuted = isDarkMode
        ? const Color(0xFF94a3b8)
        : const Color(0xFF64748b);
    final saturdayColor = const Color(0xFFef4444); // Red accent for Saturday

    final totalDaysInMonth = NepaliCalendarEngine.getDaysInMonth(
      _displayYear,
      _displayMonth,
    );
    final startWeekdayOffset = NepaliCalendarEngine.getStartWeekdayOffset(
      _displayYear,
      _displayMonth,
    );

    final monthNameEn = NepaliCalendarEngine.getMonthNameEnglish(_displayMonth);
    final monthNameNp = NepaliCalendarEngine.getMonthNameNepali(_displayMonth);
    final yearNpDigits = NepaliCalendarEngine.toNepaliDigits(_displayYear);

    // Gregorian (AD) reference for the first and last day of this BS month
    final firstDayAd = NepaliCalendarEngine.bsToAd(
      NepaliDateTime(_displayYear, _displayMonth, 1),
    );
    final lastDayAd = NepaliCalendarEngine.bsToAd(
      NepaliDateTime(_displayYear, _displayMonth, totalDaysInMonth),
    );
    final adMonthSummary =
        '${_monthAbbr(firstDayAd.month)} ${firstDayAd.year} - ${_monthAbbr(lastDayAd.month)} ${lastDayAd.year}';

    final today = NepaliCalendarEngine.now();

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Calendar Top Navigation Header ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Month & Year Selector (Clickable Pill)
                Expanded(
                  child: InkWell(
                    onTap: _openYearMonthPicker,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$monthNameEn $_displayYear',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Manrope',
                                    color: textColor,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '($monthNameNp $yearNpDigits)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textMuted,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.arrow_drop_down_rounded,
                                  size: 20,
                                  color: textMuted,
                                ),
                              ],
                            ),
                          ),
                          if (widget.showDualAdDates)
                            Text(
                              adMonthSummary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: textMuted.withValues(alpha: 0.8),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // "Today" (आज) Snap Button
                OutlinedButton(
                  onPressed: _goToToday,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(color: borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Today (आज)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Month Nav Arrows
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 22),
                      tooltip: 'Previous Month',
                      onPressed: _previousMonth,
                      style: IconButton.styleFrom(
                        backgroundColor: surfaceAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(6),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 22),
                      tooltip: 'Next Month',
                      onPressed: _nextMonth,
                      style: IconButton.styleFrom(
                        backgroundColor: surfaceAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Weekday Column Header ─────────────────────────────────────────
          Container(
            color: surfaceAccent.withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: List.generate(7, (index) {
                final isSaturday = index == 6;
                final enDay = NepaliCalendarEngine.weekdaysEnglish[index];
                final npDay = NepaliCalendarEngine.weekdaysNepali[index];

                return Expanded(
                  child: Column(
                    children: [
                      Text(
                        enDay.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isSaturday ? saturdayColor : textMuted,
                        ),
                      ),
                      Text(
                        npDay,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isSaturday
                              ? saturdayColor.withValues(alpha: 0.8)
                              : textMuted.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),

          const Divider(height: 1),

          // ── 7x6 Calendar Grid Cells ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildMonthGrid(
              totalDaysInMonth: totalDaysInMonth,
              startOffset: startWeekdayOffset,
              today: today,
              primaryColor: primaryColor,
              saturdayColor: saturdayColor,
              textColor: textColor,
              textMuted: textMuted,
              borderColor: borderColor,
              isDarkMode: isDarkMode,
            ),
          ),

          // ── Legend Key ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.05),
              border: Border(
                top: BorderSide(color: borderColor.withValues(alpha: 0.3)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(
                  color: isDarkMode
                      ? const Color(0xFF10b981)
                      : const Color(0xFF047857),
                  bgColor: isDarkMode
                      ? const Color(0xFF064e3b).withValues(alpha: 0.45)
                      : const Color(0xFFecfdf5),
                  label: '1 Event',
                  textColor: textColor,
                ),
                _buildLegendItem(
                  color: isDarkMode
                      ? const Color(0xFFA855F7)
                      : const Color(0xFF6b21a8),
                  bgColor: isDarkMode
                      ? const Color(0xFF4c1d95).withValues(alpha: 0.55)
                      : const Color(0xFFf3e8ff),
                  label: 'Multi Events',
                  textColor: textColor,
                ),
                _buildLegendItem(
                  color: const Color(0xFFea580c),
                  bgColor: const Color(0xFFea580c).withValues(alpha: 0.12),
                  label: 'Holiday',
                  textColor: textColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthGrid({
    required int totalDaysInMonth,
    required int startOffset,
    required NepaliDateTime today,
    required Color primaryColor,
    required Color saturdayColor,
    required Color textColor,
    required Color textMuted,
    required Color borderColor,
    required bool isDarkMode,
  }) {
    final totalCells = ((startOffset + totalDaysInMonth) / 7).ceil() * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.84,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        // Offset padding cells
        if (index < startOffset || index >= startOffset + totalDaysInMonth) {
          return const SizedBox.shrink();
        }

        final dayNumber = index - startOffset + 1;
        final currentBsDate = NepaliDateTime(
          _displayYear,
          _displayMonth,
          dayNumber,
        );
        final currentAdDate = NepaliCalendarEngine.bsToAd(currentBsDate);

        final isSaturday = NepaliHolidays.isSaturday(currentBsDate);
        final holiday = NepaliHolidays.getHoliday(currentBsDate);
        final isToday = NepaliCalendarEngine.isSameDay(currentBsDate, today);

        // Range / Single selection logic
        final isSelected =
            !widget.isRangePicker &&
            NepaliCalendarEngine.isSameDay(currentBsDate, widget.selectedDate);

        bool isInRange = false;
        bool isRangeStart = false;
        bool isRangeEnd = false;

        if (widget.isRangePicker && _tempRangeStart != null) {
          isRangeStart = NepaliCalendarEngine.isSameDay(
            currentBsDate,
            _tempRangeStart,
          );
          if (_tempRangeEnd != null) {
            isRangeEnd = NepaliCalendarEngine.isSameDay(
              currentBsDate,
              _tempRangeEnd,
            );
            isInRange = NepaliCalendarEngine.isDateInRange(
              currentBsDate,
              _tempRangeStart!,
              _tempRangeEnd!,
            );
          }
        }

        // Count indicators
        final cleanAdMidnight = DateTime(
          currentAdDate.year,
          currentAdDate.month,
          currentAdDate.day,
        );
        final hasEvents = widget.eventDates.contains(cleanAdMidnight);
        final eventCount =
            widget.eventCounts?[cleanAdMidnight] ?? (hasEvents ? 1 : 0);
        final orderCount = widget.orderCounts?[cleanAdMidnight] ?? 0;

        return _buildDayCell(
          dayNumber: dayNumber,
          currentBsDate: currentBsDate,
          currentAdDate: currentAdDate,
          isSaturday: isSaturday,
          holiday: holiday,
          isToday: isToday,
          isSelected: isSelected,
          isInRange: isInRange,
          isRangeStart: isRangeStart,
          isRangeEnd: isRangeEnd,
          eventCount: eventCount,
          orderCount: orderCount,
          primaryColor: primaryColor,
          saturdayColor: saturdayColor,
          textColor: textColor,
          textMuted: textMuted,
          isDarkMode: isDarkMode,
        );
      },
    );
  }

  Widget _buildDayCell({
    required int dayNumber,
    required NepaliDateTime currentBsDate,
    required DateTime currentAdDate,
    required bool isSaturday,
    required NepaliHolidayInfo? holiday,
    required bool isToday,
    required bool isSelected,
    required bool isInRange,
    required bool isRangeStart,
    required bool isRangeEnd,
    required int eventCount,
    required int orderCount,
    required Color primaryColor,
    required Color saturdayColor,
    required Color textColor,
    required Color textMuted,
    required bool isDarkMode,
  }) {
    final npDigit = NepaliCalendarEngine.toNepaliDigits(dayNumber);
    final adDay = currentAdDate.day;

    BoxDecoration cellDecoration;
    Color cellTextColor;

    if (isSelected || isRangeStart || isRangeEnd) {
      cellDecoration = BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      );
      cellTextColor = Colors.white;
    } else if (isInRange) {
      cellDecoration = BoxDecoration(
        color: primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      );
      cellTextColor = primaryColor;
    } else if (eventCount == 1) {
      // SINGLE EVENT DAY: Soft Emerald fill & Emerald border
      final singleEventBg = isDarkMode
          ? const Color(0xFF064e3b).withValues(alpha: 0.45)
          : const Color(0xFFecfdf5);
      final singleEventBorder = isDarkMode
          ? const Color(0xFF10b981).withValues(alpha: 0.6)
          : const Color(0xFFa7f3d0);
      cellDecoration = BoxDecoration(
        color: singleEventBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: singleEventBorder, width: 1.2),
      );
      cellTextColor = isDarkMode
          ? const Color(0xFF6ee7b7)
          : const Color(0xFF047857);
    } else if (eventCount > 1) {
      // MULTIPLE EVENTS DAY: Distinct Vibrant Purple fill & Purple border
      final multiEventBg = isDarkMode
          ? const Color(0xFF4c1d95).withValues(alpha: 0.55)
          : const Color(0xFFf3e8ff);
      final multiEventBorder = isDarkMode
          ? const Color(0xFFA855F7).withValues(alpha: 0.7)
          : const Color(0xFFd8b4fe);
      cellDecoration = BoxDecoration(
        color: multiEventBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: multiEventBorder, width: 1.5),
      );
      cellTextColor = isDarkMode
          ? const Color(0xFFd8b4fe)
          : const Color(0xFF6b21a8);
    } else if (isToday) {
      cellDecoration = BoxDecoration(
        border: Border.all(color: primaryColor, width: 1.5),
        borderRadius: BorderRadius.circular(10),
        color: primaryColor.withValues(alpha: 0.04),
      );
      cellTextColor = primaryColor;
    } else {
      cellDecoration = BoxDecoration(borderRadius: BorderRadius.circular(8));
      cellTextColor = isSaturday
          ? saturdayColor
          : (holiday != null ? const Color(0xFFea580c) : textColor);
    }

    return Tooltip(
      message: holiday != null
          ? '${holiday.nameEnglish}\n(${holiday.nameNepali})'
          : '$dayNumber ${NepaliCalendarEngine.getMonthNameEnglish(currentBsDate.month)} ${currentBsDate.year}'
                '${eventCount > 0 ? '\n• $eventCount Event${eventCount > 1 ? 's' : ''}' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleDayTap(currentBsDate),
          borderRadius: BorderRadius.circular(10),
          hoverColor: primaryColor.withValues(alpha: 0.08),
          child: Container(
            decoration: cellDecoration,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: BS Day (Big) & AD Gregorian Reference
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            (isSelected ||
                                isRangeStart ||
                                isRangeEnd ||
                                isToday ||
                                eventCount > 0)
                            ? FontWeight.w900
                            : FontWeight.w700,
                        color: cellTextColor,
                        fontFamily: 'Manrope',
                      ),
                    ),
                    if (widget.showDualAdDates)
                      Text(
                        '$adDay',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: (isSelected || isRangeStart || isRangeEnd)
                              ? Colors.white.withValues(alpha: 0.75)
                              : (eventCount == 1
                                    ? (isDarkMode
                                          ? const Color(0xFFa7f3d0)
                                          : const Color(0xFF047857))
                                    : (eventCount > 1
                                          ? (isDarkMode
                                                ? const Color(0xFFd8b4fe)
                                                : const Color(0xFF6b21a8))
                                          : textMuted.withValues(alpha: 0.7))),
                        ),
                      ),
                  ],
                ),

                // Center: Devanagari sub-digit
                Text(
                  npDigit,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: (isSelected || isRangeStart || isRangeEnd)
                        ? Colors.white.withValues(alpha: 0.9)
                        : (eventCount == 1
                              ? (isDarkMode
                                    ? const Color(0xFFa7f3d0)
                                    : const Color(0xFF047857))
                              : (eventCount > 1
                                    ? (isDarkMode
                                          ? const Color(0xFFd8b4fe)
                                          : const Color(0xFF6b21a8))
                                    : (isSaturday
                                          ? saturdayColor.withValues(alpha: 0.8)
                                          : textMuted))),
                  ),
                ),

                // Bottom: Event & Order indicator dots / pills
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (holiday != null &&
                        !(isSelected || isRangeStart || isRangeEnd))
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: const BoxDecoration(
                          color: Color(0xFFea580c),
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (eventCount == 1)
                      Container(
                        width: 4.5,
                        height: 4.5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: (isSelected || isRangeStart || isRangeEnd)
                              ? Colors.white
                              : const Color(0xFF10b981), // Single event emerald
                          shape: BoxShape.circle,
                        ),
                      )
                    else if (eventCount > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2.5,
                          vertical: 0,
                        ),
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: (isSelected || isRangeStart || isRangeEnd)
                              ? Colors.white
                              : const Color(0xFFA855F7), // Multi event purple
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$eventCount',
                          style: TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.bold,
                            color: (isSelected || isRangeStart || isRangeEnd)
                                ? primaryColor
                                : Colors.white,
                          ),
                        ),
                      ),
                    if (orderCount > 0)
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: (isSelected || isRangeStart || isRangeEnd)
                              ? Colors.white.withValues(alpha: 0.8)
                              : const Color(0xFF0284c7),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required Color bgColor,
    required String label,
    required Color textColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
          ),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: textColor.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  String _monthAbbr(int month) {
    const abbrs = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return (month >= 1 && month <= 12) ? abbrs[month] : '';
  }
}
