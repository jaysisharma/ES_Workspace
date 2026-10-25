import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nepali_utils/nepali_utils.dart';

/// Immutable representation of a Bikram Sambat (BS) calendar day.
class BsDate implements Comparable<BsDate> {
  final int year;
  final int month;
  final int day;

  const BsDate(this.year, this.month, this.day);

  /// Converts this BS date to the canonical AD [DateTime] set at midday (12:00:00 Asia/Kathmandu).
  DateTime toAd() => BsCalendarService.bsToAd(year, month, day);

  /// Converts this BS date to a Firestore [Timestamp] set at midday Asia/Kathmandu.
  Timestamp toTimestamp() => BsCalendarService.bsToTimestamp(year, month, day);

  /// Formats this BS date into a string pattern (e.g. 'yyyy-MM-dd', 'MMMM dd, yyyy').
  String format({
    String pattern = 'yyyy-MM-dd',
    Language language = Language.english,
  }) {
    return BsCalendarService.formatBs(
      toAd(),
      pattern: pattern,
      language: language,
    );
  }

  /// Standard ISO-like BS date string: 'YYYY-MM-DD'.
  String get isoString =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  String toString() => isoString;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BsDate &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month &&
          day == other.day;

  @override
  int get hashCode => year.hashCode ^ month.hashCode ^ day.hashCode;

  @override
  int compareTo(BsDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  bool isBefore(BsDate other) => compareTo(other) < 0;
  bool isAfter(BsDate other) => compareTo(other) > 0;
  bool isAtSameMomentAs(BsDate other) => compareTo(other) == 0;
}

/// Central, timezone-deterministic Bikram Sambat (BS) Calendar Service.
///
/// This service is the SINGLE SOURCE OF TRUTH for:
/// - BS <-> AD conversions
/// - Certified BS month lengths & weekday offsets
/// - BS Month & Year filtering ranges (AD start & end)
/// - Chronological comparisons (Past / Today / Upcoming)
/// - Devanagari digit & date formatting
///
/// All conversions are canonically anchored in Asia/Kathmandu (UTC+05:45).
class BsCalendarService {
  BsCalendarService._();

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

  /// Minimum and maximum BS years certified by Panchanga Nirnayak Samiti in nepali_utils.
  static const int minBsYear = 2000;
  static const int maxBsYear = 2099;

  /// Asia/Kathmandu fixed offset: UTC + 5 hours 45 minutes (no DST).
  static const Duration kathmanduOffset = Duration(hours: 5, minutes: 45);

  // ── 1. Digits & Numeral Parsing ────────────────────────────────────────────

  /// Converts any integer or number string into Nepali Devanagari digits (e.g. 2083 -> २०८३).
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

  /// Normalizes Nepali Devanagari numerals into ASCII digits ('०'-'९' -> '0'-'9').
  static String normalizeNepaliDigits(String input) {
    const nepaliToAscii = {
      '०': '0',
      '१': '1',
      '२': '2',
      '३': '3',
      '४': '4',
      '५': '5',
      '६': '6',
      '७': '7',
      '८': '8',
      '९': '9',
    };
    var result = input;
    nepaliToAscii.forEach((np, en) {
      result = result.replaceAll(np, en);
    });
    return result;
  }

  // ── 2. Month Length & Date Validation ──────────────────────────────────────

  /// Returns the certified total number of days in a given BS month of a given BS year.
  static int getDaysInMonth(int bsYear, int bsMonth) {
    if (bsYear < minBsYear || bsYear > maxBsYear || bsMonth < 1 || bsMonth > 12) {
      return 30; // Safe fallback
    }
    return NepaliDateTime(bsYear, bsMonth, 1).totalDays;
  }

  /// Validates whether a BS date is completely valid according to certified calendar tables.
  static bool isValidBsDate(int bsYear, int bsMonth, int bsDay) {
    if (bsYear < minBsYear || bsYear > maxBsYear) return false;
    if (bsMonth < 1 || bsMonth > 12) return false;
    if (bsDay < 1) return false;
    final maxDays = getDaysInMonth(bsYear, bsMonth);
    return bsDay <= maxDays;
  }

