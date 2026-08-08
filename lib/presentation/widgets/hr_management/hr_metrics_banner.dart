import 'package:flutter/material.dart';

class HrMetricsBannerWidget extends StatelessWidget {
  final int totalStaff;
  final int checkedIn;
  final int onLeave;
  final int pendingLeaves;

  const HrMetricsBannerWidget({
    super.key,
    required this.totalStaff,
    required this.checkedIn,
    required this.onLeave,
    required this.pendingLeaves,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final card1 = _buildMetricCard(
      context,
      title: 'Total Staff',
      value: '$totalStaff',
      icon: Icons.badge_outlined,
      color: colorScheme.primary,
    );
    final card2 = _buildMetricCard(
      context,
      title: 'Checked In',
      value: '$checkedIn',
      icon: Icons.check_circle_outline,
      color: Colors.green,
    );
    final card3 = _buildMetricCard(
      context,
      title: 'On Leave',
      value: '$onLeave',
      icon: Icons.beach_access_outlined,
      color: Colors.orange,
    );
    final card4 = _buildMetricCard(
      context,
      title: 'Pending Leaves',
      value: '$pendingLeaves',
      icon: Icons.pending_actions_outlined,
      color: pendingLeaves > 0 ? Colors.red : colorScheme.onSurfaceVariant,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: isMobile
          ? Column(
              children: [
                Row(
                  children: [
                    Expanded(child: card1),
                    const SizedBox(width: 8),
                    Expanded(child: card2),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: card3),
                    const SizedBox(width: 8),
                    Expanded(child: card4),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: card1),
                const SizedBox(width: 8),
                Expanded(child: card2),
                const SizedBox(width: 8),
                Expanded(child: card3),
                const SizedBox(width: 8),
                Expanded(child: card4),
              ],
            ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
