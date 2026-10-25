import 'package:flutter/material.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:order_app/core/calendar/bs_calendar_service.dart';
import 'package:order_app/core/calendar/nepali_calendar_engine.dart';
import 'package:order_app/presentation/widgets/calendar/nepali_calendar_view.dart';

class NepaliDatePickerDialog extends StatefulWidget {
  final String title;
  final DateTime initialStart;
  final DateTime? initialEnd;
  final bool allowRange;
  final bool initialManualMode;

  const NepaliDatePickerDialog({
    super.key,
    required this.title,
    required this.initialStart,
    this.initialEnd,
    this.allowRange = true,
    this.initialManualMode = false,
  });

  static Future<Map<String, DateTime?>?> show({
    required BuildContext context,
    required String title,
    required DateTime initialStart,
    DateTime? initialEnd,
    bool allowRange = true,
    bool initialManualMode = false,
  }) {
    return showDialog<Map<String, DateTime?>>(
      context: context,
      builder: (ctx) => NepaliDatePickerDialog(
        title: title,
        initialStart: initialStart,
        initialEnd: initialEnd,
        allowRange: allowRange,
        initialManualMode: initialManualMode,
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
  late bool _isManualMode;

  // Controllers for manual input
  late final TextEditingController _quickStartController;
  late final TextEditingController _startYearController;
  late final TextEditingController _startDayController;
  int _startMonth = 1;
  String? _startError;

  late final TextEditingController _quickEndController;
  late final TextEditingController _endYearController;
  late final TextEditingController _endDayController;
  int _endMonth = 1;
  String? _endError;

  @override
  void initState() {
    super.initState();
    _selectedStart = NepaliCalendarEngine.adToBs(widget.initialStart);
    _selectedEnd = widget.initialEnd != null
        ? NepaliCalendarEngine.adToBs(widget.initialEnd!)
        : null;
    _isRangeMode = widget.allowRange && widget.initialEnd != null;
    _isManualMode = widget.initialManualMode;

    _quickStartController = TextEditingController();
    _startYearController = TextEditingController();
    _startDayController = TextEditingController();

    _quickEndController = TextEditingController();
    _endYearController = TextEditingController();
    _endDayController = TextEditingController();

    _syncStartControllersFromSelected();
    if (_selectedEnd != null) {
      _syncEndControllersFromSelected();
    } else {
      _syncEndControllersFromDefault();
    }
  }

  @override
  void dispose() {
    _quickStartController.dispose();
    _startYearController.dispose();
    _startDayController.dispose();
    _quickEndController.dispose();
    _endYearController.dispose();
    _endDayController.dispose();
    super.dispose();
  }

  void _syncStartControllersFromSelected() {
    _startYearController.text = '${_selectedStart.year}';
    _startMonth = _selectedStart.month;
    _startDayController.text = '${_selectedStart.day}';
    _quickStartController.text =
        '${_selectedStart.year}-${_selectedStart.month.toString().padLeft(2, '0')}-${_selectedStart.day.toString().padLeft(2, '0')}';
    _startError = null;
  }

  void _syncEndControllersFromSelected() {
    if (_selectedEnd == null) return;
    _endYearController.text = '${_selectedEnd!.year}';
    _endMonth = _selectedEnd!.month;
    _endDayController.text = '${_selectedEnd!.day}';
    _quickEndController.text =
        '${_selectedEnd!.year}-${_selectedEnd!.month.toString().padLeft(2, '0')}-${_selectedEnd!.day.toString().padLeft(2, '0')}';
    _endError = null;
  }

  void _syncEndControllersFromDefault() {
    final next = _selectedStart.add(const Duration(days: 1));
    _endYearController.text = '${next.year}';
    _endMonth = next.month;
    _endDayController.text = '${next.day}';
    _quickEndController.text =
        '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
    _endError = null;
  }

  void _onQuickStartChanged(String text) {
    final parsed = NepaliCalendarEngine.tryParseBs(text);
    if (parsed != null) {
      setState(() {
        _selectedStart = parsed;
        _startYearController.text = '${parsed.year}';
        _startMonth = parsed.month;
        _startDayController.text = '${parsed.day}';
        _startError = null;
      });
    } else {
      setState(() {
        _startError = 'Enter valid BS date (YYYY-MM-DD)';
      });
    }
  }

  void _onStructuredStartChanged() {
    final year = int.tryParse(_startYearController.text.trim());
    final day = int.tryParse(_startDayController.text.trim());

    if (year != null && day != null) {
      if (NepaliCalendarEngine.isValidBsDate(year, _startMonth, day)) {
        setState(() {
          _selectedStart = NepaliDateTime(year, _startMonth, day);
          _quickStartController.text =
              '$year-${_startMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
          _startError = null;
        });
        return;
      }
    }
    setState(() {
      final maxDays = year != null
          ? NepaliCalendarEngine.getDaysInMonth(year, _startMonth)
          : 32;
      _startError = 'Day must be 1 to $maxDays for this month';
    });
  }

  void _onQuickEndChanged(String text) {
    final parsed = NepaliCalendarEngine.tryParseBs(text);
    if (parsed != null) {
      setState(() {
        _selectedEnd = parsed;
        _endYearController.text = '${parsed.year}';
        _endMonth = parsed.month;
        _endDayController.text = '${parsed.day}';
        _endError = null;
      });
    } else {
      setState(() {
        _endError = 'Enter valid BS date (YYYY-MM-DD)';
      });
    }
  }

  void _onStructuredEndChanged() {
    final year = int.tryParse(_endYearController.text.trim());
    final day = int.tryParse(_endDayController.text.trim());

    if (year != null && day != null) {
      if (NepaliCalendarEngine.isValidBsDate(year, _endMonth, day)) {
        setState(() {
          _selectedEnd = NepaliDateTime(year, _endMonth, day);
          _quickEndController.text =
              '$year-${_endMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
          _endError = null;
        });
        return;
      }
    }
    setState(() {
      final maxDays = year != null
          ? NepaliCalendarEngine.getDaysInMonth(year, _endMonth)
          : 32;
      _endError = 'Day must be 1 to $maxDays for this month';
    });
  }

  void _applyPreset(String preset) {
    final now = NepaliCalendarEngine.now();
    switch (preset) {
      case 'today':
        setState(() {
          _selectedStart = now;
          _selectedEnd = null;
          _isRangeMode = false;
          _syncStartControllersFromSelected();
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
          _syncStartControllersFromSelected();
          _syncEndControllersFromSelected();
        });
        break;
      case 'this_month':
        setState(() {
          _selectedStart = NepaliDateTime(now.year, now.month, 1);
          _selectedEnd = NepaliDateTime(now.year, now.month, now.day);
          _isRangeMode = true;
          _syncStartControllersFromSelected();
          _syncEndControllersFromSelected();
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
          _syncStartControllersFromSelected();
          _syncEndControllersFromSelected();
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
                      icon: Icon(
                        _isManualMode
                            ? Icons.calendar_month_rounded
                            : Icons.edit_note_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      tooltip: _isManualMode
                          ? 'Switch to Calendar View'
                          : 'Switch to Manual Input (Type Date)',
                      onPressed: () {
                        setState(() {
                          _isManualMode = !_isManualMode;
                          if (_isManualMode) {
                            _syncStartControllersFromSelected();
                            if (_selectedEnd != null) {
                              _syncEndControllersFromSelected();
                            }
                          }
                        });
                      },
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

              // ── Mode Switcher Tab (Calendar View vs Manual Entry) ──────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1e2b38) : const Color(0xFFf1f5f9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          if (_isManualMode) {
                            setState(() {
                              _isManualMode = false;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: !_isManualMode ? primaryColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_month_rounded,
                                size: 15,
                                color: !_isManualMode ? Colors.white : textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Calendar View',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: !_isManualMode ? Colors.white : textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          if (!_isManualMode) {
                            _syncStartControllersFromSelected();
                            if (_selectedEnd != null) {
                              _syncEndControllersFromSelected();
                            }
                            setState(() {
                              _isManualMode = true;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: _isManualMode ? primaryColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.edit_note_rounded,
                                size: 16,
                                color: _isManualMode ? Colors.white : textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Manual Entry',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _isManualMode ? Colors.white : textColor,
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

              // ── Selection Summary Strip ──────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                                if (!_isRangeMode) {
                                  _selectedEnd = null;
                                } else {
                                  _selectedEnd ??= _selectedStart.add(const Duration(days: 1));
                                  _syncEndControllersFromSelected();
                                }
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
                        children: [
                          Icon(Icons.calendar_month_rounded, size: 16, color: primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isRangeMode
                                  ? '$startStr  →  $endStr'
                                  : startStr,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Quick Preset Chips ────────────────────────────────
              if (widget.allowRange && !_isManualMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
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

              // ── Main Body: Calendar Grid or Manual Entry ───────────
              if (!_isManualMode)
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
                        _syncStartControllersFromSelected();
                      });
                    },
                    onRangeSelected: (start, end) {
                      setState(() {
                        _selectedStart = start;
                        _selectedEnd = end;
                        _syncStartControllersFromSelected();
                        if (end != null) {
                          _syncEndControllersFromSelected();
                        }
                      });
                    },
                  ),
                )
              else
                _buildManualEntryView(
                  isDarkMode: isDarkMode,
                  primaryColor: primaryColor,
                  bgColor: bgColor,
                  surfaceAccent: surfaceAccent,
                  borderColor: borderColor,
                  textColor: textColor,
                  textMuted: textMuted,
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
                        final startAd = BsCalendarService.bsToAd(
                          _selectedStart.year,
                          _selectedStart.month,
                          _selectedStart.day,
                        );
                        final endAd = _isRangeMode && _selectedEnd != null
                            ? BsCalendarService.bsToAd(
                                _selectedEnd!.year,
                                _selectedEnd!.month,
                                _selectedEnd!.day,
                              )
                            : null;
                        Navigator.pop(context, {
                          'start': startAd,
                          'end': endAd,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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

  Widget _buildManualEntryView({
    required bool isDarkMode,
    required Color primaryColor,
    required Color bgColor,
    required Color surfaceAccent,
    required Color borderColor,
    required Color textColor,
    required Color textMuted,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Start Date Section
          Text(
            _isRangeMode ? 'Start Date (सुरुको मिति - BS)' : 'Date in Bikram Sambat (BS)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          _buildDateManualForm(
            quickController: _quickStartController,
            yearController: _startYearController,
            dayController: _startDayController,
            selectedMonth: _startMonth,
            errorMessage: _startError,
            onQuickChanged: _onQuickStartChanged,
            onMonthChanged: (m) {
              setState(() {
                _startMonth = m;
              });
              _onStructuredStartChanged();
            },
            onStructuredChanged: _onStructuredStartChanged,
            selectedDate: _selectedStart,
            isDarkMode: isDarkMode,
            primaryColor: primaryColor,
            bgColor: bgColor,
            surfaceAccent: surfaceAccent,
            borderColor: borderColor,
            textColor: textColor,
            textMuted: textMuted,
          ),

          // End Date Section (if Range Mode)
          if (_isRangeMode) ...[
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Text(
              'End Date (अन्तिम मिति - BS)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            _buildDateManualForm(
              quickController: _quickEndController,
              yearController: _endYearController,
              dayController: _endDayController,
              selectedMonth: _endMonth,
              errorMessage: _endError,
              onQuickChanged: _onQuickEndChanged,
              onMonthChanged: (m) {
                setState(() {
                  _endMonth = m;
                });
                _onStructuredEndChanged();
              },
              onStructuredChanged: _onStructuredEndChanged,
              selectedDate: _selectedEnd ?? _selectedStart,
              isDarkMode: isDarkMode,
              primaryColor: primaryColor,
              bgColor: bgColor,
              surfaceAccent: surfaceAccent,
              borderColor: borderColor,
              textColor: textColor,
              textMuted: textMuted,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateManualForm({
    required TextEditingController quickController,
    required TextEditingController yearController,
    required TextEditingController dayController,
    required int selectedMonth,
    required String? errorMessage,
    required ValueChanged<String> onQuickChanged,
    required ValueChanged<int> onMonthChanged,
    required VoidCallback onStructuredChanged,
    required NepaliDateTime selectedDate,
    required bool isDarkMode,
    required Color primaryColor,
    required Color bgColor,
    required Color surfaceAccent,
    required Color borderColor,
    required Color textColor,
    required Color textMuted,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceAccent.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: errorMessage != null ? Colors.redAccent : borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quick single text input (YYYY-MM-DD)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: quickController,
                  onChanged: onQuickChanged,
                  keyboardType: TextInputType.datetime,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Quick Date Input (YYYY-MM-DD)',
                    labelStyle: TextStyle(fontSize: 12, color: textMuted),
                    hintText: 'e.g. 2081-05-15',
                    hintStyle: TextStyle(fontSize: 12, color: textMuted.withValues(alpha: 0.6)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primaryColor, width: 1.5),
                    ),
                    prefixIcon: Icon(Icons.edit_calendar, size: 18, color: primaryColor),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Divider(color: borderColor.withValues(alpha: 0.6))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'OR SELECT BY PARTS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: textMuted,
                  ),
                ),
              ),
              Expanded(child: Divider(color: borderColor.withValues(alpha: 0.6))),
            ],
          ),
          const SizedBox(height: 10),

          // 3 Structured Fields: Year, Month, Day
          Row(
            children: [
              // Year field
              Expanded(
                flex: 3,
                child: TextField(
                  controller: yearController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onStructuredChanged(),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Year (साल)',
                    labelStyle: TextStyle(fontSize: 11, color: textMuted),
                    hintText: '2081',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Month dropdown
              Expanded(
                flex: 5,
                child: DropdownButtonFormField<int>(
                  value: selectedMonth,
                  isDense: true,
                  isExpanded: true,
                  style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Month (महिना)',
                    labelStyle: TextStyle(fontSize: 11, color: textMuted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                  items: List.generate(12, (index) {
                    final monthIndex = index + 1;
                    final enName = NepaliCalendarEngine.getMonthNameEnglish(monthIndex);
                    final npName = NepaliCalendarEngine.getMonthNameNepali(monthIndex);
                    return DropdownMenuItem<int>(
                      value: monthIndex,
                      child: Text(
                        '$enName ($npName)',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) {
                      onMonthChanged(val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Day field
              Expanded(
                flex: 3,
                child: TextField(
                  controller: dayController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onStructuredChanged(),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Day (गते)',
                    labelStyle: TextStyle(fontSize: 11, color: textMuted),
                    hintText: '15',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Error or Confirmation Badge
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 2.0),
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 2.0),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF10b981)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '${NepaliCalendarEngine.format(selectedDate, pattern: 'MMMM dd, yyyy')} BS (${NepaliCalendarEngine.format(selectedDate, pattern: 'MMMM dd, yyyy', language: Language.nepali)})',
                      style: const TextStyle(
                        color: Color(0xFF10b981),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
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
