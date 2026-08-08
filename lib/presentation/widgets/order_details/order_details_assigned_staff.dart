import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/presentation/providers/hr_providers.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/widgets/order_details/staff_assignment_dialog.dart';
import 'package:order_app/presentation/widgets/order_details/order_details_helper_widgets.dart';

class OrderDetailsAssignedStaffWidget extends ConsumerWidget {
  final OrderEntity order;
  final bool isCanAssign;
  final Color defaultWellColor;
  final Color borderColor;
  final Color textColor;
  final Color labelColor;
  final Color primaryColor;
  final Color inputBgColor;

  const OrderDetailsAssignedStaffWidget({
    super.key,
    required this.order,
    required this.isCanAssign,
    required this.defaultWellColor,
    required this.borderColor,
    required this.textColor,
    required this.labelColor,
    required this.primaryColor,
    required this.inputBgColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersStreamProvider);

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
                'ASSIGNED STAFF',
                labelColor: labelColor,
                accentColor: primaryColor,
              ),
              if (isCanAssign)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 16,
                    color: primaryColor,
                  ),
                  label: Text(
                    order.assignedStaffIds.isEmpty
                        ? 'Assign Staff'
                        : 'Manage Staff',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => StaffAssignmentDialog(
                        orderId: order.id,
                        eventTitle: order.eventName,
                        eventDate: order.eventDate,
                        eventEndDate: order.eventEndDate,
                        currentAssignedStaffIds: order.assignedStaffIds,
                        onSaved: (newIds) async {
                          final updatedOrder = order.copyWith(
                            assignedStaffIds: newIds,
                          );
                          await ref
                              .read(orderNotifierProvider.notifier)
                              .updateOrder(updatedOrder);
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          usersAsync.when(
            loading: () => const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (err, stack) => Text(
              'Failed to load staff list',
              style: TextStyle(color: labelColor),
            ),
            data: (users) {
              final assignedUsers = users
                  .where((u) => order.assignedStaffIds.contains(u.id))
                  .toList();

              if (assignedUsers.isEmpty) {
                return Text(
                  'No staff assigned yet',
                  style: TextStyle(
                    fontSize: 13,
                    color: labelColor,
                    fontStyle: FontStyle.italic,
                  ),
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: assignedUsers.map((u) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: primaryColor.withValues(
                        alpha: 0.2,
                      ),
                      child: Text(
                        u.name.isNotEmpty ? u.name[0].toUpperCase() : 'S',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    label: Text(
                      u.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    backgroundColor: inputBgColor,
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
