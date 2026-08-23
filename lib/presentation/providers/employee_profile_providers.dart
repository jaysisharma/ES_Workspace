import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/data/datasources/remote/firestore_employee_profile_datasource.dart';
import 'package:order_app/data/repositories/employee_profile_repository_impl.dart';
import 'package:order_app/domain/entities/employee_profile_entity.dart';
import 'package:order_app/domain/repositories/employee_profile_repository.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';
import 'package:order_app/presentation/providers/hr_providers.dart';

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

final currentEmployeeProfileProvider = Provider<EmployeeProfileEntity?>((ref) {
  final authUser = ref.watch(authNotifierProvider).user;
  if (authUser == null) return null;

  final usersList = ref.watch(usersStreamProvider).value ?? [];
  final matchingUser = usersList.where((u) {
    if (u.id.isNotEmpty && u.id == authUser.uid) return true;
    if (authUser.email.isNotEmpty && u.email.toLowerCase() == authUser.email.toLowerCase()) return true;
    return false;
  }).firstOrNull;

  final profiles = ref.watch(employeeProfilesStreamProvider).value ?? [];
  if (profiles.isEmpty) return null;

  final authUid = authUser.uid.trim().toLowerCase();
  final authEmail = authUser.email.trim().toLowerCase();
  final authName = authEmail.contains('@') ? authEmail.split('@').first : authEmail;
  final dbUserId = (matchingUser?.id ?? '').trim().toLowerCase();
  final dbEmail = (matchingUser?.email ?? '').trim().toLowerCase();
  final dbName = (matchingUser?.name ?? '').trim().toLowerCase();

  for (final p in profiles) {
    final pUserId = p.userId.trim().toLowerCase();
    final pId = p.id.trim().toLowerCase();
    final pEmail = p.email.trim().toLowerCase();
    final pName = p.name.trim().toLowerCase();

    // 1. Explicit email stored on profile
    if (pEmail.isNotEmpty) {
      if (authEmail.isNotEmpty && pEmail == authEmail) return p;
      if (dbEmail.isNotEmpty && pEmail == dbEmail) return p;
    }

    // 2. Direct ID matches
    if (authUid.isNotEmpty && (pUserId == authUid || pId == authUid)) return p;
    if (dbUserId.isNotEmpty && (pUserId == dbUserId || pId == dbUserId)) return p;

    // 3. Email in userId field
    if (authEmail.isNotEmpty && (pUserId == authEmail || pId == authEmail)) return p;
    if (dbEmail.isNotEmpty && (pUserId == dbEmail || pId == dbEmail)) return p;

    // 4. Exact full name match from DB user
    if (dbName.isNotEmpty && pName == dbName) return p;

    // 5. Prefix username match
    if (authName.isNotEmpty && (pName == authName || pUserId == authName)) return p;
  }

  return null;
});

class EmployeeProfileNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> saveProfile(EmployeeProfileEntity profile) async {
    final repository = ref.read(employeeProfileRepositoryProvider);
    await repository.saveEmployeeProfile(profile);
    ref.invalidate(employeeProfilesStreamProvider);
  }

  Future<void> deleteProfile(String profileId) async {
    final repository = ref.read(employeeProfileRepositoryProvider);
    await repository.deleteEmployeeProfile(profileId);
    ref.invalidate(employeeProfilesStreamProvider);
  }

  Future<void> deleteProfileByUserId(String userId) async {
    final repository = ref.read(employeeProfileRepositoryProvider);
    await repository.deleteEmployeeProfileByUserId(userId);
    ref.invalidate(employeeProfilesStreamProvider);
  }
}

final employeeProfileNotifierProvider =
    NotifierProvider<EmployeeProfileNotifier, void>(
        EmployeeProfileNotifier.new);

