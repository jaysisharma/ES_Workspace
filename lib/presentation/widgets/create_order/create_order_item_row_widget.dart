import 'package:flutter/material.dart';
import 'package:order_app/presentation/widgets/common/vendor_autocomplete_field.dart';
import 'item_row_model.dart';

class CreateOrderItemRowWidget extends StatelessWidget {
  final int index;
  final ItemRow item;
  final int totalItems;
  final VoidCallback onRemove;
  final Color primaryColor;
  final Color textColor;
  final Color labelColor;
  final Color borderColor;

  const CreateOrderItemRowWidget({
    super.key,
    required this.index,
    required this.item,
    required this.totalItems,
    required this.onRemove,
    required this.primaryColor,
    required this.textColor,
    required this.labelColor,
    required this.borderColor,
  });

  Widget _buildFieldLabel(String label) {
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

  Widget _buildTextField({
    required String hintText,
    IconData? icon,
    TextInputType? keyboardType,
    TextEditingController? controller,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: textColor, fontSize: 14),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: labelColor),
        prefixIcon: icon != null
            ? Icon(icon, color: labelColor, size: 20)
            : null,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
              if (totalItems > 1)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.redAccent,
                  ),
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFieldLabel('Item Name'),
          _buildTextField(
            controller: item.nameController,
            hintText: 'e.g. LED Wall P3',
          ),
          const SizedBox(height: 14),
          _buildFieldLabel('Specification'),
          _buildTextField(
            controller: item.specController,
            hintText: 'e.g. 20ft x 10ft',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Unit'),
                    _buildTextField(
                      controller: item.unitController,
                      hintText: 'Pcs / Set',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Qty'),
                    _buildTextField(
                      controller: item.qtyController,
                      hintText: '1',
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Days'),
                    _buildTextField(
                      controller: item.daysController,
                      hintText: '1',
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildFieldLabel('Vendor (Optional)'),
          VendorAutocompleteField(
            controller: item.vendorController,
            hintText: 'Select or type vendor',
            icon: Icons.storefront_outlined,
          ),
        ],
      ),
    );
  }
}
