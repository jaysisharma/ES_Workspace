import 'package:order_app/domain/entities/leave_request_entity.dart';
import 'package:order_app/domain/repositories/leave_request_repository.dart';
import '../datasources/remote/firestore_leave_request_datasource.dart';

class LeaveRequestRepositoryImpl implements LeaveRequestRepository {
  final LeaveRequestRemoteDataSource remoteDataSource;

  LeaveRequestRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<LeaveRequestEntity>> getLeaveRequestsStream() {
    return remoteDataSource.getLeaveRequests();
  }

  @override
  Future<void> submitLeaveRequest(LeaveRequestEntity request) {
    return remoteDataSource.submitLeaveRequest(request);
  }

  @override
  Future<void> updateLeaveStatus({
    required String requestId,
    required LeaveStatus status,
    required String reviewerName,
  }) {
    return remoteDataSource.updateLeaveStatus(
      requestId: requestId,
      status: status,
      reviewerName: reviewerName,
    );
  }
}
