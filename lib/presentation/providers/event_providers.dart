import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/firestore_event_remote_datasource.dart';
import '../../data/repositories/event_repository_impl.dart';
import '../../domain/entities/event_entity.dart';
import '../../domain/repositories/event_repository.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final eventRemoteDataSourceProvider = Provider<FirestoreEventRemoteDataSource>((
  ref,
) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreEventRemoteDataSource(firestore);
});

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final remoteDataSource = ref.watch(eventRemoteDataSourceProvider);
  return EventRepositoryImpl(remoteDataSource);
});

final eventsStreamProvider = StreamProvider<List<EventEntity>>((ref) {
  final repository = ref.watch(eventRepositoryProvider);
  return repository.getEvents();
});
