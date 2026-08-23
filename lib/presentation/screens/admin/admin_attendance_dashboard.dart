import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:order_app/core/services/attendance_excel_export_service.dart';
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

class AdminAttendanceDashboard extends ConsumerStatefulWidget {
  const AdminAttendanceDashboard({super.key});

  @override
  ConsumerState<AdminAttendanceDashboard> createState() =>
      _AdminAttendanceDashboardState();
}

class _AdminAttendanceDashboardState
    extends ConsumerState<AdminAttendanceDashboard> {
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

    return Scaffold(
      floatingActionButton: const BottomRightBackButton(),
      appBar: AppBar(
        title: const Text('Staff Attendance & Geofence Audit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_outlined),
            tooltip: 'Export Month Excel',
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
            icon: const Icon(Icons.share_location_rounded),
            tooltip: 'Manage Geofence Zone',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const ManageGeofenceDialog(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(allAttendanceStreamProvider);
              ref.invalidate(usersStreamProvider);
            },
          ),
        ],
      ),
      body: Column(
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

          // Main View Stream Body
          Expanded(
            child: attendanceStream.when(
              data: (allRecords) {
                // Filter by Staff ID or Search Query if specified
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
                var dayRecords = filtered.where((r) {
                  return r.checkInTime.year == _selectedDate.year &&
                      r.checkInTime.month == _selectedDate.month &&
                      r.checkInTime.day == _selectedDate.day;
                }).toList();

                if (_showOnlyOutOfBounds) {
                  dayRecords = dayRecords.where((r) => !r.isWithinGeofence).toList();
                }

                dayRecords.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));

                final nepaliDayHeader = formatNepaliDate(_selectedDate, 'yyyy MMMM dd');

                return Column(
                  children: [
                    // Metric Summary Chips
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMetricChip('Total Logs', '${dayRecords.length}', Theme.of(context).colorScheme.primary),
                          _buildMetricChip(
                            'On Duty',
                            '${dayRecords.where((r) => !r.isCheckedOut).length}',
                            Theme.of(context).colorScheme.secondary,
                          ),
                          _buildMetricChip(
                            'Present',
                            '${dayRecords.where((r) => r.status == AttendanceStatus.present).length}',
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
                              '${allRecords.where((r) => !r.isWithinGeofence).length}',
                              Theme.of(context).colorScheme.error,
                              _showOnlyOutOfBounds,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Day Record List
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
