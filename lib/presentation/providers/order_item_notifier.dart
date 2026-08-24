import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/domain/entities/notification_entity.dart';
import 'package:order_app/core/services/fcm_sender.dart';
import 'package:order_app/presentation/providers/notification_notifier.dart';
import 'order_providers.dart';

class OrderItemState {
  final List<OrderItemEntity> items;
  final bool isLoading;
  final String? error;

  const OrderItemState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  OrderItemState copyWith({
    List<OrderItemEntity>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return OrderItemState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class OrderItemNotifier extends Notifier<OrderItemState> {
  @override
  OrderItemState build() {
    return const OrderItemState();
  }

  Future<void> loadItems(String orderId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await ref.read(getOrderItemsUseCaseProvider)(orderId);
      state = state.copyWith(isLoading: false, items: items);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addItem(OrderItemEntity item, {bool reload = true}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(addOrderItemUseCaseProvider)(item);
      ref.invalidate(allItemsStreamProvider);
      if (reload) {
        loadItems(item.orderId);
      }
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateItem(OrderItemEntity item) async {
    // Optimistic local update so UI does not collapse or trigger scroll jumps
    final updatedItems =
        state.items.map((i) => i.id == item.id ? item : i).toList();
    state = state.copyWith(items: updatedItems, clearError: true);
    try {
      await ref.read(updateOrderItemUseCaseProvider)(item);
      ref.invalidate(allItemsStreamProvider);
    } catch (e) {
      debugPrint('❌ [OrderItemNotifier] Failed to update item: $e');
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> bulkUpdateItems(List<OrderItemEntity> items) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updateUseCase = ref.read(updateOrderItemUseCaseProvider);
      await Future.wait(items.map((item) => updateUseCase(item)));
      ref.invalidate(allItemsStreamProvider);
      if (items.isNotEmpty) {
        await loadItems(items.first.orderId);
      }
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> toggleCompletion(OrderItemEntity item) async {
    final newStatus = !item.isCompleted;
    final updatedItem = item.copyWith(isCompleted: newStatus);
    await updateItem(updatedItem);

    // If a staff member completed a manual task, alert admin and founder
    if (newStatus && item.isManualTask) {
      final staffName = item.assignedStaffName ?? 'Staff';
      try {
        final notifId = const Uuid().v4();
        await ref
            .read(notificationNotifierProvider.notifier)
            .addNotification(
              NotificationEntity(
                id: notifId,
                title: 'Task Completed',
                description: '$staffName completed task: "${item.itemName}".',
                timestamp: DateTime.now(),
                type: 'task',
                relatedId: item.id,
                targetRole: 'admin_founder',
              ),
            );
        FcmSender.sendToTopics(
          topics: ['role_admin', 'role_founder'],
          title: 'Task Completed',
          body: '$staffName completed task: "${item.itemName}".',
          notificationId: notifId,
        );
      } catch (e) {
        debugPrint('Failed to send task completed notification: $e');
      }
    }
  }

  Future<void> assignStaffToTask(
    OrderItemEntity item,
    String? staffId,
    String? staffName,
  ) async {
    final updatedItem = staffId == null || staffId.isEmpty
        ? item.copyWith(clearAssignedStaff: true)
        : item.copyWith(assignedStaffId: staffId, assignedStaffName: staffName);
    await updateItem(updatedItem);
  }

  Future<void> assignAllTasksToStaff(String? staffId, String? staffName) async {
    final updatedItems = state.items.map((item) {
      if (staffId == null || staffId.isEmpty) {
        return item.copyWith(clearAssignedStaff: true);
      } else {
        return item.copyWith(
          assignedStaffId: staffId,
          assignedStaffName: staffName,
        );
      }
    }).toList();
    await bulkUpdateItems(updatedItems);
  }

  Future<void> deleteItem(String itemId) async {
    try {
      await ref.read(deleteOrderItemUseCaseProvider)(itemId);
      ref.invalidate(allItemsStreamProvider);
      state = state.copyWith(
        items: state.items.where((i) => i.id != itemId).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteItemsForOrder(String orderId) async {
    try {
      final items = await ref.read(getOrderItemsUseCaseProvider)(orderId);
      final deleteUseCase = ref.read(deleteOrderItemUseCaseProvider);
      await Future.wait(items.map((item) => deleteUseCase(item.id)));
      ref.invalidate(allItemsStreamProvider);
      state = state.copyWith(items: []);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  bool isEventComplete() {
    if (state.items.isEmpty) return false;
    return state.items.every((item) => item.isCompleted);
  }
}
