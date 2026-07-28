import '../entities/employee_profile_entity.dart';

abstract class EmployeeProfileRepository {
  Stream<List<EmployeeProfileEntity>> getEmployeeProfilesStream();
  Future<EmployeeProfileEntity?> getEmployeeProfileByUserId(String userId);
  Future<void> saveEmployeeProfile(EmployeeProfileEntity profile);
}
