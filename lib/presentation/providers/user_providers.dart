import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/user_repository.dart';
import '../../data/repositories/firestore_user_repository.dart';
import '../../domain/usecases/add_user_usecase.dart';
import '../../domain/usecases/get_all_users_usecase.dart';
import '../../domain/usecases/update_user_usecase.dart';
import 'user_notifier.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return FirestoreUserRepository();
});

final addUserUseCaseProvider = Provider<AddUserUseCase>((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return AddUserUseCase(repository);
});

final getAllUsersUseCaseProvider = Provider<GetAllUsersUseCase>((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return GetAllUsersUseCase(repository);
});

final updateUserUseCaseProvider = Provider<UpdateUserUseCase>((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return UpdateUserUseCase(repository);
});

final userNotifierProvider = NotifierProvider<UserNotifier, UserState>(() {
  return UserNotifier();
});
