import '../entities/user_entity.dart';
import '../repositories/user_repository.dart';

class AddUserUseCase {
  final UserRepository _repository;

  AddUserUseCase(this._repository);

  Future<void> call(UserEntity user) {
    return _repository.addUser(user);
  }
}
