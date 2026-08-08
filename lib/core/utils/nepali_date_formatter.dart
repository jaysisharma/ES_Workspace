import 'package:nepali_utils/nepali_utils.dart';

/// Converts a [NepaliDateTime] to a timezone-safe AD [DateTime] set at midday (12:00:00)
/// to prevent timezone / UTC midnight shifts (e.g. 26 Shrawan turning into 27 Shrawan).
DateTime safeNepaliToDateTime(NepaliDateTime np) {
  final ad = np.toDateTime();
  return DateTime(ad.year, ad.month, ad.day, 12, 0, 0);
}

/// Converts an AD [DateTime] safely to a [NepaliDateTime] by mitigating midnight timezone shifts.
NepaliDateTime safeDateTimeToNepali(DateTime dt) {
  final safe = (dt.hour == 0 && dt.minute == 0 && dt.second == 0)
      ? DateTime(dt.year, dt.month, dt.day, 12, 0, 0)
      : dt;
  return safe.toNepaliDateTime();
}

/// Converts an AD [DateTime] to a Nepali (BS) formatted string.
/// [pattern] follows NepaliDateFormat patterns (e.g. 'MMMM dd, yyyy').
String formatNepaliDate(DateTime date, String pattern) {
  final nepaliDate = safeDateTimeToNepali(date);
  return NepaliDateFormat(pattern).format(nepaliDate);
}
