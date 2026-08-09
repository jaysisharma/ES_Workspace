import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/domain/entities/expense_entity.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/providers/settings_provider.dart';
import 'package:order_app/presentation/widgets/revenue_breakdown/revenue_form_dialog.dart';
import 'package:order_app/presentation/widgets/revenue_breakdown/revenue_financials_card.dart';
import 'package:order_app/presentation/widgets/revenue_breakdown/revenue_totals_card.dart';
import 'package:order_app/presentation/widgets/revenue_breakdown/revenue_description_card.dart';
import 'package:order_app/presentation/widgets/revenue_breakdown/revenue_items_section.dart';
import 'package:order_app/presentation/widgets/revenue_breakdown/manual_revenue_section.dart';
import 'package:order_app/presentation/widgets/revenue_breakdown/revenue_calculations.dart';
import 'package:order_app/presentation/widgets/revenue_breakdown/revenue_actions_helper.dart';
import 'package:order_app/presentation/widgets/revenue_breakdown/revenue_breakdown_app_bar.dart';

class RevenueBreakdownScreen extends ConsumerStatefulWidget {
  final OrderEntity order;
  final List<OrderItemEntity> items;

  const RevenueBreakdownScreen({
    super.key,
    required this.order,
    required this.items,
  });

  @override
  ConsumerState<RevenueBreakdownScreen> createState() =>
      _RevenueBreakdownScreenState();
}

