import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/leave_request_model.dart';
import '../../../domain/entities/leave_request_entity.dart';

abstract class LeaveRequestRemoteDataSource {
  Stream<List<LeaveRequestEntity>> getLeaveRequests();
  Future<void> submitLeaveRequest(LeaveRequestEntity request);
  Future<void> updateLeaveStatus({
    required String requestId,
    required LeaveStatus status,
    required String reviewerName,
  });
}

class FirestoreLeaveRequestRemoteDataSource
    implements LeaveRequestRemoteDataSource {
  final FirebaseFirestore _firestore;

  FirestoreLeaveRequestRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<LeaveRequestEntity>> getLeaveRequests() {
    return _firestore
        .collection('leave_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => LeaveRequestModel.fromJson(doc.data()))
              .toList();
        });
  }

  @override
  Future<void> submitLeaveRequest(LeaveRequestEntity request) async {
    final model = LeaveRequestModel.fromEntity(request);
    await _firestore
        .collection('leave_requests')
        .doc(model.id)
        .set(model.toJson());
  }

  @override
  Future<void> updateLeaveStatus({
    required String requestId,
    required LeaveStatus status,
    required String reviewerName,
  }) async {
    await _firestore.collection('leave_requests').doc(requestId).update({
      'status': status.name,
      'reviewedBy': reviewerName,
      'reviewedAt': DateTime.now().toIso8601String(),
    });
  }
}
