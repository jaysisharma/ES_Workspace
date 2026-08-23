import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/domain/entities/expense_entity.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/providers/settings_provider.dart';
import 'package:order_app/presentation/widgets/common/receipt_viewer_modal.dart';
import 'package:order_app/presentation/widgets/expense_breakdown/expense_card_widget.dart';
import 'package:order_app/presentation/widgets/expense_breakdown/expense_financials_card.dart';
import 'package:order_app/presentation/widgets/expense_breakdown/expense_form_dialog.dart';
import 'package:order_app/presentation/widgets/expense_breakdown/expense_item_costs_card.dart';
import 'package:order_app/presentation/widgets/expense_breakdown/expense_totals_card.dart';
import 'package:order_app/presentation/widgets/expense_breakdown/expense_actions_helper.dart';
import 'package:order_app/presentation/widgets/expense_breakdown/expense_breakdown_app_bar.dart';

class ExpenseBreakdownScreen extends ConsumerStatefulWidget {
  final OrderEntity order;
  final List<OrderItemEntity> items;

  const ExpenseBreakdownScreen({
    super.key,
    required this.order,
    required this.items,
  });

  @override
  ConsumerState<ExpenseBreakdownScreen> createState() =>
      _ExpenseBreakdownScreenState();
}

class _ExpenseBreakdownScreenState
    extends ConsumerState<ExpenseBreakdownScreen> {
  List<ExpenseEntity> _manualExpenses = [];
  bool _isInitialLoading = true;
  bool _includeItemsInPdf = true;
  late List<OrderItemEntity> _items;
  late Map<String, TextEditingController> _itemControllers;
  late Map<String, TextEditingController> _itemQtyControllers;
  late Map<String, TextEditingController> _itemDaysControllers;
  late TextEditingController _orderDescriptionController;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
    _itemControllers = {
      for (var item in _items)
        item.id: TextEditingController(
          text: item.vendorRate == 0 ? '' : item.vendorRate.toStringAsFixed(0),
        ),
    };
    _itemQtyControllers = {
      for (var item in _items)
        item.id: TextEditingController(text: item.quantity.toString()),
    };
    _itemDaysControllers = {
      for (var item in _items)
        item.id: TextEditingController(text: item.days.toString()),
    };
    _orderDescriptionController =
        TextEditingController(text: widget.order.description);
    _loadExpenses();
  }

  @override
  void dispose() {
    for (var controller in _itemControllers.values) {
      controller.dispose();
    }
    for (var controller in _itemQtyControllers.values) {
      controller.dispose();
    }
    for (var controller in _itemDaysControllers.values) {
      controller.dispose();
    }
    _orderDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    try {
      final expenses = await ref.read(getExpensesUseCaseProvider)(
        widget.order.id,
      );
      if (mounted) {
        setState(() {
          _manualExpenses = List<ExpenseEntity>.from(expenses);
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitialLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load expenses: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double get _itemTotalExpenses {
    double total = 0;
    for (var item in _items) {
      final rate = double.tryParse(_itemControllers[item.id]!.text) ?? 0.0;
      final qty =
          int.tryParse(_itemQtyControllers[item.id]?.text ?? '') ?? item.quantity;
      final days =
          int.tryParse(_itemDaysControllers[item.id]?.text ?? '') ?? item.days;
      if (item.billingType == 'event') {
        total += rate * qty;
      } else {
        total += rate * qty * days;
      }
    }
    return total;
  }

  double get _manualTotalExpenses =>
      _manualExpenses.fold(0, (sum, e) => sum + e.amount);

  double get _totalExpenses => _itemTotalExpenses + _manualTotalExpenses;

  void _openExpenseDialog(String currencyLabel, {ExpenseEntity? expense}) {
    ExpenseFormDialog.show(
      context,
      orderId: widget.order.id,
      currencyLabel: currencyLabel,
      expense: expense,
      onSaved: (newExpense) {
        setState(() {
          if (expense != null) {
            final idx = _manualExpenses.indexWhere((e) => e.id == expense.id);
            if (idx != -1) _manualExpenses[idx] = newExpense;
          } else {
            _manualExpenses.add(newExpense);
          }
        });
      },
    );
  }

  void _deleteExpense(ExpenseEntity expense) {
    setState(() {
      _manualExpenses.removeWhere((e) => e.id == expense.id);
    });
  }

  void _previewManualBill(ExpenseEntity expense) {
    final title = expense.billName ??
        '${expense.category} (${expense.description.isNotEmpty ? expense.description : (expense.vendorName ?? 'Expense')})';
    ReceiptViewerModal.show(
      context,
      title: title,
      url: expense.billUrl,
      path: expense.billPath,
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color primaryColor,
    Color labelColor,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: labelColor,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseCard(
    ExpenseEntity expense,
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color labelColor,
    Color primaryColor,
    String currencyLabel,
  ) {
    return ExpenseCardWidget(
      expense: expense,
      backgroundColor: surfaceColor,
      borderColor: borderColor,
      textColor: textColor,
      labelColor: labelColor,
      primaryColor: primaryColor,
      currencyLabel: currencyLabel,
      onEdit: () => _openExpenseDialog(currencyLabel, expense: expense),
      onDelete: () => _deleteExpense(expense),
      onPreviewBill: () => _previewManualBill(expense),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    final bgColor = colorScheme.surface;
    final surfaceColor = colorScheme.surface;
    final borderColor = colorScheme.outline;
    final textColor = colorScheme.onSurface;
    final labelColor = colorScheme.onSurfaceVariant;
    final settings = ref.watch(settingsProvider);
    final currencyLabel = settings.currency.split(' ').first;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: ExpenseBreakdownAppBarWidget(
        bgColor: bgColor,
        textColor: textColor,
        borderColor: borderColor,
        primaryColor: primaryColor,
        onExportExcel: () => ExpenseActionsHelper.generateExpenseExcel(
          context: context,
          order: widget.order,
          items: _items,
          itemControllers: _itemControllers,
          manualExpenses: _manualExpenses,
        ),
        onPdfOptions: () => ExpenseActionsHelper.showPdfOptions(
          context,
          includeItems: _includeItemsInPdf,
          onIncludeItemsChanged: (val) =>
              setState(() => _includeItemsInPdf = val),
          onPrintOrSave: () => ExpenseActionsHelper.executeExpensePdf(
            context: context,
            order: widget.order,
            orderDescription: _orderDescriptionController.text,
            items: _items,
            itemControllers: _itemControllers,
            manualExpenses: _manualExpenses,
            share: false,
            includeItems: _includeItemsInPdf,
          ),
          onShare: () => ExpenseActionsHelper.executeExpensePdf(
            context: context,
            order: widget.order,
            orderDescription: _orderDescriptionController.text,
            items: _items,
            itemControllers: _itemControllers,
            manualExpenses: _manualExpenses,
            share: true,
            includeItems: _includeItemsInPdf,
          ),
        ),
      ),
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;

                final itemsListContent = [
                  _buildSectionHeader(
                    'ORDER DESCRIPTION',
                    Icons.description_outlined,
                    primaryColor,
                    labelColor,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _orderDescriptionController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Add overall order notes...',
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.3,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ExpenseItemCostsCardWidget(
                    orderId: widget.order.id,
                    items: _items,
                    itemControllers: _itemControllers,
                    itemQtyControllers: _itemQtyControllers,
                    itemDaysControllers: _itemDaysControllers,
                    backgroundColor: surfaceColor,
                    borderColor: borderColor,
                    textColor: textColor,
                    labelColor: labelColor,
                    primaryColor: primaryColor,
                    currencyLabel: currencyLabel,
                    onBillingTypeChanged: (idx, type) {
                      setState(() {
                        _items[idx] = _items[idx].copyWith(billingType: type);
                      });
                    },
                    onItemBillChanged: (idx, billData) {
                      setState(() {
                        _items[idx] = _items[idx].copyWith(
                          vendorBillUrl: billData.url,
                          vendorBillPath: billData.path,
                          vendorBillName: billData.name,
                          clearVendorBill: billData.url == null,
                        );
                      });
                    },
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ADDITIONAL EXPENSES',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: labelColor,
                          letterSpacing: 1,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _openExpenseDialog(currencyLabel),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Manual'),
                        style: TextButton.styleFrom(
                          foregroundColor: primaryColor,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_manualExpenses.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 44,
                              color: labelColor.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No manual expenses recorded',
                              style: TextStyle(
                                color: labelColor,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._manualExpenses.map(
                      (expense) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildExpenseCard(
                          expense,
                          surfaceColor,
                          borderColor,
                          textColor,
                          labelColor,
                          primaryColor,
                          currencyLabel,
                        ),
                      ),
                    ),
                ];

                final financialsWidget = ExpenseFinancialsCardWidget(
                  itemTotalExpenses: _itemTotalExpenses,
                  manualTotalExpenses: _manualTotalExpenses,
                  totalExpenses: _totalExpenses,
                  currencyLabel: currencyLabel,
                  onPreviewPdf: () => ExpenseActionsHelper.executeExpensePdf(
                    context: context,
                    order: widget.order,
                    orderDescription: _orderDescriptionController.text,
                    items: _items,
                    itemControllers: _itemControllers,
                    manualExpenses: _manualExpenses,
                    share: false,
                    includeItems: _includeItemsInPdf,
                  ),
                  onFinalize: () => ExpenseActionsHelper.finalizeExpenses(
                    context: context,
                    ref: ref,
                    order: widget.order,
                    orderDescription: _orderDescriptionController.text,
                    totalExpenses: _totalExpenses,
                    currencyLabel: currencyLabel,
                    items: _items,
                    itemControllers: _itemControllers,
                    itemQtyControllers: _itemQtyControllers,
                    itemDaysControllers: _itemDaysControllers,
                    manualExpenses: _manualExpenses,
                  ),
                );

                return Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 1380 : 860,
                          ),
                          child: isDesktop
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left Column: Items & Expenses
                                    Expanded(
                                      flex: 6,
                                      child: ListView(
                                        padding: const EdgeInsets.all(16),
                                        children: itemsListContent,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Right Column: Summary & Actions
                                    Expanded(
                                      flex: 4,
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.fromLTRB(
                                          0,
                                          16,
                                          16,
                                          24,
                                        ),
                                        child: financialsWidget,
                                      ),
                                    ),
                                  ],
                                )
                              : ListView(
                                  padding: const EdgeInsets.all(16),
                                  children: itemsListContent,
                                ),
                        ),
                      ),
                    ),
                    if (!isDesktop)
                      ExpenseTotalsCardWidget(
                        manualTotalExpenses: _manualTotalExpenses,
                        itemTotalExpenses: _itemTotalExpenses,
                        totalExpenses: _totalExpenses,
                        currencyLabel: currencyLabel,
                        onPreviewPdf: () =>
                            ExpenseActionsHelper.executeExpensePdf(
                          context: context,
                          order: widget.order,
                          orderDescription: _orderDescriptionController.text,
                          items: _items,
                          itemControllers: _itemControllers,
                          manualExpenses: _manualExpenses,
                          share: false,
                          includeItems: _includeItemsInPdf,
                        ),
                        onFinalize: () => ExpenseActionsHelper.finalizeExpenses(
                          context: context,
                          ref: ref,
                          order: widget.order,
                          orderDescription: _orderDescriptionController.text,
                          totalExpenses: _totalExpenses,
                          currencyLabel: currencyLabel,
                          items: _items,
                          itemControllers: _itemControllers,
                          itemQtyControllers: _itemQtyControllers,
                          itemDaysControllers: _itemDaysControllers,
                          manualExpenses: _manualExpenses,
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
