import '../entities/change_request_entity.dart';
import '../repositories/change_request_repository.dart';

class GetChangeRequestsByOrderUseCase {
  final ChangeRequestRepository repository;

  GetChangeRequestsByOrderUseCase(this.repository);

  Future<List<ChangeRequestEntity>> call(String orderId) async {
    return await repository.getRequestsByOrder(orderId);
  }
}
