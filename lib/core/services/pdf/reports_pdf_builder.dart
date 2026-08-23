import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/domain/entities/expense_entity.dart';
import 'package:order_app/domain/entities/purchase_order_entity.dart';
import '../../utils/nepali_date_formatter.dart';
import '../../utils/number_to_words_converter.dart';
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

    final double totalAdvance =
        orders.fold(0.0, (sum, o) => sum + o.advanceReceived);
    final double totalDue = orders.fold(
      0.0,
      (sum, o) =>
          sum + (o.totalAmount - o.advanceReceived).clamp(0.0, double.infinity),
    );

    final logoImage = pw.MemoryImage(logoBytes);

    pdf.addPage(
      pw.MultiPage(
        maxPages: 100,
        pageFormat: pageFormat,
        margin: getAdaptiveMargin(pageFormat),
        header: (context) => PdfThemeAndStyles.buildHeader(logoImage, orders.isEmpty ? null : orders.first, title: 'FINANCIAL SUMMARY'),
        footer: (context) => PdfThemeAndStyles.buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 16),
          PdfTablesBuilder.buildGlobalFinancialSummaryCard(
            totalRevenue,
            totalExpenses,
            netProfit,
            margin,
            totalAdvance: totalAdvance,
            totalDue: totalDue,
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

  static Future<Uint8List> generateInvoicePdf({
    required OrderEntity order,
    required List<OrderItemEntity> items,
    List<ExpenseEntity> additionalRevenue = const [],
    required Uint8List logoBytes,
    required pw.Font font,
    required pw.Font boldFont,
    String invoiceType = 'PROFORMA INVOICE', // Proforma Invoice
    String companyName = 'Event Solution Pvt Ltd',
    String companyAddress = 'Jwagal - 10, Lalitpur',
    String companyPhone = 'Ph: 01-5268535, 01-5268103',
    String companyVatNo = '601234567',
    String? buyerName,
    String? buyerAddress,
    String? buyerVatNo,
    String paymentTerms = 'Cash / Credit / Cheque',
    double discount = 0.0,
    double discountRate = 0.0,
    double managementCharge = 0.0,
    double managementChargeRate = 0.0,
    double? customVatRate,
    double advanceReceived = 0.0,
    String? invoiceNumber,
    DateTime? invoiceDate,
    String? manualAmountInWords,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    void Function(String)? onProgress,
  }) async {
    final isProforma = invoiceType.toUpperCase().contains('PROFORMA');
    final docTitle = isProforma ? 'PROFORMA INVOICE' : 'TAX INVOICE';
    final invPrefix = isProforma ? 'PI' : 'INV';

    onProgress?.call('Generating $docTitle for ${order.eventName}...');

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: boldFont),
    );

    final logoImage = pw.MemoryImage(logoBytes);
    final invNum = invoiceNumber ??
        '$invPrefix-${order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id.toUpperCase()}';
    final invDate = invoiceDate ?? DateTime.now();
    final clientName = (buyerName != null && buyerName.trim().isNotEmpty)
        ? buyerName.trim()
        : (order.client.isNotEmpty ? order.client : 'Valued Client');
    final clientAddr = (buyerAddress != null && buyerAddress.trim().isNotEmpty)
        ? buyerAddress.trim()
        : (order.venue.isNotEmpty ? order.venue : 'Kathmandu, Nepal');
    final clientVat = buyerVatNo?.trim() ?? '';

    final itemSubtotal = items.fold(0.0, (sum, i) => sum + i.amount);
    final extraSubtotal =
        additionalRevenue.fold(0.0, (sum, r) => sum + r.amount);
    final subtotal = itemSubtotal + extraSubtotal;

    final computedDiscount = discount > 0
        ? discount
        : (discountRate > 0 ? (subtotal * discountRate / 100) : 0.0);

    final computedMgtCharge = managementCharge > 0
        ? managementCharge
        : (managementChargeRate > 0
            ? ((subtotal - computedDiscount) * managementChargeRate / 100)
            : 0.0);

    final taxableAmount = subtotal - computedDiscount + computedMgtCharge;
    final effectiveVatRate = (customVatRate != null && customVatRate >= 0)
        ? customVatRate
        : order.vatRate;
    final computedVat =
        effectiveVatRate > 0.0001 ? (taxableAmount * effectiveVatRate) : 0.0;
    final grandTotal = taxableAmount + computedVat;
    final balanceDue =
        (grandTotal - advanceReceived).clamp(0.0, double.infinity);

    final wordsText = (manualAmountInWords != null &&
            manualAmountInWords.trim().isNotEmpty)
        ? manualAmountInWords.trim()
        : NumberToWordsConverter.convertToRupees(grandTotal);

    final isA5 = pageFormat.width < 500;

    final headers = [
      'S.No.',
      'Description',
      'Rate (Rs.)',
      'Qty',
      'Amount (Rs.)',
      'Ps.',
    ];
    final headerWidths = [0.8, 5.0, 1.8, 1.0, 2.0, 0.8];

    final tableData = <List<String>>[];
    int sn = 1;
    for (final item in items) {
      final desc = item.specification.isNotEmpty
          ? '${item.itemName}\n(${item.specification})'
          : item.itemName;
      final amtFloor = item.amount.floor();
      final amtPs = ((item.amount - amtFloor) * 100).round();
      tableData.add([
        '${sn++}',
        desc,
        item.rate.toStringAsFixed(2),
        item.quantity.toString(),
        amtFloor.toString(),
        amtPs == 0 ? '00' : amtPs.toString().padLeft(2, '0'),
      ]);
    }
    for (final rev in additionalRevenue) {
      final desc = rev.description.isNotEmpty
          ? '${rev.category} - ${rev.description}'
          : rev.category;
      final amtFloor = rev.amount.floor();
      final amtPs = ((rev.amount - amtFloor) * 100).round();
      tableData.add([
        '${sn++}',
        desc,
        rev.rate.toStringAsFixed(2),
        rev.quantity.toString(),
        amtFloor.toString(),
        amtPs == 0 ? '00' : amtPs.toString().padLeft(2, '0'),
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        maxPages: 100,
        pageFormat: pageFormat,
        margin: getAdaptiveMargin(pageFormat),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 4, bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom:
                  pw.BorderSide(color: PdfThemeAndStyles.borderColor, width: 1.5),
            ),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 70,
                height: 70,
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      companyName.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfThemeAndStyles.darkColor,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      companyAddress,
                      style: const pw.TextStyle(
                        fontSize: 9.5,
                        color: PdfThemeAndStyles.labelColor,
                      ),
                    ),
                    pw.Text(
                      companyPhone,
                      style: const pw.TextStyle(
                        fontSize: 9.5,
                        color: PdfThemeAndStyles.labelColor,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'VAT / PAN No: $companyVatNo',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfThemeAndStyles.darkColor,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: pw.BoxDecoration(
                      color: isProforma ? PdfThemeAndStyles.lightBg : null,
                      border: pw.Border.all(
                        color: PdfThemeAndStyles.borderColor,
                        width: 1,
                      ),
                    ),
                    child: pw.Text(
                      docTitle,
                      style: pw.TextStyle(
                        fontSize: isProforma ? 12 : 14,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    isProforma ? 'Proforma No: $invNum' : 'Invoice No: $invNum',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Date: ${formatNepaliDate(invDate, 'yyyy-MM-dd')} (${invDate.toIso8601String().split('T').first})',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfThemeAndStyles.labelColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        footer: (context) => PdfThemeAndStyles.buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 12),
          // Buyer & Payment Terms Info Box
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfThemeAndStyles.lightBg,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(
                color: PdfThemeAndStyles.borderColor,
                width: 0.5,
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "BUYER'S DETAILS:",
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfThemeAndStyles.labelColor,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        clientName,
                        style: pw.TextStyle(
                          fontSize: 10.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Address: $clientAddr',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                      if (clientVat.isNotEmpty)
                        pw.Text(
                          "Buyer's PAN/VAT: $clientVat",
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      if (order.contactNumber.isNotEmpty)
                        pw.Text(
                          'Phone: ${order.contactNumber}',
                          style: const pw.TextStyle(fontSize: 8.5),
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PAYMENT & EVENT PARTICULARS:',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfThemeAndStyles.labelColor,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Payment Terms: $paymentTerms',
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Event: ${order.eventName}',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                      pw.Text(
                        'Event Date: ${formatNepaliDate(order.eventDate, 'yyyy-MM-dd')}',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Items Table
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: tableData,
            columnWidths: Map.fromIterables(
              List.generate(headers.length, (i) => i),
              headerWidths.map((w) => pw.FlexColumnWidth(w)),
            ),
            border: pw.TableBorder.all(
              color: PdfThemeAndStyles.borderColor,
              width: 0.5,
            ),
            headerStyle: pw.TextStyle(
              fontSize: isA5 ? 8 : 8.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration:
                const pw.BoxDecoration(color: PdfThemeAndStyles.darkColor),
            cellStyle: pw.TextStyle(fontSize: isA5 ? 7 : 7.5),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.center,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.center,
            },
          ),
          pw.SizedBox(height: 10),

          // Financial Breakdown & Amount in Words
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfThemeAndStyles.lightBg,
                        border: pw.Border.all(
                          color: PdfThemeAndStyles.borderColor,
                          width: 0.5,
                        ),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'AMOUNT IN WORDS:',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfThemeAndStyles.labelColor,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            wordsText,
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              fontStyle: pw.FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfThemeAndStyles.borderColor,
                          width: 0.5,
                        ),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'TERMS & CONDITIONS:',
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '1. Payment is subject to realized funds in bank account.',
                            style: const pw.TextStyle(fontSize: 7),
                          ),
                          pw.Text(
                            '2. Goods/Services received in good order and condition.',
                            style: const pw.TextStyle(fontSize: 7),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 2,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: PdfThemeAndStyles.lightBg,
                    border: pw.Border.all(
                      color: PdfThemeAndStyles.borderColor,
                      width: 0.5,
                    ),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    children: [
                      _buildSplitRow('Taxable Subtotal:', subtotal),
                      if (computedDiscount > 0)
                        _buildSplitRow('Discount:', -computedDiscount),
                      if (computedMgtCharge > 0)
                        _buildSplitRow('Management Charge:', computedMgtCharge),
                      if (computedVat > 0)
                        _buildSplitRow('13% VAT:', computedVat),
                      pw.Divider(height: 5, thickness: 0.5),
                      _buildSplitRow('Grand Total:', grandTotal, isBold: true),
                      if (advanceReceived > 0)
                        _buildSplitRow('Advance Received:', -advanceReceived),
                      pw.Divider(height: 5, thickness: 1),
                      _buildSplitRow(
                        'BALANCE DUE:',
                        balanceDue,
                        isBold: true,
                        fontSize: 9.5,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Two Signature Blocks: Received By & Authorized Signatory
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 140,
                    height: 1,
                    color: PdfThemeAndStyles.borderColor,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Received By (Signature)',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 160,
                    height: 1,
                    color: PdfThemeAndStyles.borderColor,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'For: $companyName',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Authorized Signatory',
                    style: const pw.TextStyle(
                      fontSize: 7.5,
                      color: PdfThemeAndStyles.labelColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSplitRow(
    String label,
    double amount, {
    bool isBold = false,
    double fontSize = 7.5,
  }) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final floorVal = absAmount.floor();
    final psVal = ((absAmount - floorVal) * 100).round();

    final rsText = '${isNegative ? "- " : ""}Rs. $floorVal';
    final psText = psVal == 0 ? '00' : psVal.toString().padLeft(2, '0');

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                rsText,
                style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight:
                      isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
              pw.Text(
                '.$psText',
                style: pw.TextStyle(
                  fontSize: fontSize * 0.85,
                  fontWeight:
                      isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
