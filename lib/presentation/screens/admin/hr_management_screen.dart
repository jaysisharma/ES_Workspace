import 'package:flutter/material.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:order_app/core/services/employee_pdf_service.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/attendance_entity.dart';
import 'package:order_app/domain/entities/employee_profile_entity.dart';
import 'package:order_app/domain/entities/leave_request_entity.dart';
import 'package:order_app/domain/entities/notification_entity.dart';
import 'package:order_app/domain/entities/order_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/presentation/providers/attendance_providers.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/employee_profile_providers.dart';
import 'package:order_app/presentation/providers/hr_providers.dart';
import 'package:order_app/presentation/providers/notification_notifier.dart';
import 'package:order_app/presentation/providers/order_providers.dart';
import 'package:order_app/presentation/providers/user_providers.dart';
import 'package:order_app/presentation/screens/common/utility/pdf_preview_screen.dart';
import 'package:order_app/presentation/screens/admin/employee_detail_screen.dart';
import 'package:order_app/presentation/screens/admin/add_employee_screen.dart';
import 'package:order_app/presentation/widgets/hr_management/admin_manual_attendance_dialog.dart';
import 'package:order_app/presentation/widgets/hr_management/leave_cycle_settings_dialog.dart';
import 'package:order_app/presentation/widgets/calendar/nepali_date_picker_dialog.dart';
import 'package:order_app/core/services/fcm_sender.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';

import '../../widgets/hr_management/hr_metrics_banner.dart';

class HrManagementScreen extends ConsumerStatefulWidget {
  const HrManagementScreen({super.key});

  @override
  ConsumerState<HrManagementScreen> createState() => _HrManagementScreenState();
}

