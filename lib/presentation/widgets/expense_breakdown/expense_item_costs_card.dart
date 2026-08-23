import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:order_app/core/utils/receipt_compressor.dart';
import 'package:order_app/data/services/synology_service.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/presentation/providers/company_document_provider.dart';
import 'package:order_app/presentation/widgets/common/receipt_viewer_modal.dart';

class ExpenseItemCostsCardWidget extends ConsumerStatefulWidget {
  final String orderId;
  final List<OrderItemEntity> items;
  final Map<String, TextEditingController> itemControllers;
  final Map<String, TextEditingController> itemQtyControllers;
  final Map<String, TextEditingController> itemDaysControllers;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color labelColor;
  final Color primaryColor;
  final String currencyLabel;
  final Function(int index, String billingType) onBillingTypeChanged;
  final Function(int index, ({String? url, String? path, String? name}) billData)
      onItemBillChanged;
  final VoidCallback onChanged;

  const ExpenseItemCostsCardWidget({
    super.key,
    required this.orderId,
    required this.items,
    required this.itemControllers,
    required this.itemQtyControllers,
    required this.itemDaysControllers,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.labelColor,
    required this.primaryColor,
    required this.currencyLabel,
    required this.onBillingTypeChanged,
    required this.onItemBillChanged,
    required this.onChanged,
  });

  @override
  ConsumerState<ExpenseItemCostsCardWidget> createState() =>
      _ExpenseItemCostsCardWidgetState();
}

class _ExpenseItemCostsCardWidgetState
    extends ConsumerState<ExpenseItemCostsCardWidget> {
  final Map<String, bool> _uploadingItemIds = {};
  final Map<String, Uint8List> _cachedItemBytes = {};

  Future<void> _pickAndUploadBill(int index, OrderItemEntity item) async {
    setState(() => _uploadingItemIds[item.id] = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final picked = result.files.first;
        final rawBytes = picked.bytes ??
            (picked.path != null ? await File(picked.path!).readAsBytes() : null);

        if (rawBytes == null) {
          throw Exception('Could not read file data');
        }

        final compressedBytes = await ReceiptCompressor.compressReceiptBytes(
          rawBytes: rawBytes,
          fileName: picked.name,
        );

        _cachedItemBytes[item.id] = compressedBytes;

        final filename =
            'VendorBill_${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
        final synologyConfig =
            ref.read(companyDocumentNotifierProvider).synologyConfig;
        final uploadRes = await SynologyService().uploadPdf(
          config: synologyConfig,
          fileBytes: compressedBytes,
          filename: filename,
        );

        final billName = picked.name;
        final billPath = uploadRes?['synologyPath'] ??
            '/EventSolution/ESWORKSPACE_app/VendorBills/$filename';
        final billUrl = uploadRes?['shareUrl'] ??
            '${synologyConfig.host}/sharing/$filename';

        widget.onItemBillChanged(
          index,
          (
            url: billUrl,
            path: billPath,
            name: billName,
          ),
        );
        widget.onChanged();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vendor bill attached: $billName'),
              backgroundColor: const Color(0xFF10b981),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload bill: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingItemIds.remove(item.id));
      }
    }
  }

  void _previewBill(OrderItemEntity item) {
    final title = item.vendorBillName ?? '${item.itemName} Bill';
    final url = item.vendorBillUrl;
    final path = item.vendorBillPath;
    final cached = _cachedItemBytes[item.id];

    ReceiptViewerModal.show(
      context,
      title: title,
      url: url,
      path: path,
      initialBytes: cached,
    );
  }

  Future<void> _openBillUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ITEM-BASED VENDOR COSTS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: widget.labelColor,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: widget.borderColor),
          ),
          child: Column(
            children: widget.items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final rateController = widget.itemControllers[item.id]!;
              final qtyController = widget.itemQtyControllers[item.id]!;
              final daysController = widget.itemDaysControllers[item.id]!;
              final isLast = idx == widget.items.length - 1;
              final isUploading = _uploadingItemIds[item.id] == true;
              final hasBill = item.vendorBillUrl != null &&
                  item.vendorBillUrl!.isNotEmpty;

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
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Item Name & Billing Type Toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.itemName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: widget.textColor,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => widget.onBillingTypeChanged(
                                    idx,
                                    'event',
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: item.billingType == 'event'
                                          ? widget.primaryColor
                                          : colorScheme
                                              .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Event',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: item.billingType == 'event'
                                            ? Colors.white
                                            : widget.labelColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => widget.onBillingTypeChanged(
                                    idx,
                                    'daily',
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: item.billingType == 'daily'
                                          ? widget.primaryColor
                                          : colorScheme
                                              .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Daily',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: item.billingType == 'daily'
                                            ? Colors.white
                                            : widget.labelColor,
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
                              Icon(
                                Icons.storefront_outlined,
                                size: 14,
                                color: widget.labelColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Vendor: ${item.vendor}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.labelColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),

                        // Inputs: Qty, Days, Vendor Rate, Subtotal
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
                                      color: widget.labelColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: qtyController,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => widget.onChanged(),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.all(8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: widget.textColor,
                                    ),
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
                                      color: widget.labelColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: daysController,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => widget.onChanged(),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.all(8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: widget.textColor,
                                    ),
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
                                    'VENDOR RATE (${widget.currencyLabel})',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: widget.labelColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: rateController,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => widget.onChanged(),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.all(8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: widget.textColor,
                                    ),
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
                                    color: widget.labelColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.currencyLabel} ${vendorSubtotal.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: widget.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Vendor Bill / Receipt Upload Section
                        if (hasBill) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10b981).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF10b981).withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.receipt_long_rounded,
                                  color: Color(0xFF10b981),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.vendorBillName ?? 'Vendor Bill',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                          color: Color(0xFF047857),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _previewBill(item),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10b981).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.visibility_outlined,
                                          size: 12,
                                          color: Color(0xFF047857),
                                        ),
                                        SizedBox(width: 3),
                                        Text(
                                          'VIEW',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF047857),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (item.vendorBillUrl != null &&
                                    item.vendorBillUrl!.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => _openBillUrl(item.vendorBillUrl!),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10b981).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.open_in_new_rounded,
                                        size: 12,
                                        color: Color(0xFF047857),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    widget.onItemBillChanged(
                                      idx,
                                      (url: null, path: null, name: null),
                                    );
                                    widget.onChanged();
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          InkWell(
                            onTap: isUploading
                                ? null
                                : () => _pickAndUploadBill(idx, item),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: widget.primaryColor.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: widget.primaryColor.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isUploading)
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.upload_file_rounded,
                                      size: 14,
                                      color: widget.primaryColor,
                                    ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isUploading
                                        ? 'Uploading Bill…'
                                        : 'Attach Vendor Bill (Optional)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: widget.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isLast) Divider(color: widget.borderColor, height: 1),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
