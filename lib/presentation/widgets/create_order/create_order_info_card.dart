import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'create_order_category_selector.dart';
import 'create_order_form_helpers.dart';

class CreateOrderInfoCardWidget extends StatelessWidget {
  final TextEditingController orderIdController;
  final TextEditingController eventNameController;
  final TextEditingController venueController;
  final TextEditingController contactPersonController;
  final TextEditingController contactNumberController;
  final TextEditingController descriptionController;
  final bool isEditMode;
  final String dateTextEvent;
  final String dateTextSetup;
  final String? selectedCategory;
  final String orderType;
  final double vatRate;
  final VoidCallback onSelectEventDate;
  final VoidCallback onSelectSetupDate;
  final ValueChanged<String?> onCategorySelected;
  final ValueChanged<String> onOrderTypeChanged;
  final ValueChanged<double> onVatRateSelected;
  final Color primaryColor;
  final Color textColor;
  final Color labelColor;
  final Color borderColor;
  final Color surfaceColor;
  final Color filledColor;

  const CreateOrderInfoCardWidget({
    super.key,
    required this.orderIdController,
    required this.eventNameController,
    required this.venueController,
    required this.contactPersonController,
    required this.contactNumberController,
    required this.descriptionController,
    required this.isEditMode,
    required this.dateTextEvent,
    required this.dateTextSetup,
    required this.selectedCategory,
    required this.orderType,
    required this.vatRate,
    required this.onSelectEventDate,
    required this.onSelectSetupDate,
    required this.onCategorySelected,
    required this.onOrderTypeChanged,
    required this.onVatRateSelected,
    required this.primaryColor,
    required this.textColor,
    required this.labelColor,
    required this.borderColor,
    required this.surfaceColor,
    required this.filledColor,
  });

  @override
  Widget build(BuildContext context) {
    final currentType = (orderType.toLowerCase() == 'rental') ? 'Rental' : 'Event';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CreateOrderFormHelpers.buildFieldLabel('Order ID', labelColor),
          CreateOrderFormHelpers.buildTextField(
            controller: orderIdController,
            hintText: 'Order ID',
            icon: Icons.tag,
            textColor: textColor,
            labelColor: labelColor,
            borderColor: borderColor,
            primaryColor: primaryColor,
            filledColor: filledColor,
            readOnly: isEditMode,
          ),
          const SizedBox(height: 16),

          // Order Type (styled exactly like Category dropdown)
          CreateOrderFormHelpers.buildFieldLabel('Type', labelColor),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: currentType,
            decoration: InputDecoration(
              hintText: 'Select Type',
              hintStyle: TextStyle(fontSize: 14, color: labelColor),
              prefixIcon: Icon(
                currentType == 'Rental'
                    ? Icons.inventory_2_outlined
                    : Icons.celebration_outlined,
                color: labelColor,
              ),
              filled: true,
              fillColor: surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            dropdownColor: surfaceColor,
            items: [
              DropdownMenuItem(
                value: 'Event',
                child: Row(
                  children: [
                    Icon(
                      Icons.celebration_outlined,
                      size: 18,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Event',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'Rental',
                child: Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 18,
                      color: Color(0xFF8b5cf6),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Rental',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                onOrderTypeChanged(val);
              }
            },
          ),
          const SizedBox(height: 16),

          CreateOrderFormHelpers.buildFieldLabel('Event Name', labelColor),
          CreateOrderFormHelpers.buildTextField(
            controller: eventNameController,
            hintText: 'e.g. Annual Tech Summit 2024',
            icon: Icons.event_note,
            textColor: textColor,
            labelColor: labelColor,
            borderColor: borderColor,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 16),

          CreateOrderFormHelpers.buildFieldLabel('Event Date', labelColor),
          CreateOrderFormHelpers.buildDateSelector(
            context: context,
            label: 'Event Date',
            dateText: dateTextEvent,
            icon: Icons.calendar_today,
            textColor: textColor,
            labelColor: labelColor,
            onTap: onSelectEventDate,
          ),
          const SizedBox(height: 16),

          CreateOrderFormHelpers.buildFieldLabel('Setup Date', labelColor),
          CreateOrderFormHelpers.buildDateSelector(
            context: context,
            label: 'Setup Date',
            dateText: dateTextSetup,
            icon: Icons.build_circle_outlined,
            textColor: textColor,
            labelColor: labelColor,
            onTap: onSelectSetupDate,
          ),
          const SizedBox(height: 16),

          CreateOrderFormHelpers.buildFieldLabel('Venue', labelColor),
          CreateOrderFormHelpers.buildTextField(
            controller: venueController,
            hintText: 'Enter venue location',
            icon: Icons.location_on_outlined,
            textColor: textColor,
            labelColor: labelColor,
            borderColor: borderColor,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 16),

          CreateOrderFormHelpers.buildFieldLabel('Contact Person', labelColor),
          CreateOrderFormHelpers.buildTextField(
            controller: contactPersonController,
            hintText: 'Name',
            icon: Icons.person_outline,
            textColor: textColor,
            labelColor: labelColor,
            borderColor: borderColor,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 16),

          CreateOrderFormHelpers.buildFieldLabel('Contact Number', labelColor),
          CreateOrderFormHelpers.buildTextField(
            controller: contactNumberController,
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

          CreateOrderFormHelpers.buildFieldLabel('Category', labelColor),
          CreateOrderCategorySelectorWidget(
            selectedCategory: selectedCategory,
            onCategorySelected: onCategorySelected,
            primaryColor: primaryColor,
            labelColor: labelColor,
            textColor: textColor,
            borderColor: borderColor,
            surfaceColor: surfaceColor,
          ),
          const SizedBox(height: 16),

          CreateOrderFormHelpers.buildFieldLabel(
            'Order Description',
            labelColor,
          ),
          CreateOrderFormHelpers.buildTextField(
            controller: descriptionController,
            hintText: 'Enter order details/description',
            icon: Icons.description_outlined,
            maxLines: 3,
            textColor: textColor,
            labelColor: labelColor,
            borderColor: borderColor,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 16),

          CreateOrderFormHelpers.buildFieldLabel(
            'VAT (Grand Total)',
            labelColor,
          ),
          Row(
            children: [
              CreateOrderFormHelpers.vatChip(
                rate: 0.0,
                currentVatRate: vatRate,
                label: 'No VAT (0%)',
                primaryColor: primaryColor,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                textColor: textColor,
                onTap: onVatRateSelected,
              ),
              const SizedBox(width: 12),
              CreateOrderFormHelpers.vatChip(
                rate: 0.13,
                currentVatRate: vatRate,
                label: 'VAT (13%)',
                primaryColor: primaryColor,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                textColor: textColor,
                onTap: onVatRateSelected,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
