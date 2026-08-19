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
    double advanceReceived = 0.0,
    String advanceReferenceNo = '',
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
        maxPages: 100,
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
                advanceReceived: advanceReceived,
                advanceReferenceNo: advanceReferenceNo,
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
        maxPages: 100,
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
    onProgress?.call('Generating Event Financial Statement...');
    await _loadAssets();

    final logoImage = pw.MemoryImage(_cachedLogoBytes!);
    final font = _cachedRegularFont!;
    final boldFont = _cachedBoldFont!;

    final itemDatas = items
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

    final revenueDatas = additionalRevenue
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

    final expenseDatas = orderExpenses
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

    final double revenueSubtotal = items.fold(0.0, (sum, i) => sum + i.amount) +
        additionalRevenue.fold(0.0, (sum, e) => sum + e.amount);

    final double computedMgtCharge = order.managementCharge > 0
        ? (order.isMgtChargePercent ? (revenueSubtotal * order.managementCharge / 100) : order.managementCharge)
        : 0.0;

    final double computedDiscount = order.discount > 0
        ? (order.isDiscountPercent ? (revenueSubtotal * order.discount / 100) : order.discount)
        : 0.0;

    final double netRevenue = revenueSubtotal + computedMgtCharge - computedDiscount;
    final double computedVat = order.vatRate > 0.0001 ? (netRevenue * order.vatRate) : 0.0;
    final double totalRevenue = netRevenue + computedVat;

    final double vendorTotal = items.fold(0.0, (sum, item) {
      final amt = item.vendorAmount > 0
          ? item.vendorAmount
          : (item.vendorRate *
                item.quantity *
                (item.billingType == 'daily' ? item.days : 1));
      return sum + amt;
    });

    final double operationalTotal = orderExpenses.fold(0.0, (sum, exp) => sum + exp.amount);
    final double totalExpenses = vendorTotal + operationalTotal;
    final double netProfit = totalRevenue - totalExpenses;
    final double profitMargin = totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0.0;

    debugPrint('=== [SINGLE EVENT FINANCIAL PDF DEBUG] ===');
    debugPrint('Order ID: ${order.id}, Event: ${order.eventName}');
    debugPrint('Item rows: ${itemDatas.length}, Revenue rows: ${revenueDatas.length}, Expense rows: ${expenseDatas.length}');
    debugPrint('Revenue Subtotal: $revenueSubtotal, Net Rev: $netRevenue, Total Rev: $totalRevenue');
    debugPrint('Vendor Expenses: $vendorTotal, Operational Expenses: $operationalTotal, Total Expenses: $totalExpenses');
    debugPrint('Net Profit: $netProfit, Margin: ${profitMargin.toStringAsFixed(2)}%');
    debugPrint('=========================================');

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: boldFont),
    );

    pdf.addPage(
      pw.MultiPage(
        maxPages: 100,
        pageFormat: pageFormat,
        margin: ReportsPdfBuilder.getAdaptiveMargin(pageFormat),
        header: (context) => PdfThemeAndStyles.buildHeader(
          logoImage,
          order,
          title: 'EVENT FINANCIAL STATEMENT',
        ),
        footer: (context) => PdfThemeAndStyles.buildFooter(context),
        build: (context) {
          return [
            pw.SizedBox(height: 12),
            PdfThemeAndStyles.buildOrderInfoCard(order),
            pw.SizedBox(height: 12),
            PdfTablesBuilder.buildGlobalFinancialSummaryCard(
              totalRevenue,
              totalExpenses,
              netProfit,
              profitMargin,
            ),
            pw.SizedBox(height: 14),
            ...PdfTablesBuilder.buildItemsTableWidgets(
              order,
              itemDatas,
              showFinancials: true,
              additionalRevenue: revenueDatas,
              managementCharge: order.managementCharge,
              managementChargeRate: order.isMgtChargePercent ? order.managementCharge : 0.0,
              discount: order.discount,
              discountRate: order.isDiscountPercent ? order.discount : 0.0,
              customVatRate: order.vatRate,
              advanceReceived: order.advanceReceived,
              advanceReferenceNo: order.advanceReferenceNo,
            ),
            pw.SizedBox(height: 16),
            ...PdfTablesBuilder.buildExpenseTableWidgets(
              itemRows: itemDatas,
              expenseRows: expenseDatas,
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

  static Future<Uint8List> generateInvoicePdf({
    required OrderEntity order,
    required List<OrderItemEntity> items,
    List<ExpenseEntity> additionalRevenue = const [],
    String invoiceType = 'TAX INVOICE', // 'TAX INVOICE' or 'PROFORMA INVOICE'
    String companyName = 'Event Solution Pvt Ltd',
    String companyAddress = 'Jwagal - 10, Lalitpur',
    String companyPhone = 'Ph: 01-5268535, 01-5268103',
    String companyVatNo = '601234567',
    String? buyerName,
    String? buyerAddress,
    String? buyerVatNo,
    String paymentTerms = 'Cash / Credit / Cheque',
    String defaultHsCode = '998399',
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
    await _loadAssets();
    return ReportsPdfBuilder.generateInvoicePdf(
      order: order,
      items: items,
      additionalRevenue: additionalRevenue,
      logoBytes: _cachedLogoBytes!,
      font: _cachedRegularFont!,
      boldFont: _cachedBoldFont!,
      invoiceType: invoiceType,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
      companyVatNo: companyVatNo,
      buyerName: buyerName,
      buyerAddress: buyerAddress,
      buyerVatNo: buyerVatNo,
      paymentTerms: paymentTerms,
      defaultHsCode: defaultHsCode,
      discount: discount,
      discountRate: discountRate,
      managementCharge: managementCharge,
      managementChargeRate: managementChargeRate,
      customVatRate: customVatRate,
      advanceReceived: advanceReceived,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      manualAmountInWords: manualAmountInWords,
      pageFormat: pageFormat,
      onProgress: onProgress,
    );
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
