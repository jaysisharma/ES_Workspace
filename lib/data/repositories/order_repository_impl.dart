import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/domain/entities/expense_entity.dart';
import 'package:order_app/domain/repositories/order_repository.dart';
import '../datasources/remote/firestore_order_remote_datasource.dart';
import 'package:order_app/core/errors/failures.dart';

class OrderRepositoryImpl implements OrderRepository {
  final OrderRemoteDataSource _remoteDataSource;

  OrderRepositoryImpl({required OrderRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  @override
  Future<void> createOrder(OrderEntity order) async {
    try {
      await _remoteDataSource.createOrder(order);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to create order: ${e.toString()}');
    }
  }

  @override
  Future<void> updateOrder(OrderEntity order) async {
    try {
      await _remoteDataSource.updateOrder(order);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to update order: ${e.toString()}');
    }
  }

  @override
  Future<OrderEntity?> getOrderById(String id) async {
    try {
      return await _remoteDataSource.getOrderById(id);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to get order: ${e.toString()}');
    }
  }

  @override
  Future<List<OrderEntity>> getAllOrders() async {
    try {
      return await _remoteDataSource.getAllOrders();
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to get all orders: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>> getOrdersPaginated(int limit, {dynamic lastDoc}) async {
    try {
      return await _remoteDataSource.getOrdersPaginated(limit, lastDoc: lastDoc);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to get paginated orders: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteOrder(String id) async {
    try {
      await _remoteDataSource.deleteOrder(id);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to delete order: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteOrders(List<String> ids) async {
    try {
      await _remoteDataSource.deleteOrders(ids);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to delete orders: ${e.toString()}');
    }
  }

  @override
  Future<void> finalizeRevenue(
    OrderEntity order,
    List<OrderItemEntity> items,
    List<ExpenseEntity> additionalRevenue,
  ) async {
    try {
      await _remoteDataSource.finalizeRevenue(order, items, additionalRevenue);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to finalize revenue: ${e.toString()}');
    }
  }

  @override
  Future<void> finalizeExpenses(
    OrderEntity order,
    List<ExpenseEntity> expenses,
    List<OrderItemEntity> items,
  ) async {
    try {
      await _remoteDataSource.finalizeExpenses(order, expenses, items);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to finalize expenses: ${e.toString()}');
    }
  }

  @override
  Future<List<ExpenseEntity>> getExpenses(String orderId) async {
    try {
      return await _remoteDataSource.getExpenses(orderId);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to get expenses: ${e.toString()}');
    }
  }

  @override
  Future<List<ExpenseEntity>> getAdditionalRevenue(String orderId) async {
    try {
      return await _remoteDataSource.getAdditionalRevenue(orderId);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to get additional revenue: ${e.toString()}');
    }
  }

  @override
  Stream<List<OrderEntity>> getOrdersStream() {
    return _remoteDataSource.getOrdersStream();
  }

  @override
  Stream<List<ExpenseEntity>> getAllAdditionalRevenueStream() {
    return _remoteDataSource.getAllAdditionalRevenueStream();
  }

  @override
  Stream<List<ExpenseEntity>> getAllExpensesStream() {
    return _remoteDataSource.getAllExpensesStream();
  }
}
