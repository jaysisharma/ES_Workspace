import 'package:flutter/material.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/screens/auth/change_password_screen.dart';
import 'package:order_app/presentation/screens/common/utility/profile_screen.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';
import 'package:order_app/presentation/widgets/common/role_based_router.dart';

import 'settings/team_management_screen.dart';
import 'settings/company_policies_screen.dart';
import 'settings/export_storage_settings_screen.dart';
import 'settings/app_preferences_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isAdminOrFounder =
        user?.role == UserRole.admin || user?.role == UserRole.founder;

    // Design Tokens
    final bgColor = isDarkMode ? const Color(0xFF0b1319) : const Color(0xFFf8fafc);
    final cardColor = isDarkMode ? const Color(0xFF141f28) : Colors.white;
    final borderColor = isDarkMode ? const Color(0xFF1e2d3d) : const Color(0xFFe2e8f0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0f172a);
    final labelColor = isDarkMode ? const Color(0xFF94a3b8) : const Color(0xFF64748b);
    final dividerColor = isDarkMode
        ? const Color(0xFF1e2d3d).withValues(alpha: 0.6)
        : const Color(0xFFe2e8f0);

    final email = user?.email ?? '';
    final name = email.contains('@') ? email.split('@').first : 'User';
    final roleName = user?.role.name.toUpperCase() ?? 'STAFF';

    Color roleColor;
    switch (user?.role) {
      case UserRole.founder:
        roleColor = const Color(0xFF0075db);
        break;
      case UserRole.admin:
        roleColor = const Color(0xFFa855f7);
        break;
      case UserRole.finance:
        roleColor = const Color(0xFFf59e0b);
        break;
      default:
        roleColor = const Color(0xFF10b981);
        break;
    }

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
                if (Navigator.canPop(context)) ...[
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: textColor),
                    tooltip: 'Back',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    fontFamily: 'Manrope',
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Profile Summary Card ──────────────────────────────
            InkWell(
              onTap: () => Navigator.push(
                context,
                SlidePageRoute(page: const ProfileScreen()),
              ),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: roleColor.withValues(alpha: 0.12),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: roleColor,
                            ),
                          ),
                        ),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10b981),
                            shape: BoxShape.circle,
                            border: Border.all(color: cardColor, width: 2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: roleColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: roleColor.withValues(alpha: 0.25)),
                                ),
                                child: Text(
                                  roleName,
                                  style: TextStyle(
                                    color: roleColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: TextStyle(fontSize: 12, color: labelColor),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: labelColor.withValues(alpha: 0.6), size: 22),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Administration & Management Sub-pages ────────────────
            _buildSectionLabel('ADMINISTRATION & POLICIES', labelColor),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  if (isAdminOrFounder) ...[
                    _buildNavTile(
                      icon: Icons.people_alt_rounded,
                      iconColor: const Color(0xFF0075db),
                      title: 'Team & Access Control',
                      subtitle: 'Employee accounts, credentials, roles & permissions',
                      onTap: () => Navigator.push(
                        context,
                        SlidePageRoute(page: const TeamManagementScreen()),
                      ),
                      textColor: textColor,
                      labelColor: labelColor,
                      dividerColor: dividerColor,
                      isLast: false,
                    ),
                    _buildNavTile(
                      icon: Icons.business_rounded,
                      iconColor: const Color(0xFF6366f1),
                      title: 'Company & Operational Policies',
                      subtitle: 'Geofencing, leave resets, order categories & Synology NAS',
                      onTap: () => Navigator.push(
                        context,
                        SlidePageRoute(page: const CompanyPoliciesScreen()),
                      ),
                      textColor: textColor,
                      labelColor: labelColor,
                      dividerColor: dividerColor,
                      isLast: false,
                    ),
                  ],
                  _buildNavTile(
                    icon: Icons.folder_special_rounded,
                    iconColor: const Color(0xFF0284c7),
                    title: 'Exports, Data & Storage',
                    subtitle: 'Export folder destinations, auto-arrange & Excel statements',
                    onTap: () => Navigator.push(
                      context,
                      SlidePageRoute(page: const ExportStorageSettingsScreen()),
                    ),
                    textColor: textColor,
                    labelColor: labelColor,
                    dividerColor: dividerColor,
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Application & Display Preferences ────────────────────
            _buildSectionLabel('PREFERENCES & SYSTEM', labelColor),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  _buildNavTile(
                    icon: Icons.tune_rounded,
                    iconColor: const Color(0xFFf59e0b),
                    title: 'App & Display Preferences',
                    subtitle: 'Theme, currency, notifications & dashboard event strip',
                    onTap: () => Navigator.push(
                      context,
                      SlidePageRoute(page: const AppPreferencesScreen()),
                    ),
                    textColor: textColor,
                    labelColor: labelColor,
                    dividerColor: dividerColor,
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Account & Security ───────────────────────────────────
            _buildSectionLabel('ACCOUNT & SECURITY', labelColor),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  if (user?.role != UserRole.staff) ...[
                    _buildNavTile(
                      icon: Icons.lock_reset_rounded,
                      iconColor: const Color(0xFF64748b),
                      title: 'Change Password',
                      subtitle: 'Update your account login password',
                      onTap: () => Navigator.push(
                        context,
                        SlidePageRoute(page: const ChangePasswordScreen()),
                      ),
                      textColor: textColor,
                      labelColor: labelColor,
                      dividerColor: dividerColor,
                      isLast: false,
                    ),
                  ],
                  _buildNavTile(
                    icon: Icons.logout_rounded,
                    iconColor: const Color(0xFFf43f5e),
                    title: 'Log Out',
                    subtitle: 'End active session on this device',
                    onTap: () => _showLogoutConfirmation(context, ref),
                    textColor: const Color(0xFFf43f5e),
                    labelColor: labelColor,
                    dividerColor: dividerColor,
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
            Center(
              child: Column(
                children: [
                  Text(
                    'ES WORKSPACE',
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                      fontFamily: 'Manrope',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'App Version v1.1.0 • Enterprise Cloud Edition',
                    style: TextStyle(
                      color: labelColor.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: labelColor,
          letterSpacing: 1.2,
          fontFamily: 'Manrope',
        ),
      ),
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color textColor,
    required Color labelColor,
    required Color dividerColor,
    required bool isLast,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(16))
          : BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: labelColor, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: labelColor.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFf43f5e)),
            SizedBox(width: 8),
            Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Are you sure you want to log out of your session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const RoleBasedRouter()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFf43f5e),
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
