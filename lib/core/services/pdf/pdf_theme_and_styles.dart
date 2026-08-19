import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/purchase_order_entity.dart';

class PdfThemeAndStyles {
  static const darkColor = PdfColor.fromInt(0xFF000000);
  static const labelColor = PdfColor.fromInt(0xFF4b5563);
  static const borderColor = PdfColor.fromInt(0xFF000000);
  static const lightBg = PdfColor.fromInt(0xFFf3f4f6);

  static pw.Widget buildHeader(
    pw.MemoryImage logo,
    OrderEntity? order, {
    String title = 'ORDER SUMMARY',
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8, bottom: 16),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: borderColor, width: 1.5),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 80,
            height: 80,
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: darkColor,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.SizedBox(height: 4),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                order != null ? 'ORDER ID: ${order.id}' : 'STATEMENT',
                style: pw.TextStyle(
                  fontSize: 15,
                  color: darkColor,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Date: ${formatNepaliDate(order?.createdAt ?? DateTime.now(), 'MMMM dd, yyyy')}',
                style: const pw.TextStyle(fontSize: 9, color: darkColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget buildPOHeader(pw.MemoryImage logo, PurchaseOrderEntity po) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8, bottom: 16),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: borderColor, width: 1.5),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 80,
            height: 80,
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PURCHASE ORDER',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: darkColor,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  po.vendorName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: darkColor,
                  ),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'PO #: ${po.poNumber}',
                style: pw.TextStyle(
                  fontSize: 15,
                  color: darkColor,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Date: ${formatNepaliDate(po.createdAt, 'MMMM dd, yyyy')}',
                style: const pw.TextStyle(fontSize: 9, color: darkColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borderColor, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: labelColor),
          ),
        ],
      ),
    );
  }

  static pw.Widget buildOrderInfoCard(OrderEntity order) {
    return card(
      title: 'ORDER INFORMATION',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            order.eventName,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: darkColor,
            ),
          ),
          pw.SizedBox(height: 8),
          infoRow('Order ID', order.id),
          pw.SizedBox(height: 4),
          infoRow('Venue', order.venue),
          pw.SizedBox(height: 4),
          infoRow(
            'Event Dates',
            formatDateRange(order.eventDate, order.eventEndDate),
          ),
          pw.SizedBox(height: 4),
          infoRow(
            'Setup Dates',
            formatDateRange(order.setupDate, order.setupEndDate),
          ),
          pw.SizedBox(height: 4),
          infoRow('Contact', order.contactPerson),
          pw.SizedBox(height: 4),
          infoRow('Phone', order.contactNumber),
        ],
      ),
    );
  }

  static pw.Widget buildPOOrderInfoCard(PurchaseOrderEntity po) {
    return card(
      title: 'PURCHASE ORDER DETAILS',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          infoRow('VENDOR NAME', po.vendorName),
          pw.SizedBox(height: 6),
          infoRow('RELATED ORDER', po.orderId.isEmpty ? 'N/A' : po.orderId),
          pw.SizedBox(height: 6),
          infoRow('EVENT NAME', po.eventName),
          pw.SizedBox(height: 6),
          infoRow('VENUE', po.venue),
          pw.SizedBox(height: 6),
          infoRow(
            'EVENT DATE',
            formatDateRange(po.eventDate, po.eventEndDate),
          ),
          pw.SizedBox(height: 6),
          infoRow(
            'SETUP DATE',
            formatDateRange(po.setupDate, po.setupEndDate),
          ),
        ],
      ),
    );
  }

  static String formatDateRange(DateTime start, DateTime? end) {
    if (end == null ||
        (start.year == end.year &&
            start.month == end.month &&
            start.day == end.day)) {
      return formatNepaliDate(start, 'MMMM dd, yyyy');
    }

    if (start.year == end.year) {
      if (start.month == end.month) {
        return '${formatNepaliDate(start, 'MMMM dd')} - ${formatNepaliDate(end, 'dd, yyyy')}';
      }
      return '${formatNepaliDate(start, 'MMMM dd')} - ${formatNepaliDate(end, 'MMMM dd, yyyy')}';
    }

    return '${formatNepaliDate(start, 'MMMM dd, yyyy')} - ${formatNepaliDate(end, 'MMMM dd, yyyy')}';
  }

  static pw.Widget tableCell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: darkColor,
        ),
        textAlign: align,
      ),
    );
  }

  static pw.Widget buildSignatureSection() {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 40),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          sigBlock('Prepared by'),
          sigBlock('Checked by'),
          sigBlock('Approved by'),
        ],
      ),
    );
  }

  static pw.Widget sigBlock(String label) {
    return pw.Column(
      children: [
        pw.Container(
          width: 120,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: borderColor, width: 0.5),
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: darkColor,
          ),
        ),
      ],
    );
  }

  static pw.Widget card({required String title, required pw.Widget child}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor, width: 0.5),
        borderRadius: pw.BorderRadius.circular(2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: darkColor,
              letterSpacing: 1.0,
            ),
          ),
          pw.SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  static pw.Widget infoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 70,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              color: labelColor,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Text(': ', style: const pw.TextStyle(fontSize: 8, color: labelColor)),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: darkColor,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget summaryRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 8,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: darkColor,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: darkColor,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget summarySummaryRow(
    String label,
    String value, {
    bool isBold = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: labelColor)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: darkColor,
          ),
        ),
      ],
    );
  }
}
