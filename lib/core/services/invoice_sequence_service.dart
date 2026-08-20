import 'package:order_app/core/calendar/nepali_calendar_engine.dart';

class InvoiceSequenceService {
  InvoiceSequenceService._();

  /// Gets the current Nepal Fiscal Year representation (e.g. "81/82" for 2081/2082 BS)
  static String getCurrentFiscalYearString([DateTime? date]) {
    final targetDate = date ?? DateTime.now();
    final nepaliDate = NepaliCalendarEngine.adToBs(targetDate);
    final nepaliYear = nepaliDate.year; // e.g. 2081
    final nepaliMonth = nepaliDate.month; // 1 to 12

    // In Nepal, the fiscal year starts in Shrawan (Month 4)
    // If month >= 4 (Shrawan to Chaitra), FY is Year / (Year+1) -> 2081/82
    // If month < 4 (Baisakh to Ashadh), FY is (Year-1) / Year -> 2080/81
    int startYear;
    int endYear;

    if (nepaliMonth >= 4) {
      startYear = nepaliYear % 100;
      endYear = (nepaliYear + 1) % 100;
    } else {
      startYear = (nepaliYear - 1) % 100;
      endYear = nepaliYear % 100;
    }

    final startStr = startYear.toString().padLeft(2, '0');
    final endStr = endYear.toString().padLeft(2, '0');
    return '$startStr/$endStr';
  }

  /// Generates a standardized, clean default invoice number
  /// e.g. "INV-81/82-001" or "PI-81/82-001"
  static String generateSuggestedInvoiceNumber({
    bool isProforma = true,
    required String orderId,
    int? sequenceIndex,
    DateTime? date,
  }) {
    final prefix = isProforma ? 'PI' : 'INV';
    final fy = getCurrentFiscalYearString(date);

    if (sequenceIndex != null && sequenceIndex > 0) {
      final seqStr = sequenceIndex.toString().padLeft(3, '0');
      return '$prefix-$fy-$seqStr';
    }

    // Fallback using compact order identifier
    final shortId = orderId.length > 5 ? orderId.substring(0, 5).toUpperCase() : orderId.toUpperCase();
    return '$prefix-$fy-$shortId';
  }
}