  /// Starting weekday offset for a BS month (0 = Sunday, 1 = Monday, ..., 6 = Saturday).
  static int getStartWeekdayOffset(int bsYear, int bsMonth) {
    final firstDayAd = bsToAd(bsYear, bsMonth, 1);
    // Dart DateTime: Monday=1 ... Sunday=7 -> 0 = Sunday, 1 = Monday ... 6 = Saturday
    return firstDayAd.weekday % 7;
  }

  // ── 3. Core Bidirectional Conversions ───────────────────────────────────────

  /// Converts a BS date into the canonical machine-readable AD [DateTime].
  ///
  /// The canonical DateTime is anchored at midday (12:00:00 Asia/Kathmandu time,
  /// which corresponds to 06:15:00 UTC).
  /// This midday anchoring ensures that regardless of user device timezone
  /// (-12h to +14h), the date never shifts to the previous or next day.
  static DateTime bsToAd(int bsYear, int bsMonth, int bsDay) {
    // Clamp to valid day if needed
    final safeDay = bsDay.clamp(1, getDaysInMonth(bsYear, bsMonth));
    final nepaliDt = NepaliDateTime(bsYear, bsMonth, safeDay, 12, 0, 0);
    final rawAd = nepaliDt.toDateTime();
    return DateTime(rawAd.year, rawAd.month, rawAd.day, 12, 0, 0);
  }

  /// Converts a BS date directly into a canonical Firestore [Timestamp].
  static Timestamp bsToTimestamp(int bsYear, int bsMonth, int bsDay) {
    return Timestamp.fromDate(bsToAd(bsYear, bsMonth, bsDay));
  }

  /// Converts any AD [DateTime] to its canonical [BsDate] components.
  ///
  /// Takes the instant, converts it deterministically to Asia/Kathmandu time (+05:45),
  /// extracts the calendar year/month/day, and performs the BS conversion.
  static BsDate adToBs(DateTime adDate) {
    // Deterministic shift to Asia/Kathmandu time
    final ktm = adDate.isUtc
        ? adDate.add(kathmanduOffset)
        : adDate.toUtc().add(kathmanduOffset);

    final cleanAd = DateTime(ktm.year, ktm.month, ktm.day);
    final np = NepaliDateTime.fromDateTime(cleanAd);
    return BsDate(np.year, np.month, np.day);
  }

  /// Converts a Firestore [Timestamp] to its canonical [BsDate] components.
  static BsDate timestampToBs(Timestamp timestamp) {
    return adToBs(timestamp.toDate());
  }

  /// Safely converts any dynamic date value (Timestamp, DateTime, String, int) to [BsDate].
  static BsDate parseToBs(dynamic value) {
    if (value == null) return todayBs();
    if (value is Timestamp) return timestampToBs(value);
    if (value is DateTime) return adToBs(value);
    if (value is int) return adToBs(DateTime.fromMillisecondsSinceEpoch(value));
    if (value is String) {
      // First check if it's already a formatted BS string like '2083-06-15'
      final directBs = tryParseBs(value);
      if (directBs != null) return directBs;

      // Otherwise parse as ISO AD string
      final parsedAd = DateTime.tryParse(value);
      if (parsedAd != null) return adToBs(parsedAd);
    }
    return todayBs();
  }

  /// Safely converts any dynamic date value to canonical AD [DateTime].
  static DateTime parseToCanonicalAd(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) {
      // Normalize to midday if this is a calendar-only date
      final bs = adToBs(value);
      return bsToAd(bs.year, bs.month, bs.day);
    }
    if (value is int) {
      final dt = DateTime.fromMillisecondsSinceEpoch(value);
      final bs = adToBs(dt);
      return bsToAd(bs.year, bs.month, bs.day);
    }
    if (value is String) {
      final directBs = tryParseBs(value);
      if (directBs != null) {
        return directBs.toAd();
      }
      final parsedAd = DateTime.tryParse(value);
      if (parsedAd != null) {
        final bs = adToBs(parsedAd);
        return bsToAd(bs.year, bs.month, bs.day);
      }
    }
    return DateTime.now();
  }

  /// Safely converts any dynamic date value to canonical Firestore [Timestamp].
  static Timestamp parseToCanonicalTimestamp(dynamic value) {
    return Timestamp.fromDate(parseToCanonicalAd(value));
  }

