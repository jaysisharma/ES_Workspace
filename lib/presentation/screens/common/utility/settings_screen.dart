import 'package:flutter/material.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/settings_provider.dart';
import 'package:order_app/presentation/providers/user_providers.dart';
import 'package:order_app/presentation/providers/event_providers.dart';
import 'package:order_app/presentation/providers/dashboard_strip_notifier.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/screens/admin/add_user_screen.dart';
import 'package:order_app/presentation/screens/auth/change_password_screen.dart';
import 'package:order_app/presentation/screens/common/finance/financial_reports_screen.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/core/utils/excel_export_helper.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/screens/common/utility/profile_screen.dart';
import 'package:order_app/presentation/widgets/hr_management/manage_geofence_dialog.dart';
import 'package:order_app/presentation/widgets/dashboard/dashboard_event_selection_dialog.dart';
import 'package:order_app/presentation/screens/admin/synology_company_pdf_screen.dart';
import 'package:order_app/presentation/screens/common/inventory/inventory_management_screen.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:order_app/core/services/export_directory_service.dart';
import 'package:order_app/presentation/widgets/create_order/manage_categories_dialog.dart';
import 'package:order_app/presentation/widgets/hr_management/leave_cycle_settings_dialog.dart';
import 'package:order_app/presentation/widgets/common/role_based_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final settings = ref.watch(settingsProvider);
    final userState = ref.watch(userNotifierProvider);
    final stripState = ref.watch(dashboardStripNotifierProvider);

    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isAdminOrFounder =
        authState.user?.role == UserRole.admin ||
        authState.user?.role == UserRole.founder;

    // Design Tokens mapped to ColorScheme
    final primaryColor = colorScheme.primary;
    final bgColor = colorScheme.surface;
    final cardColor = colorScheme.surface;
    final borderColor = colorScheme.outline;
    final textColor = colorScheme.onSurface;
    final labelColor = colorScheme.onSurfaceVariant;
    final dividerColor = colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.3,
    );

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: const BottomRightBackButton(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: AppBar(
          backgroundColor: bgColor.withValues(alpha: 0.8),
          elevation: 0,
          scrolledUnderElevation: 0,
          leadingWidth: 56,
          title: Text(
            'Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
              fontFamily: 'Manrope',
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      SlidePageRoute(page: const ProfileScreen()),
                    ),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          authState.user?.email
                                  .split('@')
                                  .first[0]
                                  .toUpperCase() ??
                              'U',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: bgColor, width: 2),
                    ),
                  ),
                ],
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: borderColor, height: 1),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section: User Management
            if (isAdminOrFounder) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('User Management', labelColor),
                  _buildSmallButton('Add User', Icons.add, primaryColor, () {
                    Navigator.push(
                      context,
                      SlidePageRoute(page: const AddUserScreen()),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: _cardDecoration(cardColor, borderColor),
                child: Column(
                  children: [
                    if (userState.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (userState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          userState.errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else if (userState.users.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Text(
                            'No users found',
                            style: TextStyle(color: labelColor, fontSize: 12),
                          ),
                        ),
                      )
                    else
                      ...userState.users.map(
                        (user) => _buildUserRow(
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
                          isLast: userState.users.last == user,
                          primaryColor: primaryColor,
                          textColor: textColor,
                          labelColor: labelColor,
                          dividerColor: dividerColor,
                          onToggleActive: (val) {
                            ref
                                .read(userNotifierProvider.notifier)
                                .toggleUserActive(user);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Section: Data & Backup
            if (isAdminOrFounder) ...[
              _buildSectionTitle('Data & Backup', labelColor),
              const SizedBox(height: 12),
              Container(
                decoration: _cardDecoration(cardColor, borderColor),
                child: Column(
                  children: [
                    _buildActionRow(
                      title: 'Export All Orders',
                      subtitle: 'Generates a detailed Excel (.xlsx) file',
                      icon: Icons.table_chart_outlined,
                      iconColor: Colors.blue,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Export Data'),
                            content: const Text(
                              'Are you sure you want to export all order data to Excel?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(dialogContext);

                                  final orders = ref.read(orderNotifierProvider).orders;
                                  final headers = [
                                    'Order ID',
                                    'Event Name',
                                    'Venue',
                                    'Contact Person',
                                    'Contact Number',
                                    'Event Start',
                                    'Event End',
                                    'Setup Start',
                                    'Setup End',
                                    'Status',
                                    'Total Amount (NPR)',
                                    'Description',
                                  ];

                                  final rows = orders.map((o) => [
                                    o.id,
                                    o.eventName,
                                    o.venue,
                                    o.contactPerson,
                                    o.contactNumber,
                                    formatNepaliDate(o.eventDate, 'yyyy-MM-dd'),
                                    o.eventEndDate != null ? formatNepaliDate(o.eventEndDate!, 'yyyy-MM-dd') : '',
                                    formatNepaliDate(o.setupDate, 'yyyy-MM-dd'),
                                    o.setupEndDate != null ? formatNepaliDate(o.setupEndDate!, 'yyyy-MM-dd') : '',
                                    o.status.name,
                                    o.totalAmount,
                                    o.description,
                                  ]).toList();

                                  await ExcelExportHelper.exportAndShareExcel(
                                    context: context,
                                    headers: headers,
                                    rows: rows,
                                    filename: 'All_Orders_Export_${formatNepaliDate(DateTime.now(), "yyyyMMdd")}.xlsx',
                                    sheetName: 'All Orders',
                                    title: 'All Orders Statement Summary',
                                  );
                                },
                                child: const Text('Export'),
                              ),
                            ],
                          ),
                        );
                      },
                      trailing: Icon(
                        Icons.download,
                        color: labelColor.withValues(alpha: 0.5),
                        size: 18,
                      ),
                      isLast: false,
                      textColor: textColor,
                      labelColor: labelColor,
                      dividerColor: dividerColor,
                    ),
                    _buildActionRow(
                      title: 'Financial Reports',
                      subtitle: 'Professional PDF summary',
                      icon: Icons.picture_as_pdf,
                      iconColor: const Color(0xFF10b981),
                      onTap: () => Navigator.push(
                        context,
                        SlidePageRoute(page: const FinancialReportsScreen()),
                      ),
                      trailing: Icon(
                        Icons.download,
                        color: labelColor.withValues(alpha: 0.5),
                        size: 18,
                      ),
                      isLast: false,
                      textColor: textColor,
                      labelColor: labelColor,
                      dividerColor: dividerColor,
                    ),
                    _buildActionRow(
                      title: 'Office Geofence Zone',
                      subtitle: 'Configure GPS Coordinates & Radius',
                      icon: Icons.share_location_rounded,
                      iconColor: primaryColor,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => const ManageGeofenceDialog(),
                        );
                      },
                      trailing: Icon(
                        Icons.chevron_right,
                        color: labelColor.withValues(alpha: 0.5),
                        size: 18,
                      ),
                      isLast: false,
                      textColor: textColor,
                      labelColor: labelColor,
                      dividerColor: dividerColor,
                    ),
                    _buildActionRow(
                      title: 'Company PDF & Synology NAS',
                      subtitle: 'Upload, manage & share company PDF via Synology',
                      icon: Icons.cloud_upload_outlined,
                      iconColor: Colors.deepOrange,
                      onTap: () => Navigator.push(
                        context,
                        SlidePageRoute(page: const SynologyCompanyPdfScreen()),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: labelColor.withValues(alpha: 0.5),
                        size: 18,
                      ),
                      isLast: false,
                      textColor: textColor,
                      labelColor: labelColor,
                      dividerColor: dividerColor,
                    ),
                    _buildActionRow(
                      title: 'Inventory & Equipment',
                      subtitle: 'Track available stock, rates & categories',
                      icon: Icons.inventory_2_outlined,
                      iconColor: Colors.purple,
                      onTap: () => Navigator.push(
                        context,
                        SlidePageRoute(page: const InventoryManagementScreen()),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: labelColor.withValues(alpha: 0.5),
                        size: 18,
                      ),
                      isLast: false,
                      textColor: textColor,
                      labelColor: labelColor,
                      dividerColor: dividerColor,
                    ),
                    _buildActionRow(
                      title: 'Order Categories',
                      subtitle: 'Add, view & remove event categories',
                      icon: Icons.category_rounded,
                      iconColor: Colors.teal,
                      onTap: () => ManageCategoriesDialog.show(context),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: labelColor.withValues(alpha: 0.5),
                        size: 18,
                      ),
                      isLast: false,
                      textColor: textColor,
                      labelColor: labelColor,
                      dividerColor: dividerColor,
                    ),
                    _buildActionRow(
                      title: 'Leave Reset & Cycle Settings',
                      subtitle: 'Configure annual leave reset rules or manual cycle',
                      icon: Icons.event_repeat,
                      iconColor: const Color(0xFF0075db),
                      onTap: () => showLeaveCycleSettingsDialog(context, ref),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: labelColor.withValues(alpha: 0.5),
                        size: 18,
                      ),
                      isLast: false,
                      textColor: textColor,
                      labelColor: labelColor,
                      dividerColor: dividerColor,
                    ),
                    _buildActionRow(
                      title: 'Backup to Cloud',
                      subtitle: 'Sync with Firebase Storage',
                      icon: Icons.cloud_upload,
                      iconColor: Colors.amber,
                      onTap: () {},
                      trailing: const Text(
                        'SYNCING',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      isLast: true,
                      textColor: textColor,
                      labelColor: labelColor,
                      dividerColor: dividerColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Section: Export & Storage Destination
              _buildSectionTitle('Export & Storage Destination', labelColor),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(cardColor, borderColor),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.folder_special_rounded, color: Colors.blue, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Destination Export Folder',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                settings.exportDestinationDirectory != null
                                    ? settings.exportDestinationDirectory!
                                    : 'Default System Downloads Directory',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: settings.exportDestinationDirectory != null ? primaryColor : labelColor,
                                  fontWeight: settings.exportDestinationDirectory != null ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final selectedDir = await FilePicker.platform.getDirectoryPath(
                              dialogTitle: 'Select Destination Folder for Exports',
                            );
                            if (selectedDir != null && selectedDir.isNotEmpty) {
                              await ref.read(settingsProvider.notifier).setExportDestinationDirectory(selectedDir);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Export directory set to: $selectedDir'),
                                    backgroundColor: Colors.green.shade700,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.drive_folder_upload_rounded, size: 16),
                          label: const Text('Choose Folder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        if (settings.exportDestinationDirectory != null) ...[
                          OutlinedButton.icon(
                            onPressed: () async {
                              await ExportDirectoryService.openDirectory(settings.exportDestinationDirectory!);
                            },
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.folder_open_rounded, size: 16),
                            label: const Text('Open Folder', style: TextStyle(fontSize: 12)),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await ref.read(settingsProvider.notifier).setExportDestinationDirectory(null);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Reset export directory to system default.'),
                                  ),
                                );
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.restart_alt_rounded, size: 16),
                            label: const Text('Reset', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                    const Divider(height: 24),
                    _buildPreferenceRow(
                      title: 'Auto-Arrange in Subfolders',
                      subtitle: 'Organizes exports into Attendance/, Orders/, Finance/, Employees/ folders',
                      textColor: textColor,
                      labelColor: labelColor,
                      child: _buildSwitch(
                        context,
                        settings.autoArrangeExportFolders,
                        (val) {
                          ref.read(settingsProvider.notifier).toggleAutoArrangeExportFolders(val);
                        },
                        primaryColor,
                        isDarkMode,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
            // Section: App Preferences
            _buildSectionTitle('App Preferences', labelColor),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(cardColor, borderColor),
              child: Column(
                children: [
                  _buildPreferenceRow(
                    title: 'Currency',
                    subtitle: 'Active transaction currency',
                    textColor: textColor,
                    labelColor: labelColor,
                    child: _buildDropdown(
                      ['NPR (Rs.)', 'USD (\$)', 'EUR (€)'],
                      settings.currency,
                      isDarkMode,
                      primaryColor,
                      cardColor,
                      textColor,
                      labelColor,
                      (val) {
                        if (val != null) {
                          ref.read(settingsProvider.notifier).setCurrency(val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildPreferenceRow(
                    title: 'Enable Notifications',
                    subtitle: 'Order updates & system alerts',
                    textColor: textColor,
                    labelColor: labelColor,
                    child: _buildSwitch(
                      context,
                      settings.notificationsEnabled,
                      (val) {
                        ref
                            .read(settingsProvider.notifier)
                            .toggleNotifications(val);
                      },
                      primaryColor,
                      isDarkMode,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildPreferenceRow(
                    title: 'Dark Mode',
                    subtitle: 'Toggle theme',
                    textColor: textColor,
                    labelColor: labelColor,
                    child: _buildSwitch(
                      context,
                      isDarkMode,
                      (val) {
                        ref
                            .read(settingsProvider.notifier)
                            .setThemeMode(
                              val ? ThemeMode.dark : ThemeMode.light,
                            );
                      },
                      primaryColor,
                      isDarkMode,
                    ),
                  ),
                  if (isAdminOrFounder) ...[
                    const SizedBox(height: 20),
                    _buildPreferenceRow(
                      title: 'Dashboard Event Strip',
                      subtitle: 'Active mode: ${stripState.mode.label}',
                      textColor: textColor,
                      labelColor: labelColor,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final events =
                              ref.read(eventsStreamProvider).value ?? [];
                          DashboardEventSelectionDialog.show(context, events);
                        },
                        icon: Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: primaryColor,
                        ),

                        
                        label: Text(
                          'Configure',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: primaryColor.withValues(alpha: 0.4),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),
            // Section: Account
            _buildSectionTitle('Account', labelColor),
            const SizedBox(height: 12),
            Container(
              decoration: _cardDecoration(cardColor, borderColor),
              child: Column(
                children: [
                  _buildActionRow(
                    title: 'Change Password',
                    subtitle: null,
                    icon: Icons.lock_reset,
                    iconColor: labelColor,
                    onTap: () => Navigator.push(
                      context,
                      SlidePageRoute(page: const ChangePasswordScreen()),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: labelColor.withValues(alpha: 0.3),
                      size: 18,
                    ),
                    isLast: false,
                    textColor: textColor,
                    labelColor: labelColor,
                    dividerColor: dividerColor,
                  ),
                  _buildActionRow(
                    title: 'Logout',
                    subtitle: null,
                    icon: Icons.logout,
                    iconColor: const Color(0xFFf43f5e),
                    onTap: () => _showLogoutConfirmation(context, ref),
                    trailing: null,
                    isLast: true,
                    textColor: const Color(0xFFf43f5e),
                    labelColor: labelColor,
                    dividerColor: dividerColor,
                    isDestructive: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
            Center(
              child: Column(
                children: [
                  Text(
                    'EVENT ORDER PRO',
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'App Version v1.0.4',
                    style: TextStyle(
                      color: labelColor.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(Color cardColor, Color borderColor) {
    return BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: borderColor),
    );
  }

  Widget _buildSectionTitle(String title, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: labelColor,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSmallButton(
    String label,
    IconData icon,
    Color primaryColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
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
    // Admin can only act on non-founder, non-self users
    final canManage = !isSelf && !isFounder;

    return Opacity(
      opacity: isActive ? 1.0 : 0.6,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    name[0],
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
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
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: role == 'FOUNDER'
                              ? primaryColor.withValues(alpha: 0.1)
                              : labelColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: role == 'FOUNDER'
                                ? primaryColor.withValues(alpha: 0.2)
                                : labelColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: TextStyle(
                            color: role == 'FOUNDER'
                                ? primaryColor
                                : labelColor,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                // Reset password button
                GestureDetector(
                  onTap: () => _onResetPassword(
                    context: context,
                    ref: ref,
                    user: user,
                    canManage: canManage,
                    isSelf: isSelf,
                    isFounder: isFounder,
                    labelColor: labelColor,
                  ),
                  child: Icon(
                    Icons.lock_reset,
                    color: canManage
                        ? labelColor.withValues(alpha: 0.7)
                        : labelColor.withValues(alpha: 0.25),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                // Delete button
                GestureDetector(
                  onTap: () => _onDeleteUser(
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
                  child: Icon(
                    Icons.delete_outline,
                    color: canManage
                        ? const Color(0xFFf43f5e).withValues(alpha: 0.7)
                        : labelColor.withValues(alpha: 0.25),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                _buildSwitch(
                  context,
                  isActive,
                  onToggleActive,
                  primaryColor,
                  false,
                  small: true,
                ),
              ],
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
          'This will remove their profile. Their login credentials '
          'remain in the auth system — contact your Firebase project '
          'admin if full removal is needed.',
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

  void _showSnackBar(BuildContext context, String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFf43f5e) : const Color(0xFF10b981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _buildActionRow({
    required String title,
    String? subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required Widget? trailing,
    required bool isLast,
    required Color textColor,
    required Color labelColor,
    required Color dividerColor,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: isDestructive
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(color: labelColor, fontSize: 10),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceRow({
    required String title,
    required String subtitle,
    required Color textColor,
    required Color labelColor,
    required Widget child,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              Text(subtitle, style: TextStyle(color: labelColor, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        child,
      ],
    );
  }

  Widget _buildSwitch(
    BuildContext context,
    bool value,
    ValueChanged<bool> onChanged,
    Color primaryColor,
    bool isDarkMode, {
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
          borderRadius: BorderRadius.circular(6),
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

  Widget _buildDropdown(
    List<String> items,
    String value,
    bool isDarkMode,
    Color primaryColor,
    Color cardColor,
    Color textColor,
    Color labelColor,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0f172a) : const Color(0xFFf1f5f9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: cardColor,
          icon: Icon(Icons.keyboard_arrow_down, color: labelColor, size: 16),
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const RoleBasedRouter()),
                  (route) => false,
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
