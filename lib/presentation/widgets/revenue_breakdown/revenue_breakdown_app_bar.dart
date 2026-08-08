import 'package:flutter/material.dart';

class RevenueBreakdownAppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final Color bgColor;
  final Color textColor;
  final Color borderColor;
  final Color primaryColor;
  final VoidCallback onSave;
  final VoidCallback onPdf;

  const RevenueBreakdownAppBarWidget({
    super.key,
    required this.bgColor,
    required this.textColor,
    required this.borderColor,
    required this.primaryColor,
    required this.onSave,
    required this.onPdf,
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
        'Revenue Breakdown',
        style: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.save_outlined, color: primaryColor),
          onPressed: onSave,
          tooltip: 'Save Breakdown',
        ),
        IconButton(
          icon: Icon(Icons.picture_as_pdf_outlined, color: primaryColor),
          onPressed: onPdf,
          tooltip: 'Revenue PDF',
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
