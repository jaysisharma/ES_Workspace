import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/purchase_order_entity.dart';
import '../../utils/nepali_date_formatter.dart';
import 'pdf_theme_and_styles.dart';
import 'pdf_tables_builder.dart';

class ReportsPdfBuilder {
  static pw.EdgeInsets getAdaptiveMargin(PdfPageFormat pageFormat) {
    final isA5 = pageFormat.width < 500;
    return isA5
        ? const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 24)
        : const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 60);
  }

  static Future<Uint8List> generatePurchaseOrderPdf({
    required PurchaseOrderEntity po,
    required Uint8List logoBytes,
    required pw.Font font,
    required pw.Font boldFont,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Generating Purchase Order #${po.poNumber}...');

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: boldFont),
    );

    final logoImage = pw.MemoryImage(logoBytes);

    pdf.addPage(
      pw.MultiPage(
        maxPages: 100,
        pageFormat: pageFormat,
        margin: getAdaptiveMargin(pageFormat),
        header: (context) => PdfThemeAndStyles.buildPOHeader(logoImage, po),
        footer: (context) => PdfThemeAndStyles.buildFooter(context),
        build: (context) {
          return [
            pw.SizedBox(height: 16),
            PdfThemeAndStyles.buildPOOrderInfoCard(po),
            pw.SizedBox(height: 14),
            PdfTablesBuilder.buildPOTable(po),
            pw.SizedBox(height: 16),
            pw.SizedBox(height: 30),
            PdfThemeAndStyles.buildSignatureSection(),
            pw.SizedBox(height: 10),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateGlobalFinancialPdf({
    required List<OrderEntity> orders,
    required double totalRevenue,
    required double totalExpenses,
    required double netProfit,
    required double margin,
    required Uint8List logoBytes,
    required pw.Font font,
    required pw.Font boldFont,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Generating financial report...');

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: boldFont),
    );

    final logoImage = pw.MemoryImage(logoBytes);

    pdf.addPage(
      pw.MultiPage(
        maxPages: 100,
        pageFormat: pageFormat,
        margin: getAdaptiveMargin(pageFormat),
        header: (context) => PdfThemeAndStyles.buildHeader(logoImage, orders.first, title: 'FINANCIAL SUMMARY'),
        footer: (context) => PdfThemeAndStyles.buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 16),
          PdfTablesBuilder.buildGlobalFinancialSummaryCard(
            totalRevenue,
            totalExpenses,
            netProfit,
            margin,
          ),
          pw.SizedBox(height: 14),
          PdfTablesBuilder.buildOrdersFinancialTable(orders),
          pw.SizedBox(height: 24),
          PdfThemeAndStyles.buildSignatureSection(),
          pw.SizedBox(height: 10),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateFinancialLedgerPdf({
    required List<Map<String, dynamic>> ledgerEntries,
    required double totalRevenue,
    required double totalExpenses,
    required double netBalance,
    String entityName = '',
    String periodText = '',
    required Uint8List logoBytes,
    required pw.Font font,
    required pw.Font boldFont,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Generating Financial Ledger Statement...');

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: boldFont),
    );

    final logoImage = pw.MemoryImage(logoBytes);
    final headers = ['SN', 'Date', 'Order ID', 'Event Name', 'Description', 'Revenue (+)', 'Expense (-)'];
    final headerWidths = [0.6, 1.5, 1.5, 2.5, 2.5, 1.7, 1.7];
    final isA5 = pageFormat.width < 500;

    pdf.addPage(
      pw.MultiPage(
        maxPages: 100,
        pageFormat: pageFormat,
        margin: getAdaptiveMargin(pageFormat),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6, bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfThemeAndStyles.borderColor, width: 1.5),
            ),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: isA5 ? 50 : 70,
                height: isA5 ? 50 : 70,
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'FINANCIAL LEDGER STATEMENT',
                      style: pw.TextStyle(
                        fontSize: isA5 ? 14 : 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfThemeAndStyles.darkColor,
                        letterSpacing: 1.1,
                      ),
                    ),
                    if (entityName.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Entity / Account: $entityName',
                        style: pw.TextStyle(
                          fontSize: isA5 ? 9 : 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfThemeAndStyles.labelColor,
                        ),
                      ),
                    ],
                    if (periodText.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Period: $periodText',
                        style: pw.TextStyle(
                          fontSize: isA5 ? 8 : 10,
                          color: PdfThemeAndStyles.labelColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'PAGE ${context.pageNumber}',
                    style: pw.TextStyle(
                      fontSize: isA5 ? 10 : 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfThemeAndStyles.darkColor,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    formatNepaliDate(DateTime.now(), 'yyyy MMMM dd'),
                    style: const pw.TextStyle(fontSize: 8, color: PdfThemeAndStyles.labelColor),
                  ),
                ],
              ),
            ],
          ),
        ),
        footer: (context) => PdfThemeAndStyles.buildFooter(context),
        build: (context) {
          int sn = 1;
          final tableData = <List<String>>[];

          for (final entry in ledgerEntries) {
            final dateStr = entry['date'] != null
                ? (entry['date'] is DateTime
                    ? formatNepaliDate(entry['date'] as DateTime, 'yyyy-MM-dd')
                    : entry['date'].toString())
                : '-';
            final orderId = entry['orderId']?.toString() ?? '-';
            final eventName = entry['eventName']?.toString() ?? '-';
            final desc = entry['description']?.toString() ?? '';
            final rev = (entry['credit'] as num?)?.toDouble() ?? (entry['revenue'] as num?)?.toDouble() ?? 0.0;
            final exp = (entry['debit'] as num?)?.toDouble() ?? (entry['expense'] as num?)?.toDouble() ?? 0.0;

            tableData.add([
              '${sn++}',
              dateStr,
              orderId,
              eventName,
              desc,
              rev > 0 ? 'Rs. ${rev.toStringAsFixed(2)}' : '-',
              exp > 0 ? 'Rs. ${exp.toStringAsFixed(2)}' : '-',
            ]);
          }

          return [
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfThemeAndStyles.lightBg,
                border: pw.Border.all(color: PdfThemeAndStyles.borderColor, width: 1),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('TOTAL REVENUE', style: const pw.TextStyle(fontSize: 8, color: PdfThemeAndStyles.labelColor)),
                      pw.SizedBox(height: 2),
                      pw.Text('Rs. ${totalRevenue.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: isA5 ? 11 : 13, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('TOTAL EXPENSES', style: const pw.TextStyle(fontSize: 8, color: PdfThemeAndStyles.labelColor)),
                      pw.SizedBox(height: 2),
                      pw.Text('Rs. ${totalExpenses.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: isA5 ? 11 : 13, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('NET BALANCE', style: const pw.TextStyle(fontSize: 8, color: PdfThemeAndStyles.labelColor)),
                      pw.SizedBox(height: 2),
                      pw.Text('Rs. ${netBalance.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: isA5 ? 11 : 13, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            if (tableData.isNotEmpty)
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: tableData,
                columnWidths: Map.fromIterables(
                  List.generate(headers.length, (i) => i),
                  headerWidths.map((w) => pw.FlexColumnWidth(w)),
                ),
                border: pw.TableBorder.all(color: PdfThemeAndStyles.borderColor, width: 0.5),
                headerStyle: pw.TextStyle(
                  fontSize: isA5 ? 8 : 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfThemeAndStyles.darkColor),
                cellStyle: pw.TextStyle(fontSize: isA5 ? 7 : 8),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerLeft,
                  5: pw.Alignment.centerRight,
                  6: pw.Alignment.centerRight,
                },
              ),
            pw.SizedBox(height: 24),
            PdfThemeAndStyles.buildSignatureSection(),
            pw.SizedBox(height: 10),
          ];
        },
      ),
    );

    return pdf.save();
  }
}
