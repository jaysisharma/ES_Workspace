import 'package:flutter/material.dart';
import '../../screens/common/revenue_summary_screen.dart' show FinancialViewMode;

class FinancialPerspectiveToggle extends StatelessWidget {
  final FinancialViewMode viewType;
  final ValueChanged<FinancialViewMode> onChanged;

  const FinancialPerspectiveToggle({
    super.key,
    required this.viewType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;
    final borderColor = colorScheme.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FINANCIAL PERSPECTIVE',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: labelColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<FinancialViewMode>(
            segments: const [
              ButtonSegment(
                value: FinancialViewMode.revenue,
                label: Text('Revenue'),
                icon: Icon(Icons.trending_up, size: 16),
              ),
              ButtonSegment(
                value: FinancialViewMode.expenses,
                label: Text('Expenses'),
                icon: Icon(Icons.trending_down, size: 16),
              ),
              ButtonSegment(
                value: FinancialViewMode.both,
                label: Text('Both'),
                icon: Icon(Icons.balance, size: 16),
              ),
            ],
            selected: {viewType},
            onSelectionChanged: (newSelection) {
              onChanged(newSelection.first);
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: colorScheme.primary.withValues(
                alpha: 0.1,
              ),
              selectedForegroundColor: colorScheme.primary,
              side: BorderSide(color: borderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
