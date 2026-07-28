import 'package:nepali_utils/nepali_utils.dart';

/// Converts an AD [DateTime] to a Nepali (BS) formatted string.
/// [pattern] follows NepaliDateFormat patterns (e.g. 'MMMM dd, yyyy').
String formatNepaliDate(DateTime date, String pattern) {
  final nepaliDate = date.toNepaliDateTime();
  return NepaliDateFormat(pattern).format(nepaliDate);
}
