import '../entities/auth_entity.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository repository;

  RegisterUseCase(this.repository);

  Future<AuthEntity?> call(String email, String password, UserRole role) {
    return repository.register(email, password, role);
  }
}
