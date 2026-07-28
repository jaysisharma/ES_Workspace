import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user_entity.dart';
import '../providers/auth_provider.dart';
import '../screens/shells/admin_shell.dart';
import '../screens/shells/founder_shell.dart';
import '../screens/auth/login_screen.dart';
import '../screens/shells/staff_shell.dart';

class RoleBasedRouter extends ConsumerWidget {
  const RoleBasedRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    // If user is null, show login screen (even while loading)
    if (authState.user == null) {
      return const LoginScreen();
    }

    // Direct to respective dashboard based on role
    switch (authState.user!.role) {
      case UserRole.admin:
        return const AdminShell();
      case UserRole.staff:
        return const StaffShell();
      case UserRole.founder:
        return const FounderShell();
    }
  }
}
