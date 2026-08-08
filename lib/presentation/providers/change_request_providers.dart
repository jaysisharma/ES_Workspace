import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/data/datasources/remote/firestore_change_request_remote_datasource.dart';
import 'package:order_app/data/repositories/change_request_repository_impl.dart';
import 'package:order_app/domain/repositories/change_request_repository.dart';
import 'package:order_app/domain/usecases/create_change_request_usecase.dart';
import 'package:order_app/domain/usecases/get_change_requests_by_order_usecase.dart';
import 'package:order_app/domain/usecases/update_change_request_status_usecase.dart';
import 'change_request_notifier.dart';

final changeRequestRemoteDataSourceProvider =
    Provider<FirestoreChangeRequestRemoteDataSource>((ref) {
      return FirestoreChangeRequestRemoteDataSource();
    });

final changeRequestRepositoryProvider = Provider<ChangeRequestRepository>((
  ref,
) {
  final remoteDataSource = ref.watch(changeRequestRemoteDataSourceProvider);
  return ChangeRequestRepositoryImpl(remoteDataSource: remoteDataSource);
});

final createChangeRequestUseCaseProvider = Provider<CreateChangeRequestUseCase>(
  (ref) {
    final repository = ref.watch(changeRequestRepositoryProvider);
    return CreateChangeRequestUseCase(repository);
  },
);

final getChangeRequestsByOrderUseCaseProvider =
    Provider<GetChangeRequestsByOrderUseCase>((ref) {
      final repository = ref.watch(changeRequestRepositoryProvider);
      return GetChangeRequestsByOrderUseCase(repository);
    });

final updateChangeRequestStatusUseCaseProvider =
    Provider<UpdateChangeRequestStatusUseCase>((ref) {
      final repository = ref.watch(changeRequestRepositoryProvider);
      return UpdateChangeRequestStatusUseCase(repository);
    });

final changeRequestNotifierProvider =
    NotifierProvider<ChangeRequestNotifier, ChangeRequestState>(() {
      // Note: In Riverpod 3.0 Notifier, dependencies should typically be accessed via ref in build()
      // but for this manual implementation we can pass them in the factory.
      // However, Notifier build() doesn't have access to the arguments passed in constructor easily.
      // Better to rewrite Notifier to use ref.read inside methods.
      return ChangeRequestNotifier();
    });
