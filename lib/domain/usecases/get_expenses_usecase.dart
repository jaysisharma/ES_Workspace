import '../entities/expense_entity.dart';
import '../repositories/order_repository.dart';

class GetExpensesUseCase {
  final OrderRepository _repository;

  GetExpensesUseCase(this._repository);

  Future<List<ExpenseEntity>> call(String orderId) async {
    return _repository.getExpenses(orderId);
  }
}
