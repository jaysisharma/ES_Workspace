import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'user_providers.dart';

class UserState {
  final List<UserEntity> users;
  final bool isLoading;
  final String? errorMessage;

  UserState({this.users = const [], this.isLoading = false, this.errorMessage});

  UserState copyWith({
    List<UserEntity>? users,
    bool? isLoading,
    String? errorMessage,
  }) {
    return UserState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class UserNotifier extends Notifier<UserState> {
  @override
  UserState build() {
    Future.microtask(_loadUsers);
    return UserState();
  }

  Future<void> _loadUsers() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final getAllUsersUseCase = ref.read(getAllUsersUseCaseProvider);
      final users = await getAllUsersUseCase();
      state = state.copyWith(isLoading: false, users: users);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> addUser(UserEntity user) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final addUserUseCase = ref.read(addUserUseCaseProvider);
      await addUserUseCase(user);
      await _loadUsers();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> toggleUserActive(UserEntity user) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final updatedUser = user.copyWith(isActive: !user.isActive);
      final updateUserUseCase = ref.read(updateUserUseCaseProvider);
      await updateUserUseCase(updatedUser);
      await _loadUsers();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> deleteUser(String userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = ref.read(userRepositoryProvider);
      await repo.deleteUser(userId);
      await _loadUsers();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Sends a Firebase password-reset email for the given user's address.
  Future<void> sendPasswordResetForUser(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  Future<void> refresh() async {
    await _loadUsers();
  }
}
