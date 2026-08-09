import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/services/order_pdf_service.dart';
import 'package:order_app/core/utils/excel_export_helper.dart';
import 'package:order_app/core/utils/share_helper.dart';
import 'package:order_app/domain/entities/expense_entity.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/screens/common/utility/pdf_preview_screen.dart';
import 'package:order_app/presentation/widgets/revenue_breakdown/revenue_calculations.dart';

class ExpenseActionsHelper {
  static void showPdfOptions(
    BuildContext context, {
    required bool includeItems,
    required ValueChanged<bool> onIncludeItemsChanged,
    required VoidCallback onPrintOrSave,
    required VoidCallback onShare,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    bool localIncludeItems = includeItems;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Expense PDF',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: const Text(
                    'Include item vendor costs',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    localIncludeItems
                        ? 'Item-based vendor costs will appear in PDF'
                        : 'Only additional expenses will appear in PDF',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                  value: localIncludeItems,
                  onChanged: (val) {
                    setSheetState(() => localIncludeItems = val);
                    onIncludeItemsChanged(val);
                  },
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.print_outlined, color: colorScheme.primary),
                ),
                title: const Text('Print / Save', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Open print dialog to save or print'),
                onTap: () {
                  Navigator.pop(ctx);
                  onPrintOrSave();
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.share_outlined, color: Colors.green),
                ),
                title: const Text('Share', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Share PDF via WhatsApp, email, etc.'),
                onTap: () {
                  Navigator.pop(ctx);
                  onShare();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> executeExpensePdf({
    required BuildContext context,
    required OrderEntity order,
    required String orderDescription,
    required List<OrderItemEntity> items,
    required Map<String, TextEditingController> itemControllers,
    required List<ExpenseEntity> manualExpenses,
    required bool share,
    required bool includeItems,
  }) async {
    if (manualExpenses.isEmpty && (!includeItems || items.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expenses or items to export')),
      );
      return;
    }

    String progressMessage = 'Generating Expenses Summary PDF…';
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
      final updatedItems = items.map((item) {
        final rate = double.tryParse(itemControllers[item.id]?.text ?? '') ?? 0.0;
        final double amount;
        if (item.billingType == 'event') {
          amount = rate * item.quantity;
        } else {
          amount = rate * item.quantity * item.days;
        }
        return item.copyWith(vendorRate: rate, vendorAmount: amount);
      }).toList();

      final pdfData = await OrderPdfService.generateExpensePdf(
        order: order.copyWith(description: orderDescription.trim()),
        expenses: manualExpenses,
        items: updatedItems,
        includeItems: includeItems,
        onProgress: (status) {
          setSnackBarState(() => progressMessage = status);
        },
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final fileName = 'Expenses_Summary_${order.id}_${order.venue.replaceAll(RegExp(r'[ ,]+'), '_')}.pdf';

      if (share) {
        await ShareHelper.sharePdf(
          context: context,
          pdfBytes: pdfData,
          fileName: fileName,
          subject: 'Expenses Summary',
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(
              pdfData: pdfData,
              title: 'Expenses Summary',
              fileName: fileName,
            ),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('PDF generation error [expense_breakdown]: $e\n$st');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<void> generateExpenseExcel({
    required BuildContext context,
    required OrderEntity order,
    required List<OrderItemEntity> items,
    required Map<String, TextEditingController> itemControllers,
    required List<ExpenseEntity> manualExpenses,
  }) async {
    if (manualExpenses.isEmpty &&
        items.every((item) => (double.tryParse(itemControllers[item.id]?.text ?? '') ?? 0.0) == 0)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No expenses to export')));
      return;
    }

    final headers = [
      'Type',
      'Description',
      'Vendor',
      'Category',
      'Rate (NPR)',
      'Quantity',
      'Days',
      'Amount (NPR)',
    ];

    final rows = <List<dynamic>>[];

    for (var item in items) {
      final rate = double.tryParse(itemControllers[item.id]?.text ?? '') ?? 0.0;
      if (rate > 0) {
        rows.add([
          'Item Cost',
          item.itemName,
          item.vendor,
          'Vendor Payable',
          rate,
          item.quantity,
          item.days,
          rate * item.quantity * item.days,
        ]);
      }
    }

    for (var expense in manualExpenses) {
      rows.add([
        'Manual Expense',
        expense.description,
        expense.vendorName ?? '',
        expense.category,
        expense.rate,
        expense.quantity,
        expense.days,
        expense.amount,
      ]);
    }

    final fileName = 'Expense_Breakdown_${order.id}.xlsx';

    await ExcelExportHelper.exportAndShareExcel(
      context: context,
      headers: headers,
      rows: rows,
      filename: fileName,
      sheetName: 'Expenses',
      title: 'Expense Breakdown Statement - ${order.eventName}',
    );
  }

  static Future<void> finalizeExpenses({
    required BuildContext context,
    required WidgetRef ref,
    required OrderEntity order,
    required String orderDescription,
    required double totalExpenses,
    required String currencyLabel,
    required List<OrderItemEntity> items,
    required Map<String, TextEditingController> itemControllers,
    required Map<String, TextEditingController> itemQtyControllers,
    required Map<String, TextEditingController> itemDaysControllers,
    required List<ExpenseEntity> manualExpenses,
  }) async {
    bool? proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        title: const Text('Finalize Expenses?'),
        content: Text(
          'This will update the total expenses to $currencyLabel ${totalExpenses.toStringAsFixed(0)}. Do you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
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

    if (proceed != true) return;

    final updatedItems = items.map((item) {
      final rate = RevenueCalculations.parseRate(itemControllers[item.id]?.text, item.vendorRate);
      final qty = RevenueCalculations.parseQuantity(itemQtyControllers[item.id]?.text, item.quantity);
      final days = RevenueCalculations.parseDays(itemDaysControllers[item.id]?.text, item.days);
      final double amount;
      if (item.billingType == 'event') {
        amount = rate * qty;
      } else {
        amount = rate * qty * days;
      }
      return item.copyWith(
        vendorRate: rate,
        quantity: qty,
        days: days,
        vendorAmount: amount,
      );
    }).toList();

    final updatedOrder = order.copyWith(
      totalExpenses: totalExpenses,
      description: orderDescription.trim(),
    );

    try {
      await ref
          .read(orderNotifierProvider.notifier)
          .finalizeExpenses(updatedOrder, manualExpenses, updatedItems);

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expenses finalized successfully'),
            backgroundColor: Color(0xFF10b981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to finalize expenses: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
