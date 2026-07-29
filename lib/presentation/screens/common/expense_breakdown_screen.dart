import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/excel_export_helper.dart';
import '../../../core/services/order_pdf_service.dart';
import '../../../domain/entities/order_entity.dart';
import '../../../domain/entities/order_item_entity.dart';
import '../../../domain/entities/expense_entity.dart';
import '../../providers/order_providers.dart';
import '../../providers/vendor_provider.dart';
import '../../widgets/vendor_autocomplete_field.dart';
import '../../providers/settings_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../../data/services/synology_service.dart';
import '../../providers/company_document_provider.dart';
import 'pdf_preview_screen.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

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
      final qty = int.tryParse(_itemQtyControllers[item.id]?.text ?? '') ?? item.quantity;
      final days = int.tryParse(_itemDaysControllers[item.id]?.text ?? '') ?? item.days;
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

  void _addExpense(String currencyLabel) {
    _showExpenseForm(currencyLabel);
  }

  void _editExpense(ExpenseEntity expense, String currencyLabel) {
    _showExpenseForm(currencyLabel, expense: expense);
  }

  void _deleteExpense(ExpenseEntity expense) {
    setState(() {
      _manualExpenses.removeWhere((e) => e.id == expense.id);
    });
  }

  void _showExpensePdfOptions() {
    final colorScheme = Theme.of(context).colorScheme;
    bool includeItems = _includeItemsInPdf;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
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
                'Expense PDF',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              // Toggle: include item-based vendor costs
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: const Text(
                    'Include item vendor costs',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    includeItems
                        ? 'Item-based vendor costs will appear in PDF'
                        : 'Only additional expenses will appear in PDF',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                  value: includeItems,
                  onChanged: (val) {
                    setSheetState(() => includeItems = val);
                    setState(() => _includeItemsInPdf = val);
                  },
                ),
              ),
              const SizedBox(height: 16),
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
                title: const Text('Print / Save', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Open print dialog to save or print'),
                onTap: () {
                  Navigator.pop(ctx);
                  _executeExpensePdf(share: false, includeItems: includeItems);
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
                title: const Text('Share', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Share PDF via WhatsApp, email, etc.'),
                onTap: () {
                  Navigator.pop(ctx);
                  _executeExpensePdf(share: true, includeItems: includeItems);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _executeExpensePdf({required bool share, required bool includeItems}) async {
    if (_manualExpenses.isEmpty && (!includeItems || _items.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expenses or items to export')),
      );
      return;
    }

    String progressMessage = 'Generating Expenses Summary PDF…';
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
      final updatedItems = _items.map((item) {
        final rate = double.tryParse(_itemControllers[item.id]?.text ?? '') ?? 0.0;
        final double amount;
        if (item.billingType == 'event') {
          amount = rate * item.quantity;
        } else {
          amount = rate * item.quantity * item.days;
        }
        return item.copyWith(vendorRate: rate, vendorAmount: amount);
      }).toList();

      final pdfData = await OrderPdfService.generateExpensePdf(
        order: widget.order.copyWith(description: _orderDescriptionController.text.trim()),
        expenses: _manualExpenses,
        items: updatedItems,
        includeItems: includeItems,
        onProgress: (status) {
          if (mounted) setSnackBarState(() => progressMessage = status);
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final fileName = 'Expenses_Summary_${widget.order.id}_${widget.order.venue.replaceAll(RegExp(r'[ ,]+'), '_')}.pdf';

      if (share) {
        await Printing.sharePdf(bytes: pdfData, filename: fileName);
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(
              pdfData: pdfData,
              title: 'Expenses Summary',
              fileName: fileName,
            ),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('PDF generation error [expense_breakdown]: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateExpenseExcel() async {
    if (_manualExpenses.isEmpty &&
        _items.every((item) => item.vendorRate == 0)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No expenses to export')));
      return;
    }

    final headers = [
      'Type',
      'Description',
      'Vendor',
      'Category',
      'Rate (NPR)',
      'Quantity',
      'Days',
      'Amount (NPR)',
    ];

    final rows = <List<dynamic>>[];

    // Item-based vendor costs
    for (var item in _items) {
      final rate = double.tryParse(_itemControllers[item.id]?.text ?? '') ?? 0.0;
      if (rate > 0) {
        rows.add([
          'Item Cost',
          item.itemName,
          item.vendor,
          'Vendor Payable',
          rate,
          item.quantity,
          item.days,
          rate * item.quantity * item.days,
        ]);
      }
    }

    // Manual expenses
    for (var expense in _manualExpenses) {
      rows.add([
        'Manual Expense',
        expense.description,
        expense.vendorName ?? '',
        expense.category,
        expense.rate,
        expense.quantity,
        expense.days,
        expense.amount,
      ]);
    }

    final fileName = 'Expense_Breakdown_${widget.order.id}.xlsx';

    await ExcelExportHelper.exportAndShareExcel(
      context: context,
      headers: headers,
      rows: rows,
      filename: fileName,
      sheetName: 'Expenses',
      title: 'Expense Breakdown Statement - ${widget.order.eventName}',
    );
  }

  void _showExpenseForm(String currencyLabel, {ExpenseEntity? expense}) {
    final isEdit = expense != null;
    final rateController = TextEditingController(
      text: expense?.rate == null ? '' : expense!.rate.toStringAsFixed(0),
    );
    final qtyController = TextEditingController(
      text: expense?.quantity == null ? '1' : expense!.quantity.toString(),
    );
    final daysController = TextEditingController(
      text: expense?.days == null ? '1' : expense!.days.toString(),
    );
    final descriptionController = TextEditingController(
      text: expense?.description ?? '',
    );
    final specificationController = TextEditingController(
      text: expense?.specification ?? '',
    );
    final unitController = TextEditingController(
      text: expense?.unit ?? 'Pcs',
    );

    String category = expense?.category ?? 'Labour';
    String billingType = expense?.billingType ?? 'event';
    String? selectedVendorId = expense?.vendorId;
    String? currentBillUrl = expense?.billUrl;
    String? currentBillPath = expense?.billPath;
    String? currentBillName = expense?.billName;
    bool isUploadingBill = false;
    final vendorNameController = TextEditingController(
      text: expense?.vendorName ?? '',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit ? 'Edit Expense' : 'Add New Expense',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: labelColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'CATEGORY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: labelColor,
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
                        hintText: 'Describe this expense...',
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
                  Text(
                    'BILLING TYPE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _categoryChip(
                        'Daily',
                        billingType == 'daily',
                        () => setModalState(() => billingType = 'daily'),
                      ),
                      const SizedBox(width: 8),
                      _categoryChip(
                        'Event',
                        billingType == 'event',
                        () => setModalState(() => billingType = 'event'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildInputCol(
                    'SPECIFICATION',
                    specificationController,
                    labelColor,
                    inputBgColor,
                    textColor,
                  ),
                  const SizedBox(height: 16),
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
                          'UNIT',
                          unitController,
                          labelColor,
                          inputBgColor,
                          textColor,
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
                  const SizedBox(height: 16),
                  Text(
                    'ASSOCIATED VENDOR (OPTIONAL)',
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
                    hintText: 'Type vendor name...',
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
                  Text(
                    'BILL / RECEIPT ATTACHMENT (OPTIONAL)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (currentBillUrl != null && currentBillUrl!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              currentBillName ?? 'Bill Document',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Colors.red),
                            onPressed: () {
                              setModalState(() {
                                currentBillUrl = null;
                                currentBillPath = null;
                                currentBillName = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: isUploadingBill
                          ? null
                          : () async {
                              setModalState(() => isUploadingBill = true);
                              try {
                                final result = await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
                                  withData: true,
                                );
                                if (result != null && result.files.isNotEmpty) {
                                  final picked = result.files.first;
                                  Uint8List? bytes = picked.bytes;
                                  if (bytes == null && picked.path != null) {
                                    bytes = await File(picked.path!).readAsBytes();
                                  }
                                  if (bytes != null) {
                                    final filename = 'Bill_${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
                                    final synologyConfig = ref.read(companyDocumentNotifierProvider).synologyConfig;
                                    final uploadRes = await SynologyService().uploadPdf(
                                      config: synologyConfig,
                                      fileBytes: bytes,
                                      filename: filename,
                                    );
                                    setModalState(() {
                                      currentBillName = picked.name;
                                      currentBillPath = uploadRes?['synologyPath'] ?? '/EventSolution/ESWORKSPACE_app/$filename';
                                      currentBillUrl = uploadRes?['shareUrl'] ?? '${synologyConfig.host}/sharing/$filename';
                                      isUploadingBill = false;
                                    });
                                  } else {
                                    setModalState(() => isUploadingBill = false);
                                  }
                                } else {
                                  setModalState(() => isUploadingBill = false);
                                }
                              } catch (e) {
                                setModalState(() => isUploadingBill = false);
                              }
                            },
                      icon: isUploadingBill
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload_file_rounded, size: 18),
                      label: Text(isUploadingBill ? 'Uploading Bill to Synology...' : 'Upload Bill / Receipt Document (PDF/Image)'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        if (rateController.text.isEmpty) return;
                        final amount = calculateTotal();
                        if (amount <= 0) return;

                        final newExpense = ExpenseEntity(
                          id: expense?.id ?? const Uuid().v4(),
                          orderId: widget.order.id,
                          description: category == 'Other'
                              ? descriptionController.text.trim()
                              : '',
                          specification: specificationController.text.trim(),
                          unit: unitController.text.trim().isEmpty
                              ? 'Pcs'
                              : unitController.text.trim(),
                          amount: amount,
                          rate: double.tryParse(rateController.text) ?? 0.0,
                          quantity: int.tryParse(qtyController.text) ?? 1,
                          days: int.tryParse(daysController.text) ?? 1,
                          billingType: billingType,
                          category: category,
                          vendorId: selectedVendorId,
                          vendorName: vendorNameController.text.isEmpty
                              ? null
                              : vendorNameController.text,
                          createdAt: expense?.createdAt ?? DateTime.now(),
                          billUrl: currentBillUrl,
                          billPath: currentBillPath,
                          billName: currentBillName,
                        );

                        setState(() {
                          if (isEdit) {
                            final idx = _manualExpenses.indexWhere(
                              (e) => e.id == expense.id,
                            );
                            if (idx != -1) _manualExpenses[idx] = newExpense;
                          } else {
                            _manualExpenses.add(newExpense);
                          }
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isEdit ? 'Update Expense' : 'Add Expense',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
          color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _finalizeExpenses(String currencyLabel) async {
    bool? proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        title: const Text('Finalize Expenses?'),
        content: Text(
          'This will update the total expenses to $currencyLabel ${_totalExpenses.toStringAsFixed(0)}. Do you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
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

    if (proceed != true) return;

    final updatedItems = _items.map((item) {
      final rate =
          double.tryParse(_itemControllers[item.id]?.text ?? '') ?? 0.0;
      final qty =
          int.tryParse(_itemQtyControllers[item.id]?.text ?? '') ?? item.quantity;
      final days =
          int.tryParse(_itemDaysControllers[item.id]?.text ?? '') ?? item.days;
      final double amount;
      if (item.billingType == 'event') {
        amount = rate * qty;
      } else {
        amount = rate * qty * days;
      }
      return item.copyWith(
        vendorRate: rate,
        quantity: qty,
        days: days,
        vendorAmount: amount,
      );
    }).toList();

    final updatedOrder = widget.order.copyWith(
      totalExpenses: _totalExpenses,
      description: _orderDescriptionController.text.trim(),
    );

    try {
      await ref
          .read(orderNotifierProvider.notifier)
          .finalizeExpenses(updatedOrder, _manualExpenses, updatedItems);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expenses finalized successfully'),
            backgroundColor: Color(0xFF10b981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to finalize expenses: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Expense Breakdown',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_outlined, color: Colors.green),
            onPressed: _generateExpenseExcel,
            tooltip: 'Export Excel Report',
          ),
          IconButton(
            icon: Icon(Icons.picture_as_pdf_outlined, color: primaryColor),
            onPressed: _showExpensePdfOptions,
            tooltip: 'Expense PDF',
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: borderColor, height: 1),
        ),
      ),
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSectionHeader(
                        'ORDER DESCRIPTION',
                        Icons.description_outlined,
                        primaryColor,
                        labelColor,
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
                      _buildItemCostsSection(
                        surfaceColor,
                        borderColor,
                        textColor,
                        labelColor,
                        primaryColor,
                        currencyLabel,
                      ),
                      const SizedBox(height: 24),
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
                            onPressed: () => _addExpense(currencyLabel),
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
                      const SizedBox(height: 12),
                      if (_manualExpenses.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 48,
                                  color: labelColor.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No manual expenses recorded',
                                  style: TextStyle(
                                    color: labelColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._manualExpenses.map(
                          (expense) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
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
                    ],
                  ),
                ),
                _buildTotalSection(
                  surfaceColor,
                  borderColor,
                  textColor,
                  labelColor,
                  primaryColor,
                  currencyLabel,
                ),
              ],
            ),
      floatingActionButton: null,
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
        Icon(icon, size: 18, color: primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: primaryColor,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildItemCostsSection(
    Color backgroundColor,
    Color borderColor,
    Color textColor,
    Color labelColor,
    Color primaryColor,
    String currencyLabel,
  ) {
    if (_items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ITEM-BASED VENDOR COSTS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: labelColor,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: _items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final rateController = _itemControllers[item.id]!;
              final qtyController = _itemQtyControllers[item.id]!;
              final daysController = _itemDaysControllers[item.id]!;
              final isLast = idx == _items.length - 1;

              final rate = double.tryParse(rateController.text) ?? 0.0;
              final qty = int.tryParse(qtyController.text) ?? item.quantity;
              final days = int.tryParse(daysController.text) ?? item.days;

              final double vendorSubtotal;
              if (item.billingType == 'event') {
                vendorSubtotal = rate * qty;
              } else {
                vendorSubtotal = rate * qty * days;
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
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
                                  color: textColor,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _items[idx] = item.copyWith(billingType: 'event');
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: item.billingType == 'event'
                                          ? primaryColor
                                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Event',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: item.billingType == 'event'
                                            ? Colors.white
                                            : labelColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _items[idx] = item.copyWith(billingType: 'daily');
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: item.billingType == 'daily'
                                          ? primaryColor
                                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Daily',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: item.billingType == 'daily'
                                            ? Colors.white
                                            : labelColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (item.vendor.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.storefront_outlined, size: 14, color: labelColor),
                              const SizedBox(width: 4),
                              Text(
                                'Vendor: ${item.vendor}',
                                style: TextStyle(fontSize: 12, color: labelColor),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
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
                                    style: TextStyle(fontSize: 13, color: textColor),
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
                                    style: TextStyle(fontSize: 13, color: textColor),
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
                                    'VENDOR RATE ($currencyLabel)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: labelColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: rateController,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.all(8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                    style: TextStyle(fontSize: 13, color: textColor),
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
                                  '$currencyLabel ${vendorSubtotal.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isLast) Divider(color: borderColor, height: 1),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseCard(
    ExpenseEntity expense,
    Color backgroundColor,
    Color borderColor,
    Color textColor,
    Color labelColor,
    Color primaryColor,
    String currencyLabel,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
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
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  expense.category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
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
                    onPressed: () => _editExpense(expense, currencyLabel),
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
                    onPressed: () => _deleteExpense(expense),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            expense.category == 'Other' && expense.description.isNotEmpty
                ? expense.description
                : expense.category,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          if (expense.vendorName != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.storefront_outlined, size: 14, color: labelColor),
                const SizedBox(width: 4),
                Text(
                  expense.vendorName!,
                  style: TextStyle(fontSize: 13, color: labelColor),
                ),
              ],
            ),
          ],
          if (expense.hasBill) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _previewBill(context, expense),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Attached Bill: ${expense.billName ?? "View Attachment"}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.open_in_new, size: 12, color: Colors.green),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Amount', style: TextStyle(fontSize: 13, color: labelColor)),
              Text(
                '$currencyLabel ${expense.amount.toStringAsFixed(0)}',
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

  void _previewBill(BuildContext context, ExpenseEntity expense) {
    if (expense.billUrl == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                expense.billName ?? 'Bill / Receipt Document',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attached to: ${expense.description.isNotEmpty ? expense.description : expense.category}'),
            const SizedBox(height: 8),
            Text('Synology / Storage URL:', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            SelectableText(
              expense.billUrl!,
              style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Open / Download'),
            onPressed: () {
              Navigator.pop(ctx);
              Printing.sharePdf(
                bytes: Uint8List(0),
                filename: expense.billName ?? 'bill.pdf',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection(
    Color backgroundColor,
    Color borderColor,
    Color textColor,
    Color labelColor,
    Color primaryColor,
    String currencyLabel,
  ) {
    // Show section if we have either item costs or manual expenses
    if (_manualTotalExpenses == 0 && _itemTotalExpenses == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
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
                  'TOTAL EXPENSES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: labelColor,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '$currencyLabel ${_totalExpenses.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => _finalizeExpenses(currencyLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'Finalize Expenses',
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
