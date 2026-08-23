import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:order_app/core/utils/receipt_compressor.dart';
import 'package:order_app/data/services/synology_service.dart';
import 'package:order_app/domain/entities/expense_entity.dart';
import 'package:order_app/presentation/providers/company_document_provider.dart';
import 'package:order_app/presentation/providers/vendor_provider.dart';
import 'package:order_app/presentation/widgets/common/receipt_viewer_modal.dart';
import 'package:order_app/presentation/widgets/common/vendor_autocomplete_field.dart';

class RevenueFormDialog extends ConsumerStatefulWidget {
  final String orderId;
  final String currencyLabel;
  final ExpenseEntity? revenue;
  final ValueChanged<ExpenseEntity> onSaved;

  const RevenueFormDialog({
    super.key,
    required this.orderId,
    required this.currencyLabel,
    this.revenue,
    required this.onSaved,
  });

  static void show(
    BuildContext context, {
    required String orderId,
    required String currencyLabel,
    ExpenseEntity? revenue,
    required ValueChanged<ExpenseEntity> onSaved,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RevenueFormDialog(
        orderId: orderId,
        currencyLabel: currencyLabel,
        revenue: revenue,
        onSaved: onSaved,
      ),
    );
  }

  @override
  ConsumerState<RevenueFormDialog> createState() => _RevenueFormDialogState();
}

class _RevenueFormDialogState extends ConsumerState<RevenueFormDialog> {
  late final TextEditingController rateController;
  late final TextEditingController qtyController;
  late final TextEditingController daysController;
  late final TextEditingController descriptionController;
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
    final revenue = widget.revenue;
    rateController = TextEditingController(
      text: revenue?.rate == null ? '' : revenue!.rate.toStringAsFixed(0),
    );
    qtyController = TextEditingController(
      text: revenue?.quantity == null ? '1' : revenue!.quantity.toString(),
    );
    daysController = TextEditingController(
      text: revenue?.days == null ? '1' : revenue!.days.toString(),
    );
    descriptionController = TextEditingController(
      text: revenue?.description ?? '',
    );
    vendorNameController = TextEditingController(
      text: revenue?.vendorName ?? '',
    );

    category = revenue?.category ?? 'Labour';
    billingType = revenue?.billingType ?? 'event';
    selectedVendorId = revenue?.vendorId;
    currentBillUrl = revenue?.billUrl;
    currentBillPath = revenue?.billPath;
    currentBillName = revenue?.billName;
  }

  @override
  void dispose() {
    rateController.dispose();
    qtyController.dispose();
    daysController.dispose();
    descriptionController.dispose();
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
    final isEdit = widget.revenue != null;
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
                  () => setState(() => billingType = 'daily'),
                ),
                const SizedBox(width: 12),
                _categoryChip(
                  'Event',
                  billingType == 'event',
                  () => setState(() => billingType = 'event'),
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
                      child: InkWell(
                        onTap: () {
                          ReceiptViewerModal.show(
                            context,
                            title: currentBillName ?? 'Bill Document',
                            url: currentBillUrl,
                            path: currentBillPath,
                          );
                        },
                        child: Text(
                          currentBillName ?? 'Bill Document',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.green,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 18, color: Colors.green),
                      tooltip: 'View in App',
                      onPressed: () {
                        ReceiptViewerModal.show(
                          context,
                          title: currentBillName ?? 'Bill Document',
                          url: currentBillUrl,
                          path: currentBillPath,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.red),
                      tooltip: 'Remove',
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
                            final rawBytes = picked.bytes ??
                                (picked.path != null
                                    ? await File(picked.path!).readAsBytes()
                                    : null);
                            if (rawBytes != null) {
                              final compressedBytes =
                                  await ReceiptCompressor.compressReceiptBytes(
                                rawBytes: rawBytes,
                                fileName: picked.name,
                              );
                              final filename =
                                  'Bill_${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
                              final synologyConfig = ref
                                  .read(companyDocumentNotifierProvider)
                                  .synologyConfig;
                              final uploadRes =
                                  await SynologyService().uploadPdf(
                                config: synologyConfig,
                                fileBytes: compressedBytes,
                                filename: filename,
                              );
                              setState(() {
                                currentBillName = picked.name;
                                currentBillPath = uploadRes?['synologyPath'] ??
                                    '/EventSolution/ESWORKSPACE_app/$filename';
                                currentBillUrl = uploadRes?['shareUrl'] ??
                                    '${synologyConfig.host}/sharing/$filename';
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

                  final newRevenue = ExpenseEntity(
                    id: widget.revenue?.id ?? const Uuid().v4(),
                    orderId: widget.orderId,
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
                    createdAt: widget.revenue?.createdAt ?? DateTime.now(),
                    billUrl: currentBillUrl,
                    billPath: currentBillPath,
                    billName: currentBillName,
                  );

                  widget.onSaved(newRevenue);
                  Navigator.pop(context);
                },
                child: Text(isEdit ? 'Update' : 'Add'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
