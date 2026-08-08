import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CreateOrderFormHelpers {
  static Widget buildSectionTitle(String title, Color textColor) {
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

  static Widget buildFieldLabel(String label, Color labelColor) {
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

  static Widget buildTextField({
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

  static Widget buildDateSelector({
    required BuildContext context,
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

  static Widget vatChip({
    required double rate,
    required double currentVatRate,
    required String label,
    required Color primaryColor,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required ValueChanged<double> onTap,
  }) {
    final isSelected = currentVatRate == rate;
    return GestureDetector(
      onTap: () => onTap(rate),
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
}
