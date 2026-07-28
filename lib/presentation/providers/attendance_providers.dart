import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/attendance_entity.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../domain/usecases/attendance_usecases.dart';
import '../../data/datasources/remote/firestore_attendance_remote_data_source.dart';
import '../../data/repositories/attendance_repository_impl.dart';

final attendanceRemoteDataSourceProvider = Provider<FirestoreAttendanceRemoteDataSource>((ref) {
  return FirestoreAttendanceRemoteDataSourceImpl(firestore: FirebaseFirestore.instance);
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepositoryImpl(
    remoteDataSource: ref.watch(attendanceRemoteDataSourceProvider),
  );
});

final checkInUseCaseProvider = Provider<CheckInUseCase>((ref) {
  return CheckInUseCase(ref.watch(attendanceRepositoryProvider));
});

final checkOutUseCaseProvider = Provider<CheckOutUseCase>((ref) {
  return CheckOutUseCase(ref.watch(attendanceRepositoryProvider));
});

final updateAttendanceStatusUseCaseProvider = Provider<UpdateAttendanceStatusUseCase>((ref) {
  return UpdateAttendanceStatusUseCase(ref.watch(attendanceRepositoryProvider));
});

final eventAttendanceStreamProvider = StreamProvider.family<List<AttendanceEntity>, String>((ref, eventId) {
  return ref.watch(attendanceRepositoryProvider).getEventAttendanceStream(eventId);
});

final staffAttendanceStreamProvider = StreamProvider.family<List<AttendanceEntity>, String>((ref, staffId) {
  return ref.watch(attendanceRepositoryProvider).getStaffAttendanceStream(staffId);
});

final todayAttendanceStreamProvider = StreamProvider<List<AttendanceEntity>>((ref) {
  return ref.watch(attendanceRepositoryProvider).getTodayAttendanceStream();
});

final allAttendanceStreamProvider = StreamProvider<List<AttendanceEntity>>((ref) {
  return ref.watch(attendanceRepositoryProvider).getAllAttendanceStream();
});

class AttendanceState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const AttendanceState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  AttendanceState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return AttendanceState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class AttendanceNotifier extends Notifier<AttendanceState> {
  @override
  AttendanceState build() {
    return const AttendanceState();
  }

  Future<bool> checkIn(AttendanceEntity attendance, {String? selfieBase64}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await ref.read(checkInUseCaseProvider).execute(attendance, selfieBase64: selfieBase64);
      state = state.copyWith(isLoading: false, successMessage: 'Clock-in recorded successfully!');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to clock in: $e');
      return false;
    }
  }

  Future<bool> checkOut({
    required String attendanceId,
    required DateTime checkOutTime,
    double? latitude,
    double? longitude,
    String? address,
    String? selfieBase64,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await ref.read(checkOutUseCaseProvider).execute(
        attendanceId: attendanceId,
        checkOutTime: checkOutTime,
        latitude: latitude,
        longitude: longitude,
        address: address,
        selfieBase64: selfieBase64,
        notes: notes,
      );
      state = state.copyWith(isLoading: false, successMessage: 'Clock-out recorded successfully!');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to clock out: $e');
      return false;
    }
  }

  Future<void> updateStatus(String attendanceId, AttendanceStatus status) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await ref.read(updateAttendanceStatusUseCaseProvider).execute(
        attendanceId: attendanceId,
        status: status,
      );
      state = state.copyWith(isLoading: false, successMessage: 'Attendance status updated!');
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to update status: $e');
    }
  }
}

final attendanceNotifierProvider = NotifierProvider<AttendanceNotifier, AttendanceState>(() {
  return AttendanceNotifier();
});
