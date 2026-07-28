import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/nepali_date_formatter.dart';
import '../../providers/order_providers.dart';
import '../../providers/vendor_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/settings_provider.dart';
import '../../../domain/entities/order_entity.dart';
import '../../../domain/entities/order_item_entity.dart';
import '../../../domain/entities/expense_entity.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/route_transitions.dart';
import '../../../core/utils/excel_export_helper.dart';
import '../../../core/services/order_pdf_service.dart';
import 'pdf_preview_screen.dart';

class FinancialLedgerScreen extends ConsumerStatefulWidget {
  const FinancialLedgerScreen({super.key});

  @override
  ConsumerState<FinancialLedgerScreen> createState() =>
      _FinancialLedgerScreenState();
}

class _FinancialLedgerScreenState extends ConsumerState<FinancialLedgerScreen> {
  String? _selectedName;
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, 1, 1),
    end: DateTime.now(),
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final vendorsAsync = ref.watch(vendorNotifierProvider);
    final clientsAsync = ref.watch(clientNotifierProvider);
    final ordersAsync = ref.watch(ordersStreamProvider);
    final allItemsAsync = ref.watch(allItemsStreamProvider);
    final allExpensesAsync = ref.watch(allExpensesStreamProvider);
    final allAdditionalRevenueAsync = ref.watch(allAdditionalRevenueStreamProvider);
    final settings = ref.watch(settingsProvider);
    final currencyLabel = settings.currency.split(' ').first;

    // Combine unique names from vendors and clients
    final allNames = {
      ...vendorsAsync.vendors.map((v) => v.name),
      ...clientsAsync.clients.map((c) => c.name),
    }.toList()..sort();

    final filteredNames = allNames
        .where((name) => name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Financial Ledger',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_outlined),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                initialDateRange: _selectedDateRange,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => _selectedDateRange = picked);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ordersStreamProvider);
          ref.invalidate(allItemsStreamProvider);
          ref.invalidate(allExpensesStreamProvider);
          ref.invalidate(allAdditionalRevenueStreamProvider);
          ref.invalidate(vendorNotifierProvider);
          ref.invalidate(clientNotifierProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Filter Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                          // If the query exactly matches one name, select it automatically
                          // but typically we want the user to click.
                          // However, we can also search transactions directly by this query.
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search Vendor, Client or Event...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty 
                            ? IconButton(
                                icon: const Icon(Icons.clear), 
                                onPressed: () => setState(() {
                                  _searchQuery = '';
                                  _selectedName = null;
                                }),
                              ) 
                            : null,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surface,
                      ),
                    ),
                    if (filteredNames.isNotEmpty && _selectedName == null && _searchQuery.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredNames.length,
                          itemBuilder: (context, index) {
                            final name = filteredNames[index];
                            return ListTile(
                              title: Text(name),
                              onTap: () => setState(() {
                                _selectedName = name;
                                _searchQuery = ''; // Clear search once selected
                              }),
                            );
                          },
                        ),
                      ),
                    if (_selectedName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Chip(
                          label: Text(_selectedName!),
                          onDeleted: () => setState(() => _selectedName = null),
                          deleteIcon: const Icon(Icons.close, size: 18),
                        ),
                      ),
                  ],
                ),
              ),

              if (_selectedDateRange != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event, size: 16, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Period: ${formatNepaliDate(_selectedDateRange!.start, 'MMM dd, yyyy')} - ${formatNepaliDate(_selectedDateRange!.end, 'MMM dd, yyyy')}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              _selectedName == null
                  ? _buildEmptyState('Select an entity to view ledger')
                  : ordersAsync.when(
                      data: (ordersRaw) {
                        final orders = ordersRaw.cast<OrderEntity>();
                        return allItemsAsync.when(
                          data: (allItems) {
                            return allExpensesAsync.when(
                              data: (allExpenses) {
                                return allAdditionalRevenueAsync.when(
                                  data: (allManualRevenues) {
                                    // --- FILTERING LOGIC ---
                                    
                                    // 1. Orders where this entity is the CLIENT (Revenue)
                                    final revenueOrders = orders.where((o) {
                                      final dateMatch = _selectedDateRange == null ||
                                          (o.eventDate.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                                           o.eventDate.isBefore(_selectedDateRange!.end.add(const Duration(days: 1))));
                                      return o.client == _selectedName && dateMatch && o.status != OrderStatus.draft;
                                    }).toList();
                                    
                                    final revenueOrderIds = revenueOrders.map((o) => o.id).toSet();
                                    
                                    // Detailed items for these revenue orders
                                    final revenueItems = allItems.where((i) => revenueOrderIds.contains(i.orderId)).toList();
                                    final revenueManual = allManualRevenues.where((r) => revenueOrderIds.contains(r.orderId)).toList();

                                    // 2. Data where this entity is the VENDOR (Expenses)
                                    // Items provided by this vendor in ANY order
                                    final expenseItems = allItems.where((i) {
                                      final order = orders.firstWhere((o) => o.id == i.orderId, orElse: () => orders.first);
                                      final dateMatch = _selectedDateRange == null ||
                                          (order.eventDate.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                                           order.eventDate.isBefore(_selectedDateRange!.end.add(const Duration(days: 1))));
                                      return i.vendor == _selectedName && dateMatch;
                                    }).toList();

                                    // Manual expenses associated with this vendor
                                    final expenseManual = allExpenses.where((e) {
                                      final dateMatch = _selectedDateRange == null ||
                                          (e.createdAt.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                                           e.createdAt.isBefore(_selectedDateRange!.end.add(const Duration(days: 1))));
                                      return e.vendorName == _selectedName && dateMatch;
                                    }).toList();

                                    if (revenueOrders.isEmpty && expenseItems.isEmpty && expenseManual.isEmpty) {
                                      return _buildEmptyState('No financial data found for this period');
                                    }

                                    // --- CALCULATIONS ---
                                    final totalRevenue = revenueOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
                                    final totalExpenses = expenseItems.fold(0.0, (sum, i) => sum + i.vendorAmount) +
                                        expenseManual.fold(0.0, (sum, e) => sum + e.amount);
                                    
                                    final netBalance = totalRevenue - totalExpenses;

                                    // Group by Order for display and filter by search query
                                    final filteredRelatedOrderIds = {
                                      ...revenueOrderIds,
                                      ...expenseItems.map((i) => i.orderId),
                                      ...expenseManual.map((e) => e.orderId),
                                    }.where((id) {
                                      if (_searchQuery.isEmpty) return true;
                                      final order = orders.firstWhere((o) => o.id == id, orElse: () => orders.first);
                                      final query = _searchQuery.toLowerCase();
                                      return order.eventName.toLowerCase().contains(query) || 
                                             order.id.toLowerCase().contains(query);
                                    }).toList();

                                    final ledgerEntries = _collectLedgerEntries(
                                      orders: orders,
                                      revenueItems: revenueItems,
                                      revenueManual: revenueManual,
                                      expenseItems: expenseItems,
                                      expenseManual: expenseManual,
                                    );

                                    final periodText = _selectedDateRange != null
                                        ? '${formatNepaliDate(_selectedDateRange!.start, "MMM dd, yyyy")} - ${formatNepaliDate(_selectedDateRange!.end, "MMM dd, yyyy")}'
                                        : 'All Time';

                                    return Column(
                                      children: [
                                        _buildNetSummaryBanner(
                                          rev: totalRevenue,
                                          exp: totalExpenses,
                                          net: netBalance,
                                          currency: currencyLabel,
                                          cs: colorScheme,
                                          onExportExcel: () => _exportLedgerToExcel(
                                            name: _selectedName!,
                                            totalRevenue: totalRevenue,
                                            totalExpenses: totalExpenses,
                                            entries: ledgerEntries,
                                          ),
                                          onExportPdf: () => _exportLedgerToPdf(
                                            name: _selectedName!,
                                            periodText: periodText,
                                            totalRevenue: totalRevenue,
                                            totalExpenses: totalExpenses,
                                            netBalance: netBalance,
                                            entries: ledgerEntries,
                                          ),
                                        ),
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          padding: const EdgeInsets.all(16),
                                          itemCount: filteredRelatedOrderIds.length,
                                          itemBuilder: (context, index) {
                                            final orderId = filteredRelatedOrderIds.elementAt(index);
                                            final order = orders.firstWhere((o) => o.id == orderId);
                                            
                                            // Revenue components for this order (only if entity is client)
                                            final isClient = order.client == _selectedName;
                                            final orderRevenueItems = isClient ? revenueItems.where((i) => i.orderId == orderId).toList() : <OrderItemEntity>[];
                                            final orderRevenueManual = isClient ? revenueManual.where((r) => r.orderId == orderId).toList() : <ExpenseEntity>[];
                                            
                                            // Expense components for this order (where entity is vendor)
                                            final orderExpenseItems = expenseItems.where((i) => i.orderId == orderId).toList();
                                            final orderExpenseManual = expenseManual.where((e) => e.orderId == orderId).toList();

                                            return _buildOrderGroup(
                                              context,
                                              order,
                                              orderRevenueItems,
                                              orderRevenueManual,
                                              orderExpenseItems,
                                              orderExpenseManual,
                                              currencyLabel,
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                  loading: () => const Center(child: CircularProgressIndicator()),
                                  error: (e, _) => Center(child: Text('Error loading manual revenue: $e')),
                                );
                              },
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (e, _) => Center(child: Text('Error loading expenses: $e')),
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Center(child: Text('Error loading items: $e')),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error loading orders: $e')),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _collectLedgerEntries({
    required List<OrderEntity> orders,
    required List<OrderItemEntity> revenueItems,
    required List<ExpenseEntity> revenueManual,
    required List<OrderItemEntity> expenseItems,
    required List<ExpenseEntity> expenseManual,
  }) {
    final List<Map<String, dynamic>> entries = [];

    for (final item in revenueItems) {
      final o = orders.firstWhere((ord) => ord.id == item.orderId, orElse: () => orders.first);
      entries.add({
        'date': o.eventDate,
        'orderId': o.id,
        'eventName': o.eventName,
        'category': 'Client Revenue',
        'description': '${item.itemName} (${item.quantity} ${item.unit})',
        'qty': item.quantity,
        'unit': item.unit,
        'days': item.days,
        'credit': item.amount,
        'debit': 0.0,
      });
    }

    for (final rev in revenueManual) {
      final o = orders.firstWhere((ord) => ord.id == rev.orderId, orElse: () => orders.first);
      entries.add({
        'date': rev.createdAt,
        'orderId': o.id,
        'eventName': o.eventName,
        'category': 'Additional Revenue',
        'description': rev.description.isNotEmpty ? rev.description : rev.category,
        'qty': rev.quantity,
        'unit': rev.unit,
        'days': rev.days,
        'credit': rev.amount,
        'debit': 0.0,
      });
    }

    for (final item in expenseItems) {
      final o = orders.firstWhere((ord) => ord.id == item.orderId, orElse: () => orders.first);
      entries.add({
        'date': o.eventDate,
        'orderId': o.id,
        'eventName': o.eventName,
        'category': 'Vendor Expense',
        'description': '${item.itemName} (${item.quantity} ${item.unit})',
        'qty': item.quantity,
        'unit': item.unit,
        'days': item.days,
        'credit': 0.0,
        'debit': item.vendorAmount,
      });
    }

    for (final exp in expenseManual) {
      entries.add({
        'date': exp.createdAt,
        'orderId': exp.orderId,
        'eventName': exp.category,
        'category': 'Manual Expense',
        'description': exp.description.isNotEmpty ? exp.description : exp.category,
        'qty': exp.quantity,
        'unit': exp.unit,
        'days': exp.days,
        'credit': 0.0,
        'debit': exp.amount,
      });
    }

    entries.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    return entries;
  }

  Future<void> _exportLedgerToExcel({
    required String name,
    required double totalRevenue,
    required double totalExpenses,
    required List<Map<String, dynamic>> entries,
  }) async {
    final headers = [
      'Date',
      'Order ID',
      'Event Name',
      'Category',
      'Description / Item',
      'Qty',
      'Unit',
      'Days',
      'Credit Revenue (NPR)',
      'Debit Expense (NPR)',
    ];

    final rows = entries.map((e) {
      final dateStr = formatNepaliDate(e['date'] as DateTime, 'yyyy-MM-dd');
      return [
        dateStr,
        e['orderId'] ?? '-',
        e['eventName'] ?? '-',
        e['category'] ?? '-',
        e['description'] ?? '-',
        e['qty'] ?? 1,
        e['unit'] ?? 'Pcs',
        e['days'] ?? 1,
        (e['credit'] as num).toDouble() > 0 ? (e['credit'] as num).toDouble() : 0.0,
        (e['debit'] as num).toDouble() > 0 ? (e['debit'] as num).toDouble() : 0.0,
      ];
    }).toList();

    rows.add([
      'TOTAL STATEMENT',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      totalRevenue,
      totalExpenses,
    ]);

    await ExcelExportHelper.exportAndShareExcel(
      context: context,
      headers: headers,
      rows: rows,
      filename: 'Ledger_${name.replaceAll(' ', '_')}.xlsx',
      sheetName: 'Ledger Statement',
      title: 'Financial Ledger Statement - $name',
    );
  }

  Future<void> _exportLedgerToPdf({
    required String name,
    required String periodText,
    required double totalRevenue,
    required double totalExpenses,
    required double netBalance,
    required List<Map<String, dynamic>> entries,
  }) async {
    final pdfBytes = await OrderPdfService.generateFinancialLedgerPdf(
      entityName: name,
      periodText: periodText,
      totalRevenue: totalRevenue,
      totalExpenses: totalExpenses,
      netBalance: netBalance,
      ledgerEntries: entries,
    );

    if (!mounted) return;

    Navigator.push(
      context,
      SlidePageRoute(
        page: PdfPreviewScreen(
          title: 'Financial Ledger - $name',
          fileName: 'Ledger_${name.replaceAll(' ', '_')}.pdf',
          pdfData: pdfBytes,
        ),
      ),
    );
  }

  Widget _buildNetSummaryBanner({
    required double rev,
    required double exp,
    required double net,
    required String currency,
    required ColorScheme cs,
    required VoidCallback onExportExcel,
    required VoidCallback onExportPdf,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryColumn('REVENUE', rev, currency, const Color(0xFF4ade80)),
              Container(width: 1, height: 40, color: cs.outline.withValues(alpha: 0.2)),
              _summaryColumn('EXPENSES', exp, currency, Colors.redAccent),
            ],
          ),
          const Divider(height: 28),
          Text(
            'NET BALANCE',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.formatWithLabel(net, currency),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: net >= 0 ? const Color(0xFF4ade80) : Colors.redAccent,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onExportExcel,
                  icon: const Icon(Icons.table_chart_outlined, size: 18, color: Colors.green),
                  label: const Text(
                    'Export Excel',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onExportPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.white),
                  label: const Text(
                    'Export PDF',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryColumn(String label, double val, String currency, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.7))),
        Text(
          CurrencyFormatter.format(val, showDecimal: false),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildOrderGroup(
    BuildContext context,
    OrderEntity order,
    List<OrderItemEntity> revItems,
    List<ExpenseEntity> revManual,
    List<OrderItemEntity> expItems,
    List<ExpenseEntity> expManual,
    String currency,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    
    final orderRevenue = (revItems.fold(0.0, (sum, i) => sum + i.amount) + 
                         revManual.fold(0.0, (sum, r) => sum + r.amount)) * (1 + order.vatRate);
    
    final orderExpense = expItems.fold(0.0, (sum, i) => sum + i.vendorAmount) +
                         expManual.fold(0.0, (sum, e) => sum + e.amount);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: ExpansionTile(
        title: Text(
          order.eventName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          'Order ID: ${order.id} | ${formatNepaliDate(order.eventDate, 'MMM dd, yyyy')}',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (orderRevenue > 0)
              Text(
                '+ ${CurrencyFormatter.format(orderRevenue, showDecimal: false)}',
                style: const TextStyle(color: Color(0xFF4ade80), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            if (orderExpense > 0)
              Text(
                '- ${CurrencyFormatter.format(orderExpense, showDecimal: false)}',
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
              ),
          ],
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          if (revItems.isNotEmpty || revManual.isNotEmpty) ...[
            _groupSubHeader('Revenue Details', const Color(0xFF4ade80)),
            ...revItems.map((i) => _itemRow(i.itemName, '${i.quantity} ${i.unit} × ${i.days} days', i.amount, false)),
            ...revManual.map((r) => _itemRow(r.category, r.description, r.amount, false)),
            const SizedBox(height: 8),
          ],
          if (expItems.isNotEmpty || expManual.isNotEmpty) ...[
            _groupSubHeader('Expense Details', Colors.redAccent),
            ...expItems.map((i) => _itemRow(i.itemName, '${i.quantity} ${i.unit} × ${i.days} days', i.vendorAmount, true)),
            ...expManual.map((e) => _itemRow(e.category, e.description, e.amount, true)),
          ],
        ],
      ),
    );
  }

  Widget _groupSubHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(width: 4, height: 14, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _itemRow(String title, String subtitle, double amount, bool isExpense) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.format(amount, showDecimal: false),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isExpense ? Colors.redAccent : const Color(0xFF4ade80)),
          ),
        ],
      ),
    );
  }
}
