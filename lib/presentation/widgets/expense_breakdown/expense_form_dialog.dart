import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:order_app/data/services/synology_service.dart';
import 'package:order_app/domain/entities/expense_entity.dart';
import 'package:order_app/presentation/providers/company_document_provider.dart';
import 'package:order_app/presentation/providers/vendor_provider.dart';
import 'package:order_app/presentation/widgets/common/vendor_autocomplete_field.dart';

class ExpenseFormDialog extends ConsumerStatefulWidget {
  final String orderId;
  final String currencyLabel;
  final ExpenseEntity? expense;
  final ValueChanged<ExpenseEntity> onSaved;

  const ExpenseFormDialog({
    super.key,
    required this.orderId,
    required this.currencyLabel,
    this.expense,
    required this.onSaved,
  });

  static void show(
    BuildContext context, {
    required String orderId,
    required String currencyLabel,
    ExpenseEntity? expense,
    required ValueChanged<ExpenseEntity> onSaved,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExpenseFormDialog(
        orderId: orderId,
        currencyLabel: currencyLabel,
        expense: expense,
        onSaved: onSaved,
      ),
    );
  }

  @override
  ConsumerState<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends ConsumerState<ExpenseFormDialog> {
  late final TextEditingController rateController;
  late final TextEditingController qtyController;
  late final TextEditingController daysController;
  late final TextEditingController descriptionController;
  late final TextEditingController specificationController;
  late final TextEditingController unitController;
  late final TextEditingController vendorNameController;

  late String category;
  late String billingType;
  String? selectedVendorId;
  String? currentBillUrl;
  String? currentBillPath;
  String? currentBillName;
  bool isUploadingBill = false;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    rateController = TextEditingController(
      text: expense?.rate == null ? '' : expense!.rate.toStringAsFixed(0),
    );
    qtyController = TextEditingController(
      text: expense?.quantity == null ? '1' : expense!.quantity.toString(),
    );
    daysController = TextEditingController(
      text: expense?.days == null ? '1' : expense!.days.toString(),
    );
    descriptionController = TextEditingController(
      text: expense?.description ?? '',
    );
    specificationController = TextEditingController(
      text: expense?.specification ?? '',
    );
    unitController = TextEditingController(
      text: expense?.unit ?? 'Pcs',
    );
    vendorNameController = TextEditingController(
      text: expense?.vendorName ?? '',
    );

    category = expense?.category ?? 'Labour';
    billingType = expense?.billingType ?? 'event';
    selectedVendorId = expense?.vendorId;
    currentBillUrl = expense?.billUrl;
    currentBillPath = expense?.billPath;
    currentBillName = expense?.billName;
  }

  @override
  void dispose() {
    rateController.dispose();
    qtyController.dispose();
    daysController.dispose();
    descriptionController.dispose();
    specificationController.dispose();
    unitController.dispose();
    vendorNameController.dispose();
    super.dispose();
  }

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

  Widget _categoryChip(String label, bool isSelected, VoidCallback onTap) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final borderColor = Theme.of(context).colorScheme.outline;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? primaryColor : borderColor,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? primaryColor
                : Theme.of(context).colorScheme.onSurface,
          ),
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.expense != null;
    final vendors = ref.watch(vendorNotifierProvider).vendors;
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColor = colorScheme.surface;
    final textColor = colorScheme.onSurface;
    final labelColor = colorScheme.onSurfaceVariant;
    final inputBgColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

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
                  () => setState(() => category = 'Labour'),
                ),
                const SizedBox(width: 12),
                _categoryChip(
                  'Transportation',
                  category == 'Transportation',
                  () => setState(() => category = 'Transportation'),
                ),
                const SizedBox(width: 12),
                _categoryChip(
                  'Other',
                  category == 'Other',
                  () => setState(() => category = 'Other'),
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
                  () => setState(() => billingType = 'daily'),
                ),
                const SizedBox(width: 8),
                _categoryChip(
                  'Event',
                  billingType == 'event',
                  () => setState(() => billingType = 'event'),
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
                    onChanged: (_) => setState(() {}),
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
                    onChanged: (_) => setState(() {}),
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
                    onChanged: (_) => setState(() {}),
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
                    '${widget.currencyLabel} ${calculateTotal().toStringAsFixed(0)}',
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
                        setState(() {
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
                        setState(() => isUploadingBill = true);
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
                              setState(() {
                                currentBillName = picked.name;
                                currentBillPath = uploadRes?['synologyPath'] ?? '/EventSolution/ESWORKSPACE_app/$filename';
                                currentBillUrl = uploadRes?['shareUrl'] ?? '${synologyConfig.host}/sharing/$filename';
                                isUploadingBill = false;
                              });
                            } else {
                              setState(() => isUploadingBill = false);
                            }
                          } else {
                            setState(() => isUploadingBill = false);
                          }
                        } catch (e) {
                          setState(() => isUploadingBill = false);
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
                    id: widget.expense?.id ?? const Uuid().v4(),
                    orderId: widget.orderId,
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
                    createdAt: widget.expense?.createdAt ?? DateTime.now(),
                    billUrl: currentBillUrl,
                    billPath: currentBillPath,
                    billName: currentBillName,
                  );

                  widget.onSaved(newExpense);
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
  }
}
