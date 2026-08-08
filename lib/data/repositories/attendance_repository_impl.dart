import 'package:cloud_functions/cloud_functions.dart';
import 'package:order_app/domain/entities/attendance_entity.dart';
import 'package:order_app/domain/repositories/attendance_repository.dart';
import '../datasources/remote/firestore_attendance_remote_data_source.dart';
import '../models/attendance_model.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final FirestoreAttendanceRemoteDataSource remoteDataSource;
  final FirebaseFunctions? functions;

  AttendanceRepositoryImpl({
    required this.remoteDataSource,
    this.functions,
  });

  FirebaseFunctions get _functions => functions ?? FirebaseFunctions.instance;

  Future<String?> _uploadSelfieToSynology({
    required String selfieBase64,
    required String staffId,
    required String eventId,
    required String type,
  }) async {
    try {
      final callable = _functions.httpsCallable('uploadToSynology');
      final response = await callable.call({
        'imageBase64': selfieBase64,
        'staffId': staffId,
        'eventId': eventId,
        'type': type,
      });

      if (response.data != null && response.data['synologyUrl'] != null) {
        return response.data['synologyUrl'] as String;
      }
    } catch (e) {
      // Fallback or log error if Cloud Function call fails
      print('Failed to upload selfie to Synology NAS via Cloud Function: $e');
    }
    return null;
  }

  @override
  Future<void> checkIn(
    AttendanceEntity attendance, {
    String? selfieBase64,
  }) async {
    String? synologyUrl;
    if (selfieBase64 != null && selfieBase64.isNotEmpty) {
      synologyUrl = await _uploadSelfieToSynology(
        selfieBase64: selfieBase64,
        staffId: attendance.staffId,
        eventId: attendance.eventId,
        type: 'check_in',
      );
    }

    final updatedEntity = attendance.copyWith(
      checkInSelfieUrl: synologyUrl ?? attendance.checkInSelfieUrl,
    );

    final model = AttendanceModel.fromEntity(updatedEntity);
    await remoteDataSource.saveAttendance(model);
  }

  @override
  Future<void> checkOut({
    required String attendanceId,
    required DateTime checkOutTime,
    double? latitude,
    double? longitude,
    String? address,
    String? selfieBase64,
    String? notes,
  }) async {
    String? synologyUrl;
    if (selfieBase64 != null && selfieBase64.isNotEmpty) {
      synologyUrl = await _uploadSelfieToSynology(
        selfieBase64: selfieBase64,
        staffId: attendanceId,
        eventId: 'checkout',
        type: 'check_out',
      );
    }

    await remoteDataSource.updateCheckOut(
      attendanceId: attendanceId,
      checkOutTime: checkOutTime,
      latitude: latitude,
      longitude: longitude,
      address: address,
      selfieUrl: synologyUrl,
      notes: notes,
    );
  }

  @override
  Stream<List<AttendanceEntity>> getEventAttendanceStream(String eventId) {
    return remoteDataSource.getEventAttendanceStream(eventId);
  }

  @override
  Stream<List<AttendanceEntity>> getStaffAttendanceStream(String staffId) {
    return remoteDataSource.getStaffAttendanceStream(staffId);
  }

  @override
  Stream<List<AttendanceEntity>> getTodayAttendanceStream() {
    return remoteDataSource.getTodayAttendanceStream();
  }

  @override
  Stream<List<AttendanceEntity>> getAllAttendanceStream() {
    return remoteDataSource.getAllAttendanceStream();
  }

  @override
  Future<void> updateAttendanceStatus({
    required String attendanceId,
    required AttendanceStatus status,
  }) {
    return remoteDataSource.updateStatus(attendanceId, status);
  }

  @override
  Future<void> deleteAttendanceRecord(String attendanceId) {
    return remoteDataSource.deleteRecord(attendanceId);
  }
}
