import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/nepali_date_formatter.dart';
import '../../../core/utils/excel_export_helper.dart';
import '../../../core/services/order_pdf_service.dart';
import '../../../domain/entities/order_entity.dart';
import '../../../domain/entities/order_item_entity.dart';
import '../../../domain/entities/expense_entity.dart';
import '../../providers/order_providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/purchase_order_providers.dart';
import '../../widgets/revenue_summary/billing_type_section.dart';
import '../../widgets/revenue_summary/bottom_action_bar.dart';
import '../../widgets/revenue_summary/client_revenue_section.dart';
import '../../widgets/revenue_summary/financial_perspective_toggle.dart';
import '../../widgets/revenue_summary/order_drilldown_section.dart';
import '../../widgets/revenue_summary/profit_summary_card.dart';
import '../../widgets/revenue_summary/vendor_expenses_section.dart';
import 'pdf_preview_screen.dart';

enum FinancialViewMode { revenue, expenses, both }

class RevenueSummaryScreen extends ConsumerStatefulWidget {
  final String? orderId;
  const RevenueSummaryScreen({super.key, this.orderId});

  @override
  ConsumerState<RevenueSummaryScreen> createState() =>
      _RevenueSummaryScreenState();
}

class _RevenueSummaryScreenState extends ConsumerState<RevenueSummaryScreen> {
  String _billingType = 'Multi-Day Event';
  DateTime _filterDate = DateTime.now();
  bool _includeDrafts = false;
  FinancialViewMode _viewType = FinancialViewMode.both;

  // Per-item editable rate controllers, keyed by order-item id
  final Map<String, TextEditingController> _rateControllers = {};

