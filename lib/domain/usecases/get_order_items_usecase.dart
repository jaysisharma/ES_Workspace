import '../entities/order_item_entity.dart';
import '../repositories/order_item_repository.dart';

class GetOrderItemsUseCase {
  final OrderItemRepository repository;

  GetOrderItemsUseCase(this.repository);

  Future<List<OrderItemEntity>> call(String orderId) async {
    return await repository.getItemsByOrderId(orderId);
  }
}
