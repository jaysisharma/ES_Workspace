import '../entities/auth_entity.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<AuthEntity?> login(String email, String password);
  Future<AuthEntity?> register(String email, String password, UserRole role);
  Future<void> logout();
  Future<void> updatePassword(String newPassword);
  Future<AuthEntity?> getCurrentUser();
}
