import 'package:nepali_utils/nepali_utils.dart';

/// Accurate, timezone-invariant Nepali (Bikram Sambat) Calendar Engine.
/// Guarantees exact BS <-> AD date conversions, month lengths, weekday alignments,
/// and Devnagari numeral formatting without midnight / UTC / local timezone off-by-one errors.
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

  /// Converts an AD [DateTime] safely to [NepaliDateTime] using pure UTC calendar math.
  /// 100% immune to OS timezones (Windows, macOS, Linux, Web) and daylight saving shifts.
  static NepaliDateTime adToBs(DateTime adDate) {
    final targetUtc = DateTime.utc(adDate.year, adDate.month, adDate.day);
    final refUtc = DateTime.utc(1913, 4, 13);
    var difference = targetUtc.difference(refUtc).inDays;

    var nepaliYear = 1970;
    var nepaliMonth = 1;
    var nepaliDay = 1;

    var daysInYear = _nepaliYearsMap[nepaliYear]?.first ?? 365;
    while (difference >= daysInYear && nepaliYear < 2099) {
      nepaliYear += 1;
      difference -= daysInYear;
      daysInYear = _nepaliYearsMap[nepaliYear]?.first ?? 365;
    }

    var yearData = _nepaliYearsMap[nepaliYear] ?? _defaultYearData;
    var daysInMonth = yearData[nepaliMonth];
    while (difference >= daysInMonth && nepaliMonth < 12) {
      difference -= daysInMonth;
      nepaliMonth += 1;
      daysInMonth = yearData[nepaliMonth];
    }

    nepaliDay += difference;

    return NepaliDateTime(
      nepaliYear,
      nepaliMonth,
      nepaliDay,
      adDate.hour,
      adDate.minute,
      adDate.second,
      adDate.millisecond,
      adDate.microsecond,
    );
  }

  /// Converts a [NepaliDateTime] to an AD [DateTime] set safely at midday (12:00:00).
  static DateTime bsToAd(NepaliDateTime bsDate) {
    final rawAd = bsDate.toDateTime();
    return DateTime(rawAd.year, rawAd.month, rawAd.day, 12, 0, 0);
  }

  /// Returns today's [NepaliDateTime] in timezone-safe manner.
  static NepaliDateTime now() {
    return adToBs(DateTime.now());
  }

  /// Returns the total number of days in a given BS month of a year.
  static int getDaysInMonth(int bsYear, int bsMonth) {
    final yearData = _nepaliYearsMap[bsYear];
    if (yearData != null && bsMonth >= 1 && bsMonth <= 12) {
      return yearData[bsMonth];
    }
    return 30; // Safe fallback
  }

  /// Returns the starting weekday offset (0 = Sunday ... 6 = Saturday) for a BS month.
  static int getStartWeekdayOffset(int bsYear, int bsMonth) {
    final firstDayAd = bsToAd(NepaliDateTime(bsYear, bsMonth, 1));
    // In Dart DateTime: Monday=1 ... Sunday=7 -> 0 = Sunday, 1 = Monday ... 6 = Saturday
    return firstDayAd.weekday % 7;
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
        ? adToBs(referenceDate)
        : now();
    final startYear =
        nepaliDate.month >= 4 ? nepaliDate.year : nepaliDate.year - 1;
    final endYearShort = ((startYear + 1) % 100).toString().padLeft(2, '0');
    return 'FY $startYear/$endYearShort';
  }

  /// Checks if a given [DateTime] falls within the current Nepali Fiscal Year.
  static bool isWithinCurrentFiscalYear(DateTime date, {DateTime? referenceDate}) {
    final ref = referenceDate != null
        ? adToBs(referenceDate)
        : now();
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

  static const List<int> _defaultYearData = [
    365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30
  ];

  static const Map<int, List<int>> _nepaliYearsMap = {
    1969: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    1970: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    1971: [365, 31, 31, 32, 31, 32, 30, 30, 29, 30, 29, 30, 30],
    1972: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    1973: [365, 30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    1974: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    1975: [365, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    1976: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    1977: [365, 30, 32, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
    1978: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    1979: [365, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    1980: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    1981: [365, 31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
    1982: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    1983: [365, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    1984: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    1985: [365, 31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
    1986: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    1987: [365, 31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    1988: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    1989: [365, 31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
    1990: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    1991: [365, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
    1992: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    1993: [365, 31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
    1994: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    1995: [365, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
    1996: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    1997: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    1998: [365, 31, 31, 32, 31, 32, 30, 30, 29, 30, 29, 30, 30],
    1999: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2000: [365, 30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2001: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2002: [365, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2003: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2004: [365, 30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2005: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2006: [365, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2007: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2008: [365, 31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
    2009: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2010: [365, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2011: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2012: [365, 31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
    2013: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2014: [365, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2015: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2016: [365, 31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
    2017: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2018: [365, 31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2019: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2020: [365, 31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
    2021: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2022: [365, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
    2023: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2024: [365, 31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
    2025: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2026: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2027: [365, 30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2028: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2029: [365, 31, 31, 32, 31, 32, 30, 30, 29, 30, 29, 30, 30],
    2030: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2031: [365, 30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2032: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2033: [365, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2034: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2035: [365, 30, 32, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
    2036: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2037: [365, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2038: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2039: [365, 31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
    2040: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2041: [365, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2042: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2043: [365, 31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
    2044: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2045: [365, 31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2046: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2047: [365, 31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
    2048: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2049: [365, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
    2050: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2051: [365, 31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
    2052: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2053: [365, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
    2054: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2055: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2056: [365, 31, 31, 32, 31, 32, 30, 30, 29, 30, 29, 30, 30],
    2057: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2058: [365, 30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2059: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2060: [365, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2061: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2062: [365, 30, 32, 31, 32, 31, 31, 29, 30, 29, 30, 29, 31],
    2063: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2064: [365, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2065: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2066: [365, 31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
    2067: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2068: [365, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2069: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2070: [365, 31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
    2071: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2072: [365, 31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2073: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2074: [365, 31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
    2075: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2076: [365, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
    2077: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2078: [365, 31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
    2079: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2080: [365, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
    2081: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2082: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2083: [365, 31, 31, 32, 31, 32, 30, 30, 29, 30, 29, 30, 30],
    2084: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2085: [365, 31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2086: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2087: [365, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2088: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2089: [365, 30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2090: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2091: [365, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2092: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2093: [365, 30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2094: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2095: [365, 31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2096: [366, 31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
    2097: [365, 31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
    2098: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2099: [365, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  };
}
