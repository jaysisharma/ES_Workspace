import '../entities/order_item_entity.dart';
import '../repositories/order_item_repository.dart';

class AddOrderItemUseCase {
  final OrderItemRepository repository;

  AddOrderItemUseCase(this.repository);

  Future<void> call(OrderItemEntity item) async {
    return await repository.addItem(item);
  }
}
