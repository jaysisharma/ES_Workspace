import '../entities/expense_entity.dart';
import '../repositories/order_repository.dart';

class GetAdditionalRevenueUseCase {
  final OrderRepository _repository;

  GetAdditionalRevenueUseCase(this._repository);

  Future<List<ExpenseEntity>> call(String orderId) async {
    return _repository.getAdditionalRevenue(orderId);
  }
}
