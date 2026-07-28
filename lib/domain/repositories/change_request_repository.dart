import '../entities/change_request_entity.dart';

abstract class ChangeRequestRepository {
  Future<void> createRequest(ChangeRequestEntity request);
  Future<void> updateRequestStatus(String requestId, String status);
  Future<List<ChangeRequestEntity>> getRequestsByOrder(String orderId);
}
