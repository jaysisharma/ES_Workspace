import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/screens/shells/admin_shell.dart';
import 'package:order_app/presentation/screens/shells/founder_shell.dart';
import 'package:order_app/presentation/screens/auth/login_screen.dart';
import 'package:order_app/presentation/screens/shells/staff_shell.dart';

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
