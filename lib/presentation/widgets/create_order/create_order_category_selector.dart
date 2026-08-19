import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/presentation/providers/category_providers.dart';
import 'package:order_app/presentation/widgets/create_order/manage_categories_dialog.dart';

class CreateOrderCategorySelectorWidget extends ConsumerWidget {
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;
  final Color primaryColor;
  final Color labelColor;
  final Color textColor;
  final Color borderColor;
  final Color surfaceColor;

  const CreateOrderCategorySelectorWidget({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.primaryColor,
    required this.labelColor,
    required this.textColor,
    required this.borderColor,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(orderCategoriesStreamProvider);

    return categoriesAsync.when(
      data: (categories) {
        final isValidSelection = categories.contains(selectedCategory);

        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: isValidSelection ? selectedCategory : null,
                decoration: InputDecoration(
                  hintText: 'Select Category',
                  hintStyle: TextStyle(fontSize: 14, color: labelColor),
                  prefixIcon: Icon(Icons.category_outlined, color: labelColor),
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
                    value: '__MANAGE__',
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Manage / Add / Remove...',
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
                  if (val == '__MANAGE__') {
                    ManageCategoriesDialog.show(context);
                  } else {
                    onCategorySelected(val);
                  }
                },
                dropdownColor: surfaceColor,
                icon: Icon(Icons.arrow_drop_down, color: labelColor),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.tune_rounded, color: primaryColor, size: 20),
              tooltip: 'Manage & Remove Categories',
              style: IconButton.styleFrom(
                backgroundColor: primaryColor.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
              ),
              onPressed: () => ManageCategoriesDialog.show(context),
            ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(
        'Error loading categories: $e',
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }
}
