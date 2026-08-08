import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/data/repositories/firebase_auth_repository.dart';
import 'package:order_app/domain/repositories/auth_repository.dart';
import 'package:order_app/domain/usecases/login_usecase.dart';
import 'package:order_app/domain/usecases/register_usecase.dart';
import 'package:order_app/domain/usecases/get_current_user_usecase.dart';
import 'package:order_app/domain/usecases/logout_usecase.dart';
import 'auth_notifier.dart';

// Provides the repository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

// Provides the login usecase
final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return LoginUseCase(repository);
});

// Provides the register usecase
final registerUseCaseProvider = Provider<RegisterUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return RegisterUseCase(repository);
});

// Provides the get current user usecase
final getCurrentUserUseCaseProvider = Provider<GetCurrentUserUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return GetCurrentUserUseCase(repository);
});

// Provides the logout usecase
final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return LogoutUseCase(repository);
});

// Provides the AuthNotifier state using modern syntax
final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
