import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/data/datasources/remote/firestore_employee_profile_datasource.dart';
import 'package:order_app/data/repositories/employee_profile_repository_impl.dart';
import 'package:order_app/domain/entities/employee_profile_entity.dart';
import 'package:order_app/domain/repositories/employee_profile_repository.dart';

final employeeProfileRemoteDataSourceProvider =
    Provider<EmployeeProfileRemoteDataSource>((ref) {
  return FirestoreEmployeeProfileRemoteDataSource();
});

final employeeProfileRepositoryProvider =
    Provider<EmployeeProfileRepository>((ref) {
  final dataSource = ref.watch(employeeProfileRemoteDataSourceProvider);
  return EmployeeProfileRepositoryImpl(remoteDataSource: dataSource);
});

final employeeProfilesStreamProvider =
    StreamProvider<List<EmployeeProfileEntity>>((ref) {
  final repository = ref.watch(employeeProfileRepositoryProvider);
  return repository.getEmployeeProfilesStream();
});

final employeeProfileFamilyProvider = FutureProvider.family<EmployeeProfileEntity?, String>(
  (ref, userId) async {
    final repository = ref.watch(employeeProfileRepositoryProvider);
    return repository.getEmployeeProfileByUserId(userId);
  },
);

class EmployeeProfileNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> saveProfile(EmployeeProfileEntity profile) async {
    final repository = ref.read(employeeProfileRepositoryProvider);
    await repository.saveEmployeeProfile(profile);
    ref.invalidate(employeeProfilesStreamProvider);
  }
}

final employeeProfileNotifierProvider =
    NotifierProvider<EmployeeProfileNotifier, void>(
        EmployeeProfileNotifier.new);
