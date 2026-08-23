import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';
import 'package:order_app/core/utils/receipt_compressor.dart';
import 'package:order_app/data/services/synology_service.dart';
import 'package:order_app/presentation/providers/company_document_provider.dart';
import 'package:order_app/presentation/widgets/common/receipt_viewer_modal.dart';
import 'package:url_launcher/url_launcher.dart';

enum VatOption { noVat, vat13, custom }

class RevenueFinancialsCardWidget extends ConsumerStatefulWidget {
  final TextEditingController mgtChargeController;
  final TextEditingController discountController;
  final TextEditingController vatRateController;
  final TextEditingController advanceReceivedController;
  final TextEditingController advanceRefNoController;
  final bool isMgtChargePercent;
  final bool isDiscountPercent;
  final VatOption vatOption;
  final double totalRevenue;
  final double managementChargeAmount;
  final double discountAmount;
  final double netTotalRevenue;
  final double vatAmount;
  final double effectiveVatRate;
  final double grandTotalRevenue;
  final String currencyLabel;
  final bool canEditAdvance;
  final String? advanceReceiptUrl;
  final String? advanceReceiptPath;
  final String? advanceReceiptName;
  final ValueChanged<({String? url, String? path, String? name})> onReceiptChanged;
  final ValueChanged<bool> onMgtChargePercentChanged;
  final ValueChanged<bool> onDiscountPercentChanged;
  final ValueChanged<VatOption> onVatOptionChanged;
  final VoidCallback onChanged;
  final VoidCallback onPreviewPdf;
  final VoidCallback? onGenerateInvoice;

  const RevenueFinancialsCardWidget({
    super.key,
    required this.mgtChargeController,
    required this.discountController,
    required this.vatRateController,
    required this.advanceReceivedController,
    required this.advanceRefNoController,
    required this.isMgtChargePercent,
    required this.isDiscountPercent,
    required this.vatOption,
    required this.totalRevenue,
    required this.managementChargeAmount,
    required this.discountAmount,
    required this.netTotalRevenue,
    required this.vatAmount,
    required this.effectiveVatRate,
    required this.grandTotalRevenue,
    required this.currencyLabel,
    this.canEditAdvance = true,
    this.advanceReceiptUrl,
    this.advanceReceiptPath,
    this.advanceReceiptName,
    required this.onReceiptChanged,
    required this.onMgtChargePercentChanged,
    required this.onDiscountPercentChanged,
    required this.onVatOptionChanged,
    required this.onChanged,
    required this.onPreviewPdf,
    this.onGenerateInvoice,
  });

  @override
  ConsumerState<RevenueFinancialsCardWidget> createState() =>
      _RevenueFinancialsCardWidgetState();
}

