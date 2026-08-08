import 'package:flutter/material.dart';

class ExpenseBreakdownAppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final Color bgColor;
  final Color textColor;
  final Color borderColor;
  final Color primaryColor;
  final VoidCallback onExportExcel;
  final VoidCallback onPdfOptions;

  const ExpenseBreakdownAppBarWidget({
    super.key,
    required this.bgColor,
    required this.textColor,
    required this.borderColor,
    required this.primaryColor,
    required this.onExportExcel,
    required this.onPdfOptions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
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
          onPressed: onExportExcel,
          tooltip: 'Export Excel Report',
        ),
        IconButton(
          icon: Icon(Icons.picture_as_pdf_outlined, color: primaryColor),
          onPressed: onPdfOptions,
          tooltip: 'Expense PDF',
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(color: borderColor, height: 1),
      ),
    );
  }
}
