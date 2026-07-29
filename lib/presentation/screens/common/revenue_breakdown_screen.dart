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
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../../data/services/synology_service.dart';
import '../../providers/company_document_provider.dart';
import 'pdf_preview_screen.dart';
import '../../../core/utils/share_helper.dart';

enum VatOption { noVat, vat13, custom }

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
    _mgtChargeController = TextEditingController();
    _discountController = TextEditingController();
    
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
    _vatRateController.dispose();
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

  double get _managementChargeAmount {
    final val = double.tryParse(_mgtChargeController.text.trim()) ?? 0.0;
    if (val <= 0) return 0.0;
    return _isMgtChargePercent ? (_totalRevenue * val / 100.0) : val;
  }

  double get _discountAmount {
    final val = double.tryParse(_discountController.text.trim()) ?? 0.0;
    if (val <= 0) return 0.0;
    return _isDiscountPercent ? (_totalRevenue * val / 100.0) : val;
  }

  double get _netTotalRevenue =>
      _totalRevenue + _managementChargeAmount - _discountAmount;

  double get _effectiveVatRate {
    switch (_vatOption) {
      case VatOption.noVat:
        return 0.0;
      case VatOption.vat13:
        return 0.13;
      case VatOption.custom:
        final val = double.tryParse(_vatRateController.text.trim());
        return (val != null && val >= 0) ? (val / 100.0) : 0.0;
    }
  }

  double get _vatAmount => _netTotalRevenue * _effectiveVatRate;

  double get _grandTotalRevenue => _netTotalRevenue + _vatAmount;

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
    String? currentBillUrl = revenue?.billUrl;
    String? currentBillPath = revenue?.billPath;
    String? currentBillName = revenue?.billName;
    bool isUploadingBill = false;
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
                          billUrl: currentBillUrl,
                          billPath: currentBillPath,
                          billName: currentBillName,
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

  Future<void> _executeRevenuePdf({required bool share}) async {
    final valMgt = double.tryParse(_mgtChargeController.text.trim()) ?? 0.0;
    final valDisc = double.tryParse(_discountController.text.trim()) ?? 0.0;
    final valVat = double.tryParse(_vatRateController.text.trim());

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
        managementCharge: _isMgtChargePercent ? 0.0 : valMgt,
        managementChargeRate: _isMgtChargePercent ? valMgt : 0.0,
        discount: _isDiscountPercent ? 0.0 : valDisc,
        discountRate: _isDiscountPercent ? valDisc : 0.0,
        vatRate: valVat != null ? (valVat / 100.0) : null,
        onProgress: (status) {
          if (mounted) setSnackBarState(() => progressMessage = status);
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final fileName =
          'Revenue_Summary_${widget.order.id}_${widget.order.venue.replaceAll(RegExp(r'[ ,]+'), '_')}.pdf';

      if (share) {
        await ShareHelper.sharePdf(
          context: context,
          pdfBytes: pdfData,
          fileName: fileName,
          subject: 'Revenue Summary',
        );
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

  Widget _buildOptionalFinancialsSection(String currencyLabel) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.outline.withValues(alpha: 0.3);

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'OPTIONAL FINANCIALS & PDF SETTINGS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Management Charge (Optional)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _mgtChargeController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Management Charge (Optional)',
                    hintText: _isMgtChargePercent
                        ? 'e.g. 10 (%)'
                        : 'e.g. 5000 ($currencyLabel)',
                    isDense: true,
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.percent, size: 18),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              ToggleButtons(
                isSelected: [_isMgtChargePercent, !_isMgtChargePercent],
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
                onPressed: (index) {
                  setState(() => _isMgtChargePercent = index == 0);
                },
                children: [
                  const Text('%', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(currencyLabel,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Discount (Optional)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _discountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Discount (Optional)',
                    hintText: _isDiscountPercent
                        ? 'e.g. 5 (%)'
                        : 'e.g. 2000 ($currencyLabel)',
                    isDense: true,
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.local_offer_outlined, size: 18),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              ToggleButtons(
                isSelected: [_isDiscountPercent, !_isDiscountPercent],
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
                onPressed: (index) {
                  setState(() => _isDiscountPercent = index == 0);
                },
                children: [
                  const Text('%', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(currencyLabel,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // VAT Option Choice Chips
          Text(
            'VAT OPTION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(
                    child: Text(
                      'NO VAT (0%)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  selected: _vatOption == VatOption.noVat,
                  selectedColor: colorScheme.surfaceContainerHighest,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _vatOption = VatOption.noVat;
                        _vatRateController.text = '0';
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(
                    child: Text(
                      '13% VAT',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  selected: _vatOption == VatOption.vat13,
                  selectedColor: Colors.green.shade100,
                  labelStyle: TextStyle(
                    color: _vatOption == VatOption.vat13 ? Colors.green.shade900 : null,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _vatOption = VatOption.vat13;
                        _vatRateController.text = '13';
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(
                    child: Text(
                      'CUSTOM %',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  selected: _vatOption == VatOption.custom,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _vatOption = VatOption.custom;
                      });
                    }
                  },
                ),
              ),
            ],
          ),

          if (_vatOption == VatOption.custom) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _vatRateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Custom VAT Rate %',
                hintText: 'e.g. 13',
                isDense: true,
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.receipt_long, size: 18),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Live In-Page Summary Breakdown Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _summarySummaryRow(
                    'Subtotal', '$currencyLabel ${_totalRevenue.toStringAsFixed(0)}'),
                if (_managementChargeAmount > 0)
                  _summarySummaryRow(
                    _isMgtChargePercent
                        ? 'Management Charge (${_mgtChargeController.text.trim()}%)'
                        : 'Management Charge',
                    '+ $currencyLabel ${_managementChargeAmount.toStringAsFixed(0)}',
                    color: Colors.blue.shade700,
                  ),
                if (_discountAmount > 0)
                  _summarySummaryRow(
                    _isDiscountPercent
                        ? 'Discount (${_discountController.text.trim()}%)'
                        : 'Discount',
                    '- $currencyLabel ${_discountAmount.toStringAsFixed(0)}',
                    color: Colors.orange.shade800,
                  ),
                _summarySummaryRow(
                  'Total',
                  '$currencyLabel ${_netTotalRevenue.toStringAsFixed(0)}',
                  isBold: true,
                ),
                if (_vatAmount > 0)
                  _summarySummaryRow(
                    'VAT (${(_effectiveVatRate * 100).toStringAsFixed(0)}%)',
                    '+ $currencyLabel ${_vatAmount.toStringAsFixed(0)}',
                    color: Colors.green.shade800,
                  ),
                const Divider(height: 12),
                _summarySummaryRow(
                  'Grand Total',
                  '$currencyLabel ${_grandTotalRevenue.toStringAsFixed(0)}',
                  isBold: true,
                  fontSize: 15,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Direct Print / Share Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('PREVIEW / PRINT PDF',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _executeRevenuePdf(share: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('SHARE REVENUE PDF',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _executeRevenuePdf(share: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summarySummaryRow(String label, String value,
      {bool isBold = false, double fontSize = 13, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
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
              : 'This will update the total revenue to $currencyLabel ${_grandTotalRevenue.toStringAsFixed(0)}. Do you want to proceed?',
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

    final totalRevenue = _grandTotalRevenue;
    final updatedOrder = widget.order.copyWith(
      totalAmount: totalRevenue,
      vatRate: _effectiveVatRate,
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
            onPressed: () => _executeRevenuePdf(share: false),
            tooltip: 'Preview / Print Revenue PDF',
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
                const SizedBox(height: 20),
                _buildOptionalFinancialsSection(currencyLabel),
                const SizedBox(height: 40),
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
          if (revenue.hasBill) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _previewBill(context, revenue),
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
                        'Attached Bill: ${revenue.billName ?? "View Attachment"}',
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

  void _previewBill(BuildContext context, ExpenseEntity item) {
    if (item.billUrl == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.billName ?? 'Bill / Receipt',
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
            Text('Attached to: ${item.description.isNotEmpty ? item.description : item.category}'),
            const SizedBox(height: 8),
            Text('Synology / Storage URL:', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            SelectableText(
              item.billUrl!,
              style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
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
                  'GRAND TOTAL REVENUE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: labelColor,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '$currencyLabel ${_grandTotalRevenue.toStringAsFixed(0)}',
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
