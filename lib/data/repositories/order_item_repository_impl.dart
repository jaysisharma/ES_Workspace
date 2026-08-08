import 'package:order_app/domain/entities/order_item_entity.dart';
import 'package:order_app/domain/repositories/order_item_repository.dart';
import '../datasources/remote/firestore_order_item_remote_datasource.dart';
import 'package:order_app/core/errors/failures.dart';

class OrderItemRepositoryImpl implements OrderItemRepository {
  final OrderItemRemoteDataSource _remoteDataSource;

  OrderItemRepositoryImpl({required OrderItemRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  @override
  Future<void> addItem(OrderItemEntity item) async {
    try {
      await _remoteDataSource.addItem(item);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to add order item: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteItem(String itemId) async {
    try {
      await _remoteDataSource.deleteItem(itemId);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to delete order item: ${e.toString()}');
    }
  }

  @override
  Future<void> updateItem(OrderItemEntity item) async {
    try {
      await _remoteDataSource.updateItem(item);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to update order item: ${e.toString()}');
    }
  }

  @override
  Future<List<OrderItemEntity>> getItemsByOrderId(String orderId) async {
    try {
      return await _remoteDataSource.getItemsByOrderId(orderId);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to fetch order items: ${e.toString()}');
    }
  }

  @override
  Future<List<OrderItemEntity>> getAllItems() async {
    try {
      return await _remoteDataSource.getAllItems();
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to fetch all order items: ${e.toString()}');
    }
  }

  @override
  Stream<List<OrderItemEntity>> getAllItemsStream() {
    return _remoteDataSource.getAllItemsStream();
  }
}
