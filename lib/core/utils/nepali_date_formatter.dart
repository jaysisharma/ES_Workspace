import 'package:nepali_utils/nepali_utils.dart';
import 'package:order_app/core/calendar/bs_calendar_service.dart';

/// Converts a [NepaliDateTime] to a timezone-safe AD [DateTime] set at midday (12:00:00)
/// using [BsCalendarService] as the single source of truth.
DateTime safeNepaliToDateTime(NepaliDateTime np) {
  return BsCalendarService.bsToAd(np.year, np.month, np.day);
}

/// Converts an AD [DateTime] safely to a [NepaliDateTime] via [BsCalendarService].
NepaliDateTime safeDateTimeToNepali(DateTime dt) {
  final bs = BsCalendarService.adToBs(dt);
  return NepaliDateTime(
    bs.year,
    bs.month,
    bs.day,
    dt.hour,
    dt.minute,
    dt.second,
  );
}

/// Converts an AD [DateTime] to a Nepali (BS) formatted string via [BsCalendarService].
/// [pattern] follows NepaliDateFormat patterns (e.g. 'MMMM dd, yyyy').
String formatNepaliDate(DateTime date, String pattern, {Language language = Language.english}) {
  return BsCalendarService.formatBs(date, pattern: pattern, language: language);
}
