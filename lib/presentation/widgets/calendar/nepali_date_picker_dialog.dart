import 'package:flutter/material.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:order_app/core/calendar/nepali_calendar_engine.dart';
import 'package:order_app/presentation/widgets/calendar/nepali_calendar_view.dart';

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
  late bool _isRangeMode;

  @override
  void initState() {
    super.initState();
    _selectedStart = NepaliCalendarEngine.adToBs(widget.initialStart);
    _selectedEnd = widget.initialEnd != null
        ? NepaliCalendarEngine.adToBs(widget.initialEnd!)
        : null;
    _isRangeMode = widget.allowRange && widget.initialEnd != null;
  }

  void _applyPreset(String preset) {
    final now = NepaliCalendarEngine.now();
    switch (preset) {
      case 'today':
        setState(() {
          _selectedStart = now;
          _selectedEnd = null;
          _isRangeMode = false;
        });
        break;
      case 'this_week':
        final startOffset = now.weekday - 1; // 0 = Sunday
        final start = now.subtract(Duration(days: startOffset));
        final end = start.add(const Duration(days: 6));
        setState(() {
          _selectedStart = start;
          _selectedEnd = end;
          _isRangeMode = true;
        });
        break;
      case 'this_month':
        final totalDays = NepaliCalendarEngine.getDaysInMonth(now.year, now.month);
        setState(() {
          _selectedStart = NepaliDateTime(now.year, now.month, 1);
          _selectedEnd = NepaliDateTime(now.year, now.month, totalDays);
          _isRangeMode = true;
        });
        break;
      case 'last_month':
        int prevYear = now.year;
        int prevMonth = now.month - 1;
        if (prevMonth == 0) {
          prevMonth = 12;
          prevYear--;
        }
        final totalDays = NepaliCalendarEngine.getDaysInMonth(prevYear, prevMonth);
        setState(() {
          _selectedStart = NepaliDateTime(prevYear, prevMonth, 1);
          _selectedEnd = NepaliDateTime(prevYear, prevMonth, totalDays);
          _isRangeMode = true;
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0075db);
    final bgColor = isDarkMode ? const Color(0xFF141e28) : Colors.white;
    final surfaceAccent = isDarkMode ? const Color(0xFF1e2b38) : const Color(0xFFf8fafc);
    final borderColor = isDarkMode ? const Color(0xFF2a3b4c) : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final textMuted = isDarkMode ? const Color(0xFF94a3b8) : const Color(0xFF64748b);

    final startStr = NepaliCalendarEngine.format(_selectedStart, pattern: 'MMM dd, yyyy');
    final endStr = _selectedEnd != null
        ? NepaliCalendarEngine.format(_selectedEnd!, pattern: 'MMM dd, yyyy')
        : 'Select End Date';

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              fontFamily: 'Manrope',
                            ),
                          ),
                          const Text(
                            'Nepali Bikram Sambat (BS) Calendar',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // ── Selection Summary Strip ──────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: surfaceAccent,
                child: Column(
                  children: [
                    if (widget.allowRange)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isRangeMode ? 'Range Selection (अवधि)' : 'Single Date Selection',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isRangeMode = !_isRangeMode;
                                if (!_isRangeMode) _selectedEnd = null;
                              });
                            },
                            child: Text(
                              _isRangeMode ? 'Switch to Single' : 'Switch to Range',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_month_rounded, size: 16, color: primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                _isRangeMode
                                    ? '$startStr  →  $endStr'
                                    : startStr,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
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

              // ── Quick Preset Chips ────────────────────────────────
              if (widget.allowRange)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetChip('Today', () => _applyPreset('today'), primaryColor, surfaceAccent, borderColor, textColor),
                        const SizedBox(width: 6),
                        _buildPresetChip('This Week', () => _applyPreset('this_week'), primaryColor, surfaceAccent, borderColor, textColor),
                        const SizedBox(width: 6),
                        _buildPresetChip('This Month', () => _applyPreset('this_month'), primaryColor, surfaceAccent, borderColor, textColor),
                        const SizedBox(width: 6),
                        _buildPresetChip('Last Month', () => _applyPreset('last_month'), primaryColor, surfaceAccent, borderColor, textColor),
                      ],
                    ),
                  ),
                ),

              // ── Calendar Body ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: NepaliCalendarView(
                  selectedDate: _selectedStart,
                  isRangePicker: _isRangeMode,
                  rangeStartDate: _selectedStart,
                  rangeEndDate: _selectedEnd,
                  onDateSelected: (date) {
                    setState(() {
                      _selectedStart = date;
                      _selectedEnd = null;
                    });
                  },
                  onRangeSelected: (start, end) {
                    setState(() {
                      _selectedStart = start;
                      _selectedEnd = end;
                    });
                  },
                ),
              ),

              // ── Action Buttons ───────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: surfaceAccent,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: TextStyle(color: textMuted)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final startAd = NepaliCalendarEngine.bsToAd(_selectedStart);
                        final endAd = _selectedEnd != null
                            ? NepaliCalendarEngine.bsToAd(_selectedEnd!)
                            : null;
                        Navigator.pop(context, {
                          'start': startAd,
                          'end': endAd,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildPresetChip(
    String label,
    VoidCallback onTap,
    Color primaryColor,
    Color surfaceAccent,
    Color borderColor,
    Color textColor,
  ) {
    return ActionChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
      onPressed: onTap,
      backgroundColor: surfaceAccent,
      side: BorderSide(color: borderColor),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}
