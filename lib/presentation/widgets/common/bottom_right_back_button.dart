import 'package:flutter/material.dart';

class BottomRightBackButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const BottomRightBackButton({
    super.key,
    this.label = 'Back to Dashboard',
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (!Navigator.canPop(context)) return const SizedBox.shrink();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0075db);
    final bgColor = isDarkMode ? const Color(0xFF1e293b) : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final borderColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFcbd5e1);

    return Material(
      color: Colors.transparent,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onPressed ?? () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 16,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  fontFamily: 'Manrope',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
