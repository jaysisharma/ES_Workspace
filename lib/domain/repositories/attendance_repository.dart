import '../entities/attendance_entity.dart';

abstract class AttendanceRepository {
  Future<void> checkIn(
    AttendanceEntity attendance, {
    String? selfieBase64,
  });

  Future<void> checkOut({
    required String attendanceId,
    required DateTime checkOutTime,
    double? latitude,
    double? longitude,
    String? address,
    String? selfieBase64,
    String? notes,
  });

  Stream<List<AttendanceEntity>> getEventAttendanceStream(String eventId);
  Stream<List<AttendanceEntity>> getStaffAttendanceStream(String staffId);
  Stream<List<AttendanceEntity>> getTodayAttendanceStream();
  Stream<List<AttendanceEntity>> getAllAttendanceStream();

  Future<void> updateAttendanceStatus({
    required String attendanceId,
    required AttendanceStatus status,
  });

  Future<void> deleteAttendanceRecord(String attendanceId);
}
