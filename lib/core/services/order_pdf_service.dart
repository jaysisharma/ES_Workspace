import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/domain/entities/expense_entity.dart';
import 'package:order_app/domain/entities/purchase_order_entity.dart';
import 'pdf_data_models.dart';
import 'pdf/pdf_theme_and_styles.dart';
import 'pdf/pdf_tables_builder.dart';
import 'pdf/reports_pdf_builder.dart';

class OrderPdfService {
  static Uint8List? _cachedLogoBytes;
  static pw.Font? _cachedRegularFont;
  static pw.Font? _cachedBoldFont;
  static Uint8List? _cachedRegularFontBytes;
  static Uint8List? _cachedBoldFontBytes;

  /// Preloads assets at app startup to avoid latency during first PDF generation.
  static Future<void> preloadAssets() async {
    try {
      if (_cachedLogoBytes == null) {
        final logoData = await rootBundle.load(
          'assets/images/event_solution_logo.jpeg',
        );
        _cachedLogoBytes = logoData.buffer.asUint8List();
      }

      if (_cachedRegularFont == null) {
        final fontData = await rootBundle.load(
          'assets/fonts/Roboto-Regular.ttf',
        );
        _cachedRegularFontBytes = fontData.buffer.asUint8List();
        _cachedRegularFont = pw.Font.ttf(fontData);
      }

      if (_cachedBoldFont == null) {
        final fontData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
        _cachedBoldFontBytes = fontData.buffer.asUint8List();
        _cachedBoldFont = pw.Font.ttf(fontData);
      }

      debugPrint(
        'OrderPdfService: Assets (Roboto fonts & Logo) preloaded successfully',
      );
    } catch (e) {
      debugPrint('OrderPdfService: Error preloading assets: $e');
    }
  }

  static Future<void> _loadAssets() async {
    if (_cachedLogoBytes == null ||
        _cachedRegularFont == null ||
        _cachedBoldFont == null ||
        _cachedRegularFontBytes == null ||
        _cachedBoldFontBytes == null) {
      await preloadAssets();
    }
  }

