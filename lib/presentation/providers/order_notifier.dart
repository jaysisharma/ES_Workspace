import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/entities/order_item_entity.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../core/services/fcm_sender.dart';
import 'order_providers.dart';
import 'notification_notifier.dart';
import 'auth_provider.dart';
import '../../domain/entities/notification_entity.dart';
import 'package:uuid/uuid.dart';

class OrderState {
  final List<OrderEntity> orders;
  final bool isLoading;
  final String? error;
  final dynamic lastDoc;
  final bool hasMore;

  const OrderState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
    this.lastDoc,
    this.hasMore = true,
  });

  OrderState copyWith({
    List<OrderEntity>? orders,
    bool? isLoading,
    String? error,
    bool clearError = false,
    dynamic lastDoc,
    bool? hasMore,
    bool clearLastDoc = false,
  }) {
    return OrderState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastDoc: clearLastDoc ? null : (lastDoc ?? this.lastDoc),
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class OrderNotifier extends Notifier<OrderState> {
  @override
  OrderState build() {
    return const OrderState();
  }

  Future<void> loadOrders() async {
    state = state.copyWith(
      isLoading: true, 
      clearError: true, 
      clearLastDoc: true,
      hasMore: true,
      orders: [],
    );
    try {
      final result = await ref.read(orderRepositoryProvider).getOrdersPaginated(10);
      state = state.copyWith(
        isLoading: false, 
        orders: result['orders'] as List<OrderEntity>,
        lastDoc: result['lastDoc'],
        hasMore: result['hasMore'] as bool,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMoreOrders() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await ref.read(orderRepositoryProvider).getOrdersPaginated(
        10, 
        lastDoc: state.lastDoc,
      );
      
      final newOrders = result['orders'] as List<OrderEntity>;
      state = state.copyWith(
        isLoading: false,
        orders: [...state.orders, ...newOrders],
        lastDoc: result['lastDoc'],
        hasMore: result['hasMore'] as bool,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> create(OrderEntity order) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final now = DateTime.now();
      final orderWithLog = order.copyWith(
        logs: [OrderLogEntity(timestamp: now, message: 'Order created')],
      );
      await ref.read(createOrderUseCaseProvider)(orderWithLog);

      final currentRole = ref.read(authNotifierProvider).user?.role;

      // Notify founder only (admin already knows — they just created it)
      if (currentRole != UserRole.founder) {
        await ref.read(notificationNotifierProvider.notifier).addNotification(
          NotificationEntity(
            id: const Uuid().v4(),
            title: 'New Order Created',
            description: 'Order for "${order.eventName}" has been created.',
            timestamp: DateTime.now(),
            type: 'order',
            relatedId: order.id,
            targetRole: 'founder',
          ),
        );
        FcmSender.sendToTopic(
          topic: 'role_founder',
          title: 'New Order Created',
          body: 'Order for "${order.eventName}" has been created.',
        );
      }

      // Notify each assigned staff member individually
      for (final staffId in order.assignedStaffIds) {
        await ref.read(notificationNotifierProvider.notifier).addNotification(
          NotificationEntity(
            id: const Uuid().v4(),
            title: 'You\'ve Been Assigned',
            description: 'You are assigned to "${order.eventName}".',
            timestamp: DateTime.now(),
            type: 'order',
            relatedId: order.id,
            targetRole: 'staff',
            targetUserId: staffId,
          ),
        );
        FcmSender.sendToUser(
          userId: staffId,
          title: 'You\'ve Been Assigned',
          body: 'You are assigned to "${order.eventName}".',
        );
      }

      loadOrders();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateOrder(OrderEntity order) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final oldOrder = state.orders.where((o) => o.id == order.id).firstOrNull;
      List<OrderLogEntity> newLogs = List.from(order.logs);
      final now = DateTime.now();

      if (oldOrder != null && oldOrder.status != order.status) {
        newLogs.add(
          OrderLogEntity(
            timestamp: now,
            message: 'Status updated to ${_statusLabel(order.status)}',
          ),
        );

        // Notify founder of status changes
        ref.read(notificationNotifierProvider.notifier).addNotification(
          NotificationEntity(
            id: const Uuid().v4(),
            title: 'Order Status Updated',
            description:
                'Order "${order.eventName}" is now ${_statusLabel(order.status)}.',
            timestamp: now,
            type: 'system',
            relatedId: order.id,
            targetRole: 'founder',
          ),
        );
        FcmSender.sendToTopic(
          topic: 'role_founder',
          title: 'Order Status Updated',
          body: 'Order "${order.eventName}" is now ${_statusLabel(order.status)}.',
        );

        // Also notify each assigned staff member
        for (final staffId in order.assignedStaffIds) {
          ref.read(notificationNotifierProvider.notifier).addNotification(
            NotificationEntity(
              id: const Uuid().v4(),
              title: 'Order Status Updated',
              description:
                  '"${order.eventName}" is now ${_statusLabel(order.status)}.',
              timestamp: now,
              type: 'system',
              relatedId: order.id,
              targetRole: 'staff',
              targetUserId: staffId,
            ),
          );
          FcmSender.sendToUser(
            userId: staffId,
            title: 'Order Status Updated',
            body: '"${order.eventName}" is now ${_statusLabel(order.status)}.',
          );
        }
      } else if (oldOrder != null &&
          oldOrder.totalAmount != order.totalAmount) {
        newLogs.add(
          OrderLogEntity(
            timestamp: now,
            message:
                'Revenue updated to Rs. ${order.totalAmount.toStringAsFixed(0)}',
          ),
        );
      } else if (oldOrder != null &&
          oldOrder.totalExpenses != order.totalExpenses) {
        newLogs.add(
          OrderLogEntity(
            timestamp: now,
            message:
                'Expenses updated to Rs. ${order.totalExpenses.toStringAsFixed(0)}',
          ),
        );
      } else {
        newLogs.add(
          OrderLogEntity(timestamp: now, message: 'Order details updated'),
        );
      }

      final updatedOrder = order.copyWith(logs: newLogs, updatedAt: now);
      await ref.read(updateOrderUseCaseProvider)(updatedOrder);
      await loadOrders();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  String _statusLabel(OrderStatus s) {
    switch (s) {
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.inProgress:
        return 'In Progress';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.locked:
        return 'Locked';
      case OrderStatus.draft:
        return 'Draft';
    }
  }

  Future<void> delete(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(deleteOrderUseCaseProvider)(id);
      await loadOrders();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> finalizeRevenue(
    OrderEntity order,
    List<OrderItemEntity> items,
    List<ExpenseEntity> additionalRevenue,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final now = DateTime.now();
      final newLogs = List<OrderLogEntity>.from(order.logs);
      newLogs.add(
        OrderLogEntity(
          timestamp: now,
          message:
              'Revenue finalized to Rs. ${order.totalAmount.toStringAsFixed(0)}',
        ),
      );

      final updatedOrder = order.copyWith(logs: newLogs, updatedAt: now);
      await ref
          .read(finalizeRevenueUseCaseProvider)(updatedOrder, items, additionalRevenue);

      // Notify admin + founder
      await ref
          .read(notificationNotifierProvider.notifier)
          .addNotification(
            NotificationEntity(
              id: const Uuid().v4(),
              title: 'Revenue Finalized',
              description:
                  'Revenue for "${order.eventName}" finalized at Rs. ${order.totalAmount.toStringAsFixed(0)}',
              timestamp: DateTime.now(),
              type: 'finance',
              relatedId: order.id,
              targetRole: 'admin_founder',
            ),
          );
      FcmSender.sendToTopics(
        topics: ['role_admin', 'role_founder'],
        title: 'Revenue Finalized',
        body: 'Revenue for "${order.eventName}" finalized at Rs. ${order.totalAmount.toStringAsFixed(0)}',
      );

      await loadOrders();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> finalizeExpenses(
    OrderEntity order,
    List<ExpenseEntity> expenses,
    List<OrderItemEntity> items,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final now = DateTime.now();
      final newLogs = List<OrderLogEntity>.from(order.logs);
      newLogs.add(
        OrderLogEntity(
          timestamp: now,
          message:
              'Expenses finalized to Rs. ${order.totalExpenses.toStringAsFixed(0)}',
        ),
      );

      final updatedOrder = order.copyWith(logs: newLogs, updatedAt: now);
      await ref.read(finalizeExpensesUseCaseProvider)(
        updatedOrder,
        expenses,
        items,
      );

      // Notify admin + founder
      await ref
          .read(notificationNotifierProvider.notifier)
          .addNotification(
            NotificationEntity(
              id: const Uuid().v4(),
              title: 'Expenses Finalized',
              description:
                  'Expenses for "${order.eventName}" finalized at Rs. ${order.totalExpenses.toStringAsFixed(0)}',
              timestamp: DateTime.now(),
              type: 'finance',
              relatedId: order.id,
              targetRole: 'admin_founder',
            ),
          );
      FcmSender.sendToTopics(
        topics: ['role_admin', 'role_founder'],
        title: 'Expenses Finalized',
        body: 'Expenses for "${order.eventName}" finalized at Rs. ${order.totalExpenses.toStringAsFixed(0)}',
      );

      await loadOrders();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
