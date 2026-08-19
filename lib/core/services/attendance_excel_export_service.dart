import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:order_app/core/utils/excel_export_helper.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/attendance_entity.dart';
import 'package:order_app/domain/entities/user_entity.dart';

import 'package:order_app/core/services/export_directory_service.dart';

class AttendanceExcelExportService {
  /// Exports monthly attendance records for a specific employee or all employees to Excel.
  static Future<void> exportMonthlyAttendance({
    required BuildContext context,
    required List<AttendanceEntity> records,
    required DateTime selectedMonth,
    UserEntity? selectedStaff,
    String? staffNameOverride,
  }) async {
    final nepaliMonthHeader = formatNepaliDate(selectedMonth, 'yyyy MMMM');

    final title = selectedStaff != null || staffNameOverride != null
        ? '${selectedStaff?.name ?? staffNameOverride} - Monthly Attendance Report ($nepaliMonthHeader)'
        : 'Company Wide - Monthly Attendance Report ($nepaliMonthHeader)';

    final headers = [
      'S.N.',
      'Staff Name',
      'Date',
      'Day',
      'Check-In Time',
      'Check-Out Time',
      'Duration (Hours)',
      'Status',
      'Geofence Zone',
      'Check-In Location / Address',
      'Check-Out Location',
      'Event / Shift Notes',
    ];

    // Sort records chronologically (oldest to newest for report readability)
    final sorted = List<AttendanceEntity>.from(records)
      ..sort((a, b) => a.checkInTime.compareTo(b.checkInTime));

    final List<List<dynamic>> rows = [];
    double totalHours = 0.0;
    int presentCount = 0;
    int halfDayCount = 0;
    int outOfBoundsCount = 0;

    for (int i = 0; i < sorted.length; i++) {
      final r = sorted[i];

      // Calculate working hours
      double hoursWorked = 0.0;
      if (r.checkOutTime != null) {
        hoursWorked = r.checkOutTime!.difference(r.checkInTime).inMinutes / 60.0;
        totalHours += hoursWorked;
      }

      if (r.status == AttendanceStatus.present) presentCount++;
      if (r.status == AttendanceStatus.halfDay) halfDayCount++;
      if (!r.isWithinGeofence) outOfBoundsCount++;

      final dateStr = formatNepaliDate(r.checkInTime, 'yyyy-MM-dd');
      final dayName = DateFormat('EEEE').format(r.checkInTime);
      final checkInStr = DateFormat('hh:mm a').format(r.checkInTime);
      final checkOutStr = r.checkOutTime != null
          ? DateFormat('hh:mm a').format(r.checkOutTime!)
          : 'Pending / On Duty';
      final durationStr = hoursWorked > 0
          ? '${hoursWorked.toStringAsFixed(2)} hrs'
          : (r.checkOutTime != null ? '0.0 hrs' : 'In Progress');
      final geofenceStr = r.isWithinGeofence ? 'Verified Inside Zone' : 'Out of Bounds';

      rows.add([
        i + 1,
        r.staffName,
        dateStr,
        dayName,
        checkInStr,
        checkOutStr,
        durationStr,
        r.status.displayName,
        geofenceStr,
        r.checkInAddress ?? 'N/A',
        r.checkOutAddress ?? 'N/A',
        r.notes != null && r.notes!.isNotEmpty
            ? r.notes
            : (r.eventTitle.isNotEmpty ? r.eventTitle : 'Daily Duty'),
      ]);
    }

    // Add Summary / Totals Row at the bottom
    rows.add([
      'TOTAL',
      '${sorted.length} Shifts / Logs',
      '',
      '',
      '',
      'Total Hours:',
      '${totalHours.toStringAsFixed(2)} hrs',
      'Present: $presentCount | Half: $halfDayCount',
      'Out of Fence: $outOfBoundsCount',
      '',
      '',
      '',
    ]);

    // Sanitize file name
    final namePart = selectedStaff?.name ?? staffNameOverride ?? 'All_Employees';
    final cleanName = namePart.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final monthPart = nepaliMonthHeader.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final filename = 'Attendance_${cleanName}_$monthPart.xlsx';

    await ExcelExportHelper.exportAndShareExcel(
      context: context,
      headers: headers,
      rows: rows,
      filename: filename,
      sheetName: 'Attendance',
      title: title,
      category: ExportCategory.attendance,
    );
  }
}
