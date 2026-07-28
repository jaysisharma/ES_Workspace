import '../entities/auth_entity.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _authRepository;

  LoginUseCase(this._authRepository);

  Future<AuthEntity?> call(String email, String password) async {
    return await _authRepository.login(email, password);
  }
}
