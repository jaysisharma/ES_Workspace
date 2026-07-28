import '../repositories/change_request_repository.dart';

class UpdateChangeRequestStatusUseCase {
  final ChangeRequestRepository repository;

  UpdateChangeRequestStatusUseCase(this.repository);

  Future<void> call(String requestId, String status) async {
    return await repository.updateRequestStatus(requestId, status);
  }
}
