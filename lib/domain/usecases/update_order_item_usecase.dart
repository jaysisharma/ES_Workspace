import '../entities/order_item_entity.dart';
import '../repositories/order_item_repository.dart';

class UpdateOrderItemUseCase {
  final OrderItemRepository repository;

  UpdateOrderItemUseCase(this.repository);

  Future<void> call(OrderItemEntity item) async {
    return await repository.updateItem(item);
  }
}
