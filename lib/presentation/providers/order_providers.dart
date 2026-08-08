import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/data/datasources/remote/firestore_order_remote_datasource.dart';
import 'package:order_app/data/datasources/remote/firestore_order_item_remote_datasource.dart';
import 'package:order_app/data/repositories/order_repository_impl.dart';
import 'package:order_app/data/repositories/order_item_repository_impl.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/domain/entities/expense_entity.dart';
import 'package:order_app/domain/usecases/get_orders_usecase.dart';
import 'package:order_app/domain/usecases/get_order_by_id_usecase.dart';
import 'package:order_app/domain/usecases/create_order_usecase.dart';
import 'package:order_app/domain/usecases/update_order_usecase.dart';
import 'package:order_app/domain/usecases/delete_order_usecase.dart';
import 'package:order_app/domain/usecases/finalize_revenue_usecase.dart';
import 'package:order_app/domain/usecases/finalize_expenses_usecase.dart';
import 'package:order_app/domain/usecases/get_expenses_usecase.dart';
import 'package:order_app/domain/usecases/get_order_items_usecase.dart';
import 'package:order_app/domain/usecases/get_additional_revenue_usecase.dart';
import 'package:order_app/domain/usecases/add_order_item_usecase.dart';
import 'package:order_app/domain/usecases/update_order_item_usecase.dart';
import 'package:order_app/domain/usecases/delete_order_item_usecase.dart';
import 'order_notifier.dart';
import 'order_item_notifier.dart';

// ── Data Sources ─────────────────────────────────────────────────────────────

final orderRemoteDataSourceProvider = Provider<OrderRemoteDataSource>((ref) {
  return FirestoreOrderRemoteDataSource();
});

final orderItemRemoteDataSourceProvider =
    Provider<OrderItemRemoteDataSource>((ref) {
      return FirestoreOrderItemRemoteDataSource();
    });

// ── Repositories ─────────────────────────────────────────────────────────────

final orderRepositoryProvider = Provider<OrderRepositoryImpl>((ref) {
  final remoteDataSource = ref.watch(orderRemoteDataSourceProvider);
  return OrderRepositoryImpl(remoteDataSource: remoteDataSource);
});

final orderItemRepositoryProvider = Provider<OrderItemRepositoryImpl>((ref) {
  final remoteDataSource = ref.watch(orderItemRemoteDataSourceProvider);
  return OrderItemRepositoryImpl(remoteDataSource: remoteDataSource);
});

// ── Use Cases ───────────────────────────────────────────────────────────────

final getOrdersUseCaseProvider = Provider<GetOrdersUseCase>((ref) {
  final repository = ref.watch(orderRepositoryProvider);
  return GetOrdersUseCase(repository);
});

final getOrderByIdUseCaseProvider = Provider<GetOrderByIdUseCase>((ref) {
  final repository = ref.watch(orderRepositoryProvider);
  return GetOrderByIdUseCase(repository);
});

final createOrderUseCaseProvider = Provider<CreateOrderUseCase>((ref) {
  final repository = ref.watch(orderRepositoryProvider);
  return CreateOrderUseCase(repository);
});

final updateOrderUseCaseProvider = Provider<UpdateOrderUseCase>((ref) {
  final repository = ref.watch(orderRepositoryProvider);
  return UpdateOrderUseCase(repository);
});

final deleteOrderUseCaseProvider = Provider<DeleteOrderUseCase>((ref) {
  final repository = ref.watch(orderRepositoryProvider);
  return DeleteOrderUseCase(repository);
});

final finalizeRevenueUseCaseProvider = Provider<FinalizeRevenueUseCase>((ref) {
  final repository = ref.watch(orderRepositoryProvider);
  return FinalizeRevenueUseCase(repository);
});

final finalizeExpensesUseCaseProvider = Provider<FinalizeExpensesUseCase>((
  ref,
) {
  final repository = ref.watch(orderRepositoryProvider);
  return FinalizeExpensesUseCase(repository);
});

final getExpensesUseCaseProvider = Provider<GetExpensesUseCase>((ref) {
  final repository = ref.watch(orderRepositoryProvider);
  return GetExpensesUseCase(repository);
});

final getAdditionalRevenueUseCaseProvider =
    Provider<GetAdditionalRevenueUseCase>((ref) {
      final repository = ref.watch(orderRepositoryProvider);
      return GetAdditionalRevenueUseCase(repository);
    });

final getOrderItemsUseCaseProvider = Provider<GetOrderItemsUseCase>((ref) {
  final repository = ref.watch(orderItemRepositoryProvider);
  return GetOrderItemsUseCase(repository);
});

final addOrderItemUseCaseProvider = Provider<AddOrderItemUseCase>((ref) {
  final repository = ref.watch(orderItemRepositoryProvider);
  return AddOrderItemUseCase(repository);
});

final updateOrderItemUseCaseProvider = Provider<UpdateOrderItemUseCase>((ref) {
  final repository = ref.watch(orderItemRepositoryProvider);
  return UpdateOrderItemUseCase(repository);
});

final deleteOrderItemUseCaseProvider = Provider<DeleteOrderItemUseCase>((ref) {
  final repository = ref.watch(orderItemRepositoryProvider);
  return DeleteOrderItemUseCase(repository);
});

// ── Notifiers ────────────────────────────────────────────────────────────────

final orderNotifierProvider =
    NotifierProvider<OrderNotifier, OrderState>(() {
      return OrderNotifier();
    });

final orderItemNotifierProvider =
    NotifierProvider<OrderItemNotifier, OrderItemState>(() {
      return OrderItemNotifier();
    });

// ── Streams ──────────────────────────────────────────────────────────────────

final ordersStreamProvider = StreamProvider<List<OrderEntity>>((ref) {
  final repository = ref.watch(orderRepositoryProvider);
  return repository.getOrdersStream();
});

final allItemsStreamProvider = StreamProvider<List<OrderItemEntity>>((ref) {
  final repository = ref.watch(orderItemRepositoryProvider);
  return repository.getAllItemsStream();
});

final allAdditionalRevenueStreamProvider =
    StreamProvider<List<ExpenseEntity>>((ref) {
      final repository = ref.watch(orderRepositoryProvider);
      return repository.getAllAdditionalRevenueStream();
    });

final allExpensesStreamProvider = StreamProvider<List<ExpenseEntity>>((ref) {
  final repository = ref.watch(orderRepositoryProvider);
  return repository.getAllExpensesStream();
});
