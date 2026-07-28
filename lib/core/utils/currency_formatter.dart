import 'package:intl/intl.dart';

class CurrencyFormatter {
  /// Formats a double value to South Asian number system (Lakh/Crore).
  /// Example: 100000 becomes 1,00,000.00
  static String format(double value, {bool showDecimal = true}) {
    final format = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '',
      decimalDigits: showDecimal ? 2 : 0,
    );
    return format.format(value).trim();
  }

  /// Formats a double value with a prepended currency label.
  /// Example: formatWithLabel(100000, 'NPR') becomes NPR 1,00,000.00
  static String formatWithLabel(
    double value,
    String label, {
    bool showDecimal = true,
  }) {
    return '$label ${format(value, showDecimal: showDecimal)}';
  }

  /// Formats a double value with compact suffixes (k for thousands, L for Lakhs).
  static String formatCompact(double value) {
    if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(1)}L';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }
}
