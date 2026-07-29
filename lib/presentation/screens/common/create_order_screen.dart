import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/nepali_date_formatter.dart';
import 'package:flutter/services.dart';
import '../../../domain/entities/order_entity.dart';
import '../../../domain/entities/order_item_entity.dart';
import '../../../domain/entities/event_entity.dart';
import '../../widgets/vendor_autocomplete_field.dart';
import '../../providers/order_providers.dart';
import '../../providers/event_notifier.dart';
import '../../providers/category_providers.dart';
import '../../providers/client_provider.dart';
import '../../../domain/entities/client_entity.dart';
import '../../widgets/calendar/nepali_date_picker_dialog.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  /// Pass an existing order to enter edit mode.
  final OrderEntity? existingOrder;

  const CreateOrderScreen({super.key, this.existingOrder});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _ItemRow {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController specController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController daysController = TextEditingController(text: '1');
  final TextEditingController vendorController = TextEditingController();
  String billingType = 'daily';
  final TextEditingController unitController = TextEditingController(
    text: 'Pcs',
  );

  void dispose() {
    nameController.dispose();
    specController.dispose();
    qtyController.dispose();
    daysController.dispose();
    vendorController.dispose();
    unitController.dispose();
  }
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _eventNameController = TextEditingController();
  final _venueController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _descriptionController = TextEditingController();
  double _vatRate = 0.0;

  DateTime _eventDate = DateTime.now().add(const Duration(days: 7));
  DateTime? _eventEndDate;
  DateTime _setupDate = DateTime.now().add(const Duration(days: 6));
  DateTime? _setupEndDate;

  final List<_ItemRow> _items = [_ItemRow()];
  late final TextEditingController _orderIdController;
  final _customCategoryController = TextEditingController();
  bool _isSaving = false;
  String? _selectedCategory;

  bool get _isEditMode => widget.existingOrder != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existingOrder;
    if (existing != null) {
      // -- EDIT MODE: pre-fill all fields from the existing order --
      _orderIdController = TextEditingController(text: existing.id);
      _eventNameController.text = existing.eventName;
      _venueController.text = existing.venue;
      _contactPersonController.text = existing.contactPerson;
      _contactNumberController.text = existing.contactNumber;
      _eventDate = existing.eventDate;
      _eventEndDate = existing.eventEndDate;
      _setupDate = existing.setupDate;
      _setupEndDate = existing.setupEndDate;
      _descriptionController.text = existing.description;
      _vatRate = existing.vatRate;

      // Load existing items from Firestore and populate _items list
      Future.microtask(() async {
        await ref
            .read(orderItemNotifierProvider.notifier)
            .loadItems(existing.id);
        final loadedItems = ref.read(orderItemNotifierProvider).items;
        if (loadedItems.isNotEmpty && mounted) {
          setState(() {
            // Clear the default empty row then add real items
            for (final r in _items) {
              r.dispose();
            }
            _items.clear();
            for (final item in loadedItems) {
              final row = _ItemRow();
              row.nameController.text = item.itemName;
              row.specController.text = item.specification;
              row.qtyController.text = item.quantity.toString();
              row.daysController.text = item.days.toString();
              row.vendorController.text = item.vendor;
              row.billingType = item.billingType;
              row.unitController.text = item.unit;
              _selectedCategory = existing.category.isEmpty
                  ? null
                  : existing.category;
              _items.add(row);
            }
          });
        }
      });
    } else {
      // -- CREATE MODE: start with an empty Order ID --
      _orderIdController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _venueController.dispose();
    _contactPersonController.dispose();
    _contactNumberController.dispose();
    _descriptionController.dispose();
    _orderIdController.dispose();
    _customCategoryController.dispose();
    for (var item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isSetup) async {
    final title = isSetup ? 'Select Setup Date (Nepali BS)' : 'Select Event Date (Nepali BS)';
    final initialStart = isSetup ? _setupDate : _eventDate;
    final initialEnd = isSetup ? _setupEndDate : _eventEndDate;

    final picked = await NepaliDatePickerDialog.show(
      context: context,
      title: title,
      initialStart: initialStart,
      initialEnd: initialEnd,
      allowRange: true,
    );

    if (picked != null && picked['start'] != null) {
      setState(() {
        if (isSetup) {
          _setupDate = picked['start']!;
          _setupEndDate = picked['end'];
        } else {
          _eventDate = picked['start']!;
          _eventEndDate = picked['end'];
        }
      });
    }
  }

  String _formatDateRange(DateTime start, DateTime? end) {
    if (end == null) {
      return formatNepaliDate(start, 'MMM dd, yyyy');
    }
    if (start.year == end.year) {
      return '${formatNepaliDate(start, 'MMM dd')} - ${formatNepaliDate(end, 'MMM dd, yyyy')}';
    }
    return '${formatNepaliDate(start, 'MMM dd, yyyy')} - ${formatNepaliDate(end, 'MMM dd, yyyy')}';
  }

  void _addNewItem() {
    setState(() {
      _items.add(_ItemRow());
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

  Future<void> _submitOrder(bool isDraft) async {
    if (_eventNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an event name')),
      );
      return;
    }
    if (_venueController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a venue')));
      return;
    }
    if (_contactPersonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a contact person')),
      );
      return;
    }
    if (_contactNumberController.text.trim().length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact number must be exactly 10 digits'),
        ),
      );
      return;
    }

    if (_setupDate.isAfter(_eventDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setup date cannot be after event date')),
      );
      return;
    }

    // Check if at least one item has a name
    bool hasValidItem = _items.any(
      (item) => item.nameController.text.isNotEmpty,
    );
    if (!hasValidItem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item with a name'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentOrder = widget.existingOrder;
      final now = DateTime.now();
      // In edit mode, always use the original order's ID — Firestore document
      // IDs are immutable, so changing the ID field would try to update a
      // non-existent document and silently fail.
      final String finalOrderId = _isEditMode
          ? widget.existingOrder!.id
          : (_orderIdController.text.trim().isEmpty
              ? 'ORD-${DateTime.now().millisecondsSinceEpoch}'
              : _orderIdController.text.trim());

      final contactName = _contactPersonController.text.trim();
      final contactPhone = _contactNumberController.text.trim();
      final eventName = _eventNameController.text.trim();

      // 0. Auto-manage client based on contact person and phone number
      final clients = ref.read(clientNotifierProvider).clients;
      final existingClientIndex = clients.indexWhere(
        (c) =>
            c.name.toLowerCase() == contactName.toLowerCase() &&
            c.phone == contactPhone,
      );

      if (existingClientIndex != -1) {
        // Update existing client (we can update phone if it was different, but here it's part of the match condition.
        // We'll just leave it as is or update the name to the exact casing.
        final existing = clients[existingClientIndex];
        await ref
            .read(clientNotifierProvider.notifier)
            .updateClient(
              existing.copyWith(
                name: contactName, // ensure casing matches latest input
                contactPerson: contactName,
                notes:
                    '${existing.notes}\nAutomatically added from Order $finalOrderId'
                        .trim(),
              ),
            );
      } else {
        // Create new client
        await ref
            .read(clientNotifierProvider.notifier)
            .addClient(
              ClientEntity(
                id: '',
                name: contactName,
                contactPerson: contactName,
                phone: contactPhone,
                email: '',
                notes:
                    'Automatically added from Order $finalOrderId', // Initial notes.
              ),
            );
      }

      final order = OrderEntity(
        id: finalOrderId,
        eventName: eventName,
        eventDate: _eventDate,
        eventEndDate: _eventEndDate,
        setupDate: _setupDate,
        setupEndDate: _setupEndDate,
        venue: _venueController.text.trim(),
        contactPerson: contactName,
        contactNumber: contactPhone,
        notes: currentOrder?.notes ?? '',
        status: _isEditMode
            ? (currentOrder!.status == OrderStatus.completed
                  ? OrderStatus.confirmed
                  : currentOrder.status)
            : (isDraft ? OrderStatus.draft : OrderStatus.confirmed),
        assignedStaffIds: _isEditMode ? (currentOrder!.assignedStaffIds) : [],
        totalAmount: currentOrder?.totalAmount ?? 0.0,
        totalExpenses: currentOrder?.totalExpenses ?? 0.0,
        createdAt: currentOrder?.createdAt ?? now,
        updatedAt: now,
        category: _selectedCategory ?? '',
        client: contactName,
        description: _descriptionController.text.trim(),
        vatRate: _vatRate,
      );

      // 1. Create or Update the Order
      if (_isEditMode) {
        await ref.read(orderNotifierProvider.notifier).updateOrder(order);
      } else {
        await ref.read(orderNotifierProvider.notifier).create(order);
      }

      // 2. Update or create order items
      final Map<String, OrderItemEntity> existingStates = {};
      if (_isEditMode) {
        final currentItems = ref.read(orderItemNotifierProvider).items;
        for (final item in currentItems) {
          // Use name + spec as key but trim to be safe
          final key = '${item.itemName.trim()}_${item.specification.trim()}';
          existingStates[key] = item;
        }
        // Delete old items then re-add to reflect any changes
        await ref
            .read(orderItemNotifierProvider.notifier)
            .deleteItemsForOrder(finalOrderId);
      }
      final List<Future<void>> itemFutures = [];
      for (var itemRow in _items) {
        if (itemRow.nameController.text.isNotEmpty) {
          final itemName = itemRow.nameController.text.trim();
          final spec = itemRow.specController.text.trim();
          final key = '${itemName}_$spec';
          final existing = existingStates[key];

          final item = OrderItemEntity(
            id: const Uuid().v4(),
            orderId: finalOrderId,
            itemName: itemName,
            specification: spec,
            quantity: int.tryParse(itemRow.qtyController.text) ?? 1,
            unit: itemRow.unitController.text,
            days: int.tryParse(itemRow.daysController.text) ?? 1,
            vendor: itemRow.vendorController.text,
            billingType: itemRow.billingType,
            isCompleted: existing?.isCompleted ?? false,
            rate: existing?.rate ?? 0.0,
            amount: existing?.amount ?? 0.0,
            vendorRate: existing?.vendorRate ?? 0.0,
            vendorAmount: existing?.vendorAmount ?? 0.0,
          );
          // Add but don't trigger individual refreshes for each item
          itemFutures.add(
            ref
                .read(orderItemNotifierProvider.notifier)
                .addItem(item, reload: false),
          );
        }
      }

      if (itemFutures.isNotEmpty) {
        await Future.wait(itemFutures);
        // Trigger one final refresh for items after all are added
        ref.read(orderItemNotifierProvider.notifier).loadItems(finalOrderId);
      }

      // 3. Create an Event entry only when creating a new confirmed order
      if (!_isEditMode && !isDraft) {
        final event = EventEntity(
          id: const Uuid().v4(),
          orderId: finalOrderId,
          title: _eventNameController.text.trim(),
          date: _eventDate,
          location: _venueController.text.trim(),
          role: 'Lead Tech', // Default role for now
          status: 'In Progress',
          completion: 0.0,
          assignedStaffId: null,
        );
        await ref.read(eventNotifierProvider.notifier).create(event);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDraft
                  ? 'Draft saved successfully'
                  : _isEditMode
                  ? 'Order updated successfully'
                  : 'Order confirmed successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted && _isSaving) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    final bgColor = colorScheme.surface;
    final surfaceColor = colorScheme.surface;
    final borderColor = colorScheme.outline;
    final textColor = colorScheme.onSurface;
    final labelColor = colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.8),
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: labelColor),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Text(
                  _isEditMode ? 'Edit Order' : 'Create Event Order',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
                if (!_isEditMode)
                  TextButton(
                    onPressed: _isSaving ? null : () => _submitOrder(true),
                    child: _isSaving
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                labelColor.withValues(alpha: 0.5),
                              ),
                            ),
                          )
                        : Text(
                            'Save Draft',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0).copyWith(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SECTION 1: Event Information
            _buildSectionTitle('Event Information', textColor),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Order ID', labelColor),
                  _buildTextField(
                    controller: _orderIdController,
                    hintText: 'Order ID',
                    icon: Icons.tag,
                    textColor: textColor,
                    labelColor: labelColor,
                    borderColor: borderColor,
                    primaryColor: primaryColor,
                    filledColor: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    readOnly: _isEditMode,
                  ),
                  const SizedBox(height: 16),

                  _buildFieldLabel('Event Name', labelColor),
                  _buildTextField(
                    controller: _eventNameController,
                    hintText: 'e.g. Annual Tech Summit 2024',
                    icon: Icons.event_note,
                    textColor: textColor,
                    labelColor: labelColor,
                    borderColor: borderColor,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(height: 16),

                  _buildFieldLabel('Event Date', labelColor),
                  _buildDateSelector(
                    label: 'Event Date',
                    dateText: _formatDateRange(_eventDate, _eventEndDate),
                    icon: Icons.calendar_today,
                    textColor: textColor,
                    labelColor: labelColor,
                    onTap: () => _selectDate(context, false),
                  ),
                  const SizedBox(height: 16),
                  _buildFieldLabel('Setup Date', labelColor),
                  _buildDateSelector(
                    label: 'Setup Date',
                    dateText: _formatDateRange(_setupDate, _setupEndDate),
                    icon: Icons.build_circle_outlined,
                    textColor: textColor,
                    labelColor: labelColor,
                    onTap: () => _selectDate(context, true),
                  ),
                  const SizedBox(height: 16),

                  _buildFieldLabel('Venue', labelColor),
                  _buildTextField(
                    controller: _venueController,
                    hintText: 'Enter venue location',
                    icon: Icons.location_on_outlined,
                    textColor: textColor,
                    labelColor: labelColor,
                    borderColor: borderColor,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(height: 16),

                  _buildFieldLabel('Contact Person', labelColor),
                  _buildTextField(
                    controller: _contactPersonController,
                    hintText: 'Name',
                    icon: Icons.person_outline,
                    textColor: textColor,
                    labelColor: labelColor,
                    borderColor: borderColor,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(height: 16),

                  _buildFieldLabel('Contact Number', labelColor),
                  _buildTextField(
                    controller: _contactNumberController,
                    hintText: '98XXXXXXXX',
                    icon: Icons.call_outlined,
                    textColor: textColor,
                    labelColor: labelColor,
                    borderColor: borderColor,
                    primaryColor: primaryColor,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 16),

                  _buildFieldLabel('Category', labelColor),
                  _buildCategorySelector(
                    primaryColor,
                    labelColor,
                    textColor,
                    borderColor,
                    surfaceColor,
                  ),
                  const SizedBox(height: 16),
                  _buildFieldLabel('Order Description', labelColor),
                  _buildTextField(
                    controller: _descriptionController,
                    hintText: 'Enter order details/description',
                    icon: Icons.description_outlined,
                    maxLines: 3,
                    textColor: textColor,
                    labelColor: labelColor,
                    borderColor: borderColor,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(height: 16),
                  _buildFieldLabel('VAT (Grand Total)', labelColor),
                  Row(
                    children: [
                      _vatChip(
                        0.0,
                        'No VAT (0%)',
                        primaryColor,
                        surfaceColor,
                        borderColor,
                        textColor,
                      ),
                      const SizedBox(width: 12),
                      _vatChip(
                        0.13,
                        'VAT (13%)',
                        primaryColor,
                        surfaceColor,
                        borderColor,
                        textColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // SECTION 2: Items
            _buildSectionTitle('Items', textColor),
            const SizedBox(height: 12),
            // Dynamic Items List
            ..._items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildItemRow(index, item),
              );
            }),

            // Add Item Button
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _addNewItem,
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: const Text(
                    'Add New Item',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: primaryColor,
                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(top: BorderSide(color: borderColor)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: _isSaving ? null : () => _submitOrder(false),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                elevation: 0,
                minimumSize: const Size(double.infinity, 54),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isEditMode
                              ? Icons.save_rounded
                              : Icons.verified_outlined,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isEditMode ? 'Save Changes' : 'Confirm Order',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isSaving ? null : () => _submitOrder(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                foregroundColor: textColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                elevation: 0,
                minimumSize: const Size(double.infinity, 54),
              ),
              child: _isSaving
                  ? CircularProgressIndicator(color: primaryColor)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save_outlined, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Save as Draft',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor.withValues(alpha: 0.7),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: labelColor,
        ),
      ),
    );
  }

  Widget _vatChip(
    double rate,
    String label,
    Color primaryColor,
    Color surfaceColor,
    Color borderColor,
    Color textColor,
  ) {
    final isSelected = _vatRate == rate;
    return GestureDetector(
      onTap: () => setState(() => _vatRate = rate),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? primaryColor : borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : textColor,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hintText,
    IconData? icon,
    required Color textColor,
    required Color labelColor,
    required Color borderColor,
    required Color primaryColor,
    TextInputType? keyboardType,
    Color? filledColor,
    TextEditingController? controller,
    int maxLines = 1,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: textColor, fontSize: 14),
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      readOnly: readOnly,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: labelColor),
        prefixIcon: icon != null
            ? Icon(icon, color: labelColor, size: 20)
            : null,
        filled: filledColor != null,
        fillColor: filledColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: primaryColor, width: 1),
        ),
        counterText: '',
      ),
    );
  }

  Widget _buildDateSelector({
    required String label,
    required String dateText,
    required IconData icon,
    required Color textColor,
    required Color labelColor,
    required VoidCallback onTap,
  }) {
    final borderColor = Theme.of(context).colorScheme.outline;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: labelColor, size: 20),
            const SizedBox(width: 12),
            Text(
              dateText,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_drop_down, color: labelColor),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(int index, _ItemRow item) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    final textColor = colorScheme.onSurface;
    final labelColor = colorScheme.onSurfaceVariant;
    final borderColor = colorScheme.outline;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: primaryColor.withValues(alpha: 0.1),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'ITEM #${index + 1}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: labelColor,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (_items.length > 1)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.redAccent,
                  ),
                  onPressed: () => _removeItem(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFieldLabel('Item Name', labelColor),
          _buildTextField(
            controller: item.nameController,
            hintText: 'e.g. LED Wall P3',
            textColor: textColor,
            labelColor: labelColor,
            borderColor: borderColor,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 14),
          _buildFieldLabel('Specification', labelColor),
          _buildTextField(
            controller: item.specController,
            hintText: 'e.g. 20ft x 10ft',
            textColor: textColor,
            labelColor: labelColor,
            borderColor: borderColor,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Billing Type', labelColor),
                    _buildBillingTypeSelector(item),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Unit', labelColor),
                    _buildTextField(
                      controller: item.unitController,
                      hintText: 'Pcs',
                      textColor: textColor,
                      labelColor: labelColor,
                      borderColor: borderColor,
                      primaryColor: primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Qty', labelColor),
                    _buildTextField(
                      controller: item.qtyController,
                      hintText: '1',
                      textColor: textColor,
                      labelColor: labelColor,
                      borderColor: borderColor,
                      primaryColor: primaryColor,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Days', labelColor),
                    _buildTextField(
                      controller: item.daysController,
                      hintText: '1',
                      textColor: textColor,
                      labelColor: labelColor,
                      borderColor: borderColor,
                      primaryColor: primaryColor,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildFieldLabel('Preferred Vendor', labelColor),
          VendorAutocompleteField(
            controller: item.vendorController,
            hintText: 'Select or type vendor',
            icon: Icons.storefront_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(
    Color primaryColor,
    Color labelColor,
    Color textColor,
    Color borderColor,
    Color surfaceColor,
  ) {
    final categoriesAsync = ref.watch(orderCategoriesStreamProvider);

    return categoriesAsync.when(
      data: (categories) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: categories.contains(_selectedCategory)
                ? _selectedCategory
                : null,
            decoration: InputDecoration(
              hintText: 'Select Category',
              hintStyle: TextStyle(fontSize: 14, color: labelColor),
              prefixIcon: Icon(Icons.category_outlined, color: labelColor),
              filled: true,
              fillColor: surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items: [
              ...categories.map(
                (cat) => DropdownMenuItem(
                  value: cat,
                  child: Text(
                    cat,
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),
                ),
              ),
              const DropdownMenuItem(
                value: 'ADD_NEW',
                child: Row(
                  children: [
                    Icon(Icons.add, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Add Custom...',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            onChanged: (val) {
              if (val == 'ADD_NEW') {
                _showAddCategoryDialog();
              } else {
                setState(() => _selectedCategory = val);
              }
            },
            dropdownColor: surfaceColor,
            icon: Icon(Icons.arrow_drop_down, color: labelColor),
          ),
        ],
      ),
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(
        'Error loading categories',
        style: TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Category'),
        content: TextField(
          controller: _customCategoryController,
          decoration: const InputDecoration(
            hintText: 'Category Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newCat = _customCategoryController.text.trim();
              if (newCat.isNotEmpty) {
                await ref.read(categoryActionProvider).addCategory(newCat);
                setState(() => _selectedCategory = newCat);
                _customCategoryController.clear();
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((_) {
      if (_selectedCategory == 'ADD_NEW') {
        setState(() => _selectedCategory = null);
      }
    });
  }

  Widget _buildBillingTypeSelector(_ItemRow item) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colorScheme.outline),
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
                    fontSize: 12,
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
                    fontSize: 12,
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
}
