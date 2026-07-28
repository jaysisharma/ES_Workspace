import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/errors/failures.dart';
import '../../models/change_request_model.dart';
import '../../../domain/entities/change_request_entity.dart';

abstract class ChangeRequestRemoteDataSource {
  Future<void> createRequest(ChangeRequestEntity request);
  Future<void> updateRequestStatus(String requestId, String status);
  Future<List<ChangeRequestEntity>> getRequestsByOrder(String orderId);
}

class FirestoreChangeRequestRemoteDataSource
    implements ChangeRequestRemoteDataSource {
  final FirebaseFirestore _firestore;

  FirestoreChangeRequestRemoteDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> createRequest(ChangeRequestEntity request) async {
    try {
      final requestModel = ChangeRequestModel.fromEntity(request);
      await _firestore
          .collection('change_requests')
          .doc(requestModel.id)
          .set(requestModel.toJson());
    } catch (e) {
      throw ServerException('Failed to create change request: ${e.toString()}');
    }
  }

  @override
  Future<void> updateRequestStatus(String requestId, String status) async {
    try {
      await _firestore.collection('change_requests').doc(requestId).update({
        'status': status,
      });
    } catch (e) {
      throw ServerException('Failed to update request status: ${e.toString()}');
    }
  }

  @override
  Future<List<ChangeRequestEntity>> getRequestsByOrder(String orderId) async {
    try {
      final querySnapshot = await _firestore
          .collection('change_requests')
          .where('orderId', isEqualTo: orderId)
          .get();

      return querySnapshot.docs.map((doc) {
        return ChangeRequestModel.fromJson(doc.data());
      }).toList();
    } catch (e) {
      throw ServerException('Failed to fetch change requests: ${e.toString()}');
    }
  }
}
