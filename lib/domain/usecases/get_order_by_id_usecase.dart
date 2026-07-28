import '../entities/order_entity.dart';
import '../repositories/order_repository.dart';

class GetOrderByIdUseCase {
  final OrderRepository _repository;

  GetOrderByIdUseCase(this._repository);

  Future<OrderEntity?> call(String id) async {
    return _repository.getOrderById(id);
  }
}
