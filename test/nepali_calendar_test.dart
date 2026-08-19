import 'package:flutter_test/flutter_test.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:order_app/core/calendar/nepali_calendar_engine.dart';
import 'package:order_app/core/calendar/nepali_holidays.dart';

void main() {
  group('NepaliCalendarEngine Tests', () {
    test('Nepali New Year (2081 Baisakh 1) converts accurately to 2024 April 13', () {
      final bs = NepaliDateTime(2081, 1, 1);
      final ad = NepaliCalendarEngine.bsToAd(bs);

      expect(ad.year, 2024);
      expect(ad.month, 4);
      expect(ad.day, 13);

      final backToBs = NepaliCalendarEngine.adToBs(ad);
      expect(backToBs.year, 2081);
      expect(backToBs.month, 1);
      expect(backToBs.day, 1);
    });

    test('Midnight AD dates do not experience off-by-one date shifts', () {
      final midnightAd = DateTime(2024, 4, 13, 0, 0, 0);
      final middayAd = DateTime(2024, 4, 13, 12, 0, 0);
      final lateNightAd = DateTime(2024, 4, 13, 23, 59, 59);

      final bs1 = NepaliCalendarEngine.adToBs(midnightAd);
      final bs2 = NepaliCalendarEngine.adToBs(middayAd);
      final bs3 = NepaliCalendarEngine.adToBs(lateNightAd);

      expect(bs1.year, 2081);
      expect(bs1.month, 1);
      expect(bs1.day, 1);

      expect(bs2.year, 2081);
      expect(bs2.month, 1);
      expect(bs2.day, 1);

      expect(bs3.year, 2081);
      expect(bs3.month, 1);
      expect(bs3.day, 1);
    });

    test('Devanagari digit conversion works accurately', () {
      expect(NepaliCalendarEngine.toNepaliDigits(2081), '२०८१');
      expect(NepaliCalendarEngine.toNepaliDigits(15), '१५');
      expect(NepaliCalendarEngine.toNepaliDigits(0), '०');
    });

    test('Total days in BS months are valid and within certified limits (29-32)', () {
      for (int month = 1; month <= 12; month++) {
        final days = NepaliCalendarEngine.getDaysInMonth(2081, month);
        expect(days >= 29 && days <= 32, isTrue, reason: 'Month $month has $days days');
      }
    });

    test('Nepali month names in English and Devanagari match', () {
      expect(NepaliCalendarEngine.getMonthNameEnglish(1), 'Baisakh');
      expect(NepaliCalendarEngine.getMonthNameNepali(1), 'बैशाख');
      expect(NepaliCalendarEngine.getMonthNameEnglish(12), 'Chaitra');
      expect(NepaliCalendarEngine.getMonthNameNepali(12), 'चैत्र');
    });
  });

  group('NepaliHolidays Tests', () {
    test('Detects Saturday correctly', () {
      // 2081 Baisakh 1 was a Saturday
      final newYear2081 = NepaliDateTime(2081, 1, 1);
      expect(NepaliHolidays.isSaturday(newYear2081), isTrue);
      expect(NepaliHolidays.isPublicHoliday(newYear2081), isTrue);
    });

    test('Detects fixed national holidays', () {
      final constitutionDay = NepaliDateTime(2081, 6, 3);
      final holiday = NepaliHolidays.getHoliday(constitutionDay);
      expect(holiday, isNotNull);
      expect(holiday!.nameEnglish.contains('Constitution Day'), isTrue);
      expect(NepaliHolidays.isPublicHoliday(constitutionDay), isTrue);
    });

    test('Detects Dashain Vijaya Dashami festival', () {
      final tika2081 = NepaliDateTime(2081, 6, 27);
      final holiday = NepaliHolidays.getHoliday(tika2081);
      expect(holiday, isNotNull);
      expect(holiday!.nameEnglish.contains('Vijaya Dashami'), isTrue);
    });
  });
}
