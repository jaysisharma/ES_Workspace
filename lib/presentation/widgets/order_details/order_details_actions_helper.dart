import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/services/order_pdf_service.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/presentation/providers/event_notifier.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/screens/common/utility/pdf_preview_screen.dart';

class OrderDetailsActionsHelper {
  static Future<void> sharePdf({
    required BuildContext context,
    required OrderEntity order,
    required List<OrderItemEntity> items,
  }) async {
    String progressMessage = 'Preparing PDF to share…';
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
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
      final pdf = await OrderPdfService.generateOrderPdf(
        order: order,
        items: items,
        showFinancials: false,
        onProgress: (status) {
          if (context.mounted) {
            setSnackBarState(() {
              progressMessage = status;
            });
          }
        },
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final fileName =
          'Order_${order.id}_${order.venue.replaceAll(RegExp(r'[ ,]+'), '_')}.pdf';
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            pdfData: pdf,
            title: 'Order Summary PDF',
            fileName: fileName,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('PDF generation error [order_details]: $e\n$st');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share PDF: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      );
    }
  }

  static Future<void> handleDeleteOrder({
    required BuildContext context,
    required WidgetRef ref,
    required String? eventId,
    required String orderId,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: const Text(
          'Are you sure you want to delete this order? This will also delete all associated items and any linked event. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Order'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deleting...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      await ref
          .read(orderItemNotifierProvider.notifier)
          .deleteItemsForOrder(orderId);

      await ref.read(orderNotifierProvider.notifier).delete(orderId);

      bool eventDeleteOk = true;
      if (eventId != null) {
        eventDeleteOk = await ref
            .read(eventNotifierProvider.notifier)
            .deleteEvent(eventId);
      }

      if (context.mounted) {
        if (eventDeleteOk) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Order deleted successfully'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
          );
          Navigator.pop(context);
        } else {
          final error = ref.read(eventNotifierProvider).errorMessage;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${error ?? 'Failed to complete deletion'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
