import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import '../../../domain/entities/inventory_entity.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/settings_provider.dart';
import 'add_edit_inventory_screen.dart';

class InventoryManagementScreen extends ConsumerStatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  ConsumerState<InventoryManagementScreen> createState() =>
      _InventoryManagementScreenState();
}

class _InventoryManagementScreenState
    extends ConsumerState<InventoryManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'ALL',
    'Sound',
    'Lighting',
    'Stage',
    'Decor',
    'AV Equipment',
    'Catering',
    'Furniture',
    'General',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final inventoryState = ref.watch(inventoryNotifierProvider);
    final settings = ref.watch(settingsProvider);
    final currencySymbol = settings.currency.split(' ').first;

    final allItems = inventoryState.items;
    final filteredItems = inventoryState.filteredItems;

    final totalItemsCount = allItems.length;
    final totalUnits = allItems.fold<int>(0, (sum, i) => sum + i.totalQuantity);
    final availUnits = allItems.fold<int>(0, (sum, i) => sum + i.availableQuantity);
    final lowStockCount = allItems.where((i) => i.isLowStock || i.status == 'Low Stock').length;
    final outOfStockCount = allItems.where((i) => i.isOutOfStock || i.status == 'Out of Stock').length;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Inventory Management',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Inventory',
            onPressed: () {
              ref.read(inventoryNotifierProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(inventoryNotifierProvider.notifier).refresh();
        },
        child: Column(
          children: [
            // Search Bar & Filter Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    ref.read(inventoryNotifierProvider.notifier).setSearchQuery(val);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search equipment by name, SKU, or location...',
                    hintStyle: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                    prefixIcon: Icon(Icons.search_rounded, color: colorScheme.primary, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(inventoryNotifierProvider.notifier).setSearchQuery('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            // Category Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = inventoryState.selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          ref.read(inventoryNotifierProvider.notifier).setCategory(cat);
                        }
                      },
                      selectedColor: colorScheme.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : colorScheme.onSurface,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 8),

            // Metrics Summary Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricCol('Items', totalItemsCount.toString(), Icons.inventory_2, colorScheme.primary),
                    _buildMetricDivider(colorScheme),
                    _buildMetricCol('In Stock', '$availUnits / $totalUnits', Icons.check_circle_outline, Colors.green),
                    _buildMetricDivider(colorScheme),
                    _buildMetricCol('Low Stock', lowStockCount.toString(), Icons.warning_amber_rounded, Colors.orange),
                    _buildMetricDivider(colorScheme),
                    _buildMetricCol('Out of Stock', outOfStockCount.toString(), Icons.remove_circle_outline, Colors.red),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Inventory Item List
            Expanded(
              child: inventoryState.isLoading && allItems.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 64, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              Text(
                                'No inventory items found',
                                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Click + button below to add your equipment or stock',
                                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return _buildInventoryCard(context, ref, item, currencySymbol);
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'inventory_management_fab',
        onPressed: () {
          Navigator.push(
            context,
            SlidePageRoute(page: const AddEditInventoryScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('ADD ITEM', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMetricDivider(ColorScheme colorScheme) {
    return Container(
      height: 24,
      width: 1,
      color: colorScheme.outline.withValues(alpha: 0.2),
    );
  }

  Widget _buildInventoryCard(
      BuildContext context, WidgetRef ref, InventoryItemEntity item, String currencySymbol) {
    final colorScheme = Theme.of(context).colorScheme;

    Color statusColor;
    IconData statusIcon;
    if (item.availableQuantity <= 0 || item.status == 'Out of Stock') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel_outlined;
    } else if (item.isLowStock || item.status == 'Low Stock') {
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber_rounded;
    } else if (item.status == 'Maintenance') {
      statusColor = Colors.purple;
      statusIcon = Icons.build_circle_outlined;
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
    }

    final double availRatio = item.totalQuantity > 0 ? (item.availableQuantity / item.totalQuantity).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getCategoryIcon(item.category),
                  color: colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (item.sku.isNotEmpty) ...[
                          Text(
                            'SKU: ${item.sku}',
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 8),
                          Text('•', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          item.category,
                          style: TextStyle(fontSize: 11, color: colorScheme.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      item.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Stock Quantity Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available Stock: ${item.availableQuantity} of ${item.totalQuantity} units',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${(availRatio * 100).toInt()}%',
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: availRatio,
                  minHeight: 6,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Footer info & Stock Adjustment Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.rentalRatePerDay > 0)
                    Text(
                      '$currencySymbol ${item.rentalRatePerDay.toStringAsFixed(0)} / day',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.secondary),
                    ),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 12, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 2),
                      Text(
                        item.location,
                        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  // Minus Button
                  IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.remove, size: 16),
                    onPressed: item.availableQuantity > 0
                        ? () {
                            ref.read(inventoryNotifierProvider.notifier).adjustStock(item.id, -1);
                          }
                        : null,
                  ),
                  const SizedBox(width: 4),
                  // Plus Button
                  IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add, size: 16),
                    onPressed: () {
                      ref.read(inventoryNotifierProvider.notifier).adjustStock(item.id, 1);
                    },
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    onSelected: (action) async {
                      if (action == 'edit') {
                        Navigator.push(
                          context,
                          SlidePageRoute(page: AddEditInventoryScreen(item: item)),
                        );
                      } else if (action == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Item?'),
                            content: Text('Are you sure you want to delete "${item.name}" from inventory?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          ref.read(inventoryNotifierProvider.notifier).deleteInventoryItem(item.id);
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit Item')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'sound':
        return Icons.speaker_group;
      case 'lighting':
        return Icons.lightbulb_outlined;
      case 'stage':
        return Icons.theater_comedy;
      case 'decor':
        return Icons.palette_outlined;
      case 'av equipment':
        return Icons.videocam_outlined;
      case 'catering':
        return Icons.restaurant;
      case 'furniture':
        return Icons.chair_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }
}
