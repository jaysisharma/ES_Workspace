import '../entities/user_entity.dart';

abstract class UserRepository {
  Future<UserEntity?> getCurrentUser();
  Future<void> addUser(UserEntity user);
  Future<List<UserEntity>> getAllUsers();
  Future<void> updateUser(UserEntity user);
  Future<void> deleteUser(String userId);
}
