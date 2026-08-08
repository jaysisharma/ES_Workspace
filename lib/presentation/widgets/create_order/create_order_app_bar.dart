import 'package:flutter/material.dart';

class CreateOrderAppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final bool isEditMode;
  final bool isSaving;
  final VoidCallback onSaveDraft;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final Color labelColor;
  final Color primaryColor;

  const CreateOrderAppBarWidget({
    super.key,
    required this.isEditMode,
    required this.isSaving,
    required this.onSaveDraft,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.labelColor,
    required this.primaryColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
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
                backgroundColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(
              isEditMode ? 'Edit Order' : 'Create Event Order',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
                letterSpacing: -0.5,
              ),
            ),
            if (!isEditMode)
              TextButton(
                onPressed: isSaving ? null : onSaveDraft,
                child: isSaving
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
    );
  }
}
