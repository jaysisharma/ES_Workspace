import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:order_app/core/calendar/nepali_calendar_engine.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  String _filterLabel = 'All Events';

  @override
  void initState() {
    super.initState();
    // Default to current month (BS 1st to Current Date)
    _selectCurrentMonth();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectCurrentMonth() {
    final now = DateTime.now();
    final bsNow = NepaliCalendarEngine.adToBs(now);
    // 1st day of the current Nepali month in AD
    final bsStart = NepaliDateTime(bsNow.year, bsNow.month, 1);
    final startAd = NepaliCalendarEngine.bsToAd(bsStart);
    final start = DateTime(startAd.year, startAd.month, startAd.day, 0, 0, 0);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final monthName = NepaliCalendarEngine.monthsEnglish[bsNow.month - 1];

    setState(() {
      _selectedDateRange = DateTimeRange(start: start, end: end);
      _filterLabel = '$monthName 1 - ${bsNow.day} (${bsNow.year})';
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
      'Advance Received (NPR)',
      'Due Amount (NPR)',
    ];

    int extractOrderNum(String id) {
      final match = RegExp(r'\d+').firstMatch(id);
      return match != null ? int.tryParse(match.group(0)!) ?? 0 : 0;
    }

    final sorted = List<OrderEntity>.from(orders)
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
        rev,
        exp,
        profitLoss,
        advance,
        due,
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
      totalAdvance,
      totalDue,
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

  Future<void> _exportEventsFinancialPdf(List<OrderEntity> orders) async {
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No event records to export.')),
      );
      return;
    }

    double totalRevenue = 0;
    double totalExpenses = 0;
    for (var o in orders) {
      totalRevenue += o.totalAmount;
      totalExpenses += o.totalExpenses;
    }
    final netProfit = totalRevenue - totalExpenses;
    final margin = totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0.0;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating Event Financial Report PDF...')),
    );

    try {
      final pdfData = await OrderPdfService.generateGlobalFinancialPdf(
        orders: orders,
        totalRevenue: totalRevenue,
        totalExpenses: totalExpenses,
        netProfit: netProfit,
        margin: margin,
        periodText: _filterLabel,
        reportTitle: 'EVENT FINANCIAL REPORT',
      );

      if (!context.mounted) return;
      final cleanLabel = _filterLabel.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      await ShareHelper.sharePdf(
        context: context,
        pdfBytes: pdfData,
        fileName: 'Event_Financial_Report_$cleanLabel.pdf',
        subject: 'Event Financial Report - $_filterLabel',
      );
    } catch (e, st) {
      debugPrint('PDF export error in event_financial_report: $e\n$st');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export PDF failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
            icon: Icon(
              _selectedDateRange != null
                  ? Icons.filter_alt_rounded
                  : Icons.date_range_outlined,
              color: _selectedDateRange != null
                  ? colorScheme.primary
                  : null,
            ),
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 22),
            tooltip: 'More options',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) async {
              final orders = ordersAsync.value ?? [];
              final filtered = _getFilteredOrders(orders);
              switch (value) {
                case 'export_pdf':
                  _exportEventsFinancialPdf(filtered);
                  break;
                case 'export_excel':
                  _exportEventsFinancialExcel(filtered);
                  break;
                case 'filter_date':
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
                  break;
                case 'current_month':
                  _selectCurrentMonth();
                  break;
                case 'clear_filter':
                  setState(() {
                    _selectedDateRange = null;
                    _filterLabel = 'All Events';
                  });
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_pdf',
                child: Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 18,
                      color: Color(0xFFf43f5e),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Export Summary PDF',
                      style: TextStyle(fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_excel',
                child: Row(
                  children: [
                    Icon(
                      Icons.table_chart_outlined,
                      size: 18,
                      color: Colors.green,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Export to Excel (.xlsx)',
                      style: TextStyle(fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'filter_date',
                child: Row(
                  children: [
                    Icon(Icons.date_range_outlined, size: 18),
                    SizedBox(width: 12),
                    Text(
                      'Filter Date Range (BS)',
                      style: TextStyle(fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'current_month',
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 18),
                    SizedBox(width: 12),
                    Text(
                      'Reset to Current Month',
                      style: TextStyle(fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              if (_selectedDateRange != null) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'clear_filter',
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_alt_off_outlined,
                        size: 18,
                        color: Colors.orange,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Clear Date Filter',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ordersAsync.when(
        data: (orders) {
          final filteredOrders = _getFilteredOrders(orders);

          double totalRevenue = 0;
          double totalExpenses = 0;
          double totalAdvance = 0;
          double totalDue = 0;
          for (var o in filteredOrders) {
            totalRevenue += o.totalAmount;
            totalExpenses += o.totalExpenses;
            totalAdvance += o.advanceReceived;
            totalDue += (o.totalAmount - o.advanceReceived).clamp(0.0, double.infinity);
          }
          final totalProfit = totalRevenue - totalExpenses;

          return Column(
            children: [
              // 1. TOP: KPI Cards (REV, ADV, DUE, EXP, NET)
              _buildKpiRow(
                context,
                totalRevenue,
                totalAdvance,
                totalDue,
                totalExpenses,
                totalProfit,
                currencyLabel,
              ),

              // 2. BELOW: Responsive Search & Date Filters
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;

                    final datePickerButton = Material(
                      color: _selectedDateRange != null
                          ? colorScheme.primary.withValues(alpha: 0.12)
                          : cardColor,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () async {
                          final picked = await NepaliDatePickerDialog.show(
                            context: context,
                            title: 'Filter Event Date Range',
                            initialStart: _selectedDateRange?.start ??
                                DateTime.now(),
                            initialEnd:
                                _selectedDateRange?.end ?? DateTime.now(),
                            allowRange: true,
                          );
                          if (picked != null && picked['start'] != null) {
                            final start = picked['start']!;
                            final end = picked['end'] ?? picked['start']!;
                            setState(() {
                              _selectedDateRange =
                                  DateTimeRange(start: start, end: end);
                              _filterLabel =
                                  '${formatNepaliDate(start, 'yyyy-MM-dd')} to ${formatNepaliDate(end, 'yyyy-MM-dd')}';
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _selectedDateRange != null
                                  ? colorScheme.primary.withValues(alpha: 0.6)
                                  : colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_month_rounded,
                                size: 16,
                                color: _selectedDateRange != null
                                    ? colorScheme.primary
                                    : labelColor,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _selectedDateRange != null
                                      ? _filterLabel
                                      : 'Select Date',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: _selectedDateRange != null
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: _selectedDateRange != null
                                        ? colorScheme.primary
                                        : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_selectedDateRange != null) ...[
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedDateRange = null;
                                      _filterLabel = 'All Events';
                                    });
                                  },
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 15,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );

                    final searchField = TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: TextStyle(
                            fontSize: 12.5, color: labelColor),
                        prefixIcon:
                            const Icon(Icons.search_rounded, size: 17),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 32),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        isDense: true,
                        filled: true,
                        fillColor: cardColor,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 9.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.4)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: colorScheme.primary, width: 1.5),
                        ),
                      ),
                      onChanged: (val) =>
                          setState(() => _searchQuery = val),
                    );

                    if (isWide) {
                      return Row(
                        children: [
                          datePickerButton,
                          const SizedBox(width: 10),
                          SizedBox(width: 220, child: searchField),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _exportEventsFinancialExcel(filteredOrders),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10b981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.table_chart_rounded,
                                size: 15),
                            label: Text(
                              'Excel (${filteredOrders.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _exportEventsFinancialPdf(filteredOrders),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFf43f5e),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.picture_as_pdf_rounded,
                                size: 15),
                            label: Text(
                              'PDF (${filteredOrders.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Row(
                        children: [
                          SizedBox(width: 135, child: searchField),
                          const SizedBox(width: 8),
                          Expanded(child: datePickerButton),
                        ],
                      );
                    }
                  },
                ),
              ),

              // 3. Events List
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
      final isSearching = query.isNotEmpty;

      final cleanNoSymbols = query.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final cleanNoPrefix = query
          .replaceAll('#', '')
          .replaceAll('order-', '')
          .replaceAll('ord-', '')
          .replaceAll('order', '')
          .replaceAll('id:', '')
          .trim();

      final orderIdLower = o.id.toLowerCase();
      final orderIdNoSymbols = orderIdLower.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '',
      );

      final idMatch = orderIdLower == query ||
          (cleanNoPrefix.isNotEmpty && orderIdLower == cleanNoPrefix) ||
          (cleanNoSymbols.isNotEmpty && orderIdNoSymbols == cleanNoSymbols) ||
          orderIdLower.contains(query) ||
          (cleanNoPrefix.isNotEmpty && orderIdLower.contains(cleanNoPrefix)) ||
          (cleanNoSymbols.isNotEmpty &&
              orderIdNoSymbols.contains(cleanNoSymbols));

      final nameMatch = o.eventName.toLowerCase().contains(query);
      final venueMatch = o.venue.toLowerCase().contains(query);
      final clientMatch = o.client.toLowerCase().contains(query) ||
          o.contactPerson.toLowerCase().contains(query);
      final notesMatch = o.notes.toLowerCase().contains(query) ||
          o.description.toLowerCase().contains(query) ||
          o.category.toLowerCase().contains(query);

      final matchesQuery =
          !isSearching || idMatch || nameMatch || venueMatch || clientMatch || notesMatch;

      bool dateMatch = true;
      if (!isSearching && _selectedDateRange != null) {
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

  Widget _buildKpiRow(
    BuildContext context,
    double revenue,
    double advance,
    double due,
    double expenses,
    double profit,
    String currency,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0075db);
    final cardBg = isDark ? const Color(0xFF141f28) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF1e2d3d) : const Color(0xFFe2e8f0);
    final textMuted =
        isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b);
    final textColor = isDark ? Colors.white : const Color(0xFF0f172a);

    final marginPercent =
        revenue > 0 ? ((profit / revenue) * 100).toStringAsFixed(1) : '0';

    final revCard = _buildKPICard(
      label: 'REV',
      title: 'Revenue',
      amount: revenue,
      color: primaryColor,
      cardBg: cardBg,
      borderColor: borderColor,
      textColor: textColor,
      textMuted: textMuted,
      icon: Icons.trending_up_rounded,
    );

    final advCard = _buildKPICard(
      label: 'ADV',
      title: 'Advance',
      amount: advance,
      color: const Color(0xFF059669),
      cardBg: cardBg,
      borderColor: borderColor,
      textColor: textColor,
      textMuted: textMuted,
      icon: Icons.payments_outlined,
    );

    final dueCard = _buildKPICard(
      label: 'DUE',
      title: 'Due Amount',
      amount: due,
      color: const Color(0xFFd97706),
      cardBg: cardBg,
      borderColor: borderColor,
      textColor: textColor,
      textMuted: textMuted,
      icon: Icons.pending_actions_rounded,
    );

    final expCard = _buildKPICard(
      label: 'EXP',
      title: 'Expenses',
      amount: expenses,
      color: const Color(0xFFf43f5e),
      cardBg: cardBg,
      borderColor: borderColor,
      textColor: textColor,
      textMuted: textMuted,
      icon: Icons.trending_down_rounded,
    );

    final netCard = _buildKPICard(
      label: 'NET',
      title: 'Net Profit',
      amount: profit,
      badge: '$marginPercent%',
      color: profit >= 0
          ? const Color(0xFF10b981)
          : const Color(0xFFef4444),
      cardBg: cardBg,
      borderColor: borderColor,
      textColor: textColor,
      textMuted: textMuted,
      icon: profit >= 0
          ? Icons.account_balance_wallet_rounded
          : Icons.money_off_rounded,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 950) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(child: revCard),
                const SizedBox(width: 8),
                Expanded(child: advCard),
                const SizedBox(width: 8),
                Expanded(child: dueCard),
                const SizedBox(width: 8),
                Expanded(child: expCard),
                const SizedBox(width: 8),
                Expanded(child: netCard),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              SizedBox(width: 165, child: revCard),
              const SizedBox(width: 8),
              SizedBox(width: 165, child: advCard),
              const SizedBox(width: 8),
              SizedBox(width: 165, child: dueCard),
              const SizedBox(width: 8),
              SizedBox(width: 165, child: expCard),
              const SizedBox(width: 8),
              SizedBox(width: 175, child: netCard),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKPICard({
    required String label,
    required String title,
    required double amount,
    String? badge,
    required Color color,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color textMuted,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon Circle + Badge / Label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: color,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          badge,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 3),

          // Amount
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.formatCompactWithLabel(amount, 'NPR'),
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                color: textColor,
                letterSpacing: -0.5,
                fontFamily: 'Manrope',
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
                              'ID: ${order.id}',
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

            // ── 2. SUMMARY ROW (REVENUE, ADVANCE, DUE, EXPENSES, NET PROFIT) ─────
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
              child: Column(
                children: [
                  Row(
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
                  if (order.totalAmount > 0 || order.advanceReceived > 0) ...[
                    const SizedBox(height: 8),
                    Divider(
                      height: 1,
                      color: colorScheme.outline.withValues(alpha: 0.12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _FinancialMiniStat(
                            label: 'ADVANCE RECEIVED',
                            value: order.advanceReceived,
                            currency: widget.currency,
                            color: const Color(0xFF059669),
                          ),
                        ),
                        Expanded(
                          child: _FinancialMiniStat(
                            label: 'DUE AMOUNT',
                            value: (order.totalAmount - order.advanceReceived)
                                .clamp(0.0, double.infinity),
                            currency: widget.currency,
                            color: (order.totalAmount - order.advanceReceived) >
                                    0.01
                                ? const Color(0xFFd97706)
                                : const Color(0xFF059669),
                            isBold: (order.totalAmount - order.advanceReceived) >
                                0.01,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── 3. CLEAN 50/50 ACTION ROW (Breakdown, PDF Statement) ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    icon: Icon(
                      _isExpanded
                          ? Icons.unfold_less_rounded
                          : Icons.unfold_more_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _isExpanded ? 'Hide Items' : 'Breakdown',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(
                        color: colorScheme.primary.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: handlePdfGeneration,
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                    label: const Text(
                      'PDF Statement',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
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
