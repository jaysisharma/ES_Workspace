import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/order_entity.dart';
import '../../../domain/entities/order_item_entity.dart';
import '../../../domain/entities/expense_entity.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/order_pdf_service.dart';
import '../../providers/order_providers.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/vendor_autocomplete_field.dart';
import '../../providers/vendor_provider.dart';
import 'pdf_preview_screen.dart';
import 'package:printing/printing.dart';

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
    super.dispose();
  }

  double get _itemTotalRevenue {
    double total = 0;
    for (var item in _items) {
      final rate = double.tryParse(_controllers[item.id]!.text) ?? 0.0;
      final qty = int.tryParse(_qtyControllers[item.id]?.text ?? '') ?? item.quantity;
      final days = int.tryParse(_daysControllers[item.id]?.text ?? '') ?? item.days;
      if (item.billingType == 'event') {
        total += rate * qty;
      } else {
        total += rate * qty * days;
      }
    }
    return total;
  }

  double get _manualTotalRevenue =>
      _manualRevenues.fold(0, (sum, e) => sum + e.amount);

  double get _totalRevenue => _itemTotalRevenue + _manualTotalRevenue;

  void _addRevenue(String currencyLabel) {
    _showRevenueForm(currencyLabel);
  }

  void _editRevenue(ExpenseEntity revenue, String currencyLabel) {
    _showRevenueForm(currencyLabel, revenue: revenue);
  }

  void _deleteRevenue(ExpenseEntity revenue) {
    setState(() {
      _manualRevenues.removeWhere((e) => e.id == revenue.id);
    });
  }

  void _showRevenueForm(String currencyLabel, {ExpenseEntity? revenue}) {
    final isEdit = revenue != null;
    final rateController = TextEditingController(
      text: revenue?.rate == null ? '' : revenue!.rate.toStringAsFixed(0),
    );
    final qtyController = TextEditingController(
      text: revenue?.quantity == null ? '1' : revenue!.quantity.toString(),
    );
    final daysController = TextEditingController(
      text: revenue?.days == null ? '1' : revenue!.days.toString(),
    );
    final descriptionController = TextEditingController(
      text: revenue?.description ?? '',
    );

    String category = revenue?.category ?? 'Labour';
    String billingType = revenue?.billingType ?? 'event';
    String? selectedVendorId = revenue?.vendorId;
    final vendorNameController = TextEditingController(
      text: revenue?.vendorName ?? '',
    );

    final vendors = ref.read(vendorNotifierProvider).vendors;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final colorScheme = Theme.of(context).colorScheme;
          final surfaceColor = colorScheme.surface;
          final textColor = colorScheme.onSurface;
          final labelColor = colorScheme.onSurfaceVariant;
          final inputBgColor = colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          );

          double calculateTotal() {
            final rate = double.tryParse(rateController.text) ?? 0.0;
            final qty = int.tryParse(qtyController.text) ?? 0;
            final days = int.tryParse(daysController.text) ?? 0;
            if (billingType == 'event') {
              return rate * qty;
            } else {
              return rate * qty * days;
            }
          }

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 24,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit
                        ? 'Edit Additional Revenue'
                        : 'Add Additional Revenue',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'CATEGORY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _categoryChip(
                        'Labour',
                        category == 'Labour',
                        () => setModalState(() => category = 'Labour'),
                      ),
                      const SizedBox(width: 12),
                      _categoryChip(
                        'Transportation',
                        category == 'Transportation',
                        () => setModalState(() => category = 'Transportation'),
                      ),
                      const SizedBox(width: 12),
                      _categoryChip(
                        'Other',
                        category == 'Other',
                        () => setModalState(() => category = 'Other'),
                      ),
                    ],
                  ),
                  if (category == 'Other') ...[
                    const SizedBox(height: 16),
                    Text(
                      'SPECIFY OTHER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: labelColor,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        hintText: 'Describe this revenue...',
                        filled: true,
                        fillColor: inputBgColor,
                        isDense: true,
                        contentPadding: const EdgeInsets.all(10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(color: textColor, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'BILLING TYPE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _categoryChip(
                        'Daily',
                        billingType == 'daily',
                        () => setModalState(() => billingType = 'daily'),
                      ),
                      const SizedBox(width: 12),
                      _categoryChip(
                        'Event',
                        billingType == 'event',
                        () => setModalState(() => billingType = 'event'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputCol(
                          'RATE',
                          rateController,
                          labelColor,
                          inputBgColor,
                          textColor,
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInputCol(
                          'QTY',
                          qtyController,
                          labelColor,
                          inputBgColor,
                          textColor,
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInputCol(
                          'DAYS',
                          daysController,
                          labelColor,
                          inputBgColor,
                          textColor,
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'VENDOR NAME (OPTIONAL)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  VendorAutocompleteField(
                    controller: vendorNameController,
                    hintText: 'Type or select vendor name...',
                    onSelected: (name) {
                      final v = vendors.firstWhere(
                        (v) => v.name == name,
                        orElse: () => vendors.first,
                      );
                      if (v.name == name) {
                        selectedVendorId = v.id;
                      } else {
                        selectedVendorId = null;
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Calculated Total:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$currencyLabel ${calculateTotal().toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        if (rateController.text.isEmpty) return;
                        final amount = calculateTotal();
                        if (amount <= 0) return;

                        final newRevenue = ExpenseEntity(
                          id: revenue?.id ?? const Uuid().v4(),
                          orderId: widget.order.id,
                          description: category == 'Other'
                              ? descriptionController.text.trim()
                              : '',
                          amount: amount,
                          rate: double.tryParse(rateController.text) ?? 0.0,
                          quantity: int.tryParse(qtyController.text) ?? 1,
                          days: int.tryParse(daysController.text) ?? 1,
                          billingType: billingType,
                          category: category,
                          vendorId: selectedVendorId,
                          vendorName: vendorNameController.text.trim().isEmpty
                              ? null
                              : vendorNameController.text.trim(),
                          createdAt: revenue?.createdAt ?? DateTime.now(),
                        );

                        setState(() {
                          if (isEdit) {
                            final idx = _manualRevenues.indexWhere(
                              (e) => e.id == revenue.id,
                            );
                            if (idx != -1) _manualRevenues[idx] = newRevenue;
                          } else {
                            _manualRevenues.add(newRevenue);
                          }
                        });
                        Navigator.pop(context);
                      },
                      child: Text(isEdit ? 'Update' : 'Add'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showRevenuePdfOptions() {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue PDF',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.print_outlined, color: colorScheme.primary),
              ),
              title: const Text(
                'Print / Save',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Open print dialog to save or print'),
              onTap: () {
                Navigator.pop(ctx);
                _executeRevenuePdf(share: false);
              },
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.share_outlined, color: Colors.green),
              ),
              title: const Text(
                'Share',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Share PDF via WhatsApp, email, etc.'),
              onTap: () {
                Navigator.pop(ctx);
                _executeRevenuePdf(share: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeRevenuePdf({required bool share}) async {
    String progressMessage = 'Generating Revenue Summary PDF…';
    StateSetter setSnackBarState = (_) {};

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: StatefulBuilder(
          builder: (context, setState) {
            setSnackBarState = setState;
            return Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(progressMessage)),
              ],
            );
          },
        ),
        duration: const Duration(seconds: 30),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );

    try {
      final pdfData = await OrderPdfService.generateOrderPdf(
        order: widget.order.copyWith(
          description: _orderDescriptionController.text.trim(),
        ),
        items: _items,
        additionalRevenue: _manualRevenues,
        showFinancials: true,
        onProgress: (status) {
          if (mounted) setSnackBarState(() => progressMessage = status);
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final fileName =
          'Revenue_Summary_${widget.order.id}_${widget.order.venue.replaceAll(RegExp(r'[ ,]+'), '_')}.pdf';

      if (share) {
        await Printing.sharePdf(bytes: pdfData, filename: fileName);
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(
              pdfData: pdfData,
              title: 'Revenue Summary',
              fileName: fileName,
            ),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('PDF generation error [revenue_breakdown]: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      );
    }
  }

  Future<void> _confirmFinalize(String currencyLabel) async {
    final colorScheme = Theme.of(context).colorScheme;
    final zeroRateItems = _items
        .where((i) => (double.tryParse(_controllers[i.id]!.text) ?? 0.0) == 0)
        .length;

    bool? proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        title: const Text('Finalize Revenue?'),
        content: Text(
          zeroRateItems > 0
              ? 'You have $zeroRateItems items with a rate of 0. Are you sure you want to finalize?'
              : 'This will update the total revenue to $currencyLabel ${_totalRevenue.toStringAsFixed(0)}. Do you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      _save();
    }
  }

  Future<void> _save() async {
    final updatedItems = _items.map((item) {
      final rate = double.tryParse(_controllers[item.id]!.text) ?? 0.0;
      final qty = int.tryParse(_qtyControllers[item.id]?.text ?? '') ?? item.quantity;
      final days = int.tryParse(_daysControllers[item.id]?.text ?? '') ?? item.days;
      final double amount;
      if (item.billingType == 'event') {
        amount = rate * qty;
      } else {
        amount = rate * qty * days;
      }
      return item.copyWith(
        rate: rate,
        quantity: qty,
        days: days,
        amount: amount,
      );
    }).toList();

    final totalRevenue = _totalRevenue;
    final updatedOrder = widget.order.copyWith(
      totalAmount: totalRevenue,
      description: _orderDescriptionController.text.trim(),
    );

    try {
      await ref
          .read(orderNotifierProvider.notifier)
          .finalizeRevenue(updatedOrder, updatedItems, _manualRevenues);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Revenue breakdown finalized successfully'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to finalize revenue: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.outline;

    final settings = ref.watch(settingsProvider);
    final currencyLabel = settings.currency.split(' ').first;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Revenue Breakdown',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.picture_as_pdf_outlined,
              color: colorScheme.primary,
            ),
            onPressed: _showRevenuePdfOptions,
            tooltip: 'Revenue PDF',
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: borderColor, height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader(
                  'ORDER DESCRIPTION',
                  Icons.description_outlined,
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 24),
                _buildSectionHeader('ITEMIZED REVENUE', Icons.list_alt_rounded),
                const SizedBox(height: 12),
                ..._items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildItemCard(item, index, currencyLabel),
                  );
                }),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  'ADDITIONAL REVENUE',
                  Icons.add_circle_outline_rounded,
                  onAdd: () => _addRevenue(currencyLabel),
                ),
                const SizedBox(height: 12),
                if (_manualRevenues.isEmpty)
                  _buildEmptyState('No additional revenue added')
                else
                  ..._manualRevenues.map(
                    (revenue) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildManualRevenueCard(revenue, currencyLabel),
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          _buildTotalSection(currencyLabel),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon, {
    VoidCallback? onAdd,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
            letterSpacing: 1,
          ),
        ),
        if (onAdd != null) ...[
          const Spacer(),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: colorScheme.outlineVariant,
          style: BorderStyle.none,
        ),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildInputCol(
    String label,
    TextEditingController controller,
    Color labelColor,
    Color inputBgColor,
    Color textColor, {
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: '0',
            filled: true,
            fillColor: inputBgColor,
            isDense: true,
            contentPadding: const EdgeInsets.all(10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
          ),
          style: TextStyle(color: textColor, fontSize: 13),
        ),
      ],
    );
  }

  Widget _categoryChip(String label, bool isSelected, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildManualRevenueCard(ExpenseEntity revenue, String currencyLabel) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;
    final textColor = colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${revenue.category.toUpperCase()} (${revenue.billingType.toUpperCase()})',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: labelColor,
                    ),
                    onPressed: () => _editRevenue(revenue, currencyLabel),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: Colors.red.withValues(alpha: 0.7),
                    ),
                    onPressed: () => _deleteRevenue(revenue),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            revenue.category == 'Other' && revenue.description.isNotEmpty
                ? revenue.description
                : revenue.category,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          if (revenue.vendorName != null && revenue.vendorName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 14,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Vendor: ${revenue.vendorName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Rate: $currencyLabel ${revenue.rate.toStringAsFixed(0)} | Qty: ${revenue.quantity} | Days: ${revenue.days}',
            style: TextStyle(fontSize: 12, color: labelColor),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: TextStyle(fontSize: 13, color: labelColor),
              ),
              Text(
                '$currencyLabel ${revenue.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(OrderItemEntity item, int index, String currencyLabel) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;
    final rateController = _controllers[item.id]!;
    final qtyController = _qtyControllers[item.id]!;
    final daysController = _daysControllers[item.id]!;

    final rate = double.tryParse(rateController.text) ?? 0.0;
    final qty = int.tryParse(qtyController.text) ?? item.quantity;
    final days = int.tryParse(daysController.text) ?? item.days;

    final double subtotal;
    if (item.billingType == 'event') {
      subtotal = rate * qty;
    } else {
      subtotal = rate * qty * days;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.itemName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _items[index] = item.copyWith(billingType: 'event');
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.billingType == 'event'
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Event',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: item.billingType == 'event'
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _items[index] = item.copyWith(billingType: 'daily');
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.billingType == 'daily'
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Daily',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: item.billingType == 'daily'
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (item.specification.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.specification,
              style: TextStyle(fontSize: 12, color: labelColor),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.storefront_outlined, size: 14, color: labelColor),
              const SizedBox(width: 4),
              Text(
                item.vendor.isNotEmpty ? item.vendor : 'In-House',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QTY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: labelColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.all(8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAYS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: labelColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: daysController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.all(8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RATE ($currencyLabel)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: labelColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: rateController,
                      focusNode: _focusNodes[item.id],
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.all(8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'SUBTOTAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$currencyLabel ${subtotal.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection(String currencyLabel) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;
    final borderColor = colorScheme.outline;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL REVENUE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: labelColor,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '$currencyLabel ${_totalRevenue.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => _confirmFinalize(currencyLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'Finalize Revenue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
