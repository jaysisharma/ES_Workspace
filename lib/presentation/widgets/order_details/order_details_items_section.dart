import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/domain/entities/event_entity.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/event_notifier.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/providers/order_item_notifier.dart';
import 'package:order_app/presentation/widgets/order_details/order_details_helper_widgets.dart';
import 'package:order_app/presentation/widgets/order_details/order_task_assignment_dialog.dart';

class OrderDetailsItemsSectionWidget extends ConsumerWidget {
  final OrderEntity order;
  final OrderItemState itemState;
  final EventEntity? event;
  final bool isCanAssign;
  final bool isDarkMode;
  final Color primaryColor;
  final Color successColor;
  final Color defaultWellColor;
  final Color borderColor;
  final Color textColor;
  final Color labelColor;
  final Color inputBgColor;

  const OrderDetailsItemsSectionWidget({
    super.key,
    required this.order,
    required this.itemState,
    required this.event,
    required this.isCanAssign,
    required this.isDarkMode,
    required this.primaryColor,
    required this.successColor,
    required this.defaultWellColor,
    required this.borderColor,
    required this.textColor,
    required this.labelColor,
    required this.inputBgColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedItems = itemState.items.where((i) => i.isCompleted).length;
    final totalItems = itemState.items.length;
    final completion = totalItems > 0 ? completedItems / totalItems : 0.0;
    final userRole = ref.watch(authNotifierProvider).user?.role;
    final isAdminOrFounder = userRole == UserRole.admin || userRole == UserRole.founder;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: defaultWellColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SectionLabelWidget(
                'ITEMS LIST',
                labelColor: labelColor,
                accentColor: primaryColor,
              ),
              Row(
                children: [
                  if (isCanAssign && itemState.items.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(
                        Icons.assignment_ind_outlined,
                        size: 14,
                        color: primaryColor,
                      ),
                      label: Text(
                        'Assign All',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      onPressed: () => showAssignAllTasksDialog(
                        context,
                        ref,
                        order,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    '$completedItems / $totalItems done',
                    style: TextStyle(
                      fontSize: 12,
                      color: completedItems == totalItems && totalItems > 0
                          ? successColor
                          : labelColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (itemState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (itemState.items.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No items added yet',
                  style: TextStyle(color: labelColor),
                ),
              ),
            )
          else
            ...itemState.items.map(
              (item) => OrderItemRowWidget(
                item: item,
                onAssignStaff: isCanAssign
                    ? () => showAssignTaskDialog(
                          context,
                          ref,
                          order,
                          item,
                        )
                    : null,
                onTap: isAdminOrFounder
                    ? () async {
                        await ref
                            .read(
                              orderItemNotifierProvider.notifier,
                            )
                            .toggleCompletion(item);

                        if (event != null) {
                          final updatedItems = ref
                              .read(orderItemNotifierProvider)
                              .items;
                          if (updatedItems.isNotEmpty) {
                            final completedCount = updatedItems
                                .where(
                                  (i) => i.isCompleted,
                                )
                                .length;
                            final newCompletion =
                                completedCount / updatedItems.length;

                            await ref
                                .read(
                                  eventNotifierProvider.notifier,
                                )
                                .updateCompletion(
                                  event!.id,
                                  newCompletion,
                                );

                            final newStatus = newCompletion == 1.0
                                ? 'Completed'
                                : 'In Progress';
                            if (event!.status != newStatus) {
                              await ref
                                  .read(
                                    eventNotifierProvider.notifier,
                                  )
                                  .updateStatus(
                                    event!.id,
                                    newStatus,
                                  );
                            }
                          }
                        }
                      }
                    : null,
                primaryColor: primaryColor,
                successColor: successColor,
                inputBgColor: inputBgColor,
                borderColor: borderColor,
                textColor: textColor,
                labelColor: labelColor,
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SectionLabelWidget(
                'TASK COMPLETION',
                labelColor: labelColor,
                accentColor: Colors.greenAccent.shade700,
              ),
              Text(
                '${(completion * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: completion == 1.0
                      ? Colors.greenAccent.shade700
                      : primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: completion,
              minHeight: 10,
              backgroundColor: isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation<Color>(
                completion == 1.0
                    ? Colors.greenAccent.shade700
                    : primaryColor,
              ),
            ),
          ),
          if (event == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No event linked yet',
                style: TextStyle(
                  fontSize: 12,
                  color: labelColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
