import '../entities/order_entity.dart';
import '../repositories/order_repository.dart';

class GetOrdersUseCase {
  final OrderRepository repository;

  GetOrdersUseCase(this.repository);

  Future<List<OrderEntity>> call() async {
    return await repository.getAllOrders();
  }
}
