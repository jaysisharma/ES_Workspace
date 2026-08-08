import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
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
    final updatedItems = state.items.map((i) => i.id == item.id ? item : i).toList();
    state = state.copyWith(items: updatedItems, clearError: true);
    try {
      await ref.read(updateOrderItemUseCaseProvider)(item);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> bulkUpdateItems(List<OrderItemEntity> items) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updateUseCase = ref.read(updateOrderItemUseCaseProvider);
      await Future.wait(items.map((item) => updateUseCase(item)));
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
    final updatedItem = item.copyWith(isCompleted: !item.isCompleted);
    await updateItem(updatedItem);
  }

  Future<void> assignStaffToTask(OrderItemEntity item, String? staffId, String? staffName) async {
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
        return item.copyWith(assignedStaffId: staffId, assignedStaffName: staffName);
      }
    }).toList();
    await bulkUpdateItems(updatedItems);
  }

  Future<void> deleteItemsForOrder(String orderId) async {
    try {
      // Fetch items for this order from Firestore, then delete each one
      final items = await ref.read(getOrderItemsUseCaseProvider)(orderId);
      final deleteUseCase = ref.read(deleteOrderItemUseCaseProvider);
      await Future.wait(items.map((item) => deleteUseCase(item.id)));
      // Update local state
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
