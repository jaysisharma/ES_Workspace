import 'package:order_app/domain/entities/revision_entity.dart';
import 'package:order_app/domain/repositories/revision_repository.dart';
import '../datasources/remote/firestore_revision_remote_datasource.dart';

class RevisionRepositoryImpl implements RevisionRepository {
  final RevisionRemoteDataSource _remoteDataSource;

  RevisionRepositoryImpl({required RevisionRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  @override
  Future<void> createRevision(RevisionEntity revision) {
    return _remoteDataSource.createRevision(revision);
  }

  @override
  Future<List<RevisionEntity>> getRevisionsByOrderId(String orderId) {
    return _remoteDataSource.getRevisionsByOrderId(orderId);
  }

  @override
  Stream<List<RevisionEntity>> getRevisionsStream(String orderId) {
    return _remoteDataSource.getRevisionsStream(orderId);
  }
}