  @override
  void dispose() {
    for (final c in _rateControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;
    final borderColor = colorScheme.outline;

    final ordersAsync = ref.watch(ordersStreamProvider);
    final allItemsAsync = ref.watch(allItemsStreamProvider);
    final allAdditionalRevenueAsync = ref.watch(allAdditionalRevenueStreamProvider);
    final purchaseOrdersAsync = ref.watch(purchaseOrdersStreamProvider);
    
    final settings = ref.watch(settingsProvider);
    final currencyLabel = settings.currency.split(' ').first;

    return ordersAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (ordersRaw) {
        final orders = ordersRaw.cast<OrderEntity>();
        return allItemsAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
          data: (allItemsRaw) {
            return allAdditionalRevenueAsync.when(
              loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
              error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
              data: (allAdditionalRevenuesRaw) {
                return purchaseOrdersAsync.when(
                  loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
                  error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
                  data: (purchaseOrdersRaw) {
                    final filteredOrders = orders.where((o) {
                      final dateMatch =
                          o.eventDate.year == _filterDate.year &&
                          o.eventDate.month == _filterDate.month;
                      final statusMatch =
                          _includeDrafts || o.status != OrderStatus.draft;
                      return dateMatch && statusMatch;
                    }).toList();

                    final filteredOrderIds = filteredOrders.map((o) => o.id).toSet();

                    final allItems = widget.orderId != null
                        ? allItemsRaw
                            .where((i) => i.orderId == widget.orderId)
                            .toList()
                        : allItemsRaw
                            .where((i) => filteredOrderIds.contains(i.orderId))
                            .toList();

                    final allManualRevenues = widget.orderId != null
                        ? allAdditionalRevenuesRaw
                            .where((r) => r.orderId == widget.orderId)
                            .toList()
                        : allAdditionalRevenuesRaw
                            .where((r) => filteredOrderIds.contains(r.orderId))
                            .toList();

                    // Populate rate controllers if they don't exist
                    for (var item in allItems) {
                      _rateControllers.putIfAbsent(
                        item.id,
                        () => TextEditingController(
                          text: item.rate.toStringAsFixed(0),
                        ),
                      );
                    }

                    // Group data by order
                    final Map<String, List<OrderItemEntity>> itemsByOrder = {};
                    for (var item in allItems) {
                      itemsByOrder.putIfAbsent(item.orderId, () => []).add(item);
                    }
                    final Map<String, List<ExpenseEntity>> manualRevByOrder = {};
                    for (var rev in allManualRevenues) {
                      manualRevByOrder.putIfAbsent(rev.orderId, () => []).add(rev);
                    }

                    double currentTotalRevenue = 0;
                    for (var order in filteredOrders) {
                      double orderSubtotal = 0;
                      final orderItems = itemsByOrder[order.id] ?? [];
                      for (var item in orderItems) {
                        final rate = double.tryParse(_rateControllers[item.id]?.text ?? '') ?? item.rate;
                        if (item.billingType == 'event') {
                          orderSubtotal += rate * item.quantity;
                        } else {
                          orderSubtotal += rate * item.quantity * item.days;
                        }
                      }
                      
                      final orderManualRevs = manualRevByOrder[order.id] ?? [];
                      for (var rev in orderManualRevs) {
                        orderSubtotal += rev.amount;
                      }

                      currentTotalRevenue += orderSubtotal * (1 + order.vatRate);
                    }

                    final totalExpenses = purchaseOrdersRaw
                        .where((po) => filteredOrderIds.contains(po.orderId))
                        .fold(0.0, (s, po) => s + po.totalWithVat);

                    final netProfit = currentTotalRevenue - totalExpenses;
                    final margin = currentTotalRevenue > 0
                        ? (netProfit / currentTotalRevenue * 100)
                        : 0.0;

                    final maxDays = allItems.isEmpty
                        ? 0
                        : allItems.map((i) => i.days).reduce((a, b) => a > b ? a : b);

                    return Scaffold(
                      backgroundColor: colorScheme.surface,
                      appBar: PreferredSize(
                        preferredSize: const Size.fromHeight(60),
                        child: Container(
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.95),
                            border: Border(
                              bottom: BorderSide(
                                color: borderColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Revenue & Financials',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      body: Stack(
                        children: [
                          SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                              vertical: 24.0,
                            ).copyWith(bottom: 120),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildDateFilter(),
                                const SizedBox(height: 24),
                                BillingTypeSection(
                                  billingType: _billingType,
                                  onBillingTypeChanged: (val) => setState(() => _billingType = val),
                                  maxDays: maxDays,
                                  includeDrafts: _includeDrafts,
                                  onIncludeDraftsChanged: (val) => setState(() => _includeDrafts = val),
                                ),
                                const SizedBox(height: 32),
                                FinancialPerspectiveToggle(
                                  viewType: _viewType,
                                  onChanged: (val) => setState(() => _viewType = val),
                                ),
                                const SizedBox(height: 32),
                                if (_viewType == FinancialViewMode.revenue ||
                                    _viewType == FinancialViewMode.both) ...[
                                  ClientRevenueSection(
                                    allItems: allItems,
                                    rateControllers: _rateControllers,
                                    currencyLabel: currencyLabel,
                                    currentTotalRevenue: currentTotalRevenue,
                                    totalExpenses: totalExpenses,
                                    grandTotal: currentTotalRevenue,
                                    onRateChanged: () => setState(() {}),
                                  ),
                                  const SizedBox(height: 32),
                                ],
                                if (_viewType == FinancialViewMode.expenses ||
                                    _viewType == FinancialViewMode.both) ...[
                                  VendorExpensesSection(
                                    allItems: allItems,
                                    filteredOrders: filteredOrders,
                                    totalExpenses: totalExpenses,
                                    currencyLabel: currencyLabel,
                                  ),
                                  const SizedBox(height: 32),
                                ],
                                ProfitSummaryCard(
                                  netProfit: netProfit,
                                  margin: margin,
                                  currentTotalRevenue: currentTotalRevenue,
                                  totalExpenses: totalExpenses,
                                  currencyLabel: currencyLabel,
                                ),
                                const SizedBox(height: 32),
                                Row(
                                  children: [
                                    Icon(Icons.list_alt, color: colorScheme.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'ORDER BREAKDOWN',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: labelColor,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${filteredOrders.length} Events',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ...filteredOrders.map(
                                  (order) => OrderDrilldownSection(
                                    order: order,
                                    allItems: allItems,
                                    rateControllers: _rateControllers,
                                    currencyLabel: currencyLabel,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          BottomActionBar(
                            onSave: () => _saveAllData(orders),
                            onExport: () => _showExportOptions(orders),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _saveAllData(List<OrderEntity> orders) async {
    final colorScheme = Theme.of(context).colorScheme;
    final itemsList = ref.read(allItemsStreamProvider).value ?? [];

    final Map<String, List<OrderItemEntity>> orderUpdates = {};
    for (var item in itemsList) {
      final controllerText = _rateControllers[item.id]?.text ?? '';
      final rate = double.tryParse(controllerText) ?? item.rate;
      if (rate != item.rate) {
        final double amount;
        if (item.billingType == 'event') {
          amount = rate * item.quantity;
        } else {
          amount = rate * item.quantity * item.days;
        }
        final updatedItem = item.copyWith(rate: rate, amount: amount);
        orderUpdates.putIfAbsent(item.orderId, () => []).add(updatedItem);
      }
    }

    if (orderUpdates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No changes to save')));
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final orderNotifier = ref.read(orderNotifierProvider.notifier);

      for (var entry in orderUpdates.entries) {
        final orderId = entry.key;
        final itemsToUpdate = entry.value;
        final order = orders.firstWhere((o) => o.id == orderId);

        final allItemsOfOrder = await ref.read(getOrderItemsUseCaseProvider)(orderId);
        final additionalRevenue = await ref.read(getAdditionalRevenueUseCaseProvider)(orderId);

        double newSubtotal = 0;
        final finalItems = <OrderItemEntity>[];

        for (var existingItem in allItemsOfOrder) {
          final updated = itemsToUpdate.firstWhere(
            (u) => u.id == existingItem.id,
            orElse: () => existingItem,
          );
          finalItems.add(updated);
          if (updated.billingType == 'event') {
            newSubtotal += updated.rate * updated.quantity;
          } else {
            newSubtotal += updated.rate * updated.quantity * updated.days;
          }
        }

        for (var rev in additionalRevenue) {
          newSubtotal += rev.amount;
        }

        final updatedOrder = order.copyWith(totalAmount: newSubtotal * (1 + order.vatRate));
        await orderNotifier.finalizeRevenue(updatedOrder, finalItems, additionalRevenue);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Revenue data saved successfully'),
            backgroundColor: colorScheme.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showExportOptions(List<OrderEntity> orders) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Export Financial Data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined, color: Colors.green),
              title: const Text('Export as Excel'),
              onTap: () {
                Navigator.pop(context);
                _exportExcel(orders);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Export as Summary PDF'),
              onTap: () {
                Navigator.pop(context);
                _generateGlobalPDF(orders);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportExcel(List<OrderEntity> orders) async {
    final itemsList = ref.read(allItemsStreamProvider).value ?? [];
    final headers = [
      'Order ID',
      'Event Name',
      'Item Name',
      'Quantity',
      'Unit',
      'Days',
      'Rate (NPR)',
      'Amount (NPR)',
      'Vendor',
      'Vendor Amount (NPR)',
    ];

    final rows = itemsList.map((item) {
      final order = orders.firstWhere(
        (o) => o.id == item.orderId,
        orElse: () => orders.first,
      );
      return [
        item.orderId,
        order.eventName,
        item.itemName,
        item.quantity,
        item.unit,
        item.days,
        item.rate,
        item.amount,
        item.vendor,
        item.vendorAmount,
      ];
    }).toList();

    final fileName = 'Revenue_Financials_Export_${formatNepaliDate(DateTime.now(), "yyyyMMdd")}.xlsx';

    await ExcelExportHelper.exportAndShareExcel(
      context: context,
      headers: headers,
      rows: rows,
      filename: fileName,
      sheetName: 'Financials',
      title: 'Revenue & Financials Report',
    );
  }

  Future<void> _generateGlobalPDF(List<OrderEntity> orders) async {
    try {
      final itemsList = ref.read(allItemsStreamProvider).value ?? [];
      final manualRevenuesList = ref.read(allAdditionalRevenueStreamProvider).value ?? [];

      double currentTotalRevenue = 0;
      final purchaseOrders = ref.read(purchaseOrdersStreamProvider).value ?? [];

      final Map<String, List<OrderItemEntity>> itemsByOrder = {};
      for (var item in itemsList) {
        itemsByOrder.putIfAbsent(item.orderId, () => []).add(item);
      }

      final Map<String, List<ExpenseEntity>> manualRevByOrder = {};
      for (var rev in manualRevenuesList) {
        manualRevByOrder.putIfAbsent(rev.orderId, () => []).add(rev);
      }

      for (var order in orders) {
        double orderSubtotal = 0;
        final orderItems = itemsByOrder[order.id] ?? [];
        for (var item in orderItems) {
          final rate = double.tryParse(_rateControllers[item.id]?.text ?? '') ?? item.rate;
          if (item.billingType == 'event') {
            orderSubtotal += rate * item.quantity;
          } else {
            orderSubtotal += rate * item.quantity * item.days;
          }
        }

        final orderManualRevs = manualRevByOrder[order.id] ?? [];
        for (var rev in orderManualRevs) {
          orderSubtotal += rev.amount;
        }

        currentTotalRevenue += orderSubtotal * (1 + order.vatRate);
      }

      final totalExpenses = purchaseOrders.fold(0.0, (s, po) => s + po.totalWithVat);
      final netProfit = currentTotalRevenue - totalExpenses;
      final margin = currentTotalRevenue > 0 ? (netProfit / currentTotalRevenue * 100) : 0.0;

      final pdfData = await OrderPdfService.generateGlobalFinancialPdf(
        orders: orders,
        totalRevenue: currentTotalRevenue,
        totalExpenses: totalExpenses,
        netProfit: netProfit,
        margin: margin,
      );

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            pdfData: pdfData,
            title: 'Financial Report PDF',
            fileName: 'financial_summary_${DateTime.now().millisecondsSinceEpoch}.pdf',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildDateFilter() {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;
    final borderColor = colorScheme.outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: colorScheme.onSurface),
            onPressed: () {
              setState(() {
                _filterDate = DateTime(_filterDate.year, _filterDate.month - 1);
              });
            },
          ),
          Column(
            children: [
              Text(
                formatNepaliDate(_filterDate, 'MMMM yyyy'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                'Financial Period',
                style: TextStyle(fontSize: 10, color: labelColor),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: colorScheme.onSurface),
            onPressed: () {
              setState(() {
                _filterDate = DateTime(_filterDate.year, _filterDate.month + 1);
              });
            },
          ),
        ],
      ),
    );
  }
}
