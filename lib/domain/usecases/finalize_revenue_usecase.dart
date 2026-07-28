import '../entities/expense_entity.dart';
import '../entities/order_entity.dart';
import '../entities/order_item_entity.dart';
import '../repositories/order_repository.dart';

class FinalizeRevenueUseCase {
  final OrderRepository _repository;

  FinalizeRevenueUseCase(this._repository);

  Future<void> call(
    OrderEntity order,
    List<OrderItemEntity> items,
    List<ExpenseEntity> additionalRevenue,
  ) async {
    return _repository.finalizeRevenue(order, items, additionalRevenue);
  }
}
