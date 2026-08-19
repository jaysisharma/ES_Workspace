import 'package:flutter/material.dart';
import 'package:order_app/core/calendar/nepali_calendar_engine.dart';

class NepaliYearMonthPickerDialog extends StatefulWidget {
  final int initialYear;
  final int initialMonth;
  final int minYear;
  final int maxYear;

  const NepaliYearMonthPickerDialog({
    super.key,
    required this.initialYear,
    required this.initialMonth,
    this.minYear = 2070,
    this.maxYear = 2095,
  });

  static Future<Map<String, int>?> show({
    required BuildContext context,
    required int initialYear,
    required int initialMonth,
    int minYear = 2070,
    int maxYear = 2095,
  }) {
    return showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => NepaliYearMonthPickerDialog(
        initialYear: initialYear,
        initialMonth: initialMonth,
        minYear: minYear,
        maxYear: maxYear,
      ),
    );
  }

  @override
  State<NepaliYearMonthPickerDialog> createState() =>
      _NepaliYearMonthPickerDialogState();
}

class _NepaliYearMonthPickerDialogState
    extends State<NepaliYearMonthPickerDialog> {
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear;
    _selectedMonth = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0075db);
    final bgColor = isDarkMode ? const Color(0xFF141e28) : Colors.white;
    final surfaceAccent = isDarkMode ? const Color(0xFF1e2b38) : const Color(0xFFf1f5f9);
    final borderColor = isDarkMode ? const Color(0xFF2a3b4c) : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final textMuted = isDarkMode ? const Color(0xFF94a3b8) : const Color(0xFF64748b);

    final years = List.generate(
      widget.maxYear - widget.minYear + 1,
      (i) => widget.minYear + i,
    );

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Month & Year',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Manrope',
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bikram Sambat (BS) Calendar',
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: surfaceAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Year Selector Bar (Horizontal Scroll / Dropdown)
            Text(
              'YEAR (वर्ष)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textMuted,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: years.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final year = years[idx];
                  final isSelected = year == _selectedYear;
                  return InkWell(
                    onTap: () => setState(() => _selectedYear = year),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor : surfaceAccent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? primaryColor : borderColor,
                        ),
                      ),
                      child: Text(
                        '$year (${NepaliCalendarEngine.toNepaliDigits(year)})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : textColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Month Grid (12 Months in 3x4 layout)
            Text(
              'MONTH (महिना)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textMuted,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              itemCount: 12,
              itemBuilder: (context, idx) {
                final monthNum = idx + 1;
                final isSelected = monthNum == _selectedMonth;
                final monthNameEn = NepaliCalendarEngine.getMonthNameEnglish(monthNum);
                final monthNameNp = NepaliCalendarEngine.getMonthNameNepali(monthNum);

                return InkWell(
                  onTap: () => setState(() => _selectedMonth = monthNum),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor : surfaceAccent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? primaryColor : borderColor,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          monthNameEn,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          monthNameNp,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.white.withValues(alpha: 0.85) : textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final now = NepaliCalendarEngine.now();
                      setState(() {
                        _selectedYear = now.year;
                        _selectedMonth = now.month;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: borderColor),
                    ),
                    child: const Text('Current Month (आज)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'year': _selectedYear,
                        'month': _selectedMonth,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