  static pw.EdgeInsets getAdaptiveMargin(PdfPageFormat format) {
    final isA5 = format.width < 500;
    return isA5
        ? const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 24)
        : const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 60);
  }

  static Future<Uint8List> generateOrderPdf({
    required OrderEntity order,
    required List<OrderItemEntity> items,
    List<ExpenseEntity> additionalRevenue = const [],
    bool showFinancials = false,
    double managementCharge = 0.0,
    double managementChargeRate = 0.0,
    double discount = 0.0,
    double discountRate = 0.0,
    double? vatRate,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Processing ${items.length} items...');
    await _loadAssets();

    final logoBytes = _cachedLogoBytes!;
    final title = showFinancials ? 'REVENUE SUMMARY' : 'ORDER SUMMARY';

    final itemRows = items
        .map(
          (item) => PdfItemData(
            itemName: item.itemName,
            specification: item.specification,
            quantity: item.quantity,
            unit: item.unit,
            billingType: item.billingType,
            days: item.days,
            rate: item.rate,
            amount: item.amount,
            vendor: item.vendor,
            vendorRate: item.vendorRate,
            vendorAmount: item.vendorAmount,
          ),
        )
        .toList();

    final revenueRows = additionalRevenue
        .map(
          (e) => PdfRevenueData(
            category: e.category,
            description: e.description,
            quantity: e.quantity.toDouble(),
            unit: e.unit,
            billingType: e.billingType,
            days: e.days,
            rate: e.rate,
            amount: e.amount,
            vendorName: e.vendorName ?? '',
          ),
        )
        .toList();

    final font = _cachedRegularFont!;
    final boldFont = _cachedBoldFont!;

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: boldFont),
    );

    final logoImage = pw.MemoryImage(logoBytes);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: getAdaptiveMargin(pageFormat),
        header: (context) => PdfThemeAndStyles.buildHeader(logoImage, order, title: title),
        footer: (context) => PdfThemeAndStyles.buildFooter(context),
        build: (context) {
          return [
            pw.SizedBox(height: 16),
            PdfThemeAndStyles.buildOrderInfoCard(order),
            pw.SizedBox(height: 14),
            if (itemRows.isNotEmpty || revenueRows.isNotEmpty) ...[
              ...PdfTablesBuilder.buildItemsTableWidgets(
                order,
                itemRows,
                showFinancials: showFinancials,
                additionalRevenue: revenueRows,
                managementCharge: managementCharge,
                managementChargeRate: managementChargeRate,
                discount: discount,
                discountRate: discountRate,
                customVatRate: vatRate,
              ),
              pw.SizedBox(height: 14),
            ],
            if (order.description.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text(
                'Order Description:',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                order.description,
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 14),
            ],
            pw.SizedBox(height: 30),
            PdfThemeAndStyles.buildSignatureSection(),
            pw.SizedBox(height: 10),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateExpensePdf({
    required OrderEntity order,
    required List<OrderItemEntity> items,
    required List<ExpenseEntity> expenses,
    bool includeItems = true,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Generating expenses summary...');
    await _loadAssets();

    final logoBytes = _cachedLogoBytes!;
    final itemRows = items
        .map(
          (item) => PdfItemData(
            itemName: item.itemName,
            specification: item.specification,
            quantity: item.quantity,
            unit: item.unit,
            billingType: item.billingType,
            days: item.days,
            rate: item.rate,
            amount: item.amount,
            vendor: item.vendor,
            vendorRate: item.vendorRate,
            vendorAmount: item.vendorAmount,
          ),
        )
        .toList();

    final expenseRows = expenses
        .map(
          (e) => PdfExpenseData(
            category: e.category,
            description: e.description,
            specification: e.specification,
            quantity: e.quantity,
            unit: e.unit,
            billingType: e.billingType,
            days: e.days,
            rate: e.rate,
            amount: e.amount,
            vendorName: e.vendorName ?? '',
          ),
        )
        .toList();

    final font = _cachedRegularFont!;
    final boldFont = _cachedBoldFont!;

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: boldFont),
    );

    final logoImage = pw.MemoryImage(logoBytes);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: getAdaptiveMargin(pageFormat),
        header: (context) =>
            PdfThemeAndStyles.buildHeader(logoImage, order, title: 'EXPENSES SUMMARY'),
        footer: (context) => PdfThemeAndStyles.buildFooter(context),
        build: (context) {
          final double itemsTotal = includeItems
              ? itemRows.fold(0.0, (sum, item) => sum + item.vendorAmount)
              : 0.0;
          final double manualTotal = expenseRows.fold(
            0.0,
            (sum, e) => sum + e.amount,
          );
          final double totalExpenses = itemsTotal + manualTotal;

          return [
            pw.SizedBox(height: 16),
            PdfThemeAndStyles.buildOrderInfoCard(order),
            pw.SizedBox(height: 14),
            if ((includeItems && itemRows.isNotEmpty) ||
                expenseRows.isNotEmpty) ...[
              ...PdfTablesBuilder.buildExpenseTableWidgets(
                itemRows: includeItems ? itemRows : [],
                expenseRows: expenseRows,
              ),
              pw.SizedBox(height: 14),
            ],
            PdfTablesBuilder.buildSummaryCard(itemsTotal, manualTotal, totalExpenses),
            pw.SizedBox(height: 14),
            if (order.description.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text(
                'Order Description:',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                order.description,
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 14),
            ],
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
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    void Function(String)? onProgress,
  }) async {
    await _loadAssets();
    return ReportsPdfBuilder.generateGlobalFinancialPdf(
      orders: orders,
      totalRevenue: totalRevenue,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      margin: margin,
      logoBytes: _cachedLogoBytes!,
      font: _cachedRegularFont!,
      boldFont: _cachedBoldFont!,
      pageFormat: pageFormat,
      onProgress: onProgress,
    );
  }

  static Future<Uint8List> generateSingleEventFinancialPdf({
    required OrderEntity order,
    required List<OrderItemEntity> items,
    List<ExpenseEntity> orderExpenses = const [],
    List<ExpenseEntity> additionalRevenue = const [],
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    void Function(String)? onProgress,
  }) async {
    return generateOrderPdf(
      order: order,
      items: items,
      additionalRevenue: additionalRevenue,
      showFinancials: true,
      pageFormat: pageFormat,
      onProgress: onProgress,
    );
  }

  static Future<Uint8List> generatePurchaseOrderPdf({
    required PurchaseOrderEntity po,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    void Function(String)? onProgress,
  }) async {
    await _loadAssets();
    return ReportsPdfBuilder.generatePurchaseOrderPdf(
      po: po,
      logoBytes: _cachedLogoBytes!,
      font: _cachedRegularFont!,
      boldFont: _cachedBoldFont!,
      pageFormat: pageFormat,
      onProgress: onProgress,
    );
  }

  static Future<Uint8List> generateVendorPurchaseOrderPdf({
    required PurchaseOrderEntity po,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    void Function(String)? onProgress,
  }) async {
    return generatePurchaseOrderPdf(po: po, pageFormat: pageFormat, onProgress: onProgress);
  }

  static Future<Uint8List> generateFinancialLedgerPdf({
    required List<Map<String, dynamic>> ledgerEntries,
    required double totalRevenue,
    required double totalExpenses,
    required double netBalance,
    String entityName = '',
    String periodText = '',
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    void Function(String)? onProgress,
  }) async {
    await _loadAssets();
    return ReportsPdfBuilder.generateFinancialLedgerPdf(
      ledgerEntries: ledgerEntries,
      totalRevenue: totalRevenue,
      totalExpenses: totalExpenses,
      netBalance: netBalance,
      entityName: entityName,
      periodText: periodText,
      logoBytes: _cachedLogoBytes!,
      font: _cachedRegularFont!,
      boldFont: _cachedBoldFont!,
      pageFormat: pageFormat,
      onProgress: onProgress,
    );
  }
}
