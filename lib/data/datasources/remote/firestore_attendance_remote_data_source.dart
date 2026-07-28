import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/attendance_model.dart';
import '../../../domain/entities/attendance_entity.dart';

abstract class FirestoreAttendanceRemoteDataSource {
  Future<void> saveAttendance(AttendanceModel model);
  Future<void> updateCheckOut({
    required String attendanceId,
    required DateTime checkOutTime,
    double? latitude,
    double? longitude,
    String? address,
    String? selfieUrl,
    String? notes,
  });
  Stream<List<AttendanceModel>> getEventAttendanceStream(String eventId);
  Stream<List<AttendanceModel>> getStaffAttendanceStream(String staffId);
  Stream<List<AttendanceModel>> getTodayAttendanceStream();
  Stream<List<AttendanceModel>> getAllAttendanceStream();
  Future<void> updateStatus(String attendanceId, AttendanceStatus status);
  Future<void> deleteRecord(String attendanceId);
}

class FirestoreAttendanceRemoteDataSourceImpl implements FirestoreAttendanceRemoteDataSource {
  final FirebaseFirestore firestore;

  FirestoreAttendanceRemoteDataSourceImpl({required this.firestore});

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection('attendance');

  @override
  Future<void> saveAttendance(AttendanceModel model) async {
    await firestore.runTransaction((transaction) async {
      final docRef = _collection.doc(model.id);
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        transaction.set(docRef, model.toJson());
      } else {
        transaction.update(docRef, model.toJson());
      }
    });
  }

  @override
  Future<void> updateCheckOut({
    required String attendanceId,
    required DateTime checkOutTime,
    double? latitude,
    double? longitude,
    String? address,
    String? selfieUrl,
    String? notes,
  }) async {
    await firestore.runTransaction((transaction) async {
      final docRef = _collection.doc(attendanceId);
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw Exception('Attendance record not found.');
      }

      final Map<String, dynamic> updateData = {
        'checkOutTime': Timestamp.fromDate(checkOutTime),
      };
      if (latitude != null) updateData['checkOutLatitude'] = latitude;
      if (longitude != null) updateData['checkOutLongitude'] = longitude;
      if (address != null) updateData['checkOutAddress'] = address;
      if (selfieUrl != null) updateData['checkOutSelfieUrl'] = selfieUrl;
      if (notes != null && notes.isNotEmpty) updateData['notes'] = notes;

      transaction.update(docRef, updateData);
    });
  }

  @override
  Stream<List<AttendanceModel>> getEventAttendanceStream(String eventId) {
    return _collection
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => AttendanceModel.fromJson(doc.data(), doc.id)).toList());
  }

  @override
  Stream<List<AttendanceModel>> getStaffAttendanceStream(String staffId) {
    return _collection
        .where('staffId', isEqualTo: staffId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => AttendanceModel.fromJson(doc.data(), doc.id)).toList());
  }

  @override
  Stream<List<AttendanceModel>> getTodayAttendanceStream() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _collection
        .where('checkInTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('checkInTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snap) => snap.docs.map((doc) => AttendanceModel.fromJson(doc.data(), doc.id)).toList());
  }

  @override
  Stream<List<AttendanceModel>> getAllAttendanceStream() {
    return _collection
        .snapshots()
        .map((snap) => snap.docs.map((doc) => AttendanceModel.fromJson(doc.data(), doc.id)).toList());
  }

  @override
  Future<void> updateStatus(String attendanceId, AttendanceStatus status) async {
    await _collection.doc(attendanceId).update({'status': status.name});
  }

  @override
  Future<void> deleteRecord(String attendanceId) async {
    await _collection.doc(attendanceId).delete();
  }
}
