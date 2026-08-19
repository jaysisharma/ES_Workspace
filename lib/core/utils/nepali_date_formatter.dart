import 'package:nepali_utils/nepali_utils.dart';
import 'package:order_app/core/calendar/nepali_calendar_engine.dart';

/// Converts a [NepaliDateTime] to a timezone-safe AD [DateTime] set at midday (12:00:00)
/// to prevent timezone / UTC midnight shifts (e.g. 26 Shrawan turning into 27 Shrawan).
DateTime safeNepaliToDateTime(NepaliDateTime np) {
  return NepaliCalendarEngine.bsToAd(np);
}

/// Converts an AD [DateTime] safely to a [NepaliDateTime] by mitigating midnight timezone shifts.
NepaliDateTime safeDateTimeToNepali(DateTime dt) {
  return NepaliCalendarEngine.adToBs(dt);
}

/// Converts an AD [DateTime] to a Nepali (BS) formatted string.
/// [pattern] follows NepaliDateFormat patterns (e.g. 'MMMM dd, yyyy').
String formatNepaliDate(DateTime date, String pattern, {Language language = Language.english}) {
  final nepaliDate = safeDateTimeToNepali(date);
  return NepaliCalendarEngine.format(nepaliDate, pattern: pattern, language: language);
}
