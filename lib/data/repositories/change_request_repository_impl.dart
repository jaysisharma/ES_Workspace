import 'package:order_app/domain/entities/change_request_entity.dart';
import 'package:order_app/domain/repositories/change_request_repository.dart';
import '../datasources/remote/firestore_change_request_remote_datasource.dart';
import 'package:order_app/core/errors/failures.dart';

class ChangeRequestRepositoryImpl implements ChangeRequestRepository {
  final ChangeRequestRemoteDataSource _remoteDataSource;

  ChangeRequestRepositoryImpl({
    required ChangeRequestRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<void> createRequest(ChangeRequestEntity request) async {
    try {
      await _remoteDataSource.createRequest(request);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to create change request: ${e.toString()}');
    }
  }

  @override
  Future<void> updateRequestStatus(String requestId, String status) async {
    try {
      await _remoteDataSource.updateRequestStatus(requestId, status);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to update change request: ${e.toString()}');
    }
  }

  @override
  Future<List<ChangeRequestEntity>> getRequestsByOrder(String orderId) async {
    try {
      return await _remoteDataSource.getRequestsByOrder(orderId);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to fetch change requests: ${e.toString()}');
    }
  }
}
