import '../entities/revision_entity.dart';

abstract class RevisionRepository {
  Future<void> createRevision(RevisionEntity revision);
  Future<List<RevisionEntity>> getRevisionsByOrderId(String orderId);
  Stream<List<RevisionEntity>> getRevisionsStream(String orderId);
}
