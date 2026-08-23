import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/user_providers.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/screens/admin/add_user_screen.dart';
import 'package:order_app/core/services/admin_auth_service.dart';
import 'package:order_app/presentation/providers/employee_profile_providers.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';

class TeamManagementScreen extends ConsumerStatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  ConsumerState<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends ConsumerState<TeamManagementScreen> {
  String _searchQuery = '';
  String _selectedRoleFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final userState = ref.watch(userNotifierProvider);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0075db);
    final bgColor = isDarkMode ? const Color(0xFF0b1319) : const Color(0xFFf8fafc);
    final cardColor = isDarkMode ? const Color(0xFF141f28) : Colors.white;
    final borderColor = isDarkMode ? const Color(0xFF1e2d3d) : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final labelColor = isDarkMode ? const Color(0xFF94a3b8) : const Color(0xFF64748b);
    final dividerColor = isDarkMode
        ? const Color(0xFF1e2d3d).withValues(alpha: 0.6)
        : const Color(0xFFe2e8f0);

    final filteredUsers = userState.users.where((u) {
      final matchesSearch = _searchQuery.isEmpty ||
          u.name.toLowerCase().contains(_searchQuery) ||
          u.email.toLowerCase().contains(_searchQuery);
      final matchesRole = _selectedRoleFilter == 'ALL' ||
          u.role.name.toUpperCase() == _selectedRoleFilter;
      return matchesSearch && matchesRole;
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: const BottomRightBackButton(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: textColor),
                  tooltip: 'Back',
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                Text(
                  'Team & Access Control',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    fontFamily: 'Manrope',
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    SlidePageRoute(page: const AddUserScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: const Text('Add User', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            // Search and Role Filters Card
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    style: TextStyle(fontSize: 13, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Search members by name or email...',
                      hintStyle: TextStyle(fontSize: 13, color: labelColor),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: labelColor),
                      filled: true,
                      fillColor: isDarkMode ? const Color(0xFF0b1319) : const Color(0xFFf1f5f9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: primaryColor, width: 1.5),
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['ALL', 'FOUNDER', 'ADMIN', 'FINANCE', 'STAFF'].map((role) {
                        final isSelected = _selectedRoleFilter == role;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: Text(
                              role == 'ALL' ? 'All Roles (${userState.users.length})' : role,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : labelColor,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: primaryColor,
                            backgroundColor: isDarkMode ? const Color(0xFF0b1319) : const Color(0xFFf1f5f9),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(
                                color: isSelected ? primaryColor : borderColor,
                              ),
                            ),
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedRoleFilter = role);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // User List Card
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: userState.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : userState.errorMessage != null
                      ? Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Center(
                            child: Text(
                              userState.errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        )
                      : filteredUsers.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(36.0),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.person_off_outlined, size: 36, color: labelColor.withValues(alpha: 0.5)),
                                    const SizedBox(height: 8),
                                    Text('No team members found', style: TextStyle(color: labelColor, fontSize: 13)),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              children: filteredUsers.map((user) {
                                return _buildUserRow(
                                  context: context,
                                  ref: ref,
                                  user: user,
                                  currentUser: authState.user != null
                                      ? UserEntity(
                                          id: authState.user!.uid,
                                          name: authState.user!.email,
                                          email: authState.user!.email,
                                          role: authState.user!.role,
                                        )
                                      : null,
                                  isLast: filteredUsers.last == user,
                                  primaryColor: primaryColor,
                                  textColor: textColor,
                                  labelColor: labelColor,
                                  dividerColor: dividerColor,
                                  onToggleActive: (val) {
                                    ref.read(userNotifierProvider.notifier).toggleUserActive(user);
                                  },
                                );
                              }).toList(),
                            ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildUserRow({
    required BuildContext context,
    required WidgetRef ref,
    required UserEntity user,
    required UserEntity? currentUser,
    required bool isLast,
    required Color primaryColor,
    required Color textColor,
    required Color labelColor,
    required Color dividerColor,
    required ValueChanged<bool> onToggleActive,
  }) {
    final name = user.name;
    final email = user.email;
    final role = user.role.name.toUpperCase();
    final isActive = user.isActive;

    final isSelf = currentUser?.id == user.id;
    final isFounder = user.role == UserRole.founder;
    final canManage = !isSelf && !isFounder;

    Color roleColor;
    switch (user.role) {
      case UserRole.founder:
        roleColor = const Color(0xFF0075db);
        break;
      case UserRole.admin:
        roleColor = const Color(0xFFa855f7);
        break;
      case UserRole.finance:
        roleColor = const Color(0xFFf59e0b);
        break;
      case UserRole.staff:
        roleColor = const Color(0xFF10b981);
        break;
    }

    return Opacity(
      opacity: isActive ? 1.0 : 0.6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: roleColor.withValues(alpha: 0.12),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: TextStyle(
                      color: roleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF10b981) : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: roleColor.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          role,
                          style: TextStyle(
                            color: roleColor,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    email,
                    style: TextStyle(color: labelColor, fontSize: 11),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canManage)
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: primaryColor, size: 18),
                    tooltip: 'Edit Credentials & Role',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _onEditUserCredentials(
                      context: context,
                      ref: ref,
                      user: user,
                    ),
                  ),
                if (canManage)
                  IconButton(
                    icon: Icon(
                      Icons.lock_reset_rounded,
                      color: labelColor.withValues(alpha: 0.8),
                      size: 18,
                    ),
                    tooltip: 'Send Password Reset Email',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _onResetPassword(
                      context: context,
                      ref: ref,
                      user: user,
                      canManage: canManage,
                      isSelf: isSelf,
                      isFounder: isFounder,
                      labelColor: labelColor,
                    ),
                  ),
                if (canManage)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFf43f5e),
                      size: 18,
                    ),
                    tooltip: 'Delete User Account',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _onDeleteUser(
                      context: context,
                      ref: ref,
                      user: user,
                      canManage: canManage,
                      isSelf: isSelf,
                      isFounder: isFounder,
                      textColor: textColor,
                      labelColor: labelColor,
                      dividerColor: dividerColor,
                    ),
                  ),
                const SizedBox(width: 4),
                _buildSwitch(
                  context,
                  isActive,
                  onToggleActive,
                  primaryColor,
                  small: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onEditUserCredentials({
    required BuildContext context,
    required WidgetRef ref,
    required UserEntity user,
  }) async {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    final passwordController = TextEditingController();
    UserRole selectedRole = user.role;
    bool isSaving = false;
    bool obscurePassword = true;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.manage_accounts_outlined, color: Color(0xFF0075db)),
              SizedBox(width: 8),
              Text('Edit User Credentials', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Update the login email, password, display name, and system role for this account.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Login Email Address',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'New Password (Optional / Min 6 chars)',
                    hintText: 'Leave blank to keep current password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                      ),
                      onPressed: () => setDialogState(
                        () => obscurePassword = !obscurePassword,
                      ),
                    ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'System Access Role',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    isDense: true,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UserRole>(
                      value: selectedRole,
                      isExpanded: true,
                      items: UserRole.values.map((role) {
                        return DropdownMenuItem<UserRole>(
                          value: role,
                          child: Row(
                            children: [
                              Icon(
                                role == UserRole.admin
                                    ? Icons.admin_panel_settings
                                    : role == UserRole.founder
                                        ? Icons.stars
                                        : role == UserRole.finance
                                            ? Icons.account_balance
                                            : Icons.badge_outlined,
                                size: 18,
                                color: role == UserRole.admin
                                    ? Colors.purple
                                    : role == UserRole.founder
                                        ? Colors.blue
                                        : role == UserRole.finance
                                            ? Colors.orange
                                            : Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Text(role.displayName),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (newRole) {
                        if (newRole != null) {
                          setDialogState(() => selectedRole = newRole);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0075db),
                foregroundColor: Colors.white,
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      final newName = nameController.text.trim();
                      final newEmail = emailController.text.trim();
                      final newPassword = passwordController.text.trim();

                      if (newEmail.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Email cannot be empty.')),
                        );
                        return;
                      }

                      if (newPassword.isNotEmpty && newPassword.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password must be at least 6 characters.')),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        await AdminAuthService.updateEmployeeCredentials(
                          userId: user.id,
                          oldEmail: user.email,
                          newEmail: newEmail,
                          newPassword: newPassword.isNotEmpty ? newPassword : null,
                          role: selectedRole,
                          name: newName,
                        );

                        await ref.read(userNotifierProvider.notifier).refresh();
                        ref.invalidate(employeeProfilesStreamProvider);

                        if (context.mounted) {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('User credentials and role updated successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error updating account: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _onResetPassword({
    required BuildContext context,
    required WidgetRef ref,
    required UserEntity user,
    required bool canManage,
    required bool isSelf,
    required bool isFounder,
    required Color labelColor,
  }) {
    if (isSelf) {
      _showSnackBar(
        context,
        'Use "Change Password" in Account section to update your own password.',
        isError: false,
      );
      return;
    }
    if (isFounder) {
      _showSnackBar(
        context,
        'Cannot reset password for a Founder account.',
        isError: true,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Password Reset'),
        content: Text(
          'A password reset email will be sent to ${user.email}.\n\n'
          'The user can use it to set a new password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(userNotifierProvider.notifier)
                    .sendPasswordResetForUser(user.email);
                if (context.mounted) {
                  _showSnackBar(
                    context,
                    'Password reset email sent to ${user.email}.',
                    isError: false,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  _showSnackBar(
                    context,
                    'Failed to send reset email: ${e.toString()}',
                    isError: true,
                  );
                }
              }
            },
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }

  void _onDeleteUser({
    required BuildContext context,
    required WidgetRef ref,
    required UserEntity user,
    required bool canManage,
    required bool isSelf,
    required bool isFounder,
    required Color textColor,
    required Color labelColor,
    required Color dividerColor,
  }) {
    if (isSelf) {
      _showSnackBar(
        context,
        'You cannot delete your own account.',
        isError: true,
      );
      return;
    }
    if (isFounder) {
      _showSnackBar(
        context,
        'Founder accounts cannot be deleted.',
        isError: true,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete "${user.name}"?\n\n'
          'This will remove their profile and deactivate their access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFf43f5e),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(userNotifierProvider.notifier)
                    .deleteUser(user.id);
                if (context.mounted) {
                  _showSnackBar(
                    context,
                    '${user.name} has been removed.',
                    isError: false,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  _showSnackBar(
                    context,
                    'Failed to delete user: ${e.toString()}',
                    isError: true,
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    required bool isError,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFf43f5e) : const Color(0xFF10b981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildSwitch(
    BuildContext context,
    bool value,
    ValueChanged<bool> onChanged,
    Color primaryColor, {
    bool small = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: small ? 32 : 44,
        height: small ? 18 : 24,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? primaryColor : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: small ? 12 : 18,
            height: small ? 12 : 18,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
            ),
          ),
        ),
      ),
    );
  }
}
