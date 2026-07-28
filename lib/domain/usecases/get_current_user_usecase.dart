import '../entities/auth_entity.dart';
import '../repositories/auth_repository.dart';

class GetCurrentUserUseCase {
  final AuthRepository _repository;

  GetCurrentUserUseCase(this._repository);

  Future<AuthEntity?> call() {
    return _repository.getCurrentUser();
  }
}
