import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/employee_profile_model.dart';
import 'package:order_app/domain/entities/employee_profile_entity.dart';

abstract class EmployeeProfileRemoteDataSource {
  Stream<List<EmployeeProfileEntity>> getEmployeeProfiles();
  Future<EmployeeProfileEntity?> getEmployeeProfileByUserId(String userId);
  Future<void> saveEmployeeProfile(EmployeeProfileEntity profile);
  Future<void> deleteEmployeeProfile(String profileId);
  Future<void> deleteEmployeeProfileByUserId(String userId);
}

class FirestoreEmployeeProfileRemoteDataSource
    implements EmployeeProfileRemoteDataSource {
  final FirebaseFirestore _firestore;

  FirestoreEmployeeProfileRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<EmployeeProfileEntity>> getEmployeeProfiles() {
    return _firestore.collection('employee_profiles').snapshots().map((snapshot) {
      return snapshot.docs
          .map<EmployeeProfileEntity>((doc) => EmployeeProfileModel.fromJson(doc.data()))
          .toList();
    });
  }

  @override
  Future<EmployeeProfileEntity?> getEmployeeProfileByUserId(
      String userId) async {
    final snapshot = await _firestore
        .collection('employee_profiles')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return EmployeeProfileModel.fromJson(snapshot.docs.first.data());
  }

  @override
  Future<void> saveEmployeeProfile(EmployeeProfileEntity profile) async {
    final model = EmployeeProfileModel.fromEntity(profile);
    await _firestore
        .collection('employee_profiles')
        .doc(model.id)
        .set(model.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteEmployeeProfile(String profileId) async {
    await _firestore.collection('employee_profiles').doc(profileId).delete();
  }

  @override
  Future<void> deleteEmployeeProfileByUserId(String userId) async {
    final snapshot = await _firestore
        .collection('employee_profiles')
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}
