import '../repositories/order_item_repository.dart';

class DeleteOrderItemUseCase {
  final OrderItemRepository _repository;
  DeleteOrderItemUseCase(this._repository);

  Future<void> call(String itemId) => _repository.deleteItem(itemId);
}