class _RevenueBreakdownScreenState
    extends ConsumerState<RevenueBreakdownScreen> {
  late Map<String, TextEditingController> _controllers;
  late Map<String, TextEditingController> _qtyControllers;
  late Map<String, TextEditingController> _daysControllers;
  late Map<String, FocusNode> _focusNodes;
  late List<OrderItemEntity> _items;
  late TextEditingController _orderDescriptionController;
  late TextEditingController _mgtChargeController;
  late TextEditingController _discountController;
  late TextEditingController _vatRateController;
  late TextEditingController _advanceReceivedController;
  late TextEditingController _advanceRefNoController;
  late VatOption _vatOption;
  bool _isMgtChargePercent = true;
  bool _isDiscountPercent = true;
  final List<ExpenseEntity> _manualRevenues = [];

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
    _controllers = {
      for (var item in _items)
        item.id: TextEditingController(
          text: item.rate == 0 ? '' : item.rate.toStringAsFixed(0),
        ),
    };
    _qtyControllers = {
      for (var item in _items)
        item.id: TextEditingController(text: item.quantity.toString()),
    };
    _daysControllers = {
      for (var item in _items)
        item.id: TextEditingController(text: item.days.toString()),
    };
    _focusNodes = {for (var item in _items) item.id: FocusNode()};
    _orderDescriptionController = TextEditingController(
      text: widget.order.description,
    );
    _isMgtChargePercent = widget.order.isMgtChargePercent;
    _isDiscountPercent = widget.order.isDiscountPercent;

    final mgtVal = widget.order.managementCharge;
    _mgtChargeController = TextEditingController(
      text: mgtVal == 0
          ? ''
          : (mgtVal.truncateToDouble() == mgtVal
              ? mgtVal.toStringAsFixed(0)
              : mgtVal.toStringAsFixed(2)),
    );

    final discVal = widget.order.discount;
    _discountController = TextEditingController(
      text: discVal == 0
          ? ''
          : (discVal.truncateToDouble() == discVal
              ? discVal.toStringAsFixed(0)
              : discVal.toStringAsFixed(2)),
    );

    _advanceReceivedController = TextEditingController(
      text: widget.order.advanceReceived == 0
          ? ''
          : widget.order.advanceReceived.toStringAsFixed(0),
    );
    _advanceRefNoController = TextEditingController(
      text: widget.order.advanceReferenceNo,
    );

    if (widget.order.vatRate == 0) {
      _vatOption = VatOption.noVat;
      _vatRateController = TextEditingController(text: '0');
    } else if ((widget.order.vatRate - 0.13).abs() < 0.001) {
      _vatOption = VatOption.vat13;
      _vatRateController = TextEditingController(text: '13');
    } else {
      _vatOption = VatOption.custom;
      _vatRateController = TextEditingController(
        text: (widget.order.vatRate * 100).toStringAsFixed(0),
      );
    }
    _loadAdditionalRevenue();
  }

  Future<void> _loadAdditionalRevenue() async {
    try {
      final revenues = await ref.read(getAdditionalRevenueUseCaseProvider)(
        widget.order.id,
      );
      if (mounted) {
        setState(() {
          _manualRevenues.clear();
          _manualRevenues.addAll(revenues);
        });
      }
    } catch (e) {
      debugPrint('Error loading additional revenue: $e');
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    for (var controller in _qtyControllers.values) {
      controller.dispose();
    }
    for (var controller in _daysControllers.values) {
      controller.dispose();
    }
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    _orderDescriptionController.dispose();
    _mgtChargeController.dispose();
    _discountController.dispose();
    _advanceReceivedController.dispose();
    _advanceRefNoController.dispose();
    _vatRateController.dispose();
    super.dispose();
  }

  double get _itemTotalRevenue => RevenueCalculations.calculateItemTotal(
        items: _items,
        itemControllers: _controllers,
        itemQtyControllers: _qtyControllers,
        itemDaysControllers: _daysControllers,
      );

  double get _manualTotalRevenue =>
      RevenueCalculations.calculateManualTotal(_manualRevenues);

  double get _totalRevenue => _itemTotalRevenue + _manualTotalRevenue;

  double get _managementChargeRate {
    final val = double.tryParse(_mgtChargeController.text.trim()) ?? 0.0;
    return _isMgtChargePercent ? val : 0.0;
  }

  double get _managementChargeAmount =>
      RevenueCalculations.calculateManagementChargeAmount(
        totalRevenue: _totalRevenue,
        mgtChargeText: _mgtChargeController.text,
        isPercent: _isMgtChargePercent,
      );

  double get _discountRate {
    final val = double.tryParse(_discountController.text.trim()) ?? 0.0;
    return _isDiscountPercent ? val : 0.0;
  }

  double get _discountAmount => RevenueCalculations.calculateDiscountAmount(
        totalRevenue: _totalRevenue,
        discountText: _discountController.text,
        isPercent: _isDiscountPercent,
      );

  double get _netTotalRevenue => RevenueCalculations.calculateNetTotal(
        totalRevenue: _totalRevenue,
        mgtChargeAmount: _managementChargeAmount,
        discountAmount: _discountAmount,
      );

  double get _effectiveVatRate => RevenueCalculations.calculateEffectiveVatRate(
        vatOption: _vatOption,
        customVatText: _vatRateController.text,
      );

  double get _vatAmount => RevenueCalculations.calculateVatAmount(
        netTotal: _netTotalRevenue,
        effectiveVatRate: _effectiveVatRate,
      );

  double get _grandTotalRevenue => RevenueCalculations.calculateGrandTotal(
        netTotal: _netTotalRevenue,
        vatAmount: _vatAmount,
      );

  void _openRevenueDialog(String currencyLabel, {ExpenseEntity? revenue}) {
    RevenueFormDialog.show(
      context,
      orderId: widget.order.id,
      currencyLabel: currencyLabel,
      revenue: revenue,
      onSaved: (newRevenue) {
        setState(() {
          if (revenue != null) {
            final idx = _manualRevenues.indexWhere((e) => e.id == revenue.id);
            if (idx != -1) _manualRevenues[idx] = newRevenue;
          } else {
            _manualRevenues.add(newRevenue);
          }
        });
      },
    );
  }

  void _deleteRevenue(ExpenseEntity revenue) {
    setState(() {
      _manualRevenues.removeWhere((e) => e.id == revenue.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    final bgColor = colorScheme.surface;
    final borderColor = colorScheme.outline;
    final textColor = colorScheme.onSurface;
    final labelColor = colorScheme.onSurfaceVariant;
    final settings = ref.watch(settingsProvider);
    final currencyLabel = settings.currency.split(' ').first;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: RevenueBreakdownAppBarWidget(
        bgColor: bgColor,
        textColor: textColor,
        borderColor: borderColor,
        primaryColor: primaryColor,
        onSave: () async {
          final savedItems = await RevenueActionsHelper.save(
            context: context,
            ref: ref,
            order: widget.order,
            orderDescription: _orderDescriptionController.text,
            items: _items,
            itemControllers: _controllers,
            itemQtyControllers: _qtyControllers,
            itemDaysControllers: _daysControllers,
            manualRevenues: _manualRevenues,
            totalRevenue: _totalRevenue,
            effectiveVatRate: _effectiveVatRate,
            managementCharge: double.tryParse(_mgtChargeController.text.trim()) ?? 0.0,
            isMgtChargePercent: _isMgtChargePercent,
            discount: double.tryParse(_discountController.text.trim()) ?? 0.0,
            isDiscountPercent: _isDiscountPercent,
            advanceReceived: double.tryParse(_advanceReceivedController.text.trim()) ?? 0.0,
            advanceReferenceNo: _advanceRefNoController.text.trim(),
          );
          if (savedItems != null && mounted) {
            setState(() {
              _items = savedItems;
            });
          }
        },
        onPdf: () => RevenueActionsHelper.executeRevenuePdf(
          context: context,
          order: widget.order,
          orderDescription: _orderDescriptionController.text,
          items: _items,
          itemControllers: _controllers,
          itemQtyControllers: _qtyControllers,
          itemDaysControllers: _daysControllers,
          manualRevenues: _manualRevenues,
          managementChargeAmount: _managementChargeAmount,
          managementChargeRate: _managementChargeRate,
          discountAmount: _discountAmount,
          discountRate: _discountRate,
          effectiveVatRate: _effectiveVatRate,
          share: false,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                RevenueDescriptionCardWidget(
                  controller: _orderDescriptionController,
                  primaryColor: primaryColor,
                  labelColor: labelColor,
                  borderColor: borderColor,
                  containerBgColor: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                ),
                const SizedBox(height: 24),
                RevenueItemsSectionWidget(
                  items: _items,
                  itemControllers: _controllers,
                  itemQtyControllers: _qtyControllers,
                  itemDaysControllers: _daysControllers,
                  focusNodes: _focusNodes,
                  primaryColor: primaryColor,
                  labelColor: labelColor,
                  currencyLabel: currencyLabel,
                  onBillingTypeChanged: (idx, type) {
                    setState(() {
                      _items[idx] = _items[idx].copyWith(billingType: type);
                    });
                  },
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 24),
                ManualRevenueSectionWidget(
                  manualRevenues: _manualRevenues,
                  primaryColor: primaryColor,
                  labelColor: labelColor,
                  currencyLabel: currencyLabel,
                  onAddManual: () => _openRevenueDialog(currencyLabel),
                  onEdit: (revenue) => _openRevenueDialog(currencyLabel, revenue: revenue),
                  onDelete: (revenue) => _deleteRevenue(revenue),
                ),
                const SizedBox(height: 24),
                RevenueFinancialsCardWidget(
                  mgtChargeController: _mgtChargeController,
                  discountController: _discountController,
                  vatRateController: _vatRateController,
                  advanceReceivedController: _advanceReceivedController,
                  advanceRefNoController: _advanceRefNoController,
                  isMgtChargePercent: _isMgtChargePercent,
                  isDiscountPercent: _isDiscountPercent,
                  vatOption: _vatOption,
                  totalRevenue: _totalRevenue,
                  managementChargeAmount: _managementChargeAmount,
                  discountAmount: _discountAmount,
                  netTotalRevenue: _netTotalRevenue,
                  vatAmount: _vatAmount,
                  effectiveVatRate: _effectiveVatRate,
                  grandTotalRevenue: _grandTotalRevenue,
                  currencyLabel: currencyLabel,
                  onMgtChargePercentChanged: (val) => setState(() => _isMgtChargePercent = val),
                  onDiscountPercentChanged: (val) => setState(() => _isDiscountPercent = val),
                  onVatOptionChanged: (opt) {
                    setState(() {
                      _vatOption = opt;
                      if (opt == VatOption.noVat) {
                        _vatRateController.text = '0';
                      } else if (opt == VatOption.vat13) {
                        _vatRateController.text = '13';
                      }
                    });
                  },
                  onChanged: () => setState(() {}),
                  onPreviewPdf: () => RevenueActionsHelper.executeRevenuePdf(
                    context: context,
                    order: widget.order,
                    orderDescription: _orderDescriptionController.text,
                    items: _items,
                    itemControllers: _controllers,
                    itemQtyControllers: _qtyControllers,
                    itemDaysControllers: _daysControllers,
                    manualRevenues: _manualRevenues,
                    managementChargeAmount: _managementChargeAmount,
                    managementChargeRate: _managementChargeRate,
                    discountAmount: _discountAmount,
                    discountRate: _discountRate,
                    effectiveVatRate: _effectiveVatRate,
                    share: false,
                  ),
                  onSharePdf: () => RevenueActionsHelper.executeRevenuePdf(
                    context: context,
                    order: widget.order,
                    orderDescription: _orderDescriptionController.text,
                    items: _items,
                    itemControllers: _controllers,
                    itemQtyControllers: _qtyControllers,
                    itemDaysControllers: _daysControllers,
                    manualRevenues: _manualRevenues,
                    managementChargeAmount: _managementChargeAmount,
                    managementChargeRate: _managementChargeRate,
                    discountAmount: _discountAmount,
                    discountRate: _discountRate,
                    effectiveVatRate: _effectiveVatRate,
                    share: true,
                  ),
                ),
              ],
            ),
          ),
          RevenueTotalsCardWidget(
            hasItemsOrRevenues: _items.isNotEmpty || _manualRevenues.isNotEmpty,
            grandTotalRevenue: _grandTotalRevenue,
            currencyLabel: currencyLabel,
            onFinalize: () => RevenueActionsHelper.confirmFinalize(
              context: context,
              ref: ref,
              order: widget.order,
              orderDescription: _orderDescriptionController.text,
              items: _items,
              itemControllers: _controllers,
              itemQtyControllers: _qtyControllers,
              itemDaysControllers: _daysControllers,
              manualRevenues: _manualRevenues,
              totalRevenue: _totalRevenue,
              grandTotalRevenue: _grandTotalRevenue,
              effectiveVatRate: _effectiveVatRate,
              managementCharge: double.tryParse(_mgtChargeController.text.trim()) ?? 0.0,
              isMgtChargePercent: _isMgtChargePercent,
              discount: double.tryParse(_discountController.text.trim()) ?? 0.0,
              isDiscountPercent: _isDiscountPercent,
              advanceReceived: double.tryParse(_advanceReceivedController.text.trim()) ?? 0.0,
              advanceReferenceNo: _advanceRefNoController.text.trim(),
              currencyLabel: currencyLabel,
            ),
          ),
        ],
      ),
    );
  }
}
