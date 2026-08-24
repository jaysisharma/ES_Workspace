import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/domain/entities/auth_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/core/services/push_notification_service.dart';
import 'auth_provider.dart';

class AuthState {
  final bool isLoading;
  final AuthEntity? user;
  final String? errorMessage;

  const AuthState({this.isLoading = false, this.user, this.errorMessage});

  AuthState copyWith({
    bool? isLoading,
    AuthEntity? user,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // We set isLoading to true by default since we immediately check the session.
    // Use micromanagement to avoid 'Tried to read the state of an uninitialized provider'
    Future.microtask(() => _checkSession());
    return const AuthState(isLoading: true);
  }

  Future<void> _checkSession() async {
    debugPrint('🔄 [AuthNotifier] Checking existing user session...');
    try {
      final getCurrentUserUseCase = ref.read(getCurrentUserUseCaseProvider);
      final user = await getCurrentUserUseCase();
      debugPrint('🔄 [AuthNotifier] Session check result: ${user != null ? "Logged in as ${user.email} (${user.role})" : "No active session"}');
      state = state.copyWith(isLoading: false, user: user);
      if (user != null) {
        await Future.wait([
          PushNotificationService.subscribeToTopics(
            userId: user.uid,
            role: user.role.name,
          ),
          PushNotificationService.startListening(
            userId: user.uid,
            role: user.role.name,
          ),
        ]);
      }
    } catch (e) {
      debugPrint('⚠️ [AuthNotifier] Session check error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> login(String email, String password) async {
    debugPrint('🚀 [AuthNotifier] Initiating login for: $email');
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final loginUseCase = ref.read(loginUseCaseProvider);
      final user = await loginUseCase(email, password);
      debugPrint('✅ [AuthNotifier] Login successful! User UID: ${user?.uid}, Role: ${user?.role}');
      state = state.copyWith(isLoading: false, user: user);
      if (user != null) {
        await Future.wait([
          // Subscribe to FCM topics (for terminated-state notifications)
          PushNotificationService.subscribeToTopics(
            userId: user.uid,
            role: user.role.name,
          ),
          // Start Firestore listener (for foreground/background notifications)
          PushNotificationService.startListening(
            userId: user.uid,
            role: user.role.name,
          ),
        ]);
      }
    } catch (e, stack) {
      debugPrint('❌ [AuthNotifier] Login failed with error: $e');
      debugPrint('❌ [AuthNotifier] StackTrace: $stack');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> register(String email, String password, UserRole role) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final registerUseCase = ref.read(registerUseCaseProvider);
      final user = await registerUseCase(email, password, role);
      // Automatically log them in by setting user state
      state = state.copyWith(isLoading: false, user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    final currentUser = state.user;

    // 1. Safely stop notification listeners & unsubscribe topics in background without blocking
    try {
      await PushNotificationService.stopListening()
          .catchError((e) => debugPrint('Error stopping push listeners: $e'));
      if (currentUser != null) {
        await PushNotificationService.unsubscribeFromTopics(
          userId: currentUser.uid,
          role: currentUser.role.name,
        ).timeout(
          const Duration(seconds: 1),
          onTimeout: () => debugPrint('Push topic unsubscription timed out'),
        ).catchError((e) => debugPrint('Error unsubscribing push topics: $e'));
      }
    } catch (e) {
      debugPrint('Push notification cleanup error on logout: $e');
    }

    // 2. Clear Firebase Auth session and persistent local storage
    try {
      await ref.read(logoutUseCaseProvider)();
    } catch (e) {
      debugPrint('Logout usecase error: $e');
    } finally {
      // 3. ALWAYS unconditionally reset AuthState to empty unauthenticated state
      state = const AuthState();
    }
  }

  Future<void> changePassword(String newPassword) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.updatePassword(newPassword);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final currentUser = state.user;
      if (currentUser != null) {
        await Future.wait([
          PushNotificationService.stopListening(),
          PushNotificationService.unsubscribeFromTopics(
            userId: currentUser.uid,
            role: currentUser.role.name,
          ),
        ]);
      }
      final repository = ref.read(authRepositoryProvider);
      await repository.deleteAccount();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  void setLocalError(String message) {
    state = state.copyWith(errorMessage: message);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
