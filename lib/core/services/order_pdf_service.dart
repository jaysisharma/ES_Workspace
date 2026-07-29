import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/nepali_date_formatter.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/entities/order_item_entity.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/entities/purchase_order_entity.dart';

class OrderPdfService {
  static const _darkColor = PdfColor.fromInt(0xFF000000); // Pure Black
  static const _labelColor = PdfColor.fromInt(0xFF4b5563);
  static const _borderColor = PdfColor.fromInt(0xFF000000); // Black Borders
  static const _lightBg = PdfColor.fromInt(0xFFf3f4f6);

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
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Processing ${items.length} items...');
    await _loadAssets();

    final logoBytes = _cachedLogoBytes!;
    final title = showFinancials ? 'REVENUE SUMMARY' : 'ORDER SUMMARY';

    // Extract only display-required fields before spawning isolate
    final itemRows = items.map((item) => _PdfItemData(
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
    )).toList();

    final revenueRows = additionalRevenue.map((e) => _PdfRevenueData(
      category: e.category,
      description: e.description,
      quantity: e.quantity.toDouble(),
      unit: e.unit,
      billingType: e.billingType,
      days: e.days,
      rate: e.rate,
      amount: e.amount,
      vendorName: e.vendorName ?? '',
    )).toList();

    final font = _cachedRegularFont!;
    final boldFont = _cachedBoldFont!;

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: boldFont),
    );

    final logoImage = pw.MemoryImage(logoBytes);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 60),
        header: (context) => _buildHeader(logoImage, order, title: title),
        footer: (context) => _buildFooter(context),
        build: (context) {
          return [
            pw.SizedBox(height: 20),
            _buildOrderInfoCard(order),
            pw.SizedBox(height: 16),
            if (itemRows.isNotEmpty || revenueRows.isNotEmpty) ...[
              ..._buildItemsTableWidgets(
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
              pw.SizedBox(height: 16),
            ],
            if (order.description.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Text(
                'Order Description:',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(order.description, style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 16),
            ],
            pw.SizedBox(height: 40),
            _buildSignatureSection(),
            pw.SizedBox(height: 10),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateExpensePdf({
    required OrderEntity order,
    required List<ExpenseEntity> expenses,
    required List<OrderItemEntity> items,
    bool includeItems = true,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Processing ${items.length} items...');
    await _loadAssets();

    final logoBytes = _cachedLogoBytes!;

    // Extract only display-required fields before spawning isolate
    final itemRows = items.map((item) => _PdfItemData(
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
    )).toList();

    final expenseRows = expenses.map((e) => _PdfExpenseData(
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
    )).toList();

    final font = _cachedRegularFont!;
    final boldFont = _cachedBoldFont!;

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: boldFont),
    );

    final logoImage = pw.MemoryImage(logoBytes);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 60),
        header: (context) => _buildHeader(logoImage, order, title: 'EXPENSES SUMMARY'),
        footer: (context) => _buildFooter(context),
        build: (context) {
          final double itemsTotal = includeItems
              ? itemRows.fold(0.0, (sum, item) => sum + item.vendorAmount)
              : 0.0;
          final double manualTotal = expenseRows.fold(0.0, (sum, e) => sum + e.amount);
          final double totalExpenses = itemsTotal + manualTotal;

          return [
            pw.SizedBox(height: 20),
            _buildOrderInfoCard(order),
            pw.SizedBox(height: 16),
            if ((includeItems && itemRows.isNotEmpty) || expenseRows.isNotEmpty) ...[
              ..._buildExpenseTableWidgets(
                itemRows: includeItems ? itemRows : [],
                expenseRows: expenseRows,
              ),
              pw.SizedBox(height: 16),
            ],
            _buildSummaryCard(itemsTotal, manualTotal, totalExpenses),
            pw.SizedBox(height: 16),
            if (order.description.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Text(
                'Order Description:',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(order.description, style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 16),
            ],
            pw.SizedBox(height: 40),
            _buildSignatureSection(),
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
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Generating financial report...');
    await _loadAssets();

    final logoBytes = _cachedLogoBytes!;
    final font = _cachedRegularFont!;
    final boldFont = _cachedBoldFont!;

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: boldFont),
    );

    final logoImage = pw.MemoryImage(logoBytes);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 60),
        header: (context) => _buildHeader(logoImage, orders.first, title: 'FINANCIAL SUMMARY'),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 20),
          _buildGlobalFinancialSummaryCard(
            totalRevenue,
            totalExpenses,
            netProfit,
            margin,
          ),
          pw.SizedBox(height: 16),
          _buildOrdersFinancialTable(orders),
          pw.Spacer(),
          _buildSignatureSection(),
          pw.SizedBox(height: 10),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateVendorPurchaseOrderPdf({
    required PurchaseOrderEntity po,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Generating Purchase Order...');
    await _loadAssets();

    final logoBytes = _cachedLogoBytes!;
    final font = _cachedRegularFont!;
    final boldFont = _cachedBoldFont!;

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: boldFont),
    );

    final logoImage = pw.MemoryImage(logoBytes);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 60),
        header: (context) => _buildPOHeader(logoImage, po),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 20),
          _buildPOOrderInfoCard(po),
          pw.SizedBox(height: 16),
          _buildPOTable(po),
          pw.Spacer(),
          _buildSignatureSection(),
          pw.SizedBox(height: 10),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateFinancialLedgerPdf({
    required String entityName,
    required String periodText,
    required double totalRevenue,
    required double totalExpenses,
    required double netBalance,
    required List<Map<String, dynamic>> ledgerEntries,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Generating Ledger PDF...');
    await _loadAssets();

    final logoBytes = _cachedLogoBytes!;
    final font = _cachedRegularFont!;
    final boldFont = _cachedBoldFont!;

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: boldFont),
    );

    final logoImage = pw.MemoryImage(logoBytes);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 50),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _borderColor, width: 1.5)),
          ),
          child: pw.Row(
            children: [
              pw.Container(width: 60, height: 60, child: pw.Image(logoImage)),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('FINANCIAL LEDGER STATEMENT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text('ENTITY: ${entityName.toUpperCase()}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _labelColor)),
                    pw.Text('PERIOD: $periodText', style: const pw.TextStyle(fontSize: 9, color: _labelColor)),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Date: ${formatNepaliDate(DateTime.now(), "yyyy-MM-dd")}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
        ),
        footer: (context) => _buildFooter(context),
        build: (context) {
          int sn = 1;
          final headers = ['SN', 'Date', 'Order ID', 'Category / Item', 'Credit (NPR)', 'Debit (NPR)'];
          final headerWidths = [0.6, 1.2, 1.2, 3.5, 1.6, 1.6];

          final tableRows = <pw.TableRow>[
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _lightBg),
              children: headers.map((h) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: pw.Text(h.toUpperCase(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              )).toList(),
            ),
            ...ledgerEntries.map((e) {
              final dateStr = e['date'] != null ? formatNepaliDate(e['date'] as DateTime, 'dd MMM yyyy') : '-';
              final orderId = (e['orderId'] as String?) ?? '-';
              final desc = (e['description'] as String?) ?? '';
              final credit = (e['credit'] as num?)?.toDouble() ?? 0.0;
              final debit = (e['debit'] as num?)?.toDouble() ?? 0.0;

              return pw.TableRow(
                children: [
                  _tableCell((sn++).toString(), align: pw.TextAlign.center),
                  _tableCell(dateStr),
                  _tableCell(orderId),
                  _tableCell(desc, bold: true),
                  _tableCell(credit > 0 ? credit.toStringAsFixed(0) : '-', align: pw.TextAlign.right),
                  _tableCell(debit > 0 ? debit.toStringAsFixed(0) : '-', align: pw.TextAlign.right),
                ],
              );
            }),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _lightBg),
              children: [
                _tableCell(''),
                _tableCell(''),
                _tableCell(''),
                _tableCell('TOTAL STATEMENT SUMMARY', bold: true),
                _tableCell(totalRevenue.toStringAsFixed(0), bold: true, align: pw.TextAlign.right),
                _tableCell(totalExpenses.toStringAsFixed(0), bold: true, align: pw.TextAlign.right),
              ],
            ),
          ];

          return [
            pw.SizedBox(height: 16),
            // Financial Ledger Overview Card
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _borderColor, width: 1),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('TOTAL CREDIT (REVENUE)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _labelColor)),
                      pw.SizedBox(height: 2),
                      pw.Text('NPR ${totalRevenue.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Container(width: 1, height: 25, color: _borderColor),
                  pw.Column(
                    children: [
                      pw.Text('TOTAL DEBIT (EXPENSES)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _labelColor)),
                      pw.SizedBox(height: 2),
                      pw.Text('NPR ${totalExpenses.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Container(width: 1, height: 25, color: _borderColor),
                  pw.Column(
                    children: [
                      pw.Text('NET STATEMENT BALANCE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _labelColor)),
                      pw.SizedBox(height: 2),
                      pw.Text('NPR ${netBalance.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: _borderColor, width: 0.5),
              columnWidths: Map.fromIterables(
                Iterable.generate(headerWidths.length, (i) => i),
                headerWidths.map((w) => pw.FlexColumnWidth(w)),
              ),
              children: tableRows,
            ),
            pw.SizedBox(height: 24),
            _buildSignatureSection(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  static pw.Widget _buildHeader(
    pw.MemoryImage logo,
    OrderEntity order, {
    String title = 'ORDER SUMMARY',
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8, bottom: 16),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _borderColor, width: 1.5),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Logo
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
                    color: _darkColor,
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
                'ORDER ID: ${order.id}',
                style: pw.TextStyle(
                  fontSize: 15,
                  color: _darkColor,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Date: ${formatNepaliDate(order.createdAt, 'MMMM dd, yyyy')}',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: _darkColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPOHeader(pw.MemoryImage logo, PurchaseOrderEntity po) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8, bottom: 16),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _borderColor, width: 1.5),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Logo
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
                    color: _darkColor,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  po.vendorName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkColor,
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
                  color: _darkColor,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Date: ${formatNepaliDate(po.createdAt, 'MMMM dd, yyyy')}',
                style: pw.TextStyle(fontSize: 9, color: _darkColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _borderColor, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: _labelColor),
          ),
        ],
      ),
    );
  }

  // ── Order Info Card ─────────────────────────────────────────────────────────

  static pw.Widget _buildOrderInfoCard(OrderEntity order) {
    return _card(
      title: 'ORDER INFORMATION',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            order.eventName,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _darkColor,
            ),
          ),
          pw.SizedBox(height: 8),
          _infoRow('Order ID', order.id),
          pw.SizedBox(height: 4),
          _infoRow('Venue', order.venue),
          pw.SizedBox(height: 4),
          _infoRow(
            'Event Dates',
            _formatDateRange(order.eventDate, order.eventEndDate),
          ),
          pw.SizedBox(height: 4),
          _infoRow(
            'Setup Dates',
            _formatDateRange(order.setupDate, order.setupEndDate),
          ),
          pw.SizedBox(height: 4),
          _infoRow('Contact', order.contactPerson),
          pw.SizedBox(height: 4),
          _infoRow('Phone', order.contactNumber),
        ],
      ),
    );
  }

  static pw.Widget _buildPOOrderInfoCard(PurchaseOrderEntity po) {
    return _card(
      title: 'PURCHASE ORDER DETAILS',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _infoRow('VENDOR NAME', po.vendorName),
          pw.SizedBox(height: 6),
          _infoRow('RELATED ORDER', po.orderId.isEmpty ? 'N/A' : po.orderId),
          pw.SizedBox(height: 6),
          _infoRow('EVENT NAME', po.eventName),
          pw.SizedBox(height: 6),
          _infoRow('VENUE', po.venue),
          pw.SizedBox(height: 6),
          _infoRow(
            'EVENT DATE',
            _formatDateRange(po.eventDate, po.eventEndDate),
          ),
          pw.SizedBox(height: 6),
          _infoRow(
            'SETUP DATE',
            _formatDateRange(po.setupDate, po.setupEndDate),
          ),
        ],
      ),
    );
  }

  static String _formatDateRange(DateTime start, DateTime? end) {
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

  // ── Items Table ─────────────────────────────────────────────────────────────

  // pw.Table placed directly in MultiPage.build (not inside pw.Container) so
  // it can implement SpanningWidget and split across pages automatically.
  // Wrapping in pw.Container/pw.Column breaks spanning → TooManyPagesException.
  static List<pw.Widget> _buildItemsTableWidgets(
    OrderEntity order,
    List<_PdfItemData> items, {
    bool showFinancials = false,
    List<_PdfRevenueData> additionalRevenue = const [],
    double managementCharge = 0.0,
    double managementChargeRate = 0.0,
    double discount = 0.0,
    double discountRate = 0.0,
    double? customVatRate,
  }) {
    final headers = showFinancials
        ? ['SN', 'Vendor', 'Item', 'Qty', 'Unit', 'Type', 'Days', 'Rate', 'Amount']
        : ['SN', 'Vendor', 'Item', 'Specification', 'Qty', 'Unit', 'Days'];
    final headerWidths = showFinancials
        ? [0.7, 1.8, 2.5, 0.8, 0.9, 1.0, 0.8, 1.4, 1.6]
        : [0.8, 2.2, 3.2, 2.2, 1.0, 1.0, 1.0];

    final double subtotal = showFinancials
        ? items.fold(0.0, (sum, item) => sum + item.amount) +
          additionalRevenue.fold(0.0, (sum, e) => sum + e.amount)
        : 0.0;

    final double computedMgtCharge = managementCharge > 0
        ? managementCharge
        : (managementChargeRate > 0 ? (subtotal * managementChargeRate / 100) : 0.0);

    final double computedDiscount = discount > 0
        ? discount
        : (discountRate > 0 ? (subtotal * discountRate / 100) : 0.0);

    final double netTotal = subtotal + computedMgtCharge - computedDiscount;

    final double effectiveVatRate = (customVatRate != null && customVatRate >= 0)
        ? customVatRate
        : order.vatRate;

    final double computedVat = effectiveVatRate > 0.0001
        ? (netTotal * effectiveVatRate)
        : 0.0;

    final double grandTotal = netTotal + computedVat;

    int sn = 1;
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _lightBg),
        children: headers.map((h) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(h.toUpperCase(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _darkColor)),
        )).toList(),
      ),
      ...items.map((item) => pw.TableRow(
        children: showFinancials ? [
          _tableCell((sn++).toString(), align: pw.TextAlign.center),
          _tableCell(item.vendor.isEmpty ? '-' : item.vendor),
          _tableCell(item.itemName, bold: true),
          _tableCell(item.quantity.toString(), align: pw.TextAlign.center),
          _tableCell(item.unit, align: pw.TextAlign.center),
          _tableCell(item.billingType == 'daily' ? 'Daily' : 'Event', align: pw.TextAlign.center),
          _tableCell(item.days.toString(), align: pw.TextAlign.center),
          _tableCell(item.rate.toStringAsFixed(0), align: pw.TextAlign.right),
          _tableCell(item.amount.toStringAsFixed(0), align: pw.TextAlign.right),
        ] : [
          _tableCell((sn++).toString(), align: pw.TextAlign.center),
          _tableCell(item.vendor.isEmpty ? '-' : item.vendor),
          _tableCell(item.itemName, bold: true),
          _tableCell(item.specification),
          _tableCell(item.quantity.toString(), align: pw.TextAlign.center),
          _tableCell(item.unit),
          _tableCell(item.days.toString(), align: pw.TextAlign.center),
        ],
      )),
      if (showFinancials && additionalRevenue.isNotEmpty)
        ...additionalRevenue.map((rev) => pw.TableRow(
          children: [
            _tableCell((sn++).toString(), align: pw.TextAlign.center),
            _tableCell(rev.vendorName.isEmpty ? '-' : rev.vendorName),
            _tableCell(
              rev.category == 'Other' && rev.description.isNotEmpty ? rev.description : rev.category,
              bold: true,
            ),
            _tableCell(rev.quantity.toStringAsFixed(0), align: pw.TextAlign.center),
            _tableCell(rev.unit, align: pw.TextAlign.center),
            _tableCell(rev.billingType == 'daily' ? 'Daily' : 'Event', align: pw.TextAlign.center),
            _tableCell(rev.days.toString(), align: pw.TextAlign.center),
            _tableCell(rev.rate.toStringAsFixed(0), align: pw.TextAlign.right),
            _tableCell(rev.amount.toStringAsFixed(0), align: pw.TextAlign.right),
          ],
        )),
    ];

    return [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _borderColor, width: 0.5),
          borderRadius: pw.BorderRadius.circular(2),
        ),
        child: pw.Text(
          showFinancials ? 'REVENUE DETAILS' : 'ITEMS LIST',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _darkColor, letterSpacing: 1.0),
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Table(
        columnWidths: {for (int i = 0; i < headerWidths.length; i++) i: pw.FlexColumnWidth(headerWidths[i])},
        border: pw.TableBorder.all(color: _borderColor, width: 0.5),
        children: rows,
      ),
      if (showFinancials) ...[
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              width: 240,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _borderColor, width: 0.5),
                borderRadius: pw.BorderRadius.circular(2),
              ),
              child: pw.Column(children: [
                _summaryRow('SUBTOTAL', 'Rs. ${subtotal.toStringAsFixed(0)}'),
                if (computedMgtCharge > 0)
                  _summaryRow(
                    managementChargeRate > 0
                        ? 'MANAGEMENT CHARGE (${managementChargeRate.toStringAsFixed(0)}%)'
                        : 'MANAGEMENT CHARGE',
                    'Rs. ${computedMgtCharge.toStringAsFixed(0)}',
                  ),
                if (computedDiscount > 0)
                  _summaryRow(
                    discountRate > 0
                        ? 'DISCOUNT (${discountRate.toStringAsFixed(0)}%)'
                        : 'DISCOUNT',
                    '- Rs. ${computedDiscount.toStringAsFixed(0)}',
                  ),
                _summaryRow('TOTAL', 'Rs. ${netTotal.toStringAsFixed(0)}', isBold: true),
                if (computedVat > 0)
                  _summaryRow(
                    'VAT (${(effectiveVatRate * 100).toStringAsFixed(0)}%)',
                    'Rs. ${computedVat.toStringAsFixed(0)}',
                  ),
                pw.Divider(color: _borderColor, thickness: 1),
                _summaryRow('GRAND TOTAL', 'Rs. ${grandTotal.toStringAsFixed(0)}', isBold: true, fontSize: 10),
              ]),
            ),
          ],
        ),
      ],
    ];
  }

  static List<pw.Widget> _buildExpenseTableWidgets({
    required List<_PdfItemData> itemRows,
    required List<_PdfExpenseData> expenseRows,
  }) {
    final headers = ['SN', 'Vendor', 'Item', 'Qty', 'Unit', 'Type', 'Days', 'Rate', 'Amount'];
    final headerWidths = [0.7, 1.8, 2.5, 0.8, 0.9, 1.0, 0.8, 1.4, 1.6];

    int sn = 1;
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _lightBg),
        children: headers
            .map(
              (h) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Text(
                  h.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkColor,
                  ),
                ),
              ),
            )
            .toList(),
      ),
      ...itemRows.map(
        (item) => pw.TableRow(
          children: [
            _tableCell((sn++).toString(), align: pw.TextAlign.center),
            _tableCell(item.vendor.isEmpty ? '-' : item.vendor),
            _tableCell(item.itemName, bold: true),
            _tableCell(item.quantity.toString(), align: pw.TextAlign.center),
            _tableCell(item.unit, align: pw.TextAlign.center),
            _tableCell(item.billingType == 'daily' ? 'Daily' : 'Event', align: pw.TextAlign.center),
            _tableCell(item.days.toString(), align: pw.TextAlign.center),
            _tableCell(item.vendorRate.toStringAsFixed(0), align: pw.TextAlign.right),
            _tableCell(item.vendorAmount.toStringAsFixed(0), align: pw.TextAlign.right),
          ],
        ),
      ),
      ...expenseRows.map(
        (expense) => pw.TableRow(
          children: [
            _tableCell((sn++).toString(), align: pw.TextAlign.center),
            _tableCell(expense.vendorName.isEmpty ? '-' : expense.vendorName),
            _tableCell(
              expense.category == 'Other' && expense.description.isNotEmpty
                  ? expense.description
                  : (expense.specification.isNotEmpty
                      ? '${expense.category} (${expense.specification})'
                      : expense.category),
              bold: true,
            ),
            _tableCell(expense.quantity.toString(), align: pw.TextAlign.center),
            _tableCell(expense.unit, align: pw.TextAlign.center),
            _tableCell(expense.billingType == 'daily' ? 'Daily' : 'Event', align: pw.TextAlign.center),
            _tableCell(expense.days.toString(), align: pw.TextAlign.center),
            _tableCell(expense.rate.toStringAsFixed(0), align: pw.TextAlign.right),
            _tableCell(expense.amount.toStringAsFixed(0), align: pw.TextAlign.right),
          ],
        ),
      ),
    ];

    return [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _borderColor, width: 0.5),
          borderRadius: pw.BorderRadius.circular(2),
        ),
        child: pw.Text(
          'EXPENSES LIST',
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: _darkColor,
            letterSpacing: 1.0,
          ),
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Table(
        columnWidths: {
          for (int i = 0; i < headerWidths.length; i++)
            i: pw.FlexColumnWidth(headerWidths[i]),
        },
        border: pw.TableBorder.all(color: _borderColor, width: 0.5),
        children: rows,
      ),
    ];
  }

  static pw.Widget _tableCell(
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
          color: _darkColor,
        ),
        textAlign: align,
      ),
    );
  }

  // ── Signature Section ───────────────────────────────────────────────────────

  static pw.Widget _buildSignatureSection() {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 40),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _sigBlock('Prepared by'),
          _sigBlock('Checked by'),
          _sigBlock('Approved by'),
        ],
      ),
    );
  }

  static pw.Widget _sigBlock(String label) {
    return pw.Column(
      children: [
        pw.Container(
          width: 120,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: _borderColor, width: 0.5),
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: _darkColor,
          ),
        ),
      ],
    );
  }

  // ── Shared Helpers ──────────────────────────────────────────────────────────

  static pw.Widget _card({required String title, required pw.Widget child}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor, width: 0.5),
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
              color: _darkColor,
              letterSpacing: 1.0,
            ),
          ),
          pw.SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 70,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              color: _labelColor,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Text(': ', style: pw.TextStyle(fontSize: 8, color: _labelColor)),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _darkColor,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildGlobalFinancialSummaryCard(
    double totalRevenue,
    double totalExpenses,
    double netProfit,
    double margin,
  ) {
    return _card(
      title: 'GLOBAL FINANCIAL SUMMARY',
      child: pw.Column(
        children: [
          _summarySummaryRow(
            'Total Revenue',
            'Rs. ${totalRevenue.toStringAsFixed(0)}',
          ),
          pw.SizedBox(height: 4),
          _summarySummaryRow(
            'Total Expenses',
            'Rs. ${totalExpenses.toStringAsFixed(0)}',
          ),
          pw.SizedBox(height: 4),
          _summarySummaryRow(
            'Net Profit',
            'Rs. ${netProfit.toStringAsFixed(0)}',
            isBold: true,
          ),
          pw.SizedBox(height: 4),
          _summarySummaryRow('Profit Margin', '${margin.toStringAsFixed(2)}%'),
        ],
      ),
    );
  }

  static pw.Widget _summarySummaryRow(
    String label,
    String value, {
    bool isBold = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10, color: _labelColor)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: _darkColor,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildOrdersFinancialTable(List<OrderEntity> orders) {
    final headers = ['Order ID', 'Event Name', 'Revenue', 'Expenses', 'Profit'];
    final headerWidths = [2.0, 5.0, 2.0, 2.0, 2.0];

    return _card(
      title: 'ORDER-WISE BREAKDOWN',
      child: pw.Table(
        columnWidths: {
          for (int i = 0; i < headerWidths.length; i++)
            i: pw.FlexColumnWidth(headerWidths[i]),
        },
        border: pw.TableBorder.all(color: _borderColor, width: 0.5),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _lightBg),
            children: headers
                .map(
                  (h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: pw.Text(
                      h.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: _darkColor,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          ...orders.map((order) {
            final profit = order.totalAmount - order.totalExpenses;
            return pw.TableRow(
              children: [
                _tableCell(order.id, bold: true),
                _tableCell(order.eventName),
                _tableCell(order.totalAmount.toStringAsFixed(0)),
                _tableCell(order.totalExpenses.toStringAsFixed(0)),
                _tableCell(profit.toStringAsFixed(0)),
              ],
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _buildPOTable(PurchaseOrderEntity po) {
    final headers = [
      'SN',
      'ITEM NAME',
      'SPECIFICATION',
      'QTY',
      'UNIT',
      'TYPE',
      'DAYS',
      'RATE',
      'TOTAL',
    ];
    final headerWidths = [0.8, 2.5, 2.5, 1.0, 1.0, 1.0, 1.0, 1.5, 2.0];

    int sn = 1;
    final List<pw.TableRow> rows = [];

    // Header row
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _lightBg),
        children: headers
            .map(
              (h) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 6,
                ),
                child: pw.Text(
                  h,
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkColor,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            )
            .toList(),
      ),
    );

    // Items
    for (final item in po.items) {
      rows.add(
        pw.TableRow(
          children: [
            _tableCell((sn++).toString()),
            _tableCell(item.itemName, bold: true),
            _tableCell(item.specification),
            _tableCell(item.quantity.toString()),
            _tableCell(item.unit),
            _tableCell(item.billingType == 'daily' ? 'Daily' : 'Event'),
            _tableCell(item.days.toString()),
            _tableCell(item.rate.toStringAsFixed(0)),
            _tableCell(item.amount.toStringAsFixed(0)),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Table(
          columnWidths: {
            for (int i = 0; i < headerWidths.length; i++)
              i: pw.FlexColumnWidth(headerWidths[i]),
          },
          border: pw.TableBorder.all(color: _borderColor, width: 0.5),
          children: rows,
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          width: 200,
          child: pw.Column(
            children: [
              _summaryRow(
                'SUBTOTAL',
                'Rs. ${po.totalAmount.toStringAsFixed(0)}',
              ),
              if (po.vatRate > 0.0001)
                _summaryRow(
                  'VAT (${(po.vatRate * 100).toStringAsFixed(0)}%)',
                  'Rs. ${(po.totalAmount * po.vatRate).toStringAsFixed(0)}',
                ),
              pw.Divider(color: _borderColor, thickness: 1),
              _summaryRow(
                'GRAND TOTAL',
                'Rs. ${po.totalWithVat.toStringAsFixed(0)}',
                isBold: true,
                fontSize: 10,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSummaryCard(
    double itemsTotal,
    double manualTotal,
    double total,
  ) {
    return _card(
      title: 'FINANCIAL SUMMARY',
      child: pw.Column(
        children: [
          _summaryRow('Item Costs', 'Rs. ${itemsTotal.toStringAsFixed(0)}'),
          _summaryRow('Additional Expenses', 'Rs. ${manualTotal.toStringAsFixed(0)}'),
          pw.Divider(color: _borderColor, thickness: 0.5),
          _summaryRow('GRAND TOTAL', 'Rs. ${total.toStringAsFixed(0)}', isBold: true, fontSize: 10),
        ],
      ),
    );
  }

  static pw.Widget _summaryRow(
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
              color: _darkColor,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: _darkColor,
            ),
          ),
        ],
      ),
    );
  }
}

// Lightweight data classes — only the fields needed for PDF rendering.
// These are extracted from full entities before spawning the isolate so that
// complex entity objects (with unneeded fields) are never serialised/copied.

class _PdfItemData {
  final String itemName;
  final String specification;
  final int quantity;
  final String unit;
  final String billingType;
  final int days;
  final double rate;
  final double amount;
  final String vendor;
  final double vendorRate;
  final double vendorAmount;

  const _PdfItemData({
    required this.itemName,
    required this.specification,
    required this.quantity,
    required this.unit,
    required this.billingType,
    required this.days,
    required this.rate,
    required this.amount,
    required this.vendor,
    required this.vendorRate,
    required this.vendorAmount,
  });
}

class _PdfRevenueData {
  final String category;
  final String description;
  final double quantity;
  final String unit;
  final String billingType;
  final int days;
  final double rate;
  final double amount;
  final String vendorName;

  const _PdfRevenueData({
    required this.category,
    required this.description,
    required this.quantity,
    this.unit = 'Pcs',
    required this.billingType,
    required this.days,
    required this.rate,
    required this.amount,
    required this.vendorName,
  });
}

class _PdfExpenseData {
  final String category;
  final String description;
  final String specification;
  final int quantity;
  final String unit;
  final String billingType;
  final int days;
  final double rate;
  final double amount;
  final String vendorName;

  const _PdfExpenseData({
    required this.category,
    required this.description,
    required this.specification,
    required this.quantity,
    required this.unit,
    required this.billingType,
    required this.days,
    required this.rate,
    required this.amount,
    required this.vendorName,
  });
}
