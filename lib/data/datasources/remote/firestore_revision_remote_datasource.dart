import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/entities/revision_entity.dart';
import '../../models/revision_model.dart';

abstract class RevisionRemoteDataSource {
  Future<void> createRevision(RevisionEntity revision);
  Future<List<RevisionEntity>> getRevisionsByOrderId(String orderId);
  Stream<List<RevisionEntity>> getRevisionsStream(String orderId);
}

class FirestoreRevisionRemoteDataSource implements RevisionRemoteDataSource {
  final FirebaseFirestore _firestore;

  FirestoreRevisionRemoteDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> createRevision(RevisionEntity revision) async {
    try {
      final model = RevisionModel.fromEntity(revision);
      await _firestore
          .collection('revisions')
          .doc(model.id)
          .set(model.toJson());
    } catch (e) {
      throw ServerException('Failed to create revision: ${e.toString()}');
    }
  }

  @override
  Future<List<RevisionEntity>> getRevisionsByOrderId(String orderId) async {
    try {
      final querySnapshot = await _firestore
          .collection('revisions')
          .where('orderId', isEqualTo: orderId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => RevisionModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw ServerException('Failed to fetch revisions: ${e.toString()}');
    }
  }

  @override
  Stream<List<RevisionEntity>> getRevisionsStream(String orderId) {
    return _firestore
        .collection('revisions')
        .where('orderId', isEqualTo: orderId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => RevisionModel.fromJson(doc.data()))
              .toList();
        });
  }
}
