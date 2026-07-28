import '../entities/revision_entity.dart';
import '../repositories/revision_repository.dart';

class CreateRevisionUseCase {
  final RevisionRepository _repository;

  CreateRevisionUseCase(this._repository);

  Future<void> call(RevisionEntity revision) {
    return _repository.createRevision(revision);
  }
}
