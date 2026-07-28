import 'package:flutter/material.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/nepali_date_formatter.dart';
import '../../providers/purchase_order_providers.dart';
import 'create_purchase_order_screen.dart';
import 'purchase_order_details_screen.dart';

class PurchaseOrderListScreen extends ConsumerWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posAsync = ref.watch(purchaseOrdersStreamProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Orders')),
      body: posAsync.when(
        data: (pos) {
          if (pos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Purchase Orders found',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      SlidePageRoute(page: const CreatePurchaseOrderScreen()),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Your First PO'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(purchaseOrdersStreamProvider);
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: pos.length,
              itemBuilder: (context, index) {
                final po = pos[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      po.vendorName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'PO #: ${po.poNumber}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          'Event: ${po.eventName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          'Date: ${formatNepaliDate(po.createdAt, 'MMM dd, yyyy')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Rs. ${po.totalWithVat.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      SlidePageRoute(page: PurchaseOrderDetailsScreen(po: po)),
                    ),
                    onLongPress: () => _showDeleteDialog(context, ref, po.id),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          SlidePageRoute(page: const CreatePurchaseOrderScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Purchase Order?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(purchaseOrderNotifierProvider.notifier).delete(id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
