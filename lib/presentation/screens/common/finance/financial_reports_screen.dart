import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:order_app/core/utils/share_helper.dart';
import 'package:order_app/core/utils/excel_export_helper.dart';
import 'package:order_app/core/services/export_directory_service.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/core/services/order_pdf_service.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/domain/entities/expense_entity.dart';

enum FinancialViewMode { revenue, expenses, both }

class FinancialReportsScreen extends ConsumerStatefulWidget {
  const FinancialReportsScreen({super.key});

  @override
  ConsumerState<FinancialReportsScreen> createState() =>
      _FinancialReportsScreenState();
}

class _FinancialReportsScreenState
    extends ConsumerState<FinancialReportsScreen> {
  String _searchQuery = '';
  FinancialViewMode _viewType = FinancialViewMode.both;

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderNotifierProvider);
    final ordersStream = ref.watch(ordersStreamProvider);
    final allOrders = ordersStream.maybeWhen(
      data: (list) => list,
      orElse: () => orderState.orders,
    );
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final primaryColor = const Color(0xFF0075db);
    final bgColor = isDarkMode
        ? const Color(0xFF0b0f13)
        : const Color(0xFFf5f7f8);
    final cardColor = isDarkMode ? const Color(0xFF1a1f26) : Colors.white;
    final borderColor = isDarkMode
        ? const Color(0xFF262f3a)
        : const Color(0xFFf1f5f9);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final labelColor = isDarkMode
        ? const Color(0xFF94a3b8)
        : const Color(0xFF64748b);
    final successColor = const Color(0xFF4ade80);

    final filteredOrders = allOrders.where((order) {
      final query = _searchQuery.trim().toLowerCase();
      if (query.isEmpty) return true;

      final cleanNoSymbols = query.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final cleanNoPrefix = query
          .replaceAll('#', '')
          .replaceAll('order-', '')
          .replaceAll('ord-', '')
          .replaceAll('order', '')
          .replaceAll('id:', '')
          .trim();

      final orderIdLower = order.id.toLowerCase();
      final orderIdNoSymbols = orderIdLower.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '',
      );

      final idMatch =
          orderIdLower.contains(query) ||
          (cleanNoPrefix.isNotEmpty && orderIdLower.contains(cleanNoPrefix)) ||
          (cleanNoSymbols.isNotEmpty &&
              orderIdNoSymbols.contains(cleanNoSymbols));

      if (idMatch) return true;

      return order.eventName.toLowerCase().contains(query) ||
          order.venue.toLowerCase().contains(query) ||
          order.client.toLowerCase().contains(query) ||
          order.contactPerson.toLowerCase().contains(query);
    }).toList();

    final allItems = ref.watch(allItemsStreamProvider).value ?? [];
    final allExpenses = ref.watch(allExpensesStreamProvider).value ?? [];
    final allAdditionalRevenue =
        ref.watch(allAdditionalRevenueStreamProvider).value ?? [];

    // Calculate totals for export
    double totalRevenue = 0;
    double totalExpenses = 0;
    for (var order in filteredOrders) {
      totalRevenue += order.totalAmount;
      totalExpenses += order.totalExpenses;
    }
    final netProfit = totalRevenue - totalExpenses;
    final margin = totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0.0;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.8),
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: textColor),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Text(
                  'Financial Reports',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.table_chart_outlined, color: Colors.green),
                      tooltip: 'Export Financial Excel (.xlsx)',
                      onPressed: () async {
                        if (filteredOrders.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No orders to export')),
                          );
                          return;
                        }

                        final headers = [
                          'E.O.',
                          'Event Name',
                          'Venue',
                          'Client Name',
                          'Event / Rental',
                          'Event Date (BS)',
                          'Event Date (AD)',
                          'Total Revenue (NPR)',
                          'Advance Received (NPR)',
                          'Due Amount (NPR)',
                          'Total Expenses (NPR)',
                          'Profit / Loss (NPR)',
                        ];

                        int extractOrderNum(String id) {
                          final match = RegExp(r'\d+').firstMatch(id);
                          return match != null ? int.tryParse(match.group(0)!) ?? 0 : 0;
                        }

                        final sorted = List<OrderEntity>.from(filteredOrders)
                          ..sort((a, b) {
                            final numA = extractOrderNum(a.id);
                            final numB = extractOrderNum(b.id);
                            if (numA != 0 && numB != 0 && numA != numB) {
                              return numA.compareTo(numB);
                            }
                            return a.id.compareTo(b.id);
                          });

                        final List<List<dynamic>> rows = [];
                        double totalRev = 0.0;
                        double totalAdvance = 0.0;
                        double totalDue = 0.0;
                        double totalExp = 0.0;

                        for (final o in sorted) {
                          final clientName = o.client.isNotEmpty
                              ? o.client
                              : (o.contactPerson.isNotEmpty ? o.contactPerson : 'N/A');
                          final eventType = o.category.isNotEmpty ? o.category : 'Event';
                          final rev = o.totalAmount;
                          final advance = o.advanceReceived;
                          final due = (rev - advance).clamp(0.0, double.infinity);
                          final exp = o.totalExpenses;
                          final profitLoss = rev - exp;
                          final bsDate = formatNepaliDate(o.eventDate, 'yyyy-MM-dd');
                          final adDate = DateFormat('yyyy-MM-dd').format(o.eventDate);

                          totalRev += rev;
                          totalAdvance += advance;
                          totalDue += due;
                          totalExp += exp;

                          rows.add([
                            o.id,
                            o.eventName,
                            o.venue.isNotEmpty ? o.venue : 'N/A',
                            clientName,
                            eventType,
                            bsDate,
                            adDate,
                            rev,
                            advance,
                            due,
                            exp,
                            profitLoss,
                          ]);
                        }

                        final netProf = totalRev - totalExp;

                        rows.add([
                          'TOTAL',
                          '${sorted.length} Events',
                          '',
                          '',
                          '',
                          '',
                          '',
                          totalRev,
                          totalAdvance,
                          totalDue,
                          totalExp,
                          netProf,
                        ]);

                        final filename =
                            'Financial_Summary_${formatNepaliDate(DateTime.now(), 'yyyyMMdd')}.xlsx';

                        await ExcelExportHelper.exportAndShareExcel(
                          context: context,
                          headers: headers,
                          rows: rows,
                          filename: filename,
                          sheetName: 'Financial Summary',
                          title: 'Global Financial Summary Report',
                          category: ExportCategory.finance,
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.download, color: primaryColor),
                      tooltip: 'Export Summary PDF',
                      onPressed: () async {
                    if (filteredOrders.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No orders to export')),
                      );
                      return;
                    }

                    debugPrint('=== [GLOBAL FINANCIAL REPORT EXPORT DEBUG] ===');
                    debugPrint('Filtered orders count: ${filteredOrders.length}');
                    debugPrint('Total Revenue: $totalRevenue, Total Expenses: $totalExpenses, Net Profit: $netProfit, Margin: ${margin.toStringAsFixed(2)}%');
                    debugPrint('==============================================');

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Generating Financial Summary...'),
                      ),
                    );

                    try {
                      final pdfData =
                          await OrderPdfService.generateGlobalFinancialPdf(
                            orders: filteredOrders,
                            totalRevenue: totalRevenue,
                            totalExpenses: totalExpenses,
                            netProfit: netProfit,
                            margin: margin,
                            reportTitle: 'FINANCIAL SUMMARY REPORT',
                          );

                      if (!context.mounted) return;
                      await ShareHelper.sharePdf(
                        context: context,
                        pdfBytes: pdfData,
                        fileName:
                            'Financial_Summary_${formatNepaliDate(DateTime.now(), 'yyyyMMdd')}.pdf',
                        subject: 'Financial Summary Report',
                      );
                    } catch (e, st) {
                      debugPrint(
                        'PDF generation error [financial_reports/export]: $e\n$st',
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Export failed: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ),
  body: orderState.isLoading && orderState.orders.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(orderNotifierProvider.notifier).loadOrders(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                ).copyWith(bottom: 120, top: 24),
                child: Column(
                  children: [
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkMode ? cardColor : const Color(0xFFf1f5f9),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: isDarkMode
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: TextField(
                        style: TextStyle(fontSize: 14, color: textColor),
                        decoration: InputDecoration(
                          hintText:
                              'Search by event name, Order ID (e.g. 403), or venue...',
                          hintStyle: TextStyle(fontSize: 14, color: labelColor),
                          prefixIcon: Icon(Icons.search, color: labelColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // View Mode Toggle
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FINANCIAL PERSPECTIVE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: labelColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<FinancialViewMode>(
                            segments: const [
                              ButtonSegment(
                                value: FinancialViewMode.revenue,
                                label: Text('Revenue'),
                                icon: Icon(Icons.trending_up, size: 16),
                              ),
                              ButtonSegment(
                                value: FinancialViewMode.expenses,
                                label: Text('Expenses'),
                                icon: Icon(Icons.trending_down, size: 16),
                              ),
                              ButtonSegment(
                                value: FinancialViewMode.both,
                                label: Text('Both'),
                                icon: Icon(Icons.balance, size: 16),
                              ),
                            ],
                            selected: {_viewType},
                            onSelectionChanged: (newSelection) =>
                                setState(() => _viewType = newSelection.first),
                            style: SegmentedButton.styleFrom(
                              selectedBackgroundColor: primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              selectedForegroundColor: primaryColor,
                              side: BorderSide(color: borderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Recent Reports Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'EVENT FINANCIAL REPORTS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: labelColor,
                          ),
                        ),
                        Text(
                          '${filteredOrders.length} Reports Found',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (filteredOrders.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Text(
                          'No reports found',
                          style: TextStyle(color: labelColor),
                        ),
                      )
                    else
                      ...filteredOrders.map((order) {
                        final orderItems = allItems
                            .where((i) => i.orderId == order.id)
                            .toList();
                        final orderExpenses = allExpenses
                            .where((e) => e.orderId == order.id)
                            .toList();
                        final orderRev = allAdditionalRevenue
                            .where((r) => r.orderId == order.id)
                            .toList();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _FinancialReportCardWidget(
                            order: order,
                            isDarkMode: isDarkMode,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            textColor: textColor,
                            labelColor: labelColor,
                            successColor: successColor,
                            primaryColor: primaryColor,
                            viewType: _viewType,
                            orderItems: orderItems,
                            orderExpenses: orderExpenses,
                            additionalRevenue: orderRev,
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }
}

class _FinancialReportCardWidget extends ConsumerStatefulWidget {
  final OrderEntity order;
  final bool isDarkMode;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color labelColor;
  final Color successColor;
  final Color primaryColor;
  final FinancialViewMode viewType;
  final List<OrderItemEntity> orderItems;
  final List<ExpenseEntity> orderExpenses;
  final List<ExpenseEntity> additionalRevenue;

  const _FinancialReportCardWidget({
    required this.order,
    required this.isDarkMode,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.labelColor,
    required this.successColor,
    required this.primaryColor,
    required this.viewType,
    required this.orderItems,
    required this.orderExpenses,
    required this.additionalRevenue,
  });

  @override
  ConsumerState<_FinancialReportCardWidget> createState() =>
      __FinancialReportCardWidgetState();
}

class __FinancialReportCardWidgetState
    extends ConsumerState<_FinancialReportCardWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isDarkMode = widget.isDarkMode;
    final cardColor = widget.cardColor;
    final borderColor = widget.borderColor;
    final textColor = widget.textColor;
    final labelColor = widget.labelColor;
    final successColor = widget.successColor;
    final primaryColor = widget.primaryColor;
    final viewType = widget.viewType;

    final revenueVal = order.totalAmount;
    final expensesVal = order.totalExpenses;
    final profitVal = revenueVal - expensesVal;

    final revenueStr = NumberFormat.currency(
      symbol: 'NPR ',
      decimalDigits: 2,
    ).format(revenueVal);
    final expensesStr = NumberFormat.currency(
      symbol: 'NPR ',
      decimalDigits: 2,
    ).format(expensesVal);
    final netProfitStr = NumberFormat.currency(
      symbol: 'NPR ',
      decimalDigits: 2,
    ).format(profitVal);
    final date = formatNepaliDate(order.eventDate, 'MMM dd, yyyy');

    final vendorItems = widget.orderItems
        .where((i) => i.vendorAmount > 0 || i.vendor.isNotEmpty)
        .toList();

    Future<void> handlePdfGeneration() async {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating Event Financial Statement PDF...'),
        ),
      );
      try {
        final pdfData = await OrderPdfService.generateSingleEventFinancialPdf(
          order: order,
          items: widget.orderItems,
          orderExpenses: widget.orderExpenses,
          additionalRevenue: widget.additionalRevenue,
        );

        if (!context.mounted) return;
        final safeName = order.eventName.replaceAll(RegExp(r'[^\w\.-]'), '_');
        await ShareHelper.sharePdf(
          context: context,
          pdfBytes: pdfData,
          fileName: 'Financial_Statement_${order.id}_$safeName.pdf',
          subject: 'Event Financial Statement: ${order.eventName}',
        );
      } catch (e, st) {
        debugPrint('PDF generation error [financial_reports/report]: $e\n$st');
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── OVERVIEW HEADER ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.eventName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Order ID: #${order.id}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: successColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        order.status.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: successColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: labelColor),
                    const SizedBox(width: 4),
                    Text(
                      date,
                      style: TextStyle(fontSize: 12, color: labelColor),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '•',
                        style: TextStyle(fontSize: 12, color: labelColor),
                      ),
                    ),
                    Icon(Icons.location_on, size: 14, color: labelColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.venue,
                        style: TextStyle(fontSize: 12, color: labelColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ── METRICS SUMMARY ROW ──────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.black.withValues(alpha: 0.2)
                        : const Color(0xFFf8fafc),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      if (viewType == FinancialViewMode.revenue ||
                          viewType == FinancialViewMode.both)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'REVENUE',
                                style: TextStyle(
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                  color: labelColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  revenueStr,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (viewType == FinancialViewMode.expenses ||
                          viewType == FinancialViewMode.both)
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                viewType == FinancialViewMode.both
                                ? CrossAxisAlignment.center
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EXPENSES',
                                style: TextStyle(
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                  color: labelColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  expensesStr,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFef4444),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (viewType == FinancialViewMode.both)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'NET PROFIT',
                                style: TextStyle(
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                  color: labelColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  netProfitStr,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: profitVal >= 0
                                        ? successColor
                                        : const Color(0xFFef4444),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── EXPAND/COLLAPSE TOGGLE BUTTON ────────────────────────────
                InkWell(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isExpanded
                                  ? Icons.unfold_less
                                  : Icons.unfold_more,
                              size: 16,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isExpanded
                                  ? 'Hide Financial Breakdown'
                                  : 'Expand Revenue & Expense Details',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 18,
                          color: primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── EXPANDABLE BREAKDOWN SECTION ─────────────────────────────
          if (_isExpanded) ...[
            Container(
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF11161d)
                    : const Color(0xFFf8fafc),
                border: Border(
                  top: BorderSide(color: borderColor),
                  bottom: BorderSide(color: borderColor),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. REVENUE BREAKDOWN
                  Row(
                    children: [
                      Icon(Icons.trending_up, size: 16, color: primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'REVENUE BREAKDOWN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: textColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${widget.orderItems.length + widget.additionalRevenue.length} Items',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (widget.orderItems.isEmpty &&
                      widget.additionalRevenue.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No revenue items recorded',
                        style: TextStyle(
                          fontSize: 11,
                          color: labelColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else ...[
                    ...widget.orderItems.map((item) {
                      final itemAmt = item.billingType == 'event'
                          ? item.rate * item.quantity
                          : item.rate * item.quantity * item.days;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.itemName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                  if (item.specification.isNotEmpty)
                                    Text(
                                      item.specification,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: labelColor,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                item.billingType == 'event'
                                    ? '${item.quantity} ${item.unit} @ Rs.${item.rate.toStringAsFixed(0)}'
                                    : '${item.quantity} ${item.unit} x ${item.days}d @ Rs.${item.rate.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: labelColor,
                                ),
                              ),
                            ),
                            Text(
                              'Rs.${itemAmt.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    ...widget.additionalRevenue.map(
                      (rev) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                '${rev.category}: ${rev.description}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ),
                            Text(
                              'Rs.${rev.amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const Divider(height: 24),

                  // 2. EXPENSES BREAKDOWN
                  Row(
                    children: [
                      const Icon(
                        Icons.trending_down,
                        size: 16,
                        color: Color(0xFFef4444),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'EXPENSES BREAKDOWN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: textColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${vendorItems.length + widget.orderExpenses.length} Entries',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (vendorItems.isEmpty && widget.orderExpenses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No expense items recorded for this order',
                        style: TextStyle(
                          fontSize: 11,
                          color: labelColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else ...[
                    ...vendorItems.map(
                      (vItem) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vItem.itemName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    'Vendor: ${vItem.vendor.isNotEmpty ? vItem.vendor : "Direct Supplier"}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: const Color(0xFFef4444),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Rs.${vItem.vendorRate.toStringAsFixed(0)} / unit',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: labelColor,
                                ),
                              ),
                            ),
                            Text(
                              'Rs.${vItem.vendorAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFef4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ...widget.orderExpenses.map(
                      (exp) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    exp.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    'Category: ${exp.category} ${exp.vendorName != null && exp.vendorName!.isNotEmpty ? "(${exp.vendorName})" : ""}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: labelColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Rs.${exp.amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFef4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // ── ACTION BUTTONS FOOTER ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: handlePdfGeneration,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: BorderSide(
                        color: primaryColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      'View Financial Statement PDF',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildIconButton(
                  Icons.download,
                  isDarkMode,
                  cardColor,
                  handlePdfGeneration,
                ),
                const SizedBox(width: 12),
                _buildIconButton(
                  Icons.share,
                  isDarkMode,
                  cardColor,
                  handlePdfGeneration,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(
    IconData icon,
    bool isDarkMode,
    Color cardColor,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF1e293b).withValues(alpha: 0.5)
            : const Color(0xFFf1f5f9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: isDarkMode ? const Color(0xFFcbd5e1) : const Color(0xFF475569),
        ),
        onPressed: onTap,
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(),
      ),
    );
  }
}
