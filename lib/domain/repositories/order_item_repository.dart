import '../entities/order_item_entity.dart';

abstract class OrderItemRepository {
  Future<void> addItem(OrderItemEntity item);
  Future<void> updateItem(OrderItemEntity item);
  Future<void> deleteItem(String itemId);
  Future<List<OrderItemEntity>> getItemsByOrderId(String orderId);
  Future<List<OrderItemEntity>> getAllItems();
  Stream<List<OrderItemEntity>> getAllItemsStream();
}
