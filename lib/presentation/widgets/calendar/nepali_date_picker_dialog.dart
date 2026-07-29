import 'package:flutter/material.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'custom_nepali_calendar_widget.dart';
import '../../../core/utils/nepali_date_formatter.dart';

class NepaliDatePickerDialog extends StatefulWidget {
  final String title;
  final DateTime initialStart;
  final DateTime? initialEnd;
  final bool allowRange;

  const NepaliDatePickerDialog({
    super.key,
    required this.title,
    required this.initialStart,
    this.initialEnd,
    this.allowRange = true,
  });

  static Future<Map<String, DateTime?>?> show({
    required BuildContext context,
    required String title,
    required DateTime initialStart,
    DateTime? initialEnd,
    bool allowRange = true,
  }) {
    return showDialog<Map<String, DateTime?>>(
      context: context,
      builder: (ctx) => NepaliDatePickerDialog(
        title: title,
        initialStart: initialStart,
        initialEnd: initialEnd,
        allowRange: allowRange,
      ),
    );
  }

  @override
  State<NepaliDatePickerDialog> createState() => _NepaliDatePickerDialogState();
}

class _NepaliDatePickerDialogState extends State<NepaliDatePickerDialog> {
  late NepaliDateTime _selectedStart;
  NepaliDateTime? _selectedEnd;

  // false = Single Day, true = Date Range (From - To)
  late bool _isRangeMode;

  @override
  void initState() {
    super.initState();
    _selectedStart = widget.initialStart.toNepaliDateTime();
    _selectedEnd = widget.initialEnd?.toNepaliDateTime();
    // Default to Range Mode whenever range is allowed
    _isRangeMode = widget.allowRange;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = colorScheme.primary;

    final startStr = formatNepaliDate(
      _selectedStart.toDateTime(),
      'MMM dd, yyyy',
    );
    final endStr = _selectedEnd != null
        ? formatNepaliDate(_selectedEnd!.toDateTime(), 'MMM dd, yyyy')
        : 'Tap a 2nd date to set range';

    return Dialog(
      backgroundColor: isDarkMode ? colorScheme.surface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Dialog Header ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Mode Switcher: Single Day vs Date Range
                    if (widget.allowRange) ...[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isRangeMode = false;
                                    _selectedEnd = null;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !_isRangeMode
                                        ? colorScheme.surface
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: !_isRangeMode
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.05,
                                              ),
                                              blurRadius: 4,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.today_rounded,
                                        size: 16,
                                        color: !_isRangeMode
                                            ? primaryColor
                                            : colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Single Day',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: !_isRangeMode
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: !_isRangeMode
                                              ? primaryColor
                                              : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isRangeMode = true;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isRangeMode
                                        ? colorScheme.surface
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: _isRangeMode
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.05,
                                              ),
                                              blurRadius: 4,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.date_range_rounded,
                                        size: 16,
                                        color: _isRangeMode
                                            ? primaryColor
                                            : colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Date Range (From - To)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: _isRangeMode
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: _isRangeMode
                                              ? primaryColor
                                              : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Selected Date Information Display
                    if (!_isRangeMode) ...[
                      // Single Day Mode Display
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.event_available,
                              color: primaryColor,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Selected Date: ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              startStr,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Range Mode Display Chips
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: primaryColor,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'FROM (Start Date)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    startStr,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _selectedEnd != null
                                    ? primaryColor.withValues(alpha: 0.12)
                                    : colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _selectedEnd != null
                                      ? primaryColor
                                      : colorScheme.outline.withValues(
                                          alpha: 0.2,
                                        ),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'TO (End Date)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _selectedEnd != null
                                              ? primaryColor
                                              : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      if (_selectedEnd != null)
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedEnd = null;
                                            });
                                          },
                                          child: const Icon(
                                            Icons.clear,
                                            size: 14,
                                            color: Colors.red,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    endStr,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedEnd != null
                                          ? colorScheme.onSurface
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Custom Nepali Calendar Component
                    CustomNepaliCalendarWidget(
                      selectedDate: _selectedStart,
                      rangeStartDate: _isRangeMode ? _selectedStart : null,
                      rangeEndDate: _isRangeMode ? _selectedEnd : null,
                      onDateSelected: (nepaliDate) {
                        setState(() {
                          if (!_isRangeMode) {
                            // Single Day Mode
                            _selectedStart = nepaliDate;
                            _selectedEnd = null;
                          } else {
                            // Date Range Mode
                            if (_selectedEnd != null) {
                              // If range is already full, start a new selection
                              _selectedStart = nepaliDate;
                              _selectedEnd = null;
                            } else {
                              // Selecting second date
                              if (nepaliDate.isBefore(_selectedStart)) {
                                _selectedStart = nepaliDate;
                              } else if (nepaliDate.year ==
                                      _selectedStart.year &&
                                  nepaliDate.month == _selectedStart.month &&
                                  nepaliDate.day == _selectedStart.day) {
                                _selectedEnd = null;
                              } else {
                                _selectedEnd = nepaliDate;
                              }
                            }
                          }
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // Action Buttons
                    Row(
                      children: [
                        if (widget.allowRange && _selectedEnd != null)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedEnd = null;
                              });
                            },
                            child: const Text(
                              'Clear End Date',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context, {
                              'start': _selectedStart.toDateTime(),
                              'end': _isRangeMode
                                  ? _selectedEnd?.toDateTime()
                                  : null,
                            });
                          },
                          child: const Text(
                            'Apply Date',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
