import '../entities/attendance_entity.dart';
import '../repositories/attendance_repository.dart';

class CheckInUseCase {
  final AttendanceRepository repository;
  CheckInUseCase(this.repository);

  Future<void> execute(AttendanceEntity attendance, {String? selfieBase64}) {
    return repository.checkIn(attendance, selfieBase64: selfieBase64);
  }
}

class CheckOutUseCase {
  final AttendanceRepository repository;
  CheckOutUseCase(this.repository);

  Future<void> execute({
    required String attendanceId,
    required DateTime checkOutTime,
    double? latitude,
    double? longitude,
    String? address,
    String? selfieBase64,
    String? notes,
  }) {
    return repository.checkOut(
      attendanceId: attendanceId,
      checkOutTime: checkOutTime,
      latitude: latitude,
      longitude: longitude,
      address: address,
      selfieBase64: selfieBase64,
      notes: notes,
    );
  }
}

class GetEventAttendanceUseCase {
  final AttendanceRepository repository;
  GetEventAttendanceUseCase(this.repository);

  Stream<List<AttendanceEntity>> execute(String eventId) {
    return repository.getEventAttendanceStream(eventId);
  }
}

class GetStaffAttendanceUseCase {
  final AttendanceRepository repository;
  GetStaffAttendanceUseCase(this.repository);

  Stream<List<AttendanceEntity>> execute(String staffId) {
    return repository.getStaffAttendanceStream(staffId);
  }
}

class GetTodayAttendanceUseCase {
  final AttendanceRepository repository;
  GetTodayAttendanceUseCase(this.repository);

  Stream<List<AttendanceEntity>> execute() {
    return repository.getTodayAttendanceStream();
  }
}

class UpdateAttendanceStatusUseCase {
  final AttendanceRepository repository;
  UpdateAttendanceStatusUseCase(this.repository);

  Future<void> execute({
    required String attendanceId,
    required AttendanceStatus status,
  }) {
    return repository.updateAttendanceStatus(
      attendanceId: attendanceId,
      status: status,
    );
  }
}
