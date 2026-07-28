import '../entities/order_entity.dart';
import '../repositories/order_repository.dart';

class CreateOrderUseCase {
  final OrderRepository repository;

  CreateOrderUseCase(this.repository);

  Future<void> call(OrderEntity order) async {
    return await repository.createOrder(order);
  }
}
