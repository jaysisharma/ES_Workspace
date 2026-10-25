import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_app/core/calendar/bs_calendar_service.dart';

void main() {
  group('BsCalendarService Ground Truth Reference Tests', () {
    test('2073 Baisakh 1 converts to 2016 April 13', () {
      final ad = BsCalendarService.bsToAd(2073, 1, 1);
      expect(ad.year, 2016);
      expect(ad.month, 4);
      expect(ad.day, 13);

      final bs = BsCalendarService.adToBs(ad);
      expect(bs, const BsDate(2073, 1, 1));
    });

    test('2081 Baisakh 1 converts to 2024 April 13', () {
      final ad = BsCalendarService.bsToAd(2081, 1, 1);
      expect(ad.year, 2024);
      expect(ad.month, 4);
      expect(ad.day, 13);

      final bs = BsCalendarService.adToBs(ad);
      expect(bs, const BsDate(2081, 1, 1));
    });

    test('2081 Bhadra 7 converts to 2024 August 23', () {
      final ad = BsCalendarService.bsToAd(2081, 5, 7);
      expect(ad.year, 2024);
      expect(ad.month, 8);
      expect(ad.day, 23);

      final bs = BsCalendarService.adToBs(ad);
      expect(bs, const BsDate(2081, 5, 7));
    });

    test('2083 Baisakh 1 converts to 2026 April 14', () {
      final ad = BsCalendarService.bsToAd(2083, 1, 1);
      expect(ad.year, 2026);
      expect(ad.month, 4);
      expect(ad.day, 14);

      final bs = BsCalendarService.adToBs(ad);
      expect(bs, const BsDate(2083, 1, 1));
    });

    test('2083 Ashwin 15 converts to 2026 October 1', () {
      final ad = BsCalendarService.bsToAd(2083, 6, 15);
      expect(ad.year, 2026);
      expect(ad.month, 10);
      expect(ad.day, 1);

      final bs = BsCalendarService.adToBs(ad);
      expect(bs, const BsDate(2083, 6, 15));
    });
  });

  group('BsCalendarService Complete 2073-2093 Bidirectional Verification', () {
    test('100% round-trip identity across every single day from 2073 to 2093 BS', () {
      for (int year = 2073; year <= 2093; year++) {
        for (int month = 1; month <= 12; month++) {
          final totalDays = BsCalendarService.getDaysInMonth(year, month);
          expect(totalDays >= 29 && totalDays <= 32, isTrue,
              reason: 'Invalid day count $totalDays in $year-$month');

          for (int day = 1; day <= totalDays; day++) {
            final ad = BsCalendarService.bsToAd(year, month, day);
            final bsBack = BsCalendarService.adToBs(ad);

            expect(bsBack.year, year, reason: 'Failed year on $year-$month-$day');
            expect(bsBack.month, month, reason: 'Failed month on $year-$month-$day');
            expect(bsBack.day, day, reason: 'Failed day on $year-$month-$day');
          }
        }
      }
    });

    test('Boundary test: First day (Day 1) and Last day for all months in 2073, 2083, 2093', () {
      final checkYears = [2073, 2081, 2082, 2083, 2084, 2092, 2093];
      for (final y in checkYears) {
        for (int m = 1; m <= 12; m++) {
          final lastDay = BsCalendarService.getDaysInMonth(y, m);

          // Day 1
          final adFirst = BsCalendarService.bsToAd(y, m, 1);
          final bsFirst = BsCalendarService.adToBs(adFirst);
          expect(bsFirst, BsDate(y, m, 1));

          // Last Day
          final adLast = BsCalendarService.bsToAd(y, m, lastDay);
          final bsLast = BsCalendarService.adToBs(adLast);
          expect(bsLast, BsDate(y, m, lastDay));
        }
      }
    });
  });

  group('Date Validation & Edge Cases', () {
    test('Correctly rejects invalid BS dates', () {
      expect(BsCalendarService.isValidBsDate(2083, 5, 32), isFalse); // Bhadra 2083 has 31 days
      expect(BsCalendarService.isValidBsDate(2083, 6, 31), isTrue);  // Ashwin 2083 has 31 days
      expect(BsCalendarService.isValidBsDate(2083, 13, 1), isFalse); // Month 13
      expect(BsCalendarService.isValidBsDate(2083, 0, 1), isFalse);  // Month 0
      expect(BsCalendarService.isValidBsDate(2083, 1, 0), isFalse);  // Day 0
      expect(BsCalendarService.isValidBsDate(2083, 1, 35), isFalse); // Day 35
    });

    test('tryParseBs handles different delimiters and Devanagari digits', () {
      expect(BsCalendarService.tryParseBs('2083-06-15'), const BsDate(2083, 6, 15));
      expect(BsCalendarService.tryParseBs('2083/6/15'), const BsDate(2083, 6, 15));
      expect(BsCalendarService.tryParseBs('2083.6.15'), const BsDate(2083, 6, 15));
      expect(BsCalendarService.tryParseBs('२०८३-०६-१५'), const BsDate(2083, 6, 15));
      expect(BsCalendarService.tryParseBs('invalid'), isNull);
      expect(BsCalendarService.tryParseBs('2083-05-32'), isNull);
    });
  });

  group('Timezone & Hour Invariance', () {
    test('Midnight UTC, midday, and late evening AD timestamps map to identical BS date', () {
      // 2026-10-01 is 2083 Ashwin 15
      final midnightUtc = DateTime.utc(2026, 10, 1, 0, 0, 0); // 05:45 AM Kathmandu
      final middayUtc = DateTime.utc(2026, 10, 1, 6, 15, 0);   // 12:00 PM Kathmandu
      final eveningUtc = DateTime.utc(2026, 10, 1, 14, 0, 0);  // 19:45 PM Kathmandu

      expect(BsCalendarService.adToBs(midnightUtc), const BsDate(2083, 6, 15));
      expect(BsCalendarService.adToBs(middayUtc), const BsDate(2083, 6, 15));
      expect(BsCalendarService.adToBs(eveningUtc), const BsDate(2083, 6, 15));
    });

    test('Firestore Timestamp round-trip is completely lossless', () {
      final ts = BsCalendarService.bsToTimestamp(2083, 6, 15);
      final bs = BsCalendarService.timestampToBs(ts);
      expect(bs, const BsDate(2083, 6, 15));
    });
  });

  group('BS Month Range Filtering', () {
    test('getBsMonthAdRange accurately encloses all days of the BS month', () {
      final range = BsCalendarService.getBsMonthAdRange(2083, 6); // 2083 Ashwin (31 days)

      final day1Ad = BsCalendarService.bsToAd(2083, 6, 1);
      final day15Ad = BsCalendarService.bsToAd(2083, 6, 15);
      final day31Ad = BsCalendarService.bsToAd(2083, 6, 31);

      // Previous month last day & next month first day
      final prevMonthLastDayAd = BsCalendarService.bsToAd(2083, 5, 31);
      final nextMonthFirstDayAd = BsCalendarService.bsToAd(2083, 7, 1);

      // Ashwin events must be within range
      expect(day1Ad.isAfter(range.start.subtract(const Duration(seconds: 1))), isTrue);
      expect(day1Ad.isBefore(range.end.add(const Duration(seconds: 1))), isTrue);

      expect(day15Ad.isAfter(range.start), isTrue);
      expect(day15Ad.isBefore(range.end), isTrue);

      expect(day31Ad.isAfter(range.start), isTrue);
      expect(day31Ad.isBefore(range.end.add(const Duration(seconds: 1))), isTrue);

      // Bhadra and Kartik events must be strictly OUTSIDE the range
      expect(prevMonthLastDayAd.isBefore(range.start), isTrue);
      expect(nextMonthFirstDayAd.isAfter(range.end), isTrue);
    });
  });

  group('Chronological Sorting & Comparison', () {
    test('BsDate comparison is strictly chronological', () {
      final d1 = const BsDate(2083, 5, 30);
      final d2 = const BsDate(2083, 6, 1);
      final d3 = const BsDate(2083, 6, 15);
      final d4 = const BsDate(2084, 1, 1);

      final list = [d3, d1, d4, d2];
      list.sort();

      expect(list, [d1, d2, d3, d4]);
    });

    test('Timestamp-based sorting matches BsDate sorting', () {
      final dates = [
        const BsDate(2073, 1, 1),
        const BsDate(2081, 5, 7),
        const BsDate(2083, 6, 15),
        const BsDate(2084, 2, 10),
        const BsDate(2093, 12, 30),
      ];

      final timestamps = dates.map((d) => d.toTimestamp()).toList();
      for (int i = 0; i < timestamps.length - 1; i++) {
        expect(timestamps[i].compareTo(timestamps[i + 1]) < 0, isTrue);
      }
    });
  });
}
