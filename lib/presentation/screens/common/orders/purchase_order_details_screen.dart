import 'package:flutter/material.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/purchase_order_entity.dart';
import 'package:order_app/presentation/providers/purchase_order_providers.dart';
import 'package:order_app/core/services/order_pdf_service.dart';
import 'package:order_app/presentation/screens/common/orders/create_purchase_order_screen.dart';
import 'package:order_app/presentation/screens/common/utility/pdf_preview_screen.dart';

class PurchaseOrderDetailsScreen extends ConsumerWidget {
  final PurchaseOrderEntity po;

  const PurchaseOrderDetailsScreen({super.key, required this.po});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Purchase Order Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share PDF',
            onPressed: () => _sharePdf(context),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit PO',
            onPressed: () {
              Navigator.push(
                context,
                SlidePageRoute(page: CreatePurchaseOrderScreen(existingPO: po)),
              ).then((_) {
                // Return to list after edit, or we could pop to refresh.
                // For now, simpler to just pop back to list since the details
                // might be stale. Or we can pop until list.
                if (!context.mounted) return;
                Navigator.pop(context);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            tooltip: 'Delete PO',
            onPressed: () => _showDeleteDialog(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderCard(colorScheme, isDark),
            const SizedBox(height: 16),
            _buildEventDetailsCard(colorScheme, isDark),
            const SizedBox(height: 16),
            _buildItemsList(colorScheme, isDark),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ColorScheme colorScheme, bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
      ),
      color: isDark
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
          : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long,
                size: 32,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              po.poNumber.isEmpty ? 'Draft PO' : po.poNumber,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              po.vendorName,
              style: TextStyle(
                fontSize: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (po.orderId.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Order: ${po.orderId}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEventDetailsCard(ColorScheme colorScheme, bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
      ),
      color: isDark
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
          : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EVENT DETAILS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              Icons.event,
              'Event Name',
              po.eventName,
              colorScheme,
            ),
            const Divider(height: 24),
            _buildDetailRow(Icons.location_on, 'Venue', po.venue, colorScheme),
            const Divider(height: 24),
            _buildDetailRow(
              Icons.calendar_today,
              'Event Dates',
              _formatDateRange(po.eventDate, po.eventEndDate),
              colorScheme,
            ),
            const Divider(height: 24),
            _buildDetailRow(
              Icons.build_circle,
              'Setup Dates',
              _formatDateRange(po.setupDate, po.setupEndDate),
              colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    ColorScheme colorScheme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value.isEmpty ? 'Not specified' : value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemsList(ColorScheme colorScheme, bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
      ),
      color: isDark
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
          : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ITEMIZED BREAKDOWN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            ...po.items.asMap().entries.map((e) {
              final index = e.key + 1;
              final item = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$index.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.itemName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Text(
                                'Rs. ${item.amount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (item.specification.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.specification,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            '${item.quantity} qty x ${item.days} days x Rs. ${item.rate.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 32, thickness: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SUBTOTAL',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(
                  'Rs. ${po.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (po.vatRate > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'VAT (${(po.vatRate * 100).toStringAsFixed(0)}%)',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Rs. ${(po.totalAmount * po.vatRate).toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'GRAND TOTAL',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Rs. ${po.totalWithVat.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateRange(DateTime start, DateTime? end) {
    if (end == null) {
      return formatNepaliDate(start, 'MMM dd, yyyy');
    }
    if (start.year == end.year) {
      if (start.month == end.month && start.day == end.day) {
        return formatNepaliDate(start, 'MMM dd, yyyy');
      }
      return '${formatNepaliDate(start, 'MMM dd')} - ${formatNepaliDate(end, 'MMM dd, yyyy')}';
    }
    return '${formatNepaliDate(start, 'MMM dd, yyyy')} - ${formatNepaliDate(end, 'MMM dd, yyyy')}';
  }

  Future<void> _sharePdf(BuildContext context) async {
    try {
      final pdfBytes = await OrderPdfService.generateVendorPurchaseOrderPdf(
        po: po,
      );
      final filename = 'Purchase_${po.poNumber.isEmpty ? "DRAFT" : po.poNumber.replaceAll(' ', '_')}_${po.venue.replaceAll(RegExp(r'[ ,]+'), '_')}.pdf';

      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            pdfData: pdfBytes,
            title: 'Purchase Order PDF',
            fileName: filename,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Purchase Order?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(purchaseOrderNotifierProvider.notifier).delete(po.id);
              Navigator.pop(ctx); // pop dialog
              Navigator.pop(context); // pop details screen
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
