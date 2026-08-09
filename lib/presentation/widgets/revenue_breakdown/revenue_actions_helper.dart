import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/services/order_pdf_service.dart';
import 'package:order_app/domain/entities/expense_entity.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/screens/common/utility/pdf_preview_screen.dart';
import 'package:order_app/core/utils/share_helper.dart';
import 'package:order_app/presentation/widgets/revenue_breakdown/revenue_calculations.dart';

class RevenueActionsHelper {
  static Future<void> executeRevenuePdf({
    required BuildContext context,
    required OrderEntity order,
    required String orderDescription,
    required List<OrderItemEntity> items,
    required Map<String, TextEditingController> itemControllers,
    required Map<String, TextEditingController> itemQtyControllers,
    required Map<String, TextEditingController> itemDaysControllers,
    required List<ExpenseEntity> manualRevenues,
    required double managementChargeAmount,
    required double managementChargeRate,
    required double discountAmount,
    required double discountRate,
    required double effectiveVatRate,
    required bool share,
    double advanceReceived = 0.0,
    String advanceReferenceNo = '',
  }) async {
    if (items.isEmpty && manualRevenues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No revenue items to export')),
      );
      return;
    }

    String progressMessage = 'Generating Revenue Summary PDF…';
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
        final rate = RevenueCalculations.parseRate(itemControllers[item.id]?.text, item.rate);
        final qty = RevenueCalculations.parseQuantity(itemQtyControllers[item.id]?.text, item.quantity);
        final days = RevenueCalculations.parseDays(itemDaysControllers[item.id]?.text, item.days);
        final double amount;
        if (item.billingType == 'event') {
          amount = rate * qty;
        } else {
          amount = rate * qty * days;
        }
        return item.copyWith(
          rate: rate,
          quantity: qty,
          days: days,
          amount: amount,
        );
      }).toList();

      final pdfData = await OrderPdfService.generateOrderPdf(
        order: order.copyWith(description: orderDescription.trim()),
        items: updatedItems,
        additionalRevenue: manualRevenues,
        showFinancials: true,
        managementCharge: managementChargeAmount,
        managementChargeRate: managementChargeRate,
        discount: discountAmount,
        discountRate: discountRate,
        vatRate: effectiveVatRate,
        advanceReceived: advanceReceived,
        advanceReferenceNo: advanceReferenceNo,
        onProgress: (status) {
          setSnackBarState(() => progressMessage = status);
        },
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final fileName = 'Revenue_Summary_${order.id}_${order.venue.replaceAll(RegExp(r'[ ,]+'), '_')}.pdf';

      if (share) {
        await ShareHelper.sharePdf(
          context: context,
          pdfBytes: pdfData,
          fileName: fileName,
          subject: 'Revenue Summary',
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(
              pdfData: pdfData,
              title: 'Revenue Summary',
              fileName: fileName,
            ),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('PDF generation error [revenue_breakdown]: $e\n$st');
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

  static Future<List<OrderItemEntity>?> save({
    required BuildContext context,
    required WidgetRef ref,
    required OrderEntity order,
    required String orderDescription,
    required List<OrderItemEntity> items,
    required Map<String, TextEditingController> itemControllers,
    required Map<String, TextEditingController> itemQtyControllers,
    required Map<String, TextEditingController> itemDaysControllers,
    required List<ExpenseEntity> manualRevenues,
    required double totalRevenue,
    required double effectiveVatRate,
    double managementCharge = 0.0,
    bool isMgtChargePercent = true,
    double discount = 0.0,
    bool isDiscountPercent = true,
    double advanceReceived = 0.0,
    String advanceReferenceNo = '',
  }) async {
    final updatedItems = items.map((item) {
      final rate = RevenueCalculations.parseRate(itemControllers[item.id]?.text, item.rate);
      final qty = RevenueCalculations.parseQuantity(itemQtyControllers[item.id]?.text, item.quantity);
      final days = RevenueCalculations.parseDays(itemDaysControllers[item.id]?.text, item.days);
      final double amount;
      if (item.billingType == 'event') {
        amount = rate * qty;
      } else {
        amount = rate * qty * days;
      }
      return item.copyWith(
        rate: rate,
        quantity: qty,
        days: days,
        amount: amount,
      );
    }).toList();

    final updatedOrder = order.copyWith(
      totalAmount: totalRevenue,
      vatRate: effectiveVatRate,
      description: orderDescription.trim(),
      managementCharge: managementCharge,
      isMgtChargePercent: isMgtChargePercent,
      discount: discount,
      isDiscountPercent: isDiscountPercent,
      advanceReceived: advanceReceived,
      advanceReferenceNo: advanceReferenceNo,
    );

    debugPrint('=== [REVENUE SAVE DEBUG] ===');
    debugPrint('Order ID: ${order.id}');
    debugPrint('Description: ${orderDescription.trim()}');
    debugPrint('Management Charge: $managementCharge (isPercent: $isMgtChargePercent)');
    debugPrint('Discount: $discount (isPercent: $isDiscountPercent)');
    debugPrint('VAT Rate: $effectiveVatRate');
    debugPrint('Advance Received: $advanceReceived (Ref: $advanceReferenceNo)');
    debugPrint('Total Revenue: $totalRevenue');
    for (final item in updatedItems) {
      debugPrint('Item "${item.itemName}" (ID: ${item.id}): rate=${item.rate}, qty=${item.quantity}, days=${item.days}, amount=${item.amount}');
    }
    debugPrint('===========================');

    try {
      await ref
          .read(orderNotifierProvider.notifier)
          .finalizeRevenue(updatedOrder, updatedItems, manualRevenues);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Revenue breakdown saved successfully'),
            backgroundColor: Color(0xFF10b981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return updatedItems;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save revenue breakdown: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    }
  }

  static Future<void> confirmFinalize({
    required BuildContext context,
    required WidgetRef ref,
    required OrderEntity order,
    required String orderDescription,
    required List<OrderItemEntity> items,
    required Map<String, TextEditingController> itemControllers,
    required Map<String, TextEditingController> itemQtyControllers,
    required Map<String, TextEditingController> itemDaysControllers,
    required List<ExpenseEntity> manualRevenues,
    required double totalRevenue,
    required double grandTotalRevenue,
    required double effectiveVatRate,
    required String currencyLabel,
    double managementCharge = 0.0,
    bool isMgtChargePercent = true,
    double discount = 0.0,
    bool isDiscountPercent = true,
    double advanceReceived = 0.0,
    String advanceReferenceNo = '',
  }) async {
    bool? proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        title: const Text('Finalize Revenue Breakdown?'),
        content: Text(
          'This will update the order total to $currencyLabel ${grandTotalRevenue.toStringAsFixed(0)}. Do you want to proceed?',
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

    if (!context.mounted) return;
    await save(
      context: context,
      ref: ref,
      order: order,
      orderDescription: orderDescription,
      items: items,
      itemControllers: itemControllers,
      itemQtyControllers: itemQtyControllers,
      itemDaysControllers: itemDaysControllers,
      manualRevenues: manualRevenues,
      totalRevenue: grandTotalRevenue,
      effectiveVatRate: effectiveVatRate,
      managementCharge: managementCharge,
      isMgtChargePercent: isMgtChargePercent,
      discount: discount,
      isDiscountPercent: isDiscountPercent,
      advanceReceived: advanceReceived,
      advanceReferenceNo: advanceReferenceNo,
    );

    if (context.mounted) {
      Navigator.pop(context);
    }
  }
}
