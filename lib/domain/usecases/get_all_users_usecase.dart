import '../entities/user_entity.dart';
import '../repositories/user_repository.dart';

class GetAllUsersUseCase {
  final UserRepository _repository;

  GetAllUsersUseCase(this._repository);

  Future<List<UserEntity>> call() {
    return _repository.getAllUsers();
  }
}
