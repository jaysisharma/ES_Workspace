import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:order_app/core/services/attendance_excel_export_service.dart';
import 'package:order_app/core/services/location_tracking_service.dart';
import 'package:order_app/domain/entities/attendance_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/presentation/providers/attendance_providers.dart';
import 'package:order_app/presentation/providers/hr_providers.dart';
import 'package:order_app/presentation/widgets/hr_management/manage_geofence_dialog.dart';
import 'package:order_app/presentation/widgets/calendar/nepali_date_picker_dialog.dart';
import 'package:order_app/presentation/widgets/hr_management/admin_attendance_card.dart';
import 'package:order_app/presentation/widgets/hr_management/admin_attendance_filter_bar.dart';
import 'package:order_app/presentation/widgets/hr_management/admin_attendance_month_view.dart';
import 'package:order_app/presentation/widgets/common/bottom_right_back_button.dart';

enum AdminDashboardTab {
  attendance,
  loginLogs,
}

class AdminAttendanceDashboard extends ConsumerStatefulWidget {
  final AdminDashboardTab initialTab;

  const AdminAttendanceDashboard({
    super.key,
    this.initialTab = AdminDashboardTab.attendance,
  });

  @override
  ConsumerState<AdminAttendanceDashboard> createState() =>
      _AdminAttendanceDashboardState();
}

