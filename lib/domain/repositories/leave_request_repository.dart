import '../entities/leave_request_entity.dart';

abstract class LeaveRequestRepository {
  Stream<List<LeaveRequestEntity>> getLeaveRequestsStream();
  Future<void> submitLeaveRequest(LeaveRequestEntity request);
  Future<void> updateLeaveStatus({
    required String requestId,
    required LeaveStatus status,
    required String reviewerName,
  });
}
