import '../entities/expense_entity.dart';
import '../entities/order_entity.dart';
import '../entities/order_item_entity.dart';
import '../repositories/order_repository.dart';

class FinalizeExpensesUseCase {
  final OrderRepository _repository;

  FinalizeExpensesUseCase(this._repository);

  Future<void> call(
    OrderEntity order,
    List<ExpenseEntity> expenses,
    List<OrderItemEntity> items,
  ) async {
    return _repository.finalizeExpenses(order, expenses, items);
  }
}
