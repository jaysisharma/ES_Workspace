import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/domain/entities/inventory_entity.dart';
import 'package:order_app/presentation/providers/inventory_provider.dart';

class AddEditInventoryScreen extends ConsumerStatefulWidget {
  final InventoryItemEntity? item;

  const AddEditInventoryScreen({super.key, this.item});

  @override
  ConsumerState<AddEditInventoryScreen> createState() =>
      _AddEditInventoryScreenState();
}

class _AddEditInventoryScreenState
    extends ConsumerState<AddEditInventoryScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _totalQtyController;
  late TextEditingController _availQtyController;
  late TextEditingController _rateController;
  late TextEditingController _locationController;
  late TextEditingController _descController;

  String _selectedCategory = 'Sound';
  String _selectedStatus = 'Available';

  final List<String> _categories = [
    'Sound',
    'Lighting',
    'Stage',
    'Decor',
    'AV Equipment',
    'Catering',
    'Furniture',
    'General',
  ];

  final List<String> _statuses = [
    'Available',
    'Low Stock',
    'Out of Stock',
    'Maintenance',
  ];

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _nameController = TextEditingController(text: i?.name ?? '');
    _skuController = TextEditingController(text: i?.sku ?? '');
    _totalQtyController =
        TextEditingController(text: (i?.totalQuantity ?? 1).toString());
    _availQtyController =
        TextEditingController(text: (i?.availableQuantity ?? 1).toString());
    _rateController =
        TextEditingController(text: (i?.rentalRatePerDay ?? 0.0).toString());
    _locationController =
        TextEditingController(text: i?.location ?? 'Main Warehouse');
    _descController = TextEditingController(text: i?.description ?? '');

    if (i != null && _categories.contains(i.category)) {
      _selectedCategory = i.category;
    }
    if (i != null && _statuses.contains(i.status)) {
      _selectedStatus = i.status;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _totalQtyController.dispose();
    _availQtyController.dispose();
    _rateController.dispose();
    _locationController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final sku = _skuController.text.trim();
    final totalQty = int.tryParse(_totalQtyController.text.trim()) ?? 0;
    final availQty = int.tryParse(_availQtyController.text.trim()) ?? 0;
    final rate = double.tryParse(_rateController.text.trim()) ?? 0.0;
    final location = _locationController.text.trim();
    final desc = _descController.text.trim();

    final newItem = InventoryItemEntity(
      id: widget.item?.id ?? '',
      name: name,
      sku: sku.isEmpty ? 'SKU-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}' : sku,
      category: _selectedCategory,
      totalQuantity: totalQty,
      availableQuantity: availQty,
      rentalRatePerDay: rate,
      status: availQty <= 0 ? 'Out of Stock' : _selectedStatus,
      location: location.isEmpty ? 'Main Warehouse' : location,
      description: desc,
      createdAt: widget.item?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = widget.item == null
        ? await ref.read(inventoryNotifierProvider.notifier).addInventoryItem(newItem)
        : await ref.read(inventoryNotifierProvider.notifier).updateInventoryItem(newItem);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.item == null
                ? 'Inventory item added successfully'
                : 'Inventory item updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save inventory item'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEdit = widget.item != null;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Inventory Item' : 'Add Inventory Item',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  hintText: 'e.g. JBL PRX 815 Loudspeaker',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Item name is required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _skuController,
                      decoration: const InputDecoration(
                        labelText: 'SKU / Serial No',
                        hintText: 'e.g. SPK-JBL-01',
                        prefixIcon: Icon(Icons.qr_code),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: _categories
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCategory = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _totalQtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total Units *',
                        prefixIcon: Icon(Icons.numbers),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || int.tryParse(v) == null) ? 'Enter valid number' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _availQtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Available Units *',
                        prefixIcon: Icon(Icons.check_circle_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || int.tryParse(v) == null) ? 'Enter valid number' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Daily Rental Rate / Cost',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.info_outline),
                        border: OutlineInputBorder(),
                      ),
                      items: _statuses
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  s,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStatus = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Warehouse Location / Shelf',
                  hintText: 'e.g. Shelf B2, Section 4',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description & Notes',
                  hintText: 'Technical specifications, condition, maintenance notes...',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(
                    isEdit ? 'UPDATE INVENTORY ITEM' : 'ADD INVENTORY ITEM',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
