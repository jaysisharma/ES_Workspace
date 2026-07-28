import '../../domain/entities/event_entity.dart';
import '../../domain/repositories/event_repository.dart';
import '../datasources/remote/firestore_event_remote_datasource.dart';
import '../models/event_model.dart';

class EventRepositoryImpl implements EventRepository {
  final FirestoreEventRemoteDataSource _remoteDataSource;

  EventRepositoryImpl(this._remoteDataSource);

  @override
  Stream<List<EventEntity>> getEvents() {
    return _remoteDataSource.getEvents().map(
      (list) => list.map((e) => e as EventEntity).toList(),
    );
  }

  @override
  Future<EventEntity?> getEventById(String id) {
    return _remoteDataSource.getEventById(id);
  }

  @override
  Future<void> createEvent(EventEntity event) {
    return _remoteDataSource.createEvent(EventModel.fromEntity(event));
  }

  @override
  Future<void> updateEvent(EventEntity event) {
    return _remoteDataSource.updateEvent(EventModel.fromEntity(event));
  }

  @override
  Future<void> deleteEvent(String id) {
    return _remoteDataSource.deleteEvent(id);
  }
}
