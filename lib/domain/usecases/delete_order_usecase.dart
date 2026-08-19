import '../repositories/order_repository.dart';

class DeleteOrderUseCase {
  final OrderRepository repository;

  DeleteOrderUseCase(this.repository);

  Future<void> call(String id) async {
    return await repository.deleteOrder(id);
  }

  Future<void> deleteMultiple(List<String> ids) async {
    return await repository.deleteOrders(ids);
  }
}