  /// Parses a string representation of a Bikram Sambat date (e.g. "2083-06-15", "2083/6/15", "२०८३-०६-१५").
  static BsDate? tryParseBs(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final normalized = normalizeNepaliDigits(input.trim());
    final parts = normalized
        .split(RegExp(r'[\-\/\.\s,]+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.length != 3) return null;

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);

    if (year == null || month == null || day == null) return null;
    if (!isValidBsDate(year, month, day)) return null;

    return BsDate(year, month, day);
  }

  // ── 4. Canonical Month & Year Filtering Ranges ─────────────────────────────

  /// Computes the exact Gregorian [DateTimeRange] for an entire Bikram Sambat month.
  ///
  /// For example, for 2083 Ashwin:
  /// - start: 2083-06-01 00:00:00 (Kathmandu time)
  /// - end:   2083-06-[lastDay] 23:59:59.999 (Kathmandu time)
  ///
  /// This range must be used for all month filtering queries:
  /// `order.eventDate >= range.start && order.eventDate <= range.end`
  static DateTimeRange getBsMonthAdRange(int bsYear, int bsMonth) {
    final daysInMonth = getDaysInMonth(bsYear, bsMonth);

    // Day 1 at 00:00:00
    final firstDayBs = NepaliDateTime(bsYear, bsMonth, 1, 0, 0, 0);
    final startAd = firstDayBs.toDateTime();

    // Last day at 23:59:59.999
    final lastDayBs = NepaliDateTime(bsYear, bsMonth, daysInMonth, 23, 59, 59, 999);
    final endAd = lastDayBs.toDateTime();

    return DateTimeRange(start: startAd, end: endAd);
  }

  /// Computes the exact Gregorian [DateTimeRange] for an entire Bikram Sambat year (1 Baisakh to Chaitra end).
  static DateTimeRange getBsYearAdRange(int bsYear) {
    final startBs = NepaliDateTime(bsYear, 1, 1, 0, 0, 0);
    final endDays = getDaysInMonth(bsYear, 12);
    final endBs = NepaliDateTime(bsYear, 12, endDays, 23, 59, 59, 999);

    return DateTimeRange(start: startBs.toDateTime(), end: endBs.toDateTime());
  }

  // ── 5. Chronological Order Comparisons (Past / Today / Upcoming) ────────────

  /// Returns today's [BsDate] in Asia/Kathmandu time.
  static BsDate todayBs() {
    return adToBs(DateTime.now());
  }

  /// Returns whether a canonical date is strictly in the past relative to today in Nepal.
  static bool isPastEvent(dynamic canonicalDate) {
    final eventBs = parseToBs(canonicalDate);
    final today = todayBs();
    return eventBs.isBefore(today);
  }

  /// Returns whether a canonical date is today in Nepal.
  static bool isTodayEvent(dynamic canonicalDate) {
    final eventBs = parseToBs(canonicalDate);
    final today = todayBs();
    return eventBs == today;
  }

  /// Returns whether a canonical date is today or in the future in Nepal.
  static bool isUpcomingEvent(dynamic canonicalDate) {
    final eventBs = parseToBs(canonicalDate);
    final today = todayBs();
    return !eventBs.isBefore(today);
  }

  // ── 6. Formatting Helpers ──────────────────────────────────────────────────

  /// Formats a canonical date using [NepaliDateFormat] patterns.
  static String formatBs(
    dynamic canonicalDate, {
    String pattern = 'yyyy-MM-dd',
    Language language = Language.english,
  }) {
    final bs = parseToBs(canonicalDate);
    final nepaliDt = NepaliDateTime(bs.year, bs.month, bs.day);
    return NepaliDateFormat(pattern, language).format(nepaliDt);
  }

  /// Returns the English name of the BS month (1-indexed).
  static String getMonthNameEnglish(int month) {
    if (month < 1 || month > 12) return '';
    return monthsEnglish[month - 1];
  }

  /// Returns the Devanagari name of the BS month (1-indexed).
  static String getMonthNameNepali(int month) {
    if (month < 1 || month > 12) return '';
    return monthsNepali[month - 1];
  }
}
