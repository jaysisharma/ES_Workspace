import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/order_providers.dart';

class OrderDetailsBottomActionsWidget extends ConsumerWidget {
  final OrderEntity order;
  final String Function(OrderStatus) statusLabel;
  final Future<void> Function(OrderStatus) onUpdateStatus;
  final Color primaryColor;
  final Color successColor;
  final Color warningColor;
  final Color surfaceColor;
  final Color textColor;
  final bool isDarkMode;

  const OrderDetailsBottomActionsWidget({
    super.key,
    required this.order,
    required this.statusLabel,
    required this.onUpdateStatus,
    required this.primaryColor,
    required this.successColor,
    required this.warningColor,
    required this.surfaceColor,
    required this.textColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (order.status == OrderStatus.draft) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => onUpdateStatus(OrderStatus.confirmed),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          icon: const Icon(Icons.check_circle_outline, color: Colors.white),
          label: const Text(
            'Confirm Order',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    if (order.status == OrderStatus.confirmed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => onUpdateStatus(OrderStatus.inProgress),
              style: ElevatedButton.styleFrom(
                backgroundColor: warningColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              label: const Text(
                'Mark In Progress',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (order.status == OrderStatus.inProgress) {
      final itemState = ref.watch(orderItemNotifierProvider);
      final completedItems = itemState.items.where((i) => i.isCompleted).length;
      final totalItems = itemState.items.length;
      final allDone = totalItems > 0 && completedItems == totalItems;

      final authState = ref.watch(authNotifierProvider);
      final isAdmin = authState.user?.role == UserRole.admin ||
          authState.user?.role == UserRole.founder;

      final canComplete = allDone;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!allDone && isAdmin)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Items pending, but Admin bypass enabled',
                style: TextStyle(
                  fontSize: 12,
                  color: warningColor,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: canComplete
                  ? Colors.greenAccent.shade700
                  : successColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: canComplete
                  ? [
                      BoxShadow(
                        color: Colors.greenAccent.shade700.withValues(
                          alpha: 0.4,
                        ),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton.icon(
              onPressed: canComplete
                  ? () => onUpdateStatus(OrderStatus.completed)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                canComplete
                    ? Icons.done_all_rounded
                    : Icons.lock_clock_outlined,
                color: canComplete
                    ? Colors.white
                    : successColor.withValues(alpha: 0.5),
              ),
              label: Text(
                allDone
                    ? 'Mark as Completed'.toUpperCase()
                    : 'Finish all items to complete'.toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: canComplete
                      ? Colors.white
                      : successColor.withValues(alpha: 0.5),
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Completed / Locked
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: successColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: successColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_rounded, color: successColor),
          const SizedBox(width: 8),
          Text(
            'Order ${statusLabel(order.status)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: successColor,
            ),
          ),
        ],
      ),
    );
  }
}
