import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/presentation/providers/category_providers.dart';

class ManageCategoriesDialog extends ConsumerStatefulWidget {
  const ManageCategoriesDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const ManageCategoriesDialog(),
    );
  }

  @override
  ConsumerState<ManageCategoriesDialog> createState() =>
      _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState
    extends ConsumerState<ManageCategoriesDialog> {
  final TextEditingController _newCategoryController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(categoryActionProvider).addCategory(name);
      _newCategoryController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "$name" added'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding category: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteCategory(String category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove Category "$category"?'),
        content: Text(
          'Are you sure you want to remove "$category"? It will no longer appear in category selection options.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref.read(categoryActionProvider).deleteCategory(category);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Category "$category" removed'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting category: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0075db);
    final bgColor = isDarkMode ? const Color(0xFF141e28) : Colors.white;
    final surfaceAccent =
        isDarkMode ? const Color(0xFF1e2b38) : const Color(0xFFf8fafc);
    final borderColor =
        isDarkMode ? const Color(0xFF2a3b4c) : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final textMuted =
        isDarkMode ? const Color(0xFF94a3b8) : const Color(0xFF64748b);

    final categoriesAsync = ref.watch(orderCategoriesStreamProvider);

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 580),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.category_rounded,
                        color: primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Categories',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Manrope',
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Add new or remove existing categories',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: surfaceAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Add New Category Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCategoryController,
                    onSubmitted: (_) => _addCategory(),
                    decoration: InputDecoration(
                      hintText: 'Enter new category name...',
                      hintStyle: TextStyle(fontSize: 13, color: textMuted),
                      prefixIcon: Icon(
                        Icons.add_circle_outline_rounded,
                        size: 18,
                        color: textMuted,
                      ),
                      filled: true,
                      fillColor: surfaceAccent,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: primaryColor,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                    style: TextStyle(fontSize: 13, color: textColor),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _addCategory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Add',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Text(
              'ACTIVE CATEGORIES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textMuted,
                letterSpacing: 1.1,
              ),
            ),

            const SizedBox(height: 8),

            // List of Categories
            Expanded(
              child: categoriesAsync.when(
                data: (categories) {
                  if (categories.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 40,
                            color: textMuted,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No categories found',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: categories.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: surfaceAccent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              tooltip: 'Remove $category',
                              onPressed: () => _deleteCategory(category),
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    Colors.redAccent.withValues(alpha: 0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(6),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text(
                    'Error: $err',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Close Button
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: surfaceAccent,
                  foregroundColor: textColor,
                  elevation: 0,
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
