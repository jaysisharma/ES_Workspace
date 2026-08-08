import 'package:flutter/material.dart';

class ExpenseTotalsCardWidget extends StatelessWidget {
  final double manualTotalExpenses;
  final double itemTotalExpenses;
  final double totalExpenses;
  final Color backgroundColor;
  final Color borderColor;
  final Color labelColor;
  final Color primaryColor;
  final String currencyLabel;
  final VoidCallback onFinalize;

  const ExpenseTotalsCardWidget({
    super.key,
    required this.manualTotalExpenses,
    required this.itemTotalExpenses,
    required this.totalExpenses,
    required this.backgroundColor,
    required this.borderColor,
    required this.labelColor,
    required this.primaryColor,
    required this.currencyLabel,
    required this.onFinalize,
  });

  @override
  Widget build(BuildContext context) {
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
                  '$currencyLabel ${totalExpenses.toStringAsFixed(0)}',
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
                onPressed: onFinalize,
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
