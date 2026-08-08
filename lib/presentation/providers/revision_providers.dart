import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/data/datasources/remote/firestore_revision_remote_datasource.dart';
import 'package:order_app/data/repositories/revision_repository_impl.dart';
import 'package:order_app/domain/repositories/revision_repository.dart';
import 'package:order_app/domain/usecases/create_revision_usecase.dart';
import 'package:order_app/domain/usecases/get_revisions_by_order_usecase.dart';
import 'package:order_app/domain/entities/revision_entity.dart';

final revisionRemoteDataSourceProvider = Provider<RevisionRemoteDataSource>((
  ref,
) {
  return FirestoreRevisionRemoteDataSource();
});

final revisionRepositoryProvider = Provider<RevisionRepository>((ref) {
  return RevisionRepositoryImpl(
    remoteDataSource: ref.watch(revisionRemoteDataSourceProvider),
  );
});

final createRevisionUseCaseProvider = Provider<CreateRevisionUseCase>((ref) {
  return CreateRevisionUseCase(ref.watch(revisionRepositoryProvider));
});

final getRevisionsByOrderUseCaseProvider = Provider<GetRevisionsByOrderUseCase>(
  (ref) {
    return GetRevisionsByOrderUseCase(ref.watch(revisionRepositoryProvider));
  },
);

final revisionsStreamProvider =
    StreamProvider.family<List<RevisionEntity>, String>((ref, orderId) {
      return ref.watch(revisionRepositoryProvider).getRevisionsStream(orderId);
    });
