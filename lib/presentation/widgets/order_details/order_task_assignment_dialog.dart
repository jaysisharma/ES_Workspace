import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:order_app/core/services/fcm_sender.dart';
import 'package:order_app/domain/entities/notification_entity.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/providers/hr_providers.dart';
import 'package:order_app/presentation/providers/notification_notifier.dart';
import 'package:order_app/presentation/providers/order_providers.dart';

/// Helper to show task assignment dialog for a single item.
void showAssignTaskDialog(
  BuildContext context,
  WidgetRef ref,
  OrderEntity order,
  OrderItemEntity item,
) {
  showDialog(
    context: context,
    builder: (ctx) {
      final usersAsync = ref.watch(usersStreamProvider);
      return AlertDialog(
        title: Text(
          'Assign Task: ${item.itemName}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 320,
          child: usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error loading staff: $e'),
            data: (users) {
              final staffUsers = users
                  .where((u) => u.role == UserRole.staff && u.isActive)
                  .toList();
              return ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_off_outlined, color: Colors.grey),
                    title: const Text('Unassigned'),
                    onTap: () async {
                      await ref
                          .read(orderItemNotifierProvider.notifier)
                          .assignStaffToTask(item, null, null);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                  const Divider(),
                  ...staffUsers.map((staff) {
                    final isSelected = item.assignedStaffId == staff.id;
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          staff.name.isNotEmpty
                              ? staff.name[0].toUpperCase()
                              : 'S',
                        ),
                      ),
                      title: Text(
                        staff.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        staff.email,
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.blue)
                          : null,
                      onTap: () async {
                        await ref
                            .read(orderItemNotifierProvider.notifier)
                            .assignStaffToTask(item, staff.id, staff.name);
                        await ref
                            .read(notificationNotifierProvider.notifier)
                            .addNotification(
                              NotificationEntity(
                                id: const Uuid().v4(),
                                title: 'Task Assigned',
                                description:
                                    'You are assigned task "${item.itemName}" in "${order.eventName}".',
                                timestamp: DateTime.now(),
                                type: 'order',
                                relatedId: order.id,
                                targetRole: 'staff',
                                targetUserId: staff.id,
                              ),
                            );
                        FcmSender.sendToUser(
                          userId: staff.id,
                          title: 'Task Assigned',
                          body:
                              'You are assigned task "${item.itemName}" in "${order.eventName}".',
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    );
                  }),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

/// Helper to show assignment dialog for all tasks in an order.
void showAssignAllTasksDialog(
  BuildContext context,
  WidgetRef ref,
  OrderEntity order,
) {
  showDialog(
    context: context,
    builder: (ctx) {
      final usersAsync = ref.watch(usersStreamProvider);
      return AlertDialog(
        title: Text(
          'Assign ALL Tasks in ${order.eventName}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 320,
          child: usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error loading staff: $e'),
            data: (users) {
              final staffUsers = users
                  .where((u) => u.role == UserRole.staff && u.isActive)
                  .toList();
              return ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_off_outlined, color: Colors.grey),
                    title: const Text('Unassign All Tasks'),
                    onTap: () async {
                      await ref
                          .read(orderItemNotifierProvider.notifier)
                          .assignAllTasksToStaff(null, null);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                  const Divider(),
                  ...staffUsers.map((staff) {
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          staff.name.isNotEmpty
                              ? staff.name[0].toUpperCase()
                              : 'S',
                        ),
                      ),
                      title: Text(
                        staff.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        staff.email,
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () async {
                        await ref
                            .read(orderItemNotifierProvider.notifier)
                            .assignAllTasksToStaff(staff.id, staff.name);
                        await ref
                            .read(notificationNotifierProvider.notifier)
                            .addNotification(
                              NotificationEntity(
                                id: const Uuid().v4(),
                                title: 'All Tasks Assigned',
                                description:
                                    'You have been assigned all tasks for event "${order.eventName}".',
                                timestamp: DateTime.now(),
                                type: 'order',
                                relatedId: order.id,
                                targetRole: 'staff',
                                targetUserId: staff.id,
                              ),
                            );
                        FcmSender.sendToUser(
                          userId: staff.id,
                          title: 'All Tasks Assigned',
                          body:
                              'You have been assigned all tasks for event "${order.eventName}".',
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    );
                  }),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}
