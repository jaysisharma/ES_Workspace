import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/core/utils/currency_formatter.dart';
import 'package:order_app/core/utils/share_helper.dart';
import 'package:order_app/core/utils/excel_export_helper.dart';
import 'package:order_app/core/services/export_directory_service.dart';
import 'package:order_app/core/services/order_pdf_service.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/domain/entities/expense_entity.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/providers/settings_provider.dart';
import 'package:order_app/presentation/widgets/calendar/nepali_date_picker_dialog.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';

class EventFinancialReportScreen extends ConsumerStatefulWidget {
  const EventFinancialReportScreen({super.key});

  @override
  ConsumerState<EventFinancialReportScreen> createState() =>
      _EventFinancialReportScreenState();
}

class _EventFinancialReportScreenState
    extends ConsumerState<EventFinancialReportScreen> {
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  String _filterLabel = 'All Events';

  @override
  void initState() {
    super.initState();
    // Default to current month (BS)
    _selectCurrentMonth();
  }

  void _selectCurrentMonth() {
    final now = DateTime.now();
    // Start of approx month window (first day of current month)
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    setState(() {
      _selectedDateRange = DateTimeRange(start: start, end: end);
      _filterLabel = formatNepaliDate(now, 'yyyy MMMM');
    });
  }

  Future<void> _exportEventsFinancialExcel(List<OrderEntity> orders) async {
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No event records to export.')),
      );
      return;
    }

    final headers = [
      'E.O.',
      'Event Name',
      'Venue',
      'Client Name',
      'Event / Rental',
      'Total Revenue (NPR)',
      'Total Expenses (NPR)',
      'Profit / Loss (NPR)',
    ];

    final sorted = List<OrderEntity>.from(orders)
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

    final List<List<dynamic>> rows = [];
    double totalRev = 0.0;
    double totalExp = 0.0;

    for (final o in sorted) {
      final clientName = o.client.isNotEmpty
          ? o.client
          : (o.contactPerson.isNotEmpty ? o.contactPerson : 'N/A');
      final eventType = o.category.isNotEmpty ? o.category : 'Event';
      final rev = o.totalAmount;
      final exp = o.totalExpenses;
      final profitLoss = rev - exp;

      totalRev += rev;
      totalExp += exp;

      rows.add([
        o.id,
        o.eventName,
        o.venue.isNotEmpty ? o.venue : 'N/A',
        clientName,
        eventType,
        rev,
        exp,
        profitLoss,
      ]);
    }

    final netProfit = totalRev - totalExp;

    // Totals / Summary Row at the bottom
    rows.add([
      'TOTAL',
      '${sorted.length} Events',
      '',
      '',
      '',
      totalRev,
      totalExp,
      netProfit,
    ]);

    final cleanLabel = _filterLabel.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final filename = 'Event_Financial_Report_$cleanLabel.xlsx';
    final reportTitle = 'Event Monthly Financial Report - $_filterLabel';

    await ExcelExportHelper.exportAndShareExcel(
      context: context,
      headers: headers,
      rows: rows,
      filename: filename,
      sheetName: 'Event Financial Report',
      title: reportTitle,
      category: ExportCategory.finance,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ordersAsync = ref.watch(ordersStreamProvider);
    final allItems = ref.watch(allItemsStreamProvider).value ?? [];
    final allExpenses = ref.watch(allExpensesStreamProvider).value ?? [];
    final allAdditionalRevenue =
        ref.watch(allAdditionalRevenueStreamProvider).value ?? [];

    final settings = ref.watch(settingsProvider);
    final currencyLabel = settings.currency.split(' ').first;

    final bgColor = colorScheme.surface;
    final cardColor = colorScheme.surface;
    final labelColor = colorScheme.onSurfaceVariant;
    final successColor = const Color(0xFF4ade80);
    final errorColor = colorScheme.error;

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: const BottomRightBackButton(),
      appBar: AppBar(
        title: const Text(
          'Event Financial Reports',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_outlined, color: Colors.greenAccent),
            tooltip: 'Export to Excel',
            onPressed: () {
              final orders = ordersAsync.value ?? [];
              final filtered = _getFilteredOrders(orders);
              _exportEventsFinancialExcel(filtered);
            },
          ),
          IconButton(
            icon: const Icon(Icons.date_range_outlined),
            tooltip: 'Filter Date Range',
            onPressed: () async {
              final picked = await NepaliDatePickerDialog.show(
                context: context,
                title: 'Filter Event Date Range',
                initialStart: _selectedDateRange?.start ?? DateTime.now(),
                initialEnd: _selectedDateRange?.end ?? DateTime.now(),
                allowRange: true,
              );
              if (picked != null && picked['start'] != null) {
                final start = picked['start']!;
                final end = picked['end'] ?? picked['start']!;
                setState(() {
                  _selectedDateRange = DateTimeRange(start: start, end: end);
                  _filterLabel =
                      '${formatNepaliDate(start, 'yyyy-MM-dd')} to ${formatNepaliDate(end, 'yyyy-MM-dd')}';
                });
              }
            },
          ),
          if (_selectedDateRange != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear Filter',
              onPressed: () => setState(() {
                _selectedDateRange = null;
                _filterLabel = 'All Events';
              }),
            ),
        ],
      ),
      body: ordersAsync.when(
        data: (orders) {
          final filteredOrders = _getFilteredOrders(orders);

          double totalRevenue = 0;
          double totalExpenses = 0;
          for (var o in filteredOrders) {
            totalRevenue += o.totalAmount;
            totalExpenses += o.totalExpenses;
          }
          final totalProfit = totalRevenue - totalExpenses;

          return Column(
            children: [
              // Search & Filter Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText:
                        'Search by event name, Order ID (e.g. 403), or venue...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: cardColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),

              // Date Selection Chips Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    FilterChip(
                      selected: _selectedDateRange != null && _filterLabel.contains(formatNepaliDate(DateTime.now(), 'MMMM')),
                      avatar: const Icon(Icons.calendar_month_rounded, size: 16),
                      label: Text('This Month (${formatNepaliDate(DateTime.now(), "MMMM")})'),
                      onSelected: (_) => _selectCurrentMonth(),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _selectedDateRange != null && !_filterLabel.contains(formatNepaliDate(DateTime.now(), 'MMMM')),
                      avatar: const Icon(Icons.tune_rounded, size: 16),
                      label: Text(_selectedDateRange != null && !_filterLabel.contains(formatNepaliDate(DateTime.now(), 'MMMM'))
                          ? _filterLabel
                          : 'Pick Date Range'),
                      onSelected: (_) async {
                        final picked = await NepaliDatePickerDialog.show(
                          context: context,
                          title: 'Filter Event Date Range',
                          initialStart: _selectedDateRange?.start ?? DateTime.now(),
                          initialEnd: _selectedDateRange?.end ?? DateTime.now(),
                          allowRange: true,
                        );
                        if (picked != null && picked['start'] != null) {
                          final start = picked['start']!;
                          final end = picked['end'] ?? picked['start']!;
                          setState(() {
                            _selectedDateRange = DateTimeRange(start: start, end: end);
                            _filterLabel =
                                '${formatNepaliDate(start, 'yyyy-MM-dd')} to ${formatNepaliDate(end, 'yyyy-MM-dd')}';
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _selectedDateRange == null,
                      avatar: const Icon(Icons.all_inclusive_rounded, size: 16),
                      label: const Text('All Time'),
                      onSelected: (_) => setState(() {
                        _selectedDateRange = null;
                        _filterLabel = 'All Events';
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Summary Banner with Export Button
              _buildSummaryBanner(
                context,
                totalRevenue,
                totalExpenses,
                totalProfit,
                currencyLabel,
                filteredOrders,
              ),

              Expanded(
                child: filteredOrders.isEmpty
                    ? Center(
                        child: Text(
                          'No reports found',
                          style: TextStyle(color: labelColor),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredOrders.length,
                        itemBuilder: (context, index) {
                          final order = filteredOrders[index];
                          final orderItems = allItems
                              .where((i) => i.orderId == order.id)
                              .toList();
                          final orderExpenses = allExpenses
                              .where((e) => e.orderId == order.id)
                              .toList();
                          final orderRev = allAdditionalRevenue
                              .where((r) => r.orderId == order.id)
                              .toList();

                          return _EventFinancialCardWidget(
                            order: order,
                            currency: currencyLabel,
                            successColor: successColor,
                            errorColor: errorColor,
                            orderItems: orderItems,
                            orderExpenses: orderExpenses,
                            additionalRevenue: orderRev,
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  List<OrderEntity> _getFilteredOrders(List<OrderEntity> orders) {
    return orders.where((o) {
      final query = _searchQuery.trim().toLowerCase();
      final nameMatch = o.eventName.toLowerCase().contains(query);
      final idMatch = o.id.toLowerCase().contains(query);
      final venueMatch = o.venue.toLowerCase().contains(query);
      final clientMatch = o.client.toLowerCase().contains(query) ||
          o.contactPerson.toLowerCase().contains(query);
      final matchesQuery = nameMatch || idMatch || venueMatch || clientMatch;

      bool dateMatch = true;
      if (_selectedDateRange != null) {
        dateMatch = o.eventDate.isAfter(
              _selectedDateRange!.start.subtract(const Duration(days: 1)),
            ) &&
            o.eventDate.isBefore(
              _selectedDateRange!.end.add(const Duration(days: 1)),
            );
      }
      return matchesQuery && dateMatch && o.status != OrderStatus.draft;
    }).toList();
  }

  Widget _buildSummaryBanner(
    BuildContext context,
    double revenue,
    double expenses,
    double profit,
    String currency,
    List<OrderEntity> orders,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryItem(
                label: 'REV',
                value: revenue,
                currency: currency,
                color: colorScheme.primary,
              ),
              _SummaryItem(
                label: 'EXP',
                value: expenses,
                currency: currency,
                color: colorScheme.error,
              ),
              _SummaryItem(
                label: 'NET',
                value: profit,
                currency: currency,
                color: const Color(0xFF4ade80),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _exportEventsFinancialExcel(orders),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10b981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.table_chart_rounded, size: 18),
              label: Text(
                'Export ${orders.length} Events to Excel ($_filterLabel)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventFinancialCardWidget extends ConsumerStatefulWidget {
  final OrderEntity order;
  final String currency;
  final Color successColor;
  final Color errorColor;
  final List<OrderItemEntity> orderItems;
  final List<ExpenseEntity> orderExpenses;
  final List<ExpenseEntity> additionalRevenue;

  const _EventFinancialCardWidget({
    required this.order,
    required this.currency,
    required this.successColor,
    required this.errorColor,
    required this.orderItems,
    required this.orderExpenses,
    required this.additionalRevenue,
  });

  @override
  ConsumerState<_EventFinancialCardWidget> createState() =>
      __EventFinancialCardWidgetState();
}

class __EventFinancialCardWidgetState
    extends ConsumerState<_EventFinancialCardWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final profit = order.totalAmount - order.totalExpenses;

    final cardBg = colorScheme.surface;
    final borderColor = colorScheme.outline.withValues(alpha: 0.15);
    final textColor = colorScheme.onSurface;
    final labelColor = colorScheme.onSurfaceVariant;

    final vendorItems = widget.orderItems
        .where((i) => i.vendorAmount > 0 || i.vendor.isNotEmpty)
        .toList();

    Future<void> handlePdfGeneration() async {
      debugPrint('=== [EVENT FINANCIAL REPORT PDF GENERATION] ===');
      debugPrint('Order ID: ${order.id}, Event Name: ${order.eventName}');
      debugPrint('Total Items: ${widget.orderItems.length}, Vendor Items: ${vendorItems.length}');
      debugPrint('Total Expenses: ${widget.orderExpenses.length}, Additional Revenue: ${widget.additionalRevenue.length}');
      debugPrint('===============================================');

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
        debugPrint(
          'PDF generation error [event_financial_report/report]: $e\n$st',
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. HEADER (Event Name, #Order ID Badge, Nepali Date, Venue) ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.eventName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '#${order.id}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                          if (order.venue.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: labelColor,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                order.venue,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: labelColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatNepaliDate(order.eventDate, 'MMM dd, yyyy'),
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── 2. SUMMARY ROW (3 Columns: REVENUE, EXPENSES, NET PROFIT) ─────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.black.withValues(alpha: 0.25)
                    : colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.3,
                      ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _FinancialMiniStat(
                      label: 'REVENUE',
                      value: order.totalAmount,
                      currency: widget.currency,
                      color: textColor,
                    ),
                  ),
                  Expanded(
                    child: _FinancialMiniStat(
                      label: 'EXPENSES',
                      value: order.totalExpenses,
                      currency: widget.currency,
                      color: widget.errorColor,
                    ),
                  ),
                  Expanded(
                    child: _FinancialMiniStat(
                      label: 'NET PROFIT',
                      value: profit,
                      currency: widget.currency,
                      color: profit >= 0
                          ? widget.successColor
                          : widget.errorColor,
                      isBold: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── 3. SINGLE ACTION ROW (View Breakdown, PDF Statement, Download, Share) ──
            Row(
              children: [
                // View Breakdown Toggle Button
                Expanded(
                  flex: 4,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    icon: Icon(
                      _isExpanded ? Icons.unfold_less : Icons.unfold_more,
                      size: 15,
                    ),
                    label: Text(
                      _isExpanded ? 'Hide' : 'Breakdown',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      side: BorderSide(
                        color: colorScheme.primary.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // PDF Statement Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: handlePdfGeneration,
                    icon: const Icon(Icons.picture_as_pdf, size: 15),
                    label: const Text(
                      'PDF Statement',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                // Download Icon
                IconButton(
                  icon: const Icon(Icons.download, size: 18),
                  tooltip: 'Download PDF',
                  onPressed: handlePdfGeneration,
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(width: 6),
                // Share Icon
                IconButton(
                  icon: const Icon(Icons.share, size: 18),
                  tooltip: 'Share PDF',
                  onPressed: handlePdfGeneration,
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.all(10),
                  ),
                ),
              ],
            ),

            // ── 4. EXPANDABLE SECTION (Revenue & Expenses Tables) ─────────────
            if (_isExpanded) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.black.withValues(alpha: 0.3)
                      : colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.2,
                        ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 📈 REVENUE BREAKDOWN
                    Row(
                      children: [
                        Icon(
                          Icons.trending_up,
                          size: 16,
                          color: colorScheme.primary,
                        ),
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
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL REVENUE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            Text(
                              '${widget.currency} ${order.totalAmount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Divider(height: 24),

                    // 📉 EXPENSES BREAKDOWN
                    Row(
                      children: [
                        Icon(
                          Icons.trending_down,
                          size: 16,
                          color: widget.errorColor,
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
                                        color: widget.errorColor,
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
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: widget.errorColor,
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
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: widget.errorColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: widget.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: widget.errorColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL EXPENSES',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: widget.errorColor,
                              ),
                            ),
                            Text(
                              '${widget.currency} ${order.totalExpenses.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: widget.errorColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double value;
  final String currency;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.currency,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color.withValues(alpha: 0.7),
          ),
        ),
        Text(
          CurrencyFormatter.format(value, showDecimal: false),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _FinancialMiniStat extends StatelessWidget {
  final String label;
  final double value;
  final String currency;
  final Color color;
  final bool isBold;

  const _FinancialMiniStat({
    required this.label,
    required this.value,
    required this.currency,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 8,
            letterSpacing: 0.5,
            color: color.withValues(alpha: 0.6),
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          CurrencyFormatter.format(value, showDecimal: false),
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
