import 'package:order_app/domain/entities/employee_profile_entity.dart';
import 'package:order_app/domain/repositories/employee_profile_repository.dart';
import '../datasources/remote/firestore_employee_profile_datasource.dart';

class EmployeeProfileRepositoryImpl implements EmployeeProfileRepository {
  final EmployeeProfileRemoteDataSource remoteDataSource;

  EmployeeProfileRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<EmployeeProfileEntity>> getEmployeeProfilesStream() {
    return remoteDataSource.getEmployeeProfiles();
  }

  @override
  Future<EmployeeProfileEntity?> getEmployeeProfileByUserId(String userId) {
    return remoteDataSource.getEmployeeProfileByUserId(userId);
  }

  @override
  Future<void> saveEmployeeProfile(EmployeeProfileEntity profile) {
    return remoteDataSource.saveEmployeeProfile(profile);
  }

  @override
  Future<void> deleteEmployeeProfile(String profileId) {
    return remoteDataSource.deleteEmployeeProfile(profileId);
  }

  @override
  Future<void> deleteEmployeeProfileByUserId(String userId) {
    return remoteDataSource.deleteEmployeeProfileByUserId(userId);
  }
}
