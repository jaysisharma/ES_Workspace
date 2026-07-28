import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/nepali_date_formatter.dart';
import '../../../domain/entities/purchase_order_entity.dart';
import '../../../domain/entities/order_item_entity.dart';
import '../../providers/purchase_order_providers.dart';
import '../../providers/order_providers.dart';

class CreatePurchaseOrderScreen extends ConsumerStatefulWidget {
  final PurchaseOrderEntity? existingPO;
  final String? initialOrderId;
  final String? initialVendorName;

  const CreatePurchaseOrderScreen({
    super.key,
    this.existingPO,
    this.initialOrderId,
    this.initialVendorName,
  });

  @override
  ConsumerState<CreatePurchaseOrderScreen> createState() =>
      _CreatePurchaseOrderScreenState();
}

class _POItemRow {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController specController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController daysController = TextEditingController(text: '1');
  final TextEditingController rateController = TextEditingController(text: '0');
  final TextEditingController unitController = TextEditingController(
    text: 'Pcs',
  );
  String billingType = 'daily';

  void dispose() {
    nameController.dispose();
    specController.dispose();
    qtyController.dispose();
    daysController.dispose();
    rateController.dispose();
    unitController.dispose();
  }
}

class _CreatePurchaseOrderScreenState
    extends ConsumerState<CreatePurchaseOrderScreen> {
  final _poNumberController = TextEditingController();
  final _orderIdController = TextEditingController();
  final _vendorNameController = TextEditingController();
  final _eventNameController = TextEditingController();
  final _venueController = TextEditingController();

  DateTime _eventDate = DateTime.now();
  DateTime? _eventEndDate;
  DateTime _setupDate = DateTime.now();
  DateTime? _setupEndDate;

  final List<_POItemRow> _items = [_POItemRow()];
  bool _isSaving = false;
  double _vatRate = 0.0;
  List<String> _orderVendors = [];
  List<OrderItemEntity> _orderItems = [];

  @override
  void initState() {
    super.initState();

    if (widget.existingPO != null) {
      final po = widget.existingPO!;
      _poNumberController.text = po.poNumber;
      _orderIdController.text = po.orderId;
      _vendorNameController.text = po.vendorName;
      _eventNameController.text = po.eventName;
      _venueController.text = po.venue;
      _eventDate = po.eventDate;
      _eventEndDate = po.eventEndDate;
      _setupDate = po.setupDate;
      _setupEndDate = po.setupEndDate;
      _vatRate = po.vatRate;

      _items.clear();
      for (final item in po.items) {
        final row = _POItemRow();
        row.nameController.text = item.itemName;
        row.specController.text = item.specification;
        row.qtyController.text = item.quantity.toString();
        row.daysController.text = item.days.toString();
        row.rateController.text = item.rate.toStringAsFixed(0);
        row.unitController.text = item.unit;
        row.billingType = item.billingType;
        _addItemListeners(row);
        _items.add(row);
      }
    } else {
      _poNumberController.text = ''; // Allow manual entry
      _orderIdController.text = widget.initialOrderId ?? '';
      _vendorNameController.text = widget.initialVendorName ?? '';

      // Add listener to the initial item
      _addItemListeners(_items.first);

      // Add listener to Order ID to auto-fetch details
      _orderIdController.addListener(() {
        final orderId = _orderIdController.text.trim();
        if (orderId.isNotEmpty) {
          _fetchOrderDetails(orderId);
        }
      });

      // If initialOrderId is provided, try to fetch order details to pre-fill
      if (widget.initialOrderId != null) {
        Future.microtask(() => _fetchOrderDetails(widget.initialOrderId!));
      }
    }
  }

  void _addItemListeners(_POItemRow row) {
    row.nameController.addListener(_onItemChanged);
    row.qtyController.addListener(_onItemChanged);
    row.daysController.addListener(_onItemChanged);
    row.rateController.addListener(_onItemChanged);
  }

  void _onItemChanged() {
    setState(() {});
  }

  Future<void> _fetchOrderDetails(String orderId) async {
    // Try to find in notifier first
    final orders = ref.read(orderNotifierProvider).orders;
    var order = orders.where((o) => o.id == orderId).firstOrNull;

    // Fallback to stream value
    if (order == null) {
      final streamedOrders = ref.read(ordersStreamProvider).value;
      order = streamedOrders?.where((o) => o.id == orderId).firstOrNull;
    }

    final foundOrder = order;
    if (foundOrder != null) {
      // Fetch items to get vendors
      final allItems = ref.read(allItemsStreamProvider).value ?? [];
      final orderItems = allItems.where((i) => i.orderId == orderId).toList();
      final vendors = orderItems.map((i) => i.vendor).toSet().toList();

      setState(() {
        _eventNameController.text = foundOrder.eventName;
        _venueController.text = foundOrder.venue;
        _eventDate = foundOrder.eventDate;
        _eventEndDate = foundOrder.eventEndDate;
        _setupDate = foundOrder.setupDate;
        _setupEndDate = foundOrder.setupEndDate;
        _orderVendors = vendors;
        _orderItems = orderItems;
      });
    } else {
      setState(() {
        _orderVendors = [];
        _orderItems = [];
      });
    }
  }

  @override
  void dispose() {
    _poNumberController.dispose();
    _orderIdController.dispose();
    _vendorNameController.dispose();
    _eventNameController.dispose();
    _venueController.dispose();
    for (var item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addNewItem() {
    setState(() {
      final newRow = _POItemRow();
      _addItemListeners(newRow);
      _items.add(newRow);
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items[index].dispose();
        _items.removeAt(index);
      });
    }
  }

  Future<void> _submitPO() async {
    if (_vendorNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter vendor name')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final List<PurchaseOrderItemEntity> poItems = [];
      double total = 0;

      for (var row in _items) {
        if (row.nameController.text.isNotEmpty) {
          final qty = int.tryParse(row.qtyController.text) ?? 1;
          final days = int.tryParse(row.daysController.text) ?? 1;
          final rate = double.tryParse(row.rateController.text) ?? 0.0;
          final double amount;
          if (row.billingType == 'event') {
            amount = qty * rate;
          } else {
            amount = qty * days * rate;
          }

          poItems.add(
            PurchaseOrderItemEntity(
              id: const Uuid().v4(),
              itemName: row.nameController.text.trim(),
              specification: row.specController.text.trim(),
              quantity: qty,
              days: days,
              unit: row.unitController.text,
              billingType: row.billingType,
              rate: rate,
              amount: amount,
            ),
          );
          total += amount;
        }
      }

      final po = PurchaseOrderEntity(
        id: widget.existingPO?.id ?? const Uuid().v4(),
        poNumber: _poNumberController.text.trim(),
        orderId: _orderIdController.text.trim(),
        vendorName: _vendorNameController.text.trim(),
        eventName: _eventNameController.text.trim(),
        venue: _venueController.text.trim(),
        eventDate: _eventDate,
        eventEndDate: _eventEndDate,
        setupDate: _setupDate,
        setupEndDate: _setupEndDate,
        items: poItems,
        totalAmount: total,
        createdAt: widget.existingPO?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'draft',
        vatRate: _vatRate,
      );

      if (widget.existingPO != null) {
        await ref.read(purchaseOrderNotifierProvider.notifier).update(po);
      } else {
        await ref.read(purchaseOrderNotifierProvider.notifier).create(po);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase Order saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingPO != null
              ? 'Edit Purchase Order'
              : 'Create Purchase Order',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection('Basic Information', [
              _buildTextField(_poNumberController, 'PO Number', Icons.tag),
              const SizedBox(height: 12),
              _buildTextField(
                _orderIdController,
                'Related Order ID (Optional)',
                Icons.link,
              ),
              const SizedBox(height: 12),
              _buildVendorAutocomplete(ref),
            ]),
            const SizedBox(height: 20),
            _buildSection('Event Details', [
              _buildTextField(_eventNameController, 'Event Name', Icons.event),
              const SizedBox(height: 12),
              _buildTextField(_venueController, 'Venue', Icons.location_on),
              const SizedBox(height: 12),
              _buildDateTile(
                'Event Date',
                _eventDate,
                _eventEndDate,
                (d) => setState(() => _eventDate = d.start),
              ),
              const SizedBox(height: 12),
              _buildDateTile(
                'Setup Date',
                _setupDate,
                _setupEndDate,
                (d) => setState(() => _setupDate = d.start),
              ),
              const SizedBox(height: 12),
              const Text(
                'VAT (Grand Total)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _vatChip(0.0, 'No VAT (0%)', colorScheme),
                  const SizedBox(width: 12),
                  _vatChip(0.13, 'VAT (13%)', colorScheme),
                ],
              ),
            ]),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ITEMS',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _addNewItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._items.asMap().entries.map(
              (e) => _buildItemCard(e.key, e.value),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: _addNewItem,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text(
                  'Add Item',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Financial Summary
            _buildFinancialSummary(colorScheme),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _submitPO,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isSaving
              ? const CircularProgressIndicator()
              : const Text('Save Purchase Order'),
        ),
      ),
    );
  }

  Widget _vatChip(double rate, String label, ColorScheme colorScheme) {
    final isSelected = _vatRate == rate;
    return GestureDetector(
      onTap: () => setState(() => _vatRate = rate),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : colorScheme.onSurface,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialSummary(ColorScheme colorScheme) {
    double subtotal = 0;
    for (var row in _items) {
      if (row.nameController.text.isNotEmpty) {
        final qty = int.tryParse(row.qtyController.text) ?? 1;
        final days = int.tryParse(row.daysController.text) ?? 1;
        final rate = double.tryParse(row.rateController.text) ?? 0.0;
        if (row.billingType == 'event') {
          subtotal += qty * rate;
        } else {
          subtotal += qty * days * rate;
        }
      }
    }

    final vatAmount = subtotal * _vatRate;
    final grandTotal = subtotal + vatAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          _summaryRow('Subtotal', 'Rs. ${subtotal.toStringAsFixed(0)}',
              colorScheme.onSurface),
          if (_vatRate > 0)
            _summaryRow(
              'VAT (${(_vatRate * 100).toStringAsFixed(0)}%)',
              'Rs. ${vatAmount.toStringAsFixed(0)}',
              colorScheme.onSurfaceVariant,
            ),
          const Divider(height: 24),
          _summaryRow(
            'Grand Total',
            'Rs. ${grandTotal.toStringAsFixed(0)}',
            colorScheme.primary,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 18 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildVendorAutocomplete(WidgetRef ref) {
    // If we have vendors from the order, use them. Otherwise show nothing or fall back?
    // User said "only that vendors of that order", so we use _orderVendors.
    final List<String> vendorNames = _orderVendors.isNotEmpty 
        ? _orderVendors 
        : <String>[]; 

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _vendorNameController.text),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty || vendorNames.isEmpty) {
          return const Iterable<String>.empty();
        }
        return vendorNames.where((String option) {
          return option.toLowerCase().contains(
            textEditingValue.text.toLowerCase(),
          );
        });
      },
      onSelected: (String selection) {
        _vendorNameController.text = selection;
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        // Synchronize our controller with Autocomplete controller
        if (controller.text != _vendorNameController.text && _vendorNameController.text.isNotEmpty) {
           controller.text = _vendorNameController.text;
        }
        controller.addListener(() {
          _vendorNameController.text = controller.text;
        });

        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Vendor Name',
            prefixIcon: const Icon(Icons.business, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          onSubmitted: (value) => onFieldSubmitted(),
        );
      },
    );
  }

  Widget _buildDateTile(
    String label,
    DateTime start,
    DateTime? end,
    Function(DateTimeRange) onSelected,
  ) {
    String dateText = formatNepaliDate(start, 'MMM dd, yyyy');
    if (end != null && (end.year != start.year || end.month != start.month || end.day != start.day)) {
      dateText += ' - ${formatNepaliDate(end, 'MMM dd, yyyy')}';
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      subtitle: Text(
        dateText,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      trailing: const Icon(Icons.calendar_today, size: 20),
      onTap: () async {
        final picked = await showDateRangePicker(
          context: context,
          initialDateRange: DateTimeRange(start: start, end: end ?? start),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onSelected(picked);
      },
    );
  }

  Widget _buildPOBillingTypeSelector(_POItemRow item) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => item.billingType = 'daily'),
              child: Container(
                decoration: BoxDecoration(
                  color: item.billingType == 'daily'
                      ? colorScheme.primary
                      : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(3),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Daily',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: item.billingType == 'daily'
                        ? Colors.white
                        : colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  item.billingType = 'event';
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: item.billingType == 'event'
                      ? colorScheme.primary
                      : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(3),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Event',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: item.billingType == 'event'
                        ? Colors.white
                        : colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(int index, _POItemRow row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  radius: 14,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildItemNameAutocomplete(row),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
            const Divider(),
            TextField(
              controller: row.specController,
              decoration: const InputDecoration(
                hintText: 'Specification',
                border: InputBorder.none,
                icon: Icon(Icons.short_text, size: 16),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Billing Type',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      _buildPOBillingTypeSelector(row),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _buildItemField(
                    row.qtyController,
                    'Qty',
                    TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _buildItemField(
                    row.unitController,
                    'Unit',
                    TextInputType.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildItemField(
                    row.daysController,
                    'Days',
                    TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildItemField(
                    row.rateController,
                    'Rate',
                    TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemNameAutocomplete(_POItemRow row) {
    // If we have an order selected, filter items by that order. 
    // Otherwise show all unique items from system? 
    // User said "items of that event only".
    final itemsToSuggest = _orderItems.isNotEmpty 
        ? _orderItems 
        : (ref.watch(allItemsStreamProvider).value ?? []);
    
    final itemNames = itemsToSuggest.map((i) => i.itemName).toSet().toList();

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: row.nameController.text),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return itemNames.where((String option) {
          return option.toLowerCase().contains(
            textEditingValue.text.toLowerCase(),
          );
        });
      },
      onSelected: (String selection) {
        row.nameController.text = selection;
        
        // Find the item in _orderItems to auto-fill details
        final matchedItem = _orderItems.where((i) => i.itemName == selection).firstOrNull;
        if (matchedItem != null) {
          setState(() {
            row.specController.text = matchedItem.specification;
            row.billingType = matchedItem.billingType;
            row.qtyController.text = matchedItem.quantity.toString();
            row.unitController.text = matchedItem.unit;
            row.daysController.text = matchedItem.days.toString();
            row.rateController.text = matchedItem.vendorRate.toStringAsFixed(0);
          });
        }
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        if (controller.text != row.nameController.text && row.nameController.text.isNotEmpty) {
           controller.text = row.nameController.text;
        }
        controller.addListener(() {
          row.nameController.text = controller.text;
        });

        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            hintText: 'Item Name',
            border: InputBorder.none,
          ),
          onSubmitted: (value) => onFieldSubmitted(),
        );
      },
    );
  }

  Widget _buildItemField(
    TextEditingController controller,
    String label,
    TextInputType type,
  ) {
    return TextField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }
}
