import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/domain/entities/inventory_entity.dart';
import 'package:order_app/presentation/providers/inventory_provider.dart';
import 'package:order_app/presentation/providers/settings_provider.dart';

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

  late TextEditingController _itemNoController;
  late TextEditingController _nameController;
  late TextEditingController _specController;
  late TextEditingController _qtyController;
  late TextEditingController _availQtyController;
  late TextEditingController _rateController;
  late TextEditingController _locationController;

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
    _itemNoController = TextEditingController(text: i?.itemNo ?? '');
    _nameController = TextEditingController(text: i?.name ?? '');
    _specController = TextEditingController(text: i?.specification ?? '');
    _qtyController = TextEditingController(text: (i?.quantity ?? 1).toString());
    _availQtyController =
        TextEditingController(text: (i?.availableQuantity ?? 1).toString());
    _rateController =
        TextEditingController(text: (i?.rate ?? 0.0).toString());
    _locationController =
        TextEditingController(text: i?.location ?? 'Main Warehouse');

    if (i != null && i.category.isNotEmpty) {
      if (!_categories.contains(i.category)) {
        _categories.add(i.category);
      }
      _selectedCategory = i.category;
    }

    if (i != null && _statuses.contains(i.status)) {
      _selectedStatus = i.status;
    }

    // Populate existing categories from current inventory items
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final existingItems = ref.read(inventoryNotifierProvider).items;
      bool updated = false;
      for (final itm in existingItems) {
        final cat = itm.category.trim();
        if (cat.isNotEmpty && !_categories.contains(cat)) {
          _categories.add(cat);
          updated = true;
        }
      }
      if (updated && mounted) setState(() {});
    });

    _qtyController.addListener(_onNumbersChanged);
    _rateController.addListener(_onNumbersChanged);
  }

  void _onNumbersChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _qtyController.removeListener(_onNumbersChanged);
    _rateController.removeListener(_onNumbersChanged);
    _itemNoController.dispose();
    _nameController.dispose();
    _specController.dispose();
    _qtyController.dispose();
    _availQtyController.dispose();
    _rateController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  double get _computedTotal {
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    final rate = double.tryParse(_rateController.text.trim()) ?? 0.0;
    return qty * rate;
  }

  Future<void> _showAddCategoryDialog() async {
    final textCtrl = TextEditingController();
    final newCategory = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom Category'),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g. Trussing, Cables, LED Screen',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = textCtrl.text.trim();
              if (val.isNotEmpty) {
                Navigator.pop(ctx, val);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (newCategory != null && newCategory.isNotEmpty) {
      setState(() {
        if (!_categories.contains(newCategory)) {
          _categories.add(newCategory);
        }
        _selectedCategory = newCategory;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final itemNo = _itemNoController.text.trim();
    final name = _nameController.text.trim();
    final spec = _specController.text.trim();
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    final availQty = int.tryParse(_availQtyController.text.trim()) ?? qty;
    final rate = double.tryParse(_rateController.text.trim()) ?? 0.0;
    final location = _locationController.text.trim();

    final autoItemNo = itemNo.isEmpty
        ? 'ITM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}'
        : itemNo;

    final newItem = InventoryItemEntity(
      id: widget.item?.id ?? '',
      itemNo: autoItemNo,
      name: name,
      category: _selectedCategory,
      specification: spec,
      quantity: qty,
      availableQuantity: availQty > qty ? qty : availQty,
      rate: rate,
      status: availQty <= 0 ? 'Out of Stock' : _selectedStatus,
      location: location.isEmpty ? 'Main Warehouse' : location,
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
                ? 'Inventory item "$name" added successfully'
                : 'Inventory item "$name" updated successfully'),
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
    final settings = ref.watch(settingsProvider);
    final currencySymbol = settings.currency.split(' ').first;
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
              // 1. Item No & Category Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: _itemNoController,
                      decoration: const InputDecoration(
                        labelText: 'Item No',
                        hintText: 'e.g. ITM-001 (auto if empty)',
                        prefixIcon: Icon(Icons.tag_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _categories.contains(_selectedCategory)
                                ? _selectedCategory
                                : null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Item Category *',
                              prefixIcon: Icon(Icons.category_outlined),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              ..._categories.map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCategory = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          tooltip: 'Add Custom Category',
                          icon: const Icon(Icons.add_rounded),
                          onPressed: _showAddCategoryDialog,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Item Name
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

              // 3. Specification
              TextFormField(
                controller: _specController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Specification',
                  hintText: 'Technical details, dimensions, wattage, accessories, condition...',
                  prefixIcon: Icon(Icons.description_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 4. Quantity & Rate
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity *',
                        hintText: 'e.g. 10',
                        prefixIcon: Icon(Icons.numbers_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Quantity required';
                        final n = int.tryParse(v.trim());
                        if (n == null || n < 0) return 'Enter valid quantity';
                        return null;
                      },
                      onChanged: (v) {
                        if (!isEdit) {
                          // Auto match available units for new item
                          _availQtyController.text = v;
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _rateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Rate ($currencySymbol) *',
                        hintText: 'e.g. 1500',
                        prefixIcon: const Icon(Icons.payments_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final r = double.tryParse(v.trim());
                        if (r == null || r < 0) return 'Enter valid rate';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 5. Total Live Calculation Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colorScheme.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calculate_outlined, color: colorScheme.primary, size: 22),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL (Quantity × Rate)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              '${_qtyController.text.isEmpty ? "0" : _qtyController.text} units × $currencySymbol ${_rateController.text.isEmpty ? "0" : _rateController.text}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      '$currencySymbol ${_computedTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 6. Secondary / Operational Details (Available, Status, Location)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: isEdit,
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'Operational & Stock Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Available units in warehouse, stock status, shelf location',
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                  children: [
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _availQtyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Available Units',
                              prefixIcon: Icon(Icons.check_circle_outline),
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
                                      child: Text(s, overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedStatus = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Warehouse Location / Shelf',
                        hintText: 'e.g. Shelf B2, Section 4',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
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
