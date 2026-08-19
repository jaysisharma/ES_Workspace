import 'package:nepali_utils/nepali_utils.dart';

/// Accurate, timezone-invariant Nepali (Bikram Sambat) Calendar Engine.
/// Guarantees exact BS <-> AD date conversions, month lengths, weekday alignments,
/// and Devnagari numeral formatting without midnight / UTC off-by-one errors.
class NepaliCalendarEngine {
  NepaliCalendarEngine._();

  static const List<String> monthsEnglish = [
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

  static const List<String> monthsNepali = [
    'बैशाख',
    'जेठ',
    'असार',
    'श्रावण',
    'भाद्र',
    'आश्विन',
    'कार्तिक',
    'मंसिर',
    'पौष',
    'माघ',
    'फाल्गुन',
    'चैत्र',
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

  static const List<String> weekdaysEnglishFull = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  static const List<String> weekdaysNepali = [
    'आइत',
    'सोम',
    'मंगल',
    'बुध',
    'बिही',
    'शुक्र',
    'शनि',
  ];

  static const List<String> weekdaysNepaliFull = [
    'आइतबार',
    'सोमबार',
    'मंगलबार',
    'बुधबार',
    'बिहीबार',
    'शुक्रबार',
    'शनिबार',
  ];

  static const List<String> nepaliDigits = [
    '०',
    '१',
    '२',
    '३',
    '४',
    '५',
    '६',
    '७',
    '८',
    '९',
  ];

  /// Formats an integer to Nepali Devanagari numerals (e.g. 2081 -> २०८१).
  static String toNepaliDigits(dynamic number) {
    if (number == null) return '';
    final str = number.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      final codeUnit = str.codeUnitAt(i);
      if (codeUnit >= 48 && codeUnit <= 57) {
        buffer.write(nepaliDigits[codeUnit - 48]);
      } else {
        buffer.write(str[i]);
      }
    }
    return buffer.toString();
  }

  /// Converts an AD [DateTime] safely to [NepaliDateTime] avoiding midnight timezone drift.
  static NepaliDateTime adToBs(DateTime adDate) {
    // Force midday normalization (12:00:00) to ensure zero UTC-offset distortion across timezones
    final safeAd = DateTime(adDate.year, adDate.month, adDate.day, 12, 0, 0);
    return safeAd.toNepaliDateTime();
  }

  /// Converts a [NepaliDateTime] to an AD [DateTime] set at midday (12:00:00).
  static DateTime bsToAd(NepaliDateTime bsDate) {
    final ad = bsDate.toDateTime();
    return DateTime(ad.year, ad.month, ad.day, 12, 0, 0);
  }

  /// Returns today's [NepaliDateTime].
  static NepaliDateTime now() {
    return NepaliDateTime.now();
  }

  /// Returns the total number of days in a given BS month of a year.
  static int getDaysInMonth(int bsYear, int bsMonth) {
    if (bsYear < 2000 || bsYear > 2099 || bsMonth < 1 || bsMonth > 12) {
      return 30; // Safe fallback
    }
    final firstDay = NepaliDateTime(bsYear, bsMonth, 1);
    return firstDay.totalDays;
  }

  /// Returns the starting weekday offset (0 = Sunday ... 6 = Saturday) for a BS month.
  static int getStartWeekdayOffset(int bsYear, int bsMonth) {
    final firstDay = NepaliDateTime(bsYear, bsMonth, 1);
    // In nepali_utils: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
    return (firstDay.weekday - 1).clamp(0, 6);
  }

  /// Formats a [NepaliDateTime] according to standard patterns with English or Nepali language.
  static String format(NepaliDateTime date, {String pattern = 'MMMM dd, yyyy', Language language = Language.english}) {
    return NepaliDateFormat(pattern, language).format(date);
  }

  /// Checks if two BS dates represent the same calendar day.
  static bool isSameDay(NepaliDateTime? a, NepaliDateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Checks if a date is within a closed date range [start, end].
  static bool isDateInRange(NepaliDateTime date, NepaliDateTime start, NepaliDateTime end) {
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
    final nepaliDate = referenceDate != null
        ? referenceDate.toNepaliDateTime()
        : NepaliDateTime.now();
    final startYear =
        nepaliDate.month >= 4 ? nepaliDate.year : nepaliDate.year - 1;
    final endYearShort = ((startYear + 1) % 100).toString().padLeft(2, '0');
    return 'FY $startYear/$endYearShort';
  }

  /// Checks if a given [DateTime] falls within the current Nepali Fiscal Year.
  static bool isWithinCurrentFiscalYear(DateTime date, {DateTime? referenceDate}) {
    final ref = referenceDate != null
        ? referenceDate.toNepaliDateTime()
        : NepaliDateTime.now();
    final int startYear = ref.month >= 4 ? ref.year : ref.year - 1;
    final fyStart = NepaliDateTime(startYear, 4, 1).toDateTime();
    final fyEnd = NepaliDateTime(startYear + 1, 4, 1).toDateTime();
    return !date.isBefore(fyStart) && date.isBefore(fyEnd);
  }

  /// Returns a human-readable label of the active leave reset cycle.
  static String getLeaveCycleLabel({
    String cycleType = 'nepali_fiscal',
    DateTime? manualStartDate,
  }) {
    if (manualStartDate != null) {
      final bs = manualStartDate.toNepaliDateTime();
      return 'Custom Cycle (Since ${NepaliDateFormat('dd MMM yyyy').format(bs)})';
    }
    switch (cycleType) {
      case 'nepali_year':
        final nepaliNow = NepaliDateTime.now();
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
        final dateNepali = date.toNepaliDateTime();
        final nowNepali = NepaliDateTime.now();
        return dateNepali.year == nowNepali.year;
      case 'calendar_year':
        return date.year == DateTime.now().year;
      case 'nepali_fiscal':
      default:
        return isWithinCurrentFiscalYear(date);
    }
  }
}
