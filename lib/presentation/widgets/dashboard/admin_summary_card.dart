import 'package:flutter/material.dart';

class AdminSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isPrimary;
  final Color? iconColor;
  final double? width;

  const AdminSummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isPrimary = false,
    this.iconColor,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;

    final wellColor = colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.3,
    );

    return Container(
      width: width ?? 176,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPrimary ? color : wellColor,
        borderRadius: BorderRadius.circular(8),
        border: !isPrimary
            ? Border.all(color: colorScheme.outline.withValues(alpha: 0.3))
            : null,
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isPrimary
                  ? colorScheme.onPrimary.withValues(alpha: 0.2)
                  : (iconColor ?? color).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              icon,
              color: isPrimary ? Colors.white : (iconColor ?? color),
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isPrimary ? Colors.white : colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isPrimary
                  ? Colors.white.withValues(alpha: 0.8)
                  : labelColor,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
