import 'package:flutter/material.dart';

enum VatOption { noVat, vat13, custom }

class RevenueFinancialsCardWidget extends StatelessWidget {
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
  final ValueChanged<bool> onMgtChargePercentChanged;
  final ValueChanged<bool> onDiscountPercentChanged;
  final ValueChanged<VatOption> onVatOptionChanged;
  final VoidCallback onChanged;
  final VoidCallback onPreviewPdf;
  final VoidCallback onSharePdf;
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
    required this.onMgtChargePercentChanged,
    required this.onDiscountPercentChanged,
    required this.onVatOptionChanged,
    required this.onChanged,
    required this.onPreviewPdf,
    required this.onSharePdf,
    this.onGenerateInvoice,
  });

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

  @override
  Widget build(BuildContext context) {
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
                  controller: mgtChargeController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(
                    labelText: 'Management Charge (Optional)',
                    hintText: isMgtChargePercent
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
                isSelected: [isMgtChargePercent, !isMgtChargePercent],
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
                onPressed: (index) {
                  onMgtChargePercentChanged(index == 0);
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
                  controller: discountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(
                    labelText: 'Discount (Optional)',
                    hintText: isDiscountPercent
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
                isSelected: [isDiscountPercent, !isDiscountPercent],
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
                onPressed: (index) {
                  onDiscountPercentChanged(index == 0);
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

          // Advance Received (Optional)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: advanceReceivedController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(
                    labelText: 'Advance Received (Optional)',
                    hintText: 'e.g. 10000',
                    isDense: true,
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.payments_outlined, size: 18),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: advanceRefNoController,
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(
                    labelText: 'Ref / Receipt No.',
                    hintText: 'e.g. RCP-001',
                    isDense: true,
                    filled: true,
                    fillColor: colorScheme.surface,
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
                  selected: vatOption == VatOption.noVat,
                  selectedColor: colorScheme.surfaceContainerHighest,
                  onSelected: (selected) {
                    if (selected) {
                      onVatOptionChanged(VatOption.noVat);
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
                  selected: vatOption == VatOption.vat13,
                  selectedColor: Colors.green.shade100,
                  labelStyle: TextStyle(
                    color: vatOption == VatOption.vat13 ? Colors.green.shade900 : null,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      onVatOptionChanged(VatOption.vat13);
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
                  selected: vatOption == VatOption.custom,
                  onSelected: (selected) {
                    if (selected) {
                      onVatOptionChanged(VatOption.custom);
                    }
                  },
                ),
              ),
            ],
          ),

          if (vatOption == VatOption.custom) ...[
            const SizedBox(height: 10),
            TextField(
              controller: vatRateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => onChanged(),
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
                    context, 'Subtotal', '$currencyLabel ${totalRevenue.toStringAsFixed(0)}'),
                if (managementChargeAmount > 0)
                  _summarySummaryRow(
                    context,
                    isMgtChargePercent
                        ? 'Management Charge (${mgtChargeController.text.trim()}%)'
                        : 'Management Charge',
                    '+ $currencyLabel ${managementChargeAmount.toStringAsFixed(0)}',
                    color: Colors.blue.shade700,
                  ),
                if (discountAmount > 0)
                  _summarySummaryRow(
                    context,
                    isDiscountPercent
                        ? 'Discount (${discountController.text.trim()}%)'
                        : 'Discount',
                    '- $currencyLabel ${discountAmount.toStringAsFixed(0)}',
                    color: Colors.orange.shade800,
                  ),
                _summarySummaryRow(
                  context,
                  'Total',
                  '$currencyLabel ${netTotalRevenue.toStringAsFixed(0)}',
                  isBold: true,
                ),
                if (vatAmount > 0)
                  _summarySummaryRow(
                    context,
                    'VAT (${(effectiveVatRate * 100).toStringAsFixed(0)}%)',
                    '+ $currencyLabel ${vatAmount.toStringAsFixed(0)}',
                    color: Colors.green.shade800,
                  ),
                const Divider(height: 12),
                _summarySummaryRow(
                  context,
                  'Grand Total',
                  '$currencyLabel ${grandTotalRevenue.toStringAsFixed(0)}',
                  isBold: true,
                  fontSize: 15,
                  color: colorScheme.primary,
                ),
                if ((double.tryParse(advanceReceivedController.text.trim()) ?? 0) > 0) ...[
                  const SizedBox(height: 4),
                  _summarySummaryRow(
                    context,
                    advanceRefNoController.text.trim().isNotEmpty
                        ? 'Advance Received (${advanceRefNoController.text.trim()})'
                        : 'Advance Received',
                    '- $currencyLabel ${(double.tryParse(advanceReceivedController.text.trim()) ?? 0).toStringAsFixed(0)}',
                    color: Colors.teal.shade700,
                  ),
                  const Divider(height: 10),
                  _summarySummaryRow(
                    context,
                    'Balance Due',
                    '$currencyLabel ${(grandTotalRevenue - (double.tryParse(advanceReceivedController.text.trim()) ?? 0)).toStringAsFixed(0)}',
                    isBold: true,
                    fontSize: 15,
                    color: Colors.deepOrange.shade700,
                  ),
                ],
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
                  onPressed: onPreviewPdf,
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
                  onPressed: onSharePdf,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
