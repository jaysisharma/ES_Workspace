import 'package:nepali_utils/nepali_utils.dart';

import 'package:order_app/core/calendar/bs_calendar_service.dart';

/// Accurate, timezone-invariant Nepali (Bikram Sambat) Calendar Engine.
/// Guarantees exact BS <-> AD date conversions, month lengths, weekday alignments,
/// and Devnagari numeral formatting without midnight / UTC / local timezone off-by-one errors.
///
/// NOTE: In Phase 3, this engine delegates all core calculations to [BsCalendarService]
/// ensuring ONE SINGLE SOURCE OF TRUTH across the application.
class NepaliCalendarEngine {
  NepaliCalendarEngine._();

  static const List<String> monthsEnglish = BsCalendarService.monthsEnglish;
  static const List<String> monthsNepali = BsCalendarService.monthsNepali;
  static const List<String> weekdaysEnglish = BsCalendarService.weekdaysEnglish;
  static const List<String> weekdaysEnglishFull =
      BsCalendarService.weekdaysEnglishFull;
  static const List<String> weekdaysNepali = BsCalendarService.weekdaysNepali;
  static const List<String> weekdaysNepaliFull =
      BsCalendarService.weekdaysNepaliFull;
  static const List<String> nepaliDigits = BsCalendarService.nepaliDigits;

  /// Formats an integer to Nepali Devanagari numerals (e.g. 2081 -> २०८१).
  static String toNepaliDigits(dynamic number) =>
      BsCalendarService.toNepaliDigits(number);

  /// Converts an AD [DateTime] safely to [NepaliDateTime] using pure UTC calendar math.
  /// Delegates directly to [BsCalendarService].
  static NepaliDateTime adToBs(DateTime adDate) {
    final bs = BsCalendarService.adToBs(adDate);
    return NepaliDateTime(
      bs.year,
      bs.month,
      bs.day,
      adDate.hour,
      adDate.minute,
      adDate.second,
      adDate.millisecond,
      adDate.microsecond,
    );
  }

  /// Converts a [NepaliDateTime] to an AD [DateTime] set safely at midday (12:00:00).
  /// Delegates directly to [BsCalendarService].
  static DateTime bsToAd(NepaliDateTime bsDate) {
    return BsCalendarService.bsToAd(bsDate.year, bsDate.month, bsDate.day);
  }

  /// Returns today's [NepaliDateTime] in timezone-safe manner.
  static NepaliDateTime now() {
    return adToBs(DateTime.now());
  }

  /// Returns the total number of days in a given BS month of a year.
  static int getDaysInMonth(int bsYear, int bsMonth) {
    return BsCalendarService.getDaysInMonth(bsYear, bsMonth);
  }

  /// Alias for getDaysInMonth
  static int daysInMonth(int bsYear, int bsMonth) =>
      BsCalendarService.getDaysInMonth(bsYear, bsMonth);

  /// Returns the starting weekday offset (0 = Sunday ... 6 = Saturday) for a BS month.
  static int getStartWeekdayOffset(int bsYear, int bsMonth) {
    return BsCalendarService.getStartWeekdayOffset(bsYear, bsMonth);
  }

  /// Formats a [NepaliDateTime] according to standard patterns with English or Nepali language.
  static String format(
    NepaliDateTime date, {
    String pattern = 'MMMM dd, yyyy',
    Language language = Language.english,
  }) {
    return NepaliDateFormat(pattern, language).format(date);
  }

