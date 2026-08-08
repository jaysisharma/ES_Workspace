import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/widgets/calendar/nepali_date_picker_dialog.dart';
import 'package:order_app/presentation/widgets/create_order/create_order_form_helpers.dart';
import 'package:order_app/presentation/widgets/create_order/create_order_info_card.dart';
import 'package:order_app/presentation/widgets/create_order/create_order_app_bar.dart';
import 'package:order_app/presentation/widgets/create_order/create_order_bottom_nav_bar.dart';
import 'package:order_app/presentation/widgets/create_order/create_order_item_row_widget.dart';
import 'package:order_app/presentation/widgets/create_order/create_order_submit_helper.dart';
import 'package:order_app/presentation/widgets/create_order/item_row_model.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  /// Pass an existing order to enter edit mode.
  final OrderEntity? existingOrder;

  /// Pass an initial date to pre-fill when creating a new order from calendar.
  final DateTime? initialDate;

  const CreateOrderScreen({super.key, this.existingOrder, this.initialDate});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
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

  final List<ItemRow> _items = [ItemRow()];
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
              final row = ItemRow();
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
      if (widget.initialDate != null) {
        _eventDate = widget.initialDate!;
        _setupDate = widget.initialDate!.subtract(const Duration(days: 1));
      }
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
    final title = isSetup
        ? 'Select Setup Date (Nepali BS)'
        : 'Select Event Date (Nepali BS)';
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
      _items.add(ItemRow());
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
    await CreateOrderSubmitHelper.submitOrder(
      context: context,
      ref: ref,
      isDraft: isDraft,
      isEditMode: _isEditMode,
      existingOrder: widget.existingOrder,
      orderIdController: _orderIdController,
      eventNameController: _eventNameController,
      venueController: _venueController,
      contactPersonController: _contactPersonController,
      contactNumberController: _contactNumberController,
      descriptionController: _descriptionController,
      eventDate: _eventDate,
      eventEndDate: _eventEndDate,
      setupDate: _setupDate,
      setupEndDate: _setupEndDate,
      selectedCategory: _selectedCategory,
      vatRate: _vatRate,
      items: _items,
      onSavingStateChanged: (saving) {
        if (mounted) setState(() => _isSaving = saving);
      },
    );
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
      appBar: CreateOrderAppBarWidget(
        isEditMode: _isEditMode,
        isSaving: _isSaving,
        onSaveDraft: () => _submitOrder(true),
        bgColor: bgColor,
        borderColor: borderColor,
        textColor: textColor,
        labelColor: labelColor,
        primaryColor: primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0).copyWith(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SECTION 1: Event Information
            CreateOrderFormHelpers.buildSectionTitle(
              'Event Information',
              textColor,
            ),
            const SizedBox(height: 12),
            CreateOrderInfoCardWidget(
              orderIdController: _orderIdController,
              eventNameController: _eventNameController,
              venueController: _venueController,
              contactPersonController: _contactPersonController,
              contactNumberController: _contactNumberController,
              descriptionController: _descriptionController,
              isEditMode: _isEditMode,
              dateTextEvent: _formatDateRange(_eventDate, _eventEndDate),
              dateTextSetup: _formatDateRange(_setupDate, _setupEndDate),
              selectedCategory: _selectedCategory,
              vatRate: _vatRate,
              onSelectEventDate: () => _selectDate(context, false),
              onSelectSetupDate: () => _selectDate(context, true),
              onCategorySelected: (cat) =>
                  setState(() => _selectedCategory = cat),
              onVatRateSelected: (rate) => setState(() => _vatRate = rate),
              primaryColor: primaryColor,
              textColor: textColor,
              labelColor: labelColor,
              borderColor: borderColor,
              surfaceColor: surfaceColor,
              filledColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
            ),
            const SizedBox(height: 24),

            // SECTION 2: Items
            CreateOrderFormHelpers.buildSectionTitle('Items', textColor),
            const SizedBox(height: 12),
            // Dynamic Items List
            ..._items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: CreateOrderItemRowWidget(
                  index: index,
                  item: item,
                  totalItems: _items.length,
                  onRemove: () => _removeItem(index),
                  onBillingTypeChanged: (val) =>
                      setState(() => item.billingType = val),
                  primaryColor: primaryColor,
                  textColor: textColor,
                  labelColor: labelColor,
                  borderColor: borderColor,
                ),
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
      bottomNavigationBar: CreateOrderBottomNavBarWidget(
        isEditMode: _isEditMode,
        isSaving: _isSaving,
        onSubmit: () => _submitOrder(false),
        onSaveDraft: () => _submitOrder(true),
        primaryColor: primaryColor,
        surfaceColor: surfaceColor,
        borderColor: borderColor,
        textColor: textColor,
      ),
    );
  }
}
