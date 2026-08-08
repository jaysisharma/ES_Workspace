import 'package:flutter/material.dart';

class CreateOrderBottomNavBarWidget extends StatelessWidget {
  final bool isEditMode;
  final bool isSaving;
  final VoidCallback onSubmit;
  final VoidCallback onSaveDraft;
  final Color primaryColor;
  final Color surfaceColor;
  final Color borderColor;
  final Color textColor;

  const CreateOrderBottomNavBarWidget({
    super.key,
    required this.isEditMode,
    required this.isSaving,
    required this.onSubmit,
    required this.onSaveDraft,
    required this.primaryColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
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
            onPressed: isSaving ? null : onSubmit,
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
            child: isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isEditMode
                            ? Icons.save_rounded
                            : Icons.verified_outlined,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEditMode ? 'Save Changes' : 'Confirm Order',
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
            onPressed: isSaving ? null : onSaveDraft,
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
            child: isSaving
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
    );
  }
}
