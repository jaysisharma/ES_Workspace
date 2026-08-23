import 'package:flutter/material.dart';

class ExpenseFinancialsCardWidget extends StatelessWidget {
  final double itemTotalExpenses;
  final double manualTotalExpenses;
  final double totalExpenses;
  final String currencyLabel;
  final VoidCallback onPreviewPdf;
  final VoidCallback onFinalize;

  const ExpenseFinancialsCardWidget({
    super.key,
    required this.itemTotalExpenses,
    required this.manualTotalExpenses,
    required this.totalExpenses,
    required this.currencyLabel,
    required this.onPreviewPdf,
    required this.onFinalize,
  });

  Widget _summaryRow(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 13,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'EXPENSE SUMMARY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Summary breakdown
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                _summaryRow(
                  context,
                  'Item-Based Vendor Costs',
                  '$currencyLabel ${itemTotalExpenses.toStringAsFixed(0)}',
                ),
                _summaryRow(
                  context,
                  'Additional / Manual Expenses',
                  '$currencyLabel ${manualTotalExpenses.toStringAsFixed(0)}',
                ),
                const Divider(height: 14),
                _summaryRow(
                  context,
                  'Total Expenses',
                  '$currencyLabel ${totalExpenses.toStringAsFixed(0)}',
                  isBold: true,
                  fontSize: 16,
                  color: Colors.red.shade700,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Preview / Share Expense PDF Action Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.preview_rounded, size: 18),
              label: const Text(
                'PREVIEW / SHARE EXPENSE PDF',
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
              onPressed: onPreviewPdf,
            ),
          ),

          const SizedBox(height: 10),

          // Finalize Expenses Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text(
                'FINALIZE EXPENSES',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onFinalize,
            ),
          ),
        ],
      ),
    );
  }
}