class _AdminAttendanceDashboardState
    extends ConsumerState<AdminAttendanceDashboard> {
  late AdminDashboardTab _selectedTab = widget.initialTab;
  AttendanceViewMode _viewMode = AttendanceViewMode.day;
  DateTime _selectedDate = DateTime.now();
  String? _selectedStaffId;
  String _searchQuery = '';
  bool _showOnlyOutOfBounds = false;

  void _showSelfieDialog(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(title),
                automaticallyImplyLeading: false,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Image.network(
                imageUrl,
                height: 350,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 250,
                    color: Colors.grey.shade300,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Selfie stored on Synology NAS'),
                      ],
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'Stored on Synology NAS: $imageUrl',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final picked = await NepaliDatePickerDialog.show(
      context: context,
      title: 'Select Attendance Date (Nepali BS)',
      initialStart: _selectedDate,
      allowRange: false,
    );
    if (picked != null && picked['start'] != null) {
      setState(() {
        _selectedDate = picked['start']!;
      });
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select Month & Year',
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  void _exportEmployeeMonthlyExcel({
    required List<AttendanceEntity> allRecords,
    required List<UserEntity> staffList,
    UserEntity? specificStaff,
  }) {
    final monthRecords = allRecords.where((r) {
      return r.checkInTime.year == _selectedDate.year &&
          r.checkInTime.month == _selectedDate.month;
    }).toList();

    if (specificStaff != null) {
      final staffRecords = monthRecords.where((r) => r.staffId == specificStaff.id).toList();
      AttendanceExcelExportService.exportMonthlyAttendance(
        context: context,
        records: staffRecords,
        selectedMonth: _selectedDate,
        selectedStaff: specificStaff,
      );
      return;
    }

    if (_selectedStaffId != null) {
      final staff = staffList.where((u) => u.id == _selectedStaffId).firstOrNull;
      final staffRecords = monthRecords.where((r) => r.staffId == _selectedStaffId).toList();
      AttendanceExcelExportService.exportMonthlyAttendance(
        context: context,
        records: staffRecords,
        selectedMonth: _selectedDate,
        selectedStaff: staff,
        staffNameOverride: staff?.name ?? 'Selected_Employee',
      );
      return;
    }

    // Show Employee Selection Dialog to choose which employee to export
    _showExportChoiceDialog(monthRecords, staffList);
  }

  void _showExportChoiceDialog(
    List<AttendanceEntity> monthRecords,
    List<UserEntity> staffList,
  ) {
    final nepaliMonthHeader = formatNepaliDate(_selectedDate, 'yyyy MMMM');
    String dialogSearch = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredList = staffList.where((s) {
              if (dialogSearch.isEmpty) return true;
              return s.name.toLowerCase().contains(dialogSearch.toLowerCase()) ||
                  s.email.toLowerCase().contains(dialogSearch.toLowerCase());
            }).toList();

            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Export Attendance to Excel',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '$nepaliMonthHeader BS Month Report',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Option 1: Export ALL Staff (Consolidated)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pop(context);
                        AttendanceExcelExportService.exportMonthlyAttendance(
                          context: this.context,
                          records: monthRecords,
                          selectedMonth: _selectedDate,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF064E3B).withValues(alpha: 0.45)
                              : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF059669)
                                : const Color(0xFFA7F3D0),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.table_chart_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Export All Employees (Consolidated)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: isDark
                                          ? const Color(0xFF6EE7B7)
                                          : const Color(0xFF065F46),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Total ${monthRecords.length} records across all staff in $nepaliMonthHeader',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? const Color(0xFFA7F3D0)
                                          : const Color(0xFF047857),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF059669).withValues(alpha: 0.3)
                                    : const Color(0xFFD1FAE5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.download_rounded,
                                color: isDark
                                    ? const Color(0xFF6EE7B7)
                                    : const Color(0xFF059669),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Search for employee
                  TextField(
                    onChanged: (val) => setSheetState(() => dialogSearch = val),
                    decoration: InputDecoration(
                      hintText: 'Search employee to export...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  const Text(
                    'Or Choose Specific Employee:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),

                  Expanded(
                    child: filteredList.isEmpty
                        ? const Center(
                            child: Text(
                              'No employees found',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredList.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final staff = filteredList[idx];
                              final staffCount = monthRecords.where((r) => r.staffId == staff.id).length;

                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 16,
                                  child: Text(
                                    staff.name.isNotEmpty ? staff.name[0].toUpperCase() : 'E',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(
                                  staff.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                subtitle: Text(
                                  '${staff.role.name.toUpperCase()} • $staffCount logs this month',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  icon: const Icon(Icons.file_download, size: 14),
                                  label: const Text('Export', style: TextStyle(fontSize: 11)),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    final staffRecords = monthRecords.where((r) => r.staffId == staff.id).toList();
                                    AttendanceExcelExportService.exportMonthlyAttendance(
                                      context: this.context,
                                      records: staffRecords,
                                      selectedMonth: _selectedDate,
                                      selectedStaff: staff,
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendanceStream = ref.watch(allAttendanceStreamProvider);
    final usersAsync = ref.watch(usersStreamProvider);

    final staffList = usersAsync.maybeWhen(
      data: (users) => users,
      orElse: () => <UserEntity>[],
    );

    final selectedStaff = staffList.where((u) => u.id == _selectedStaffId).firstOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: const BottomRightBackButton(),
      appBar: AppBar(
        title: Text(
          _selectedTab == AdminDashboardTab.attendance
              ? 'Staff Attendance'
              : 'User Login & Location Logs',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_selectedTab == AdminDashboardTab.attendance) ...[
            IconButton(
              icon: const Icon(Icons.table_chart_outlined, size: 20),
              tooltip: 'Export Month Excel',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                attendanceStream.whenData((allRecords) {
                  _exportEmployeeMonthlyExcel(
                    allRecords: allRecords,
                    staffList: staffList,
                    specificStaff: selectedStaff,
                  );
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.share_location_rounded, size: 20),
              tooltip: 'Manage Geofence Zone',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const ManageGeofenceDialog(),
                );
              },
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              ref.invalidate(allAttendanceStreamProvider);
              ref.invalidate(usersStreamProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Segmented Navigation Pill Switcher
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF141f28)
                  : const Color(0xFFf8fafc),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF1e2d3d) : const Color(0xFFe2e8f0),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    title: 'Event Attendance',
                    icon: Icons.checklist_rtl_rounded,
                    isSelected: _selectedTab == AdminDashboardTab.attendance,
                    onTap: () => setState(() => _selectedTab = AdminDashboardTab.attendance),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTabButton(
                    title: 'Login & Locations',
                    icon: Icons.location_on_rounded,
                    isSelected: _selectedTab == AdminDashboardTab.loginLogs,
                    onTap: () => setState(() => _selectedTab = AdminDashboardTab.loginLogs),
                  ),
                ),
              ],
            ),
          ),

          // Main View Body
          Expanded(
            child: _selectedTab == AdminDashboardTab.attendance
                ? _buildAttendanceView(attendanceStream, staffList, selectedStaff)
                : _buildLoginLocationLogsView(staffList),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Material(
      color: isSelected ? primaryColor : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? primaryColor : theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceView(
    AsyncValue<List<AttendanceEntity>> attendanceStream,
    List<UserEntity> staffList,
    UserEntity? selectedStaff,
  ) {
    return Column(
      children: [
        // Filter Bar
        AdminAttendanceFilterBarWidget(
          viewMode: _viewMode,
          onViewModeChanged: (mode) => setState(() => _viewMode = mode),
          selectedDate: _selectedDate,
          onPickDate: _pickDate,
          onPickMonth: _pickMonth,
          selectedStaffId: _selectedStaffId,
          staffList: staffList,
          onStaffChanged: (id) => setState(() => _selectedStaffId = id),
          searchQuery: _searchQuery,
          onSearchQueryChanged: (query) => setState(() => _searchQuery = query),
          showOnlyOutOfBounds: _showOnlyOutOfBounds,
          onOutOfBoundsToggled: (val) => setState(() => _showOnlyOutOfBounds = val),
        ),

        // Main Attendance Stream
        Expanded(
          child: attendanceStream.when(
            data: (allRecords) {
              var filtered = allRecords.where((r) {
                if (_selectedStaffId != null && r.staffId != _selectedStaffId) {
                  return false;
                }
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  final matchName = r.staffName.toLowerCase().contains(q);
                  final matchEvent = r.eventTitle.toLowerCase().contains(q);
                  return matchName || matchEvent;
                }
                return true;
              }).toList();

              if (_viewMode == AttendanceViewMode.month) {
                final monthlyRecords = filtered.where((r) {
                  return r.checkInTime.year == _selectedDate.year &&
                      r.checkInTime.month == _selectedDate.month;
                }).toList();
                monthlyRecords.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));

                return AdminAttendanceMonthViewWidget(
                  monthlyRecords: monthlyRecords,
                  selectedStaff: selectedStaff,
                  selectedMonth: _selectedDate,
                  onStatusChanged: (item, status) {
                    ref
                        .read(attendanceNotifierProvider.notifier)
                        .updateStatus(item.id, status);
                  },
                  onSelfieTap: (url, name) => _showSelfieDialog(
                    context,
                    url,
                    '$name Check-In Selfie',
                  ),
                  onExportExcel: () {
                    _exportEmployeeMonthlyExcel(
                      allRecords: allRecords,
                      staffList: staffList,
                      specificStaff: selectedStaff,
                    );
                  },
                );
              }

              // Day View Mode
              final dayBaseRecords = filtered.where((r) {
                return r.checkInTime.year == _selectedDate.year &&
                    r.checkInTime.month == _selectedDate.month &&
                    r.checkInTime.day == _selectedDate.day;
              }).toList();

              final totalLogsCount = dayBaseRecords.length;
              final onDutyCount =
                  dayBaseRecords.where((r) => !r.isCheckedOut).length;
              final presentCount = dayBaseRecords
                  .where((r) => r.status == AttendanceStatus.present)
                  .length;
              final outOfFenceCount =
                  dayBaseRecords.where((r) => !r.isWithinGeofence).length;

              var dayRecords = _showOnlyOutOfBounds
                  ? dayBaseRecords.where((r) => !r.isWithinGeofence).toList()
                  : dayBaseRecords;

              dayRecords.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));

              final nepaliDayHeader = formatNepaliDate(_selectedDate, 'yyyy MMMM dd');

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricChip(
                          'Total Logs',
                          '$totalLogsCount',
                          Theme.of(context).colorScheme.primary,
                        ),
                        _buildMetricChip(
                          'On Duty',
                          '$onDutyCount',
                          Theme.of(context).colorScheme.secondary,
                        ),
                        _buildMetricChip(
                          'Present',
                          '$presentCount',
                          Theme.of(context).colorScheme.tertiary,
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showOnlyOutOfBounds = !_showOnlyOutOfBounds;
                            });
                          },
                          child: _buildMetricChip(
                            'Out of Fence',
                            '$outOfFenceCount',
                            Theme.of(context).colorScheme.error,
                            _showOnlyOutOfBounds,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: dayRecords.isEmpty
                        ? Center(
                            child: Text(
                              'No attendance records found for $nepaliDayHeader BS',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: dayRecords.length,
                            itemBuilder: (context, index) {
                              final item = dayRecords[index];
                              return AdminAttendanceCardWidget(
                                item: item,
                                onStatusChanged: (status) {
                                  ref
                                      .read(attendanceNotifierProvider.notifier)
                                      .updateStatus(item.id, status);
                                },
                                onSelfieTap: () {
                                  if (item.checkInSelfieUrl != null) {
                                    _showSelfieDialog(
                                      context,
                                      item.checkInSelfieUrl!,
                                      '${item.staffName} Check-In Selfie',
                                    );
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, stack) => Center(child: Text('Error loading logs: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginLocationLogsView(List<UserEntity> staffList) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF141f28) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1e2d3d) : const Color(0xFFe2e8f0);
    final textColor = isDark ? Colors.white : const Color(0xFF0f172a);
    final labelColor = isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b);

    return Column(
      children: [
        // Filter bar for login logs
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Column(
            children: [
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                style: TextStyle(fontSize: 13, color: textColor),
                decoration: InputDecoration(
                  hintText: 'Search by staff name, email, or location...',
                  hintStyle: TextStyle(fontSize: 12.5, color: labelColor),
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: labelColor),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0b1319) : const Color(0xFFf1f5f9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All Staff'),
                      selected: _selectedStaffId == null,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedStaffId = null);
                      },
                    ),
                    const SizedBox(width: 6),
                    ...staffList.map((staff) {
                      final isSelected = _selectedStaffId == staff.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          label: Text(staff.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedStaffId = selected ? staff.id : null);
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Live stream of login logs
        Expanded(
          child: StreamBuilder<List<LoginLocationData>>(
            stream: LocationTrackingService.getLoginLogsStream(limit: 150),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading location logs: ${snapshot.error}'),
                );
              }

              final allLogs = snapshot.data ?? [];
              final filteredLogs = allLogs.where((log) {
                if (_selectedStaffId != null && log.userId != _selectedStaffId) {
                  return false;
                }
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  final matchName = log.userName.toLowerCase().contains(q);
                  final matchEmail = log.userEmail.toLowerCase().contains(q);
                  final matchAddress = log.address.toLowerCase().contains(q);
                  final matchDevice = log.device.toLowerCase().contains(q);
                  return matchName || matchEmail || matchAddress || matchDevice;
                }
                return true;
              }).toList();

              if (filteredLogs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off_rounded, size: 48, color: labelColor.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text(
                        'No login location records found',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Location coordinates are detected automatically when users log in.',
                        style: TextStyle(fontSize: 11.5, color: labelColor.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: filteredLogs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final log = filteredLogs[index];
                  return _buildLoginLogCard(
                    log: log,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textColor: textColor,
                    labelColor: labelColor,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoginLogCard({
    required LoginLocationData log,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color labelColor,
  }) {
    final theme = Theme.of(context);
    final hasCoordinates = log.latitude != null && log.longitude != null;
    final timeStr = DateFormat('yyyy-MM-dd • hh:mm a').format(log.timestamp);
    final nepaliDateStr = formatNepaliDate(log.timestamp, 'yyyy MMMM dd (EEE)');

    Color roleBadgeColor;
    switch (log.userRole.toLowerCase()) {
      case 'superadmin':
        roleBadgeColor = const Color(0xFF7c3aed);
        break;
      case 'admin':
        roleBadgeColor = const Color(0xFFa855f7);
        break;
      case 'director':
      case 'founder':
        roleBadgeColor = const Color(0xFF6366f1);
        break;
      case 'finance':
        roleBadgeColor = const Color(0xFFf59e0b);
        break;
      default:
        roleBadgeColor = const Color(0xFF0075db);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Role Badge, and Time
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: roleBadgeColor.withValues(alpha: 0.15),
                child: Text(
                  log.userName.isNotEmpty ? log.userName[0].toUpperCase() : 'U',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: roleBadgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            log.userName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: roleBadgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: roleBadgeColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            log.userRole.toUpperCase(),
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: roleBadgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      log.userEmail,
                      style: TextStyle(fontSize: 11.5, color: labelColor),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Text(
                    nepaliDateStr,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Location Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 18,
                  color: hasCoordinates ? const Color(0xFF10b981) : const Color(0xFFef4444),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.address,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      if (hasCoordinates) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Coordinates: ${log.latitude!.toStringAsFixed(5)}, ${log.longitude!.toStringAsFixed(5)}',
                          style: TextStyle(fontSize: 10.5, color: labelColor),
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasCoordinates) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      LocationTrackingService.openMap(log.latitude!, log.longitude!);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0075db).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF0075db).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_rounded, size: 13, color: Color(0xFF0075db)),
                          SizedBox(width: 4),
                          Text(
                            'Maps',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0075db),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Footer Badges: Device and IP
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: labelColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      log.device.toLowerCase().contains('iphone') ||
                              log.device.toLowerCase().contains('android')
                          ? Icons.smartphone_rounded
                          : Icons.computer_rounded,
                      size: 11,
                      color: labelColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      log.device,
                      style: TextStyle(fontSize: 10, color: labelColor, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (log.ip != null && log.ip!.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: labelColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'IP: ${log.ip}',
                    style: TextStyle(fontSize: 10, color: labelColor, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(
    String label,
    String value,
    Color color, [
    bool isSelected = false,
  ]) {
    return Container(
      width: 85,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.25) : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? color : color.withValues(alpha: 0.3),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
