import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/firestore_leave_request_datasource.dart';
import '../../data/repositories/leave_request_repository_impl.dart';
import '../../domain/entities/leave_request_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/leave_request_repository.dart';
import 'auth_provider.dart';

final leaveRequestRemoteDataSourceProvider =
    Provider<LeaveRequestRemoteDataSource>((ref) {
  return FirestoreLeaveRequestRemoteDataSource();
});

final leaveRequestRepositoryProvider =
    Provider<LeaveRequestRepository>((ref) {
  final dataSource = ref.watch(leaveRequestRemoteDataSourceProvider);
  return LeaveRequestRepositoryImpl(remoteDataSource: dataSource);
});

final leaveRequestsStreamProvider =
    StreamProvider<List<LeaveRequestEntity>>((ref) {
  final repository = ref.watch(leaveRequestRepositoryProvider);
  return repository.getLeaveRequestsStream();
});

final usersStreamProvider = StreamProvider<List<UserEntity>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return UserEntity(
        id: doc.id,
        name: data['name'] as String? ?? 'Staff Member',
        email: data['email'] as String? ?? '',
        role: _roleFromString(data['role'] as String?),
        isActive: data['isActive'] as bool? ?? true,
      );
    }).toList();
  });
});

UserRole _roleFromString(String? role) {
  switch (role) {
    case 'founder':
      return UserRole.founder;
    case 'staff':
      return UserRole.staff;
    default:
      return UserRole.admin;
  }
}

class LeaveRequestNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> submitLeave(LeaveRequestEntity request) async {
    final repository = ref.read(leaveRequestRepositoryProvider);
    await repository.submitLeaveRequest(request);
  }

  Future<void> reviewLeave({
    required String requestId,
    required LeaveStatus status,
  }) async {
    final repository = ref.read(leaveRequestRepositoryProvider);
    final reviewerName =
        ref.read(authNotifierProvider).user?.email ?? 'Admin';
    await repository.updateLeaveStatus(
      requestId: requestId,
      status: status,
      reviewerName: reviewerName,
    );
  }

  Future<void> toggleUserActive(String userId, bool isActive) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'isActive': isActive,
    });
  }
}

final leaveRequestNotifierProvider =
    NotifierProvider<LeaveRequestNotifier, void>(LeaveRequestNotifier.new);
