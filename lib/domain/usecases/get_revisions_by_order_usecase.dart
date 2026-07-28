import '../entities/revision_entity.dart';
import '../repositories/revision_repository.dart';

class GetRevisionsByOrderUseCase {
  final RevisionRepository _repository;

  GetRevisionsByOrderUseCase(this._repository);

  Future<List<RevisionEntity>> call(String orderId) {
    return _repository.getRevisionsByOrderId(orderId);
  }
}
