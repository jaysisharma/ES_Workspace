import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/presentation/providers/category_providers.dart';

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

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final customCategoryController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom Category'),
        content: TextField(
          controller: customCategoryController,
          decoration: const InputDecoration(
            hintText: 'Category Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newCat = customCategoryController.text.trim();
              if (newCat.isNotEmpty) {
                await ref.read(categoryActionProvider).addCategory(newCat);
                onCategorySelected(newCat);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((_) {
      if (selectedCategory == 'ADD_NEW') {
        onCategorySelected(null);
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(orderCategoriesStreamProvider);

    return categoriesAsync.when(
      data: (categories) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: categories.contains(selectedCategory)
                ? selectedCategory
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
                _showAddCategoryDialog(context, ref);
              } else {
                onCategorySelected(val);
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
}