class _RevenueFinancialsCardWidgetState
    extends ConsumerState<RevenueFinancialsCardWidget> {
  bool _isUploadingReceipt = false;
  Uint8List? _cachedReceiptBytes;
  bool _hasAdvance = false;

  @override
  void initState() {
    super.initState();
    final advVal =
        double.tryParse(widget.advanceReceivedController.text.trim()) ?? 0.0;
    _hasAdvance = advVal > 0 ||
        (widget.advanceReceiptUrl != null &&
            widget.advanceReceiptUrl!.isNotEmpty) ||
        (widget.advanceReceiptPath != null &&
            widget.advanceReceiptPath!.isNotEmpty);
  }

  void _toggleAdvance(bool value) {
    setState(() {
      _hasAdvance = value;
      if (!value) {
        widget.advanceReceivedController.text = '0';
        widget.advanceRefNoController.clear();
        widget.onReceiptChanged((url: null, path: null, name: null));
        widget.onChanged();
      }
    });
  }

  Widget _summarySummaryRow(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 13,
    Color? color,
  }) {
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

  Future<void> _pickAndUploadReceipt() async {
    setState(() => _isUploadingReceipt = true);
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

        if (rawBytes != null) {
          final compressedBytes = await ReceiptCompressor.compressReceiptBytes(
            rawBytes: rawBytes,
            fileName: picked.name,
          );

          setState(() {
            _cachedReceiptBytes = compressedBytes;
          });

          final filename =
              'Receipt_${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
          final synologyConfig =
              ref.read(companyDocumentNotifierProvider).synologyConfig;
          final uploadRes = await SynologyService().uploadPdf(
            config: synologyConfig,
            fileBytes: compressedBytes,
            filename: filename,
          );

          final receiptName = picked.name;
          final receiptPath = uploadRes?['synologyPath'] ??
              '/EventSolution/ESWORKSPACE_app/Receipts/$filename';
          final receiptUrl = uploadRes?['shareUrl'] ??
              '${synologyConfig.host}/sharing/$filename';

          widget.onReceiptChanged((
            url: receiptUrl,
            path: receiptPath,
            name: receiptName,
          ));

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Receipt "$receiptName" attached successfully!'),
                backgroundColor: const Color(0xFF10b981),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to attach receipt: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingReceipt = false);
    }
  }

  void _previewReceipt() {
    final title = widget.advanceReceiptName ?? 'Advance Receipt';
    final url = widget.advanceReceiptUrl;
    final path = widget.advanceReceiptPath;

    ReceiptViewerModal.show(
      context,
      title: title,
      url: url,
      path: path,
      initialBytes: _cachedReceiptBytes,
    );
  }

  Future<void> _openReceiptUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.outline.withValues(alpha: 0.3);

    final hasReceipt = widget.advanceReceiptName != null &&
        widget.advanceReceiptName!.isNotEmpty;

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
                'FINANCIALS & ADVANCE PAYMENT',
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

          // Management Charge & Discount (Responsive Grid)
          LayoutBuilder(
            builder: (context, finConstraints) {
              final isWide = finConstraints.maxWidth >= 540;

              final mgtWidget = Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.mgtChargeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => widget.onChanged(),
                      decoration: InputDecoration(
                        labelText: 'Management Charge (Optional)',
                        hintText: widget.isMgtChargePercent
                            ? 'e.g. 10 (%)'
                            : 'e.g. 5000 (${widget.currencyLabel})',
                        isDense: true,
                        filled: true,
                        fillColor: colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(
                          Icons.business_center_outlined,
                          size: 18,
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ToggleButtons(
                    isSelected: [
                      widget.isMgtChargePercent,
                      !widget.isMgtChargePercent,
                    ],
                    onPressed: (index) {
                      widget.onMgtChargePercentChanged(index == 0);
                      widget.onChanged();
                    },
                    borderRadius: BorderRadius.circular(8),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    selectedColor: colorScheme.onPrimary,
                    fillColor: colorScheme.primary,
                    color: colorScheme.onSurfaceVariant,
                    children: [
                      const Text(
                        '%',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.currencyLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              );

              final discWidget = Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.discountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => widget.onChanged(),
                      decoration: InputDecoration(
                        labelText: 'Discount (Optional)',
                        hintText: widget.isDiscountPercent
                            ? 'e.g. 5 (%)'
                            : 'e.g. 2000 (${widget.currencyLabel})',
                        isDense: true,
                        filled: true,
                        fillColor: colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(
                          Icons.local_offer_outlined,
                          size: 18,
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ToggleButtons(
                    isSelected: [
                      widget.isDiscountPercent,
                      !widget.isDiscountPercent,
                    ],
                    onPressed: (index) {
                      widget.onDiscountPercentChanged(index == 0);
                      widget.onChanged();
                    },
                    borderRadius: BorderRadius.circular(8),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    selectedColor: colorScheme.onPrimary,
                    fillColor: colorScheme.primary,
                    color: colorScheme.onSurfaceVariant,
                    children: [
                      const Text(
                        '%',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.currencyLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: mgtWidget),
                    const SizedBox(width: 12),
                    Expanded(child: discWidget),
                  ],
                );
              }

              return Column(
                children: [
                  mgtWidget,
                  const SizedBox(height: 12),
                  discWidget,
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Advance Payment Section (Admin & Finance) with Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hasAdvance
                    ? colorScheme.primary.withValues(alpha: 0.3)
                    : colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Switch Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: widget.canEditAdvance
                          ? () => _toggleAdvance(!_hasAdvance)
                          : null,
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 16,
                            color: _hasAdvance
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'ADVANCE PAYMENT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _hasAdvance
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: widget.canEditAdvance
                                  ? const Color(0xFF10b981).withValues(alpha: 0.12)
                                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.canEditAdvance ? 'ADMIN / FINANCE' : 'READ ONLY',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: widget.canEditAdvance
                                    ? const Color(0xFF10b981)
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.canEditAdvance)
                      SizedBox(
                        height: 24,
                        child: Transform.scale(
                          scale: 0.75,
                          alignment: Alignment.centerRight,
                          child: Switch.adaptive(
                            value: _hasAdvance,
                            activeThumbColor: colorScheme.primary,
                            activeTrackColor: colorScheme.primary.withValues(alpha: 0.5),
                            onChanged: _toggleAdvance,
                          ),
                        ),
                      ),
                  ],
                ),

                // Collapsible Content
                if (_hasAdvance) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widget.advanceReceivedController,
                          readOnly: !widget.canEditAdvance,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => widget.onChanged(),
                          decoration: InputDecoration(
                            labelText:
                                'Advance Received (${widget.currencyLabel})',
                            hintText: 'e.g. 10000',
                            isDense: true,
                            filled: true,
                            fillColor: widget.canEditAdvance
                                ? colorScheme.surface
                                : colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(
                              Icons.payments_outlined,
                              size: 18,
                            ),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: widget.advanceRefNoController,
                          readOnly: !widget.canEditAdvance,
                          onChanged: (_) => widget.onChanged(),
                          decoration: InputDecoration(
                            labelText: 'Ref / Receipt No.',
                            hintText: 'e.g. RCP-001',
                            isDense: true,
                            filled: true,
                            fillColor: widget.canEditAdvance
                                ? colorScheme.surface
                                : colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.tag, size: 18),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Receipt Upload / Attachment Card
                  if (hasReceipt) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10b981).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF10b981).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.receipt_long_rounded,
                            color: Color(0xFF10b981),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.advanceReceiptName ?? 'Advance Receipt',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Attached payment receipt',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: _previewReceipt,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10b981)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.visibility_outlined,
                                    size: 14,
                                    color: Color(0xFF047857),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'VIEW',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF047857),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (widget.advanceReceiptUrl != null &&
                              widget.advanceReceiptUrl!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () =>
                                  _openReceiptUrl(widget.advanceReceiptUrl!),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10b981)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 14,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                          if (widget.canEditAdvance) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Colors.red,
                              ),
                              tooltip: 'Remove receipt',
                              onPressed: () {
                                widget.onReceiptChanged((
                                  url: null,
                                  path: null,
                                  name: null,
                                ));
                                widget.onChanged();
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else if (widget.canEditAdvance) ...[
                    OutlinedButton.icon(
                      onPressed:
                          _isUploadingReceipt ? null : _pickAndUploadReceipt,
                      icon: _isUploadingReceipt
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_rounded, size: 18),
                      label: Text(
                        _isUploadingReceipt
                            ? 'UPLOADING RECEIPT…'
                            : 'ATTACH RECEIPT (OPTIONAL)',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(
                          color: colorScheme.primary.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

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
                  selected: widget.vatOption == VatOption.noVat,
                  selectedColor: colorScheme.surfaceContainerHighest,
                  onSelected: (selected) {
                    if (selected) {
                      widget.onVatOptionChanged(VatOption.noVat);
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
                  selected: widget.vatOption == VatOption.vat13,
                  selectedColor: Colors.green.shade100,
                  labelStyle: TextStyle(
                    color: widget.vatOption == VatOption.vat13
                        ? Colors.green.shade900
                        : null,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      widget.onVatOptionChanged(VatOption.vat13);
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
                  selected: widget.vatOption == VatOption.custom,
                  onSelected: (selected) {
                    if (selected) {
                      widget.onVatOptionChanged(VatOption.custom);
                    }
                  },
                ),
              ),
            ],
          ),

          if (widget.vatOption == VatOption.custom) ...[
            const SizedBox(height: 10),
            TextField(
              controller: widget.vatRateController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => widget.onChanged(),
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
                  context,
                  'Subtotal',
                  '${widget.currencyLabel} ${widget.totalRevenue.toStringAsFixed(0)}',
                ),
                if (widget.managementChargeAmount > 0)
                  _summarySummaryRow(
                    context,
                    widget.isMgtChargePercent
                        ? 'Management Charge (${widget.mgtChargeController.text.trim()}%)'
                        : 'Management Charge',
                    '+ ${widget.currencyLabel} ${widget.managementChargeAmount.toStringAsFixed(0)}',
                    color: Colors.blue.shade700,
                  ),
                if (widget.discountAmount > 0)
                  _summarySummaryRow(
                    context,
                    widget.isDiscountPercent
                        ? 'Discount (${widget.discountController.text.trim()}%)'
                        : 'Discount',
                    '- ${widget.currencyLabel} ${widget.discountAmount.toStringAsFixed(0)}',
                    color: Colors.orange.shade800,
                  ),
                _summarySummaryRow(
                  context,
                  'Total',
                  '${widget.currencyLabel} ${widget.netTotalRevenue.toStringAsFixed(0)}',
                  isBold: true,
                ),
                if (widget.vatAmount > 0)
                  _summarySummaryRow(
                    context,
                    'VAT (${(widget.effectiveVatRate * 100).toStringAsFixed(0)}%)',
                    '+ ${widget.currencyLabel} ${widget.vatAmount.toStringAsFixed(0)}',
                    color: Colors.green.shade800,
                  ),
                const Divider(height: 12),
                _summarySummaryRow(
                  context,
                  'Grand Total',
                  '${widget.currencyLabel} ${widget.grandTotalRevenue.toStringAsFixed(0)}',
                  isBold: true,
                  fontSize: 15,
                  color: colorScheme.primary,
                ),
                if ((double.tryParse(widget.advanceReceivedController.text.trim()) ?? 0) > 0) ...[
                  const SizedBox(height: 4),
                  _summarySummaryRow(
                    context,
                    widget.advanceRefNoController.text.trim().isNotEmpty
                        ? 'Advance Received (${widget.advanceRefNoController.text.trim()})'
                        : 'Advance Received',
                    '- ${widget.currencyLabel} ${(double.tryParse(widget.advanceReceivedController.text.trim()) ?? 0).toStringAsFixed(0)}',
                    color: Colors.teal.shade700,
                  ),
                  const Divider(height: 10),
                  _summarySummaryRow(
                    context,
                    'Balance Due',
                    '${widget.currencyLabel} ${(widget.grandTotalRevenue - (double.tryParse(widget.advanceReceivedController.text.trim()) ?? 0)).toStringAsFixed(0)}',
                    isBold: true,
                    fontSize: 15,
                    color: Colors.deepOrange.shade700,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Preview & Share Revenue PDF Action Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.preview_rounded, size: 18),
              label: const Text(
                'PREVIEW / SHARE REVENUE PDF',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: widget.onPreviewPdf,
            ),
          ),
          if (widget.onGenerateInvoice != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.receipt_rounded, size: 18),
                label: const Text(
                  'GENERATE & PERSONALIZE INVOICE',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: widget.onGenerateInvoice,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
