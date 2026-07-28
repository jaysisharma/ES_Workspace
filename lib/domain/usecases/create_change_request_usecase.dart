import '../entities/change_request_entity.dart';
import '../repositories/change_request_repository.dart';

class CreateChangeRequestUseCase {
  final ChangeRequestRepository repository;

  CreateChangeRequestUseCase(this.repository);

  Future<void> call(ChangeRequestEntity request) async {
    return await repository.createRequest(request);
  }
}
