import '../entities/order_entity.dart';
import '../repositories/order_repository.dart';

class UpdateOrderUseCase {
  final OrderRepository repository;

  UpdateOrderUseCase(this.repository);

  Future<void> call(OrderEntity order) async {
    return await repository.updateOrder(order);
  }
}
