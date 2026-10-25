import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:order_app/core/services/fcm_sender.dart';
import 'package:order_app/core/utils/nepali_date_formatter.dart';
import 'package:order_app/domain/entities/attendance_entity.dart';
import 'package:order_app/domain/entities/notification_entity.dart';
import 'package:order_app/domain/repositories/attendance_repository.dart';
import 'package:order_app/domain/usecases/attendance_usecases.dart';
import 'package:order_app/data/datasources/remote/firestore_attendance_remote_data_source.dart';
import 'package:order_app/data/repositories/attendance_repository_impl.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/employee_profile_providers.dart';
import 'package:order_app/presentation/providers/notification_notifier.dart';

final attendanceRemoteDataSourceProvider =
    Provider<FirestoreAttendanceRemoteDataSource>((ref) {
      return FirestoreAttendanceRemoteDataSourceImpl(
        firestore: FirebaseFirestore.instance,
      );
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

final updateAttendanceStatusUseCaseProvider =
    Provider<UpdateAttendanceStatusUseCase>((ref) {
      return UpdateAttendanceStatusUseCase(
        ref.watch(attendanceRepositoryProvider),
      );
    });

final eventAttendanceStreamProvider =
    StreamProvider.family<List<AttendanceEntity>, String>((ref, eventId) {
      return ref
          .watch(attendanceRepositoryProvider)
          .getEventAttendanceStream(eventId);
    });

final staffAttendanceStreamProvider =
    StreamProvider.family<List<AttendanceEntity>, String>((ref, staffId) {
      return ref
          .watch(attendanceRepositoryProvider)
          .getStaffAttendanceStream(staffId);
    });

final todayAttendanceStreamProvider = StreamProvider<List<AttendanceEntity>>((
  ref,
) {
  return ref.watch(attendanceRepositoryProvider).getTodayAttendanceStream();
});

final allAttendanceStreamProvider = StreamProvider<List<AttendanceEntity>>((
  ref,
) {
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

  Future<bool> checkIn(
    AttendanceEntity attendance, {
    String? selfieBase64,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await ref
          .read(checkInUseCaseProvider)
          .execute(attendance, selfieBase64: selfieBase64);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Clock-in recorded successfully!',
      );

      // Notify all users about check-in
      _notifyAllUsersOfAttendance(
        isCheckIn: true,
        staffName: attendance.staffName,
        time: attendance.checkInTime,
        location: attendance.checkInAddress ?? attendance.eventTitle,
        attendanceId: attendance.id,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to clock in: $e',
      );
      return false;
    }
  }

  Future<bool> checkOut({
    required String attendanceId,
    required DateTime checkOutTime,
    String? staffName,
    double? latitude,
    double? longitude,
    String? address,
    String? selfieBase64,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await ref
          .read(checkOutUseCaseProvider)
          .execute(
            attendanceId: attendanceId,
            checkOutTime: checkOutTime,
            latitude: latitude,
            longitude: longitude,
            address: address,
            selfieBase64: selfieBase64,
            notes: notes,
          );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Clock-out recorded successfully!',
      );

      // Notify all users about check-out
      _notifyAllUsersOfAttendance(
        isCheckIn: false,
        staffName: staffName,
        time: checkOutTime,
        location: address,
        attendanceId: attendanceId,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to clock out: $e',
      );
      return false;
    }
  }

  /// Broadcasts attendance check-in / check-out notification to all users across the system.
  Future<void> _notifyAllUsersOfAttendance({
    required bool isCheckIn,
    String? staffName,
    required DateTime time,
    String? location,
    required String attendanceId,
  }) async {
    try {
      String resolvedName = staffName?.trim() ?? '';
      if (resolvedName.isEmpty) {
        final profile = ref.read(currentEmployeeProfileProvider);
        if (profile != null && profile.name.trim().isNotEmpty) {
          resolvedName = profile.name.trim();
        } else {
          try {
            final doc = await FirebaseFirestore.instance
                .collection('attendance')
                .doc(attendanceId)
                .get();
            if (doc.exists) {
              resolvedName = doc.data()?['staffName'] as String? ?? '';
            }
          } catch (_) {}

          if (resolvedName.isEmpty) {
            final authUser = ref.read(authNotifierProvider).user;
            if (authUser != null && authUser.email.contains('@')) {
              final raw = authUser.email.split('@').first;
              if (raw.isNotEmpty) {
                resolvedName = raw[0].toUpperCase() + raw.substring(1);
              }
            }
          }
        }
      }

      if (resolvedName.isEmpty) {
        resolvedName = 'A team member';
      }

      final formattedTime = DateFormat('hh:mm a').format(time);
      final nepaliDate = formatNepaliDate(time, 'MMM dd');

      final title = isCheckIn
          ? '$resolvedName Checked In'
          : '$resolvedName Checked Out';

      final locText = (location != null && location.trim().isNotEmpty)
          ? ' • ${location.trim()}'
          : '';

      final description = isCheckIn
          ? '$resolvedName clocked in at $formattedTime ($nepaliDate)$locText'
          : '$resolvedName clocked out at $formattedTime ($nepaliDate)$locText';

      final notificationId = const Uuid().v4();

      // 1. Save In-App Notification targeting 'all' in Firestore
      await ref
          .read(notificationNotifierProvider.notifier)
          .addNotification(
            NotificationEntity(
              id: notificationId,
              title: title,
              description: description,
              timestamp: DateTime.now(),
              type: 'attendance',
              relatedId: attendanceId,
              targetRole: 'all',
            ),
          );

      // 2. Broadcast FCM push to all user roles
      const allRoleTopics = [
        'role_super_admin',
        'role_admin',
        'role_founder',
        'role_director',
        'role_company_secretary',
        'role_senior_staff',
        'role_finance',
        'role_staff',
      ];

      FcmSender.sendToTopics(
        topics: allRoleTopics,
        title: title,
        body: description,
        notificationId: notificationId,
        data: {
          'type': 'attendance',
          'attendanceId': attendanceId,
          'action': isCheckIn ? 'check_in' : 'check_out',
        },
      );
    } catch (e) {
      debugPrint('Failed to send attendance broadcast notification: $e');
    }
  }

  Future<void> updateStatus(
    String attendanceId,
    AttendanceStatus status,
  ) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await ref
          .read(updateAttendanceStatusUseCaseProvider)
          .execute(attendanceId: attendanceId, status: status);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Attendance status updated!',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update status: $e',
      );
    }
  }
}

final attendanceNotifierProvider =
    NotifierProvider<AttendanceNotifier, AttendanceState>(() {
      return AttendanceNotifier();
    });