class _HrManagementScreenState extends ConsumerState<HrManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _staffSearchQuery = '';
  String _roleFilter = 'all';

  // Leave Requests state
  String _leaveSearchQuery = '';
  DateTime? _leaveStartDate;
  DateTime? _leaveEndDate;
  int _leaveLimit = 10;
  final ScrollController _leaveScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _leaveScrollController.addListener(() {
      if (_leaveScrollController.position.pixels >=
          _leaveScrollController.position.maxScrollExtent - 200) {
        if (mounted) {
          setState(() {
            _leaveLimit += 10;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _leaveScrollController.dispose();
    super.dispose();
  }

  Future<void> _printSingleEmployeePdf(
    BuildContext context,
    UserEntity user,
  ) async {
    try {
      final profiles = await ref.read(employeeProfilesStreamProvider.future);
      final profile = profiles.cast<EmployeeProfileEntity>().firstWhere(
        (p) => p.userId == user.id,
        orElse: () => EmployeeProfileEntity(
          id: user.id,
          userId: user.id,
          name: user.name,
          officeJoinDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final pdfData = await EmployeePdfService.generateEmployeeDetailPdf(
        profile: profile,
        user: user,
      );

      final fileName =
          'Employee_Profile_${user.name.replaceAll(RegExp(r'[ ,]+'), '_')}.pdf';

      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            pdfData: pdfData,
            title: 'Employee Profile - ${user.name}',
            fileName: fileName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate Employee PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _printStaffDirectoryPdf(
    AsyncValue<List<UserEntity>> usersAsync,
    AsyncValue<List<EmployeeProfileEntity>> profilesAsync,
  ) async {
    try {
      final users = usersAsync.value ?? [];
      final profiles = profilesAsync.value ?? [];

      final pdfData = await EmployeePdfService.generateStaffListPdf(
        profiles: profiles,
        users: users,
      );

      final fileName =
          'Staff_Directory_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            pdfData: pdfData,
            title: 'Staff Directory',
            fileName: fileName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate Staff Directory PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeleteEmployee(BuildContext context, UserEntity user) async {
    bool deleteUserAccount = true;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Delete Employee Record',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to permanently delete "${user.name}" from employee records?',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: const Text(
                  '⚠️ This will permanently remove their HR profile, payroll data, documents, and credentials.',
                  style: TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              ),
              const SizedBox(height: 14),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: deleteUserAccount,
                activeColor: Colors.red,
                title: Text(
                  'Also remove user login (${user.email})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                onChanged: (val) {
                  setDialogState(() {
                    deleteUserAccount = val ?? false;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (shouldDelete == true && mounted) {
      try {
        await ref
            .read(employeeProfileNotifierProvider.notifier)
            .deleteProfileByUserId(user.id);

        if (deleteUserAccount) {
          await ref
              .read(userNotifierProvider.notifier)
              .deleteUser(user.id);
        }

        ref.invalidate(usersStreamProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Employee "${user.name}" deleted successfully.'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete employee: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;

    final usersAsync = ref.watch(usersStreamProvider);
    final profilesAsync = ref.watch(employeeProfilesStreamProvider);
    final attendanceAsync = ref.watch(todayAttendanceStreamProvider);
    final leaveRequestsAsync = ref.watch(leaveRequestsStreamProvider);
    final ordersAsync = ref.watch(ordersStreamProvider);

    final authUser = ref.watch(authNotifierProvider).user;
    final isAdmin = authUser?.role == UserRole.admin;

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'HR Management Hub',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.picture_as_pdf_outlined,
              color: colorScheme.primary,
            ),
            tooltip: 'Print Staff Directory PDF',
            onPressed: () => _printStaffDirectoryPdf(usersAsync, profilesAsync),
          ),
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.event_repeat),
              tooltip: 'Leave Cycle & Reset Settings',
              onPressed: () => showLeaveCycleSettingsDialog(context, ref),
            ),
            const SizedBox(width: 8),
            isMobile
                ? IconButton(
                    icon: const Icon(Icons.person_add_alt_1),
                    tooltip: 'New Employee Record',
                    onPressed: () {
                      context.pushPage(
                        const AddEmployeeScreen(
                          userId: '',
                          userName: '',
                          isNewUser: true,
                        ),
                      );
                    },
                  )
                : ElevatedButton.icon(
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: const Text('New Employee Record'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onPressed: () {
                      context.pushPage(
                        const AddEmployeeScreen(
                          userId: '',
                          userName: '',
                          isNewUser: true,
                        ),
                      );
                    },
                  ),
          ],
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: colorScheme.primary,
          unselectedLabelColor: labelColor,
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'Staff Directory'),
            Tab(icon: Icon(Icons.access_time), text: 'Live Attendance'),
            Tab(icon: Icon(Icons.event_busy_outlined), text: 'Leave Requests'),
            Tab(
              icon: Icon(Icons.analytics_outlined),
              text: 'Payroll & Metrics',
            ),
          ],
        ),
      ),
      floatingActionButton: const BottomRightBackButton(),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading users: $e')),
        data: (users) {
          final allUsers = users;

          final todayAttendance = attendanceAsync.maybeWhen(
            data: (list) => list,
            orElse: () => <AttendanceEntity>[],
          );

          final leaveRequests = leaveRequestsAsync.maybeWhen(
            data: (list) => list,
            orElse: () => <LeaveRequestEntity>[],
          );

          final orders = ordersAsync.maybeWhen(
            data: (list) => list.cast<OrderEntity>(),
            orElse: () => <OrderEntity>[],
          );

          final pendingLeaves = leaveRequests
              .where((l) => l.status == LeaveStatus.pending)
              .toList();

          final checkedInCount = todayAttendance
              .where((a) => a.checkInTime.day == DateTime.now().day)
              .length;

          final onLeaveToday = leaveRequests.where((l) {
            final now = DateTime.now();
            return l.status == LeaveStatus.approved &&
                l.startDate.isBefore(now.add(const Duration(days: 1))) &&
                l.endDate.isAfter(now.subtract(const Duration(days: 1)));
          }).length;

          return Column(
            children: [
              // Top Metric Banner
              HrMetricsBannerWidget(
                totalStaff: allUsers.length,
                checkedIn: checkedInCount,
                onLeave: onLeaveToday,
                pendingLeaves: pendingLeaves.length,
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Staff Directory
                    _buildStaffDirectoryTab(
                      context,
                      allUsers,
                      orders,
                      profilesAsync.maybeWhen(data: (p) => p, orElse: () => []),
                      isAdmin: isAdmin,
                    ),

                    // Tab 2: Live Attendance
                    _buildAttendanceTab(context, todayAttendance),

                    // Tab 3: Leave Requests
                    _buildLeaveRequestsTab(context, leaveRequests),

                    // Tab 4: Payroll & Metrics
                    _buildPayrollMetricsTab(
                      context,
                      allUsers,
                      orders,
                      todayAttendance,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // TAB 1: Staff Directory
  Widget _buildStaffDirectoryTab(
    BuildContext context,
    List<UserEntity> users,
    List<OrderEntity> orders,
    List<EmployeeProfileEntity> profiles, {
    bool isAdmin = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;

    final filtered = users.where((u) {
      final matchesSearch =
          u.name.toLowerCase().contains(_staffSearchQuery.toLowerCase()) ||
          u.email.toLowerCase().contains(_staffSearchQuery.toLowerCase());
      final matchesRole = _roleFilter == 'all' || u.role.name == _roleFilter;
      return matchesSearch && matchesRole;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _staffSearchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search staff by name or email...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _roleFilter,
                onChanged: (val) {
                  if (val != null) setState(() => _roleFilter = val);
                },
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Roles')),
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'founder', child: Text('Founder')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No staff members found',
                      style: TextStyle(color: labelColor),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final u = filtered[index];
                      final assignedCount = orders
                          .where((o) => o.assignedStaffIds.contains(u.id))
                          .length;

                      final isMobile = MediaQuery.of(context).size.width < 600;

                      final roleColor = u.role == UserRole.admin
                          ? Colors.purple
                          : u.role == UserRole.founder
                          ? Colors.blue
                          : u.role == UserRole.finance
                          ? Colors.orange
                          : Colors.green;

                      final roleBadge = Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          u.role.displayName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: roleColor,
                          ),
                        ),
                      );

                      if (isMobile) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              context.pushPage(EmployeeDetailScreen(user: u));
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      (() {
                                        final profile = profiles
                                            .where((p) => p.userId == u.id)
                                            .firstOrNull;
                                        final photoUrl = profile?.photoUrl;
                                        return CircleAvatar(
                                          backgroundColor:
                                              colorScheme.primaryContainer,
                                          foregroundImage:
                                              (photoUrl != null &&
                                                  photoUrl.isNotEmpty)
                                              ? NetworkImage(photoUrl)
                                              : null,
                                          onForegroundImageError:
                                              (photoUrl != null &&
                                                  photoUrl.isNotEmpty)
                                              ? (_, __) {}
                                              : null,
                                          child: Text(
                                            u.name.isNotEmpty
                                                ? u.name[0].toUpperCase()
                                                : 'U',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                          ),
                                        );
                                      })(),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    u.name,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                roleBadge,
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              u.email,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: labelColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isAdmin)
                                        Switch(
                                          value: u.isActive,
                                          onChanged: (val) async {
                                            await ref
                                                .read(
                                                  leaveRequestNotifierProvider
                                                      .notifier,
                                                )
                                                .toggleUserActive(u.id, val);
                                            ref.invalidate(usersStreamProvider);
                                          },
                                        ),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '$assignedCount Events Assigned',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: labelColor,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.picture_as_pdf_outlined,
                                          size: 18,
                                          color: colorScheme.primary,
                                        ),
                                        tooltip: 'Print Employee PDF',
                                        onPressed: () =>
                                            _printSingleEmployeePdf(context, u),
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(
                                          Icons.badge_outlined,
                                          size: 14,
                                        ),
                                        label: const Text('View HR File'),
                                        onPressed: () {
                                          context.pushPage(
                                            EmployeeDetailScreen(user: u),
                                          );
                                        },
                                      ),
                                      if (isAdmin)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 18,
                                            color: Colors.redAccent,
                                          ),
                                          tooltip: 'Delete Employee Record',
                                          onPressed: () =>
                                              _confirmDeleteEmployee(context, u),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        child: ListTile(
                          leading: (() {
                            final profile = profiles
                                .where((p) => p.userId == u.id)
                                .firstOrNull;
                            final photoUrl = profile?.photoUrl;
                            return CircleAvatar(
                              backgroundColor: colorScheme.primaryContainer,
                              foregroundImage:
                                  (photoUrl != null && photoUrl.isNotEmpty)
                                  ? NetworkImage(photoUrl)
                                  : null,
                              onForegroundImageError:
                                  (photoUrl != null && photoUrl.isNotEmpty)
                                  ? (_, __) {}
                                  : null,
                              child: Text(
                                u.name.isNotEmpty
                                    ? u.name[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            );
                          })(),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  u.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              roleBadge,
                            ],
                          ),
                          subtitle: Text(
                            '${u.email} • $assignedCount Events Assigned',
                            style: TextStyle(fontSize: 12, color: labelColor),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.picture_as_pdf_outlined,
                                  size: 18,
                                  color: colorScheme.primary,
                                ),
                                tooltip: 'Print Employee PDF',
                                onPressed: () =>
                                    _printSingleEmployeePdf(context, u),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.badge_outlined,
                                  size: 14,
                                ),
                                label: const Text('HR File'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                ),
                                onPressed: () {
                                  context.pushPage(
                                    EmployeeDetailScreen(user: u),
                                  );
                                },
                              ),
                              if (isAdmin) ...[
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: Colors.redAccent,
                                  ),
                                  tooltip: 'Delete Employee Record',
                                  onPressed: () =>
                                      _confirmDeleteEmployee(context, u),
                                ),
                                const SizedBox(width: 4),
                                Switch(
                                  value: u.isActive,
                                  onChanged: (val) async {
                                    await ref
                                        .read(
                                          leaveRequestNotifierProvider.notifier,
                                        )
                                        .toggleUserActive(u.id, val);
                                    ref.invalidate(usersStreamProvider);
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // TAB 2: Attendance & Shifts
  Widget _buildAttendanceTab(
    BuildContext context,
    List<AttendanceEntity> attendance,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Today\'s Check-in Log (${attendance.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // Prompt manual attendance dialog
                  _showManualAttendanceDialog(context);
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Manual Entry'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: attendance.isEmpty
                ? Center(
                    child: Text(
                      'No attendance records for today',
                      style: TextStyle(color: labelColor),
                    ),
                  )
                : ListView.builder(
                    itemCount: attendance.length,
                    itemBuilder: (context, index) {
                      final item = attendance[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                item.status == AttendanceStatus.present
                                ? Colors.green.withValues(alpha: 0.1)
                                : item.status == AttendanceStatus.halfDay
                                ? Colors.orange.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
                            child: Icon(
                              item.status == AttendanceStatus.present
                                  ? Icons.check
                                  : item.status == AttendanceStatus.halfDay
                                  ? Icons.timelapse
                                  : Icons.close,
                              color: item.status == AttendanceStatus.present
                                  ? Colors.green
                                  : item.status == AttendanceStatus.halfDay
                                  ? Colors.orange
                                  : Colors.red,
                            ),
                          ),
                          title: Text(
                            item.staffName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Event: ${item.eventTitle}\nCheck-in: ${formatNepaliDate(item.checkInTime, 'hh:mm a')}${item.checkOutTime != null ? ' | Out: ${formatNepaliDate(item.checkOutTime!, 'hh:mm a')}' : ''}',
                            style: TextStyle(fontSize: 12, color: labelColor),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: item.isWithinGeofence
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.isWithinGeofence
                                      ? 'Geofence OK'
                                      : 'Out of Geofence',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: item.isWithinGeofence
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // TAB 3: Leave Requests
  Widget _buildLeaveRequestsTab(
    BuildContext context,
    List<LeaveRequestEntity> requests,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;

    // Filter requests
    final filtered = requests.where((l) {
      final matchesSearch = l.staffName.toLowerCase().contains(
        _leaveSearchQuery.toLowerCase(),
      );

      if (!matchesSearch) return false;

      if (_leaveStartDate != null && _leaveEndDate != null) {
        // Normalizing date ranges to only check date parts
        final startL = DateTime(
          l.startDate.year,
          l.startDate.month,
          l.startDate.day,
        );
        final endL = DateTime(l.endDate.year, l.endDate.month, l.endDate.day);
        final startQ = DateTime(
          _leaveStartDate!.year,
          _leaveStartDate!.month,
          _leaveStartDate!.day,
        );
        final endQ = DateTime(
          _leaveEndDate!.year,
          _leaveEndDate!.month,
          _leaveEndDate!.day,
        );

        // Standard overlap: !(l.startDate > Q.end || l.endDate < Q.start)
        final overlaps = !(startL.isAfter(endQ) || endL.isBefore(startQ));
        return overlaps;
      }
      return true;
    }).toList();

    // Calculate total approved leave days in the selected date range
    int totalLeaveDays = 0;
    if (_leaveStartDate != null && _leaveEndDate != null) {
      for (final l in filtered) {
        if (l.status == LeaveStatus.approved) {
          final startL = DateTime(
            l.startDate.year,
            l.startDate.month,
            l.startDate.day,
          );
          final endL = DateTime(l.endDate.year, l.endDate.month, l.endDate.day);
          final startQ = DateTime(
            _leaveStartDate!.year,
            _leaveStartDate!.month,
            _leaveStartDate!.day,
          );
          final endQ = DateTime(
            _leaveEndDate!.year,
            _leaveEndDate!.month,
            _leaveEndDate!.day,
          );

          final overlapStart = startL.isAfter(startQ) ? startL : startQ;
          final overlapEnd = endL.isBefore(endQ) ? endL : endQ;

          if (!overlapStart.isAfter(overlapEnd)) {
            totalLeaveDays += overlapEnd.difference(overlapStart).inDays + 1;
          }
        }
      }
    }

    final paginatedList = filtered.take(_leaveLimit).toList();
    final hasMore = filtered.length > _leaveLimit;

    Future<void> selectDateRange() async {
      final picked = await NepaliDatePickerDialog.show(
        context: context,
        title: 'Filter Leave Requests (Nepali BS)',
        initialStart: _leaveStartDate ?? DateTime.now(),
        initialEnd: _leaveEndDate ?? DateTime.now(),
        allowRange: true,
      );
      if (picked != null && picked['start'] != null) {
        setState(() {
          _leaveStartDate = picked['start']!;
          _leaveEndDate = picked['end'] ?? picked['start']!;
        });
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() {
                    _leaveSearchQuery = val;
                    _leaveLimit = 10; // Reset limit on search
                  }),
                  decoration: InputDecoration(
                    hintText: 'Search by staff name...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: selectDateRange,
                icon: const Icon(Icons.date_range, size: 16),
                label: Text(
                  _leaveStartDate != null && _leaveEndDate != null
                      ? '${formatNepaliDate(_leaveStartDate!, "dd MMM")} - ${formatNepaliDate(_leaveEndDate!, "dd MMM")}'
                      : 'Date Range',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                ),
              ),
              if (_leaveSearchQuery.isNotEmpty || _leaveStartDate != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.clear_all),
                  tooltip: 'Clear filters',
                  onPressed: () => setState(() {
                    _leaveSearchQuery = '';
                    _leaveStartDate = null;
                    _leaveEndDate = null;
                    _leaveLimit = 10;
                  }),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Leave Summary Card (Only if date range is selected)
          if (_leaveStartDate != null && _leaveEndDate != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.summarize_outlined, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _leaveSearchQuery.isNotEmpty
                              ? 'Approved leaves for "$_leaveSearchQuery"'
                              : 'Total Approved Leaves (All Staff)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Period: ${formatNepaliDate(_leaveStartDate!, "dd MMM yyyy")} to ${formatNepaliDate(_leaveEndDate!, "dd MMM yyyy")}',
                          style: TextStyle(fontSize: 11, color: labelColor),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$totalLeaveDays days',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          Row(
            children: [
              Expanded(
                child: Text(
                  'Leave & Absence Requests (${filtered.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_repeat, size: 14),
                label: const Text('Leave Cycle', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => showLeaveCycleSettingsDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No matching leave requests found',
                      style: TextStyle(color: labelColor),
                    ),
                  )
                : ListView.builder(
                    controller: _leaveScrollController,
                    itemCount: paginatedList.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == paginatedList.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final l = paginatedList[index];
                      final isPending = l.status == LeaveStatus.pending;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    l.staffName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isPending
                                          ? Colors.orange.withValues(alpha: 0.1)
                                          : l.status == LeaveStatus.approved
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      l.status.displayName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isPending
                                            ? Colors.orange
                                            : l.status == LeaveStatus.approved
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Type: ${l.leaveType} | Period: ${formatNepaliDate(l.startDate, 'dd MMM yyyy')} - ${formatNepaliDate(l.endDate, 'dd MMM yyyy')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: labelColor,
                                ),
                              ),
                              if (l.reason.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Reason: "${l.reason}"',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                              if (isPending) ...[
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () =>
                                          _reviewLeave(l, LeaveStatus.rejected),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(
                                          color: Colors.red,
                                        ),
                                      ),
                                      child: const Text('Reject'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () =>
                                          _reviewLeave(l, LeaveStatus.approved),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Approve'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // TAB 4: Payroll & Metrics
  Widget _buildPayrollMetricsTab(
    BuildContext context,
    List<UserEntity> staffUsers,
    List<OrderEntity> orders,
    List<AttendanceEntity> todayAttendance,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Staff Performance & Work Hours',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Export Payroll Report',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('HR Payroll summary prepared for export.'),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: staffUsers.length,
              itemBuilder: (context, index) {
                final u = staffUsers[index];
                final assignedOrders = orders
                    .where((o) => o.assignedStaffIds.contains(u.id))
                    .toList();

                // Retrieve profile if available
                final profilesAsync = ref.watch(employeeProfilesStreamProvider);
                final profile = profilesAsync.maybeWhen(
                  data: (list) {
                    final matching = list.where((p) => p.userId == u.id);
                    return matching.isNotEmpty ? matching.first : null;
                  },
                  orElse: () => null,
                );

                final basic = profile?.basicSalary ?? 0.0;
                final da = profile?.dearnessAllowance ?? 0.0;
                final bonus = profile?.bonus ?? 0.0;
                final gross = profile?.grossSalary ?? (basic + da + bonus);
                final tds = profile?.tds ?? 0.0;
                final net =
                    profile?.netSalary ??
                    (gross - (profile?.totalDeductions ?? 0.0));

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                u.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${assignedOrders.length} Events Assigned',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Email: ${u.email}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: labelColor,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: u.isActive
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                u.isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: u.isActive ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 10),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Gross: NPR ${gross.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            if (tds > 0)
                              Text(
                                'TDS: NPR ${tds.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                ),
                              ),
                            Text(
                              'Net: NPR ${net.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reviewLeave(LeaveRequestEntity l, LeaveStatus status) async {
    try {
      await ref
          .read(leaveRequestNotifierProvider.notifier)
          .reviewLeave(requestId: l.id, status: status);

      // Dispatch targeted notification to staff member
      final isApproved = status == LeaveStatus.approved;
      final notifTitle = isApproved
          ? 'Leave Approved'
          : 'Leave Request Rejected';
      final notifBody = isApproved
          ? 'Your leave request for ${formatNepaliDate(l.startDate, 'dd MMM')} to ${formatNepaliDate(l.endDate, 'dd MMM')} has been approved.'
          : 'Your leave request for ${formatNepaliDate(l.startDate, 'dd MMM')} was rejected.';

      await ref
          .read(notificationNotifierProvider.notifier)
          .addNotification(
            NotificationEntity(
              id: const Uuid().v4(),
              title: notifTitle,
              description: notifBody,
              timestamp: DateTime.now(),
              type: 'system',
              targetRole: 'staff',
              targetUserId: l.staffId,
            ),
          );

      FcmSender.sendToUser(
        userId: l.staffId,
        title: notifTitle,
        body: notifBody,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Leave request ${status.name} successfully.'),
            backgroundColor: isApproved ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showManualAttendanceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AdminManualAttendanceDialog(),
    );
  }
}