  /// Checks if two BS dates represent the same calendar day.
  static bool isSameDay(NepaliDateTime? a, NepaliDateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Checks if a date is within a closed date range [start, end].
  static bool isDateInRange(
    NepaliDateTime date,
    NepaliDateTime start,
    NepaliDateTime end,
  ) {
    final cleanDate = NepaliDateTime(date.year, date.month, date.day);
    final cleanStart = NepaliDateTime(start.year, start.month, start.day);
    final cleanEnd = NepaliDateTime(end.year, end.month, end.day);
    return !cleanDate.isBefore(cleanStart) && !cleanDate.isAfter(cleanEnd);
  }

  /// Returns the English name of the month (1-indexed).
  static String getMonthNameEnglish(int month) {
    if (month < 1 || month > 12) return '';
    return monthsEnglish[month - 1];
  }

  /// Returns the Nepali Devanagari name of the month (1-indexed).
  static String getMonthNameNepali(int month) {
    if (month < 1 || month > 12) return '';
    return monthsNepali[month - 1];
  }

  /// Returns the Nepali Fiscal Year label (e.g. "FY 2081/82" running 1 Shrawan - Ashadh end).
  static String getCurrentFiscalYearLabel([DateTime? referenceDate]) {
    final nepaliDate = referenceDate != null ? adToBs(referenceDate) : now();
    final startYear = nepaliDate.month >= 4
        ? nepaliDate.year
        : nepaliDate.year - 1;
    final endYearShort = ((startYear + 1) % 100).toString().padLeft(2, '0');
    return 'FY $startYear/$endYearShort';
  }

  /// Checks if a given [DateTime] falls within the current Nepali Fiscal Year.
  static bool isWithinCurrentFiscalYear(
    DateTime date, {
    DateTime? referenceDate,
  }) {
    final ref = referenceDate != null ? adToBs(referenceDate) : now();
    final int startYear = ref.month >= 4 ? ref.year : ref.year - 1;
    final fyStart = bsToAd(NepaliDateTime(startYear, 4, 1));
    final fyEnd = bsToAd(NepaliDateTime(startYear + 1, 4, 1));
    return !date.isBefore(fyStart) && date.isBefore(fyEnd);
  }

  /// Returns a human-readable label of the active leave reset cycle.
  static String getLeaveCycleLabel({
    String cycleType = 'nepali_fiscal',
    DateTime? manualStartDate,
  }) {
    if (manualStartDate != null) {
      final bs = adToBs(manualStartDate);
      return 'Custom Cycle (Since ${NepaliDateFormat('dd MMM yyyy').format(bs)})';
    }
    switch (cycleType) {
      case 'nepali_year':
        final nepaliNow = now();
        return 'Nepali Year ${nepaliNow.year} BS (1 Baisakh - Chaitra)';
      case 'calendar_year':
        return 'Calendar Year ${DateTime.now().year} (1 Jan - 31 Dec)';
      case 'nepali_fiscal':
      default:
        return getCurrentFiscalYearLabel();
    }
  }

  /// Checks if a date falls within the active leave cycle based on admin settings.
  static bool isWithinActiveLeaveCycle(
    DateTime date, {
    String cycleType = 'nepali_fiscal',
    DateTime? manualStartDate,
  }) {
    if (manualStartDate != null) {
      final start = DateTime(
        manualStartDate.year,
        manualStartDate.month,
        manualStartDate.day,
      );
      return !date.isBefore(start);
    }
    switch (cycleType) {
      case 'nepali_year':
        final dateNepali = adToBs(date);
        final nowNepali = now();
        return dateNepali.year == nowNepali.year;
      case 'calendar_year':
        return date.year == DateTime.now().year;
      case 'nepali_fiscal':
      default:
        return isWithinCurrentFiscalYear(date);
    }
  }

  /// Validates if year, month, and day form a valid Bikram Sambat date.
  static bool isValidBsDate(int year, int month, int day) =>
      BsCalendarService.isValidBsDate(year, month, day);

  /// Normalizes Devanagari numerals to standard ASCII digits.
  static String normalizeNepaliDigits(String input) =>
      BsCalendarService.normalizeNepaliDigits(input);

  /// Parses a string representation of a Bikram Sambat date.
  /// Supports separators `-`, `/`, `.`, space, or comma (e.g. "2081-05-15", "2081/5/15", "२०८१-०५-१५").
  /// Returns [NepaliDateTime] if valid, or `null` if invalid.
  static NepaliDateTime? tryParseBs(String? input) {
    final parsed = BsCalendarService.tryParseBs(input);
    if (parsed == null) return null;
    return NepaliDateTime(parsed.year, parsed.month, parsed.day);
  }
}
