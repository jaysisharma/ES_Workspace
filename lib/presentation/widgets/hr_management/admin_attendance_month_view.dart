import 'package:flutter/material.dart';
import 'package:order_app/domain/entities/attendance_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/presentation/widgets/hr_management/admin_attendance_card.dart';

class AdminAttendanceMonthViewWidget extends StatelessWidget {
  final List<AttendanceEntity> monthlyRecords;
  final UserEntity? selectedStaff;
  final DateTime selectedMonth;
  final Function(AttendanceEntity, AttendanceStatus) onStatusChanged;
  final Function(String, String) onSelfieTap;

  final VoidCallback? onExportExcel;

  const AdminAttendanceMonthViewWidget({
    super.key,
    required this.monthlyRecords,
    required this.selectedMonth,
    required this.selectedStaff,
    required this.onStatusChanged,
    required this.onSelfieTap,
    this.onExportExcel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final nepaliMonthHeader = formatNepaliDate(selectedMonth, 'yyyy MMMM');

    // Aggregate monthly statistics
    final totalRecords = monthlyRecords.length;
    final presentCount = monthlyRecords.where((r) => r.status == AttendanceStatus.present).length;
    final halfDayCount = monthlyRecords.where((r) => r.status == AttendanceStatus.halfDay).length;
    final outOfBoundsCount = monthlyRecords.where((r) => !r.isWithinGeofence).length;

    double totalHours = 0;
    for (final r in monthlyRecords) {
      if (r.checkOutTime != null) {
        totalHours += r.checkOutTime!.difference(r.checkInTime).inMinutes / 60.0;
      }
    }

    return Column(
      children: [
        // Monthly Metrics Header Banner
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedStaff != null
                              ? '${selectedStaff!.name}\'s Monthly Report'
                              : 'Company Monthly Overview',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (selectedStaff != null)
                          Text(
                            selectedStaff!.role.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$nepaliMonthHeader BS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatBadge(
                    context,
                    'Present Days',
                    '$presentCount',
                    colorScheme.primary,
                  ),
                  _buildStatBadge(
                    context,
                    'Half Days',
                    '$halfDayCount',
                    colorScheme.tertiary,
                  ),
                  _buildStatBadge(
                    context,
                    'Total Hours',
                    '${totalHours.toStringAsFixed(1)}h',
                    colorScheme.secondary,
                  ),
                  _buildStatBadge(
                    context,
                    'Out of Fence',
                    '$outOfBoundsCount',
                    colorScheme.error,
                  ),
                ],
              ),

              if (onExportExcel != null && monthlyRecords.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onExportExcel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.table_chart_rounded, size: 18),
                    label: Text(
                      selectedStaff != null
                          ? 'Export ${selectedStaff!.name}\'s Month Excel'
                          : 'Export Monthly Attendance to Excel',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Record List for the month
        Expanded(
          child: monthlyRecords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy_rounded,
                        size: 48,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No attendance records logged in $nepaliMonthHeader BS',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: totalRecords,
                  itemBuilder: (context, index) {
                    final item = monthlyRecords[index];
                    return AdminAttendanceCardWidget(
                      item: item,
                      onStatusChanged: (status) => onStatusChanged(item, status),
                      onSelfieTap: () {
                        if (item.checkInSelfieUrl != null) {
                          onSelfieTap(item.checkInSelfieUrl!, item.staffName);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatBadge(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
